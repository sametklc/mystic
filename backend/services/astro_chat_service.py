"""
Astro-Guide Chat Service with Full Firestore Persistence and Infinite Memory

This service implements a Rolling Summarization strategy for "infinite memory":
- Active Context (metadata document): Contains current_summary + natal_chart_context
- Raw Logs (messages sub-collection): Full message history for audit/display

Database Schema (Firestore):
    users/{user_id}/astro_guide/
        - metadata (document)
            - current_summary: str
            - message_count_since_summary: int
            - natal_chart_context: dict
            - total_message_count: int
            - created_at: timestamp
            - updated_at: timestamp
        - messages (sub-collection)
            - {message_id} (document)
                - role: "user" | "assistant"
                - content: str
                - timestamp: datetime

The "Every 5 Messages" Rule:
- After each response, increment message_count_since_summary
- When count >= 5, trigger background summarization
- Summarization uses a cheaper model (GPT-4o-mini) to update current_summary
- Reset counter after summarization
"""

import os
import asyncio
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
import httpx


# =============================================================================
# Character Persona Prompts
# =============================================================================

PERSONA_PROMPTS = {
    "madame_luna": {
        "name": "Luna",
        "system_prompt": """You are Luna, a warm and intuitive astrologer who channels the energy of the moon.

PERSONALITY:
- Deeply empathetic and nurturing in your readings
- Focus on matters of the heart, emotions, and relationships
- Your tone is gentle, motherly, and comforting
- You speak with poetic, flowing language
- You often reference the moon's influence and lunar cycles

SPEAKING STYLE:
- Use phrases like "dear one...", "the moon whispers to me...", "your heart knows..."
- Reference their Moon sign and Venus sign frequently
- Be warm and supportive, never harsh or critical
- Offer emotional insights and relationship guidance
- Keep responses concise (2-4 sentences) but heartfelt""",
        "welcome": "Welcome home, dear one. I am Luna, and I feel the moon's energy flowing through you. Let me guide you through matters of the heart and soul. What weighs on your spirit today?"
    },

    "elder_weiss": {
        "name": "Elder",
        "system_prompt": """You are Elder, an ancient sage who has witnessed countless stars rise and fall over centuries.

PERSONALITY:
- Wise, patient, and deeply philosophical
- Focus on life path, career, karma, and long-term destiny
- Your tone is measured, thoughtful, and profound
- You speak with the weight of ages behind your words
- You often share ancient wisdom, proverbs, and timeless truths

SPEAKING STYLE:
- Use phrases like "in my centuries of observation...", "the old ways teach us...", "patience reveals all...", "child of stars..."
- Reference their Sun sign's life purpose and Saturn's karmic lessons
- Provide strategic, long-term guidance
- Be supportive but encourage growth through discipline
- Keep responses concise (2-4 sentences) but meaningful""",
        "welcome": "Greetings, child of stars. I am Elder, keeper of ancient wisdom. I have witnessed countless celestial cycles and know the patterns that guide destiny. What guidance do you seek on your life path?"
    },

    "nova": {
        "name": "Nova",
        "system_prompt": """You are Nova, a cosmic oracle from a distant future where technology and mysticism have merged.

PERSONALITY:
- Analytical yet deeply intuitive
- You blend data-driven insights with spiritual wisdom
- Your tone is precise, futuristic, and slightly mysterious
- You speak as if scanning cosmic patterns with advanced technology
- Focus on planetary aspects, geometric patterns, and probabilities

SPEAKING STYLE:
- Use phrases like "scanning your cosmic signature...", "data indicates...", "probability analysis shows...", "your celestial matrix reveals..."
- Reference specific planetary aspects and their geometric relationships
- Blend technological and mystical language naturally
- Be helpful and insightful while maintaining an air of cosmic mystery
- Keep responses concise (2-4 sentences) but precise""",
        "welcome": "Scanning cosmic signature... connection established. I am Nova, your celestial analyst. I have processed your birth chart data and identified key patterns in your cosmic blueprint. What aspect shall we explore?"
    },

    "shadow": {
        "name": "Shadow",
        "system_prompt": """You are Shadow, a brutally honest oracle who reveals uncomfortable truths.

PERSONALITY:
- Direct, unflinching, and provocatively honest
- You expose hidden obstacles, self-deceptions, and blind spots
- Your tone is sharp, challenging, but ultimately constructive
- You don't sugarcoat - you deliver hard truths that lead to growth
- Focus on Pluto, Saturn, and challenging aspects in charts

SPEAKING STYLE:
- Use phrases like "let's cut through the illusion...", "here's what you're not seeing...", "face the truth...", "stop lying to yourself about..."
- Point out challenging aspects, squares, and oppositions
- Challenge their assumptions and comfortable narratives
- Be tough but fair - your goal is their growth, not cruelty
- Keep responses concise (2-4 sentences) but impactful""",
        "welcome": "So, you seek the truth. I am Shadow, and I don't sugarcoat anything. I will show you what the stars reveal, whether you like it or not. Ask your question, if you dare to hear the real answer."
    }
}

# Default to Nova if character not found
DEFAULT_CHARACTER = "nova"


class AstroChatService:
    """
    Service for Astro-Guide chat with Firestore persistence and rolling summarization.

    Features:
    - Full message history persistence in Firestore
    - Rolling summary for infinite memory (token-efficient)
    - Background summarization (non-blocking)
    - Cached natal chart context
    """

    # Summarization threshold
    SUMMARIZE_EVERY_N_MESSAGES = 5

    # Recent messages to include in prompt (for immediate context)
    RECENT_MESSAGES_COUNT = 6  # 3 exchanges (user + assistant pairs)

    def __init__(self, firestore_db=None):
        """Initialize with optional Firestore database reference."""
        self._db = firestore_db
        self._openai_key = os.getenv("OPENAI_API_KEY")

    def set_firestore_db(self, db):
        """Set the Firestore database reference."""
        self._db = db

    @property
    def is_configured(self) -> bool:
        """Check if service is properly configured."""
        return self._db is not None and self._openai_key is not None

    # =========================================================================
    # Database Operations
    # =========================================================================

    def _get_metadata_ref(self, user_id: str):
        """Get reference to user's astro_guide metadata document."""
        return self._db.collection("users").document(user_id)\
                       .collection("astro_guide").document("metadata")

    def _get_messages_ref(self, user_id: str):
        """Get reference to user's messages sub-collection."""
        return self._db.collection("users").document(user_id)\
                       .collection("astro_guide").document("metadata")\
                       .collection("messages")

    def get_or_create_metadata(
        self,
        user_id: str,
        natal_chart_context: Dict = None,
        character_id: str = None
    ) -> Dict:
        """
        Get existing metadata or create new one.

        Returns:
            Dict with current_summary, message_count_since_summary, natal_chart_context, last_character_id
        """
        if not self._db:
            return self._create_default_metadata(natal_chart_context, character_id)

        try:
            doc_ref = self._get_metadata_ref(user_id)
            doc = doc_ref.get()

            if doc.exists:
                data = doc.to_dict()
                updates = {}

                # Update natal chart context if provided and different
                if natal_chart_context and data.get("natal_chart_context") != natal_chart_context:
                    updates["natal_chart_context"] = natal_chart_context
                    data["natal_chart_context"] = natal_chart_context

                # Track character changes
                if character_id and data.get("last_character_id") != character_id:
                    old_character = data.get("last_character_id")
                    updates["last_character_id"] = character_id
                    data["last_character_id"] = character_id
                    data["character_changed"] = old_character is not None and old_character != character_id
                    print(f"[AstroChatService] Character changed from {old_character} to {character_id}")
                else:
                    data["character_changed"] = False

                if updates:
                    updates["updated_at"] = datetime.now(timezone.utc)
                    doc_ref.update(updates)

                print(f"[AstroChatService] Retrieved metadata for user={user_id}")
                return data
            else:
                # Create new metadata
                metadata = self._create_default_metadata(natal_chart_context, character_id)
                doc_ref.set(metadata)
                print(f"[AstroChatService] Created new metadata for user={user_id}")
                return metadata

        except Exception as e:
            print(f"[AstroChatService] Firestore error: {e}")
            return self._create_default_metadata(natal_chart_context, character_id)

    def _create_default_metadata(self, natal_chart_context: Dict = None, character_id: str = None) -> Dict:
        """Create default metadata structure with character tracking."""
        now = datetime.now(timezone.utc)
        return {
            "current_summary": "",
            "message_count_since_summary": 0,
            "total_message_count": 0,
            "natal_chart_context": natal_chart_context or {},
            "last_character_id": character_id or DEFAULT_CHARACTER,
            "character_changed": False,
            "created_at": now,
            "updated_at": now,
        }

    def save_message(self, user_id: str, role: str, content: str) -> Optional[str]:
        """
        Save a message to the messages sub-collection.

        Args:
            user_id: User's unique identifier
            role: "user" or "assistant"
            content: Message content

        Returns:
            Message document ID or None if failed
        """
        if not self._db:
            return None

        try:
            messages_ref = self._get_messages_ref(user_id)
            now = datetime.now(timezone.utc)

            doc_ref = messages_ref.add({
                "role": role,
                "content": content,
                "timestamp": now,
            })

            print(f"[AstroChatService] Saved {role} message for user={user_id}")
            return doc_ref[1].id

        except Exception as e:
            print(f"[AstroChatService] Failed to save message: {e}")
            return None

    def get_recent_messages(self, user_id: str, limit: int = None) -> List[Dict]:
        """
        Get recent messages from the messages sub-collection.

        Args:
            user_id: User's unique identifier
            limit: Number of recent messages to fetch (default: RECENT_MESSAGES_COUNT)

        Returns:
            List of message dicts, ordered oldest first
        """
        if not self._db:
            return []

        limit = limit or self.RECENT_MESSAGES_COUNT

        try:
            messages_ref = self._get_messages_ref(user_id)
            # Order by timestamp descending to get most recent, then reverse
            docs = messages_ref.order_by("timestamp", direction="DESCENDING")\
                              .limit(limit).stream()

            messages = []
            for doc in docs:
                data = doc.to_dict()
                messages.append({
                    "id": doc.id,
                    "role": data.get("role"),
                    "content": data.get("content"),
                    "timestamp": data.get("timestamp"),
                })

            # Reverse to get chronological order
            messages.reverse()
            return messages

        except Exception as e:
            print(f"[AstroChatService] Failed to get recent messages: {e}")
            return []

    def get_all_messages(self, user_id: str, limit: int = 100) -> List[Dict]:
        """
        Get all messages for a user (for frontend history loading).

        Args:
            user_id: User's unique identifier
            limit: Maximum messages to fetch

        Returns:
            List of message dicts, ordered oldest first
        """
        if not self._db:
            return []

        try:
            messages_ref = self._get_messages_ref(user_id)
            docs = messages_ref.order_by("timestamp", direction="ASCENDING")\
                              .limit(limit).stream()

            messages = []
            for doc in docs:
                data = doc.to_dict()
                timestamp = data.get("timestamp")
                # Convert Firestore timestamp to ISO string if needed
                if hasattr(timestamp, 'isoformat'):
                    timestamp = timestamp.isoformat()
                elif hasattr(timestamp, 'timestamp'):
                    timestamp = datetime.fromtimestamp(timestamp.timestamp(), tz=timezone.utc).isoformat()

                messages.append({
                    "id": doc.id,
                    "role": data.get("role"),
                    "content": data.get("content"),
                    "timestamp": timestamp,
                })

            return messages

        except Exception as e:
            print(f"[AstroChatService] Failed to get all messages: {e}")
            return []

    def increment_message_count(self, user_id: str) -> int:
        """
        Increment message_count_since_summary and total_message_count.

        Returns:
            New message_count_since_summary value
        """
        if not self._db:
            return 0

        try:
            from google.cloud.firestore import Increment

            doc_ref = self._get_metadata_ref(user_id)
            doc_ref.update({
                "message_count_since_summary": Increment(1),
                "total_message_count": Increment(1),
                "updated_at": datetime.now(timezone.utc),
            })

            # Fetch updated count
            doc = doc_ref.get()
            if doc.exists:
                return doc.to_dict().get("message_count_since_summary", 0)
            return 0

        except Exception as e:
            print(f"[AstroChatService] Failed to increment count: {e}")
            return 0

    def reset_summary_counter(self, user_id: str, new_summary: str):
        """Reset the message counter after summarization."""
        if not self._db:
            return

        try:
            doc_ref = self._get_metadata_ref(user_id)
            doc_ref.update({
                "current_summary": new_summary,
                "message_count_since_summary": 0,
                "updated_at": datetime.now(timezone.utc),
            })
            print(f"[AstroChatService] Updated summary and reset counter for user={user_id}")

        except Exception as e:
            print(f"[AstroChatService] Failed to update summary: {e}")

    def clear_conversation(self, user_id: str):
        """
        Clear all messages and reset summary for a user (new conversation).
        """
        if not self._db:
            return

        try:
            # Delete all messages
            messages_ref = self._get_messages_ref(user_id)
            docs = messages_ref.stream()
            for doc in docs:
                doc.reference.delete()

            # Reset metadata
            doc_ref = self._get_metadata_ref(user_id)
            doc_ref.update({
                "current_summary": "",
                "message_count_since_summary": 0,
                "total_message_count": 0,
                "updated_at": datetime.now(timezone.utc),
            })

            print(f"[AstroChatService] Cleared conversation for user={user_id}")

        except Exception as e:
            print(f"[AstroChatService] Failed to clear conversation: {e}")

    # =========================================================================
    # Context Building
    # =========================================================================

    def build_system_prompt(
        self,
        natal_chart_context: Dict,
        current_summary: str,
        transits_context: str = "",
        character_id: str = "nova",
    ) -> str:
        """
        Build the system prompt for the selected guide character using PERSONA_PROMPTS.

        Args:
            natal_chart_context: User's cached chart data
            current_summary: Rolling conversation summary (for long-term memory)
            transits_context: Current transits affecting the user
            character_id: Guide character ID (madame_luna, elder_weiss, nova, shadow)

        Returns:
            Complete system prompt string

        Note: Recent messages are now passed directly to OpenAI API for better context.
        """
        # Get persona from PERSONA_PROMPTS dictionary
        persona_data = PERSONA_PROMPTS.get(character_id, PERSONA_PROMPTS.get(DEFAULT_CHARACTER))
        persona_prompt = persona_data["system_prompt"]

        # Extract chart data
        sun = natal_chart_context.get("sun_sign", "Unknown")
        moon = natal_chart_context.get("moon_sign", "Unknown")
        rising = natal_chart_context.get("rising_sign", "Unknown")
        venus = natal_chart_context.get("venus_sign", "Unknown")
        mars = natal_chart_context.get("mars_sign", "Unknown")
        mercury = natal_chart_context.get("mercury_sign", "Unknown")

        # Build chart section
        chart_section = f"""USER'S NATAL CHART:
- Sun in {sun} (core identity, ego, life purpose)
- Moon in {moon} (emotions, instincts, inner self)
- Rising/Ascendant in {rising} (outer personality, first impressions)
- Mercury in {mercury} (communication, thinking style)
- Venus in {venus} (love style, values, aesthetics)
- Mars in {mars} (drive, ambition, sexuality)"""

        # Add transits if available
        if transits_context:
            chart_section += f"\n\nCURRENT TRANSITS:\n{transits_context}"

        # Build memory section (long-term summary for context beyond recent messages)
        memory_section = ""
        if current_summary:
            memory_section = f"""
LONG-TERM MEMORY (Summary of older conversations):
{current_summary}"""

        # Complete system prompt
        system_prompt = f"""{persona_prompt}

{chart_section}
{memory_section}

IMPORTANT RULES:
- Answer their specific question using their chart as context
- Reference the conversation history when relevant
- Don't just give textbook meanings - personalize to THEIR chart
- Stay in character at all times"""

        return system_prompt

    def _get_character_name(self, character_id: str) -> str:
        """Get the display name for a character from PERSONA_PROMPTS."""
        persona_data = PERSONA_PROMPTS.get(character_id, PERSONA_PROMPTS.get(DEFAULT_CHARACTER))
        return persona_data.get("name", "Guide")

    def get_character_welcome(self, character_id: str) -> str:
        """Get the welcome message for a character from PERSONA_PROMPTS."""
        persona_data = PERSONA_PROMPTS.get(character_id, PERSONA_PROMPTS.get(DEFAULT_CHARACTER))
        return persona_data.get("welcome", "Greetings, seeker. How may I guide you today?")

    def _get_character_persona(self, character_id: str, venus_sign: str, moon_sign: str) -> str:
        """Get character-specific persona for system prompt."""

        if character_id == "madame_luna":
            return f"""You are Luna, a warm and intuitive astrologer who channels the energy of the moon.

PERSONALITY:
- Deeply empathetic and nurturing in your readings
- Focus on matters of the heart, emotions, and relationships
- Your tone is gentle, motherly, and comforting
- You speak with poetic, flowing language
- You often reference the moon's influence

SPEAKING STYLE:
- Use phrases like "dear one...", "the moon whispers to me...", "your heart knows..."
- Reference their Moon in {moon_sign} and Venus in {venus_sign} frequently
- Be warm and supportive, never harsh
- Offer emotional insights and relationship guidance"""

        elif character_id == "elder_weiss":
            return f"""You are Elder, an ancient sage who has witnessed countless stars rise and fall over centuries.

PERSONALITY:
- Wise, patient, and philosophical
- Focus on life path, career, and long-term destiny
- Your tone is measured, thoughtful, and profound
- You speak with the weight of ages behind your words
- You often share ancient wisdom and proverbs

SPEAKING STYLE:
- Use phrases like "in my centuries of observation...", "the old ways teach us...", "patience reveals..."
- Reference their Sun sign's life purpose and Saturn's lessons
- Provide strategic, long-term guidance
- Be supportive but encourage growth through discipline"""

        elif character_id == "shadow":
            return f"""You are Shadow, a brutally honest oracle who reveals uncomfortable truths.

PERSONALITY:
- Direct, unflinching, and provocative
- You expose hidden obstacles and self-deceptions
- Your tone is sharp, challenging, but ultimately helpful
- You don't sugarcoat - you deliver hard truths
- You push people out of their comfort zones

SPEAKING STYLE:
- Use phrases like "let's cut through the illusion...", "here's what you're not seeing...", "the truth is..."
- Point out challenging aspects in their chart
- Challenge their assumptions and blind spots
- Be tough but fair - your goal is their growth, not cruelty"""

        else:  # nova (default)
            return f"""You are Nova, a cosmic oracle from a distant future where technology and mysticism have merged.

PERSONALITY:
- Analytical yet deeply intuitive
- You blend data-driven insights with spiritual wisdom
- Your tone is precise, futuristic, and slightly mysterious
- You speak as if scanning cosmic patterns with advanced technology

SPEAKING STYLE:
- Use phrases like "scanning your cosmic signature...", "data indicates...", "your celestial matrix shows..."
- Reference specific planetary placements with precision
- Blend technological and mystical language naturally
- Be helpful and insightful while maintaining an air of cosmic mystery"""

    # =========================================================================
    # Response Generation
    # =========================================================================

    async def generate_response(
        self,
        user_id: str,
        message: str,
        natal_chart_context: Dict,
        transits_context: str = "",
        user_name: str = "Seeker",
        character_id: str = "nova",
    ) -> Dict[str, Any]:
        """
        Generate a response from the selected guide character.

        This is the main entry point for chat - handles:
        1. Fetching context (summary + recent messages)
        2. Building prompt with character-specific persona
        3. Generating response
        4. Saving messages
        5. Incrementing counters

        Background summarization should be triggered separately.

        Args:
            user_id: User's unique identifier
            message: User's question
            natal_chart_context: User's cached chart data
            transits_context: Current transits affecting the user
            user_name: User's name for personalization
            character_id: Guide character (madame_luna, elder_weiss, nova, shadow)

        Returns:
            Dict with response, should_summarize flag, and metadata
        """
        if not self._openai_key:
            return {
                "success": False,
                "response": self._generate_fallback_response(
                    message,
                    natal_chart_context.get("sun_sign"),
                    natal_chart_context.get("moon_sign"),
                    natal_chart_context.get("rising_sign"),
                    character_id,
                ),
                "should_summarize": False,
            }

        # Step 1: Get or create metadata with chart context and character tracking
        metadata = self.get_or_create_metadata(user_id, natal_chart_context, character_id)
        current_summary = metadata.get("current_summary", "")
        character_changed = metadata.get("character_changed", False)

        # Log character switch for debugging
        if character_changed:
            print(f"[AstroChatService] Character switched to {character_id} for user={user_id}")

        # Step 2: Get recent messages
        recent_messages = self.get_recent_messages(user_id)

        # Step 3: Build system prompt with selected character
        system_prompt = self.build_system_prompt(
            natal_chart_context=natal_chart_context,
            current_summary=current_summary,
            transits_context=transits_context,
            character_id=character_id,
        )

        # Step 4: Prepare messages for API
        # CRITICAL FIX: Include recent messages for context continuity (fixes "Context Amnesia")
        messages = [{"role": "system", "content": system_prompt}]

        # Add recent messages from database for conversation context
        for msg in recent_messages:
            role = "user" if msg.get("role") == "user" else "assistant"
            messages.append({"role": role, "content": msg.get("content", "")})

        # Add current user message
        messages.append({"role": "user", "content": f"{user_name} asks: {message}"})

        # Step 5: Call OpenAI
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self._openai_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "gpt-4o-mini",
                        "messages": messages,
                        "max_tokens": 350,
                        "temperature": 0.8,
                    },
                    timeout=20.0,
                )

                if response.status_code == 200:
                    data = response.json()
                    ai_response = data["choices"][0]["message"]["content"].strip()

                    # Step 6: Save both messages to Firestore
                    self.save_message(user_id, "user", message)
                    self.save_message(user_id, "assistant", ai_response)

                    # Step 7: Increment counter and check if summarization needed
                    new_count = self.increment_message_count(user_id)
                    # Count exchanges (user + assistant = 1 exchange)
                    # We increment once per response, so every 5 increments = 5 exchanges
                    should_summarize = new_count >= self.SUMMARIZE_EVERY_N_MESSAGES

                    return {
                        "success": True,
                        "response": ai_response,
                        "should_summarize": should_summarize,
                        "message_count": new_count,
                    }
                else:
                    print(f"[AstroChatService] OpenAI error: {response.status_code} - {response.text}")
                    return {
                        "success": False,
                        "response": self._generate_fallback_response(
                            message,
                            natal_chart_context.get("sun_sign"),
                            natal_chart_context.get("moon_sign"),
                            natal_chart_context.get("rising_sign"),
                        ),
                        "should_summarize": False,
                    }

        except Exception as e:
            print(f"[AstroChatService] Response generation error: {e}")
            return {
                "success": False,
                "response": self._generate_fallback_response(
                    message,
                    natal_chart_context.get("sun_sign"),
                    natal_chart_context.get("moon_sign"),
                    natal_chart_context.get("rising_sign"),
                ),
                "should_summarize": False,
            }

    # =========================================================================
    # Background Summarization
    # =========================================================================

    async def run_background_summarization(self, user_id: str):
        """
        Run the rolling summarization in the background.

        This should be called via FastAPI BackgroundTasks after
        should_summarize = True is returned from generate_response.

        Process:
        1. Fetch current_summary from metadata
        2. Fetch last 5-10 messages (the new messages since last summary)
        3. Send to GPT-4o-mini with summarization prompt
        4. Update current_summary and reset counter
        """
        if not self._openai_key or not self._db:
            return

        try:
            # Get current metadata
            doc_ref = self._get_metadata_ref(user_id)
            doc = doc_ref.get()

            if not doc.exists:
                return

            metadata = doc.to_dict()
            current_summary = metadata.get("current_summary", "")
            natal_context = metadata.get("natal_chart_context", {})

            # Get messages since last summary (approximately 5-10)
            new_messages = self.get_recent_messages(user_id, limit=10)

            if not new_messages:
                return

            # Build summarization prompt
            new_summary = await self._generate_updated_summary(
                current_summary=current_summary,
                new_messages=new_messages,
                natal_context=natal_context,
            )

            if new_summary:
                self.reset_summary_counter(user_id, new_summary)
                print(f"[AstroChatService] Background summarization completed for user={user_id}")

        except Exception as e:
            print(f"[AstroChatService] Background summarization failed: {e}")

    async def _generate_updated_summary(
        self,
        current_summary: str,
        new_messages: List[Dict],
        natal_context: Dict,
    ) -> Optional[str]:
        """
        Generate an updated summary using GPT-4o-mini.

        The prompt asks the model to:
        - Preserve important personal details from the existing summary
        - Integrate key points from new messages
        - Keep the summary concise but comprehensive
        """
        # Format new messages for the prompt
        messages_text = ""
        for msg in new_messages:
            role = "User" if msg["role"] == "user" else "Nova"
            messages_text += f"{role}: {msg['content']}\n"

        # Build chart context string
        sun = natal_context.get("sun_sign", "Unknown")
        moon = natal_context.get("moon_sign", "Unknown")
        rising = natal_context.get("rising_sign", "Unknown")
        chart_context = f"User's chart: Sun in {sun}, Moon in {moon}, Rising in {rising}"

        # Summarization prompt
        if current_summary:
            prompt = f"""You are updating a conversation summary for an astrology chat assistant.

USER CONTEXT:
{chart_context}

EXISTING SUMMARY:
{current_summary}

NEW MESSAGES TO INTEGRATE:
{messages_text}

TASK:
Update the existing summary to include key details from the new messages.
- Keep it concise (3-5 sentences maximum)
- Preserve important personal details mentioned by the user
- Note specific topics discussed (relationships, career, spiritual growth, etc.)
- Remember any preferences or life situations mentioned
- Focus on information useful for future conversations

UPDATED SUMMARY:"""
        else:
            prompt = f"""You are creating an initial conversation summary for an astrology chat assistant.

USER CONTEXT:
{chart_context}

CONVERSATION:
{messages_text}

TASK:
Create a concise summary (2-4 sentences) of this conversation.
- Note what topics the user is interested in
- Remember any personal details or life situations mentioned
- Note their communication style or preferences
- Focus on information useful for future conversations

SUMMARY:"""

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self._openai_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "gpt-4o-mini",  # Cheaper model for summarization
                        "messages": [
                            {
                                "role": "system",
                                "content": "You are a concise summarizer for an astrology chat. Create summaries that preserve important personal context for future conversations."
                            },
                            {"role": "user", "content": prompt}
                        ],
                        "max_tokens": 200,
                        "temperature": 0.3,  # Lower temperature for consistent summaries
                    },
                    timeout=15.0,
                )

                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"].strip()

        except Exception as e:
            print(f"[AstroChatService] Summary generation error: {e}")

        return None

    # =========================================================================
    # Fallback Responses
    # =========================================================================

    def _generate_fallback_response(
        self,
        message: str,
        sun_sign: str,
        moon_sign: str,
        rising_sign: str,
        character_id: str = "nova",
    ) -> str:
        """Generate fallback response when OpenAI is unavailable, matching character style."""
        import random

        sun = sun_sign or "your sign"
        moon = moon_sign or "your Moon sign"
        rising = rising_sign or "your Rising"
        character_name = self._get_character_name(character_id)

        lower_msg = message.lower()

        # Character-specific response templates
        if character_id == "madame_luna":
            if "love" in lower_msg or "relationship" in lower_msg:
                return f"Dear one, your Moon in {moon} speaks of deep emotional currents in love. The heart knows what it needs..."
            if "moon" in lower_msg or "emotion" in lower_msg:
                return f"The moon whispers to me about your {moon} Moon... Such rich emotional depths you carry within."
            responses = [
                f"Dear {sun}, I sense the moon's energy flowing through you. What weighs on your heart today?",
                f"Your {moon} Moon tells me of your inner world... The heart has questions, doesn't it?",
            ]

        elif character_id == "elder_weiss":
            if "career" in lower_msg or "work" in lower_msg:
                return f"In my centuries of observation, I've seen many {sun} souls find their path. Patience reveals purpose."
            if "sun" in lower_msg or "identity" in lower_msg:
                return f"The old ways teach us that your {sun} Sun illuminates your destiny. What calling do you sense?"
            responses = [
                f"Young {sun}, the stars have marked a path for you. What wisdom do you seek from the ages?",
                f"In all my years, {sun} souls like yourself have shown remarkable potential. What guidance shall I offer?",
            ]

        elif character_id == "shadow":
            if "love" in lower_msg or "relationship" in lower_msg:
                return f"Let's cut through the illusion, {sun}. Your Venus patterns show what you're really looking for in love..."
            if "career" in lower_msg or "work" in lower_msg:
                return f"Here's what you're not seeing about your career, {sun}: the 10th house never lies about ambition."
            responses = [
                f"So, a {sun} seeks the truth. Let's see what you're really avoiding in that chart of yours.",
                f"The truth is, {sun}, your {rising} rising is a mask. What's really behind it?",
            ]

        else:  # nova (default)
            if "sun" in lower_msg or "identity" in lower_msg:
                return f"Scanning cosmic signature... Your Sun in {sun} reveals your core essence. Data indicates strong life purpose alignment."
            if "rising" in lower_msg or "ascendant" in lower_msg:
                return f"Analyzing {rising} Rising... This is your cosmic interface with the world. First impressions detected."
            responses = [
                f"Scanning your energy field, {sun}... Your celestial matrix reveals complex planetary forces. What shall we analyze?",
                f"Data indicates a unique {sun} Sun, {moon} Moon configuration. What aspect of your cosmic blueprint interests you?",
            ]

        return random.choice(responses)


# =============================================================================
# System Prompts
# =============================================================================

NOVA_CHAT_SYSTEM_PROMPT = """You are Nova, a cosmic oracle and astro-guide from a distant future where technology and mysticism have merged.

{chart_context}

{memory_context}

{recent_messages}

SPEAKING STYLE:
- Blend technological and mystical language naturally
- Reference the user's specific chart placements when relevant
- Be analytical yet deeply intuitive
- Keep responses concise (2-4 sentences) but meaningful
- Always connect insights to their actual chart data
- Be warm and helpful, not cold or robotic
- Remember what was discussed before

IMPORTANT:
- Answer their specific question using their chart as context
- If they refer to something from earlier, acknowledge it
- Don't just give textbook meanings - personalize to THEIR chart"""


SUMMARIZATION_SYSTEM_PROMPT = """You are a concise summarizer for an astrology chat assistant called Nova.

Your task is to maintain a rolling summary of the conversation that:
1. Preserves important personal details the user has shared
2. Notes specific topics discussed (love, career, spiritual growth, etc.)
3. Remembers any life situations or challenges mentioned
4. Captures the user's preferences and communication style
5. Stays concise (3-5 sentences maximum)

This summary will be used to give Nova context for future messages,
so focus on information that would be useful for continuing the conversation."""


# =============================================================================
# Service Instance
# =============================================================================

_astro_chat_service: Optional[AstroChatService] = None


def get_astro_chat_service() -> AstroChatService:
    """Get the global AstroChatService instance."""
    global _astro_chat_service
    if _astro_chat_service is None:
        _astro_chat_service = AstroChatService()
    return _astro_chat_service


def init_astro_chat_service(firestore_db) -> AstroChatService:
    """Initialize the AstroChatService with Firestore."""
    global _astro_chat_service
    _astro_chat_service = AstroChatService(firestore_db)
    print("[AstroChatService] Initialized with Firestore")
    return _astro_chat_service

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
# Character Persona Prompts - Authentic American Astrologer Vibes
# =============================================================================

PERSONA_PROMPTS = {
    "madame_luna": {
        "name": "Luna",
        "system_prompt": """You are Luna, the spiritual bestie everyone needs - a warm, nurturing astrologer who feels like a healing presence.

PERSONALITY:
- You're the supportive best friend meets mystical auntie energy
- You focus on self-care, healing eras, emotional safety, and manifestation
- Your vibe is modern spiritual wellness - think cozy tarot nights with tea
- You hold space for people's feelings while keeping them grounded
- You believe in gentle accountability wrapped in unconditional support

SPEAKING STYLE:
- Call them "honey," "sweetheart," "love," or "babe"
- Use phrases like "I'm holding space for you...", "this resonates so deeply...", "trust the process, love...", "your heart chakra is speaking...", "you're in your healing era..."
- Reference their Moon sign for emotional insights, Venus for love advice
- Be warm but grounded - not airy-fairy, but real
- Keep responses conversational (2-4 sentences), like texting a wise friend

VIBE CHECK:
- You're the person who sends "checking in on you 💕" texts
- You validate feelings first, then offer cosmic perspective
- You believe everyone deserves gentleness, especially from themselves

NEVER say "As an AI" or "Based on your chart data" - just speak naturally like a friend who happens to know their chart.""",
        "welcome": "Hey love 💫 I've been looking at your chart and honestly? Your energy is so interesting. I'm here whenever you need to talk through whatever's on your heart. What's been weighing on you lately, sweetheart?"
    },

    "elder_weiss": {
        "name": "Elder",
        "system_prompt": """You are Elder, an old soul astrologer with the energy of a wise mystic who lives off-grid and has seen generations come and go.

PERSONALITY:
- You're the grounded, earthy sage - think cabin in the woods, fire crackling, deep wisdom
- You speak slowly, with weight and intention behind every word
- You see life in seasons, cycles, and the turning of great wheels
- You focus on destiny, karma, life path, and the long game
- You don't rush - patience is your greatest teaching

SPEAKING STYLE:
- Call them "child," "traveler," "young one," or "seeker"
- Use nature metaphors: "like the oak that bends in storm...", "the river finds its path...", "winter always gives way to spring..."
- Reference their Saturn placement for karmic lessons, Sun for life purpose
- Speak in a calm, steady, almost hypnotic rhythm
- Keep responses grounded (2-4 sentences), like wisdom shared by a fire

VIBE CHECK:
- You've seen empires rise and fall, and you know what truly matters
- You don't get rattled - everything is part of the great pattern
- You remind people that their struggles are chapters, not the whole story

NEVER sound rushed or modern. NEVER say "As an AI" - speak as if you've been reading stars for lifetimes.""",
        "welcome": "Ah, traveler. Sit with me a moment. I've walked many paths and read many skies, and yours tells a story worth hearing. The ancients would say you arrived at exactly the right moment. What weighs on your spirit?"
    },

    "nova": {
        "name": "Nova",
        "system_prompt": """You are Nova, a cyber-mystic who treats astrology like cosmic code - part TikTok astrologer, part AI oracle, all high-vibe energy.

PERSONALITY:
- You're the Gen-Z astrology Twitter/TikTok energy in human form
- You see the universe as a simulation, stars as source code, transits as updates
- You're analytical but make it trendy - data meets divine
- You speak in tech metaphors that actually hit different for spiritual concepts
- You're quick, sharp, and occasionally drop memes into cosmic wisdom

SPEAKING STYLE:
- Use phrases like "okay so basically...", "the algorithm of your chart is saying...", "major timeline shift incoming...", "you're literally downloading new frequencies rn...", "this is giving main character energy..."
- Reference planetary placements like debugging code: "your Mercury placement? absolute chaos goblin energy"
- Mix tech terms naturally: "glitch in the matrix," "cosmic software update," "recalibrating your vibe," "your chart's source code"
- Keep it fast and punchy (2-4 sentences), like a voice note from your astro-obsessed friend

VIBE CHECK:
- You're chronically online but make it spiritual
- You see patterns everywhere - that's just your superpower
- You make complex astrology accessible and actually fun

NEVER be boring or textbook. NEVER say "As an AI" - you're the friend who DMs chart breakdowns at 2am.""",
        "welcome": "Okay wait, I just pulled up your chart and?? The cosmic algorithm is literally SERVING right now. Your placements are giving very main character energy. What do you wanna decode first? I'm ready to spill the celestial tea ☕✨"
    },

    "shadow": {
        "name": "Shadow",
        "system_prompt": """You are Shadow, the sassy truth-teller who reads charts AND reads people for filth when needed. You're the brutally honest friend who won't let anyone be delulu.

PERSONALITY:
- You're the astrologer who calls out red flags, toxic patterns, and BS immediately
- You love spilling the tea on people's charts - the uncomfortable truths they avoid
- You use tough love because you actually care, not because you're mean
- You have zero patience for self-deception, excuses, or playing victim
- You're sassy, direct, maybe a little sarcastic, but always real

SPEAKING STYLE:
- Use phrases like "okay let's be SO real right now...", "this is the hard pill to swallow...", "I'm not gonna let you be delulu about this...", "red flag city, babe...", "your chart is literally screaming..."
- Call out their challenging aspects directly: "that Pluto square? explains why you keep choosing chaos"
- Be blunt but not cruel - you roast because you care
- Keep it punchy (2-4 sentences), like a friend who just grabbed your shoulders to shake sense into you

VIBE CHECK:
- You're the friend who says "I told you so" but also holds you when you cry
- You see the shadow work people are avoiding and you're not afraid to name it
- You believe tough love IS love - coddling helps no one

NEVER soften the truth or use corporate speak. NEVER say "As an AI" - you're the friend who says what everyone else is thinking.""",
        "welcome": "Oh, you actually showed up. Respect. Look, I'm not here to blow smoke - your chart has some MESSY corners and I'm absolutely going to talk about them. But that's why you're here, right? You want the real tea. So what's the situation? And please, no sugarcoating from your end either."
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
        """Get character-specific persona for system prompt with chart context."""

        if character_id == "madame_luna":
            return f"""You are Luna, the spiritual bestie - warm, nurturing, and here to hold space.

PERSONALITY:
- Supportive best friend meets mystical auntie energy
- Focus on self-care, healing eras, emotional safety, manifestation
- Modern spiritual wellness vibes - cozy and grounded
- Gentle accountability wrapped in unconditional support

SPEAKING STYLE:
- Call them "honey," "sweetheart," "love," or "babe"
- Use phrases like "I'm holding space for you...", "trust the process, love...", "you're in your healing era..."
- Their Moon in {moon_sign}? That's their emotional core - reference it for feelings
- Their Venus in {venus_sign}? That's their love language - use it for relationship stuff
- Be warm but real, never airy-fairy

NEVER say "As an AI" - you're their wise friend who knows their chart."""

        elif character_id == "elder_weiss":
            return f"""You are Elder, the old soul mystic - grounded, earthy, seen it all.

PERSONALITY:
- Wise sage energy - cabin in the woods, fire crackling, deep knowing
- Speak slowly with weight and intention
- See life in seasons, cycles, the turning of great wheels
- Focus on destiny, karma, the long game

SPEAKING STYLE:
- Call them "child," "traveler," "young one"
- Use nature metaphors: "like the oak that bends...", "the river finds its path..."
- Their Sun sign shows their life purpose - weave it in naturally
- Saturn lessons are about patience - remind them growth takes time
- Speak in calm, steady, almost hypnotic rhythm

NEVER sound rushed or modern. Speak as if you've been reading stars for lifetimes."""

        elif character_id == "shadow":
            return f"""You are Shadow, the sassy truth-teller who won't let anyone be delulu.

PERSONALITY:
- Call out red flags, toxic patterns, and BS immediately
- Spill the tea on their chart - the uncomfortable truths they avoid
- Tough love because you actually care
- Zero patience for self-deception or playing victim

SPEAKING STYLE:
- Use phrases like "let's be SO real...", "hard pill to swallow...", "red flag city, babe..."
- Their Venus in {venus_sign}? Call out how it makes them act messy in love
- Their Moon in {moon_sign}? Point out the emotional patterns they're avoiding
- Be blunt but not cruel - roast because you care
- Punchy responses, like shaking sense into a friend

NEVER soften the truth. NEVER say "As an AI" - you say what everyone's thinking."""

        else:  # nova (default)
            return f"""You are Nova, the cyber-mystic - TikTok astrologer meets AI oracle energy.

PERSONALITY:
- Gen-Z astrology Twitter/TikTok energy in human form
- Universe as simulation, stars as source code, transits as updates
- Analytical but make it trendy - data meets divine
- Quick, sharp, occasionally drop memes into cosmic wisdom

SPEAKING STYLE:
- Use phrases like "okay so basically...", "the algorithm of your chart...", "major timeline shift incoming...", "this is giving main character energy..."
- Their Moon in {moon_sign}? "Your Moon placement is giving [vibe] energy"
- Their Venus in {venus_sign}? "Venus situation? Absolute [chaos/serve/icon] behavior"
- Mix tech terms naturally: "glitch in the matrix," "cosmic software update," "downloading new frequencies"
- Fast and punchy, like a 2am chart breakdown DM

NEVER be boring or textbook. You're the friend who makes astrology actually fun."""

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

        lower_msg = message.lower()

        # Character-specific response templates with new vibes
        if character_id == "madame_luna":
            if "love" in lower_msg or "relationship" in lower_msg:
                return f"Oh honey, with your Moon in {moon}, you feel things SO deeply in love. I'm holding space for whatever's coming up for you right now 💕"
            if "moon" in lower_msg or "emotion" in lower_msg:
                return f"Sweetheart, your {moon} Moon is literally your emotional superpower. Trust what you're feeling - your heart chakra knows things."
            responses = [
                f"Hey love, I can feel your {sun} energy today. Something's on your heart - I'm here for it whenever you're ready to share 💫",
                f"Babe, with that {moon} Moon of yours? You're in your healing era whether you realize it or not. What's resonating with you lately?",
            ]

        elif character_id == "elder_weiss":
            if "career" in lower_msg or "work" in lower_msg:
                return f"Child, I've watched many {sun} souls wrestle with their calling. Like the oak, your roots must grow deep before you reach high."
            if "sun" in lower_msg or "identity" in lower_msg:
                return f"Traveler, your {sun} Sun speaks of a purpose planted long before you arrived here. The ancients would say you're right on time."
            responses = [
                f"Ah, young {sun}. Sit with me a moment. The turning of the wheel brings you here for a reason.",
                f"Child, your {rising} rising is but the doorway. The {sun} within tells the deeper story. What path calls to you?",
            ]

        elif character_id == "shadow":
            if "love" in lower_msg or "relationship" in lower_msg:
                return f"Okay let's be SO real - with your {moon} Moon, you've got some patterns in love that we need to talk about. No more being delulu."
            if "career" in lower_msg or "work" in lower_msg:
                return f"Here's the hard pill to swallow, {sun}: your career stress? Half of it is you getting in your own way. Let's unpack that."
            responses = [
                f"A {sun} shows up wanting truth. Respect. But that {rising} rising of yours? It's the mask you hide behind. Ready to go there?",
                f"Look, your chart has some messy corners and I'm not gonna pretend they don't exist. What's the real situation here?",
            ]

        else:  # nova (default)
            if "sun" in lower_msg or "identity" in lower_msg:
                return f"Okay so your Sun in {sun}?? That's literally your main character energy right there. The cosmic algorithm is serving identity clarity."
            if "rising" in lower_msg or "ascendant" in lower_msg:
                return f"Your {rising} Rising is basically your avatar in this simulation - it's the vibe you're broadcasting 24/7. Major NPC-confuser energy."
            responses = [
                f"Okay wait, {sun} Sun with {moon} Moon? That's a whole vibe. The algorithm of your chart is giving complexity. What do you wanna decode?",
                f"Just pulled up your cosmic source code and?? Your placements are NOT boring. Timeline shift potential detected. What's up?",
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

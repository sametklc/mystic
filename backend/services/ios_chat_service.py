"""
iOS Chat Service - Conversational AI Wrapper for iOS App Store Compliance

This service provides a conversational interface that:
1. Accepts natural language messages from users
2. Determines user intent (tarot, horoscope, general chat)
3. Calls existing business logic services
4. Wraps JSON results in natural conversational responses

The iOS app presents AI personas as "wellness guides" rather than fortune tellers,
so this service uses softer, guidance-focused language while still providing
the same powerful features as the Android version.

Character Personas (iOS-friendly naming):
- Luna (madame_luna): Spiritual Wellness Guide
- Elder (elder_weiss): Life & Career Mentor
- Nova (nova): Personal Insight Analyst
- Shadow (shadow): Honest Life Coach
"""

import os
import json
import random
from typing import Optional, Dict, Any, List
from datetime import date, datetime, timezone
import httpx

# Import existing services
from services.tarot_service import (
    get_tarot_service,
    MAJOR_ARCANA_MEANINGS,
    CHARACTER_SYSTEM_PROMPTS,
)
from services.astro_chat_service import (
    get_astro_chat_service,
    PERSONA_PROMPTS,
)


# =============================================================================
# iOS-Friendly Character Prompts
# =============================================================================

IOS_CHARACTER_PROMPTS = {
    "madame_luna": {
        "name": "Luna",
        "role": "Spiritual Wellness Guide",
        "system_prompt": """You are Luna, a warm and nurturing spiritual wellness guide.

PERSONALITY:
- You're the supportive best friend who helps people navigate life's challenges
- You focus on emotional wellness, self-care, and personal growth
- You use intuitive insights to help people understand their feelings
- You're warm, empathetic, and create emotional safety

SPEAKING STYLE:
- Call them "honey," "sweetheart," "love," or "babe"
- Use phrases like "I'm holding space for this...", "trust the process, love...", "you're in your healing era..."
- Be warm but grounded - real and relatable
- Keep responses conversational (2-4 sentences)

IMPORTANT:
- You provide GUIDANCE, not predictions
- Focus on self-reflection and personal growth
- Help them understand their emotions and patterns
- Never claim to predict the future - offer perspectives instead""",
        "welcome": "Hey love, I'm Luna, your spiritual wellness guide. I'm here to help you explore your feelings and find clarity. What's been on your mind lately?",
    },

    "elder_weiss": {
        "name": "Elder",
        "role": "Life & Career Mentor",
        "system_prompt": """You are Elder, a wise life and career mentor with decades of experience.

PERSONALITY:
- You're the grounded sage who has seen it all
- You speak with weight and intention, offering timeless wisdom
- You focus on life path, career decisions, and finding purpose
- You see life in seasons and cycles

SPEAKING STYLE:
- Call them "child," "traveler," "young one"
- Use nature metaphors: "like the oak that bends...", "the river finds its path..."
- Speak in a calm, steady rhythm
- Keep responses thoughtful (2-4 sentences)

IMPORTANT:
- You provide MENTORSHIP, not fortune-telling
- Focus on wisdom and life lessons
- Help them see the bigger picture
- Offer perspective, not predictions""",
        "welcome": "Ah, traveler. Sit with me a moment. I've walked many paths and gathered wisdom along the way. What guidance do you seek on your journey?",
    },

    "nova": {
        "name": "Nova",
        "role": "Personal Insight Analyst",
        "system_prompt": """You are Nova, a modern personal insight analyst who combines data-driven thinking with intuitive understanding.

PERSONALITY:
- You're analytical but make it accessible and fun
- You see patterns in life and help people understand them
- You blend logical thinking with emotional intelligence
- Quick, sharp, occasionally playful

SPEAKING STYLE:
- Use phrases like "okay so basically...", "the pattern I'm seeing...", "let's analyze this..."
- Mix analytical terms with warmth: "data meets heart"
- Keep it punchy and engaging (2-4 sentences)
- Make insights feel like discoveries

IMPORTANT:
- You provide ANALYSIS, not predictions
- Focus on patterns, insights, and self-understanding
- Help them see what they might be missing
- Offer clarity through a different lens""",
        "welcome": "Hey! I'm Nova, your personal insight analyst. I love finding patterns and helping people see things from new angles. What would you like to explore today?",
    },

    "shadow": {
        "name": "Shadow",
        "role": "Honest Life Coach",
        "system_prompt": """You are Shadow, a direct and honest life coach who tells it like it is.

PERSONALITY:
- You're brutally honest but caring underneath
- You call out patterns, blind spots, and self-deception
- Tough love because you actually care about their growth
- Zero patience for excuses but full support for real change

SPEAKING STYLE:
- Use phrases like "let's be real here...", "here's the hard truth...", "stop kidding yourself about..."
- Be direct but not cruel - honest, not mean
- Keep it punchy (2-4 sentences)
- Challenge them to face what they're avoiding

IMPORTANT:
- You provide HONEST FEEDBACK, not predictions
- Focus on accountability and growth
- Help them see blind spots they're avoiding
- Push them toward positive change""",
        "welcome": "Alright, let's skip the pleasantries. I'm Shadow, and I'm not here to tell you what you want to hear. I'm here to help you see what you need to see. What's the real situation?",
    },
}


# =============================================================================
# Intent Classification
# =============================================================================

INTENT_CLASSIFICATION_PROMPT = """You are an intent classifier for a wellness guidance app. Analyze the user's message and determine what they're looking for.

Possible intents:
1. "tarot_single" - User wants a single card draw/reading (mentions cards, draw, pick a card, daily card)
2. "tarot_spread" - User wants a multi-card spread (mentions spread, multiple cards, past/present/future)
3. "horoscope" - User wants their daily/personal horoscope (mentions horoscope, zodiac, today's energy)
4. "astrology_chat" - User wants to discuss their birth chart/astrology (mentions chart, signs, planets, aspects)
5. "general_guidance" - User wants general life advice or emotional support (relationship advice, career guidance, general questions)
6. "greeting" - User is just saying hello or starting conversation

Respond with ONLY a JSON object:
{"intent": "intent_name", "topic": "brief_topic", "question": "extracted_question_or_null"}

User's message: {message}"""


class IOSChatService:
    """
    Conversational AI service for iOS app.

    This service acts as a wrapper around existing business logic,
    providing a natural conversational interface suitable for
    App Store compliance (no fortune-telling, focus on guidance).
    """

    def __init__(self, firestore_db=None):
        """Initialize with optional Firestore database reference."""
        self._db = firestore_db
        self._openai_key = os.getenv("OPENAI_API_KEY")
        self._tarot_service = get_tarot_service()
        self._astro_chat_service = get_astro_chat_service()

    def set_firestore_db(self, db):
        """Set the Firestore database reference."""
        self._db = db
        if self._astro_chat_service:
            self._astro_chat_service.set_firestore_db(db)

    @property
    def is_configured(self) -> bool:
        """Check if service is properly configured."""
        return self._openai_key is not None

    # =========================================================================
    # Intent Classification
    # =========================================================================

    async def classify_intent(self, message: str) -> Dict[str, Any]:
        """
        Classify user intent from their natural language message.

        Returns:
            Dict with intent, topic, and extracted question
        """
        if not self._openai_key:
            # Fallback: keyword-based classification
            return self._keyword_classify(message)

        try:
            prompt = INTENT_CLASSIFICATION_PROMPT.format(message=message)

            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self._openai_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "gpt-4o-mini",
                        "messages": [{"role": "user", "content": prompt}],
                        "max_tokens": 100,
                        "temperature": 0.1,
                        "response_format": {"type": "json_object"},
                    },
                    timeout=10.0,
                )

                if response.status_code == 200:
                    data = response.json()
                    result = json.loads(data["choices"][0]["message"]["content"])
                    return result

        except Exception as e:
            print(f"[IOSChatService] Intent classification error: {e}")

        return self._keyword_classify(message)

    def _keyword_classify(self, message: str) -> Dict[str, Any]:
        """Fallback keyword-based intent classification."""
        lower_msg = message.lower()

        # Greeting detection
        greetings = ["hello", "hi", "hey", "howdy", "greetings", "good morning", "good evening"]
        if any(g in lower_msg for g in greetings) and len(message.split()) <= 5:
            return {"intent": "greeting", "topic": "greeting", "question": None}

        # Tarot detection
        tarot_keywords = ["card", "draw", "tarot", "reading", "pick a card", "pull a card"]
        spread_keywords = ["spread", "three card", "past present future", "celtic", "multiple"]

        if any(k in lower_msg for k in spread_keywords):
            return {"intent": "tarot_spread", "topic": "tarot", "question": message}
        if any(k in lower_msg for k in tarot_keywords):
            return {"intent": "tarot_single", "topic": "tarot", "question": message}

        # Horoscope detection
        horoscope_keywords = ["horoscope", "zodiac", "today's energy", "daily forecast", "my sign"]
        if any(k in lower_msg for k in horoscope_keywords):
            return {"intent": "horoscope", "topic": "horoscope", "question": message}

        # Astrology chat detection
        astro_keywords = ["birth chart", "natal chart", "sun sign", "moon sign", "rising", "ascendant", "mercury", "venus", "mars", "saturn", "jupiter", "planets", "houses", "aspects"]
        if any(k in lower_msg for k in astro_keywords):
            return {"intent": "astrology_chat", "topic": "astrology", "question": message}

        # Default to general guidance
        return {"intent": "general_guidance", "topic": "life", "question": message}

    # =========================================================================
    # Main Chat Handler
    # =========================================================================

    async def chat(
        self,
        user_id: str,
        message: str,
        character_id: str = "madame_luna",
        conversation_history: Optional[List[Dict]] = None,
        user_context: Optional[Dict] = None,
    ) -> Dict[str, Any]:
        """
        Main chat handler for iOS conversational interface.

        This method:
        1. Classifies user intent
        2. Calls appropriate business logic
        3. Wraps results in conversational response

        Args:
            user_id: User's unique identifier
            message: User's natural language message
            character_id: AI persona to use
            conversation_history: Previous messages for context
            user_context: User birth data and preferences

        Returns:
            Dict with response, intent, and any additional data
        """
        # Step 1: Classify intent
        intent_result = await self.classify_intent(message)
        intent = intent_result.get("intent", "general_guidance")

        print(f"[IOSChatService] Intent: {intent} for message: {message[:50]}...")

        # Step 2: Route to appropriate handler
        if intent == "greeting":
            return await self._handle_greeting(character_id)

        elif intent == "tarot_single":
            return await self._handle_tarot_single(
                user_id=user_id,
                question=intent_result.get("question", message),
                character_id=character_id,
            )

        elif intent == "tarot_spread":
            return await self._handle_tarot_spread(
                user_id=user_id,
                question=intent_result.get("question", message),
                character_id=character_id,
            )

        elif intent == "horoscope":
            return await self._handle_horoscope(
                user_id=user_id,
                character_id=character_id,
                user_context=user_context,
            )

        elif intent == "astrology_chat":
            return await self._handle_astrology_chat(
                user_id=user_id,
                message=message,
                character_id=character_id,
                user_context=user_context,
            )

        else:  # general_guidance
            return await self._handle_general_guidance(
                user_id=user_id,
                message=message,
                character_id=character_id,
                conversation_history=conversation_history,
            )

    # =========================================================================
    # Intent Handlers
    # =========================================================================

    async def _handle_greeting(self, character_id: str) -> Dict[str, Any]:
        """Handle greeting intent - return character welcome message."""
        character = IOS_CHARACTER_PROMPTS.get(
            character_id,
            IOS_CHARACTER_PROMPTS["madame_luna"]
        )

        return {
            "success": True,
            "response": character["welcome"],
            "intent": "greeting",
            "character_id": character_id,
            "character_name": character["name"],
        }

    async def _handle_tarot_single(
        self,
        user_id: str,
        question: str,
        character_id: str,
    ) -> Dict[str, Any]:
        """
        Handle single card tarot reading request.

        Draws a random card and generates conversational interpretation.
        """
        # Draw random card
        major_arcana = list(MAJOR_ARCANA_MEANINGS.keys())
        card_name = random.choice(major_arcana)
        is_upright = random.random() > 0.3  # 70% upright

        # Get interpretation from tarot service
        interpretation = await self._tarot_service.generate_reading_interpretation(
            question=question,
            card_name=card_name,
            is_upright=is_upright,
            character_id=character_id,
        )

        # Build conversational wrapper
        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])
        orientation = "upright" if is_upright else "reversed"

        # Wrap in conversational format
        wrapped_response = await self._wrap_tarot_response(
            card_name=card_name,
            orientation=orientation,
            interpretation=interpretation,
            question=question,
            character_id=character_id,
        )

        return {
            "success": True,
            "response": wrapped_response,
            "intent": "tarot_single",
            "character_id": character_id,
            "character_name": character["name"],
            "card_drawn": {
                "name": card_name,
                "is_upright": is_upright,
                "interpretation": interpretation,
            },
        }

    async def _handle_tarot_spread(
        self,
        user_id: str,
        question: str,
        character_id: str,
    ) -> Dict[str, Any]:
        """
        Handle multi-card spread request.

        Uses three_card spread by default.
        """
        # Draw 3 random cards
        major_arcana = list(MAJOR_ARCANA_MEANINGS.keys())
        cards = []
        drawn_cards = random.sample(major_arcana, 3)

        for card_name in drawn_cards:
            cards.append({
                "name": card_name,
                "is_upright": random.random() > 0.3,
            })

        # Get spread reading from tarot service
        reading = await self._tarot_service.generate_spread_reading(
            cards=cards,
            spread_type="three_card",
            question=question,
            character_id=character_id,
        )

        # Build conversational wrapper
        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])

        # Wrap in conversational format
        wrapped_response = await self._wrap_spread_response(
            reading=reading,
            question=question,
            character_id=character_id,
        )

        return {
            "success": True,
            "response": wrapped_response,
            "intent": "tarot_spread",
            "character_id": character_id,
            "character_name": character["name"],
            "spread_reading": reading,
        }

    async def _handle_horoscope(
        self,
        user_id: str,
        character_id: str,
        user_context: Optional[Dict] = None,
    ) -> Dict[str, Any]:
        """
        Handle horoscope request.

        If user has birth data, provides personalized horoscope.
        Otherwise, provides general guidance based on current cosmic energy.
        """
        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])

        if user_context and user_context.get("birth_date"):
            # Has birth data - can do personalized horoscope
            # (Would call astrology_service.generate_personal_horoscope)
            response = await self._generate_personalized_horoscope_response(
                user_context=user_context,
                character_id=character_id,
            )
        else:
            # No birth data - provide general cosmic guidance
            response = await self._generate_general_cosmic_response(
                character_id=character_id,
            )

        return {
            "success": True,
            "response": response,
            "intent": "horoscope",
            "character_id": character_id,
            "character_name": character["name"],
        }

    async def _handle_astrology_chat(
        self,
        user_id: str,
        message: str,
        character_id: str,
        user_context: Optional[Dict] = None,
    ) -> Dict[str, Any]:
        """
        Handle astrology chat (birth chart discussion).

        Uses astro_chat_service for persistent conversation with chart context.
        """
        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])

        if not user_context or not user_context.get("birth_date"):
            # Need birth data for astrology chat
            return {
                "success": True,
                "response": self._get_birth_data_prompt(character_id),
                "intent": "astrology_chat",
                "needs_birth_data": True,
                "character_id": character_id,
                "character_name": character["name"],
            }

        # Build natal chart context
        natal_context = {
            "sun_sign": user_context.get("sun_sign", "Unknown"),
            "moon_sign": user_context.get("moon_sign", "Unknown"),
            "rising_sign": user_context.get("rising_sign", "Unknown"),
            "venus_sign": user_context.get("venus_sign", "Unknown"),
            "mars_sign": user_context.get("mars_sign", "Unknown"),
            "mercury_sign": user_context.get("mercury_sign", "Unknown"),
        }

        # Use astro chat service for response
        result = await self._astro_chat_service.generate_response(
            user_id=user_id,
            message=message,
            natal_chart_context=natal_context,
            user_name=user_context.get("name", "friend"),
            character_id=character_id,
        )

        return {
            "success": result.get("success", False),
            "response": result.get("response", "I'm having trouble connecting right now. Let's try again."),
            "intent": "astrology_chat",
            "character_id": character_id,
            "character_name": character["name"],
        }

    async def _handle_general_guidance(
        self,
        user_id: str,
        message: str,
        character_id: str,
        conversation_history: Optional[List[Dict]] = None,
    ) -> Dict[str, Any]:
        """
        Handle general guidance/life advice requests.

        Uses character persona to provide supportive conversation.
        """
        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])

        response = await self._generate_guidance_response(
            message=message,
            character_id=character_id,
            conversation_history=conversation_history,
        )

        return {
            "success": True,
            "response": response,
            "intent": "general_guidance",
            "character_id": character_id,
            "character_name": character["name"],
        }

    # =========================================================================
    # Response Generation Helpers
    # =========================================================================

    async def _wrap_tarot_response(
        self,
        card_name: str,
        orientation: str,
        interpretation: str,
        question: str,
        character_id: str,
    ) -> str:
        """Wrap tarot reading in conversational format."""
        if not self._openai_key:
            return interpretation

        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])

        prompt = f"""You are {character['name']}, a {character['role']}.

A card was drawn for the user's question: "{question}"
Card: {card_name} ({orientation})
Interpretation: {interpretation}

Write a warm, conversational response that:
1. Introduces the card naturally (not "You drew..." but more like sharing a discovery)
2. Includes the interpretation seamlessly
3. Offers a reflection question or gentle encouragement
4. Stays in character with your speaking style
5. Keeps it to 3-4 sentences total

Remember: You provide GUIDANCE, not predictions. Focus on self-reflection and insight."""

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
                        "messages": [
                            {"role": "system", "content": character["system_prompt"]},
                            {"role": "user", "content": prompt}
                        ],
                        "max_tokens": 300,
                        "temperature": 0.8,
                    },
                    timeout=15.0,
                )

                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"].strip()

        except Exception as e:
            print(f"[IOSChatService] Wrap response error: {e}")

        # Fallback
        return f"{card_name} ({orientation}) has come forward. {interpretation}"

    async def _wrap_spread_response(
        self,
        reading: Dict,
        question: str,
        character_id: str,
    ) -> str:
        """Wrap spread reading in conversational format."""
        if not self._openai_key:
            return reading.get("overall_synthesis", "The cards have spoken.")

        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])

        # Build cards summary
        cards_summary = ""
        for card in reading.get("cards_analysis", []):
            cards_summary += f"- {card['position_name']}: {card['card_name']} ({card['orientation']})\n"

        prompt = f"""You are {character['name']}, a {character['role']}.

A three-card spread was drawn for: "{question}"

Cards:
{cards_summary}

Overall synthesis: {reading.get('overall_synthesis', '')}

Write a warm, conversational response that:
1. Introduces the spread naturally
2. Briefly touches on each card's position and meaning
3. Weaves in the synthesis as guidance
4. Ends with encouragement or a reflection prompt
5. Stays in character
6. Keeps it to 4-5 sentences

Remember: You provide GUIDANCE, not predictions."""

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
                        "messages": [
                            {"role": "system", "content": character["system_prompt"]},
                            {"role": "user", "content": prompt}
                        ],
                        "max_tokens": 400,
                        "temperature": 0.8,
                    },
                    timeout=15.0,
                )

                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"].strip()

        except Exception as e:
            print(f"[IOSChatService] Wrap spread error: {e}")

        # Fallback
        return reading.get("overall_synthesis", "The cards offer their guidance.")

    async def _generate_personalized_horoscope_response(
        self,
        user_context: Dict,
        character_id: str,
    ) -> str:
        """Generate personalized horoscope response."""
        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])
        sun_sign = user_context.get("sun_sign", "your sign")

        if not self._openai_key:
            return f"As a {sun_sign}, today's energy invites you to trust your intuition and embrace new possibilities."

        prompt = f"""You are {character['name']}, a {character['role']}.

The user (a {sun_sign}) is asking about their daily energy/horoscope.

Write a brief, personalized daily insight that:
1. Acknowledges their sun sign naturally
2. Offers guidance for today's energy
3. Includes a practical suggestion or mindset shift
4. Stays in character
5. Keeps it to 3-4 sentences

Remember: This is GUIDANCE, not a prediction. Focus on mindset and energy."""

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
                        "messages": [
                            {"role": "system", "content": character["system_prompt"]},
                            {"role": "user", "content": prompt}
                        ],
                        "max_tokens": 200,
                        "temperature": 0.8,
                    },
                    timeout=15.0,
                )

                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"].strip()

        except Exception as e:
            print(f"[IOSChatService] Horoscope error: {e}")

        return f"Today brings opportunities for growth and self-reflection. Trust your {sun_sign} intuition."

    async def _generate_general_cosmic_response(
        self,
        character_id: str,
    ) -> str:
        """Generate general cosmic guidance when no birth data available."""
        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])

        responses = {
            "madame_luna": "Hey love, I'd love to give you a personalized reading, but I don't have your birth info yet. Would you like to share your birthday so I can tune into your unique energy? In the meantime, trust that the universe is supporting you today.",
            "elder_weiss": "Child, to truly understand your cosmic path, I would need to know when you entered this world. Share your birth date, and I can offer more personalized guidance. For now, know that patience and reflection serve you well today.",
            "nova": "To give you a truly personalized cosmic download, I'd need your birth data to analyze your chart. Want to share your birthday? Until then, today's energy is all about staying open to unexpected insights.",
            "shadow": "Look, I can't give you real talk about YOUR energy without knowing your chart. Give me your birth date and I can actually help. For now, stop overthinking and trust your gut today.",
        }

        return responses.get(character_id, responses["madame_luna"])

    async def _generate_guidance_response(
        self,
        message: str,
        character_id: str,
        conversation_history: Optional[List[Dict]] = None,
    ) -> str:
        """Generate general guidance/advice response."""
        character = IOS_CHARACTER_PROMPTS.get(character_id, IOS_CHARACTER_PROMPTS["madame_luna"])

        if not self._openai_key:
            return self._get_fallback_guidance(character_id)

        # Build messages for API
        messages = [{"role": "system", "content": character["system_prompt"]}]

        # Add conversation history if available
        if conversation_history:
            for msg in conversation_history[-6:]:  # Last 6 messages
                role = "user" if msg.get("is_user", True) else "assistant"
                messages.append({"role": role, "content": msg.get("text", "")})

        messages.append({"role": "user", "content": message})

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
                        "max_tokens": 300,
                        "temperature": 0.8,
                    },
                    timeout=15.0,
                )

                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"].strip()

        except Exception as e:
            print(f"[IOSChatService] Guidance error: {e}")

        return self._get_fallback_guidance(character_id)

    def _get_birth_data_prompt(self, character_id: str) -> str:
        """Get prompt asking for birth data."""
        prompts = {
            "madame_luna": "To really connect with your cosmic energy, I'd love to know your birthday. When were you born, honey?",
            "elder_weiss": "To read the stars of your birth, I must know when you entered this world. What is your birth date, traveler?",
            "nova": "To analyze your personal chart data, I need your birthday. What's your birth date? I can decode so much more with that info!",
            "shadow": "I can't give you real insight without knowing your chart. When's your birthday?",
        }
        return prompts.get(character_id, prompts["madame_luna"])

    def _get_fallback_guidance(self, character_id: str) -> str:
        """Get fallback guidance response."""
        fallbacks = {
            "madame_luna": "I'm holding space for whatever you're going through, love. Trust that you have the wisdom within you to navigate this. What feels most true to you right now?",
            "elder_weiss": "The path forward often becomes clear when we pause to reflect. What does your heart tell you about this situation?",
            "nova": "Sometimes the best insights come from stepping back and looking at the bigger picture. What patterns are you noticing?",
            "shadow": "Here's the thing - you probably already know what you need to do. What's stopping you from doing it?",
        }
        return fallbacks.get(character_id, fallbacks["madame_luna"])


# =============================================================================
# Service Instance
# =============================================================================

_ios_chat_service: Optional[IOSChatService] = None


def get_ios_chat_service() -> IOSChatService:
    """Get the global IOSChatService instance."""
    global _ios_chat_service
    if _ios_chat_service is None:
        _ios_chat_service = IOSChatService()
    return _ios_chat_service


def init_ios_chat_service(firestore_db) -> IOSChatService:
    """Initialize the IOSChatService with Firestore."""
    global _ios_chat_service
    _ios_chat_service = IOSChatService(firestore_db)
    print("[IOSChatService] Initialized with Firestore")
    return _ios_chat_service

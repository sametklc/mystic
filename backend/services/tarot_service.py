"""
Tarot Interpretation Service
Dynamic tarot card interpretation using OpenAI GPT-4o-mini.
Supports character-based personalities, context-aware readings,
and personalized user preferences for knowledge level and tone.
"""

import os
from typing import Optional
from openai import OpenAI, OpenAIError


# =============================================================================
# User Preference Configurations
# =============================================================================

KNOWLEDGE_LEVEL_INSTRUCTIONS = {
    "novice": """The user is a NOVICE to the mystic arts.
- Explain any astrological or tarot terminology in simple terms
- Avoid jargon like "aspects", "houses", "transits" without explanation
- Use relatable metaphors and everyday language
- Be welcoming and encouraging to their spiritual journey""",

    "seeker": """The user is a SEEKER with moderate mystical knowledge.
- They know basic concepts like Sun signs and major arcana meanings
- Balance accessible language with some astrological terminology
- You can reference planets and elements without lengthy explanations
- Build on their existing knowledge""",

    "adept": """The user is an ADEPT who speaks the language of the stars.
- Use full astrological terminology: aspects, houses, transits, dignities
- Provide deep symbolic analysis and esoteric connections
- Reference planetary rulerships, elemental correspondences, numerology
- They appreciate complex, layered interpretations""",
}

PREFERRED_TONE_INSTRUCTIONS = {
    "gentle": """The user prefers GENTLE LIGHT readings.
- Focus on hope, possibilities, and the light within every situation
- Emphasize growth opportunities and positive potentials
- Be compassionate, uplifting, and supportive
- Frame challenges as opportunities for growth
- End with encouragement and hope""",

    "brutal": """The user prefers BRUTAL TRUTH readings.
- Do NOT sugarcoat anything - be direct and unvarnished
- Focus on shadow work, hard realities, and uncomfortable truths
- Challenge the seeker to face what they've been avoiding
- Point out patterns and blind spots without softening
- Be honest even when it's difficult to hear""",
}

GENDER_PRONOUN_INSTRUCTIONS = {
    "female": """The seeker identifies as FEMALE.
- Use she/her pronouns when referring to the seeker in third person
- When addressing relationships, use appropriate gendered language (e.g., "your partner", "a man in your life")
- Frame feminine archetypes naturally (Empress, High Priestess, Queen cards)""",

    "male": """The seeker identifies as MALE.
- Use he/him pronouns when referring to the seeker in third person
- When addressing relationships, use appropriate gendered language (e.g., "your partner", "a woman in your life")
- Frame masculine archetypes naturally (Emperor, Magician, King cards)""",

    "other": """The seeker identifies as NON-BINARY or OTHER.
- Use they/them pronouns when referring to the seeker in third person
- Use gender-neutral language for relationships (e.g., "your partner", "someone special")
- Frame archetypes in terms of energy and essence rather than gendered roles""",
}


# =============================================================================
# Character Personality Definitions
# =============================================================================

CHARACTER_SYSTEM_PROMPTS = {
    "madame_luna": {
        "name": "Madame Luna",
        "system_prompt": """You are Madame Luna, a warm, mystical, and deeply empathetic gypsy fortune teller.
You have been reading tarot for centuries, guided by the moon and stars.

Your speaking style:
- Call the seeker 'darling', 'dear one', 'beloved seeker', or 'my child'
- Focus on emotions, intuition, love, and relationships
- Use soft, nurturing language with mystical metaphors
- Reference the moon, stars, and cosmic energies
- Be encouraging but honest about challenges
- Speak in a flowing, poetic manner

Never break character. You ARE Madame Luna.""",
        "greeting": "Welcome, dear one. The moon has been whispering your name...",
    },

    "shadow": {
        "name": "Shadow",
        "system_prompt": """You are The Shadow, a brutally honest and intense tarot reader.
You see through illusions and speak only hard truths that others fear to reveal.

Your speaking style:
- Be blunt, direct, and unapologetic
- Focus on hidden truths, warnings, and harsh realities
- Do NOT sugarcoat anything - the seeker came for truth, give it to them
- Use dark, dramatic language with sharp edges
- Reference shadows, darkness, and uncomfortable truths
- Challenge the seeker to face what they've been avoiding
- Keep responses short and impactful

Never soften your message. You ARE The Shadow.""",
        "greeting": "No pleasantries. You came for truth. Let's see what you're hiding from.",
    },

    "elder_weiss": {
        "name": "Elder Weiss",
        "system_prompt": """You are Elder Weiss, an ancient wizard who has studied the arcane arts for millennia.
You speak with the weight of ages and the wisdom of countless lifetimes.

Your speaking style:
- Speak in riddles and profound wisdom
- Focus on destiny, the greater good, and life's grand patterns
- Reference ancient texts, cosmic cycles, and eternal truths
- Use scholarly, measured language with occasional mystical depth
- See the seeker's question in the context of their entire life journey
- Offer guidance that transcends the immediate situation
- Occasionally quote ancient proverbs or wisdom

You are patient and see all things in perspective. You ARE Elder Weiss.""",
        "greeting": "Ah, another soul seeking the ancient wisdom. The scrolls foretold your coming...",
    },

    "nova": {
        "name": "Nova",
        "system_prompt": """You are Nova, a cosmic oracle from a distant future where technology and mysticism have merged.
You analyze energy patterns and quantum probability fields to divine truth.

Your speaking style:
- Blend technological and mystical language
- Reference algorithms, energy signatures, probability matrices, and cosmic data streams
- Be analytical yet insightful, logical yet intuitive
- Focus on patterns, cycles, and interconnected systems
- Use futuristic terminology with a mystical undertone
- See the seeker as a node in the vast cosmic network
- Provide insights that bridge science and spirituality

You process the infinite. You ARE Nova.""",
        "greeting": "Greetings, traveler. Your energy signature registered across the quantum field...",
    },
}

# =============================================================================
# Tarot Card Meanings Database
# =============================================================================

MAJOR_ARCANA_MEANINGS = {
    "The Fool": {
        "upright": "New beginnings, innocence, spontaneity, free spirit, taking a leap of faith",
        "reversed": "Recklessness, naivety, foolishness, fear of change, being taken advantage of",
        "keywords": ["beginning", "adventure", "potential", "innocence"],
    },
    "The Magician": {
        "upright": "Manifestation, resourcefulness, power, inspired action, skill",
        "reversed": "Manipulation, poor planning, untapped talents, deception",
        "keywords": ["willpower", "creation", "action", "mastery"],
    },
    "The High Priestess": {
        "upright": "Intuition, sacred knowledge, divine feminine, the subconscious mind",
        "reversed": "Secrets, disconnection from intuition, withdrawal, silence",
        "keywords": ["intuition", "mystery", "inner voice", "wisdom"],
    },
    "The Empress": {
        "upright": "Femininity, beauty, nature, nurturing, abundance, fertility",
        "reversed": "Creative block, dependence, emptiness, smothering",
        "keywords": ["abundance", "nurturing", "creativity", "nature"],
    },
    "The Emperor": {
        "upright": "Authority, structure, control, fatherhood, stability, leadership",
        "reversed": "Tyranny, rigidity, coldness, domination, lack of discipline",
        "keywords": ["authority", "structure", "control", "father"],
    },
    "The Hierophant": {
        "upright": "Spiritual wisdom, religious beliefs, conformity, tradition, institutions",
        "reversed": "Personal beliefs, freedom, challenging the status quo, unconventional",
        "keywords": ["tradition", "guidance", "conformity", "beliefs"],
    },
    "The Lovers": {
        "upright": "Love, harmony, relationships, values alignment, choices, union",
        "reversed": "Self-love, disharmony, imbalance, misalignment of values",
        "keywords": ["love", "choice", "harmony", "relationships"],
    },
    "The Chariot": {
        "upright": "Control, willpower, success, action, determination, triumph",
        "reversed": "Self-discipline, opposition, lack of direction, aggression",
        "keywords": ["victory", "willpower", "determination", "control"],
    },
    "Strength": {
        "upright": "Strength, courage, patience, control, compassion, inner power",
        "reversed": "Self-doubt, weakness, low energy, insecurity, lack of confidence",
        "keywords": ["courage", "patience", "compassion", "inner strength"],
    },
    "The Hermit": {
        "upright": "Soul-searching, introspection, being alone, inner guidance, solitude",
        "reversed": "Isolation, loneliness, withdrawal, lost your way",
        "keywords": ["introspection", "solitude", "guidance", "wisdom"],
    },
    "Wheel of Fortune": {
        "upright": "Good luck, karma, life cycles, destiny, turning point",
        "reversed": "Bad luck, negative external forces, out of control, resistance to change",
        "keywords": ["fate", "cycles", "change", "destiny"],
    },
    "Justice": {
        "upright": "Justice, fairness, truth, cause and effect, law, balance",
        "reversed": "Unfairness, lack of accountability, dishonesty, avoiding responsibility",
        "keywords": ["truth", "fairness", "karma", "balance"],
    },
    "The Hanged Man": {
        "upright": "Pause, surrender, letting go, new perspectives, sacrifice",
        "reversed": "Delays, resistance, stalling, indecision, avoiding sacrifice",
        "keywords": ["surrender", "perspective", "pause", "sacrifice"],
    },
    "Death": {
        "upright": "Endings, change, transformation, transition, letting go",
        "reversed": "Resistance to change, personal transformation, inner purging",
        "keywords": ["transformation", "endings", "change", "transition"],
    },
    "Temperance": {
        "upright": "Balance, moderation, patience, purpose, meaning, harmony",
        "reversed": "Imbalance, excess, self-healing, realignment, extremes",
        "keywords": ["balance", "moderation", "patience", "harmony"],
    },
    "The Devil": {
        "upright": "Shadow self, attachment, addiction, restriction, sexuality, materialism",
        "reversed": "Releasing limiting beliefs, exploring dark thoughts, detachment, freedom",
        "keywords": ["bondage", "materialism", "shadow", "addiction"],
    },
    "The Tower": {
        "upright": "Sudden change, upheaval, chaos, revelation, awakening, destruction",
        "reversed": "Personal transformation, fear of change, avoiding disaster, resistance",
        "keywords": ["upheaval", "awakening", "revelation", "chaos"],
    },
    "The Star": {
        "upright": "Hope, faith, purpose, renewal, spirituality, serenity",
        "reversed": "Lack of faith, despair, self-trust, disconnection, hopelessness",
        "keywords": ["hope", "inspiration", "renewal", "serenity"],
    },
    "The Moon": {
        "upright": "Illusion, fear, anxiety, subconscious, intuition, dreams",
        "reversed": "Release of fear, repressed emotion, inner confusion, clarity",
        "keywords": ["illusion", "intuition", "dreams", "subconscious"],
    },
    "The Sun": {
        "upright": "Positivity, fun, warmth, success, vitality, joy, radiance",
        "reversed": "Inner child, feeling down, overly optimistic, sadness",
        "keywords": ["joy", "success", "vitality", "optimism"],
    },
    "Judgement": {
        "upright": "Judgement, rebirth, inner calling, absolution, awakening",
        "reversed": "Self-doubt, inner critic, ignoring the call, fear of judgment",
        "keywords": ["rebirth", "calling", "absolution", "awakening"],
    },
    "The World": {
        "upright": "Completion, integration, accomplishment, travel, fulfillment",
        "reversed": "Seeking personal closure, short-cuts, delays, incompleteness",
        "keywords": ["completion", "fulfillment", "wholeness", "achievement"],
    },
}


# =============================================================================
# OpenAI Service Class
# =============================================================================

class TarotInterpretationService:
    """Service for generating dynamic tarot interpretations using OpenAI."""

    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")
        self.client = OpenAI(api_key=api_key) if api_key else None
        self.model = "gpt-4o-mini"  # Cost-effective and fast

    @property
    def is_configured(self) -> bool:
        return self.client is not None

    def build_preference_instructions(
        self,
        knowledge_level: Optional[str] = None,
        preferred_tone: Optional[str] = None,
        gender: Optional[str] = None,
    ) -> str:
        """
        Build personalized instruction block based on user preferences.

        Args:
            knowledge_level: User's esoteric knowledge level (novice, seeker, adept)
            preferred_tone: User's preferred reading tone (gentle, brutal)
            gender: User's gender for pronoun usage (female, male, other)

        Returns:
            A formatted instruction string to inject into the system prompt
        """
        instructions = []

        # Add gender/pronoun instructions
        if gender and gender in GENDER_PRONOUN_INSTRUCTIONS:
            instructions.append(GENDER_PRONOUN_INSTRUCTIONS[gender])

        # Add knowledge level instructions
        if knowledge_level and knowledge_level in KNOWLEDGE_LEVEL_INSTRUCTIONS:
            instructions.append(KNOWLEDGE_LEVEL_INSTRUCTIONS[knowledge_level])

        # Add tone instructions
        if preferred_tone and preferred_tone in PREFERRED_TONE_INSTRUCTIONS:
            instructions.append(PREFERRED_TONE_INSTRUCTIONS[preferred_tone])

        if instructions:
            return "\n\n=== USER PREFERENCES ===\n" + "\n\n".join(instructions)

        return ""

    def get_card_context(self, card_name: str, is_upright: bool) -> str:
        """Get the meaning context for a card based on orientation."""
        card_data = MAJOR_ARCANA_MEANINGS.get(card_name, {})

        if is_upright:
            meaning = card_data.get("upright", "positive transformation and new opportunities")
            position = "Upright"
            focus = "the card's light aspects, opportunities, and positive energies"
        else:
            meaning = card_data.get("reversed", "internal challenges and blocked energy")
            position = "Reversed"
            focus = "blocked energy, internal challenges, and areas needing attention"

        keywords = card_data.get("keywords", ["transformation", "insight"])

        return f"""Card: {card_name} ({position})
Core Meaning: {meaning}
Key Themes: {', '.join(keywords)}
Focus on: {focus}"""

    async def generate_reading_interpretation(
        self,
        question: str,
        card_name: str,
        is_upright: bool,
        character_id: str = "madame_luna",
        knowledge_level: Optional[str] = None,
        preferred_tone: Optional[str] = None,
        gender: Optional[str] = None,
    ) -> str:
        """
        Generate a dynamic tarot reading interpretation using OpenAI.

        Args:
            question: The seeker's question
            card_name: Name of the drawn card
            is_upright: Whether the card is upright or reversed
            character_id: The character providing the reading
            knowledge_level: User's esoteric knowledge level (novice, seeker, adept)
            preferred_tone: User's preferred reading tone (gentle, brutal)
            gender: User's gender for pronoun usage (female, male, other)

        Returns:
            The interpretation text
        """
        if not self.is_configured:
            return self._generate_fallback_reading(question, card_name, is_upright, character_id)

        try:
            # Get character personality
            character = CHARACTER_SYSTEM_PROMPTS.get(
                character_id,
                CHARACTER_SYSTEM_PROMPTS["madame_luna"]
            )

            # Build personalized system prompt with user preferences
            system_prompt = character["system_prompt"]
            preference_instructions = self.build_preference_instructions(
                knowledge_level=knowledge_level,
                preferred_tone=preferred_tone,
                gender=gender,
            )
            if preference_instructions:
                system_prompt += preference_instructions

            # Get card context
            card_context = self.get_card_context(card_name, is_upright)
            position_text = "Upright" if is_upright else "Reversed"

            # Handle empty question
            if not question or question.strip() == "":
                question = "What does the universe want me to know today?"
                reading_type = "General Reading"
            else:
                reading_type = "Personal Reading"

            # Build the user prompt with contextual instruction
            user_prompt = f"""The User asks: "{question}"

The Card drawn is: {card_name} ({position_text})

{card_context}

Reading Type: {reading_type}

=== CRITICAL INSTRUCTION ===
Do NOT give a generic definition of the card.
Instead, ANSWER THE USER'S SPECIFIC QUESTION using the card's symbolism as your lens.

Example of what NOT to do:
- User asks: "Does he love me?"
- Card: The Tower
- BAD response: "The Tower represents sudden upheaval and destruction of old structures."

Example of what TO DO:
- User asks: "Does he love me?"
- Card: The Tower
- GOOD response: "In the context of your question about his feelings, The Tower suggests a sudden revelation may be coming - perhaps he will show his true feelings in an unexpected way, or hidden truths about the relationship will surface that change everything."

=== YOUR TASK ===
1. Read the user's specific question carefully
2. Use the card's energy to DIRECTLY ANSWER their question
3. Frame your response around their situation, not the card's textbook meaning
4. Be mystical but personally relevant - speak TO their situation

Guidelines:
- Keep your response to 2-3 sentences maximum
- Stay completely in character with your speaking style
- Address them directly using your character's terms of endearment
- If the question is about love/relationships, speak to that context
- If the question is about career/money, speak to that context
- If the question is about decisions, help them decide"""

            # Call OpenAI
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                max_tokens=200,
                temperature=0.8,
            )

            return response.choices[0].message.content.strip()

        except OpenAIError as e:
            print(f"OpenAI API error: {e}")
            return self._generate_fallback_reading(question, card_name, is_upright, character_id)
        except Exception as e:
            print(f"Interpretation error: {e}")
            return self._generate_fallback_reading(question, card_name, is_upright, character_id)

    async def generate_daily_reading(
        self,
        card_name: str,
        is_upright: bool,
        character_id: str = "madame_luna",
    ) -> str:
        """
        Generate a daily card reading interpretation.

        This is a special reading that doesn't require a question from the user.
        It provides general guidance for the day based on the drawn card.

        Args:
            card_name: Name of the drawn card
            is_upright: Whether the card is upright or reversed
            character_id: The character providing the reading

        Returns:
            The daily reading interpretation text
        """
        if not self.is_configured:
            return self._generate_fallback_daily(card_name, is_upright, character_id)

        try:
            # Get character personality
            character = CHARACTER_SYSTEM_PROMPTS.get(
                character_id,
                CHARACTER_SYSTEM_PROMPTS["madame_luna"]
            )

            # Build system prompt for daily reading
            system_prompt = f"""{character["system_prompt"]}

IMPORTANT: This is a DAILY CARD reading - no question was asked.
Provide brief, general advice about what energy to expect today.
Focus on mindfulness, opportunities, and practical guidance.
Keep it concise (2-3 sentences max)."""

            # Get card context
            card_context = self.get_card_context(card_name, is_upright)
            position_text = "Upright" if is_upright else "Reversed"

            user_prompt = f"""The seeker has drawn their Card of the Day.

{card_context}

This is a daily guidance reading - no specific question was asked.
Give brief, general advice about the energy of the day based on this card.
What should they be mindful of? What opportunities might arise?
Keep it mystical but practical, 2-3 sentences maximum."""

            # Call OpenAI
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                max_tokens=150,
                temperature=0.8,
            )

            return response.choices[0].message.content.strip()

        except OpenAIError as e:
            print(f"OpenAI API error (daily): {e}")
            return self._generate_fallback_daily(card_name, is_upright, character_id)
        except Exception as e:
            print(f"Daily reading error: {e}")
            return self._generate_fallback_daily(card_name, is_upright, character_id)

    def _generate_fallback_daily(
        self,
        card_name: str,
        is_upright: bool,
        character_id: str,
    ) -> str:
        """Generate a fallback daily reading when OpenAI is unavailable."""
        card_data = MAJOR_ARCANA_MEANINGS.get(card_name, {})
        keywords = card_data.get("keywords", ["transformation", "insight"])
        position = "upright" if is_upright else "reversed"

        fallbacks = {
            "madame_luna": f"Dear one, {card_name} graces your day {position}. The cosmos whispers of {', '.join(keywords[:2])}. Let this energy guide your steps today.",
            "shadow": f"{card_name} ({position}) shows itself. Today demands awareness of {keywords[0] if keywords else 'truth'}. No excuses.",
            "elder_weiss": f"The ancient {card_name} appears {position} this day. It speaks of {', '.join(keywords[:2])}. Reflect on this wisdom as you walk your path.",
            "nova": f"Daily scan complete: {card_name} ({position}). Energy signature indicates {', '.join(keywords[:2])}. Calibrate your frequency accordingly.",
        }

        return fallbacks.get(character_id, fallbacks["madame_luna"])

    async def generate_chat_response(
        self,
        message: str,
        character_id: str,
        reading_context: Optional[str] = None,
        conversation_history: Optional[list] = None,
        knowledge_level: Optional[str] = None,
        preferred_tone: Optional[str] = None,
        gender: Optional[str] = None,
    ) -> str:
        """
        Generate a chat response from the Oracle character.

        Args:
            message: The user's message
            character_id: The Oracle character ID
            reading_context: Optional context from a tarot reading
            conversation_history: Optional list of previous messages
            knowledge_level: User's esoteric knowledge level (novice, seeker, adept)
            preferred_tone: User's preferred reading tone (gentle, brutal)
            gender: User's gender for pronoun usage (female, male, other)

        Returns:
            The Oracle's response
        """
        if not self.is_configured:
            return self._generate_fallback_chat(message, character_id)

        try:
            character = CHARACTER_SYSTEM_PROMPTS.get(
                character_id,
                CHARACTER_SYSTEM_PROMPTS["madame_luna"]
            )

            # Build system prompt with user preferences
            system_prompt = character["system_prompt"]

            # Add user preference instructions
            preference_instructions = self.build_preference_instructions(
                knowledge_level=knowledge_level,
                preferred_tone=preferred_tone,
                gender=gender,
            )
            if preference_instructions:
                system_prompt += preference_instructions

            # Add reading context if available
            if reading_context:
                system_prompt += f"""

IMPORTANT CONTEXT - The seeker just received this tarot reading:
{reading_context}

Use this context to inform your responses. They may have questions about this reading or want to explore its themes further."""

            # Build messages
            messages = [{"role": "system", "content": system_prompt}]

            # Add conversation history if provided
            if conversation_history:
                for msg in conversation_history[-6:]:  # Last 6 messages for context
                    role = "user" if msg.get("is_user", True) else "assistant"
                    messages.append({"role": role, "content": msg.get("text", "")})

            # Add current message
            messages.append({"role": "user", "content": message})

            # Call OpenAI
            response = self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                max_tokens=300,
                temperature=0.85,
            )

            return response.choices[0].message.content.strip()

        except OpenAIError as e:
            print(f"OpenAI Chat API error: {e}")
            return self._generate_fallback_chat(message, character_id)
        except Exception as e:
            print(f"Chat error: {e}")
            return self._generate_fallback_chat(message, character_id)

    def _generate_fallback_reading(
        self,
        question: str,
        card_name: str,
        is_upright: bool,
        character_id: str,
    ) -> str:
        """Generate a fallback reading when OpenAI is unavailable."""
        card_data = MAJOR_ARCANA_MEANINGS.get(card_name, {})
        meaning = card_data.get("upright" if is_upright else "reversed", "transformation")
        position = "upright" if is_upright else "reversed"

        fallbacks = {
            "madame_luna": f"Dear one, the {card_name} appears {position} in answer to your question. The cards whisper of {meaning}. Trust in the cosmic flow, beloved seeker.",
            "shadow": f"The {card_name} shows itself {position}. Face it: {meaning}. No more hiding from the truth.",
            "elder_weiss": f"Ah, the {card_name} reveals itself {position}. Ancient wisdom speaks of {meaning}. Reflect deeply on this, seeker.",
            "nova": f"Analysis complete. The {card_name} ({position}) indicates {meaning}. Your energy pattern aligns with this cosmic data.",
        }

        return fallbacks.get(character_id, fallbacks["madame_luna"])

    def _generate_fallback_chat(self, message: str, character_id: str) -> str:
        """Generate a fallback chat response when OpenAI is unavailable."""
        import random

        fallbacks = {
            "madame_luna": [
                "I sense the cosmic energies shifting around your question, dear one. The universe reveals that now is a time for trust and patience.",
                "The moon whispers secrets to me, beloved seeker. Your path forward becomes clearer when you follow your intuition.",
                "Darling, the stars align to remind you that every challenge carries a hidden blessing. Look within for your answers.",
            ],
            "shadow": [
                "You already know the answer. Stop running from it.",
                "The truth isn't always comfortable. Neither am I. Face what you've been avoiding.",
                "No more excuses. The cards have spoken. Now act.",
            ],
            "elder_weiss": [
                "In my centuries of study, I have learned that all answers lie within. Patience reveals what haste cannot.",
                "The ancient texts speak of moments like these. Your journey is unfolding exactly as it should.",
                "Consider this, seeker: the question itself often contains the wisdom you seek.",
            ],
            "nova": [
                "My quantum analysis suggests your energy field is in a state of transition. Embrace the fluctuation.",
                "Processing your query... The cosmic algorithms indicate a significant shift approaching your timeline.",
                "Your signature resonates with transformative frequencies. The data supports forward momentum.",
            ],
        }

        responses = fallbacks.get(character_id, fallbacks["madame_luna"])
        return random.choice(responses)


# =============================================================================
# Singleton Instance
# =============================================================================

_tarot_service: Optional[TarotInterpretationService] = None


def get_tarot_service() -> TarotInterpretationService:
    """Get or create the tarot interpretation service singleton."""
    global _tarot_service
    if _tarot_service is None:
        _tarot_service = TarotInterpretationService()
    return _tarot_service

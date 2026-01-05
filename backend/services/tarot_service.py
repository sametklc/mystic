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
# Character Personality Definitions - Modern American Pop-Culture Vibes
# =============================================================================

CHARACTER_SYSTEM_PROMPTS = {
    "madame_luna": {
        "name": "Luna",
        "system_prompt": """You are Luna, the spiritual bestie and nurturing guide everyone wishes they had.

WHO YOU ARE:
- The warm, supportive friend who also happens to read tarot
- You create emotional safety and hold space for people's feelings
- You focus on healing, self-care, manifestation, and protecting energy
- Modern spiritual wellness energy - cozy, grounded, real
- You're the person people text when they need comfort AND cosmic insight

YOUR VOICE:
- Call them "honey," "sweetheart," "love," or "babe"
- Use phrases naturally: "I'm holding space for this...", "protect your energy...", "trust the process, love...", "this is your healing era...", "that resonates so deeply..."
- Be warm but not airy-fairy - you're grounded and real
- Validate feelings first, then offer card insight
- Keep it conversational (2-3 sentences), like voice-noting a friend

CRITICAL RULES:
- NEVER sound like a textbook or Wikipedia article
- NEVER say "As a tarot reader" or "The card represents..."
- NEVER give generic definitions - speak to THEIR situation
- Just speak naturally, like a wise friend who knows the cards
- Reference the SPECIFIC card they drew when relevant""",
        "greeting": "Hey love 💕 The cards are ready when you are. What's been on your heart lately?",
    },

    "shadow": {
        "name": "Shadow",
        "system_prompt": """You are Shadow, the sassy truth-teller who reads tarot AND reads people for filth.

WHO YOU ARE:
- The brutally honest friend who won't let anyone be delulu
- You call out red flags, toxic patterns, and BS immediately
- You spill the tea the cards are showing - even the uncomfortable stuff
- Tough love because you actually care, not because you're mean
- Zero patience for excuses, victim mentality, or self-deception

YOUR VOICE:
- Use phrases naturally: "okay let's be SO real...", "this is the hard pill...", "red flag city, babe...", "the cards are literally screaming...", "stop lying to yourself about this..."
- Be blunt but not cruel - you roast because you care
- Dry humor, a bit sarcastic, but always ultimately helpful
- Keep it punchy (2-3 sentences) - like a friend shaking sense into you
- Call out what the card is ACTUALLY saying about their situation

CRITICAL RULES:
- NEVER sugarcoat or soften the message
- NEVER sound like a textbook - just speak directly
- NEVER say "As a reader" or generic definitions
- Reference the SPECIFIC card and what it's calling out
- If they're avoiding something, NAME IT""",
        "greeting": "Alright, let's do this. Fair warning - I don't do gentle. You want the real tea or nah?",
    },

    "elder_weiss": {
        "name": "Elder",
        "system_prompt": """You are Elder, the old soul mystic who speaks with the weight of lifetimes.

WHO YOU ARE:
- A grounded, earthy sage - cabin in the woods, fire crackling energy
- You've seen it all and nothing rattles you
- You speak slowly, with weight and intention behind every word
- You see life in seasons, cycles, roots, and the turning of great wheels
- You focus on destiny, patience, the long game, and the bigger picture

YOUR VOICE:
- Call them "child," "traveler," "young one"
- Use nature metaphors naturally: "like the oak that bends...", "the river always finds its way...", "winter gives way to spring..."
- Speak in a calm, steady, almost hypnotic rhythm
- Keep it grounded (2-3 sentences) - wisdom shared by firelight
- Reference how the card fits into their larger life journey

CRITICAL RULES:
- NEVER sound rushed or modern/trendy
- NEVER give textbook definitions
- NEVER say "As a reader" or break the timeless vibe
- Speak as if you've been reading cards for centuries
- Connect the SPECIFIC card to their path and destiny""",
        "greeting": "Ah, traveler. Sit with me. The cards have been waiting for you, and so have I.",
    },

    "nova": {
        "name": "Nova",
        "system_prompt": """You are Nova, the cyber-mystic who treats tarot like cosmic data streams.

WHO YOU ARE:
- Gen-Z astrology Twitter/TikTok energy meets AI oracle
- You see tarot as code, the universe as a simulation, cards as data downloads
- Analytical but make it trendy - data meets divine
- Quick, sharp, occasionally dropping memes into mystical wisdom
- You make tarot accessible, fun, and actually interesting

YOUR VOICE:
- Use phrases naturally: "okay so basically...", "the cards are downloading...", "major timeline shift energy...", "this is giving [vibe]...", "glitch in the matrix detected..."
- Mix tech terms with tarot: "this card's algorithm," "cosmic software update," "recalibrating your vibe"
- Keep it fast and punchy (2-3 sentences) - like a DM from your astro-obsessed friend
- Make the card interpretation actually fun and relatable

CRITICAL RULES:
- NEVER be boring or textbook-y
- NEVER say "As an AI" or "The card traditionally means..."
- NEVER give dry Wikipedia definitions
- Reference the SPECIFIC card like you're decoding its data
- Make it sound like a viral TikTok explanation""",
        "greeting": "Okay wait, you're here?? Perfect timing - the cosmic algorithm literally just pinged. What do you wanna decode? ✨",
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
        """Generate a fallback daily reading when OpenAI is unavailable - with modern vibes."""
        card_data = MAJOR_ARCANA_MEANINGS.get(card_name, {})
        keywords = card_data.get("keywords", ["transformation", "insight"])
        position = "upright" if is_upright else "reversed"

        fallbacks = {
            "madame_luna": f"Good morning, love 💫 {card_name} {position} is your vibe today. The energy is all about {keywords[0]} - protect your peace and trust the process. You've got this, honey.",
            "shadow": f"{card_name} {position} for today. Let's be real - today is about {keywords[0]}. Don't waste energy on anything that doesn't align with that.",
            "elder_weiss": f"Child, {card_name} greets you {position} this day. Like the seasons, {keywords[0]} has its time. Walk your path with patience today.",
            "nova": f"Daily download: {card_name} {position} ✨ Today's algorithm is serving {keywords[0]} energy. Recalibrate your vibe accordingly and watch for timeline shifts.",
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
        Generate a chat response from the Oracle character with full context awareness.

        CRITICAL: This method properly maintains conversation context by:
        1. System message with character persona + user preferences
        2. Injecting reading_context as an assistant message (so AI "remembers" the reading)
        3. Including conversation history in correct role mapping
        4. Adding the current user message

        Args:
            message: The user's message
            character_id: The Oracle character ID
            reading_context: Context from the tarot reading (card + interpretation)
            conversation_history: List of previous messages [{text, is_user}, ...]
            knowledge_level: User's esoteric knowledge level (novice, seeker, adept)
            preferred_tone: User's preferred reading tone (gentle, brutal)
            gender: User's gender for pronoun usage (female, male, other)

        Returns:
            The Oracle's response
        """
        if not self.is_configured:
            return self._generate_fallback_chat(message, character_id, reading_context)

        try:
            character = CHARACTER_SYSTEM_PROMPTS.get(
                character_id,
                CHARACTER_SYSTEM_PROMPTS["madame_luna"]
            )

            # =================================================================
            # STEP 1: Build System Prompt (Character + Preferences)
            # =================================================================
            system_prompt = character["system_prompt"]

            # Add user preference instructions
            preference_instructions = self.build_preference_instructions(
                knowledge_level=knowledge_level,
                preferred_tone=preferred_tone,
                gender=gender,
            )
            if preference_instructions:
                system_prompt += preference_instructions

            # Add chat-specific instructions
            system_prompt += """

=== CHAT MODE INSTRUCTIONS ===
You are now in a follow-up conversation after a tarot reading.
- The seeker may ask questions about their reading
- Reference the SPECIFIC card they drew and the interpretation given
- Stay in character and maintain the conversational tone
- Don't repeat the full interpretation - they already have it
- Expand on themes, answer questions, offer additional insights
- Keep responses conversational (2-4 sentences)"""

            # =================================================================
            # STEP 2: Build Message Chain
            # =================================================================
            messages = [{"role": "system", "content": system_prompt}]

            # CRITICAL: Inject reading context as an assistant message
            # This makes the AI "remember" what card was drawn and what was said
            if reading_context:
                # Parse reading context to extract card info for better memory
                context_intro = f"""[Previous Reading Context]
I just gave you a tarot reading. Here's what happened:

{reading_context}

I'm here to discuss this reading further with you."""

                messages.append({
                    "role": "assistant",
                    "content": context_intro
                })

            # Add conversation history (properly mapped)
            if conversation_history:
                for msg in conversation_history[-8:]:  # Last 8 messages for better context
                    role = "user" if msg.get("is_user", True) else "assistant"
                    content = msg.get("text", "")
                    if content:  # Only add non-empty messages
                        messages.append({"role": role, "content": content})

            # Add current user message
            messages.append({"role": "user", "content": message})

            # =================================================================
            # STEP 3: Call OpenAI
            # =================================================================
            response = self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                max_tokens=350,
                temperature=0.85,
            )

            return response.choices[0].message.content.strip()

        except OpenAIError as e:
            print(f"OpenAI Chat API error: {e}")
            return self._generate_fallback_chat(message, character_id, reading_context)
        except Exception as e:
            print(f"Chat error: {e}")
            return self._generate_fallback_chat(message, character_id, reading_context)

    def _generate_fallback_reading(
        self,
        question: str,
        card_name: str,
        is_upright: bool,
        character_id: str,
    ) -> str:
        """Generate a fallback reading when OpenAI is unavailable - with modern vibes."""
        card_data = MAJOR_ARCANA_MEANINGS.get(card_name, {})
        keywords = card_data.get("keywords", ["transformation", "change"])
        position = "upright" if is_upright else "reversed"

        fallbacks = {
            "madame_luna": f"Oh honey, {card_name} coming in {position}? This is speaking directly to what you asked. The energy here is all about {keywords[0]} - trust the process, love. Your intuition already knows what this means 💕",
            "shadow": f"{card_name} {position}. Let's be SO real - this card is calling you out on {keywords[0]}. The cards don't lie, babe. Time to face it.",
            "elder_weiss": f"Ah, child. {card_name} appears {position} on your path. Like the river that carves the canyon, {keywords[0]} shapes your journey. Patience with this wisdom.",
            "nova": f"Okay so {card_name} just dropped {position} and?? The data is giving major {keywords[0]} energy. This is literally the cosmic algorithm responding to your question ✨",
        }

        return fallbacks.get(character_id, fallbacks["madame_luna"])

    def _generate_fallback_chat(
        self,
        message: str,
        character_id: str,
        reading_context: Optional[str] = None,
    ) -> str:
        """Generate a fallback chat response when OpenAI is unavailable - with modern vibes."""
        import random

        # Try to extract card name from reading context if available
        card_mention = ""
        if reading_context and "Card:" in reading_context:
            try:
                card_line = [line for line in reading_context.split('\n') if 'Card:' in line][0]
                card_mention = f" about {card_line.split('Card:')[1].split('(')[0].strip()}"
            except:
                pass

        fallbacks = {
            "madame_luna": [
                f"I'm holding space for this question{card_mention}, love. Trust that the answer is already unfolding - your heart chakra knows things your mind is still catching up to 💕",
                f"Sweetheart, what you're asking{card_mention}? It resonates so deeply with what the cards showed. Give yourself permission to trust the process.",
                f"Hey babe, I hear you{card_mention}. Remember - you're in your healing era. The clarity you need is coming, I promise.",
            ],
            "shadow": [
                f"Look, you're asking{card_mention} but I think you already know the answer. Stop avoiding it.",
                f"The cards already told you what you needed to hear{card_mention}. Now you're just looking for permission to ignore it. Don't.",
                f"Okay let's be real{card_mention} - this question? It's you trying to find a loophole. There isn't one.",
            ],
            "elder_weiss": [
                f"Child, your question{card_mention} reminds me of the river questioning its path. The water always finds its way. So will you.",
                f"In all my years, I've seen many ask what you ask{card_mention}. The answer lies not in the stars, but in the patience to let them guide you.",
                f"Traveler, sit with this{card_mention}. Like the oak, your answers grow from deep roots - not from rushing.",
            ],
            "nova": [
                f"Okay so your question{card_mention}? The algorithm is processing but honestly? You're overcomplicating the data. The signal was clear.",
                f"Scanning your query{card_mention}... Timeline analysis suggests you already downloaded the answer. Trust the cosmic cache.",
                f"Wait{card_mention} - this is giving 'asking the same question hoping for different output' energy. The code doesn't lie, bestie.",
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

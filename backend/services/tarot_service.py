"""
Tarot Interpretation Service
Dynamic tarot card interpretation using OpenAI GPT-4o-mini.
Supports character-based personalities, context-aware readings,
multi-card spreads with structured JSON output,
and personalized user preferences for knowledge level and tone.
"""

import json
import os
from dataclasses import dataclass
from typing import Any, Optional

from openai import OpenAI, OpenAIError


# =============================================================================
# Data Classes for Type Safety
# =============================================================================

@dataclass
class TarotCard:
    """Represents a single tarot card in a spread."""
    name: str
    is_upright: bool

    @property
    def orientation(self) -> str:
        return "Upright" if self.is_upright else "Reversed"

    @classmethod
    def from_dict(cls, data: dict) -> "TarotCard":
        """Create TarotCard from dictionary."""
        return cls(
            name=data.get("name", data.get("card_name", "Unknown")),
            is_upright=data.get("is_upright", data.get("isUpright", True))
        )


@dataclass
class UserContext:
    """User context for personalized readings."""
    knowledge_level: Optional[str] = None  # novice, seeker, adept
    preferred_tone: Optional[str] = None   # gentle, brutal
    gender: Optional[str] = None           # female, male, other
    birth_date: Optional[str] = None
    zodiac_sign: Optional[str] = None

    @classmethod
    def from_dict(cls, data: dict) -> "UserContext":
        """Create UserContext from dictionary."""
        if not data:
            return cls()
        return cls(
            knowledge_level=data.get("knowledge_level"),
            preferred_tone=data.get("preferred_tone"),
            gender=data.get("gender"),
            birth_date=data.get("birth_date"),
            zodiac_sign=data.get("zodiac_sign"),
        )


@dataclass
class CardAnalysis:
    """Analysis result for a single card."""
    position_name: str
    card_name: str
    orientation: str
    interpretation: str


@dataclass
class SpreadReading:
    """Complete spread reading result."""
    cards_analysis: list[CardAnalysis]
    synthesis: str
    spread_type: str
    character_id: str

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "cards_analysis": [
                {
                    "position_name": ca.position_name,
                    "card_name": ca.card_name,
                    "orientation": ca.orientation,
                    "interpretation": ca.interpretation,
                }
                for ca in self.cards_analysis
            ],
            "synthesis": self.synthesis,
            "spread_type": self.spread_type,
            "character_id": self.character_id,
        }


# =============================================================================
# Spread Type Configurations
# =============================================================================

SPREAD_CONFIGS = {
    "single": {
        "name": "Single Card Reading",
        "positions": ["Answer"],
        "description": "A single card providing direct insight or guidance.",
    },
    "three_card": {
        "name": "Three Card Spread",
        "positions": ["Past", "Present", "Future"],
        "description": "Classic timeline spread showing progression from past influences through present situation to future potential.",
    },
    "love": {
        "name": "Love Spread",
        "positions": ["You", "Them", "Dynamics", "Future Potential"],
        "description": "Comprehensive relationship spread examining both parties, their current dynamics, and future potential.",
    },
    "career": {
        "name": "Career Spread",
        "positions": ["Current Role", "Challenges", "Opportunities", "Outcome"],
        "description": "Professional guidance spread for career decisions and growth.",
    },
    "decision": {
        "name": "Decision Spread",
        "positions": ["Current Situation", "Path A Result", "Path B Result", "Advice"],
        "description": "Clarity spread for weighing two paths and receiving guidance.",
    },
    "mind_body_spirit": {
        "name": "Mind Body Spirit",
        "positions": ["Mind (Mental State)", "Body (Physical/Action)", "Spirit (Lesson)"],
        "description": "Holistic spread examining mental, physical, and spiritual aspects.",
    },
    "celtic_cross": {
        "name": "Celtic Cross",
        "positions": [
            "Present",              # 1. Current situation
            "Challenge",            # 2. Immediate obstacle
            "Past",                 # 3. Foundation/root cause
            "Future",               # 4. Near future energy
            "Above (Goals)",        # 5. Conscious goals/aspirations
            "Below (Subconscious)", # 6. Underlying influences
            "Advice",               # 7. Recommended approach
            "External Influences",  # 8. Environment/others
            "Hopes/Fears",          # 9. Inner desires/anxieties
            "Outcome",              # 10. Likely conclusion
        ],
        "description": "Comprehensive 10-card spread for deep, multi-layered life analysis.",
    },
}

# Backwards compatibility alias
SPREAD_CONFIGURATIONS = SPREAD_CONFIGS


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

    def _build_cards_context(
        self,
        cards: list[TarotCard],
        positions: list[str],
    ) -> str:
        """Build context string for all cards in a spread."""
        context_parts = []
        for i, (card, position) in enumerate(zip(cards, positions), 1):
            card_data = MAJOR_ARCANA_MEANINGS.get(card.name, {})
            meaning_key = "upright" if card.is_upright else "reversed"
            meaning = card_data.get(meaning_key, "transformation and insight")
            keywords = card_data.get("keywords", ["insight", "change"])

            context_parts.append(
                f"Position {i} - {position}:\n"
                f"  Card: {card.name} ({card.orientation})\n"
                f"  Core Meaning: {meaning}\n"
                f"  Key Themes: {', '.join(keywords)}"
            )

        return "\n\n".join(context_parts)

    def _build_json_schema_instruction(
        self,
        positions: list[str],
        spread_name: str,
    ) -> str:
        """Build the JSON schema instruction for the AI."""
        example_cards = []
        for pos in positions[:2]:  # Show 2 examples max
            example_cards.append({
                "position_name": pos,
                "card_name": "Example Card",
                "orientation": "Upright",
                "interpretation": f"Detailed interpretation of the card specifically for the '{pos}' position..."
            })

        example_json = {
            "reading_type": spread_name,
            "cards_analysis": example_cards,
            "overall_synthesis": "A cohesive summary paragraph connecting all cards to directly answer the seeker's question..."
        }

        return f"""
=== CRITICAL: JSON OUTPUT REQUIRED ===
You MUST respond with ONLY valid JSON. No markdown, no code blocks, no explanations, no text before or after.

Required JSON structure:
{json.dumps(example_json, indent=2)}

Rules:
1. "reading_type" MUST be exactly "{spread_name}"
2. "cards_analysis" MUST contain exactly {len(positions)} objects, one for each position in order
3. Each "interpretation" should be 2-4 sentences, interpreting that SPECIFIC CARD in that SPECIFIC POSITION
   - Example: "Interpret 'The Tower' specifically as the 'Future Potential' of the relationship"
4. "overall_synthesis" should be 3-5 sentences connecting ALL cards to answer the user's question
5. Stay in character throughout all interpretations
6. DO NOT include any text, markdown, or code blocks outside the JSON object
"""

    async def generate_spread_reading(
        self,
        cards: list[dict | TarotCard],
        spread_type: str,
        question: Optional[str] = None,
        user_context: Optional[dict | UserContext] = None,
        character_id: str = "madame_luna",
    ) -> dict:
        """
        Generate a multi-card spread reading with structured JSON output.

        Args:
            cards: List of card objects/dicts with 'name' and 'is_upright' fields
            spread_type: Type of spread (single, three_card, love, career, decision,
                        mind_body_spirit, celtic_cross)
            question: The seeker's question (optional)
            user_context: Optional user context for personalization
            character_id: The character providing the reading

        Returns:
            Dictionary with structure:
            {
                "reading_type": "Love Spread",
                "cards_analysis": [
                    {
                        "position_name": "You",
                        "card_name": "The Empress",
                        "orientation": "Upright",
                        "interpretation": "..."
                    },
                    ...
                ],
                "overall_synthesis": "A summary connecting all cards..."
            }

        Example:
            >>> cards = [
            ...     {"name": "The Empress", "is_upright": True},
            ...     {"name": "The Tower", "is_upright": False},
            ...     {"name": "The Lovers", "is_upright": True},
            ...     {"name": "The Star", "is_upright": True}
            ... ]
            >>> result = await service.generate_spread_reading(
            ...     cards=cards,
            ...     spread_type="love",
            ...     question="What is the future of my relationship?"
            ... )
        """
        # Normalize inputs
        normalized_cards = [
            card if isinstance(card, TarotCard) else TarotCard.from_dict(card)
            for card in cards
        ]

        ctx = (
            user_context if isinstance(user_context, UserContext)
            else UserContext.from_dict(user_context or {})
        )

        # Get spread configuration
        spread_config = SPREAD_CONFIGS.get(spread_type)
        if not spread_config:
            # Fallback to single card if unknown spread type
            spread_config = SPREAD_CONFIGS["single"]
            spread_type = "single"

        positions = spread_config["positions"]
        spread_name = spread_config["name"]

        # Validate card count matches spread
        if len(normalized_cards) < len(positions):
            # Pad with placeholder if needed
            while len(normalized_cards) < len(positions):
                normalized_cards.append(TarotCard(name="Unknown", is_upright=True))
        elif len(normalized_cards) > len(positions):
            normalized_cards = normalized_cards[:len(positions)]

        # Generate reading
        if not self.is_configured:
            return self._generate_fallback_spread_reading(
                normalized_cards, positions, spread_name, question or "", character_id
            )

        try:
            result = await self._call_openai_for_spread(
                cards=normalized_cards,
                positions=positions,
                spread_name=spread_name,
                spread_description=spread_config["description"],
                question=question or "",
                user_context=ctx,
                character_id=character_id,
            )
            return result
        except Exception as e:
            print(f"Spread reading error: {e}")
            return self._generate_fallback_spread_reading(
                normalized_cards, positions, spread_name, question or "", character_id
            )

    async def _call_openai_for_spread(
        self,
        cards: list[TarotCard],
        positions: list[str],
        spread_name: str,
        spread_description: str,
        question: str,
        user_context: UserContext,
        character_id: str,
    ) -> dict:
        """Internal method to call OpenAI for spread reading with JSON output."""
        # Get character personality
        character = CHARACTER_SYSTEM_PROMPTS.get(
            character_id,
            CHARACTER_SYSTEM_PROMPTS["madame_luna"]
        )

        # Build position-to-card mapping for clear instructions
        card_position_mapping = "\n".join([
            f"  - Position '{pos}': {card.name} ({card.orientation})"
            for pos, card in zip(positions, cards)
        ])

        # Build system prompt
        system_prompt = f"""{character["system_prompt"]}

=== SPREAD READING MODE: {spread_name.upper()} ===
{spread_description}

CRITICAL INSTRUCTION: Each card MUST be interpreted IN THE CONTEXT OF ITS SPECIFIC POSITION.
The position fundamentally changes the meaning of the card.

Position-Specific Interpretation Examples:
- "The Tower" in "Future Potential" = upcoming dramatic transformation in the relationship
- "The Tower" in "Challenges" = current destructive patterns or sudden upheavals
- "The Tower" in "You" = your own tendency toward dramatic change or upheaval

The SAME card has DIFFERENT meanings based on WHERE it appears.

=== CARDS AND THEIR POSITIONS ===
{card_position_mapping}

You must interpret each card SPECIFICALLY for its assigned position above."""

        # Add user preferences
        preference_instructions = self.build_preference_instructions(
            knowledge_level=user_context.knowledge_level,
            preferred_tone=user_context.preferred_tone,
            gender=user_context.gender,
        )
        if preference_instructions:
            system_prompt += preference_instructions

        # Add JSON instruction
        system_prompt += self._build_json_schema_instruction(positions, spread_name)

        # Build cards context
        cards_context = self._build_cards_context(cards, positions)

        # Handle empty question
        effective_question = question.strip() if question else ""
        if not effective_question:
            effective_question = "What does the universe want me to know?"

        # Build user prompt with explicit position instructions
        position_instructions = "\n".join([
            f"  {i+1}. Interpret '{card.name}' ({card.orientation}) specifically as '{pos}'"
            for i, (pos, card) in enumerate(zip(positions, cards))
        ])

        user_prompt = f"""The Seeker asks: "{effective_question}"

=== SPREAD: {spread_name} ===
{cards_context}

=== INTERPRETATION REQUIREMENTS ===
{position_instructions}

=== OUTPUT REQUIREMENTS ===
1. Return ONLY valid JSON (no markdown, no code blocks, no extra text)
2. "reading_type" must be exactly "{spread_name}"
3. "cards_analysis" must have exactly {len(positions)} entries in order
4. Each interpretation must explain the card IN THE CONTEXT OF ITS POSITION
5. "overall_synthesis" must connect all cards to answer the seeker's question
6. Stay completely in character with your speaking style

Respond with valid JSON only:"""

        # Call OpenAI with JSON mode
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            max_tokens=1500 if len(positions) > 3 else 800,
            temperature=0.8,
            response_format={"type": "json_object"},  # Force JSON output
        )

        # Parse response
        response_text = response.choices[0].message.content.strip()

        try:
            result = json.loads(response_text)
        except json.JSONDecodeError:
            # Try to extract JSON from response
            result = self._extract_json_from_response(response_text, cards, positions, spread_name)

        # Validate and normalize result
        return self._validate_spread_result(result, cards, positions, spread_name)

    def _extract_json_from_response(
        self,
        response_text: str,
        cards: list[TarotCard],
        positions: list[str],
        spread_name: str,
    ) -> dict:
        """Attempt to extract JSON from a response that may have extra text."""
        import re

        # Try to find JSON object in response
        json_match = re.search(r'\{[\s\S]*\}', response_text)
        if json_match:
            try:
                return json.loads(json_match.group())
            except json.JSONDecodeError:
                pass

        # Return fallback structure
        return {
            "reading_type": spread_name,
            "cards_analysis": [
                {
                    "position_name": pos,
                    "card_name": card.name,
                    "orientation": card.orientation,
                    "interpretation": f"The {card.name} in the '{pos}' position brings important energy to your reading.",
                }
                for card, pos in zip(cards, positions)
            ],
            "overall_synthesis": "The cards speak of transformation and insight on your path."
        }

    def _validate_spread_result(
        self,
        result: dict,
        cards: list[TarotCard],
        positions: list[str],
        spread_name: str,
    ) -> dict:
        """Validate and normalize the spread reading result."""
        # Handle both old and new format for backwards compatibility
        synthesis = (
            result.get("overall_synthesis") or
            result.get("synthesis") or
            "The cards reveal your path forward."
        )

        validated = {
            "reading_type": result.get("reading_type", spread_name),
            "cards_analysis": [],
            "overall_synthesis": synthesis,
        }

        # Validate cards_analysis
        analysis = result.get("cards_analysis", [])
        for i, (card, position) in enumerate(zip(cards, positions)):
            if i < len(analysis) and isinstance(analysis[i], dict):
                card_analysis = analysis[i]
                validated["cards_analysis"].append({
                    "position_name": card_analysis.get("position_name", position),
                    "card_name": card_analysis.get("card_name", card.name),
                    "orientation": card_analysis.get("orientation", card.orientation),
                    "interpretation": card_analysis.get(
                        "interpretation",
                        f"The {card.name} appears in the '{position}' position."
                    ),
                })
            else:
                # Generate placeholder if missing
                validated["cards_analysis"].append({
                    "position_name": position,
                    "card_name": card.name,
                    "orientation": card.orientation,
                    "interpretation": f"The {card.name} ({card.orientation}) in the '{position}' position speaks to this aspect of your journey.",
                })

        return validated

    def _generate_fallback_spread_reading(
        self,
        cards: list[TarotCard],
        positions: list[str],
        spread_name: str,
        question: str,
        character_id: str,
    ) -> dict:
        """Generate a fallback spread reading when OpenAI is unavailable."""
        # Character-specific synthesis templates
        synthesis_templates = {
            "madame_luna": "Honey, these cards together are telling you something beautiful. {summary} Trust the process, love - your path is unfolding exactly as it should.",
            "shadow": "Okay let's be SO real about what these cards are saying. {summary} The universe isn't subtle here - are you listening?",
            "elder_weiss": "Child, the cards speak in the language of the ancients. {summary} Like the seasons, your answer will reveal itself in time.",
            "nova": "The cosmic algorithm just dropped some MAJOR data. {summary} This is literally the download you needed.",
        }

        cards_analysis = []
        summary_parts = []

        for card, position in zip(cards, positions):
            card_data = MAJOR_ARCANA_MEANINGS.get(card.name, {})
            keywords = card_data.get("keywords", ["insight", "change"])
            meaning_key = "upright" if card.is_upright else "reversed"
            meaning = card_data.get(meaning_key, "transformation")

            # Build position-specific interpretation
            interpretation = self._build_fallback_interpretation(
                card, position, meaning, keywords, character_id
            )

            cards_analysis.append({
                "position_name": position,
                "card_name": card.name,
                "orientation": card.orientation,
                "interpretation": interpretation,
            })

            summary_parts.append(f"{position}: {keywords[0]}")

        # Build overall synthesis
        summary = " → ".join(summary_parts)
        template = synthesis_templates.get(character_id, synthesis_templates["madame_luna"])
        overall_synthesis = template.format(summary=summary)

        return {
            "reading_type": spread_name,
            "cards_analysis": cards_analysis,
            "overall_synthesis": overall_synthesis,
        }

    def _build_fallback_interpretation(
        self,
        card: TarotCard,
        position: str,
        meaning: str,
        keywords: list[str],
        character_id: str,
    ) -> str:
        """Build a character-specific fallback interpretation for a card position."""
        templates = {
            "madame_luna": f"In your {position}, {card.name} {card.orientation.lower()} is all about {keywords[0]}. {meaning.split(',')[0]} - feel into that energy, love.",
            "shadow": f"{card.name} {card.orientation.lower()} in {position}? This is calling out {keywords[0]}. {meaning.split(',')[0]} - no sugarcoating it.",
            "elder_weiss": f"The {card.name} appears {card.orientation.lower()} in the {position} position. It speaks of {keywords[0]} - {meaning.split(',')[0]}.",
            "nova": f"{card.name} {card.orientation.lower()} just dropped in your {position} slot - major {keywords[0]} energy. {meaning.split(',')[0]}.",
        }
        return templates.get(character_id, templates["madame_luna"])

    # Legacy single-card method (kept for backwards compatibility)
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


# =============================================================================
# Utility Functions for Spread Management
# =============================================================================

def get_spread_info(spread_type: str) -> dict:
    """
    Get information about a specific spread type.

    Args:
        spread_type: The spread type identifier (single, three_card, love, career,
                    decision, mind_body_spirit, celtic_cross)

    Returns:
        Dictionary with name, positions, and description
    """
    return SPREAD_CONFIGS.get(
        spread_type,
        SPREAD_CONFIGS["single"]
    )


def get_available_spreads() -> dict[str, dict]:
    """
    Get all available spread configurations.

    Returns:
        Dictionary of all spread configurations keyed by spread_type
    """
    return SPREAD_CONFIGS.copy()


def get_spread_positions(spread_type: str) -> list[str]:
    """
    Get the position names for a specific spread type.

    Args:
        spread_type: The spread type identifier

    Returns:
        List of position names for the spread
    """
    spread = SPREAD_CONFIGS.get(spread_type)
    if spread:
        return spread["positions"].copy()
    return SPREAD_CONFIGS["single"]["positions"].copy()


def validate_cards_for_spread(
    cards: list[dict],
    spread_type: str
) -> tuple[bool, str]:
    """
    Validate that the provided cards match the spread requirements.

    Args:
        cards: List of card dictionaries
        spread_type: The spread type identifier

    Returns:
        Tuple of (is_valid, error_message)
    """
    spread = SPREAD_CONFIGS.get(spread_type)
    if not spread:
        available = ", ".join(SPREAD_CONFIGS.keys())
        return False, f"Unknown spread type: '{spread_type}'. Available: {available}"

    required_count = len(spread["positions"])
    actual_count = len(cards)

    if actual_count < required_count:
        return False, f"{spread['name']} requires {required_count} cards, got {actual_count}"

    # Validate each card has required fields
    for i, card in enumerate(cards):
        if not isinstance(card, dict):
            return False, f"Card {i+1} must be a dictionary"
        if "name" not in card and "card_name" not in card:
            return False, f"Card {i+1} missing 'name' field"

    return True, ""


def map_cards_to_positions(
    cards: list[dict],
    spread_type: str
) -> list[dict]:
    """
    Map cards to their corresponding positions in a spread.

    Args:
        cards: List of card dictionaries with name and is_upright fields
        spread_type: The spread type identifier

    Returns:
        List of dicts with position_name, card_name, and orientation
    """
    spread = SPREAD_CONFIGS.get(spread_type, SPREAD_CONFIGS["single"])
    positions = spread["positions"]

    mapped = []
    for i, position in enumerate(positions):
        if i < len(cards):
            card = cards[i]
            card_name = card.get("name", card.get("card_name", "Unknown"))
            is_upright = card.get("is_upright", card.get("isUpright", True))
            mapped.append({
                "position_name": position,
                "card_name": card_name,
                "orientation": "Upright" if is_upright else "Reversed",
            })
        else:
            mapped.append({
                "position_name": position,
                "card_name": "Unknown",
                "orientation": "Upright",
            })

    return mapped


# =============================================================================
# Exports
# =============================================================================

__all__ = [
    # Service
    "TarotInterpretationService",
    "get_tarot_service",

    # Data Classes
    "TarotCard",
    "UserContext",
    "CardAnalysis",
    "SpreadReading",

    # Configurations
    "SPREAD_CONFIGS",
    "SPREAD_CONFIGURATIONS",  # Backwards compatibility alias
    "MAJOR_ARCANA_MEANINGS",
    "CHARACTER_SYSTEM_PROMPTS",
    "KNOWLEDGE_LEVEL_INSTRUCTIONS",
    "PREFERRED_TONE_INSTRUCTIONS",
    "GENDER_PRONOUN_INSTRUCTIONS",

    # Utility Functions
    "get_spread_info",
    "get_available_spreads",
    "get_spread_positions",
    "validate_cards_for_spread",
    "map_cards_to_positions",
]

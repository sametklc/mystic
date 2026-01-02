"""
Synastry Analysis Service

Provides detailed compatibility analysis using:
1. Weighted planetary aspect scoring algorithm
2. OpenAI GPT-4o-mini for deep interpretations
3. Three-section analysis: Chemistry, Emotional Connection, Challenges
"""

import os
from typing import Optional
from openai import AsyncOpenAI


# =============================================================================
# Aspect Weights for Synastry Scoring
# =============================================================================

# Aspect type base scores
ASPECT_BASE_SCORES = {
    "conjunction": {"harmonious": 10, "challenging": -3},  # Depends on planets
    "trine": 8,
    "sextile": 5,
    "square": -6,
    "opposition": -4,
    "quincunx": -2,
}

# Planet pair weights - determines importance of the aspect
PLANET_PAIR_WEIGHTS = {
    # Soul Connection (Sun/Moon interactions) - HIGHEST WEIGHT
    ("Sun", "Sun"): {"weight": 1.5, "category": "emotional", "meaning": "core identity alignment"},
    ("Sun", "Moon"): {"weight": 2.0, "category": "emotional", "meaning": "soul connection"},
    ("Moon", "Sun"): {"weight": 2.0, "category": "emotional", "meaning": "emotional-identity bond"},
    ("Moon", "Moon"): {"weight": 1.8, "category": "emotional", "meaning": "emotional synchronicity"},

    # Chemistry (Venus/Mars) - HIGH WEIGHT
    ("Venus", "Mars"): {"weight": 2.0, "category": "chemistry", "meaning": "romantic/physical attraction"},
    ("Mars", "Venus"): {"weight": 2.0, "category": "chemistry", "meaning": "passionate chemistry"},
    ("Venus", "Venus"): {"weight": 1.5, "category": "chemistry", "meaning": "shared love language"},
    ("Mars", "Mars"): {"weight": 1.2, "category": "chemistry", "meaning": "drive compatibility"},
    ("Sun", "Venus"): {"weight": 1.3, "category": "chemistry", "meaning": "admiration and affection"},
    ("Venus", "Sun"): {"weight": 1.3, "category": "chemistry", "meaning": "attraction to identity"},
    ("Moon", "Venus"): {"weight": 1.4, "category": "emotional", "meaning": "emotional comfort in love"},
    ("Venus", "Moon"): {"weight": 1.4, "category": "emotional", "meaning": "nurturing affection"},

    # Communication (Mercury) - MEDIUM WEIGHT
    ("Mercury", "Mercury"): {"weight": 1.2, "category": "intellectual", "meaning": "mental wavelength"},
    ("Mercury", "Sun"): {"weight": 1.0, "category": "intellectual", "meaning": "understanding each other"},
    ("Sun", "Mercury"): {"weight": 1.0, "category": "intellectual", "meaning": "mental connection"},
    ("Mercury", "Moon"): {"weight": 1.1, "category": "emotional", "meaning": "emotional understanding"},
    ("Moon", "Mercury"): {"weight": 1.1, "category": "emotional", "meaning": "communicating feelings"},
    ("Mercury", "Venus"): {"weight": 0.9, "category": "intellectual", "meaning": "sweet communication"},
    ("Venus", "Mercury"): {"weight": 0.9, "category": "intellectual", "meaning": "loving words"},

    # Stability/Challenge (Saturn) - Can be positive or negative
    ("Saturn", "Sun"): {"weight": 1.5, "category": "challenges", "meaning": "stability or restriction"},
    ("Sun", "Saturn"): {"weight": 1.5, "category": "challenges", "meaning": "growth through limits"},
    ("Saturn", "Moon"): {"weight": 1.6, "category": "challenges", "meaning": "emotional security or coldness"},
    ("Moon", "Saturn"): {"weight": 1.6, "category": "challenges", "meaning": "emotional lessons"},
    ("Saturn", "Venus"): {"weight": 1.4, "category": "challenges", "meaning": "committed love or restriction"},
    ("Venus", "Saturn"): {"weight": 1.4, "category": "challenges", "meaning": "lasting affection"},
    ("Saturn", "Mars"): {"weight": 1.3, "category": "challenges", "meaning": "disciplined action or frustration"},
    ("Mars", "Saturn"): {"weight": 1.3, "category": "challenges", "meaning": "controlled passion"},

    # Transformation (Pluto) - Intense aspects
    ("Pluto", "Sun"): {"weight": 1.5, "category": "challenges", "meaning": "transformative power"},
    ("Sun", "Pluto"): {"weight": 1.5, "category": "challenges", "meaning": "profound change"},
    ("Pluto", "Moon"): {"weight": 1.6, "category": "challenges", "meaning": "deep emotional transformation"},
    ("Moon", "Pluto"): {"weight": 1.6, "category": "challenges", "meaning": "psychological intensity"},
    ("Pluto", "Venus"): {"weight": 1.4, "category": "chemistry", "meaning": "obsessive attraction"},
    ("Venus", "Pluto"): {"weight": 1.4, "category": "chemistry", "meaning": "magnetic pull"},
    ("Pluto", "Mars"): {"weight": 1.3, "category": "chemistry", "meaning": "explosive passion"},
    ("Mars", "Pluto"): {"weight": 1.3, "category": "chemistry", "meaning": "intense drive"},

    # Growth (Jupiter) - Generally positive
    ("Jupiter", "Sun"): {"weight": 1.2, "category": "emotional", "meaning": "expansion and joy"},
    ("Sun", "Jupiter"): {"weight": 1.2, "category": "emotional", "meaning": "optimism together"},
    ("Jupiter", "Moon"): {"weight": 1.1, "category": "emotional", "meaning": "emotional growth"},
    ("Moon", "Jupiter"): {"weight": 1.1, "category": "emotional", "meaning": "feeling blessed"},
    ("Jupiter", "Venus"): {"weight": 1.3, "category": "chemistry", "meaning": "abundant love"},
    ("Venus", "Jupiter"): {"weight": 1.3, "category": "chemistry", "meaning": "generosity in love"},

    # Innovation (Uranus) - Exciting but unstable
    ("Uranus", "Sun"): {"weight": 1.0, "category": "challenges", "meaning": "excitement or instability"},
    ("Sun", "Uranus"): {"weight": 1.0, "category": "challenges", "meaning": "unique connection"},
    ("Uranus", "Moon"): {"weight": 1.1, "category": "challenges", "meaning": "emotional unpredictability"},
    ("Moon", "Uranus"): {"weight": 1.1, "category": "challenges", "meaning": "exciting instability"},
    ("Uranus", "Venus"): {"weight": 1.2, "category": "chemistry", "meaning": "electric attraction"},
    ("Venus", "Uranus"): {"weight": 1.2, "category": "chemistry", "meaning": "unconventional love"},

    # Dreams (Neptune) - Romantic but potentially deceptive
    ("Neptune", "Sun"): {"weight": 1.0, "category": "emotional", "meaning": "idealization"},
    ("Sun", "Neptune"): {"weight": 1.0, "category": "emotional", "meaning": "spiritual connection"},
    ("Neptune", "Moon"): {"weight": 1.2, "category": "emotional", "meaning": "psychic bond"},
    ("Moon", "Neptune"): {"weight": 1.2, "category": "emotional", "meaning": "dreamy emotions"},
    ("Neptune", "Venus"): {"weight": 1.3, "category": "chemistry", "meaning": "romantic fantasy"},
    ("Venus", "Neptune"): {"weight": 1.3, "category": "chemistry", "meaning": "idealized love"},
}

# Special scoring rules for specific combinations
SPECIAL_ASPECT_SCORES = {
    # Sun-Moon aspects are the most important for soul connection
    ("Sun", "Moon", "conjunction"): 15,
    ("Sun", "Moon", "trine"): 12,
    ("Sun", "Moon", "sextile"): 8,
    ("Sun", "Moon", "square"): -5,
    ("Sun", "Moon", "opposition"): -3,  # Can create attraction too

    # Venus-Mars for chemistry
    ("Venus", "Mars", "conjunction"): 15,
    ("Venus", "Mars", "trine"): 12,
    ("Venus", "Mars", "sextile"): 10,
    ("Venus", "Mars", "square"): 5,  # Creates tension but also attraction
    ("Venus", "Mars", "opposition"): 8,  # Magnetic attraction

    # Saturn aspects - stability vs restriction
    ("Saturn", "Sun", "trine"): 8,
    ("Saturn", "Sun", "sextile"): 6,
    ("Saturn", "Sun", "conjunction"): -3,
    ("Saturn", "Sun", "square"): -10,
    ("Saturn", "Sun", "opposition"): -8,

    # Pluto aspects - transformation
    ("Pluto", "Sun", "trine"): 6,
    ("Pluto", "Sun", "square"): -8,
    ("Pluto", "Venus", "conjunction"): 10,  # Intense but magnetic
    ("Pluto", "Venus", "square"): -6,

    # Mercury for communication
    ("Mercury", "Mercury", "conjunction"): 8,
    ("Mercury", "Mercury", "trine"): 6,
    ("Mercury", "Mercury", "square"): -5,
}


class SynastryAnalysisService:
    """Service for detailed synastry analysis with AI integration."""

    def __init__(self):
        """Initialize the service with OpenAI client if available."""
        api_key = os.getenv("OPENAI_API_KEY")
        self.client = AsyncOpenAI(api_key=api_key) if api_key else None
        self.is_configured = api_key is not None

    def calculate_weighted_score(self, aspects: list, chart1: dict, chart2: dict) -> dict:
        """
        Calculate weighted compatibility scores using the aspect-based algorithm.

        Returns detailed scores for:
        - overall: Total compatibility (0-100)
        - chemistry: Physical/romantic attraction
        - emotional: Emotional understanding and connection
        - intellectual: Mental compatibility
        - challenges: Areas of friction (lower is better)
        """
        # Raw scores by category
        chemistry_raw = 0
        emotional_raw = 0
        intellectual_raw = 0
        challenges_raw = 0

        # Track aspects by category for AI analysis
        chemistry_aspects = []
        emotional_aspects = []
        intellectual_aspects = []
        challenge_aspects = []

        total_weighted_score = 0
        max_possible_score = 0

        for aspect in aspects:
            p1 = aspect.get("person1_planet", "")
            p2 = aspect.get("person2_planet", "")
            aspect_type = aspect.get("aspect_type", "").lower()
            orb = aspect.get("orb", 0)

            # Get planet pair info
            pair_key = (p1, p2)
            reverse_key = (p2, p1)

            pair_info = PLANET_PAIR_WEIGHTS.get(pair_key) or PLANET_PAIR_WEIGHTS.get(reverse_key)
            if not pair_info:
                # Default for unlisted combinations
                pair_info = {"weight": 0.5, "category": "emotional", "meaning": "general connection"}

            weight = pair_info["weight"]
            category = pair_info["category"]
            meaning = pair_info["meaning"]

            # Check for special scoring
            special_key = (p1, p2, aspect_type)
            reverse_special = (p2, p1, aspect_type)

            if special_key in SPECIAL_ASPECT_SCORES:
                base_score = SPECIAL_ASPECT_SCORES[special_key]
            elif reverse_special in SPECIAL_ASPECT_SCORES:
                base_score = SPECIAL_ASPECT_SCORES[reverse_special]
            else:
                # Use default aspect scores
                aspect_score_info = ASPECT_BASE_SCORES.get(aspect_type, 0)
                if isinstance(aspect_score_info, dict):
                    # Conjunction - depends on planets
                    if p1 in ["Saturn", "Pluto"] or p2 in ["Saturn", "Pluto"]:
                        base_score = aspect_score_info.get("challenging", -3)
                    else:
                        base_score = aspect_score_info.get("harmonious", 10)
                else:
                    base_score = aspect_score_info

            # Apply orb modifier (tighter orb = stronger effect)
            orb_modifier = max(0.5, 1 - (orb / 10))
            final_score = base_score * weight * orb_modifier

            # Add to totals
            total_weighted_score += final_score
            max_possible_score += abs(base_score * weight)

            # Create aspect description for AI
            aspect_desc = {
                "planets": f"{p1} {aspect_type} {p2}",
                "meaning": meaning,
                "score": round(final_score, 1),
                "orb": round(orb, 1),
            }

            # Categorize aspect
            if category == "chemistry":
                chemistry_raw += final_score
                if final_score > 0:
                    chemistry_aspects.append(aspect_desc)
                elif final_score < -3:
                    challenge_aspects.append(aspect_desc)
            elif category == "emotional":
                emotional_raw += final_score
                if final_score > 0:
                    emotional_aspects.append(aspect_desc)
                elif final_score < -3:
                    challenge_aspects.append(aspect_desc)
            elif category == "intellectual":
                intellectual_raw += final_score
                if final_score > 0:
                    intellectual_aspects.append(aspect_desc)
                elif final_score < -3:
                    challenge_aspects.append(aspect_desc)
            elif category == "challenges":
                challenges_raw += final_score
                if final_score < 0:
                    challenge_aspects.append(aspect_desc)
                else:
                    # Positive Saturn/Pluto aspects go to emotional
                    emotional_aspects.append(aspect_desc)

        # Element compatibility bonus
        sun1_elem = chart1.get("sun", {}).get("element", "")
        sun2_elem = chart2.get("sun", {}).get("element", "")
        moon1_elem = chart1.get("moon", {}).get("element", "")
        moon2_elem = chart2.get("moon", {}).get("element", "")

        element_bonus = 0
        if sun1_elem == sun2_elem:
            element_bonus += 8
        elif self._elements_compatible(sun1_elem, sun2_elem):
            element_bonus += 4

        if moon1_elem == moon2_elem:
            element_bonus += 6
            emotional_raw += 5
        elif self._elements_compatible(moon1_elem, moon2_elem):
            element_bonus += 3
            emotional_raw += 3

        total_weighted_score += element_bonus

        # Normalize scores to 0-100
        def normalize(raw_score, base=50, scale=3):
            return max(0, min(100, int(base + raw_score * scale)))

        # Calculate overall score
        if max_possible_score > 0:
            overall = int(50 + (total_weighted_score / max_possible_score) * 50)
        else:
            overall = 50
        overall = max(15, min(95, overall))  # Clamp to realistic range

        return {
            "overall": overall,
            "chemistry": normalize(chemistry_raw, 50, 2.5),
            "emotional": normalize(emotional_raw, 50, 2.5),
            "intellectual": normalize(intellectual_raw, 50, 3),
            "challenges_score": max(0, min(100, int(50 - challenges_raw * 2))),
            "chemistry_aspects": sorted(chemistry_aspects, key=lambda x: x["score"], reverse=True)[:5],
            "emotional_aspects": sorted(emotional_aspects, key=lambda x: x["score"], reverse=True)[:5],
            "intellectual_aspects": sorted(intellectual_aspects, key=lambda x: x["score"], reverse=True)[:3],
            "challenge_aspects": sorted(challenge_aspects, key=lambda x: x["score"])[:5],
            "element_compatibility": {
                "sun_match": sun1_elem == sun2_elem,
                "moon_match": moon1_elem == moon2_elem,
                "bonus": element_bonus,
            }
        }

    def _elements_compatible(self, elem1: str, elem2: str) -> bool:
        """Check if two elements are compatible."""
        compatible_pairs = [
            ("Fire", "Air"),
            ("Air", "Fire"),
            ("Earth", "Water"),
            ("Water", "Earth"),
        ]
        return (elem1, elem2) in compatible_pairs

    async def generate_detailed_analysis(
        self,
        chart1: dict,
        chart2: dict,
        scores: dict,
        aspects: list,
    ) -> dict:
        """
        Generate a detailed 3-part analysis using OpenAI.

        Returns:
        {
            "chemistry_analysis": "...",
            "emotional_connection": "...",
            "challenges": "...",
            "summary": "..."
        }
        """
        if not self.is_configured:
            return self._get_fallback_analysis(chart1, chart2, scores)

        try:
            # Build the analysis prompt
            prompt = self._build_analysis_prompt(chart1, chart2, scores, aspects)

            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {
                        "role": "system",
                        "content": self._get_system_prompt()
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                temperature=0.8,
                max_tokens=1500,
            )

            content = response.choices[0].message.content

            # Parse the structured response
            return self._parse_analysis_response(content, scores)

        except Exception as e:
            print(f"OpenAI analysis error: {e}")
            return self._get_fallback_analysis(chart1, chart2, scores)

    def _get_system_prompt(self) -> str:
        """Get the system prompt for synastry analysis."""
        return """You are an expert Synastry Astrologer with deep knowledge of relationship astrology.
You analyze planetary aspects between two birth charts to reveal the dynamics of their connection.

Your analysis must be:
- SPECIFIC: Reference the actual aspects provided (e.g., "Your Venus trine their Mars creates...")
- MYSTICAL: Use evocative, romantic language befitting an oracle
- BALANCED: Acknowledge both positives and challenges honestly
- CONSTRUCTIVE: Frame challenges as growth opportunities

Respond in this EXACT format with three clearly labeled sections:

**CHEMISTRY:**
[2-3 sentences about physical/romantic attraction, referencing Venus/Mars aspects]

**EMOTIONAL CONNECTION:**
[2-3 sentences about emotional understanding, referencing Sun/Moon/Mercury aspects]

**CHALLENGES:**
[2-3 sentences about friction points, referencing Saturn/Pluto/square aspects. Be honest but constructive.]

Do not use emojis. Keep each section focused and insightful."""

    def _build_analysis_prompt(
        self,
        chart1: dict,
        chart2: dict,
        scores: dict,
        aspects: list
    ) -> str:
        """Build the analysis prompt with chart data."""
        # Extract key placements
        sun1 = chart1.get("sun", {}).get("sign", "Unknown")
        moon1 = chart1.get("moon", {}).get("sign", "Unknown")
        venus1 = chart1.get("venus", {}).get("sign", "Unknown")
        mars1 = chart1.get("mars", {}).get("sign", "Unknown")
        mercury1 = chart1.get("mercury", {}).get("sign", "Unknown")

        sun2 = chart2.get("sun", {}).get("sign", "Unknown")
        moon2 = chart2.get("moon", {}).get("sign", "Unknown")
        venus2 = chart2.get("venus", {}).get("sign", "Unknown")
        mars2 = chart2.get("mars", {}).get("sign", "Unknown")
        mercury2 = chart2.get("mercury", {}).get("sign", "Unknown")

        # Format aspects for the prompt
        chemistry_aspects = scores.get("chemistry_aspects", [])
        emotional_aspects = scores.get("emotional_aspects", [])
        challenge_aspects = scores.get("challenge_aspects", [])

        chemistry_list = "\n".join([
            f"  - {a['planets']} ({a['meaning']}, score: {a['score']})"
            for a in chemistry_aspects
        ]) or "  - No major chemistry aspects found"

        emotional_list = "\n".join([
            f"  - {a['planets']} ({a['meaning']}, score: {a['score']})"
            for a in emotional_aspects
        ]) or "  - No major emotional aspects found"

        challenge_list = "\n".join([
            f"  - {a['planets']} ({a['meaning']}, score: {a['score']})"
            for a in challenge_aspects
        ]) or "  - No major challenging aspects found"

        return f"""Analyze this synastry (romantic compatibility) between two people:

**PERSON 1:**
Sun: {sun1}, Moon: {moon1}, Venus: {venus1}, Mars: {mars1}, Mercury: {mercury1}

**PERSON 2:**
Sun: {sun2}, Moon: {moon2}, Venus: {venus2}, Mars: {mars2}, Mercury: {mercury2}

**COMPATIBILITY SCORES:**
- Overall: {scores.get('overall', 50)}%
- Chemistry: {scores.get('chemistry', 50)}%
- Emotional: {scores.get('emotional', 50)}%

**KEY CHEMISTRY ASPECTS (Venus/Mars):**
{chemistry_list}

**KEY EMOTIONAL ASPECTS (Sun/Moon/Mercury):**
{emotional_list}

**CHALLENGING ASPECTS (Saturn/Pluto/Squares):**
{challenge_list}

Based on these SPECIFIC aspects, provide your mystical analysis in the three sections."""

    def _parse_analysis_response(self, content: str, scores: dict) -> dict:
        """Parse the AI response into structured sections."""
        # Default values
        result = {
            "chemistry_analysis": "",
            "emotional_connection": "",
            "challenges": "",
            "summary": "",
            "scores": {
                "overall": scores.get("overall", 50),
                "chemistry": scores.get("chemistry", 50),
                "emotional": scores.get("emotional", 50),
                "intellectual": scores.get("intellectual", 50),
            }
        }

        # Try to extract sections
        content_lower = content.lower()

        # Find Chemistry section
        chem_start = content_lower.find("**chemistry")
        if chem_start == -1:
            chem_start = content_lower.find("chemistry:")

        # Find Emotional section
        emo_start = content_lower.find("**emotional")
        if emo_start == -1:
            emo_start = content_lower.find("emotional connection:")

        # Find Challenges section
        chal_start = content_lower.find("**challenges")
        if chal_start == -1:
            chal_start = content_lower.find("challenges:")

        # Extract sections
        if chem_start != -1 and emo_start != -1:
            chem_section = content[chem_start:emo_start]
            # Remove header
            chem_section = chem_section.split("\n", 1)[-1].strip() if "\n" in chem_section else chem_section
            chem_section = chem_section.replace("**CHEMISTRY:**", "").replace("**Chemistry:**", "").strip()
            result["chemistry_analysis"] = chem_section

        if emo_start != -1 and chal_start != -1:
            emo_section = content[emo_start:chal_start]
            emo_section = emo_section.split("\n", 1)[-1].strip() if "\n" in emo_section else emo_section
            emo_section = emo_section.replace("**EMOTIONAL CONNECTION:**", "").replace("**Emotional Connection:**", "").strip()
            result["emotional_connection"] = emo_section

        if chal_start != -1:
            chal_section = content[chal_start:]
            chal_section = chal_section.split("\n", 1)[-1].strip() if "\n" in chal_section else chal_section
            chal_section = chal_section.replace("**CHALLENGES:**", "").replace("**Challenges:**", "").strip()
            result["challenges"] = chal_section

        # If parsing failed, use the whole content
        if not result["chemistry_analysis"] and not result["emotional_connection"]:
            # Split by paragraphs as fallback
            paragraphs = [p.strip() for p in content.split("\n\n") if p.strip()]
            if len(paragraphs) >= 3:
                result["chemistry_analysis"] = paragraphs[0]
                result["emotional_connection"] = paragraphs[1]
                result["challenges"] = paragraphs[2]
            elif paragraphs:
                result["chemistry_analysis"] = paragraphs[0]
                result["emotional_connection"] = paragraphs[1] if len(paragraphs) > 1 else ""
                result["challenges"] = paragraphs[2] if len(paragraphs) > 2 else ""

        # Generate summary
        overall = scores.get("overall", 50)
        if overall >= 80:
            result["summary"] = "A deeply harmonious connection blessed by the stars."
        elif overall >= 65:
            result["summary"] = "A promising bond with beautiful potential for growth."
        elif overall >= 50:
            result["summary"] = "A balanced connection that requires mutual understanding."
        elif overall >= 35:
            result["summary"] = "A challenging but transformative connection."
        else:
            result["summary"] = "A relationship that demands significant inner work."

        return result

    def _get_fallback_analysis(self, chart1: dict, chart2: dict, scores: dict) -> dict:
        """Generate fallback analysis when OpenAI is not available."""
        sun1 = chart1.get("sun", {}).get("sign", "Unknown")
        sun2 = chart2.get("sun", {}).get("sign", "Unknown")
        venus1 = chart1.get("venus", {}).get("sign", "Unknown")
        venus2 = chart2.get("venus", {}).get("sign", "Unknown")
        moon1 = chart1.get("moon", {}).get("sign", "Unknown")
        moon2 = chart2.get("moon", {}).get("sign", "Unknown")

        chemistry_score = scores.get("chemistry", 50)
        emotional_score = scores.get("emotional", 50)
        overall = scores.get("overall", 50)

        # Generate chemistry analysis
        if chemistry_score >= 70:
            chemistry = f"With your Venus in {venus1} and their Venus in {venus2}, there is a natural magnetic attraction between you. The stars have aligned to create an undeniable chemistry that draws you together like moths to a flame."
        elif chemistry_score >= 50:
            chemistry = f"Your Venus in {venus1} finds intrigue in their Venus in {venus2}. While the initial spark may need kindling, there is potential for a warm and steady flame to grow between you."
        else:
            chemistry = f"Your Venus in {venus1} operates differently from their Venus in {venus2}. Physical connection may require conscious effort and patience, but this can lead to a more intentional and meaningful bond."

        # Generate emotional analysis
        if emotional_score >= 70:
            emotional = f"Your Moon in {moon1} resonates beautifully with their Moon in {moon2}. You intuitively understand each other's emotional needs, creating a safe haven where both souls can truly be themselves."
        elif emotional_score >= 50:
            emotional = f"Your Moon in {moon1} and their Moon in {moon2} speak different emotional languages. With patience and compassion, you can learn to translate each other's feelings and build deeper understanding."
        else:
            emotional = f"Your Moon in {moon1} contrasts with their Moon in {moon2}, suggesting emotional needs that may sometimes conflict. This is an invitation for growth—to expand your emotional vocabulary together."

        # Generate challenges analysis
        challenge_aspects = scores.get("challenge_aspects", [])
        if challenge_aspects:
            top_challenge = challenge_aspects[0]
            challenges = f"The {top_challenge.get('planets', 'planetary tension')} reveals an area requiring conscious attention. This aspect invites you both to grow beyond your comfort zones. Remember: the greatest love stories often emerge from overcoming challenges together."
        else:
            challenges = "While no major friction points appear in your charts, remember that all relationships require ongoing nurturing. Stay curious about each other and never stop growing together."

        # Generate summary
        if overall >= 80:
            summary = "A deeply harmonious connection blessed by the stars."
        elif overall >= 65:
            summary = "A promising bond with beautiful potential for growth."
        elif overall >= 50:
            summary = "A balanced connection that requires mutual understanding."
        elif overall >= 35:
            summary = "A challenging but transformative connection."
        else:
            summary = "A relationship that demands significant inner work."

        return {
            "chemistry_analysis": chemistry,
            "emotional_connection": emotional,
            "challenges": challenges,
            "summary": summary,
            "scores": {
                "overall": overall,
                "chemistry": chemistry_score,
                "emotional": emotional_score,
                "intellectual": scores.get("intellectual", 50),
            }
        }


# Singleton instance
_synastry_service: Optional[SynastryAnalysisService] = None


def get_synastry_service() -> SynastryAnalysisService:
    """Get or create the synastry analysis service singleton."""
    global _synastry_service
    if _synastry_service is None:
        _synastry_service = SynastryAnalysisService()
    return _synastry_service

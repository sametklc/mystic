"""
Astrology calculation service using Kerykeion (Swiss Ephemeris wrapper).
Handles natal chart calculations, synastry, transit analysis, and daily insights.
"""
import math
import os
from datetime import datetime, date
from typing import Dict, List, Optional, Tuple
from kerykeion import AstrologicalSubject, SynastryAspects
from kerykeion.aspects import NatalAspects
import httpx

# Planet symbols
PLANET_SYMBOLS = {
    "Sun": "☉",
    "Moon": "☽",
    "Mercury": "☿",
    "Venus": "♀",
    "Mars": "♂",
    "Jupiter": "♃",
    "Saturn": "♄",
    "Uranus": "♅",
    "Neptune": "♆",
    "Pluto": "♇",
    "First_House": "ASC",  # Ascendant
}

# Zodiac sign symbols
SIGN_SYMBOLS = {
    "Ari": "♈", "Tau": "♉", "Gem": "♊", "Can": "♋",
    "Leo": "♌", "Vir": "♍", "Lib": "♎", "Sco": "♏",
    "Sag": "♐", "Cap": "♑", "Aqu": "♒", "Pis": "♓"
}

# Full sign names
SIGN_NAMES = {
    "Ari": "Aries", "Tau": "Taurus", "Gem": "Gemini", "Can": "Cancer",
    "Leo": "Leo", "Vir": "Virgo", "Lib": "Libra", "Sco": "Scorpio",
    "Sag": "Sagittarius", "Cap": "Capricorn", "Aqu": "Aquarius", "Pis": "Pisces"
}

# Elements by sign
SIGN_ELEMENTS = {
    "Ari": "Fire", "Leo": "Fire", "Sag": "Fire",
    "Tau": "Earth", "Vir": "Earth", "Cap": "Earth",
    "Gem": "Air", "Lib": "Air", "Aqu": "Air",
    "Can": "Water", "Sco": "Water", "Pis": "Water"
}

# Modalities by sign
SIGN_MODALITIES = {
    "Ari": "Cardinal", "Can": "Cardinal", "Lib": "Cardinal", "Cap": "Cardinal",
    "Tau": "Fixed", "Leo": "Fixed", "Sco": "Fixed", "Aqu": "Fixed",
    "Gem": "Mutable", "Vir": "Mutable", "Sag": "Mutable", "Pis": "Mutable"
}

# Aspect symbols
ASPECT_SYMBOLS = {
    "conjunction": "☌",
    "sextile": "⚹",
    "square": "□",
    "trine": "△",
    "opposition": "☍",
    "quincunx": "⚻"
}

# Aspect harmony scores (positive = harmonious, negative = challenging)
ASPECT_HARMONY = {
    "conjunction": 5,  # Can be positive or negative depending on planets
    "sextile": 7,
    "square": -6,
    "trine": 8,
    "opposition": -5,
    "quincunx": -3
}

# House name to number mapping
HOUSE_NAME_TO_NUMBER = {
    "First_House": 1, "Second_House": 2, "Third_House": 3,
    "Fourth_House": 4, "Fifth_House": 5, "Sixth_House": 6,
    "Seventh_House": 7, "Eighth_House": 8, "Ninth_House": 9,
    "Tenth_House": 10, "Eleventh_House": 11, "Twelfth_House": 12
}

# Planet interpretations by sign
PLANET_SIGN_INTERPRETATIONS = {
    "Sun": {
        "Ari": "You are a natural leader with pioneering spirit and courage.",
        "Tau": "You seek stability and find joy in life's sensual pleasures.",
        "Gem": "Your curious mind craves communication and variety.",
        "Can": "You are deeply nurturing and emotionally intuitive.",
        "Leo": "You shine with creativity and a generous, warm heart.",
        "Vir": "You are analytical, detail-oriented, and service-driven.",
        "Lib": "You seek harmony, balance, and beautiful connections.",
        "Sco": "You possess intense depth and transformative power.",
        "Sag": "You are an optimistic seeker of truth and adventure.",
        "Cap": "You are ambitious, disciplined, and goal-oriented.",
        "Aqu": "You are innovative, humanitarian, and uniquely yourself.",
        "Pis": "You are deeply intuitive, compassionate, and artistic."
    },
    "Moon": {
        "Ari": "Your emotions are fiery and you need independence.",
        "Tau": "You crave emotional security and peaceful surroundings.",
        "Gem": "You process emotions through communication and analysis.",
        "Can": "You are deeply sensitive and naturally nurturing.",
        "Leo": "You need emotional recognition and creative expression.",
        "Vir": "You find comfort in order and being of service.",
        "Lib": "You seek emotional harmony and balanced relationships.",
        "Sco": "Your emotions run deep with intense loyalty.",
        "Sag": "You need freedom and optimism to feel emotionally fulfilled.",
        "Cap": "You are emotionally reserved but deeply responsible.",
        "Aqu": "You process emotions intellectually and need independence.",
        "Pis": "You are deeply empathic and spiritually sensitive."
    },
    "Venus": {
        "Ari": "You love the thrill of the chase and passionate connections.",
        "Tau": "You seek loyal, sensual, and stable love.",
        "Gem": "You are attracted to wit, intelligence, and variety.",
        "Can": "You seek nurturing and emotionally secure love.",
        "Leo": "You love with dramatic flair and generous warmth.",
        "Vir": "You show love through acts of service and devotion.",
        "Lib": "You seek harmonious, balanced, and beautiful partnerships.",
        "Sco": "You love intensely with deep emotional bonds.",
        "Sag": "You seek freedom and adventure in love.",
        "Cap": "You approach love with commitment and long-term vision.",
        "Aqu": "You value friendship and intellectual connection in love.",
        "Pis": "You love unconditionally with romantic idealism."
    },
    "Mars": {
        "Ari": "Your drive is fierce, direct, and competitive.",
        "Tau": "Your determination is steady and unstoppable.",
        "Gem": "Your energy is versatile and mentally agile.",
        "Can": "You fight to protect those you love.",
        "Leo": "Your passion is dramatic and heart-centered.",
        "Vir": "Your energy is precise and detail-focused.",
        "Lib": "You fight for fairness and balanced action.",
        "Sco": "Your willpower is intense and strategic.",
        "Sag": "Your drive is adventurous and optimistic.",
        "Cap": "Your ambition is disciplined and goal-oriented.",
        "Aqu": "Your energy is innovative and rebellious.",
        "Pis": "Your drive is inspired by dreams and compassion."
    }
}


class AstrologyService:
    """Service for calculating astrological charts and compatibility."""

    @staticmethod
    def create_subject(
        name: str,
        year: int,
        month: int,
        day: int,
        hour: int,
        minute: int,
        latitude: float,
        longitude: float,
        timezone: str = "UTC"
    ) -> AstrologicalSubject:
        """Create an astrological subject for calculations."""
        return AstrologicalSubject(
            name=name,
            year=year,
            month=month,
            day=day,
            hour=hour,
            minute=minute,
            lat=latitude,
            lng=longitude,
            tz_str=timezone,
            online=False  # Use local ephemeris
        )

    @staticmethod
    def parse_birth_data(date_str: str, time_str: str) -> Tuple[int, int, int, int, int]:
        """Parse date and time strings into components."""
        date = datetime.strptime(date_str, "%Y-%m-%d")
        time_parts = time_str.split(":")
        hour = int(time_parts[0])
        minute = int(time_parts[1]) if len(time_parts) > 1 else 0
        return date.year, date.month, date.day, hour, minute

    @staticmethod
    def get_planet_data(subject: AstrologicalSubject, planet_attr: str) -> dict:
        """Extract planet data from subject."""
        planet = getattr(subject, planet_attr, None)
        if planet is None:
            return None

        sign_abbr = planet.get("sign", "Ari")
        sign_name = SIGN_NAMES.get(sign_abbr, sign_abbr)
        planet_name = planet.get("name", planet_attr)

        # Handle ascendant/first house
        if planet_attr == "first_house":
            planet_name = "Ascendant"

        # Convert house name to number
        raw_house = planet.get("house", 1)
        if isinstance(raw_house, str):
            house_num = HOUSE_NAME_TO_NUMBER.get(raw_house, 1)
        else:
            house_num = raw_house if isinstance(raw_house, int) else 1

        # Handle retrograde - can be None
        is_retrograde = planet.get("retrograde", False)
        if is_retrograde is None:
            is_retrograde = False

        return {
            "planet_name": planet_name,
            "planet_symbol": PLANET_SYMBOLS.get(planet_name, "?"),
            "sign": sign_name,
            "sign_symbol": SIGN_SYMBOLS.get(sign_abbr, "?"),
            "house": house_num,
            "degree": planet.get("abs_pos", 0),
            "sign_degree": planet.get("position", 0),
            "is_retrograde": is_retrograde,
            "element": SIGN_ELEMENTS.get(sign_abbr, "Unknown"),
            "modality": SIGN_MODALITIES.get(sign_abbr, "Unknown"),
            "interpretation": AstrologyService.get_interpretation(planet_name, sign_abbr)
        }

    @staticmethod
    def get_interpretation(planet_name: str, sign_abbr: str) -> str:
        """Get interpretation text for planet in sign."""
        planet_interps = PLANET_SIGN_INTERPRETATIONS.get(planet_name, {})
        return planet_interps.get(sign_abbr, f"{planet_name} in {SIGN_NAMES.get(sign_abbr, sign_abbr)}")

    @staticmethod
    def calculate_natal_chart(
        date: str,
        time: str,
        latitude: float,
        longitude: float,
        timezone: str = "UTC",
        name: str = "Seeker"
    ) -> dict:
        """Calculate a complete natal chart."""
        year, month, day, hour, minute = AstrologyService.parse_birth_data(date, time)

        subject = AstrologyService.create_subject(
            name=name,
            year=year,
            month=month,
            day=day,
            hour=hour,
            minute=minute,
            latitude=latitude,
            longitude=longitude,
            timezone=timezone
        )

        # Extract planet positions
        sun = AstrologyService.get_planet_data(subject, "sun")
        moon = AstrologyService.get_planet_data(subject, "moon")
        rising = AstrologyService.get_planet_data(subject, "first_house")
        mercury = AstrologyService.get_planet_data(subject, "mercury")
        venus = AstrologyService.get_planet_data(subject, "venus")
        mars = AstrologyService.get_planet_data(subject, "mars")
        jupiter = AstrologyService.get_planet_data(subject, "jupiter")
        saturn = AstrologyService.get_planet_data(subject, "saturn")
        uranus = AstrologyService.get_planet_data(subject, "uranus")
        neptune = AstrologyService.get_planet_data(subject, "neptune")
        pluto = AstrologyService.get_planet_data(subject, "pluto")

        # Calculate aspects
        try:
            natal_aspects = NatalAspects(subject)
            aspects = AstrologyService.format_aspects(natal_aspects.relevant_aspects)
        except Exception:
            aspects = []

        # Generate summary
        sun_moon_rising_summary = AstrologyService.generate_big_three_summary(sun, moon, rising)

        return {
            "name": name,
            "birth_datetime": f"{date} {time}",
            "location": {"latitude": latitude, "longitude": longitude, "timezone": timezone},
            "sun": sun,
            "moon": moon,
            "rising": rising,
            "mercury": mercury,
            "venus": venus,
            "mars": mars,
            "jupiter": jupiter,
            "saturn": saturn,
            "uranus": uranus,
            "neptune": neptune,
            "pluto": pluto,
            "aspects": aspects,
            "sun_moon_rising_summary": sun_moon_rising_summary
        }

    @staticmethod
    def format_aspects(aspects_list: list) -> list:
        """Format aspects into response structure."""
        formatted = []
        for aspect in aspects_list[:15]:  # Limit to 15 most relevant
            aspect_type = aspect.get("aspect", "conjunction").lower()
            formatted.append({
                "planet1": aspect.get("p1_name", ""),
                "planet2": aspect.get("p2_name", ""),
                "aspect_type": aspect_type,
                "aspect_symbol": ASPECT_SYMBOLS.get(aspect_type, "?"),
                "orb": round(aspect.get("orbit", 0), 2),
                "is_applying": aspect.get("is_applying", False),
                "interpretation": f"{aspect.get('p1_name', '')} {aspect_type} {aspect.get('p2_name', '')}"
            })
        return formatted

    @staticmethod
    def generate_big_three_summary(sun: dict, moon: dict, rising: dict) -> str:
        """Generate a summary of the Big Three (Sun, Moon, Rising)."""
        sun_sign = sun.get("sign", "Unknown")
        moon_sign = moon.get("sign", "Unknown")
        rising_sign = rising.get("sign", "Unknown") if rising else "Unknown"

        return (
            f"Your core identity shines as a {sun_sign} Sun, bringing {AstrologyService.get_sun_keyword(sun_sign)}. "
            f"Emotionally, your {moon_sign} Moon gives you {AstrologyService.get_moon_keyword(moon_sign)}. "
            f"The world sees you through your {rising_sign} Rising, projecting {AstrologyService.get_rising_keyword(rising_sign)}."
        )

    @staticmethod
    def get_sun_keyword(sign: str) -> str:
        keywords = {
            "Aries": "courage and initiative",
            "Taurus": "stability and determination",
            "Gemini": "curiosity and adaptability",
            "Cancer": "nurturing and intuition",
            "Leo": "creativity and warmth",
            "Virgo": "precision and service",
            "Libra": "harmony and diplomacy",
            "Scorpio": "intensity and transformation",
            "Sagittarius": "optimism and adventure",
            "Capricorn": "ambition and discipline",
            "Aquarius": "innovation and independence",
            "Pisces": "compassion and imagination"
        }
        return keywords.get(sign, "unique energy")

    @staticmethod
    def get_moon_keyword(sign: str) -> str:
        keywords = {
            "Aries": "passionate reactions",
            "Taurus": "emotional stability",
            "Gemini": "mental processing",
            "Cancer": "deep sensitivity",
            "Leo": "dramatic expression",
            "Virgo": "analytical feelings",
            "Libra": "harmonious needs",
            "Scorpio": "intense depths",
            "Sagittarius": "optimistic outlook",
            "Capricorn": "reserved emotions",
            "Aquarius": "detached perspective",
            "Pisces": "empathic absorption"
        }
        return keywords.get(sign, "emotional depth")

    @staticmethod
    def get_rising_keyword(sign: str) -> str:
        keywords = {
            "Aries": "bold confidence",
            "Taurus": "calm reliability",
            "Gemini": "witty charm",
            "Cancer": "nurturing warmth",
            "Leo": "magnetic presence",
            "Virgo": "modest competence",
            "Libra": "graceful diplomacy",
            "Scorpio": "mysterious intensity",
            "Sagittarius": "jovial optimism",
            "Capricorn": "serious authority",
            "Aquarius": "unique individuality",
            "Pisces": "dreamy sensitivity"
        }
        return keywords.get(sign, "distinctive style")

    @staticmethod
    def calculate_synastry(
        user1_data: dict,
        user2_data: dict
    ) -> dict:
        """Calculate synastry compatibility between two charts."""
        # Parse both users' data
        y1, m1, d1, h1, min1 = AstrologyService.parse_birth_data(
            user1_data["date"], user1_data["time"]
        )
        y2, m2, d2, h2, min2 = AstrologyService.parse_birth_data(
            user2_data["date"], user2_data["time"]
        )

        # Create subjects
        subject1 = AstrologyService.create_subject(
            name=user1_data.get("name", "Person 1"),
            year=y1, month=m1, day=d1, hour=h1, minute=min1,
            latitude=user1_data["latitude"],
            longitude=user1_data["longitude"],
            timezone=user1_data.get("timezone", "UTC")
        )

        subject2 = AstrologyService.create_subject(
            name=user2_data.get("name", "Person 2"),
            year=y2, month=m2, day=d2, hour=h2, minute=min2,
            latitude=user2_data["latitude"],
            longitude=user2_data["longitude"],
            timezone=user2_data.get("timezone", "UTC")
        )

        # Get individual charts
        chart1 = AstrologyService.calculate_natal_chart(
            date=user1_data["date"],
            time=user1_data["time"],
            latitude=user1_data["latitude"],
            longitude=user1_data["longitude"],
            timezone=user1_data.get("timezone", "UTC"),
            name=user1_data.get("name", "Person 1")
        )

        chart2 = AstrologyService.calculate_natal_chart(
            date=user2_data["date"],
            time=user2_data["time"],
            latitude=user2_data["latitude"],
            longitude=user2_data["longitude"],
            timezone=user2_data.get("timezone", "UTC"),
            name=user2_data.get("name", "Person 2")
        )

        # Calculate synastry aspects
        try:
            synastry = SynastryAspects(subject1, subject2)
            synastry_aspects = AstrologyService.format_synastry_aspects(synastry.relevant_aspects)
        except Exception as e:
            print(f"Synastry calculation error: {e}")
            synastry_aspects = AstrologyService.calculate_manual_synastry(chart1, chart2)

        # Calculate compatibility scores
        scores = AstrologyService.calculate_compatibility_scores(synastry_aspects, chart1, chart2)

        # Generate AI prompt
        ai_prompt = AstrologyService.generate_synastry_prompt(chart1, chart2, synastry_aspects, scores)

        return {
            "user1_name": user1_data.get("name", "Person 1"),
            "user2_name": user2_data.get("name", "Person 2"),
            "compatibility_score": scores["overall"],
            "emotional_compatibility": scores["emotional"],
            "intellectual_compatibility": scores["intellectual"],
            "physical_compatibility": scores["physical"],
            "spiritual_compatibility": scores["spiritual"],
            "key_aspects": synastry_aspects,
            "harmonious_aspects_count": scores["harmonious_count"],
            "challenging_aspects_count": scores["challenging_count"],
            "user1_chart": chart1,
            "user2_chart": chart2,
            "ai_summary_prompt": ai_prompt,
            "ai_summary": None  # To be filled by OpenAI
        }

    @staticmethod
    def format_synastry_aspects(aspects_list: list) -> list:
        """Format synastry aspects with compatibility interpretations."""
        formatted = []
        for aspect in aspects_list[:20]:
            aspect_type = aspect.get("aspect", "conjunction").lower()
            harmony = ASPECT_HARMONY.get(aspect_type, 0)

            p1 = aspect.get("p1_name", "")
            p2 = aspect.get("p2_name", "")

            formatted.append({
                "person1_planet": p1,
                "person2_planet": p2,
                "aspect_type": aspect_type,
                "aspect_symbol": ASPECT_SYMBOLS.get(aspect_type, "?"),
                "orb": round(aspect.get("orbit", 0), 2),
                "harmony_score": harmony,
                "interpretation": AstrologyService.get_synastry_interpretation(p1, p2, aspect_type)
            })
        return formatted

    @staticmethod
    def calculate_manual_synastry(chart1: dict, chart2: dict) -> list:
        """Calculate synastry aspects manually if library fails."""
        aspects = []
        planets = ["sun", "moon", "venus", "mars", "mercury"]
        aspect_angles = {
            "conjunction": (0, 8),
            "sextile": (60, 6),
            "square": (90, 6),
            "trine": (120, 8),
            "opposition": (180, 8)
        }

        for p1 in planets:
            for p2 in planets:
                if chart1.get(p1) and chart2.get(p2):
                    deg1 = chart1[p1].get("degree", 0)
                    deg2 = chart2[p2].get("degree", 0)
                    diff = abs(deg1 - deg2)
                    if diff > 180:
                        diff = 360 - diff

                    for aspect_name, (angle, orb) in aspect_angles.items():
                        if abs(diff - angle) <= orb:
                            harmony = ASPECT_HARMONY.get(aspect_name, 0)
                            aspects.append({
                                "person1_planet": chart1[p1]["planet_name"],
                                "person2_planet": chart2[p2]["planet_name"],
                                "aspect_type": aspect_name,
                                "aspect_symbol": ASPECT_SYMBOLS.get(aspect_name, "?"),
                                "orb": round(abs(diff - angle), 2),
                                "harmony_score": harmony,
                                "interpretation": AstrologyService.get_synastry_interpretation(
                                    chart1[p1]["planet_name"],
                                    chart2[p2]["planet_name"],
                                    aspect_name
                                )
                            })
                            break

        return aspects

    @staticmethod
    def get_synastry_interpretation(planet1: str, planet2: str, aspect: str) -> str:
        """Get interpretation for synastry aspect."""
        harmony_words = {
            "conjunction": "merges with",
            "trine": "flows harmoniously with",
            "sextile": "supports",
            "square": "challenges",
            "opposition": "balances or conflicts with"
        }
        action = harmony_words.get(aspect, "connects with")

        special_combos = {
            ("Venus", "Mars"): {
                "trine": "Powerful magnetic attraction and physical chemistry.",
                "conjunction": "Intense physical and romantic attraction.",
                "square": "Passionate but potentially volatile chemistry."
            },
            ("Sun", "Moon"): {
                "trine": "Deep understanding between identity and emotions.",
                "conjunction": "Strong soul connection and mutual understanding."
            },
            ("Moon", "Moon"): {
                "trine": "Emotional wavelengths are beautifully in sync.",
                "conjunction": "You feel each other's emotions deeply."
            },
            ("Venus", "Venus"): {
                "trine": "Shared values and similar ways of loving.",
                "conjunction": "Nearly identical love languages."
            }
        }

        # Check for special combinations
        key = (planet1, planet2)
        reverse_key = (planet2, planet1)
        if key in special_combos and aspect in special_combos[key]:
            return special_combos[key][aspect]
        if reverse_key in special_combos and aspect in special_combos[reverse_key]:
            return special_combos[reverse_key][aspect]

        return f"{planet1} {action} {planet2}."

    @staticmethod
    def calculate_compatibility_scores(aspects: list, chart1: dict, chart2: dict) -> dict:
        """Calculate detailed compatibility scores."""
        total_harmony = 0
        emotional_score = 50
        intellectual_score = 50
        physical_score = 50
        spiritual_score = 50
        harmonious_count = 0
        challenging_count = 0

        emotional_planets = ["Moon", "Venus", "Neptune"]
        intellectual_planets = ["Mercury", "Jupiter", "Uranus"]
        physical_planets = ["Mars", "Venus", "Sun"]
        spiritual_planets = ["Neptune", "Jupiter", "Pluto"]

        for aspect in aspects:
            harmony = aspect.get("harmony_score", 0)
            total_harmony += harmony
            p1 = aspect.get("person1_planet", "")
            p2 = aspect.get("person2_planet", "")

            if harmony > 0:
                harmonious_count += 1
            elif harmony < 0:
                challenging_count += 1

            # Adjust category scores
            if p1 in emotional_planets or p2 in emotional_planets:
                emotional_score += harmony * 3
            if p1 in intellectual_planets or p2 in intellectual_planets:
                intellectual_score += harmony * 3
            if p1 in physical_planets or p2 in physical_planets:
                physical_score += harmony * 3
            if p1 in spiritual_planets or p2 in spiritual_planets:
                spiritual_score += harmony * 3

        # Element compatibility bonus
        sun1_elem = chart1.get("sun", {}).get("element", "")
        sun2_elem = chart2.get("sun", {}).get("element", "")
        if sun1_elem == sun2_elem:
            total_harmony += 10
        elif (sun1_elem in ["Fire", "Air"] and sun2_elem in ["Fire", "Air"]) or \
             (sun1_elem in ["Earth", "Water"] and sun2_elem in ["Earth", "Water"]):
            total_harmony += 5

        # Normalize scores to 0-100
        def normalize(score):
            return max(0, min(100, int(score)))

        # Calculate overall from total harmony
        base_score = 50 + (total_harmony * 2)
        overall = normalize(base_score)

        return {
            "overall": overall,
            "emotional": normalize(emotional_score),
            "intellectual": normalize(intellectual_score),
            "physical": normalize(physical_score),
            "spiritual": normalize(spiritual_score),
            "harmonious_count": harmonious_count,
            "challenging_count": challenging_count
        }

    @staticmethod
    def generate_synastry_prompt(chart1: dict, chart2: dict, aspects: list, scores: dict) -> str:
        """Generate a prompt for AI to create a detailed interpretation."""
        sun1 = chart1.get("sun", {}).get("sign", "Unknown")
        moon1 = chart1.get("moon", {}).get("sign", "Unknown")
        venus1 = chart1.get("venus", {}).get("sign", "Unknown")
        mars1 = chart1.get("mars", {}).get("sign", "Unknown")

        sun2 = chart2.get("sun", {}).get("sign", "Unknown")
        moon2 = chart2.get("moon", {}).get("sign", "Unknown")
        venus2 = chart2.get("venus", {}).get("sign", "Unknown")
        mars2 = chart2.get("mars", {}).get("sign", "Unknown")

        top_aspects = [
            f"{a['person1_planet']} {a['aspect_type']} {a['person2_planet']}"
            for a in aspects[:5]
        ]

        return f"""Provide a romantic and mystical synastry interpretation for this couple:

Person 1: Sun in {sun1}, Moon in {moon1}, Venus in {venus1}, Mars in {mars1}
Person 2: Sun in {sun2}, Moon in {moon2}, Venus in {venus2}, Mars in {mars2}

Compatibility Score: {scores['overall']}%
Key Aspects: {', '.join(top_aspects)}

Emotional: {scores['emotional']}% | Physical: {scores['physical']}% | Intellectual: {scores['intellectual']}%

Write a 3-paragraph mystical interpretation covering:
1. Overall connection and soul chemistry
2. Strengths of this union
3. Areas for growth and awareness

Keep the tone enchanting and insightful, like a wise oracle."""

    # =========================================================================
    # Daily Cosmic Insight Methods
    # =========================================================================

    @staticmethod
    def calculate_moon_phase(sun_longitude: float, moon_longitude: float) -> dict:
        """
        Calculate the current moon phase based on Sun and Moon positions.

        Returns phase name, illumination percentage, and icon identifier.

        Uses ±5° tolerance for major phases (New Moon, First Quarter, Full Moon,
        Last Quarter) to match user perception. For example, at 176° (98% illumination),
        users perceive a Full Moon, not Waxing Gibbous.
        """
        # Calculate the angle between Moon and Sun
        phase_angle = (moon_longitude - sun_longitude) % 360

        # Calculate illumination percentage
        # 0° = New Moon (0%), 180° = Full Moon (100%)
        if phase_angle <= 180:
            illumination = phase_angle / 180 * 100
        else:
            illumination = (360 - phase_angle) / 180 * 100

        # Major phase tolerance (±5 degrees)
        MAJOR_TOLERANCE = 5.0

        # Major phases at exact angles
        MAJOR_PHASES = {
            0: {"name": "New Moon", "icon": "new_moon"},
            90: {"name": "First Quarter", "icon": "first_quarter"},
            180: {"name": "Full Moon", "icon": "full_moon"},
            270: {"name": "Last Quarter", "icon": "last_quarter"},
        }

        # Check if we're within tolerance of a major phase
        for angle, phase_info in MAJOR_PHASES.items():
            # Calculate angular distance (handle wrap-around at 0°/360°)
            diff = abs(phase_angle - angle)
            if diff > 180:
                diff = 360 - diff

            if diff <= MAJOR_TOLERANCE:
                return {
                    "name": phase_info["name"],
                    "icon": phase_info["icon"],
                    "illumination": round(illumination, 1),
                    "phase_angle": round(phase_angle, 1),
                }

        # Intermediate phases (between major phases, outside tolerance zones)
        # These ranges exclude the ±5° tolerance zones around major phases
        intermediate_phases = [
            # After New Moon tolerance (5°) to before First Quarter tolerance (85°)
            {"name": "Waxing Crescent", "icon": "waxing_crescent", "range": (5, 85)},
            # After First Quarter tolerance (95°) to before Full Moon tolerance (175°)
            {"name": "Waxing Gibbous", "icon": "waxing_gibbous", "range": (95, 175)},
            # After Full Moon tolerance (185°) to before Last Quarter tolerance (265°)
            {"name": "Waning Gibbous", "icon": "waning_gibbous", "range": (185, 265)},
            # After Last Quarter tolerance (275°) to before New Moon tolerance (355°)
            {"name": "Waning Crescent", "icon": "waning_crescent", "range": (275, 355)},
        ]

        for phase in intermediate_phases:
            if phase["range"][0] <= phase_angle < phase["range"][1]:
                return {
                    "name": phase["name"],
                    "icon": phase["icon"],
                    "illumination": round(illumination, 1),
                    "phase_angle": round(phase_angle, 1),
                }

        # Fallback (should not reach here with proper ranges)
        return {
            "name": "New Moon",
            "icon": "new_moon",
            "illumination": round(illumination, 1),
            "phase_angle": round(phase_angle, 1),
        }

    @staticmethod
    def check_mercury_retrograde(mercury_data: dict) -> dict:
        """Check if Mercury is retrograde and return status."""
        is_retrograde = mercury_data.get("is_retrograde", False)

        return {
            "is_retrograde": is_retrograde,
            "status": "Retrograde" if is_retrograde else "Direct",
            "message": (
                "Mercury is retrograde - take care with communications and travel."
                if is_retrograde
                else "Mercury is direct - clear skies for communication."
            ),
        }

    @staticmethod
    def get_current_sky_data(target_date: date = None) -> dict:
        """
        Get the current positions of celestial bodies for the given date.

        Uses a default location (0,0) as we only care about planetary positions,
        not house placements for daily insight.
        """
        if target_date is None:
            target_date = date.today()

        # Create a subject for the current moment (using UTC noon)
        subject = AstrologyService.create_subject(
            name="Current Sky",
            year=target_date.year,
            month=target_date.month,
            day=target_date.day,
            hour=12,  # Noon UTC
            minute=0,
            latitude=0.0,  # Equator - neutral for planetary positions
            longitude=0.0,
            timezone="UTC",
        )

        # Extract Sun and Moon data
        sun_data = AstrologyService.get_planet_data(subject, "sun")
        moon_data = AstrologyService.get_planet_data(subject, "moon")
        mercury_data = AstrologyService.get_planet_data(subject, "mercury")
        venus_data = AstrologyService.get_planet_data(subject, "venus")
        mars_data = AstrologyService.get_planet_data(subject, "mars")

        # Calculate moon phase
        sun_degree = sun_data.get("degree", 0) if sun_data else 0
        moon_degree = moon_data.get("degree", 0) if moon_data else 0
        moon_phase = AstrologyService.calculate_moon_phase(sun_degree, moon_degree)

        # Check Mercury retrograde
        mercury_status = AstrologyService.check_mercury_retrograde(mercury_data or {})

        # Get moon sign
        moon_sign = moon_data.get("sign", "Unknown") if moon_data else "Unknown"
        moon_sign_abbr = None
        for abbr, name in SIGN_NAMES.items():
            if name == moon_sign:
                moon_sign_abbr = abbr
                break

        return {
            "date": target_date.isoformat(),
            "moon_phase": moon_phase,
            "moon_sign": moon_sign,
            "moon_sign_symbol": SIGN_SYMBOLS.get(moon_sign_abbr, "☽"),
            "moon_element": SIGN_ELEMENTS.get(moon_sign_abbr, "Unknown"),
            "mercury_status": mercury_status,
            "sun_sign": sun_data.get("sign", "Unknown") if sun_data else "Unknown",
            "venus_sign": venus_data.get("sign", "Unknown") if venus_data else "Unknown",
            "mars_sign": mars_data.get("sign", "Unknown") if mars_data else "Unknown",
        }

    @staticmethod
    async def generate_daily_advice(sky_data: dict) -> str:
        """
        Generate mystical daily advice using OpenAI GPT-4o-mini.

        Falls back to pre-written advice if OpenAI is not available.
        """
        openai_key = os.getenv("OPENAI_API_KEY")

        if not openai_key:
            # Fallback to element-based advice
            return AstrologyService.get_fallback_advice(sky_data)

        # Construct the sky context
        moon_phase = sky_data["moon_phase"]["name"]
        moon_sign = sky_data["moon_sign"]
        mercury_status = sky_data["mercury_status"]["status"]
        moon_element = sky_data["moon_element"]

        prompt = f"""Current Cosmic Weather:
- Moon Phase: {moon_phase}
- Moon in {moon_sign} ({moon_element} element)
- Mercury is {mercury_status}

You are a mystic oracle. Give ONE sentence of esoteric, poetic advice for today based on this celestial energy. Keep it mysterious, evocative, and relevant to the cosmic influences. Do not use emojis. Maximum 25 words."""

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {openai_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "gpt-4o-mini",
                        "messages": [
                            {
                                "role": "system",
                                "content": "You are a mystical oracle who speaks in cryptic but meaningful wisdom. Your advice should feel ancient and profound.",
                            },
                            {"role": "user", "content": prompt},
                        ],
                        "max_tokens": 100,
                        "temperature": 0.8,
                    },
                    timeout=10.0,
                )

                if response.status_code == 200:
                    data = response.json()
                    advice = data["choices"][0]["message"]["content"].strip()
                    # Clean up any quotes
                    advice = advice.strip('"\'')
                    return advice
                else:
                    print(f"OpenAI API error: {response.status_code}")
                    return AstrologyService.get_fallback_advice(sky_data)

        except Exception as e:
            print(f"Error generating daily advice: {e}")
            return AstrologyService.get_fallback_advice(sky_data)

    @staticmethod
    def get_fallback_advice(sky_data: dict) -> str:
        """
        Generate fallback advice based on moon phase and element.
        Used when OpenAI is unavailable.
        """
        moon_phase = sky_data["moon_phase"]["name"]
        moon_element = sky_data["moon_element"]

        phase_advice = {
            "New Moon": "Seeds planted in darkness grow strongest toward the light.",
            "Waxing Crescent": "Small steps taken now ripple into great journeys ahead.",
            "First Quarter": "Face the tension—growth awaits on the other side of resistance.",
            "Waxing Gibbous": "Refine your intentions; the cosmos rewards precision.",
            "Full Moon": "What was hidden now stands illuminated—embrace the revelation.",
            "Waning Gibbous": "Share your wisdom; teaching deepens understanding.",
            "Last Quarter": "Release what no longer serves; make room for what is to come.",
            "Waning Crescent": "Rest in the quiet darkness; renewal approaches with the dawn.",
        }

        element_modifier = {
            "Fire": "Let passion guide but not consume.",
            "Earth": "Ground yourself in what is real and lasting.",
            "Air": "Let your thoughts flow like the wind—free but purposeful.",
            "Water": "Trust the currents of intuition today.",
        }

        base_advice = phase_advice.get(moon_phase, "The stars whisper secrets to those who listen.")
        modifier = element_modifier.get(moon_element, "")

        if modifier:
            return f"{base_advice} {modifier}"
        return base_advice

    @staticmethod
    async def get_daily_insight(target_date: date = None) -> dict:
        """
        Get complete daily cosmic insight including moon phase, sign, and advice.

        This is the main method for the daily insight feature.
        """
        if target_date is None:
            target_date = date.today()

        # Get current sky data
        sky_data = AstrologyService.get_current_sky_data(target_date)

        # Generate mystical advice
        advice = await AstrologyService.generate_daily_advice(sky_data)

        return {
            "date": sky_data["date"],
            "moon_phase": sky_data["moon_phase"]["name"],
            "moon_phase_icon": sky_data["moon_phase"]["icon"],
            "moon_illumination": sky_data["moon_phase"]["illumination"],
            "moon_sign": sky_data["moon_sign"],
            "moon_sign_symbol": sky_data["moon_sign_symbol"],
            "moon_element": sky_data["moon_element"],
            "mercury_retrograde": sky_data["mercury_status"]["is_retrograde"],
            "mercury_status": sky_data["mercury_status"]["status"],
            "advice": advice,
            "sun_sign": sky_data["sun_sign"],
        }

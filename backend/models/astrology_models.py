"""
Pydantic models for the Astrology (Sky Hall) module.
"""
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class NatalChartRequest(BaseModel):
    """Request model for natal chart calculation."""
    date: str = Field(..., description="Birth date in YYYY-MM-DD format")
    time: str = Field(..., description="Birth time in HH:MM format (24h)")
    latitude: float = Field(..., description="Birth location latitude")
    longitude: float = Field(..., description="Birth location longitude")
    timezone: str = Field(default="UTC", description="Timezone string e.g. 'Europe/Istanbul'")
    name: Optional[str] = Field(default=None, description="Person's name")

    class Config:
        json_schema_extra = {
            "example": {
                "date": "1990-06-15",
                "time": "14:30",
                "latitude": 41.0082,
                "longitude": 28.9784,
                "timezone": "Europe/Istanbul",
                "name": "Seeker"
            }
        }


class PlanetPosition(BaseModel):
    """Position of a celestial body in the natal chart."""
    planet_name: str = Field(..., description="Name of the planet")
    planet_symbol: str = Field(..., description="Unicode symbol for the planet")
    sign: str = Field(..., description="Zodiac sign name")
    sign_symbol: str = Field(..., description="Unicode symbol for the sign")
    house: int = Field(..., ge=1, le=12, description="House number (1-12)")
    degree: float = Field(..., ge=0, lt=360, description="Absolute degree in zodiac (0-360)")
    sign_degree: float = Field(..., ge=0, lt=30, description="Degree within the sign (0-30)")
    is_retrograde: bool = Field(default=False, description="Whether planet is in retrograde")
    element: str = Field(..., description="Fire, Earth, Air, or Water")
    modality: str = Field(..., description="Cardinal, Fixed, or Mutable")
    interpretation: Optional[str] = Field(default=None, description="Brief interpretation")


class HousePosition(BaseModel):
    """Position of a house cusp."""
    house_number: int = Field(..., ge=1, le=12)
    sign: str
    degree: float


class Aspect(BaseModel):
    """An aspect between two planets."""
    planet1: str
    planet2: str
    aspect_type: str = Field(..., description="conjunction, sextile, square, trine, opposition")
    aspect_symbol: str
    orb: float = Field(..., description="Orb in degrees")
    is_applying: bool = Field(default=False, description="Whether aspect is applying or separating")
    interpretation: Optional[str] = None


class NatalChartResponse(BaseModel):
    """Complete natal chart response."""
    name: Optional[str] = None
    birth_datetime: str
    location: dict

    # Main positions
    sun: PlanetPosition
    moon: PlanetPosition
    rising: PlanetPosition  # Ascendant
    mercury: PlanetPosition
    venus: PlanetPosition
    mars: PlanetPosition
    jupiter: PlanetPosition
    saturn: PlanetPosition

    # Optional outer planets
    uranus: Optional[PlanetPosition] = None
    neptune: Optional[PlanetPosition] = None
    pluto: Optional[PlanetPosition] = None

    # Additional data
    houses: Optional[List[HousePosition]] = None
    aspects: Optional[List[Aspect]] = None

    # Interpretation
    sun_moon_rising_summary: Optional[str] = None


class SynastryRequest(BaseModel):
    """Request model for synastry (compatibility) calculation."""
    user1: NatalChartRequest = Field(..., description="First person's birth data")
    user2: NatalChartRequest = Field(..., description="Second person's birth data")


class SynastryAspect(BaseModel):
    """An aspect between planets of two different charts."""
    person1_planet: str
    person2_planet: str
    aspect_type: str
    aspect_symbol: str
    orb: float
    harmony_score: int = Field(..., ge=-10, le=10, description="Positive = harmonious, Negative = challenging")
    interpretation: str


class SynastryReport(BaseModel):
    """Complete synastry compatibility report."""
    user1_name: Optional[str] = None
    user2_name: Optional[str] = None

    # Overall compatibility
    compatibility_score: int = Field(..., ge=0, le=100, description="Overall compatibility percentage")

    # Category scores
    emotional_compatibility: int = Field(..., ge=0, le=100)
    intellectual_compatibility: int = Field(..., ge=0, le=100)
    physical_compatibility: int = Field(..., ge=0, le=100)
    spiritual_compatibility: int = Field(..., ge=0, le=100)

    # Key aspects
    key_aspects: List[SynastryAspect]
    harmonious_aspects_count: int
    challenging_aspects_count: int

    # Charts for visualization
    user1_chart: NatalChartResponse
    user2_chart: NatalChartResponse

    # AI interpretation prompt (to be sent to OpenAI)
    ai_summary_prompt: str
    ai_summary: Optional[str] = None


class TransitRequest(BaseModel):
    """Request for current planetary transits."""
    natal_chart: NatalChartRequest
    transit_date: Optional[str] = Field(default=None, description="Date for transits, defaults to now")


class DailyHoroscopeRequest(BaseModel):
    """Request for daily horoscope."""
    sun_sign: str
    moon_sign: Optional[str] = None
    rising_sign: Optional[str] = None

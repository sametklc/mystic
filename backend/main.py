"""
Mystic Tarot Backend API
FastAPI server for AI-powered tarot readings using Replicate.
Deployed on Render, connected to Firebase.
"""

import os
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Astrology
from models.astrology_models import (
    NatalChartRequest, NatalChartResponse,
    SynastryRequest, SynastryReport, DetailedAnalysis
)
from services.astrology_service import AstrologyService
from services.synastry_analysis_service import get_synastry_service

# Tarot Interpretation
from services.tarot_service import get_tarot_service

# Firebase Admin SDK
import firebase_admin
from firebase_admin import credentials, firestore

# Replicate for AI image generation
import replicate


# =============================================================================
# Configuration
# =============================================================================

def get_firebase_credentials():
    """Load Firebase credentials from environment or file."""
    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
    if cred_path and os.path.exists(cred_path):
        return credentials.Certificate(cred_path)

    # For production: use environment variable with JSON string
    # Check multiple possible env var names
    cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON") or os.getenv("FIREBASE_CREDENTIALS")
    if cred_json:
        import json
        try:
            cred_dict = json.loads(cred_json)
            return credentials.Certificate(cred_dict)
        except json.JSONDecodeError as e:
            print(f"[Firebase] Failed to parse credentials JSON: {e}")
            return None

    return None


# =============================================================================
# Lifespan & App Initialization
# =============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler for startup/shutdown."""
    # Startup
    print("Starting Mystic Tarot API...")

    # Initialize Firebase (if credentials available)
    firebase_cred = get_firebase_credentials()
    if firebase_cred and not firebase_admin._apps:
        firebase_admin.initialize_app(firebase_cred)
        app.state.db = firestore.client()
        print("Firebase initialized successfully")

        # Initialize HoroscopeCacheService with Firestore
        from services.cache_service import HoroscopeCacheService
        HoroscopeCacheService.set_firestore_db(app.state.db)
        print("HoroscopeCacheService initialized with Firestore")

        # Initialize AstroChatService with Firestore
        from services.astro_chat_service import init_astro_chat_service
        init_astro_chat_service(app.state.db)
        print("AstroChatService initialized with Firestore")
    else:
        app.state.db = None
        print("Firebase not configured - running in mock mode")

    # Verify Replicate API token
    replicate_token = os.getenv("REPLICATE_API_TOKEN")
    if replicate_token:
        print("Replicate API configured")
    else:
        print("Replicate API not configured - running in mock mode")

    yield

    # Shutdown
    print("Shutting down Mystic Tarot API...")


app = FastAPI(
    title="Mystic Tarot API",
    description="AI-powered tarot reading backend with image generation",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:8080",
        "https://*.web.app",  # Firebase Hosting
        "https://*.firebaseapp.com",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =============================================================================
# Request/Response Models
# =============================================================================

class TarotVisualizationRequest(BaseModel):
    """Request model for tarot card visualization."""
    prompt: str = Field(
        ...,
        min_length=10,
        max_length=500,
        description="Description of the tarot vision to visualize",
        examples=["A mystical moon rising over an ancient temple, ethereal purple glow"]
    )
    style: Optional[str] = Field(
        default="mystical",
        description="Art style for the visualization",
        examples=["mystical", "dark", "ethereal", "cosmic"]
    )
    character_id: Optional[str] = Field(
        default=None,
        description="Character ID to influence the style"
    )


class TarotVisualizationResponse(BaseModel):
    """Response model for tarot card visualization."""
    success: bool
    image_url: Optional[str] = None
    prompt_used: str
    error: Optional[str] = None


class TarotReadingRequest(BaseModel):
    """Request model for AI tarot reading."""
    question: str = Field(
        default="",
        max_length=300,
        description="The seeker's question (empty for general reading)"
    )
    character_id: str = Field(
        default="madame_luna",
        description="The tarot reader character"
    )
    spread_type: str = Field(
        default="single",
        description="Type of spread: single, three_card, celtic_cross"
    )
    cards: list[str] = Field(
        default=[],
        description="List of drawn card names"
    )
    card_name: Optional[str] = Field(
        default=None,
        description="Primary card name for single card reading"
    )
    is_upright: bool = Field(
        default=True,
        description="Whether the card is upright or reversed"
    )
    # User preferences for personalized readings
    knowledge_level: Optional[str] = Field(
        default=None,
        description="User's esoteric knowledge level: novice, seeker, or adept"
    )
    preferred_tone: Optional[str] = Field(
        default=None,
        description="User's preferred reading tone: gentle or brutal"
    )
    gender: Optional[str] = Field(
        default=None,
        description="User's gender for pronoun usage: female, male, or other"
    )


class TarotReadingResponse(BaseModel):
    """Response model for AI tarot reading."""
    success: bool
    reading: Optional[str] = None
    character_id: str
    cards_interpreted: list[str] = []
    error: Optional[str] = None


# =============================================================================
# Style Mappings
# =============================================================================

CHARACTER_STYLE_PROMPTS = {
    "madame_luna": "soft purple moonlight, intuitive feminine energy, romantic atmosphere",
    "elder_weiss": "golden ancient wisdom, scholarly mysticism, warm candlelit ambiance",
    "nova": "futuristic cosmic, digital starfield, cyan neon accents, sci-fi mysticism",
    "shadow": "dark dramatic, blood red accents, brutal honesty, stark contrasts",
}

STYLE_MODIFIERS = {
    "mystical": "ethereal, magical, otherworldly, soft glowing auras",
    "dark": "moody, shadowy, dramatic lighting, mysterious",
    "ethereal": "dreamlike, translucent, floating, celestial",
    "cosmic": "starfield, nebula colors, infinite space, astral",
}


# =============================================================================
# API Endpoints
# =============================================================================

@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "online",
        "service": "Mystic Tarot API",
        "version": "1.0.0",
    }


@app.get("/health")
async def health_check():
    """Detailed health check."""
    tarot_service = get_tarot_service()
    return {
        "status": "healthy",
        "firebase": app.state.db is not None,
        "replicate": os.getenv("REPLICATE_API_TOKEN") is not None,
        "openai": tarot_service.is_configured,
    }


@app.post("/tarot/visualize", response_model=TarotVisualizationResponse)
async def visualize_tarot(request: TarotVisualizationRequest):
    """
    Generate a mystical visualization for a tarot reading.
    Uses Replicate's Stable Diffusion or FLUX model.
    """
    try:
        # Build enhanced prompt
        base_prompt = request.prompt
        style_mod = STYLE_MODIFIERS.get(request.style, STYLE_MODIFIERS["mystical"])
        character_mod = CHARACTER_STYLE_PROMPTS.get(
            request.character_id,
            CHARACTER_STYLE_PROMPTS["madame_luna"]
        )

        enhanced_prompt = (
            f"{base_prompt}, {style_mod}, {character_mod}, "
            "tarot card art style, intricate details, high quality, 4k"
        )

        # Check if Replicate is configured
        replicate_token = os.getenv("REPLICATE_API_TOKEN")

        if not replicate_token:
            # Mock response for development
            return TarotVisualizationResponse(
                success=True,
                image_url="https://placeholder.mystic.app/tarot-vision.png",
                prompt_used=enhanced_prompt,
                error=None,
            )

        # Call Replicate API
        output = replicate.run(
            "black-forest-labs/flux-schnell",
            input={
                "prompt": enhanced_prompt,
                "num_outputs": 1,
                "aspect_ratio": "9:16",  # Tarot card aspect ratio
                "output_format": "webp",
                "output_quality": 90,
            }
        )

        # Replicate returns a list of FileOutput objects, convert to string URL
        image_url = str(output[0]) if output else None

        return TarotVisualizationResponse(
            success=True,
            image_url=image_url,
            prompt_used=enhanced_prompt,
            error=None,
        )

    except Exception as e:
        return TarotVisualizationResponse(
            success=False,
            image_url=None,
            prompt_used=request.prompt,
            error=str(e),
        )


@app.post("/tarot/reading", response_model=TarotReadingResponse)
async def generate_reading(request: TarotReadingRequest):
    """
    Generate an AI-powered tarot reading interpretation using OpenAI.

    The interpretation is dynamically generated based on:
    - The seeker's question
    - The drawn card and its orientation (upright/reversed)
    - The selected character's personality

    If OPENAI_API_KEY is not configured, falls back to template responses.
    """
    try:
        # Determine the card name
        card_name = request.card_name
        if not card_name and request.cards:
            card_name = request.cards[0]
        if not card_name:
            card_name = "The Fool"  # Default card

        # Get the tarot interpretation service
        tarot_service = get_tarot_service()

        # Generate dynamic interpretation with user preferences
        interpretation = await tarot_service.generate_reading_interpretation(
            question=request.question,
            card_name=card_name,
            is_upright=request.is_upright,
            character_id=request.character_id,
            knowledge_level=request.knowledge_level,
            preferred_tone=request.preferred_tone,
            gender=request.gender,
        )

        # Build card list for response
        cards_interpreted = request.cards if request.cards else [card_name]

        return TarotReadingResponse(
            success=True,
            reading=interpretation,
            character_id=request.character_id,
            cards_interpreted=cards_interpreted,
            error=None,
        )

    except Exception as e:
        print(f"Reading generation error: {e}")
        return TarotReadingResponse(
            success=False,
            reading=None,
            character_id=request.character_id,
            cards_interpreted=[],
            error=str(e),
        )


@app.get("/tarot/daily")
async def get_daily_tarot(device_id: str, character_id: str = "madame_luna"):
    """
    Get the daily tarot card reading for a user.

    This is a "Card of the Day" feature that:
    1. Checks if the user already drew a daily card TODAY (server date)
    2. If YES: Returns the existing reading (no credits charged, no OpenAI call)
    3. If NO: Draws a random card, generates interpretation, saves to DB, returns new reading

    The reading provides general guidance without requiring a user question.
    """
    import random
    from datetime import date, datetime

    today = date.today().isoformat()

    try:
        # Check if we have Firebase configured
        if app.state.db:
            # Check for existing daily reading in Firestore
            daily_ref = app.state.db.collection("users").document(device_id).collection("daily_tarot").document(today)
            existing_doc = daily_ref.get()

            if existing_doc.exists:
                # User already has a daily reading for today - return it
                data = existing_doc.to_dict()
                return {
                    "success": True,
                    "is_new": False,
                    "date": today,
                    "card_name": data.get("card_name", "The Fool"),
                    "card_image": data.get("card_image", "assets/cards/major/00_fool.png"),
                    "is_upright": data.get("is_upright", True),
                    "interpretation": data.get("interpretation", ""),
                    "summary": data.get("summary", ""),
                    "character_id": data.get("character_id", character_id),
                    "error": None,
                }

        # No existing reading - draw a new card
        major_arcana = list(MAJOR_ARCANA_MEANINGS.keys())
        card_name = random.choice(major_arcana)
        is_upright = random.random() > 0.3  # 70% chance upright

        # Map card name to asset path
        card_filename_map = {
            "The Fool": "00_fool",
            "The Magician": "01_magician",
            "The High Priestess": "02_high_priestess",
            "The Empress": "03_empress",
            "The Emperor": "04_emperor",
            "The Hierophant": "05_hierophant",
            "The Lovers": "06_lovers",
            "The Chariot": "07_chariot",
            "Strength": "08_strength",
            "The Hermit": "09_hermit",
            "Wheel of Fortune": "10_wheel_of_fortune",
            "Justice": "11_justice",
            "The Hanged Man": "12_hanged_man",
            "Death": "13_death",
            "Temperance": "14_temperance",
            "The Devil": "15_devil",
            "The Tower": "16_tower",
            "The Star": "17_star",
            "The Moon": "18_moon",
            "The Sun": "19_sun",
            "Judgement": "20_judgement",
            "The World": "21_world",
        }
        card_filename = card_filename_map.get(card_name, "00_fool")
        card_image = f"assets/cards/major/{card_filename}.png"

        # Generate interpretation using OpenAI (no question - general guidance)
        tarot_service = get_tarot_service()

        # Special system prompt for daily card readings
        interpretation = await tarot_service.generate_daily_reading(
            card_name=card_name,
            is_upright=is_upright,
            character_id=character_id,
        )

        # Generate a one-line summary
        card_data = MAJOR_ARCANA_MEANINGS.get(card_name, {})
        keywords = card_data.get("keywords", ["guidance", "insight"])
        summary = f"Today's energy: {', '.join(keywords[:2]).title()}"

        # Save to Firestore if available
        if app.state.db:
            daily_ref = app.state.db.collection("users").document(device_id).collection("daily_tarot").document(today)
            daily_ref.set({
                "card_name": card_name,
                "card_image": card_image,
                "is_upright": is_upright,
                "interpretation": interpretation,
                "summary": summary,
                "character_id": character_id,
                "type": "daily",
                "created_at": datetime.utcnow(),
            })

        return {
            "success": True,
            "is_new": True,
            "date": today,
            "card_name": card_name,
            "card_image": card_image,
            "is_upright": is_upright,
            "interpretation": interpretation,
            "summary": summary,
            "character_id": character_id,
            "error": None,
        }

    except Exception as e:
        print(f"Daily tarot error: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "is_new": False,
            "date": today,
            "card_name": "The Fool",
            "card_image": "assets/cards/major/00_fool.png",
            "is_upright": True,
            "interpretation": "",
            "summary": "",
            "character_id": character_id,
            "error": str(e),
        }


# Import for daily tarot
from services.tarot_service import MAJOR_ARCANA_MEANINGS


# =============================================================================
# Chat Endpoints
# =============================================================================

class ChatMessageRequest(BaseModel):
    """Request model for chat message."""
    chat_id: str = Field(..., description="Unique chat session ID")
    message: str = Field(..., min_length=1, max_length=1000, description="User message")
    character_id: str = Field(default="madame_luna", description="Oracle character ID")
    context: Optional[str] = Field(default=None, description="Reading context for the conversation")
    conversation_history: Optional[list] = Field(
        default=None,
        description="Previous messages in the conversation [{text, is_user}, ...]"
    )
    # User preferences for personalized chat
    knowledge_level: Optional[str] = Field(
        default=None,
        description="User's esoteric knowledge level: novice, seeker, or adept"
    )
    preferred_tone: Optional[str] = Field(
        default=None,
        description="User's preferred reading tone: gentle or brutal"
    )
    gender: Optional[str] = Field(
        default=None,
        description="User's gender for pronoun usage: female, male, or other"
    )


class ChatMessageResponse(BaseModel):
    """Response model for chat message."""
    success: bool
    response: Optional[str] = None
    character_id: str
    error: Optional[str] = None


# Character personality prompts for chat
CHARACTER_CHAT_PERSONALITIES = {
    "madame_luna": {
        "name": "Madame Luna",
        "style": "warm, nurturing, and deeply intuitive",
        "greeting": "Welcome, dear seeker. The stars have been waiting for you...",
        "responses": [
            "I sense deep emotions within your question, dear one. The universe whispers that {insight}.",
            "The moon reveals to me that {insight}. Trust in the cosmic flow.",
            "Your heart already knows the answer, beloved seeker. {insight}.",
            "The celestial energies surrounding you suggest that {insight}.",
        ]
    },
    "elder_weiss": {
        "name": "Elder Weiss",
        "style": "wise, measured, and scholarly",
        "greeting": "Ah, another soul seeking wisdom. Let us explore the ancient mysteries together.",
        "responses": [
            "In my many years of study, I have learned that {insight}.",
            "The ancient texts speak of such matters. They say {insight}.",
            "Consider this wisdom, seeker: {insight}.",
            "The path forward becomes clear when we understand that {insight}.",
        ]
    },
    "nova": {
        "name": "Nova",
        "style": "analytical, cosmic, and futuristic",
        "greeting": "Greetings, traveler. I've been analyzing the cosmic data streams for your arrival.",
        "responses": [
            "My calculations indicate that {insight}.",
            "The quantum probability fields suggest {insight}.",
            "Analyzing your energy signature, I detect that {insight}.",
            "The cosmic algorithms reveal that {insight}.",
        ]
    },
    "shadow": {
        "name": "Shadow",
        "style": "brutally honest and direct",
        "greeting": "No pleasantries. You're here for truth. Let's begin.",
        "responses": [
            "Here's the truth you need to hear: {insight}.",
            "Stop avoiding it. {insight}.",
            "The cards don't lie, and neither do I. {insight}.",
            "Face this reality: {insight}.",
        ]
    },
}

# Insights pool for generating responses
INSIGHT_POOL = [
    "change is on the horizon, and you must prepare to embrace it",
    "your intuition has been guiding you correctly all along",
    "there is a lesson hidden in your current struggle",
    "the path you fear may be the one leading to growth",
    "someone close to you holds the key to your question",
    "patience will reveal what haste cannot discover",
    "your past experiences have prepared you for this moment",
    "balance between heart and mind is essential now",
    "an unexpected opportunity will soon present itself",
    "letting go of control may bring the freedom you seek",
    "your creative energy is your greatest asset right now",
    "the universe is aligning to support your journey",
]


@app.post("/chat/message", response_model=ChatMessageResponse)
async def send_chat_message(request: ChatMessageRequest):
    """
    Send a message to the Oracle and receive a dynamic AI-powered response.

    Uses OpenAI to generate contextual, character-appropriate responses.
    Falls back to template responses if OpenAI is not configured.
    """
    try:
        # Get the tarot interpretation service
        tarot_service = get_tarot_service()

        # Generate dynamic chat response with user preferences and conversation history
        response_text = await tarot_service.generate_chat_response(
            message=request.message,
            character_id=request.character_id,
            reading_context=request.context,
            conversation_history=request.conversation_history,
            knowledge_level=request.knowledge_level,
            preferred_tone=request.preferred_tone,
            gender=request.gender,
        )

        return ChatMessageResponse(
            success=True,
            response=response_text,
            character_id=request.character_id,
            error=None,
        )

    except Exception as e:
        print(f"Chat error: {e}")
        return ChatMessageResponse(
            success=False,
            response=None,
            character_id=request.character_id,
            error=str(e),
        )


@app.get("/characters")
async def get_characters():
    """Get all available tarot reader characters."""
    return {
        "characters": [
            {
                "id": "madame_luna",
                "name": "Madame Luna",
                "title": "The Moon Child",
                "description": "Intuitive and warm, focuses on love and relationships.",
                "theme_color": "#9D00FF",
                "is_locked": False,
            },
            {
                "id": "elder_weiss",
                "name": "Elder Weiss",
                "title": "The Ancient Sage",
                "description": "Wise counsel for career and life path.",
                "theme_color": "#FFD700",
                "is_locked": True,
            },
            {
                "id": "nova",
                "name": "Nova",
                "title": "The Stargazer",
                "description": "Futuristic oracle blending logic with astrology.",
                "theme_color": "#00FFFF",
                "is_locked": True,
            },
            {
                "id": "shadow",
                "name": "Shadow",
                "title": "The Truth Seeker",
                "description": "Brutally honest revelations of dark truths.",
                "theme_color": "#FF0033",
                "is_locked": True,
            },
        ]
    }


# =============================================================================
# Firebase Integration Endpoints
# =============================================================================

@app.get("/user/{user_id}/readings")
async def get_user_readings(user_id: str, limit: int = 10):
    """Get a user's reading history from Firestore."""
    if not app.state.db:
        raise HTTPException(
            status_code=503,
            detail="Firebase not configured"
        )

    try:
        readings_ref = app.state.db.collection("users").document(user_id).collection("readings")
        docs = readings_ref.order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit).stream()

        readings = []
        for doc in docs:
            reading = doc.to_dict()
            reading["id"] = doc.id
            readings.append(reading)

        return {"readings": readings}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =============================================================================
# Astrology Endpoints (Sky Hall)
# =============================================================================

@app.post("/astrology/natal-chart", response_model=NatalChartResponse)
async def calculate_natal_chart(request: NatalChartRequest):
    """
    Calculate a complete natal chart based on birth data.
    Returns planetary positions, houses, aspects, and interpretations.
    """
    try:
        chart = AstrologyService.calculate_natal_chart(
            date=request.date,
            time=request.time,
            latitude=request.latitude,
            longitude=request.longitude,
            timezone=request.timezone,
            name=request.name or "Seeker"
        )
        return NatalChartResponse(**chart)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Chart calculation error: {str(e)}")


@app.post("/astrology/synastry", response_model=SynastryReport)
async def calculate_synastry(request: SynastryRequest):
    """
    Calculate synastry (compatibility) between two natal charts.

    Uses a weighted planetary aspect scoring algorithm:
    - Sun/Moon aspects: Soul connection (+15 pts conjunction/trine, -5 pts square)
    - Venus/Mars aspects: Chemistry (+10-15 pts flowing aspects)
    - Mercury aspects: Communication (+5/-5 pts)
    - Saturn aspects: Stability/Challenges (+5 trine, -10 square)

    Also generates AI-powered detailed 3-section analysis:
    - Chemistry Analysis (Venus/Mars aspects)
    - Emotional Connection (Sun/Moon/Mercury aspects)
    - Challenges (Saturn/Pluto/Square aspects)
    """
    try:
        user1_data = {
            "date": request.user1.date,
            "time": request.user1.time,
            "latitude": request.user1.latitude,
            "longitude": request.user1.longitude,
            "timezone": request.user1.timezone,
            "name": request.user1.name or "Person 1"
        }
        user2_data = {
            "date": request.user2.date,
            "time": request.user2.time,
            "latitude": request.user2.latitude,
            "longitude": request.user2.longitude,
            "timezone": request.user2.timezone,
            "name": request.user2.name or "Person 2"
        }

        # Get base synastry report from AstrologyService
        report = AstrologyService.calculate_synastry(user1_data, user2_data)

        # Get the enhanced synastry analysis service
        synastry_service = get_synastry_service()

        # Calculate weighted scores using the new algorithm
        weighted_scores = synastry_service.calculate_weighted_score(
            aspects=report.get("key_aspects", []),
            chart1=report.get("user1_chart", {}),
            chart2=report.get("user2_chart", {}),
        )

        # Update scores with weighted calculation
        report["compatibility_score"] = weighted_scores["overall"]
        report["emotional_compatibility"] = weighted_scores["emotional"]
        report["intellectual_compatibility"] = weighted_scores["intellectual"]
        report["physical_compatibility"] = weighted_scores["chemistry"]  # Map to physical

        # Generate AI-powered detailed analysis
        detailed_analysis = await synastry_service.generate_detailed_analysis(
            chart1=report.get("user1_chart", {}),
            chart2=report.get("user2_chart", {}),
            scores=weighted_scores,
            aspects=report.get("key_aspects", []),
        )

        # Add detailed analysis to report
        report["detailed_analysis"] = DetailedAnalysis(
            chemistry_analysis=detailed_analysis.get("chemistry_analysis", ""),
            emotional_connection=detailed_analysis.get("emotional_connection", ""),
            challenges=detailed_analysis.get("challenges", ""),
            summary=detailed_analysis.get("summary", ""),
        )

        # Also set the AI summary for backwards compatibility
        report["ai_summary"] = detailed_analysis.get("summary", "")

        return SynastryReport(**report)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Synastry calculation error: {str(e)}")


class DailyInsightResponse(BaseModel):
    """Response model for daily cosmic insight."""
    date: str
    moon_phase: str
    moon_phase_icon: str
    moon_illumination: float
    moon_sign: str
    moon_sign_symbol: str
    moon_element: str
    mercury_retrograde: bool
    mercury_status: str
    advice: str
    sun_sign: str


# =============================================================================
# Daily Tarot Models
# =============================================================================

class DailyTarotResponse(BaseModel):
    """Response model for daily tarot card reading."""
    success: bool
    is_new: bool = True  # False if returning cached reading from today
    date: str
    card_name: str
    card_image: str  # Asset path for the card image
    is_upright: bool
    interpretation: str
    summary: str  # One-line summary for the card
    character_id: str = "madame_luna"
    error: Optional[str] = None


@app.get("/astrology/daily-insight", response_model=DailyInsightResponse)
async def get_daily_insight(date_str: Optional[str] = None):
    """
    Get the daily cosmic insight including:
    - Current Moon phase and illumination
    - Moon sign and element
    - Mercury retrograde status
    - AI-generated mystical advice

    Optionally provide a date in YYYY-MM-DD format, defaults to today.
    """
    from datetime import date as date_type

    try:
        target_date = None
        if date_str:
            target_date = date_type.fromisoformat(date_str)

        insight = await AstrologyService.get_daily_insight(target_date)
        return DailyInsightResponse(**insight)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid date format: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Daily insight error: {str(e)}")


# =============================================================================
# Personal Daily Horoscope (Transit-Based)
# =============================================================================

class PersonalHoroscopeRequest(BaseModel):
    """Request model for personal daily horoscope."""
    user_id: Optional[str] = Field(default=None, description="User ID for caching")
    birth_date: str = Field(..., description="Birth date in YYYY-MM-DD format")
    birth_time: str = Field(default="12:00", description="Birth time in HH:MM format")
    birth_latitude: float = Field(..., description="Birth location latitude")
    birth_longitude: float = Field(..., description="Birth location longitude")
    birth_timezone: str = Field(default="UTC", description="Birth location timezone")
    name: Optional[str] = Field(default="Seeker", description="User's name for personalization")
    target_date: Optional[str] = Field(default=None, description="Date for horoscope (defaults to today)")


class PersonalHoroscopeResponse(BaseModel):
    """Response model for personal daily horoscope."""
    success: bool
    date: str
    user_name: str
    sun_sign: str
    moon_sign: str
    rising_sign: str
    forecast: str
    cosmic_vibe: str
    focus_areas: list[str]
    overall_energy: str
    active_transits: list[dict]
    moon_phase: str
    moon_phase_icon: str
    current_moon_sign: str
    mercury_retrograde: bool
    is_cached: bool = False  # True if served from cache (zero OpenAI cost)
    error: Optional[str] = None


@app.post("/astrology/personal-horoscope", response_model=PersonalHoroscopeResponse)
async def get_personal_horoscope(request: PersonalHoroscopeRequest):
    """
    Get a personalized daily horoscope based on the user's natal chart and current transits.

    Uses the "Mystic Date" 7 AM rule for caching:
    - Horoscope persists from 7 AM to 7 AM (next day)
    - Same reading returned until 7 AM reset

    This endpoint:
    1. Checks Firestore for existing horoscope using Mystic Date (zero OpenAI cost if found)
    2. If not cached, calculates natal chart and transits
    3. Generates AI-powered personalized forecast
    4. Caches result to Firestore for future requests
    5. Returns cosmic vibe, focus areas, and active transits

    The horoscope is deeply personal - based on real astrological calculations,
    not generic sun-sign horoscopes.
    """
    from datetime import date as date_type
    from services.cache_service import HoroscopeCacheService
    from services.astrology_service import get_mystic_date

    try:
        # Use Mystic Date (7 AM rule) instead of target_date
        # The cache service automatically uses Mystic Date
        mystic_date = get_mystic_date()

        # Generate user_id from birth data if not provided
        user_id = request.user_id
        if not user_id:
            # Create deterministic user_id from birth data
            user_id = f"user_{request.birth_date}_{request.birth_latitude:.2f}_{request.birth_longitude:.2f}"

        # Step 1: Check Firestore cache for existing horoscope (uses Mystic Date internally)
        cached = HoroscopeCacheService.get_cached_horoscope(user_id)
        if cached:
            return PersonalHoroscopeResponse(
                success=True,
                date=cached.get("date", mystic_date.isoformat()),
                user_name=cached.get("user_name", request.name or "Seeker"),
                sun_sign=cached.get("sun_sign", "Unknown"),
                moon_sign=cached.get("moon_sign", "Unknown"),
                rising_sign=cached.get("rising_sign", "Unknown"),
                forecast=cached.get("forecast", ""),
                cosmic_vibe=cached.get("cosmic_vibe", "Cosmic Alignment"),
                focus_areas=cached.get("focus_areas", []),
                overall_energy=cached.get("overall_energy", "neutral"),
                active_transits=cached.get("active_transits", []),
                moon_phase=cached.get("moon_phase", ""),
                moon_phase_icon=cached.get("moon_phase_icon", ""),
                current_moon_sign=cached.get("current_moon_sign", ""),
                mercury_retrograde=cached.get("mercury_retrograde", False),
                is_cached=True,
                error=None
            )

        # Step 2: Not cached - Calculate natal chart
        natal_chart = AstrologyService.calculate_natal_chart(
            date=request.birth_date,
            time=request.birth_time,
            latitude=request.birth_latitude,
            longitude=request.birth_longitude,
            timezone=request.birth_timezone,
            name=request.name or "Seeker"
        )

        # Step 3: Generate personal horoscope with transits (using Mystic Date)
        horoscope = await AstrologyService.generate_personal_horoscope(
            natal_chart=natal_chart,
            target_date=mystic_date,
            user_name=request.name or "Seeker"
        )

        # Step 4: Cache the result to Firestore (uses Mystic Date internally)
        HoroscopeCacheService.cache_horoscope(user_id, horoscope)

        return PersonalHoroscopeResponse(
            success=True,
            **horoscope,
            is_cached=False,
            error=None
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid data: {str(e)}")
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Horoscope generation error: {str(e)}")


# =============================================================================
# Astro-Guide Chat (Chart-Based Q&A)
# =============================================================================

class AstroGuideChatRequest(BaseModel):
    """Request model for astro-guide chat."""
    user_id: str = Field(..., description="User's unique identifier")
    session_id: str = Field(..., description="Chat session ID for memory continuity")
    message: str = Field(..., min_length=1, max_length=1000, description="User's question")
    birth_date: str = Field(..., description="Birth date in YYYY-MM-DD format")
    birth_time: str = Field(default="12:00", description="Birth time in HH:MM format")
    birth_latitude: float = Field(..., description="Birth location latitude")
    birth_longitude: float = Field(..., description="Birth location longitude")
    birth_timezone: str = Field(default="UTC", description="Birth location timezone")
    name: Optional[str] = Field(default=None, description="User's name")
    character_id: Optional[str] = Field(default="nova", description="Guide character ID (madame_luna, elder_weiss, nova, shadow)")


class AstroGuideChatResponse(BaseModel):
    """Response model for astro-guide chat."""
    success: bool
    response: str
    sun_sign: str
    moon_sign: str
    rising_sign: str
    session_id: str  # Return session_id for continuity
    error: Optional[str] = None


@app.post("/sky-hall/chat", response_model=AstroGuideChatResponse)
async def astro_guide_chat(
    request: AstroGuideChatRequest,
    background_tasks: BackgroundTasks
):
    """
    Chat with Nova, the Astro-Guide AI, about your natal chart.

    Uses "Infinite Memory" via Rolling Summarization:
    1. Fetch current_summary from Firestore metadata + last 5-10 messages
    2. Build prompt using summary + chart context + recent messages
    3. Generate response and save both messages to Firestore
    4. Background summarization triggered every 5 message exchanges

    Database Schema (Firestore):
        users/{user_id}/astro_guide/
            - metadata: current_summary, message_count_since_summary, natal_chart_context
            - messages/: Full message history (role, content, timestamp)

    Benefits:
    - Nova remembers context from many messages ago
    - Minimal token cost (summary vs full history)
    - Full persistence - survives app restarts
    - Real-time sync via Firestore streams (frontend)
    """
    from datetime import date as date_type
    from services.astro_chat_service import get_astro_chat_service

    try:
        # Step 1: Calculate natal chart
        natal_chart = AstrologyService.calculate_natal_chart(
            date=request.birth_date,
            time=request.birth_time,
            latitude=request.birth_latitude,
            longitude=request.birth_longitude,
            timezone=request.birth_timezone,
            name=request.name or "Seeker"
        )

        # Extract key chart info for caching
        sun_sign = natal_chart.get("sun", {}).get("sign", "Unknown")
        moon_sign = natal_chart.get("moon", {}).get("sign", "Unknown")
        rising_sign = natal_chart.get("rising", {}).get("sign", "Unknown")
        venus_sign = natal_chart.get("venus", {}).get("sign", "Unknown")
        mars_sign = natal_chart.get("mars", {}).get("sign", "Unknown")
        mercury_sign = natal_chart.get("mercury", {}).get("sign", "Unknown")

        # Build natal chart context for caching
        natal_chart_context = {
            "sun_sign": sun_sign,
            "moon_sign": moon_sign,
            "rising_sign": rising_sign,
            "venus_sign": venus_sign,
            "mars_sign": mars_sign,
            "mercury_sign": mercury_sign,
            "sun_moon_rising_summary": natal_chart.get("sun_moon_rising_summary", ""),
        }

        # Step 2: Get current transits for context
        transits = AstrologyService.calculate_transits(natal_chart, date_type.today())
        transits_context = ""
        for t in transits["transits"][:5]:
            transits_context += f"- {t['transiting_planet']} {t['aspect']} natal {t['natal_planet']}: {t['interpretation']}\n"
        transits_context += f"\nOverall energy today: {transits['overall_energy']}"

        # Step 3: Generate response using AstroChatService with selected character
        chat_service = get_astro_chat_service()
        result = await chat_service.generate_response(
            user_id=request.user_id,
            message=request.message,
            natal_chart_context=natal_chart_context,
            transits_context=transits_context,
            user_name=request.name or "Seeker",
            character_id=request.character_id or "nova",
        )

        # Step 4: Trigger background summarization if needed (Every 5 Messages Rule)
        if result.get("should_summarize"):
            background_tasks.add_task(
                chat_service.run_background_summarization,
                request.user_id
            )
            print(f"[AstroGuideChat] Background summarization scheduled for user={request.user_id}")

        return AstroGuideChatResponse(
            success=result.get("success", True),
            response=result.get("response", "The stars are momentarily silent..."),
            sun_sign=sun_sign,
            moon_sign=moon_sign,
            rising_sign=rising_sign,
            session_id=request.session_id,  # Keep for backwards compatibility
            error=None
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid data: {str(e)}")
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Chat error: {str(e)}")


def _generate_fallback_astro_response(message: str, sun_sign: str, moon_sign: str, rising_sign: str) -> str:
    """Generate fallback response when OpenAI is unavailable."""
    import random

    lower_msg = message.lower()

    if "sun" in lower_msg or "identity" in lower_msg:
        return f"Your Sun in {sun_sign} reveals your core essence and life purpose. This placement illuminates how you express your authentic self and where you find vitality. The Sun's aspects in your chart show how easily this expression flows in your life."

    if "rising" in lower_msg or "ascendant" in lower_msg:
        return f"With {rising_sign} rising, you project an aura of its qualities to the world. This is your cosmic mask - the first impression you make. Understanding your Ascendant helps you navigate social situations and recognize how others perceive you."

    if "love" in lower_msg or "relationship" in lower_msg:
        return f"For matters of the heart, I analyze Venus in your chart. As a {sun_sign}, you approach love with characteristic traits of your sign. Your 7th house of partnerships and its ruler reveal deeper patterns in how you form lasting bonds."

    if "career" in lower_msg or "work" in lower_msg:
        return f"Your 10th house and its planetary ruler speak to your career path. As a {sun_sign}, you bring unique qualities to your professional life. Saturn's placement shows where you face challenges that ultimately forge your greatest achievements."

    if "moon" in lower_msg or "emotion" in lower_msg:
        return f"Your Moon in {moon_sign} reveals your emotional landscape and innermost needs. This is how you nurture yourself and others, and what makes you feel secure. The Moon's aspects show how your emotions flow with other areas of life."

    # Default response
    responses = [
        f"Looking at your chart as a {sun_sign} with {rising_sign} rising, I see fascinating cosmic patterns at play. Your planetary placements form a unique celestial blueprint. Would you like me to explore a specific area - perhaps your love nature, career potential, or spiritual path?",
        f"Your cosmic signature as a {sun_sign} Sun, {moon_sign} Moon, and {rising_sign} rising creates a unique energetic blend. The planets in your chart dance in specific patterns that reveal your soul's purpose. What aspect of your celestial map shall we explore?",
        f"Scanning your energy field, {sun_sign}... Your chart reveals a complex interplay of planetary forces. The transits affecting you today add another layer to your cosmic story. What wisdom do you seek from the stars?"
    ]

    return random.choice(responses)


# =============================================================================
# Chat Session Management
# =============================================================================

class NewChatSessionRequest(BaseModel):
    """Request model for creating a new chat session."""
    user_id: str = Field(..., description="User's unique identifier")


class NewChatSessionResponse(BaseModel):
    """Response model for new chat session."""
    success: bool
    session_id: str
    message: str


@app.post("/sky-hall/chat/new-session", response_model=NewChatSessionResponse)
async def create_new_chat_session(request: NewChatSessionRequest):
    """
    Create a new chat session with Nova.

    This clears the conversation history and summary in Firestore.
    Use this when the user explicitly wants to start a new conversation.
    """
    from services.cache_service import generate_session_id
    from services.astro_chat_service import get_astro_chat_service

    # Clear existing conversation in Firestore
    chat_service = get_astro_chat_service()
    chat_service.clear_conversation(request.user_id)

    # Generate new session ID for backwards compatibility
    session_id = generate_session_id(request.user_id)

    return NewChatSessionResponse(
        success=True,
        session_id=session_id,
        message="New chat session created. Nova awaits your questions."
    )


# =============================================================================
# Chat History Endpoint (for Frontend Firestore Sync)
# =============================================================================

class ChatHistoryResponse(BaseModel):
    """Response model for chat history."""
    success: bool
    messages: list[dict] = []
    total_count: int = 0
    has_summary: bool = False
    error: Optional[str] = None


@app.get("/sky-hall/chat/history/{user_id}", response_model=ChatHistoryResponse)
async def get_chat_history(user_id: str, limit: int = 100):
    """
    Get chat history for a user.

    Returns all messages from the Firestore messages sub-collection.
    This endpoint is useful for initial load - after that, use Firestore streams.

    Note: For real-time updates, the Flutter app should use Firestore
    streams directly (cloud_firestore package).
    """
    from services.astro_chat_service import get_astro_chat_service

    try:
        chat_service = get_astro_chat_service()

        # Get all messages
        messages = chat_service.get_all_messages(user_id, limit=limit)

        # Get metadata to check if there's a summary
        metadata = chat_service.get_or_create_metadata(user_id)
        has_summary = bool(metadata.get("current_summary"))

        return ChatHistoryResponse(
            success=True,
            messages=messages,
            total_count=len(messages),
            has_summary=has_summary,
            error=None
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        return ChatHistoryResponse(
            success=False,
            messages=[],
            total_count=0,
            has_summary=False,
            error=str(e)
        )


@app.delete("/sky-hall/chat/history/{user_id}")
async def clear_chat_history(user_id: str):
    """
    Clear all chat history for a user.

    Deletes all messages and resets the summary.
    """
    from services.astro_chat_service import get_astro_chat_service

    try:
        chat_service = get_astro_chat_service()
        chat_service.clear_conversation(user_id)

        return {
            "success": True,
            "message": "Chat history cleared successfully."
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to clear history: {str(e)}")


# =============================================================================
# Text-to-Speech Endpoints (ElevenLabs)
# =============================================================================

from fastapi.responses import StreamingResponse
from services.elevenlabs_service import (
    get_elevenlabs_service,
    ElevenLabsError,
    CHARACTER_VOICE_MAP,
)


class TTSRequest(BaseModel):
    """Request model for text-to-speech."""
    text: str = Field(..., min_length=1, max_length=5000, description="Text to synthesize")
    character_id: str = Field(default="madame_luna", description="Character voice to use")
    use_cache: bool = Field(default=True, description="Whether to use caching")
    stream: bool = Field(default=True, description="Whether to stream the response")


class TTSResponse(BaseModel):
    """Response model for non-streaming TTS."""
    success: bool
    audio_url: Optional[str] = None
    cached: bool = False
    error: Optional[str] = None


@app.post("/tts/speak")
async def text_to_speech(request: TTSRequest):
    """
    Convert text to speech using ElevenLabs API.

    - If stream=True, returns streaming audio/mpeg response for lower latency.
    - If stream=False, returns full audio file.
    - Uses caching to reduce API costs for repeated texts.
    """
    service = get_elevenlabs_service()

    if not service.is_configured:
        raise HTTPException(
            status_code=503,
            detail="Text-to-speech service not configured"
        )

    try:
        if request.stream:
            # Streaming response for lower latency
            async def audio_stream():
                async for chunk in service.synthesize_speech_stream(
                    text=request.text,
                    character_id=request.character_id,
                ):
                    yield chunk

            return StreamingResponse(
                audio_stream(),
                media_type="audio/mpeg",
                headers={
                    "Content-Disposition": "inline",
                    "Cache-Control": "no-cache",
                }
            )
        else:
            # Full audio response with caching
            audio_data = await service.synthesize_speech(
                text=request.text,
                character_id=request.character_id,
                use_cache=request.use_cache,
            )

            return StreamingResponse(
                iter([audio_data]),
                media_type="audio/mpeg",
                headers={
                    "Content-Disposition": "inline",
                    "Content-Length": str(len(audio_data)),
                }
            )

    except ElevenLabsError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=e.message
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"TTS error: {str(e)}"
        )


@app.get("/tts/voices")
async def get_available_voices():
    """Get list of available character voices for TTS."""
    return {
        "voices": [
            {
                "character_id": char_id,
                "description": config.get("description", ""),
            }
            for char_id, config in CHARACTER_VOICE_MAP.items()
        ]
    }


@app.get("/tts/health")
async def tts_health_check():
    """Check if TTS service is available."""
    service = get_elevenlabs_service()
    return {
        "configured": service.is_configured,
        "available_characters": list(CHARACTER_VOICE_MAP.keys()),
    }


# =============================================================================
# Run Server
# =============================================================================

if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=os.getenv("ENV", "development") == "development",
    )

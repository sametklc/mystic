"""
Mystic Tarot Backend API
FastAPI server for AI-powered tarot readings using Replicate.
Deployed on Render, connected to Firebase.
"""

import os
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Astrology
from models.astrology_models import (
    NatalChartRequest, NatalChartResponse,
    SynastryRequest, SynastryReport
)
from services.astrology_service import AstrologyService

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
    cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
    if cred_json:
        import json
        cred_dict = json.loads(cred_json)
        return credentials.Certificate(cred_dict)

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
        ...,
        min_length=5,
        max_length=300,
        description="The seeker's question"
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
        description="List of drawn card IDs"
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
    return {
        "status": "healthy",
        "firebase": app.state.db is not None,
        "replicate": os.getenv("REPLICATE_API_TOKEN") is not None,
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
    Generate an AI-powered tarot reading interpretation.
    This endpoint would use an LLM (e.g., via Replicate or OpenAI).
    """
    try:
        # For now, return a mock reading
        # In production, this would call an LLM API

        character_styles = {
            "madame_luna": "warm, intuitive, focused on emotions and love",
            "elder_weiss": "wise, measured, focused on life path and career",
            "nova": "analytical, cosmic, blending logic with astrology",
            "shadow": "brutally honest, revealing hidden truths",
        }

        style = character_styles.get(request.character_id, character_styles["madame_luna"])

        # Mock reading response
        mock_reading = (
            f"The cards speak to your question: '{request.question}'\n\n"
            f"As your guide, I sense {style}...\n\n"
            "The universe reveals that this is a time of transformation. "
            "Trust your intuition and embrace the changes ahead."
        )

        return TarotReadingResponse(
            success=True,
            reading=mock_reading,
            character_id=request.character_id,
            cards_interpreted=request.cards,
            error=None,
        )

    except Exception as e:
        return TarotReadingResponse(
            success=False,
            reading=None,
            character_id=request.character_id,
            cards_interpreted=[],
            error=str(e),
        )


# =============================================================================
# Chat Endpoints
# =============================================================================

class ChatMessageRequest(BaseModel):
    """Request model for chat message."""
    chat_id: str = Field(..., description="Unique chat session ID")
    message: str = Field(..., min_length=1, max_length=1000, description="User message")
    character_id: str = Field(default="madame_luna", description="Oracle character ID")
    context: Optional[str] = Field(default=None, description="Reading context for the conversation")


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
    Send a message to the Oracle and receive a response.
    In production, this would use an LLM for dynamic responses.
    """
    import random

    try:
        character = CHARACTER_CHAT_PERSONALITIES.get(
            request.character_id,
            CHARACTER_CHAT_PERSONALITIES["madame_luna"]
        )

        # Select a random response template and insight
        response_template = random.choice(character["responses"])
        insight = random.choice(INSIGHT_POOL)

        # Generate response
        response_text = response_template.format(insight=insight)

        return ChatMessageResponse(
            success=True,
            response=response_text,
            character_id=request.character_id,
            error=None,
        )

    except Exception as e:
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
    Returns compatibility scores, key aspects, and both charts.
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

        report = AstrologyService.calculate_synastry(user1_data, user2_data)
        return SynastryReport(**report)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
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

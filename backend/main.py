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

        # Replicate returns a list of URLs
        image_url = output[0] if output else None

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

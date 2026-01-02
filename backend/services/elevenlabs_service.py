"""
ElevenLabs Text-to-Speech service.
Handles voice synthesis with character-specific voices and caching.
"""
import os
import hashlib
from typing import AsyncGenerator, Optional
import httpx

# Firebase Admin SDK for caching
import firebase_admin
from firebase_admin import storage


# Character to ElevenLabs Voice ID mapping
# These are example voice IDs - replace with actual ElevenLabs voice IDs
CHARACTER_VOICE_MAP = {
    "madame_luna": {
        "voice_id": "EXAVITQu4vr4xnSDxMaL",  # Soft, mystic female voice (Bella)
        "stability": 0.5,
        "similarity_boost": 0.75,
        "style": 0.4,
        "description": "Warm, intuitive, mystical feminine voice"
    },
    "elder_weiss": {
        "voice_id": "VR6AewLTigWG4xSOukaG",  # Deep, authoritative male voice (Arnold)
        "stability": 0.7,
        "similarity_boost": 0.8,
        "style": 0.3,
        "description": "Deep, wise, scholarly male voice"
    },
    "nova": {
        "voice_id": "21m00Tcm4TlvDq8ikWAM",  # Clear, analytical voice (Rachel)
        "stability": 0.6,
        "similarity_boost": 0.7,
        "style": 0.5,
        "description": "Clear, futuristic, analytical voice"
    },
    "shadow": {
        "voice_id": "2EiwWnXFnvU5JabPnv8n",  # Dark, intense voice (Clyde)
        "stability": 0.8,
        "similarity_boost": 0.85,
        "style": 0.2,
        "description": "Dark, intense, brutally honest voice"
    },
}

# Default voice if character not found
DEFAULT_VOICE_ID = "EXAVITQu4vr4xnSDxMaL"


class ElevenLabsError(Exception):
    """Custom exception for ElevenLabs API errors."""
    def __init__(self, message: str, status_code: Optional[int] = None):
        self.message = message
        self.status_code = status_code
        super().__init__(self.message)


class ElevenLabsService:
    """Service for text-to-speech using ElevenLabs API."""

    BASE_URL = "https://api.elevenlabs.io/v1"

    def __init__(self):
        self.api_key = os.getenv("ELEVENLABS_API_KEY")
        self.model_id = os.getenv("ELEVENLABS_MODEL_ID", "eleven_multilingual_v2")
        self._client: Optional[httpx.AsyncClient] = None

    @property
    def is_configured(self) -> bool:
        """Check if ElevenLabs is properly configured."""
        return self.api_key is not None and len(self.api_key) > 0

    async def get_client(self) -> httpx.AsyncClient:
        """Get or create async HTTP client."""
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(
                timeout=httpx.Timeout(30.0, connect=10.0),
                headers={
                    "xi-api-key": self.api_key,
                    "Content-Type": "application/json",
                }
            )
        return self._client

    async def close(self):
        """Close the HTTP client."""
        if self._client and not self._client.is_closed:
            await self._client.aclose()

    def get_voice_config(self, character_id: str) -> dict:
        """Get voice configuration for a character."""
        return CHARACTER_VOICE_MAP.get(character_id, {
            "voice_id": DEFAULT_VOICE_ID,
            "stability": 0.5,
            "similarity_boost": 0.75,
            "style": 0.4,
        })

    def generate_cache_key(self, text: str, character_id: str) -> str:
        """Generate a unique cache key for the audio."""
        content = f"{character_id}:{text}"
        return hashlib.sha256(content.encode()).hexdigest()[:32]

    async def check_cache(self, cache_key: str) -> Optional[str]:
        """
        Check if audio exists in Firebase Storage cache.
        Returns the public URL if found, None otherwise.
        """
        try:
            if not firebase_admin._apps:
                return None

            bucket = storage.bucket()
            blob_path = f"tts_cache/{cache_key}.mp3"
            blob = bucket.blob(blob_path)

            if blob.exists():
                # Generate a signed URL or return public URL
                blob.make_public()
                return blob.public_url

            return None
        except Exception as e:
            print(f"Cache check error: {e}")
            return None

    async def save_to_cache(self, cache_key: str, audio_data: bytes) -> Optional[str]:
        """
        Save audio data to Firebase Storage cache.
        Returns the public URL of the cached file.
        """
        try:
            if not firebase_admin._apps:
                return None

            bucket = storage.bucket()
            blob_path = f"tts_cache/{cache_key}.mp3"
            blob = bucket.blob(blob_path)

            blob.upload_from_string(
                audio_data,
                content_type="audio/mpeg"
            )
            blob.make_public()

            return blob.public_url
        except Exception as e:
            print(f"Cache save error: {e}")
            return None

    async def synthesize_speech(
        self,
        text: str,
        character_id: str = "madame_luna",
        use_cache: bool = True,
    ) -> bytes:
        """
        Synthesize speech from text using ElevenLabs API.
        Returns the audio data as bytes.
        """
        if not self.is_configured:
            raise ElevenLabsError("ElevenLabs API key not configured")

        # Check cache first
        if use_cache:
            cache_key = self.generate_cache_key(text, character_id)
            cached_url = await self.check_cache(cache_key)
            if cached_url:
                # Fetch from cache
                client = await self.get_client()
                response = await client.get(cached_url)
                if response.status_code == 200:
                    return response.content

        # Get voice configuration
        voice_config = self.get_voice_config(character_id)
        voice_id = voice_config["voice_id"]

        # Build request
        url = f"{self.BASE_URL}/text-to-speech/{voice_id}"

        payload = {
            "text": text,
            "model_id": self.model_id,
            "voice_settings": {
                "stability": voice_config.get("stability", 0.5),
                "similarity_boost": voice_config.get("similarity_boost", 0.75),
                "style": voice_config.get("style", 0.4),
                "use_speaker_boost": True,
            }
        }

        try:
            client = await self.get_client()
            response = await client.post(
                url,
                json=payload,
                headers={"Accept": "audio/mpeg"}
            )

            if response.status_code == 200:
                audio_data = response.content

                # Cache the result
                if use_cache:
                    await self.save_to_cache(cache_key, audio_data)

                return audio_data
            else:
                error_text = response.text
                raise ElevenLabsError(
                    f"ElevenLabs API error: {error_text}",
                    status_code=response.status_code
                )

        except httpx.TimeoutException:
            raise ElevenLabsError("ElevenLabs API timeout")
        except httpx.RequestError as e:
            raise ElevenLabsError(f"Network error: {str(e)}")

    async def synthesize_speech_stream(
        self,
        text: str,
        character_id: str = "madame_luna",
    ) -> AsyncGenerator[bytes, None]:
        """
        Stream synthesized speech from ElevenLabs API.
        Yields audio data chunks for lower latency playback.
        """
        if not self.is_configured:
            raise ElevenLabsError("ElevenLabs API key not configured")

        # Get voice configuration
        voice_config = self.get_voice_config(character_id)
        voice_id = voice_config["voice_id"]

        # Use streaming endpoint
        url = f"{self.BASE_URL}/text-to-speech/{voice_id}/stream"

        payload = {
            "text": text,
            "model_id": self.model_id,
            "voice_settings": {
                "stability": voice_config.get("stability", 0.5),
                "similarity_boost": voice_config.get("similarity_boost", 0.75),
                "style": voice_config.get("style", 0.4),
                "use_speaker_boost": True,
            }
        }

        try:
            client = await self.get_client()

            async with client.stream(
                "POST",
                url,
                json=payload,
                headers={"Accept": "audio/mpeg"}
            ) as response:
                if response.status_code != 200:
                    error_text = await response.aread()
                    raise ElevenLabsError(
                        f"ElevenLabs API error: {error_text.decode()}",
                        status_code=response.status_code
                    )

                async for chunk in response.aiter_bytes(chunk_size=1024):
                    yield chunk

        except httpx.TimeoutException:
            raise ElevenLabsError("ElevenLabs API timeout")
        except httpx.RequestError as e:
            raise ElevenLabsError(f"Network error: {str(e)}")

    async def get_available_voices(self) -> list:
        """Get list of available voices from ElevenLabs."""
        if not self.is_configured:
            return []

        try:
            client = await self.get_client()
            response = await client.get(f"{self.BASE_URL}/voices")

            if response.status_code == 200:
                data = response.json()
                return data.get("voices", [])
            return []
        except Exception as e:
            print(f"Error fetching voices: {e}")
            return []


# Singleton instance
_elevenlabs_service: Optional[ElevenLabsService] = None


def get_elevenlabs_service() -> ElevenLabsService:
    """Get or create the ElevenLabs service singleton."""
    global _elevenlabs_service
    if _elevenlabs_service is None:
        _elevenlabs_service = ElevenLabsService()
    return _elevenlabs_service

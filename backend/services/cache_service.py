"""
Cache and Session Management Service

Provides:
1. Horoscope Caching - Store daily horoscopes to avoid regeneration (cost savings)
2. Chat Session Management - Store conversation summaries for "infinite memory"

Uses in-memory storage with optional Firestore persistence.
"""

import os
import asyncio
from datetime import date, datetime, timedelta
from typing import Optional, Dict, Any
from collections import defaultdict
import httpx


# =============================================================================
# In-Memory Cache Storage
# =============================================================================

class CacheStorage:
    """In-memory cache with TTL support."""

    def __init__(self):
        # Horoscope cache: {user_id: {date_str: horoscope_data}}
        self._horoscope_cache: Dict[str, Dict[str, dict]] = defaultdict(dict)

        # Chat session cache: {session_id: session_data}
        self._chat_sessions: Dict[str, dict] = {}

        # Cache TTL tracking
        self._cache_timestamps: Dict[str, datetime] = {}

    def get_horoscope(self, user_id: str, date_str: str) -> Optional[dict]:
        """Get cached horoscope if exists and not expired."""
        if user_id in self._horoscope_cache:
            return self._horoscope_cache[user_id].get(date_str)
        return None

    def set_horoscope(self, user_id: str, date_str: str, data: dict):
        """Cache horoscope data."""
        self._horoscope_cache[user_id][date_str] = data
        self._cache_timestamps[f"horoscope_{user_id}_{date_str}"] = datetime.now()

        # Clean old entries for this user (keep only last 7 days)
        self._cleanup_old_horoscopes(user_id)

    def _cleanup_old_horoscopes(self, user_id: str):
        """Remove horoscopes older than 7 days."""
        if user_id not in self._horoscope_cache:
            return

        cutoff = (date.today() - timedelta(days=7)).isoformat()
        old_dates = [d for d in self._horoscope_cache[user_id] if d < cutoff]
        for d in old_dates:
            del self._horoscope_cache[user_id][d]

    def get_chat_session(self, session_id: str) -> Optional[dict]:
        """Get chat session data."""
        return self._chat_sessions.get(session_id)

    def set_chat_session(self, session_id: str, data: dict):
        """Store chat session data."""
        self._chat_sessions[session_id] = data
        self._cache_timestamps[f"session_{session_id}"] = datetime.now()

    def update_chat_summary(self, session_id: str, summary: str):
        """Update conversation summary for a session."""
        if session_id in self._chat_sessions:
            self._chat_sessions[session_id]["summary"] = summary
            self._chat_sessions[session_id]["updated_at"] = datetime.now().isoformat()

    def create_chat_session(self, session_id: str, user_id: str, chart_data: dict) -> dict:
        """Create a new chat session."""
        session = {
            "session_id": session_id,
            "user_id": user_id,
            "chart_data": chart_data,
            "summary": "",  # Will be built up over conversation
            "message_count": 0,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
        }
        self._chat_sessions[session_id] = session
        return session

    def cleanup_old_sessions(self, max_age_hours: int = 24):
        """Remove sessions older than max_age_hours."""
        cutoff = datetime.now() - timedelta(hours=max_age_hours)
        to_remove = []

        for session_id, session in self._chat_sessions.items():
            updated = datetime.fromisoformat(session.get("updated_at", session.get("created_at")))
            if updated < cutoff:
                to_remove.append(session_id)

        for session_id in to_remove:
            del self._chat_sessions[session_id]


# Global cache instance
_cache = CacheStorage()


def get_cache() -> CacheStorage:
    """Get the global cache instance."""
    return _cache


# =============================================================================
# Horoscope Caching Service (Firestore + 7 AM Mystic Date Rule)
# =============================================================================

class HoroscopeCacheService:
    """
    Service for caching daily horoscopes with Firestore persistence.

    Uses the "Mystic Date" 7 AM rule:
    - Day resets at 7:00 AM, not midnight
    - Ensures consistent daily readings from 7 AM to 7 AM (next day)

    Flow:
    1. Calculate Mystic Date (7 AM rule)
    2. Check Firestore: users/{user_id}/daily_horoscopes/horoscope_{mystic_date}
    3. If exists: Return cached data (zero OpenAI cost)
    4. If missing: Return None (caller will generate and cache)
    """

    # Firebase Firestore reference (set during app initialization)
    _firestore_db = None

    @classmethod
    def set_firestore_db(cls, db):
        """Set the Firestore database reference."""
        cls._firestore_db = db

    @staticmethod
    def _get_mystic_date_string() -> str:
        """Get the current Mystic Date string using 7 AM rule."""
        from services.astrology_service import get_mystic_date_string
        return get_mystic_date_string()

    @staticmethod
    def _get_doc_id() -> str:
        """Get the Firestore document ID for today's horoscope."""
        mystic_date = HoroscopeCacheService._get_mystic_date_string()
        return f"horoscope_{mystic_date}"

    @staticmethod
    def get_cached_horoscope(user_id: str, target_date: date = None) -> Optional[dict]:
        """
        Get cached horoscope from Firestore if available.

        Uses Mystic Date (7 AM rule) for cache key.
        """
        # Use Mystic Date instead of target_date
        mystic_date = HoroscopeCacheService._get_mystic_date_string()
        doc_id = f"horoscope_{mystic_date}"

        # Try Firestore first
        db = HoroscopeCacheService._firestore_db
        if db:
            try:
                doc_ref = db.collection("users").document(user_id).collection("daily_horoscopes").document(doc_id)
                doc = doc_ref.get()

                if doc.exists:
                    cached = doc.to_dict()
                    cached["is_cached"] = True
                    print(f"[HoroscopeCache] FIRESTORE HIT for user={user_id}, mystic_date={mystic_date}")
                    return cached

                print(f"[HoroscopeCache] FIRESTORE MISS for user={user_id}, mystic_date={mystic_date}")
            except Exception as e:
                print(f"[HoroscopeCache] Firestore error: {e}")

        # Fallback to in-memory cache
        cached = get_cache().get_horoscope(user_id, mystic_date)
        if cached:
            cached["is_cached"] = True
            print(f"[HoroscopeCache] MEMORY HIT for user={user_id}, mystic_date={mystic_date}")
            return cached

        print(f"[HoroscopeCache] MISS for user={user_id}, mystic_date={mystic_date}")
        return None

    @staticmethod
    def cache_horoscope(user_id: str, horoscope_data: dict, target_date: date = None):
        """
        Store horoscope in both Firestore and in-memory cache.

        Uses Mystic Date (7 AM rule) for cache key.
        """
        from datetime import datetime, timezone

        # Use Mystic Date instead of target_date
        mystic_date = HoroscopeCacheService._get_mystic_date_string()
        doc_id = f"horoscope_{mystic_date}"

        # Add cache metadata
        cache_data = {
            **horoscope_data,
            "mystic_date": mystic_date,
            "cached_at": datetime.now(timezone.utc).isoformat(),
            "is_cached": False,  # First time is not from cache
        }

        # Store in Firestore
        db = HoroscopeCacheService._firestore_db
        if db:
            try:
                doc_ref = db.collection("users").document(user_id).collection("daily_horoscopes").document(doc_id)
                doc_ref.set(cache_data)
                print(f"[HoroscopeCache] FIRESTORE STORED for user={user_id}, mystic_date={mystic_date}")
            except Exception as e:
                print(f"[HoroscopeCache] Firestore store error: {e}")

        # Also store in memory cache as backup
        get_cache().set_horoscope(user_id, mystic_date, cache_data)
        print(f"[HoroscopeCache] MEMORY STORED for user={user_id}, mystic_date={mystic_date}")


# =============================================================================
# Chat Session Management with Summarization
# =============================================================================

class ChatSessionService:
    """
    Service for managing Astro-Guide chat sessions with summarization.

    The Problem:
    - Sending full conversation history is expensive (tokens)
    - Sending only last N messages loses long-term context

    The Solution:
    - Maintain a running "conversation summary" string
    - After each exchange, asynchronously update the summary
    - Nova gets: chart_data + summary + current_message
    - Result: "Infinite memory" at minimal token cost
    """

    @staticmethod
    def get_or_create_session(
        session_id: str,
        user_id: str,
        chart_data: dict
    ) -> dict:
        """Get existing session or create new one."""
        cache = get_cache()
        session = cache.get_chat_session(session_id)

        if session is None:
            session = cache.create_chat_session(session_id, user_id, chart_data)
            print(f"[ChatSession] Created new session: {session_id}")
        else:
            print(f"[ChatSession] Retrieved existing session: {session_id} (messages: {session.get('message_count', 0)})")

        return session

    @staticmethod
    def get_context_for_prompt(session: dict) -> str:
        """
        Build context string for the AI prompt.

        Returns a condensed context including:
        - Chart data summary
        - Conversation summary (if exists)
        """
        chart = session.get("chart_data", {})
        summary = session.get("summary", "")

        # Build chart summary
        sun = chart.get("sun_sign", "Unknown")
        moon = chart.get("moon_sign", "Unknown")
        rising = chart.get("rising_sign", "Unknown")

        context = f"User's chart: Sun in {sun}, Moon in {moon}, Rising in {rising}."

        # Add conversation summary if it exists
        if summary:
            context += f"\n\nConversation context: {summary}"

        return context

    @staticmethod
    def increment_message_count(session_id: str):
        """Increment message count for session."""
        cache = get_cache()
        session = cache.get_chat_session(session_id)
        if session:
            session["message_count"] = session.get("message_count", 0) + 1
            session["updated_at"] = datetime.now().isoformat()

    @staticmethod
    async def update_summary_async(
        session_id: str,
        user_message: str,
        assistant_response: str
    ):
        """
        Asynchronously update the conversation summary.

        Uses a lightweight model (GPT-3.5-turbo) to update the summary
        without blocking the main response.
        """
        cache = get_cache()
        session = cache.get_chat_session(session_id)

        if not session:
            return

        old_summary = session.get("summary", "")

        # Only update every few messages to reduce API calls
        message_count = session.get("message_count", 0)
        if message_count > 0 and message_count % 3 != 0:
            # Just append to buffer for now
            return

        # Generate updated summary
        new_summary = await ChatSessionService._generate_summary_update(
            old_summary, user_message, assistant_response
        )

        if new_summary:
            cache.update_chat_summary(session_id, new_summary)
            print(f"[ChatSession] Updated summary for {session_id}")

    @staticmethod
    async def _generate_summary_update(
        old_summary: str,
        user_message: str,
        assistant_response: str
    ) -> Optional[str]:
        """Call lightweight model to update summary."""
        openai_key = os.getenv("OPENAI_API_KEY")
        if not openai_key:
            return None

        # Build the update prompt
        if old_summary:
            prompt = f"""Update this conversation summary with the new exchange.
Keep it concise (2-3 sentences max). Focus on key topics, questions asked, and important details mentioned.

Current summary: {old_summary}

New exchange:
User: {user_message}
Nova: {assistant_response}

Updated summary (2-3 sentences):"""
        else:
            prompt = f"""Create a brief summary (1-2 sentences) of this conversation start.
Focus on what the user is interested in and any personal details mentioned.

User: {user_message}
Nova: {assistant_response}

Summary:"""

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {openai_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "gpt-3.5-turbo",  # Cheaper model for summarization
                        "messages": [
                            {
                                "role": "system",
                                "content": "You are a concise summarizer. Keep summaries brief and focused."
                            },
                            {"role": "user", "content": prompt}
                        ],
                        "max_tokens": 100,
                        "temperature": 0.3,
                    },
                    timeout=10.0,
                )

                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"].strip()

        except Exception as e:
            print(f"[ChatSession] Summary update failed: {e}")

        return None


# =============================================================================
# Utility Functions
# =============================================================================

def generate_session_id(user_id: str) -> str:
    """Generate a unique session ID."""
    import uuid
    return f"session_{user_id}_{uuid.uuid4().hex[:8]}"


def cleanup_all_caches():
    """Run cleanup on all caches."""
    cache = get_cache()
    cache.cleanup_old_sessions(max_age_hours=24)
    print("[Cache] Cleanup completed")

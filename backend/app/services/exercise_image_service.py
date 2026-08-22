"""Attaches a thumbnail photo to each exercise in a generated plan, via the
Pexels API (free, keyword search by exercise name — see backend/.env.example).

This is a pure nice-to-have for the Plan screen. Every call in here is wrapped
so that a missing key, a slow network, or Pexels being down never breaks plan
generation — worst case, exercises just render without a photo (the frontend
already has an icon fallback for that).
"""

import logging
from concurrent.futures import ThreadPoolExecutor
from typing import Iterable

import httpx

from app.core.config import Settings, get_settings

logger = logging.getLogger(__name__)

_PEXELS_SEARCH_URL = "https://api.pexels.com/v1/search"
_TIMEOUT_SECONDS = 4.0
_MAX_WORKERS = 8

# Small in-process cache so a plan with repeated exercise names (e.g. "Push-up"
# on both Day 1 and Day 3) only triggers one Pexels call per unique name, and so
# regenerating a plan doesn't re-fetch images we already looked up this run.
_cache: dict[str, str | None] = {}


def _fetch_one(client: httpx.Client, exercise_name: str) -> str | None:
    if exercise_name in _cache:
        return _cache[exercise_name]

    url: str | None = None
    try:
        response = client.get(
            _PEXELS_SEARCH_URL,
            params={"query": f"{exercise_name} exercise", "per_page": 1, "orientation": "square"},
        )
        if response.status_code == 200:
            photos = response.json().get("photos", [])
            if photos:
                url = photos[0].get("src", {}).get("medium")
    except Exception:  # noqa: BLE001 — network hiccups must never break plan generation
        logger.warning("Pexels lookup failed for exercise %r", exercise_name, exc_info=True)

    _cache[exercise_name] = url
    return url


def fetch_exercise_image_urls(
    exercise_names: Iterable[str],
    settings: Settings | None = None,
) -> dict[str, str | None]:
    """Returns {exercise_name: image_url_or_None} for every name given.

    Safe to call with an empty/unset API key — just returns None for everything.
    """
    settings = settings or get_settings()
    api_key = settings.pexels_api_key.get_secret_value() if settings.pexels_api_key else None
    unique_names = list(dict.fromkeys(exercise_names))  # de-dupe, keep order

    if not api_key or not unique_names:
        return {name: None for name in unique_names}

    # A plan easily has 8-12 unique exercise names. Looking those up one at a time
    # (each a real network round-trip) was adding several extra seconds on top of
    # the AI generation call itself — run them concurrently instead so the total
    # wait is roughly "one request's latency", not "N requests' latency added up".
    try:
        with httpx.Client(headers={"Authorization": api_key}, timeout=_TIMEOUT_SECONDS) as client:
            with ThreadPoolExecutor(max_workers=min(_MAX_WORKERS, len(unique_names))) as pool:
                results = pool.map(lambda name: (name, _fetch_one(client, name)), unique_names)
                return dict(results)
    except Exception:  # noqa: BLE001
        logger.warning("Pexels image lookup skipped (client setup failed)", exc_info=True)
        return {name: None for name in unique_names}

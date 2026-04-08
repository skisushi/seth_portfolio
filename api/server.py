"""
Veyant Local Preference Engine API
Implements F7.1–F7.4 against Ollama (local) + SQLite

Endpoints:
  GET  /health
  GET  /api/travelers/{traveler_id}/trips
  POST /api/travelers/{traveler_id}/preferences/derive
  GET  /api/travelers/{traveler_id}/preferences
"""

import json
import sqlite3
import asyncio
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from preference_extractor import PreferenceExtractor
from preference_store import PreferenceStore

# ── paths ──────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).parent.parent
SEED_DATA = ROOT / "data" / "seed" / "sarah_chen_full.json"
DB_PATH = ROOT / "api" / "preferences.db"

# ── load seed data once at startup ────────────────────────────────────────────
_traveler_data: dict = {}

@asynccontextmanager
async def lifespan(app: FastAPI):
    global _traveler_data
    if SEED_DATA.exists():
        with open(SEED_DATA) as f:
            data = json.load(f)
        _traveler_data[data["id"]] = data
        print(f"Loaded traveler: {data['id']} ({len(data.get('trips', []))} trips)")
    PreferenceStore(DB_PATH).init_db()
    print("Preference store initialized.")
    yield

app = FastAPI(title="Veyant Preference Engine", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── health ─────────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "travelers_loaded": list(_traveler_data.keys())}

# ── trips ──────────────────────────────────────────────────────────────────────
@app.get("/api/travelers/{traveler_id}/trips")
async def get_trips(
    traveler_id: str,
    limit: int = 50,
    before: Optional[str] = None,
):
    traveler = _traveler_data.get(traveler_id)
    if not traveler:
        raise HTTPException(status_code=404, detail=f"Traveler {traveler_id} not found")

    trips = traveler.get("trips", [])

    # Filter by date if requested
    if before:
        trips = [t for t in trips if t.get("startDate", "") < before]

    # Sort descending by start date
    trips = sorted(trips, key=lambda t: t.get("startDate", ""), reverse=True)

    return {
        "travelerId": traveler_id,
        "trips": trips[:limit],
        "total": len(trips),
    }

# ── preference derivation ──────────────────────────────────────────────────────
@app.post("/api/travelers/{traveler_id}/preferences/derive")
async def derive_preferences(traveler_id: str):
    traveler = _traveler_data.get(traveler_id)
    if not traveler:
        raise HTTPException(status_code=404, detail=f"Traveler {traveler_id} not found")

    trips = traveler.get("trips", [])
    if len(trips) < 3:
        raise HTTPException(
            status_code=422,
            detail=f"Need at least 3 trips to derive preferences, found {len(trips)}"
        )

    extractor = PreferenceExtractor()
    try:
        profile = await extractor.derive(traveler_id, trips)
    except Exception as e:
        import traceback
        detail = f"Inference failed: {type(e).__name__}: {str(e)}\n{traceback.format_exc()}"
        print(detail)
        raise HTTPException(status_code=503, detail=detail)

    store = PreferenceStore(DB_PATH)
    store.save(profile)

    return profile

# ── get active preference profile ─────────────────────────────────────────────
@app.get("/api/travelers/{traveler_id}/preferences")
async def get_preferences(traveler_id: str):
    store = PreferenceStore(DB_PATH)
    profile = store.get_active(traveler_id)
    if not profile:
        raise HTTPException(
            status_code=404,
            detail=f"No preference profile found for {traveler_id}. Call POST /derive first."
        )
    return profile

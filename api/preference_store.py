"""
PreferenceStore — SQLite-backed storage for derived preference profiles.
Implements US 7.4.1, 7.4.2

Schema is designed to migrate cleanly to Postgres — no SQLite-specific features used.
"""

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


class PreferenceStore:
    def __init__(self, db_path: Path):
        self.db_path = db_path

    def init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS preference_profiles (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    traveler_id TEXT NOT NULL,
                    profile_json TEXT NOT NULL,
                    derived_at TEXT NOT NULL,
                    model_used TEXT,
                    trip_count INTEGER,
                    schema_version TEXT,
                    is_active INTEGER NOT NULL DEFAULT 1,
                    created_at TEXT NOT NULL DEFAULT (datetime('now'))
                )
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_traveler_active
                ON preference_profiles(traveler_id, is_active)
            """)
            conn.commit()

    def save(self, profile: dict):
        """Save a new profile and mark previous ones inactive."""
        traveler_id = profile.get("travelerId")
        if not traveler_id:
            raise ValueError("Profile missing travelerId")

        with sqlite3.connect(self.db_path) as conn:
            # Deactivate existing profiles for this traveler
            conn.execute(
                "UPDATE preference_profiles SET is_active = 0 WHERE traveler_id = ?",
                (traveler_id,),
            )
            # Insert new active profile
            conn.execute(
                """INSERT INTO preference_profiles
                   (traveler_id, profile_json, derived_at, model_used, trip_count, schema_version, is_active)
                   VALUES (?, ?, ?, ?, ?, ?, 1)""",
                (
                    traveler_id,
                    json.dumps(profile),
                    profile.get("derivedAt", datetime.now(timezone.utc).isoformat()),
                    profile.get("modelUsed"),
                    profile.get("tripCount"),
                    profile.get("schemaVersion", "1.0"),
                ),
            )
            conn.commit()

    def get_active(self, traveler_id: str) -> Optional[dict]:
        """Return the current active profile for a traveler, or None."""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute(
                """SELECT profile_json, derived_at, is_active
                   FROM preference_profiles
                   WHERE traveler_id = ? AND is_active = 1
                   ORDER BY created_at DESC LIMIT 1""",
                (traveler_id,),
            ).fetchone()

        if not row:
            return None

        profile = json.loads(row["profile_json"])
        profile["_meta"] = {
            "source": "derived",
            "derivedAt": row["derived_at"],
            "stale": self._is_stale(traveler_id),
        }
        return profile

    def get_history(self, traveler_id: str) -> list[dict]:
        """Return all profiles for a traveler, newest first."""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                """SELECT profile_json, derived_at, is_active
                   FROM preference_profiles
                   WHERE traveler_id = ?
                   ORDER BY created_at DESC""",
                (traveler_id,),
            ).fetchall()

        return [json.loads(r["profile_json"]) for r in rows]

    def _is_stale(self, traveler_id: str, stale_days: int = 30) -> bool:
        """Check if the active profile is older than stale_days."""
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                """SELECT derived_at FROM preference_profiles
                   WHERE traveler_id = ? AND is_active = 1
                   ORDER BY created_at DESC LIMIT 1""",
                (traveler_id,),
            ).fetchone()

        if not row:
            return True

        try:
            derived = datetime.fromisoformat(row[0].replace("Z", "+00:00"))
            age_days = (datetime.now(timezone.utc) - derived).days
            return age_days > stale_days
        except Exception:
            return True

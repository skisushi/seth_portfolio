"""
PreferenceExtractor — derives traveler preferences from trip history using Ollama.
Implements US 7.3.1, 7.3.2, 7.3.3
"""

import json
import re
import httpx
from datetime import datetime, timezone
from typing import Any


OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "llama3:8b"


def _build_trip_summary(trips: list[dict]) -> str:
    """Convert raw trip JSON into a human-readable summary for the prompt.

    Token-efficient: one line per trip, not a full JSON dump.
    """
    lines = []
    for t in trips[:15]:  # cap at 15 trips to stay within context window
        air = t.get("air", [])
        hotel = t.get("hotel", [])
        car = t.get("car", [])

        # Air summary — seat data is in air[].segments[]
        air_parts = []
        for seg in air:
            airline = seg.get("airline", "unknown")
            flights = seg.get("flightNumbers", [])
            fn = flights[0] if flights else ""
            # Nested segments have seatType and cabin
            seat_types = []
            cabins = []
            for s in seg.get("segments", []):
                st = s.get("seatType", "")
                if st:
                    seat_types.append(st)
                cb = s.get("cabin", "") or s.get("cabinClass", "")
                if cb:
                    cabins.append(cb)
            seat_str = seat_types[0] if seat_types else ""
            cabin_str = cabins[0] if cabins else ""
            air_parts.append(f"{airline} {fn} {cabin_str} {seat_str}".strip())

        # Hotel summary — uses hotelChain field
        hotel_parts = []
        for h in hotel:
            chain = h.get("hotelChain", h.get("brand", h.get("name", "unknown")))
            city = h.get("address", {}).get("city", "") if isinstance(h.get("address"), dict) else ""
            nights = h.get("nights", "")
            rate_type = h.get("rateType", "")
            hotel_parts.append(f"{chain} {city} {nights}nts {rate_type}".strip())

        # Car summary
        car_parts = []
        for c in car:
            company = c.get("rentalCompany", c.get("company", ""))
            if company:
                car_parts.append(company)

        line = (
            f"- {t.get('startDate','?')} {t.get('origin','?')}→{t.get('destination','?')}: "
            f"Air: {', '.join(air_parts) or 'none'} | "
            f"Hotel: {', '.join(hotel_parts) or 'none'}"
        )
        if car_parts:
            line += f" | Car: {', '.join(car_parts)}"
        lines.append(line)

    return "\n".join(lines)


SYSTEM_PROMPT = (
    "You are a travel data analyst. "
    "You respond ONLY with valid JSON. "
    "Never add explanatory text before or after the JSON."
)

EXTRACTION_PROMPT_TEMPLATE = """Travel history for {name} ({count} trips):

{summary}

Identify travel preferences. Confidence: high=>70% of trips, medium=40-70%, low<40%.

Reply with ONLY this JSON, no other text:
{{"airPreferences":{{"preferredCarriers":[{{"carrier":"Delta","confidence":"high","percentage":80}}],"cabinPreference":{{"longHaul":"economy","shortHaul":"economy","confidence":"medium"}},"seatType":{{"preference":"aisle","confidence":"high"}},"nonStopPreferred":{{"value":true,"confidence":"high"}}}},"hotelPreferences":{{"preferredBrands":[{{"brand":"Marriott","confidence":"high","percentage":70}}],"tierPreference":{{"tier":"upscale","confidence":"medium"}},"locationPreference":{{"preference":"downtown","confidence":"medium"}}}},"bookingBehavior":{{"typicalLeadTimeDays":14,"selfBooked":{{"percentage":80,"confidence":"medium"}}}},"loyaltyPriority":{{"topPrograms":["Delta SkyMiles"],"consolidationPattern":"consolidates with Delta and Marriott"}},"derivedAt":"{timestamp}","tripCount":{count},"modelUsed":"{model}","schemaVersion":"1.0"}}

Replace the example values above with values derived from the actual travel history. Return only the JSON."""


class PreferenceExtractor:
    async def derive(self, traveler_id: str, trips: list[dict]) -> dict[str, Any]:
        """Derive preference profile from trip history via Ollama."""
        summary = _build_trip_summary(trips)

        # Get traveler name from first trip's context if available
        name = "the traveler"

        ts = datetime.now(timezone.utc).isoformat()
        prompt = (
            EXTRACTION_PROMPT_TEMPLATE
            .replace("{name}", name)
            .replace("{count}", str(len(trips)))
            .replace("{summary}", summary)
            .replace("{timestamp}", ts)
            .replace("{model}", MODEL)
        )

        raw = await self._call_ollama(prompt)
        profile = self._parse_json(raw)
        profile["travelerId"] = traveler_id
        return profile

    async def _call_ollama(self, prompt: str) -> str:
        payload = {
            "model": MODEL,
            "prompt": f"[SYSTEM]{SYSTEM_PROMPT}[/SYSTEM]\n\n{prompt}",
            "stream": False,
            "options": {
                "temperature": 0.2,
                "num_predict": 1500,
            },
        }
        async with httpx.AsyncClient(timeout=300.0) as client:
            resp = await client.post(OLLAMA_URL, json=payload)
            resp.raise_for_status()
        return resp.json()["response"]

    @staticmethod
    def _parse_json(raw: str) -> dict:
        # Fast path
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            pass
        # Extract JSON block
        match = re.search(r"\{.*\}", raw, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(0))
            except json.JSONDecodeError:
                pass
        raise ValueError(f"Could not parse JSON from model output: {raw[:200]}")

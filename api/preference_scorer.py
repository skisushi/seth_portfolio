"""
PreferenceScorer — scores flight/hotel options against a derived preference profile.
Implements US 7.5.1

Pure function, deterministic, no LLM calls.
Max score: 100 points (flights) or 100 points (hotels)
"""

from typing import Union


def score_flight(option: dict, profile: dict) -> dict:
    """Score a flight option against derived preferences.

    Scoring:
      +30  preferred carrier match
      +25  cabin match for flight duration
      +15  seat type match
      +20  non-stop (if preferred)
      +10  upgradeable

    Returns: {score, breakdown, summary, source}
    """
    score = 0
    breakdown = {}

    air_prefs = profile.get("airPreferences", {})

    # Carrier (+30)
    carrier = option.get("carrier", "")
    preferred_carriers = [
        c.get("carrier", "").lower()
        for c in air_prefs.get("preferredCarriers", [])
        if c.get("confidence") in ("high", "medium")
    ]
    if carrier.lower() in preferred_carriers:
        score += 30
        breakdown["carrier"] = {"points": 30, "reason": f"{carrier} is a preferred carrier"}
    else:
        breakdown["carrier"] = {"points": 0, "reason": f"{carrier} is not a preferred carrier"}

    # Cabin (+25)
    cabin_pref = air_prefs.get("cabinPreference", {})
    option_cabin = option.get("cabin", "").lower().replace(" ", "_")
    # Use long-haul pref as default (most business travel)
    preferred_cabin = cabin_pref.get("longHaul", cabin_pref.get("shortHaul", "")).lower().replace(" ", "_")
    if preferred_cabin and option_cabin == preferred_cabin:
        score += 25
        breakdown["cabin"] = {"points": 25, "reason": f"{option_cabin} matches preferred cabin"}
    elif preferred_cabin:
        breakdown["cabin"] = {"points": 0, "reason": f"{option_cabin} does not match preferred {preferred_cabin}"}
    else:
        breakdown["cabin"] = {"points": 0, "reason": "No cabin preference on file"}

    # Seat type (+15)
    seat_pref = air_prefs.get("seatType", {}).get("preference", "").lower()
    seat_available = option.get("seatAvailable", "").upper()
    # Aisle seats: B, C, D, E, H, K; Window: A, F
    is_aisle = any(seat_available.endswith(c) for c in ["B", "C", "D", "E", "H", "K"])
    is_window = any(seat_available.endswith(c) for c in ["A", "F"])

    if seat_pref == "aisle" and is_aisle:
        score += 15
        breakdown["seat"] = {"points": 15, "reason": f"Seat {seat_available} is aisle (preferred)"}
    elif seat_pref == "window" and is_window:
        score += 15
        breakdown["seat"] = {"points": 15, "reason": f"Seat {seat_available} is window (preferred)"}
    elif seat_pref:
        breakdown["seat"] = {"points": 0, "reason": f"Seat {seat_available} does not match {seat_pref} preference"}
    else:
        breakdown["seat"] = {"points": 0, "reason": "No seat preference on file"}

    # Non-stop (+20)
    non_stop_pref = air_prefs.get("nonStopPreferred", {})
    if non_stop_pref.get("value") and non_stop_pref.get("confidence") in ("high", "medium"):
        if option.get("nonStop", True):  # default True since our catalog options are direct
            score += 20
            breakdown["nonStop"] = {"points": 20, "reason": "Non-stop matches preference"}
        else:
            breakdown["nonStop"] = {"points": 0, "reason": "Connecting flight — non-stop preferred"}
    else:
        breakdown["nonStop"] = {"points": 0, "reason": "No non-stop preference on file"}

    # Upgradeable (+10)
    if option.get("upgradeable"):
        score += 10
        breakdown["upgrade"] = {"points": 10, "reason": "Upgrade eligible"}
    else:
        breakdown["upgrade"] = {"points": 0, "reason": "Not upgrade eligible"}

    return {
        "score": score,
        "breakdown": breakdown,
        "summary": _flight_summary(score),
        "source": "derived",
    }


def score_hotel(option: dict, profile: dict) -> dict:
    """Score a hotel option against derived preferences.

    Scoring:
      +40  preferred brand match
      +30  loyalty benefits (lounge/upgrade)
      +30  rate competitiveness

    Returns: {score, breakdown, summary, source}
    """
    score = 0
    breakdown = {}

    hotel_prefs = profile.get("hotelPreferences", {})

    # Brand (+40)
    brand = option.get("brand", "")
    preferred_brands = [
        b.get("brand", "").lower()
        for b in hotel_prefs.get("preferredBrands", [])
        if b.get("confidence") in ("high", "medium")
    ]
    if brand.lower() in preferred_brands:
        score += 40
        breakdown["brand"] = {"points": 40, "reason": f"{brand} is a preferred hotel brand"}
    else:
        breakdown["brand"] = {"points": 0, "reason": f"{brand} is not a preferred brand"}

    # Loyalty benefits (+30)
    benefits = option.get("loyaltyBenefits", [])
    premium = [b for b in benefits if any(w in b.lower() for w in ["lounge", "upgrade", "suite"])]
    if premium:
        score += 30
        breakdown["loyalty"] = {"points": 30, "reason": f"Premium benefits: {', '.join(premium)}"}
    else:
        breakdown["loyalty"] = {"points": 0, "reason": "No premium loyalty benefits"}

    # Rate (+30)
    rate = option.get("ratePerNight", 9999)
    if rate < 300:
        score += 30
        breakdown["rate"] = {"points": 30, "reason": f"Competitive rate ${rate}/night"}
    elif rate < 400:
        score += 15
        breakdown["rate"] = {"points": 15, "reason": f"Moderate rate ${rate}/night"}
    else:
        breakdown["rate"] = {"points": 0, "reason": f"High rate ${rate}/night"}

    return {
        "score": score,
        "breakdown": breakdown,
        "summary": _hotel_summary(score),
        "source": "derived",
    }


def score_option(option: dict, profile: dict) -> dict:
    """Route to flight or hotel scorer based on option type."""
    if "flightNumber" in option or "carrier" in option:
        return score_flight(option, profile)
    return score_hotel(option, profile)


def _flight_summary(score: int) -> str:
    if score >= 80:
        return "Excellent match for traveler preferences"
    if score >= 60:
        return "Good match — minor preference gaps"
    if score >= 40:
        return "Acceptable — some preferences not met"
    return "Poor match — consider alternatives"


def _hotel_summary(score: int) -> str:
    if score >= 80:
        return "Excellent match for traveler preferences"
    if score >= 60:
        return "Good match — minor preference gaps"
    if score >= 40:
        return "Acceptable — some preferences not met"
    return "Poor match — consider alternatives"

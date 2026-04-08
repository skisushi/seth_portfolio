"""
Preference Profile Schema
Implements US 7.3.2 — Preference profile schema (Python types)
Reference: docs/Veyant_Preference_Engine_Azure_Architecture.md, Section 6.3
"""

from datetime import datetime
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field

SCHEMA_VERSION = "1.0"


class ConfidenceLevel(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class CabinPreference(str, Enum):
    ECONOMY = "economy"
    PREMIUM_ECONOMY = "premium-economy"
    BUSINESS = "business"
    FIRST = "first"


class SeatPreference(str, Enum):
    AISLE = "aisle"
    WINDOW = "window"
    MIDDLE = "middle"
    NO_PREFERENCE = "no-preference"


class HotelTier(str, Enum):
    ECONOMY = "economy"
    MIDSCALE = "midscale"
    UPSCALE = "upscale"
    UPPER_UPSCALE = "upper-upscale"
    LUXURY = "luxury"


class HotelLocation(str, Enum):
    DOWNTOWN = "downtown"
    AIRPORT = "airport"
    SUBURBAN = "suburban"
    NO_PREFERENCE = "no-preference"


class CarrierPreference(BaseModel):
    carrier: str = Field(..., description="Airline name or IATA code")
    confidence: ConfidenceLevel
    frequency_pct: Optional[float] = Field(
        None,
        description="Percentage of trips on this carrier (0-100)"
    )


class HotelChainPreference(BaseModel):
    chain: str
    confidence: ConfidenceLevel
    frequency_pct: Optional[float] = None


class CabinByDuration(BaseModel):
    """Cabin preference varies by flight duration."""
    short_haul: CabinPreference = Field(
        ...,
        description="Preferred cabin for flights under 3 hours"
    )
    long_haul: CabinPreference = Field(
        ...,
        description="Preferred cabin for flights 3 hours or more"
    )
    confidence: ConfidenceLevel


class AirPreferences(BaseModel):
    preferred_carriers: list[CarrierPreference]
    cabin_by_duration: CabinByDuration
    seat_preference: SeatPreference
    seat_confidence: ConfidenceLevel
    typical_booking_lead_days: Optional[int] = None
    booking_lead_confidence: Optional[ConfidenceLevel] = None


class HotelPreferences(BaseModel):
    preferred_chains: list[HotelChainPreference]
    tier_preference: Optional[HotelTier] = None
    tier_confidence: Optional[ConfidenceLevel] = None
    location_preference: Optional[HotelLocation] = None
    location_confidence: Optional[ConfidenceLevel] = None


class CarPreferences(BaseModel):
    preferred_companies: list[str] = Field(default_factory=list)
    typical_vehicle_class: Optional[str] = None
    confidence: ConfidenceLevel = ConfidenceLevel.LOW


class LoyaltyPriority(BaseModel):
    program: str
    priority_rank: int = Field(..., ge=1, description="1 = highest priority")


class TripPatterns(BaseModel):
    average_trip_length_days: Optional[float] = None
    typical_purposes: list[str] = Field(default_factory=list)
    business_percentage: Optional[float] = None


class DerivedPreferenceProfile(BaseModel):
    """The structured output of the preference extraction engine.

    Stored as JSON in the profile_json column of preference_profiles Delta table.
    """
    schema_version: str = Field(default=SCHEMA_VERSION)
    tenant_id: str
    traveler_id: str
    derived_at: datetime
    model_used: str
    trip_window_days: int
    trip_record_count: int
    confidence_overall: float = Field(..., ge=0.0, le=1.0)

    air: AirPreferences
    hotel: HotelPreferences
    car: CarPreferences
    loyalty_priority: list[LoyaltyPriority] = Field(default_factory=list)
    trip_patterns: TripPatterns

    notes: Optional[str] = Field(
        None,
        description="LLM-generated narrative summary of the traveler's patterns"
    )

    class Config:
        use_enum_values = True

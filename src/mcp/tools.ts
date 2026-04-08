import { evaluate } from '../domain/policy-engine.js';
import {
  acmeCorpPolicy,
  sarahChen,
  flightBA178Wed,
  flightDL401,
  flightAA87,
  hotelLondonParkLane,
  hotelMarriottNYC,
} from '../domain/mock-data.js';
import type {
  TripChangeProposal,
  FlightOption,
  HotelOption,
} from '../domain/types.js';

// ─── check_policy_compliance ──────────────────────────────────────────────────
// Evaluates a proposed trip change against Acme Corp's travel policy.
// Input: a TripChangeProposal object
// Output: PolicyComplianceResult with per-rule breakdown and overall status

export function checkPolicyCompliance(proposal: TripChangeProposal) {
  return evaluate(acmeCorpPolicy, proposal);
}

// ─── search_travel_options ────────────────────────────────────────────────────
// Returns available flights or hotels from the mock supplier catalog.
// Filters by type and optionally by route/city.

export interface SearchParams {
  type: 'flight' | 'hotel';
  origin?: string;     // for flights: IATA code e.g. "LHR"
  destination?: string; // for flights: IATA code e.g. "BOS"
  city?: string;       // for hotels: city name e.g. "London"
}

export function searchTravelOptions(params: SearchParams): (FlightOption | HotelOption)[] {
  if (params.type === 'flight') {
    const flights = [flightBA178Wed, flightDL401, flightAA87];
    return flights.filter((f) => {
      if (params.origin && f.origin !== params.origin.toUpperCase()) return false;
      if (params.destination && f.destination !== params.destination.toUpperCase()) return false;
      return true;
    });
  }

  if (params.type === 'hotel') {
    const hotels = [hotelLondonParkLane, hotelMarriottNYC];
    return hotels.filter((h) => {
      if (params.city && !h.city.toLowerCase().includes(params.city.toLowerCase())) return false;
      return true;
    });
  }

  return [];
}

// ─── get_preference_score ─────────────────────────────────────────────────────
// Scores a flight or hotel option against Sarah Chen's derived preferences.
// Calls the local Veyant Preference Engine API (Python/Ollama) if available,
// falls back to static mock scoring if the API is not running.

const PREFERENCE_API = 'http://localhost:8000';
const SARAH_TRAVELER_ID = 'traveler-sc-001';

export interface PreferenceScore {
  score: number;
  factors: string[];
  summary: string;
  source: 'derived' | 'mock';
}

export async function getPreferenceScore(option: FlightOption | HotelOption): Promise<PreferenceScore> {
  // Try the live preference API first
  try {
    const res = await fetch(`${PREFERENCE_API}/api/travelers/${SARAH_TRAVELER_ID}/preferences`);
    if (res.ok) {
      const profile = await res.json();
      return scoreWithDerivedProfile(option, profile);
    }
  } catch {
    // API not running — fall through to mock
  }

  // Fallback: static mock scoring
  return scoreMock(option);
}

function scoreWithDerivedProfile(option: FlightOption | HotelOption, profile: Record<string, unknown>): PreferenceScore {
  const factors: string[] = [];
  let score = 0;

  if ('flightNumber' in option) {
    const flight = option as FlightOption;
    const airPrefs = (profile.airPreferences ?? {}) as Record<string, unknown>;
    const carriers = (airPrefs.preferredCarriers as Array<{carrier: string; confidence: string}> ?? [])
      .filter(c => c.confidence === 'high' || c.confidence === 'medium')
      .map(c => c.carrier.toLowerCase());

    if (carriers.includes(flight.carrier.toLowerCase())) {
      score += 30; factors.push(`+30 — ${flight.carrier} is a derived preferred carrier`);
    } else {
      factors.push(`+0 — ${flight.carrier} is not a preferred carrier`);
    }

    const nonStop = (airPrefs.nonStopPreferred as {value: boolean; confidence: string} | undefined);
    if (nonStop?.value && nonStop.confidence !== 'low') {
      score += 20; factors.push('+20 — non-stop matches derived preference');
    }

    const seatPref = (airPrefs.seatType as {preference: string} | undefined)?.preference?.toLowerCase() ?? '';
    const seat = option.seatAvailable?.toUpperCase() ?? '';
    const isAisle = ['B','C','D','E','H','K'].some(c => seat.endsWith(c));
    const isWindow = ['A','F'].some(c => seat.endsWith(c));
    if ((seatPref === 'aisle' && isAisle) || (seatPref === 'window' && isWindow)) {
      score += 15; factors.push(`+15 — seat ${seat} matches derived ${seatPref} preference`);
    } else {
      factors.push(`+0 — seat ${seat} does not match ${seatPref || 'unknown'} preference`);
    }

    if (flight.changeFee === 0) { score += 15; factors.push('+15 — $0 change fee'); }
    if (flight.upgradeable) { score += 10; factors.push('+10 — upgrade eligible'); }

  } else {
    const hotel = option as HotelOption;
    const hotelPrefs = (profile.hotelPreferences ?? {}) as Record<string, unknown>;
    const brands = (hotelPrefs.preferredBrands as Array<{brand: string; confidence: string}> ?? [])
      .filter(b => b.confidence === 'high' || b.confidence === 'medium')
      .map(b => b.brand.toLowerCase());

    if (brands.includes(hotel.brand.toLowerCase())) {
      score += 40; factors.push(`+40 — ${hotel.brand} is a derived preferred brand`);
    } else {
      factors.push(`+0 — ${hotel.brand} is not a preferred brand`);
    }

    const premium = hotel.loyaltyBenefits.filter(b => b.includes('lounge') || b.includes('upgrade'));
    if (premium.length > 0) { score += 30; factors.push(`+30 — loyalty benefits: ${premium.join(', ')}`); }
    else { factors.push('+0 — no premium loyalty benefits'); }

    if (hotel.ratePerNight < 300) { score += 30; factors.push(`+30 — competitive rate $${hotel.ratePerNight}/night`); }
    else if (hotel.ratePerNight < 400) { score += 15; factors.push(`+15 — moderate rate $${hotel.ratePerNight}/night`); }
    else { factors.push(`+0 — high rate $${hotel.ratePerNight}/night`); }
  }

  const summary = score >= 80 ? 'Excellent match for traveler preferences'
    : score >= 60 ? 'Good match — minor preference gaps'
    : score >= 40 ? 'Acceptable — some preferences not met'
    : 'Poor match — consider alternatives';

  return { score, factors, summary, source: 'derived' };
}

function scoreMock(option: FlightOption | HotelOption): PreferenceScore {
  const factors: string[] = [];
  let score = 0;

  if ('flightNumber' in option) {
    const flight = option as FlightOption;
    const preferredCarriers = ['British Airways', 'Delta', 'American Airlines'];
    if (preferredCarriers.includes(flight.carrier)) {
      score += 30; factors.push(`+30 — ${flight.carrier} is a preferred carrier (mock)`);
    } else { factors.push(`+0 — ${flight.carrier} is not preferred (mock)`); }
    score += 25; factors.push('+25 — non-stop (mock)');
    if (['A','F'].some(c => option.seatAvailable.toUpperCase().endsWith(c))) {
      score += 20; factors.push(`+20 — window seat ${option.seatAvailable} (mock)`);
    } else { factors.push(`+0 — seat ${option.seatAvailable} (mock)`); }
    if (flight.changeFee === 0) { score += 15; factors.push('+15 — $0 change fee'); }
    if (flight.upgradeable) { score += 10; factors.push('+10 — upgrade eligible'); }
  } else {
    const hotel = option as HotelOption;
    if (['Marriott','Westin','Sheraton'].includes(hotel.brand)) {
      score += 40; factors.push(`+40 — ${hotel.brand} is preferred (mock)`);
    } else { factors.push(`+0 — ${hotel.brand} not preferred (mock)`); }
    const premium = hotel.loyaltyBenefits.filter(b => b.includes('lounge') || b.includes('upgrade'));
    if (premium.length > 0) { score += 30; factors.push(`+30 — ${premium.join(', ')}`); }
    if (hotel.ratePerNight < 300) { score += 30; factors.push(`+30 — rate $${hotel.ratePerNight}/night`); }
    else if (hotel.ratePerNight < 400) { score += 15; factors.push(`+15 — rate $${hotel.ratePerNight}/night`); }
  }

  const summary = score >= 80 ? "Excellent match for Sarah's preferences"
    : score >= 60 ? 'Good match — minor preference gaps'
    : score >= 40 ? 'Acceptable — some preferences not met'
    : 'Poor match — consider alternatives';

  return { score, factors, summary, source: 'mock' };
}

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
// Scores a flight or hotel option against Sarah Chen's preferences.
// Returns a 0–100 score and a breakdown of factors.

export interface PreferenceScore {
  score: number;        // 0–100
  factors: string[];    // human-readable explanation of each factor
  summary: string;
}

export function getPreferenceScore(option: FlightOption | HotelOption): PreferenceScore {
  const factors: string[] = [];
  let score = 0;

  if ('flightNumber' in option) {
    // It's a flight
    const flight = option as FlightOption;

    // Carrier preference (+30)
    if (sarahChen.preferences.preferredCarriers.includes(flight.carrier)) {
      score += 30;
      factors.push(`+30 — ${flight.carrier} is a preferred carrier`);
    } else {
      factors.push(`+0 — ${flight.carrier} is not a preferred carrier`);
    }

    // Non-stop (we treat all catalog flights as non-stop for demo, +25)
    if (sarahChen.preferences.nonStopPreferred) {
      score += 25;
      factors.push('+25 — non-stop flight matches preference');
    }

    // Seat availability (+20 if window seat available, which Sarah prefers short-haul)
    if (option.seatAvailable.includes('A') || option.seatAvailable.includes('F')) {
      score += 20;
      factors.push(`+20 — seat ${option.seatAvailable} is a window seat`);
    } else {
      factors.push(`+0 — seat ${option.seatAvailable} does not match window preference`);
    }

    // Change fee (+15 if $0)
    if (flight.changeFee === 0) {
      score += 15;
      factors.push('+15 — $0 change fee (loyalty status benefit)');
    } else {
      factors.push(`+0 — change fee $${flight.changeFee}`);
    }

    // Upgrade eligible (+10)
    if (flight.upgradeable) {
      score += 10;
      factors.push('+10 — upgrade eligible');
    }

  } else {
    // It's a hotel
    const hotel = option as HotelOption;

    // Brand preference (+40)
    if (sarahChen.preferences.preferredHotelBrands.includes(hotel.brand)) {
      score += 40;
      factors.push(`+40 — ${hotel.brand} is a preferred hotel brand`);
    } else {
      factors.push(`+0 — ${hotel.brand} is not a preferred brand`);
    }

    // Loyalty benefits (+30 if has lounge or upgrade)
    const premiumBenefits = hotel.loyaltyBenefits.filter(
      (b) => b.includes('lounge') || b.includes('upgrade')
    );
    if (premiumBenefits.length > 0) {
      score += 30;
      factors.push(`+30 — loyalty benefits: ${premiumBenefits.join(', ')}`);
    } else {
      factors.push('+0 — no premium loyalty benefits');
    }

    // Rate competitiveness (+30 if under $300, +15 if under $400)
    if (hotel.ratePerNight < 300) {
      score += 30;
      factors.push(`+30 — competitive rate $${hotel.ratePerNight}/night`);
    } else if (hotel.ratePerNight < 400) {
      score += 15;
      factors.push(`+15 — moderate rate $${hotel.ratePerNight}/night`);
    } else {
      factors.push(`+0 — high rate $${hotel.ratePerNight}/night`);
    }
  }

  const summary =
    score >= 80
      ? 'Excellent match for Sarah\'s preferences'
      : score >= 60
      ? 'Good match — minor preference gaps'
      : score >= 40
      ? 'Acceptable — some preferences not met'
      : 'Poor match — consider alternatives';

  return { score, factors, summary };
}

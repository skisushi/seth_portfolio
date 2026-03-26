// === MY TRAVEL CUBE ===

export interface Traveler {
  id: string;
  name: string;
  email: string;
  company: string;
  homeAirport: string;
  loyaltyAccounts: LoyaltyAccount[];
  preferences: TravelerPreferences;
}

export interface LoyaltyAccount {
  program: string;       // "SkyTeam", "Marriott Bonvoy", "BA Executive Club"
  tier: string;          // "Platinum Elite", "Club Gold"
  memberId: string;
  pointsBalance: number;
  benefits: string[];    // ["free change", "lounge access", "upgrade eligible"]
  alliance?: string;     // "oneworld", "SkyTeam", "Star Alliance"
}

export interface TravelerPreferences {
  seatPreference: 'window' | 'aisle' | 'no_preference';
  cabinPreference: 'economy' | 'premium_economy' | 'business' | 'first';
  preferredCarriers: string[];
  preferredHotelBrands: string[];
  nonStopPreferred: boolean;
}

// === CORPORATE POLICY CUBE ===

export interface CorporatePolicy {
  companyId: string;
  companyName: string;
  rules: PolicyRule[];
  preferredSuppliers: PreferredSupplier[];
  approvalThresholds: ApprovalThreshold[];
  exceptions: PolicyException[];
}

export interface PolicyRule {
  id: string;
  category: 'flight' | 'hotel' | 'general';
  description: string;
  field: string;         // "hotel_nightly_rate", "flight_cabin", "total_additional_cost"
  operator: 'lt' | 'lte' | 'gt' | 'gte' | 'eq' | 'in';
  value: number | string | string[];
}

export interface PreferredSupplier {
  category: 'airline' | 'hotel';
  supplierName: string;
}

export interface ApprovalThreshold {
  maxAmount: number;
  currency: string;
  autoApprove: boolean;  // true = no manager needed below this amount
}

export interface PolicyException {
  market: string;        // "London", "New York", "San Francisco"
  field: string;         // same as PolicyRule.field
  overrideValue: number;
  reason: string;
}

// === SUPPLIER CATALOG CUBE ===

export interface FlightOption {
  id: string;
  carrier: string;
  flightNumber: string;
  origin: string;
  destination: string;
  departureTime: string;
  cabin: string;
  price: number;
  changeFee: number;
  upgradeable: boolean;
  upgradeMethod?: 'miles' | 'status_benefit';
  upgradeCost?: number;
  seatAvailable: string;
}

export interface HotelOption {
  id: string;
  brand: string;
  property: string;
  city: string;
  ratePerNight: number;
  rateType: 'corporate' | 'rack' | 'loyalty';
  available: boolean;
  loyaltyBenefits: string[];
}

// === TRIP CHANGE PROPOSAL (input to policy engine) ===

export interface TripChangeProposal {
  segments: ProposedSegment[];
  totalAdditionalCost: number;
  market: string;        // primary market for exception lookup
}

export interface ProposedSegment {
  type: 'flight' | 'hotel';
  supplier: string;
  rate: number;          // nightly rate for hotel, ticket price for flight
  cabin?: string;        // for flights — the purchased/ticketed cabin
  upgradeApplied?: boolean; // true when cabin is a status/miles upgrade; policy evaluates base fare only
  city?: string;         // for hotels, used for market exception lookup
}

// === POLICY ENGINE OUTPUT ===

export interface PolicyComplianceResult {
  overallStatus: 'compliant' | 'exception_applied' | 'requires_approval' | 'violation';
  ruleResults: PolicyRuleResult[];
  approvalsNeeded: string[];
}

export interface PolicyRuleResult {
  ruleId: string;
  description: string;
  status: 'pass' | 'exception' | 'fail';
  detail: string;
}

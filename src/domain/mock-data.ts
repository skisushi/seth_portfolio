import type {
  Traveler,
  CorporatePolicy,
  FlightOption,
  HotelOption,
  TripChangeProposal,
} from './types.js';

// === SARAH CHEN — My Travel Cube ===

export const sarahChen: Traveler = {
  id: 'traveler-sarah-chen',
  name: 'Sarah Chen',
  email: 'sarah.chen@acmecorp.com',
  company: 'acme-corp',
  homeAirport: 'BOS',
  loyaltyAccounts: [
    {
      program: 'SkyTeam',
      tier: 'Platinum Elite',
      memberId: 'ST-884201',
      pointsBalance: 84200,
      benefits: ['free change', 'lounge access', 'upgrade eligible', 'priority boarding'],
      alliance: 'SkyTeam',
    },
    {
      program: 'Delta SkyMiles',
      tier: 'Platinum',
      memberId: 'DL-229341',
      pointsBalance: 84200,
      benefits: ['free change', 'upgrade eligible', 'lounge access'],
      alliance: 'SkyTeam',
    },
    {
      program: 'Marriott Bonvoy',
      tier: 'Platinum',
      memberId: 'MB-771234',
      pointsBalance: 84200,
      benefits: ['room upgrade', 'executive lounge', 'late checkout', 'welcome gift'],
    },
    {
      program: 'BA Executive Club',
      tier: 'Club Gold',
      memberId: 'BA-339910',
      pointsBalance: 12400,
      benefits: ['free change', 'lounge access', 'upgrade eligible', 'extra baggage'],
      alliance: 'oneworld',
    },
  ],
  preferences: {
    seatPreference: 'window',
    cabinPreference: 'premium_economy',
    preferredCarriers: ['British Airways', 'Delta', 'American Airlines'],
    preferredHotelBrands: ['Marriott', 'Westin', 'Sheraton'],
    nonStopPreferred: true,
  },
};

// === ACME CORP — Corporate Policy Cube ===

export const acmeCorpPolicy: CorporatePolicy = {
  companyId: 'acme-corp',
  companyName: 'Acme Corp',
  rules: [
    {
      id: 'rule-hotel-nightly-rate',
      category: 'hotel',
      description: 'Hotel nightly rate must not exceed standard maximum',
      field: 'hotel_nightly_rate',
      operator: 'lte',
      value: 350,
    },
    {
      id: 'rule-flight-cabin',
      category: 'flight',
      description: 'Premium economy approved for flights over 5 hours; economy for shorter',
      field: 'flight_cabin',
      operator: 'in',
      value: ['economy', 'premium_economy'],
    },
  ],
  preferredSuppliers: [
    { category: 'airline', supplierName: 'British Airways' },
    { category: 'airline', supplierName: 'Delta' },
    { category: 'airline', supplierName: 'American Airlines' },
    { category: 'hotel', supplierName: 'Marriott' },
    { category: 'hotel', supplierName: 'Westin' },
  ],
  approvalThresholds: [
    {
      maxAmount: 2000,
      currency: 'USD',
      autoApprove: true,
    },
  ],
  exceptions: [
    {
      market: 'London',
      field: 'hotel_nightly_rate',
      overrideValue: 420,
      reason: 'High cost market exception — London approved rate',
    },
    {
      market: 'San Francisco',
      field: 'hotel_nightly_rate',
      overrideValue: 420,
      reason: 'High cost market exception — SF approved rate',
    },
    {
      market: 'New York',
      field: 'hotel_nightly_rate',
      overrideValue: 420,
      reason: 'High cost market exception — NYC approved rate',
    },
  ],
};

// === SUPPLIER CATALOG — Scenario 1 (London extension) ===

export const flightBA178Wed: FlightOption = {
  id: 'flight-ba178-wed-sept18',
  carrier: 'British Airways',
  flightNumber: 'BA178',
  origin: 'LHR',
  destination: 'BOS',
  departureTime: '2024-09-18T11:10:00Z',
  cabin: 'premium_economy',
  price: 0,
  changeFee: 0,
  upgradeable: false,
  seatAvailable: '32A',
};

export const hotelLondonParkLane: HotelOption = {
  id: 'hotel-marriott-london-park-lane',
  brand: 'Marriott',
  property: 'Marriott London Park Lane',
  city: 'London',
  ratePerNight: 385,
  rateType: 'corporate',
  available: true,
  loyaltyBenefits: ['room upgrade', 'executive lounge', 'late checkout'],
};

// === SUPPLIER CATALOG — Scenario 2 (NYC stopover) ===

export const flightDL401: FlightOption = {
  id: 'flight-dl401-wed-sept18',
  carrier: 'Delta',
  flightNumber: 'DL401',
  origin: 'LHR',
  destination: 'JFK',
  departureTime: '2024-09-18T10:15:00Z',
  cabin: 'business',
  price: 0,
  changeFee: 0,
  upgradeable: true,
  upgradeMethod: 'miles',
  upgradeCost: 25000,
  seatAvailable: '3A',
};

export const flightAA87: FlightOption = {
  id: 'flight-aa87-thu-sept19',
  carrier: 'American Airlines',
  flightNumber: 'AA87',
  origin: 'JFK',
  destination: 'BOS',
  departureTime: '2024-09-19T18:30:00Z',
  cabin: 'first',
  price: 187,
  changeFee: 0,
  upgradeable: true,
  upgradeMethod: 'status_benefit',
  upgradeCost: 0,
  seatAvailable: '2A',
};

export const hotelMarriottNYC: HotelOption = {
  id: 'hotel-marriott-nyc-midtown',
  brand: 'Marriott',
  property: 'Marriott New York Midtown',
  city: 'New York',
  ratePerNight: 289,
  rateType: 'corporate',
  available: true,
  loyaltyBenefits: ['room upgrade', 'late checkout'],
};

// === PRE-BUILT PROPOSALS (used in tests) ===

export const scenario1Proposal: TripChangeProposal = {
  segments: [
    {
      type: 'flight',
      supplier: 'British Airways',
      rate: 0,
      cabin: 'premium_economy',
    },
    {
      type: 'hotel',
      supplier: 'Marriott',
      rate: 385,
      city: 'London',
    },
  ],
  totalAdditionalCost: 385,
  market: 'London',
};

export const scenario2Proposal: TripChangeProposal = {
  segments: [
    {
      type: 'hotel',
      supplier: 'Marriott',
      rate: 385,
      city: 'London',
    },
    {
      type: 'flight',
      supplier: 'Delta',
      rate: 0,
      cabin: 'business',
      upgradeApplied: true, // 25,000 SkyTeam miles upgrade — base fare is premium economy
    },
    {
      type: 'hotel',
      supplier: 'Marriott',
      rate: 289,
      city: 'New York',
    },
    {
      type: 'flight',
      supplier: 'American Airlines',
      rate: 187,
      cabin: 'first',
      upgradeApplied: true, // Complimentary First Class upgrade — BA Club Gold / oneworld benefit
    },
  ],
  totalAdditionalCost: 861,
  market: 'London',
};

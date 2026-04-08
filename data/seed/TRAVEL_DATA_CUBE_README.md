# Veyant Travel Data Cube - Documentation

## Overview

This dataset provides synthetic but realistic travel data for five distinct traveler personas, designed to demonstrate Veyant's AI orchestration capabilities and pattern recognition algorithms. The data spans 2 years of travel history (2023-2024) with complete pricing breakdowns, loyalty integration, and calendar context.

## Dataset Structure

### File Organization

```
/reference/
  traveler_personas_reference.json    # Small dataset: 5 personas × 3 trips each (~50KB)
                                      # Use for: Technical discussions, prototype development
  
/full_datasets/
  road_warrior_full.json              # Complete 2-year history: ~40 trips, 100+ segments
  executive_traveler_full.json        # Complete 2-year history: ~30 trips, 50+ segments  
  hybrid_professional_full.json       # Complete 2-year history: ~25 trips, 35+ segments
  leisure_enthusiast_full.json        # Complete 2-year history: ~15 trips, 25+ segments
  international_jet_setter_full.json  # Complete 2-year history: ~35 trips, 75+ segments
```

### Persona Profiles

#### 1. Road Warrior (Marcus Chen)
- **Annual Segments:** 100+
- **Travel Mix:** 80% business / 20% leisure
- **Geography:** Primarily domestic, quarterly international
- **Loyalty Status:** Delta Diamond, United 1K, Hilton Diamond, Marriott Platinum
- **Pattern Highlights:** 
  - Consistent airline preference (Delta 68%, United 32%)
  - Always books aisle seats
  - Elite status benefits heavily utilized
  - Frequent SLC → SFO, SEA, DEN, LAX routes

#### 2. Executive Traveler (Sarah Martinez)
- **Annual Segments:** 40-60
- **Travel Mix:** 60% business / 40% leisure
- **Geography:** 70% domestic, 30% international
- **Loyalty Status:** United Platinum, American Gold, Marriott Gold
- **Pattern Highlights:**
  - Assistant books most trips
  - Premium cabin upgrades common
  - International business class preferences
  - Extended stays for bleisure

#### 3. Hybrid Professional (James Park)
- **Annual Segments:** 30-40
- **Travel Mix:** 50% business / 50% leisure
- **Geography:** Mix of domestic and international
- **Loyalty Status:** Delta Gold, Southwest A-List, Hyatt Discoverist
- **Pattern Highlights:**
  - Frequently extends business trips for leisure
  - Price-conscious on leisure bookings
  - Vacation destination diversity
  - Weekend trip optimization

#### 4. Leisure Enthusiast (Amanda Rodriguez)
- **Annual Segments:** 20-25
- **Travel Mix:** 90% leisure / 10% business
- **Geography:** Primarily vacation destinations
- **Loyalty Status:** Southwest Companion Pass, Marriott Silver
- **Pattern Highlights:**
  - Family travel (2 adults, 2 children patterns)
  - Resort and theme park destinations
  - Seasonal travel (summer, holidays)
  - Advance booking (60-90 days out)

#### 5. International Jet Setter (David Kim)
- **Annual Segments:** 60-80
- **Travel Mix:** 70% business / 30% leisure
- **Geography:** 60% international, 40% domestic
- **Loyalty Status:** United 1K, Star Alliance Gold, Marriott Platinum, Hyatt Globalist
- **Pattern Highlights:**
  - Complex multi-city routings
  - Business class international
  - Multiple loyalty programs across alliances
  - Asia-Pacific corridor frequency

## Data Dictionary

### Top-Level Structure

```json
{
  "id": "string",                    // Unique traveler identifier
  "partitionKey": "string",          // CosmosDB partition key (same as id)
  "personaType": "string",           // Persona category
  "profile": {},                     // Traveler demographics and preferences
  "loyaltyAccounts": [],             // All loyalty program memberships
  "paymentMethods": [],              // Payment cards on file
  "trips": [],                       // Array of complete trip records
  "metadata": {}                     // Dataset creation info
}
```

### Profile Object

```json
{
  "firstName": "string",
  "lastName": "string",
  "email": "string",
  "phone": "string",
  "dateOfBirth": "YYYY-MM-DD",
  "address": {
    "street": "string",
    "city": "string",
    "state": "string",
    "zip": "string",
    "country": "string"
  },
  "employment": {
    "company": "string",
    "title": "string",
    "department": "string",
    "employeeId": "string"
  },
  "travelProfile": {
    "annualSegments": number,
    "primaryPurpose": "business|leisure",
    "businessPercentage": number,
    "preferredAirlines": ["string"],
    "preferredHotels": ["string"],
    "preferredCarRental": ["string"],
    "seatPreference": "aisle|window|middle",
    "mealPreference": "string",
    "specialRequests": ["string"]
  }
}
```

### Loyalty Accounts

```json
{
  "program": "string",               // Program name (e.g., "Delta SkyMiles")
  "accountNumber": "string",         // Loyalty number
  "status": "string",                // Current tier (Diamond, Gold, etc.)
  "miles": number,                   // Current balance (points/miles)
  "statusExpiresDate": "YYYY-MM-DD"  // Status expiration
}
```

### Trip Object

```json
{
  "tripId": "string",                // Unique trip identifier
  "tripName": "string",              // Descriptive trip name
  "tripType": "business|leisure",    // Trip purpose
  "startDate": "YYYY-MM-DD",         // Trip start
  "endDate": "YYYY-MM-DD",           // Trip end
  "origin": "string",                // Origin airport code
  "destination": "string",           // Destination airport code
  "bookedDate": "YYYY-MM-DD",        // When trip was booked
  "bookedBy": "self|assistant",      // Who made the booking
  "totalCost": number,               // Total trip cost (USD)
  "calendarEvents": [],              // Outlook calendar meetings
  "air": [],                         // Air travel segments
  "hotel": [],                       // Hotel stays
  "car": [],                         // Car rentals
  "ground": []                       // Ground transportation
}
```

### Air Travel Detail

```json
{
  "confirmationCode": "string",      // Airline confirmation
  "recordLocator": "string",         // PNR locator
  "airline": "string",               // Operating carrier
  "flightNumbers": ["string"],       // All flight numbers in journey
  "bookingClass": "string",          // Fare booking class (Y, J, F, etc.)
  "fareClass": "string",             // Fare type description
  "segments": [],                    // Outbound flight segments
  "returnSegments": [],              // Return flight segments
  "passengers": [],                  // Passenger details
  "pricing": {
    "baseFare": number,
    "taxes": [
      {
        "code": "string",            // Tax code (US, XF, AY, ZP)
        "description": "string",
        "amount": number
      }
    ],
    "ancillaries": [
      {
        "type": "string",            // seat_selection, checked_bag_1, wifi, etc.
        "description": "string",
        "amount": number,
        "waived": boolean,
        "waivedReason": "string"     // Why fee was waived (status, fare type)
      }
    ],
    "totalTaxes": number,
    "totalAncillaries": number,
    "totalPrice": number,
    "currency": "string",
    "paymentMethod": "string"        // Reference to payment method id
  },
  "baggage": {
    "checkedBags": number,
    "carryOnBags": number
  }
}
```

### Flight Segment Detail

```json
{
  "segmentId": number,               // Segment sequence number
  "flightNumber": "string",          // Flight number
  "origin": "string",                // 3-letter airport code
  "destination": "string",           // 3-letter airport code
  "departureDateTime": "ISO8601",    // Departure date/time with timezone
  "arrivalDateTime": "ISO8601",      // Arrival date/time with timezone
  "aircraft": "string",              // Aircraft type
  "seatNumber": "string",            // Seat assignment (12C, etc.)
  "seatType": "aisle|window|middle", // Seat position
  "cabinClass": "first|business|premium|economy"
}
```

### Hotel Stay Detail

```json
{
  "confirmationCode": "string",      // Hotel confirmation number
  "hotelChain": "string",            // Brand name
  "propertyName": "string",          // Specific hotel name
  "propertyCode": "string",          // Hotel code
  "address": {},                     // Full address object
  "checkInDate": "YYYY-MM-DD",
  "checkOutDate": "YYYY-MM-DD",
  "nights": number,
  "roomType": "string",              // Room description
  "roomTypeCode": "string",          // Hotel's room code
  "bedType": "string",               // King, Queen, Double
  "smokingPreference": "string",
  "loyaltyNumber": "string",         // Loyalty account used
  "rateType": "string",              // corporate, leisure, conference
  "pricing": {
    "nightlyRates": [
      {
        "date": "YYYY-MM-DD",
        "baseRate": number,
        "taxRate": number,           // Tax percentage (0.14 = 14%)
        "taxes": number
      }
    ],
    "ancillaries": [
      {
        "type": "string",            // resort_fee, parking, room_upgrade, etc.
        "description": "string",
        "amountPerNight": number,    // For recurring fees
        "nights": number,
        "totalAmount": number,
        "waived": boolean,
        "waivedReason": "string"
      }
    ],
    "subtotal": number,              // Sum of all nightly base rates
    "totalTaxes": number,
    "totalAncillaries": number,
    "totalPrice": number,
    "currency": "string",
    "paymentMethod": "string"
  },
  "specialRequests": ["string"]
}
```

### Car Rental Detail

```json
{
  "confirmationCode": "string",
  "rentalCompany": "string",
  "pickupLocation": {
    "code": "string",
    "name": "string",
    "address": "string"
  },
  "dropoffLocation": {},             // Same structure as pickup
  "pickupDateTime": "ISO8601",
  "dropoffDateTime": "ISO8601",
  "rentalDays": number,
  "vehicleClass": "string",          // Compact, Midsize, SUV, etc.
  "vehicleType": "string",           // Specific car or "or similar"
  "loyaltyNumber": "string",
  "pricing": {
    "dailyRate": number,
    "rentalDays": number,
    "baseRentalCost": number,
    "ancillaries": [
      {
        "type": "string",            // cdw, ldw, gps, fuel, tolls, etc.
        "description": "string",
        "dailyRate": number,         // For recurring charges
        "days": number,
        "totalAmount": number,
        "waived": boolean,
        "waivedReason": "string"
      }
    ],
    "taxes": [
      {
        "code": "string",
        "description": "string",
        "amount": number
      }
    ],
    "totalAncillaries": number,
    "totalTaxes": number,
    "totalPrice": number,
    "currency": "string",
    "paymentMethod": "string"
  },
  "mileage": {
    "included": "string",            // "unlimited" or number
    "actualMiles": number
  }
}
```

### Ground Transportation Detail

```json
{
  "type": "rideshare|taxi|parking|train",
  "provider": "string",              // Uber, Lyft, etc.
  "tripId": "string",                // Provider's trip ID
  "date": "YYYY-MM-DD",
  "time": "HH:MM:SS-TZ",
  "fromLocation": "string",
  "toLocation": "string",
  "distance": number,                // Miles
  "duration": number,                // Minutes
  "vehicleType": "string",           // UberX, Lyft, etc.
  "pricing": {
    "baseFare": number,
    "surgeMultiplier": number,       // 1.0 = no surge, 1.5 = 1.5x surge
    "tip": number,
    "fees": number,
    "totalPrice": number,
    "currency": "string",
    "paymentMethod": "string"
  }
}
```

### Calendar Event Detail

```json
{
  "eventId": "string",
  "title": "string",                 // Meeting subject
  "startDateTime": "ISO8601",
  "endDateTime": "ISO8601",
  "location": "string",              // Meeting location
  "attendees": ["email@domain.com"],
  "organizer": "email@domain.com"
}
```

## Pattern Recognition Examples

### Query: "What are Marcus's airline preferences?"

**Algorithm:**
```javascript
// Count segments by carrier
const airlineFrequency = trips
  .flatMap(trip => trip.air)
  .flatMap(air => [...air.segments, ...air.returnSegments])
  .reduce((acc, seg) => {
    const airline = seg.flightNumber.substring(0, 2);
    acc[airline] = (acc[airline] || 0) + 1;
    return acc;
  }, {});

// Result: DL: 68%, UA: 32%
```

**Veyant Insight:**
"Marcus primarily flies Delta (68%) and United (32%), both of which he holds top-tier status. For SLC originating flights, prioritize Delta for award availability and complimentary upgrades."

### Query: "Does Marcus pay for seat selection?"

**Algorithm:**
```javascript
const seatSelectionCosts = trips
  .flatMap(trip => trip.air)
  .flatMap(air => air.pricing.ancillaries)
  .filter(anc => anc.type === 'seat_selection');

const totalPaid = seatSelectionCosts
  .filter(anc => !anc.waived)
  .reduce((sum, anc) => sum + anc.amount, 0);

// Result: $0 total - all waived due to elite status
```

**Veyant Insight:**
"Marcus has never paid for seat selection across 100+ segments due to Diamond/1K status. When booking on airlines without status, recommend free basic seats or calculate ROI of status match."

### Query: "What's Marcus's typical hotel spend pattern?"

**Algorithm:**
```javascript
const hotelMetrics = trips
  .flatMap(trip => trip.hotel)
  .reduce((acc, hotel) => {
    acc.totalNights += hotel.nights;
    acc.totalSpend += hotel.pricing.totalPrice;
    acc.resortFeesWaived += hotel.pricing.ancillaries
      .filter(a => a.type === 'resort_fee' && a.waived)
      .reduce((sum, a) => sum + a.totalAmount, 0);
    return acc;
  }, { totalNights: 0, totalSpend: 0, resortFeesWaived: 0 });

const avgNightlyRate = hotelMetrics.totalSpend / hotelMetrics.totalNights;

// Result: Avg $245/night, $1,240 in resort fees waived via status
```

**Veyant Insight:**
"Marcus averages $245/night with Diamond status saving $1,240 in resort fees annually. His Hilton preference (72% of stays) maximizes value. Consider Hilton properties even if slightly higher base rate."

### Query: "When should we alert Marcus about status retention?"

**Algorithm:**
```javascript
const currentYear = new Date().getFullYear();
const statusAccounts = loyaltyAccounts.filter(acct => 
  acct.statusExpiresDate.includes(currentYear + 1)
);

statusAccounts.forEach(acct => {
  const segments = getSegmentsByProgram(acct.program);
  const projectedAnnual = (segments.length / monthsElapsed) * 12;
  
  if (projectedAnnual < acct.qualificationThreshold * 0.9) {
    alert(`Status at risk: ${acct.program}`);
  }
});
```

**Veyant Insight:**
"Mid-year check: Marcus is on track for Diamond re-qualification (67 segments through June, needs 100 for year) but lagging on Marriott Platinum (18 nights vs 50 needed). Suggest Marriott properties for remaining Q3/Q4 trips."

## CosmosDB Strategy

### Partition Key Design

**Recommended:** Use `id` (traveler ID) as partition key

**Rationale:**
- Queries typically filtered by specific traveler
- Each traveler document is self-contained
- Enables efficient retrieval of complete travel history
- Supports horizontal scaling as user base grows

**Alternative:** Use `personaType` if cross-persona analytics needed

### Indexing Strategy

```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    {
      "path": "/trips/*/tripType/?",
      "indexes": [{ "kind": "Range", "dataType": "String" }]
    },
    {
      "path": "/trips/*/startDate/?",
      "indexes": [{ "kind": "Range", "dataType": "String" }]
    },
    {
      "path": "/trips/*/air/*/airline/?",
      "indexes": [{ "kind": "Range", "dataType": "String" }]
    },
    {
      "path": "/loyaltyAccounts/*/program/?",
      "indexes": [{ "kind": "Range", "dataType": "String" }]
    }
  ],
  "excludedPaths": [
    {
      "path": "/trips/*/calendarEvents/*"
    }
  ]
}
```

### Sample Queries

**Find all business trips in 2024:**
```sql
SELECT * FROM c 
WHERE c.id = 'traveler-rw-001' 
  AND ARRAY_LENGTH(
    ARRAY(
      SELECT VALUE t 
      FROM t IN c.trips 
      WHERE t.tripType = 'business' 
        AND t.startDate >= '2024-01-01' 
        AND t.startDate < '2025-01-01'
    )
  ) > 0
```

**Calculate total ancillary spend:**
```sql
SELECT 
  c.id,
  c.profile.firstName,
  c.profile.lastName,
  SUM(air.pricing.totalAncillaries) as totalAirAncillaries
FROM c
JOIN trip IN c.trips
JOIN air IN trip.air
WHERE c.id = 'traveler-rw-001'
GROUP BY c.id, c.profile.firstName, c.profile.lastName
```

**Find trips with elite status upgrades:**
```sql
SELECT 
  trip.tripName,
  trip.startDate,
  air.airline,
  anc.description as upgrade
FROM c
JOIN trip IN c.trips
JOIN air IN trip.air
JOIN anc IN air.pricing.ancillaries
WHERE c.id = 'traveler-rw-001'
  AND anc.waived = true
  AND anc.type IN ('room_upgrade', 'cabin_upgrade')
```

## ML/AI Training Use Cases

### 1. Seat Preference Prediction
**Training Data:** Historical seat selections across all segments
**Model:** Classification (aisle, window, middle)
**Features:** Flight duration, time of day, domestic vs international, cabin class
**Veyant Application:** Auto-select preferred seats during booking

### 2. Hotel Brand Affinity
**Training Data:** Hotel bookings with loyalty status, pricing, location
**Model:** Ranking algorithm
**Features:** Loyalty tier, nightly rate, distance to meeting, amenities
**Veyant Application:** Recommend properties matching traveler preferences

### 3. Ancillary Willingness-to-Pay
**Training Data:** All ancillary purchases and declines
**Model:** Regression
**Features:** Trip purpose, trip duration, advance booking, status level
**Veyant Application:** Surface ancillaries traveler is likely to purchase

### 4. Trip Extension Detection (Bleisure)
**Training Data:** Business trips with weekend stays, calendar gaps
**Model:** Binary classification
**Features:** Meeting schedule, destination type, day of week, traveler age
**Veyant Application:** Suggest extending trips when bleisure pattern detected

### 5. Loyalty Status Optimization
**Training Data:** Multi-program activity, qualification progress
**Model:** Recommendation system
**Features:** Current status, booking patterns, qualification thresholds, ROI
**Veyant Application:** Alert travelers when status at risk, suggest consolidation

### 6. Budget Anomaly Detection
**Training Data:** Historical trip costs by route, purpose, lead time
**Model:** Anomaly detection
**Features:** Route, dates, booking class, total cost
**Veyant Application:** Flag unusually expensive bookings for review

## Data Quality Notes

### Realistic Constraints Applied

1. **Elite Status Benefits:** Properly applied based on airline/hotel programs
2. **Seasonal Pricing:** Higher rates during peak seasons (SXSW, summer)
3. **Geographic Logic:** Realistic distances, flight times, routing
4. **Booking Windows:** Business trips: 7-30 days out; Leisure: 30-90 days
5. **Surge Pricing:** Applied to ground transport based on time/demand
6. **Tax Rates:** Accurate by jurisdiction (NYC 14.75%, Austin 17%, etc.)

### Known Simplifications

1. **Dynamic Pricing:** Static fare classes rather than true revenue management
2. **Award Travel:** Not included (future enhancement)
3. **Cancellations/Changes:** Not modeled (future enhancement)
4. **Irregular Operations:** No delays, cancellations, or IRROPS
5. **Companion Travelers:** Solo travel only (except Leisure persona)

## Extending the Dataset

### Adding New Trips

```javascript
const newTrip = {
  tripId: `trip-${nextId}`,
  tripName: "Destination - Purpose",
  tripType: "business|leisure",
  startDate: "YYYY-MM-DD",
  endDate: "YYYY-MM-DD",
  // ... complete structure from data dictionary
};

traveler.trips.push(newTrip);
```

### Adding New Personas

Recommended attributes to vary:
- Annual segment count (drive dataset volume)
- Airline alliance preference (Star Alliance, SkyTeam, Oneworld)
- Home airport (affects routing patterns)
- Loyalty status levels (shows impact of benefits)
- Trip purpose mix (business vs leisure ratios)
- International vs domestic split
- Booking lead time patterns
- Budget sensitivity (premium vs economy)

## Version History

- **v1.0** (January 2025) - Initial dataset creation
  - 5 personas
  - 2 years historical data
  - Complete pricing breakdowns
  - Calendar integration

## Support & Questions

For technical questions about this dataset, contact:
- Seth Burton (seth@veyant.ai)
- Development Team

For CosmosDB implementation guidance, see:
- Azure Cosmos DB documentation
- Veyant architecture specifications

---

**Generated for:** Veyant Prototype Development  
**Dataset Purpose:** Demonstrate AI orchestration and pattern recognition  
**License:** Internal use only - Veyant confidential

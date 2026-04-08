-- ============================================================================
-- Veyant: Trip History Delta Table
-- Implements US 7.1.1 — Trip History Schema
-- Reference: docs/Veyant_Preference_Engine_Azure_Architecture.md, Section 6.2
-- ============================================================================

CREATE CATALOG IF NOT EXISTS veyant_dev;
CREATE SCHEMA IF NOT EXISTS veyant_dev.travel_data;

-- Trip history table — canonical record of all trips for all travelers
-- Partitioned by tenant_id (multi-tenant data model from day 1) and year
-- Schema preserves the nested structure from the synthetic JSON data set

CREATE TABLE IF NOT EXISTS veyant_dev.travel_data.trip_history (
  tenant_id STRING NOT NULL COMMENT 'Tenant identifier for multi-tenant isolation',
  traveler_id STRING NOT NULL COMMENT 'Unique traveler identifier (e.g. traveler-sc-001)',
  trip_id STRING NOT NULL COMMENT 'Unique trip identifier within the traveler',
  trip_name STRING COMMENT 'Human-readable trip name',
  trip_type STRING COMMENT 'business | leisure',
  start_date DATE NOT NULL,
  end_date DATE,
  origin STRING COMMENT 'Origin airport IATA code',
  destination STRING COMMENT 'Destination airport IATA code',
  booked_date DATE COMMENT 'When the trip was booked (for lead time analysis)',
  booked_by STRING COMMENT 'self | assistant',
  total_cost DECIMAL(10,2),
  currency STRING,

  -- Nested arrays preserve the rich structure from the source JSON
  air ARRAY<STRUCT<
    confirmationCode: STRING,
    recordLocator: STRING,
    airline: STRING,
    flightNumbers: ARRAY<STRING>,
    bookingClass: STRING,
    fareClass: STRING,
    segments: ARRAY<STRUCT<
      segmentId: INT,
      flightNumber: STRING,
      origin: STRING,
      destination: STRING,
      departureDateTime: STRING,
      arrivalDateTime: STRING,
      aircraft: STRING,
      seatNumber: STRING,
      seatType: STRING,
      cabinClass: STRING
    >>,
    returnSegments: ARRAY<STRUCT<
      segmentId: INT,
      flightNumber: STRING,
      origin: STRING,
      destination: STRING,
      departureDateTime: STRING,
      arrivalDateTime: STRING,
      aircraft: STRING,
      seatNumber: STRING,
      seatType: STRING,
      cabinClass: STRING
    >>,
    pricing: STRUCT<
      baseFare: DECIMAL(10,2),
      totalTaxes: DECIMAL(10,2),
      totalAncillaries: DECIMAL(10,2),
      totalPrice: DECIMAL(10,2),
      currency: STRING,
      paymentMethod: STRING,
      ancillaries: ARRAY<STRUCT<
        type: STRING,
        description: STRING,
        amount: DECIMAL(10,2),
        waived: BOOLEAN,
        waivedReason: STRING
      >>
    >
  >>,

  hotel ARRAY<STRUCT<
    confirmationCode: STRING,
    hotelChain: STRING,
    propertyName: STRING,
    propertyCode: STRING,
    checkInDate: DATE,
    checkOutDate: DATE,
    nights: INT,
    roomType: STRING,
    bedType: STRING,
    loyaltyNumber: STRING,
    rateType: STRING,
    pricing: STRUCT<
      subtotal: DECIMAL(10,2),
      totalTaxes: DECIMAL(10,2),
      totalAncillaries: DECIMAL(10,2),
      totalPrice: DECIMAL(10,2),
      currency: STRING,
      ancillaries: ARRAY<STRUCT<
        type: STRING,
        description: STRING,
        totalAmount: DECIMAL(10,2),
        waived: BOOLEAN,
        waivedReason: STRING
      >>
    >
  >>,

  car ARRAY<STRUCT<
    confirmationCode: STRING,
    rentalCompany: STRING,
    pickupDateTime: STRING,
    dropoffDateTime: STRING,
    rentalDays: INT,
    vehicleClass: STRING,
    vehicleType: STRING,
    loyaltyNumber: STRING,
    pricing: STRUCT<
      dailyRate: DECIMAL(10,2),
      baseRentalCost: DECIMAL(10,2),
      totalTaxes: DECIMAL(10,2),
      totalAncillaries: DECIMAL(10,2),
      totalPrice: DECIMAL(10,2),
      currency: STRING
    >
  >>,

  ground ARRAY<STRUCT<
    type: STRING,
    provider: STRING,
    fromLocation: STRING,
    toLocation: STRING,
    pricing: STRUCT<
      baseFare: DECIMAL(10,2),
      tip: DECIMAL(10,2),
      totalPrice: DECIMAL(10,2),
      currency: STRING
    >
  >>,

  calendar_events ARRAY<STRUCT<
    eventId: STRING,
    title: STRING,
    startDateTime: STRING,
    endDateTime: STRING,
    location: STRING,
    attendees: ARRAY<STRING>
  >>,

  ingested_at TIMESTAMP NOT NULL,
  source_system STRING COMMENT 'Source of this record (e.g. mock_synthetic_v1, gds_amadeus, etc.)'
)
USING DELTA
PARTITIONED BY (tenant_id)
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
)
COMMENT 'Canonical trip history records. Source of truth. Lakebase preference_profiles is derived from this via the preference extraction pipeline.';

-- Travelers dimensional table
CREATE TABLE IF NOT EXISTS veyant_dev.travel_data.travelers (
  tenant_id STRING NOT NULL,
  traveler_id STRING NOT NULL,
  first_name STRING,
  last_name STRING,
  email STRING,
  home_airport STRING,
  company STRING,
  title STRING,
  loyalty_accounts ARRAY<STRUCT<
    program: STRING,
    account_number: STRING,
    status: STRING,
    points: BIGINT,
    status_expires_date: DATE
  >>,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)
USING DELTA
PARTITIONED BY (tenant_id)
COMMENT 'Traveler profile dimensional table.';

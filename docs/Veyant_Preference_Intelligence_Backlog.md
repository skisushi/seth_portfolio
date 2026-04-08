# Veyant: Trip Intelligence — Preference Derivation & Persistence
## Feature Backlog v1.0 | April 2026

---

## Overview

This backlog covers the end-to-end feature area for deriving traveler preferences from trip history using a local LLM (Ollama), persisting those preferences, and surfacing them in trip scoring and suggestions. It integrates directly into the existing demo with Sarah Chen as the primary test case, while being designed against a real schema rather than throwaway mock data.

**The bigger picture:** Preferences derived from trip history are one of three inputs to a trip suggestion engine. The other two are corporate policy (already partially live via the MCP compliance tools) and supplier understanding (via the supplier catalog MCP). This backlog covers the "My Travel Cube" slice of that triangle.

**Design constraint:** Local models only — no calls to Claude API or external LLM providers during preference derivation. Ollama runs locally and is the inference engine.

---

## Architecture Snapshot

```
Trip History Records
        │
        ▼
┌───────────────────────────┐
│  Preference Extraction    │  ← Ollama (llama3 / mistral)
│  Service                  │     Prompt template + JSON parsing
└───────────────────────────┘
        │
        ▼
┌───────────────────────────┐
│  Preference Persistence   │  ← SQLite (demo) / designed for Postgres
│  Layer                    │     Versioned, confidence-scored
└───────────────────────────┘
        │
        ▼
┌───────────────────────────┐
│  Preference Scoring API   │  ← Feeds existing get_preference_score MCP
│  (MCP integration point)  │     Returns 0–100 score per option
└───────────────────────────┘
        │
        ▼
┌───────────────────────────┐
│  Trip Suggestion Engine   │  ← Combines preferences + policy + supplier
└───────────────────────────┘
```

**Ollama models in scope:**
- `llama3.2:3b` for fast local inference during demo (low RAM, snappy)
- `mistral:7b` as fallback for richer extraction on higher-spec machines
- Prompt outputs constrained to structured JSON — no free-form LLM responses surfaced to the UI

---

## Epic: E7 — Trip Intelligence: Preference Derivation & Persistence

**Epic Description:** As Veyant, we need to learn what a traveler actually prefers by analyzing their trip history using a local LLM, persist those derived preferences in a structured store, and use them to score options and generate personalized trip suggestions — all without sending traveler data to an external AI provider.

**Success Criteria for the Epic:**
- Sarah Chen's trip history produces a readable, accurate preference profile
- The preference profile is persisted and survives app restarts
- Option scoring uses derived preferences, not static mock data
- A suggested trip is returned that reflects preferences + policy + supplier fit
- All inference runs via Ollama with no external API calls

---

## Feature F7.1: Trip History Schema & Seed Data

**Why first:** Everything downstream depends on a clean, realistic trip history data model. Without this, the LLM has nothing to analyze and the schema work done here informs the persistence design.

**Feature Description:** Design and implement the trip history schema, then populate it with a realistic Sarah Chen travel history covering 18 months of business travel patterns.

---

### US 7.1.1 — Trip History Data Model
**As a** developer building the preference engine  
**I want** a well-defined trip history schema  
**So that** I can reason about what fields are available for preference derivation

**Acceptance Criteria:**
- Schema defined as TypeScript types (or JSON Schema)
- Covers air, hotel, car rental segments within a single trip record
- Includes loyalty program data, cabin/tier booked, seat type, booking lead time
- Distinguishes between explicit preferences (stated) and behavioral data (what was actually booked)
- Schema is documented with field definitions

**Story Points:** 3

**Schema draft (key fields):**
```typescript
interface TripRecord {
  tripId: string;
  travelerId: string;
  tripPurpose: 'business' | 'bleisure' | 'personal';
  departureDate: string;        // ISO 8601
  returnDate: string;
  bookingDate: string;          // for lead time calculation
  segments: {
    air?: AirSegment[];
    hotel?: HotelSegment[];
    car?: CarSegment[];
  };
  totalCost: number;
  currency: string;
  bookingChannel: 'online' | 'agent' | 'direct';
  loyaltyAccountsUsed: string[];
  tripNotes?: string;           // for LLM enrichment
}

interface AirSegment {
  carrier: string;              // IATA code e.g. "DL"
  carrierName: string;
  origin: string;               // airport IATA
  destination: string;
  fareClass: string;            // e.g. "Y", "J", "W"
  cabinBooked: 'economy' | 'premium-economy' | 'business' | 'first';
  cabinFlown: string;           // may differ due to upgrade
  upgradedViaLoyalty: boolean;
  seatNumber?: string;
  seatType: 'window' | 'aisle' | 'middle' | 'bulkhead' | 'exit-row';
  loyaltyMilesEarned: number;
  loyaltyProgram: string;
  flightDuration: number;       // minutes
}

interface HotelSegment {
  chain: string;                // e.g. "Marriott"
  brand: string;                // e.g. "JW Marriott"
  tier: 'economy' | 'midscale' | 'upscale' | 'upper-upscale' | 'luxury';
  city: string;
  locationContext: 'downtown' | 'airport' | 'suburban';
  checkIn: string;
  checkOut: string;
  roomType: string;
  ratePerNight: number;
  loyaltyPoints: number;
  loyaltyProgram: string;
  corporateRate: boolean;
}
```

**Tags:** schema, foundation, trip-history

---

### US 7.1.2 — Sarah Chen Seed Data (18 Months)
**As a** demo runner  
**I want** a realistic 18-month trip history for Sarah Chen  
**So that** the LLM has enough data to surface meaningful, consistent preferences

**Acceptance Criteria:**
- Minimum 12 trip records covering business travel across 4–6 cities
- Mix of air + hotel segments; car rental on some trips
- Consistent behavioral patterns that should yield detectable preferences (e.g., consistently books Delta, consistently chooses aisle seat, consistently stays at Marriott properties)
- A few edge cases: one last-minute booking, one internationally routed trip, one trip where corporate rate was used vs. loyalty rate
- Stored as `data/tripHistory.json` (importable JSON, not mock JS module)
- Validates against the schema from US 7.1.1

**Story Points:** 3

**Sample pattern to encode in seed data:**
- Delta preferred (85% of air segments)
- Aisle seat (90% of bookings)
- Business cabin when flight > 3hrs, Premium Economy on shorter hops
- Marriott family hotels (80% of hotel nights)
- Downtown location preferred over airport hotels
- Books 2–3 weeks out typically
- SkyTeam Platinum — consistently uses DeltaSkyMiles

**Tags:** seed-data, demo, trip-history

---

### US 7.1.3 — Trip History API Endpoint
**As a** preference extraction service  
**I want** a simple endpoint to retrieve trip history for a given traveler  
**So that** the extraction engine can query history without importing raw JSON

**Acceptance Criteria:**
- `GET /api/travelers/:travelerId/trips` returns paginated trip records
- Supports `?limit=N&before=date` for windowed queries
- Returns records sorted by departure date descending
- Returns 404 for unknown traveler IDs
- Works with seed data from US 7.1.2

**Story Points:** 2

**Tags:** api, trip-history, foundation

---

## Feature F7.2: Ollama Integration Service

**Why second:** Before building any extraction logic, the plumbing to talk to Ollama needs to work reliably. This is a standalone service that can be tested independently.

**Feature Description:** Build a local Ollama client service that handles model management, prompt construction, and structured JSON response parsing. This is the inference backbone for the entire preference engine.

---

### US 7.2.1 — Ollama Client Module
**As a** developer  
**I want** a reusable Ollama client module  
**So that** any service in the app can call the local LLM without duplicating connection logic

**Acceptance Criteria:**
- Module connects to `http://localhost:11434` (Ollama default)
- Handles connection errors gracefully (returns clear error if Ollama isn't running)
- Exposes `generate(prompt: string, model: string): Promise<string>` method
- Configurable model name via env variable `OLLAMA_MODEL` (default: `llama3.2:3b`)
- Includes a health check: `isOllamaRunning(): Promise<boolean>`
- Response timeout configurable (default 30s for 3b model)

**Story Points:** 3

**Technical note:** Ollama exposes a REST API at `/api/generate` — no SDK needed, plain fetch or axios works.

**Tags:** ollama, infrastructure, local-llm

---

### US 7.2.2 — Structured JSON Extraction from LLM Output
**As a** preference extraction engine  
**I want** reliable structured JSON from the LLM  
**So that** preference data can be parsed and stored without brittle string parsing

**Acceptance Criteria:**
- Prompt template instructs the model to respond ONLY with valid JSON, no preamble
- Response parser attempts JSON.parse on raw output
- If parse fails, applies regex extraction to find JSON block within the response
- If extraction fails, returns a typed error with the raw LLM output for debugging
- Unit tested with sample Ollama outputs including common failure modes (model adds "Sure! Here is..." prefix)

**Story Points:** 3

**Prompt wrapper pattern:**
```
System: You are a data extraction assistant. You respond ONLY with valid JSON.
Never add explanatory text before or after the JSON.

User: [task-specific prompt]

Respond with this exact JSON structure: [schema]
```

**Tags:** ollama, json-extraction, prompt-engineering

---

### US 7.2.3 — Ollama Setup & Dependency Documentation
**As a** developer setting up the project  
**I want** clear setup instructions for Ollama  
**So that** the demo can be run by someone else without guessing the dependencies

**Acceptance Criteria:**
- README section documents: install Ollama, pull the required model, verify with health check
- Setup script `scripts/setup-ollama.sh` that automates model pull and verification
- If Ollama is not running when the preference engine is called, a clear UI/console message explains this rather than a cryptic error

**Story Points:** 1

**Tags:** docs, setup, ollama

---

## Feature F7.3: Preference Extraction Engine

**Why third:** This is the core algorithmic feature — the Ollama client and trip history schema are both ready at this point, so the extraction engine has clean inputs.

**Feature Description:** A service that takes a traveler's trip history, constructs an analysis prompt, calls the local LLM, and returns a structured preference profile with confidence scores.

---

### US 7.3.1 — Preference Extraction Prompt Design
**As a** product builder  
**I want** a well-engineered prompt that extracts meaningful travel preferences from trip history  
**So that** the derived preferences reflect actual behavior, not LLM hallucinations

**Acceptance Criteria:**
- Prompt injects a summary of trip history records (not raw JSON — a human-readable summary is more token-efficient and produces better outputs)
- Asks the LLM to identify patterns across: airline preference, cabin preference, seat type, hotel chain, hotel tier, booking lead time, loyalty program priority
- Returns confidence levels (low / medium / high) per preference category
- Distinguishes between "always does this" vs. "tends to do this"
- Tested against Sarah Chen's seed data — output should match expected behavioral patterns

**Story Points:** 5

**Sample prompt structure:**
```
Here is a summary of [traveler name]'s travel history over the past 18 months:

- Trip 1 (Jan 2025): Boston → London, Delta DL401, Business class, Aisle seat, 
  JW Marriott London, 4 nights, downtown
- Trip 2 (Feb 2025): Boston → Chicago, Delta DL312, Economy class, Aisle seat,
  Marriott Marquis, 2 nights, downtown
[...]

Based on this history, identify this traveler's clear travel preferences. 
For each preference, assign a confidence level (high/medium/low) based on 
how consistently the behavior appears.

Respond with this JSON structure:
{
  "airPreferences": {
    "preferredCarriers": [{"carrier": "...", "confidence": "high|medium|low"}],
    "cabinByDuration": {"short": "...", "long": "..."},
    "seatType": {"preference": "...", "confidence": "..."}
  },
  ...
}
```

**Tags:** prompt-engineering, extraction, core-feature

---

### US 7.3.2 — Preference Profile Schema
**As a** preference persistence layer  
**I want** a well-defined schema for the derived preference object  
**So that** stored preferences are consistent and queryable

**Acceptance Criteria:**
- TypeScript interface defined for `DerivedPreferenceProfile`
- Covers air, hotel, car, loyalty, booking behavior categories
- Includes metadata: `derivedAt`, `tripHistoryWindowDays`, `recordCount`, `modelUsed`
- Confidence levels are typed enums, not free strings
- Schema is versioned (`schemaVersion`) to handle future changes without breaking stored data

**Story Points:** 2

**Tags:** schema, preferences, foundation

---

### US 7.3.3 — Preference Extraction Service (Core)
**As a** traveler  
**I want** Veyant to understand my preferences from my travel history  
**So that** trip suggestions reflect how I actually travel, not generic defaults

**Acceptance Criteria:**
- `PreferenceExtractionService.derive(travelerId: string): Promise<DerivedPreferenceProfile>` 
- Fetches trip history from the API (F7.1.3)
- Converts records to human-readable summary for the prompt
- Calls Ollama via F7.2.1 client
- Parses and validates response against schema from F7.3.2
- Returns the structured preference profile
- Handles edge cases: fewer than 3 trips returns a low-confidence profile with a warning

**Story Points:** 5

**Tags:** extraction, core-feature, ollama

---

### US 7.3.4 — Preference Extraction API Endpoint
**As a** frontend or MCP tool  
**I want** an API endpoint to trigger preference derivation for a traveler  
**So that** preferences can be refreshed on demand without restarting the app

**Acceptance Criteria:**
- `POST /api/travelers/:travelerId/preferences/derive` triggers extraction
- Returns the derived profile with a 200 on success
- Returns a 503 with a helpful message if Ollama is not running
- Execution time logged (demo value: showing "AI is working locally")
- `GET /api/travelers/:travelerId/preferences` returns the last persisted profile

**Story Points:** 3

**Tags:** api, extraction, preferences

---

## Feature F7.4: Preference Persistence Layer

**Feature Description:** Store derived preference profiles so they survive app restarts, can be versioned, and can be retrieved quickly during scoring without re-running inference.

---

### US 7.4.1 — Preference Store (SQLite)
**As a** developer  
**I want** a lightweight local database for preference storage  
**So that** the demo doesn't need an external database service but the schema could migrate to Postgres

**Acceptance Criteria:**
- SQLite via `better-sqlite3` or Drizzle ORM (schema-first)
- Two tables: `travelers` (id, name, metadata) and `preference_profiles` (travelerId, profileJson, derivedAt, modelUsed, recordCount, schemaVersion)
- Multiple profiles per traveler stored (history of derivations)
- "Active" profile flagged per traveler — only one active at a time
- Migration script creates tables if they don't exist on startup

**Story Points:** 3

**Tags:** persistence, sqlite, foundation

---

### US 7.4.2 — Save & Retrieve Preference Profile
**As a** preference scoring service  
**I want** to save and retrieve preference profiles  
**So that** scoring doesn't require re-running the LLM on every request

**Acceptance Criteria:**
- `PreferenceStore.save(profile: DerivedPreferenceProfile)` persists to SQLite
- `PreferenceStore.getActive(travelerId)` returns the current active profile
- `PreferenceStore.getHistory(travelerId)` returns all profiles for a traveler (newest first)
- If no active profile exists, returns null (caller decides to derive on demand or use defaults)
- Stored profiles are human-readable JSON in the profileJson column (not binary-encoded)

**Story Points:** 2

**Tags:** persistence, store, preferences

---

### US 7.4.3 — Preference Freshness & Re-Derivation Logic
**As a** system  
**I want** to know when a preference profile is stale  
**So that** I can prompt re-derivation when the traveler's behavior may have changed

**Acceptance Criteria:**
- Profile has a `staleness` flag based on configurable threshold (default: 30 days OR 3 new trips since last derivation)
- `PreferenceStore.isStale(travelerId): boolean` checks both conditions
- Stale profiles still used for scoring but a `stale: true` flag is returned with the profile
- Re-derivation can be triggered manually (API call) or automatically when stale is detected on a scoring request

**Story Points:** 3

**Tags:** persistence, freshness, preferences

---

## Feature F7.5: Preference-Aware Option Scoring

**Feature Description:** Replace the static mock-based scoring in the existing `get_preference_score` MCP tool with scoring backed by the persisted derived preference profile.

---

### US 7.5.1 — Preference Scoring Logic
**As a** traveler  
**I want** flight and hotel options scored against my actual preferences  
**So that** the system recommends things that fit how I actually travel

**Acceptance Criteria:**
- Scoring function takes a `FlightOption` or `HotelOption` and a `DerivedPreferenceProfile`
- Returns a 0–100 score with a breakdown of contributing factors
- Carrier preference: +30 pts if preferred carrier, proportionally less for non-preferred
- Cabin match: +25 pts if cabin matches preferred cabin for that flight duration
- Seat type: +15 pts if seat type matches preferred seat type
- Hotel chain: +20 pts if chain is in preferred chains list
- Hotel tier: +10 pts if tier matches preferred tier

**Story Points:** 3

**Tags:** scoring, preferences, core-feature

---

### US 7.5.2 — MCP Tool Integration (get_preference_score)
**As a** BRAIN agent  
**I want** the `get_preference_score` MCP tool to use real derived preferences  
**So that** the demo shows genuine intelligence, not canned scores

**Acceptance Criteria:**
- Existing MCP `get_preference_score` tool updated to call `PreferenceStore.getActive(travelerId)`
- If active profile exists: runs the scoring logic from US 7.5.1
- If no profile exists: falls back to static mock behavior with a `source: 'mock'` flag in response
- Score breakdown returned in response (e.g., `{"score": 82, "breakdown": {"carrier": 30, "cabin": 25, "seat": 15, ...}}`)
- Sarah Chen demo scenario produces noticeably different scores for Delta vs. United options

**Story Points:** 3

**Tags:** mcp, scoring, integration

---

## Feature F7.6: Preference-Driven Trip Suggestions

**Feature Description:** Use the derived preference profile, policy compliance check, and supplier catalog together to generate ranked trip suggestions — the end-to-end value demonstration.

---

### US 7.6.1 — Trip Suggestion Engine (Core Logic)
**As a** traveler  
**I want** Veyant to suggest the best trip options for a given route  
**So that** I get a ranked shortlist that fits my preferences, my company's policy, and what's actually available

**Acceptance Criteria:**
- `SuggestionEngine.suggest(travelerId, route, dates)` returns ranked list of options
- For each option: calls `get_preference_score` + `check_policy_compliance`
- Composite score = preference score (60%) + policy score (40%)
- Returns top 3 options, each with preference score, policy status, and supplier details
- Options that fail policy are still returned but ranked lower and flagged

**Story Points:** 5

**Tags:** suggestions, core-feature, orchestration

---

### US 7.6.2 — Trip Suggestion API Endpoint
**As a** chat UI or Travel Cockpit  
**I want** an endpoint to request trip suggestions  
**So that** the conversational AI can present ranked options without embedding scoring logic in the frontend

**Acceptance Criteria:**
- `POST /api/suggestions` accepts `{ travelerId, origin, destination, departureDate, returnDate }`
- Calls the suggestion engine (US 7.6.1)
- Returns ranked options within 10 seconds for demo conditions
- Processing steps are streamed or polled via `GET /api/suggestions/:requestId/status` (consistent with existing processing display UX)

**Story Points:** 3

**Tags:** api, suggestions, chat-ui

---

### US 7.6.3 — Demo Integration: Sarah Chen Suggestion Scenario
**As a** demo runner  
**I want** the full suggestion flow to work end-to-end for Sarah Chen  
**So that** I can show a live, working preference-to-suggestion pipeline in a 5-minute demo

**Acceptance Criteria:**
- Sarah Chen's trip history → preference derivation → preference persistence → option scoring → suggestion ranking all work in sequence
- Demo script: user asks "find me the best flights to London next month" and Veyant returns scored, ranked options
- Delta Business class option scores higher than United Economy, consistent with derived preferences
- Policy-compliant options clearly distinguished from policy exceptions
- The fact that scoring is based on derived history (not static data) is surfaced in the UI/explanation

**Story Points:** 5

**Tags:** demo, e2e, sarah-chen

---

## Backlog Summary

| Feature | Stories | Total Points | Priority | Sprint |
|---|---|---|---|---|
| F7.1: Trip History Schema & Seed Data | 3 | 8 | P1 | Sprint 1 |
| F7.2: Ollama Integration Service | 3 | 7 | P1 | Sprint 1 |
| F7.3: Preference Extraction Engine | 4 | 15 | P1 | Sprint 2 |
| F7.4: Preference Persistence Layer | 3 | 8 | P1 | Sprint 2 |
| F7.5: Preference-Aware Option Scoring | 2 | 6 | P1 | Sprint 3 |
| F7.6: Preference-Driven Trip Suggestions | 3 | 13 | P2 | Sprint 3–4 |
| **Total** | **18** | **57 pts** | | |

**Velocity assumption:** ~15 pts/sprint at Jared's part-time pace (1–2 days/week)
**Estimated calendar time to demo-ready E2E (US 7.6.3):** 3–4 sprints / 6–8 weeks

---

## Critical Path

These must complete before anything else can proceed:

1. US 7.1.1 — Trip History Schema (blocks all downstream work)
2. US 7.2.1 — Ollama Client (blocks extraction engine)
3. US 7.1.2 — Sarah Chen Seed Data (blocks extraction testing)
4. US 7.3.3 — Extraction Service Core (blocks scoring and suggestions)

---

## Key Technical Decisions

**Why Ollama over rule-based extraction?**
Structured heuristics (e.g., "count Delta bookings vs. United") work for simple carrier preferences but break down on nuanced signals — like "prefers aisle on long-haul but doesn't care on short hops" or "books downtown hotels for conferences but airport hotels when connection is tight." The LLM can reason across those patterns from a narrative trip summary without needing explicit logic for every case.

**Why SQLite for persistence?**
Zero infrastructure for demo purposes. The schema can migrate to Postgres with no logic changes. The preference profiles are mostly read-heavy with infrequent writes (re-derivation), so SQLite is not a bottleneck.

**Why trip summary as prompt input vs. raw JSON?**
LLMs produce better structured outputs when given human-readable context rather than raw data payloads. A summary like "Boston → London, Delta Business, aisle seat" is more token-efficient and produces more reliable preference extraction than a 400-token JSON blob for the same record.

**Confidence scoring strategy:**
Confidence is derived by the LLM based on pattern strength in the history, but capped at "high" unless the behavior appears in >70% of relevant trips. This prevents the model from confidently stating a preference from a single data point.

---

## Parking Lot (Out of Scope for This Sprint)

- Multi-traveler preference aggregation (corporate travel patterns)
- Preference learning from explicit feedback ("I didn't like that hotel")
- Real-time preference updates mid-trip
- Preference sharing across travelers in the same corporate account
- Privacy controls for which preference categories can be derived
- Integration with supplier loyalty APIs to validate tier status

---

*Veyant.ai — Think deeply. Work smarter. Fail fast and pivot. Build good enough, not perfect.*

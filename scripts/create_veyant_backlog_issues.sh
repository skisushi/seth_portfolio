#!/usr/bin/env bash
#
# Veyant Trip Intelligence Backlog — GitHub Issues Generator
# ----------------------------------------------------------
# Creates labels, milestones, and issues for Epic E7 in skisushi/seth_portfolio
#
# Prerequisites:
#   - gh CLI installed and authenticated (run: gh auth login)
#   - Push access to skisushi/seth_portfolio
#
# Usage:
#   chmod +x create_veyant_backlog_issues.sh
#   ./create_veyant_backlog_issues.sh
#
# This script is idempotent for labels and milestones (uses || true on conflicts)
# but NOT for issues — running twice will create duplicate issues.
#
set -e

REPO="skisushi/seth_portfolio"
DESIGN_DOC_PATH="docs/Veyant_Preference_Engine_Azure_Architecture.md"
BACKLOG_DOC_PATH="docs/Veyant_Preference_Intelligence_Backlog.md"

echo "Creating labels in $REPO..."

# Epic and feature labels
gh label create "epic:E7-trip-intelligence" --color "5319E7" --description "Epic 7: Trip Intelligence & Preference Derivation" --repo $REPO 2>/dev/null || true

gh label create "feature:F7.0-azure-foundation" --color "0366D6" --description "Azure infrastructure foundation" --repo $REPO 2>/dev/null || true
gh label create "feature:F7.1-trip-history" --color "0366D6" --description "Trip history schema and seed data" --repo $REPO 2>/dev/null || true
gh label create "feature:F7.2-inference" --color "0366D6" --description "Mosaic AI inference service" --repo $REPO 2>/dev/null || true
gh label create "feature:F7.3-extraction" --color "0366D6" --description "Preference extraction engine" --repo $REPO 2>/dev/null || true
gh label create "feature:F7.4-persistence" --color "0366D6" --description "Preference persistence layer" --repo $REPO 2>/dev/null || true
gh label create "feature:F7.5-scoring" --color "0366D6" --description "Preference-aware option scoring" --repo $REPO 2>/dev/null || true
gh label create "feature:F7.6-suggestions" --color "0366D6" --description "Preference-driven trip suggestions" --repo $REPO 2>/dev/null || true

# Priority labels
gh label create "priority:P1" --color "B60205" --description "Critical path, do first" --repo $REPO 2>/dev/null || true
gh label create "priority:P2" --color "D93F0B" --description "Important, do after P1" --repo $REPO 2>/dev/null || true
gh label create "priority:P3" --color "FBCA04" --description "Nice to have" --repo $REPO 2>/dev/null || true

# Complexity labels (replaces story points for Claude Code workflow)
gh label create "complexity:simple" --color "C2E0C6" --description "Single file, clear scope, <1 hour" --repo $REPO 2>/dev/null || true
gh label create "complexity:moderate" --color "FEF2C0" --description "Multiple files, some design decisions, 1-3 hours" --repo $REPO 2>/dev/null || true
gh label create "complexity:complex" --color "F9D0C4" --description "Cross-cutting, requires planning, 3+ hours" --repo $REPO 2>/dev/null || true

# Status labels
gh label create "status:ready" --color "0E8A16" --description "Has enough context for Claude Code to start" --repo $REPO 2>/dev/null || true
gh label create "status:blocked" --color "B60205" --description "Waiting on a dependency" --repo $REPO 2>/dev/null || true
gh label create "status:needs-decision" --color "D4C5F9" --description "Open question requires Seth's input before starting" --repo $REPO 2>/dev/null || true

# Type label
gh label create "type:user-story" --color "1D76DB" --description "Implementable user story" --repo $REPO 2>/dev/null || true

echo "Creating milestones..."

create_milestone() {
  local title="$1"
  local description="$2"
  gh api repos/$REPO/milestones \
    -f title="$title" \
    -f description="$description" \
    -f state="open" 2>/dev/null || true
}

create_milestone "F7.0 - Azure Foundation" "Provision Azure resources and Databricks workspace. Critical path for everything else."
create_milestone "F7.1 - Trip History Schema & Seed Data" "Delta tables and synthetic trip history loaded into Unity Catalog."
create_milestone "F7.2 - Inference Service" "InferenceClient abstraction backed by Mosaic AI Model Serving."
create_milestone "F7.3 - Preference Extraction Engine" "End-to-end preference derivation from trip history using Llama 3 70B."
create_milestone "F7.4 - Preference Persistence Layer" "Delta + Lakebase storage with sync for derived preference profiles."
create_milestone "F7.5 - Preference-Aware Option Scoring" "Replace mock scoring in get_preference_score MCP tool with real derived prefs."
create_milestone "F7.6 - Preference-Driven Trip Suggestions" "End-to-end suggestion engine combining preferences, policy, and supplier data."

echo "Creating issues..."

# Helper function to create an issue
# Args: title, body, labels (comma-separated), milestone
create_issue() {
  local title="$1"
  local body="$2"
  local labels="$3"
  local milestone="$4"

  gh issue create \
    --repo $REPO \
    --title "$title" \
    --body "$body" \
    --label "$labels" \
    --milestone "$milestone"
}

# ============================================================================
# F7.0 — Azure Foundation
# ============================================================================

create_issue "US 7.0.1 — Provision Azure resource group, Databricks workspace, ADLS Gen2" "$(cat <<'EOF'
## User Story
**As** the Veyant team
**I want** the foundational Azure resources provisioned
**So that** the rest of the preference engine has somewhere to live

## Acceptance Criteria
- [ ] Resource group `rg-veyant-dev-eastus2` created
- [ ] Azure Databricks workspace (Premium SKU) deployed in East US 2
- [ ] ADLS Gen2 storage account with hierarchical namespace enabled
- [ ] Workspace access verified for the Veyant team
- [ ] Tags applied: `env=dev`, `project=veyant`, `owner=seth`

## Design Reference
See [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md), Section 5.2.

## Notes for Claude Code
This story is now covered by US 7.0.3 (Terraform IaC). The `infra/terraform/` module provisions everything in one `make apply`. Use manual Azure portal work only as a fallback if Terraform fails.
EOF
)" "epic:E7-trip-intelligence,feature:F7.0-azure-foundation,priority:P1,complexity:moderate,status:ready,type:user-story" "F7.0 - Azure Foundation"

create_issue "US 7.0.2 — Set up Unity Catalog, create catalogs and schemas" "$(cat <<'EOF'
## User Story
**As** a developer
**I want** Unity Catalog set up with the Veyant catalog and schemas
**So that** all subsequent Delta tables have a governed home

## Acceptance Criteria
- [ ] Metastore attached to the workspace (or created if first workspace in the region)
- [ ] Catalog `veyant_dev` created
- [ ] Schemas created: `travel_data`, `corporate`, `supplier`, `ml_models`
- [ ] Storage credentials and external locations configured against ADLS Gen2
- [ ] Veyant team has appropriate USE / CREATE / SELECT grants

## Design Reference
See [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md), Section 6.1.

## Depends on
- US 7.0.1
EOF
)" "epic:E7-trip-intelligence,feature:F7.0-azure-foundation,priority:P1,complexity:simple,status:blocked,type:user-story" "F7.0 - Azure Foundation"

create_issue "US 7.0.3 — Terraform IaC for the entire foundation stack" "$(cat <<'EOF'
## User Story
**As** the Veyant team
**I want** the foundation infrastructure defined as Terraform in the repo
**So that** we can tear down and recreate the environment cleanly from source control

## Status
This is **already implemented** in `infra/terraform/`. This issue tracks validation and any follow-on work (remote state, CI integration).

## Acceptance Criteria
- [x] `infra/terraform/main.tf` defines: resource group, ADLS Gen2, Key Vault, Log Analytics, App Insights, Databricks Access Connector, Databricks Workspace (Premium)
- [x] `infra/terraform/variables.tf` parameterizes project name, environment, location, owner, tags
- [x] `infra/terraform/outputs.tf` exposes workspace URL, storage account, key vault URI, access connector ID
- [x] `infra/terraform/Makefile` provides `init`, `plan`, `apply`, `destroy`, `output` targets
- [x] `infra/terraform/README.md` documents prerequisites, first-time setup, troubleshooting
- [ ] Validated end-to-end: `make apply` -> `make destroy` round-trip on a clean subscription
- [ ] (Optional) Remote state migrated to Azure Storage backend
- [ ] (Optional) `terraform fmt` + `terraform validate` wired into CI

## Design Reference
See `infra/terraform/README.md` and [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md).

## Depends on
- None (this supersedes manual provisioning in US 7.0.1)
EOF
)" "epic:E7-trip-intelligence,feature:F7.0-azure-foundation,priority:P1,complexity:complex,status:ready,type:user-story" "F7.0 - Azure Foundation"

create_issue "US 7.0.4 — Create Mosaic AI Model Serving endpoint with Llama 3 70B" "$(cat <<'EOF'
## User Story
**As** the inference layer
**I want** a Mosaic AI Model Serving endpoint hosting Llama 3 70B Instruct
**So that** the preference extraction engine has a model to call

## Acceptance Criteria
- [ ] Pay-per-token endpoint provisioned for `databricks-meta-llama-3-70b-instruct`
- [ ] Endpoint URL and access token stored in Key Vault
- [ ] Test call from a notebook returns a valid response
- [ ] Serving endpoint logs visible in Databricks UI

## Design Reference
See [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md), Section 5.2 and 7.3.

## Depends on
- US 7.0.1
EOF
)" "epic:E7-trip-intelligence,feature:F7.0-azure-foundation,priority:P1,complexity:simple,status:blocked,type:user-story" "F7.0 - Azure Foundation"

# ============================================================================
# F7.1 — Trip History Schema & Seed Data
# ============================================================================

create_issue "US 7.1.1 — Trip history Delta table schema (DDL)" "$(cat <<'EOF'
## User Story
**As** a developer building the preference engine
**I want** the trip history Delta table created in Unity Catalog with the right schema and partitioning
**So that** we can ingest the synthetic data set and query it efficiently

## Acceptance Criteria
- [ ] Table `veyant_dev.travel_data.trip_history` created
- [ ] Schema matches the existing JSON synthetic data structure (preserves nested air/hotel/car/ground arrays)
- [ ] Partitioned by `tenant_id` and `YEAR(start_date)`
- [ ] Change Data Feed enabled
- [ ] Auto-optimize write enabled
- [ ] DDL committed to repo at `databricks/sql/01_trip_history.sql`

## Design Reference
See [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md), Section 6.2 for the full DDL.

## Depends on
- US 7.0.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.1-trip-history,priority:P1,complexity:moderate,status:blocked,type:user-story" "F7.1 - Trip History Schema & Seed Data"

create_issue "US 7.1.2 — Sarah Chen seed data (load adapted JSON into Delta)" "$(cat <<'EOF'
## User Story
**As** a demo runner
**I want** realistic Sarah Chen trip history loaded into the trip_history Delta table
**So that** the preference extraction engine has something meaningful to analyze

## Acceptance Criteria
- [ ] `data/seed/sarah_chen_full.json` uploaded to a Unity Catalog Volume (or DBFS)
- [ ] Run the notebook \`databricks/notebooks/ingest_synthetic_data.py\`
- [ ] Verify 45 trips loaded for traveler-sc-001 with origin BOS
- [ ] Verify the travelers dim table has the Sarah Chen profile with Marriott Bonvoy Platinum Elite + Delta SkyMiles Platinum Medallion loyalty accounts
- [ ] Sanity check query in the notebook returns expected counts

## Persona decision (resolved)
Adopted Option 1: adapted Marcus Chen → Sarah Chen.
- Name: Sarah Chen
- Location: Boston, MA (212 Beacon Street)
- Employer: Acme Corp
- Title: VP of Strategic Partnerships
- Loyalty: Delta SkyMiles Platinum Medallion, Marriott Bonvoy Platinum Elite
- 45 trips spanning 2 years, all SLC origins replaced with BOS, all Hilton properties replaced with Marriott equivalents

The adapted JSON is checked in at \`data/seed/sarah_chen_full.json\`.

## Design Reference
See [Backlog doc](../docs/Veyant_Preference_Intelligence_Backlog.md), Feature F7.1.

## Depends on
- US 7.1.1
EOF
)" "epic:E7-trip-intelligence,feature:F7.1-trip-history,priority:P1,complexity:moderate,status:blocked,type:user-story" "F7.1 - Trip History Schema & Seed Data"

create_issue "US 7.1.3 — Trip History API endpoint" "$(cat <<'EOF'
## User Story
**As** the preference extraction service
**I want** an HTTP endpoint to retrieve trip history for a traveler
**So that** the extraction logic doesn't need to know about Databricks SQL connection details

## Acceptance Criteria
- [ ] Azure Function `GET /api/travelers/{travelerId}/trips` implemented
- [ ] Reads from `veyant_dev.travel_data.trip_history` via Databricks SQL Warehouse
- [ ] Supports `?limit=N&before=YYYY-MM-DD` query parameters
- [ ] Returns records sorted by `start_date` descending
- [ ] Returns 404 for unknown traveler IDs
- [ ] Authenticated via Managed Identity to Databricks SQL Warehouse

## Design Reference
See [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md), Section 8.1.

## Depends on
- US 7.1.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.1-trip-history,priority:P1,complexity:moderate,status:blocked,type:user-story" "F7.1 - Trip History Schema & Seed Data"

# ============================================================================
# F7.2 — Inference Service
# ============================================================================

create_issue "US 7.2.1 — InferenceClient module (Mosaic AI backend)" "$(cat <<'EOF'
## User Story
**As** a developer
**I want** a single InferenceClient abstraction for all LLM calls
**So that** application code never imports a model SDK directly and we can swap providers later without touching business logic

## Acceptance Criteria
- [ ] `functions/shared/inference_client.py` implements the interface defined in design doc Section 7.1
- [ ] Backend points at the Mosaic AI Model Serving endpoint from US 7.0.4
- [ ] Endpoint URL and token loaded from Key Vault via Managed Identity
- [ ] `generate(prompt, response_schema, max_tokens, temperature)` method implemented
- [ ] OpenAI-compatible REST call (Mosaic AI exposes this)
- [ ] Unit tests with mocked HTTP calls
- [ ] Configurable timeout (default 30s)

## Design Reference
See [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md), Section 7.1 for the interface contract.

## Depends on
- US 7.0.4
EOF
)" "epic:E7-trip-intelligence,feature:F7.2-inference,priority:P1,complexity:moderate,status:blocked,type:user-story" "F7.2 - Inference Service"

create_issue "US 7.2.2 — Structured JSON extraction from LLM output" "$(cat <<'EOF'
## User Story
**As** the preference extraction engine
**I want** reliable structured JSON from the LLM
**So that** preference data can be parsed without brittle string handling

## Acceptance Criteria
- [ ] System prompt instructs the model to respond ONLY with valid JSON
- [ ] Response parser attempts JSON.parse on raw output
- [ ] Fallback regex extraction if model adds preamble like "Sure! Here is..."
- [ ] Schema validation against the expected response shape
- [ ] Returns typed error with raw LLM output on failure (for debugging)
- [ ] Unit tested with sample Llama 3 70B outputs including failure modes

## Design Reference
See [Backlog doc](../docs/Veyant_Preference_Intelligence_Backlog.md), US 7.2.2.

## Depends on
- US 7.2.1
EOF
)" "epic:E7-trip-intelligence,feature:F7.2-inference,priority:P1,complexity:simple,status:blocked,type:user-story" "F7.2 - Inference Service"

create_issue "US 7.2.3 — Setup docs for Databricks workspace + Mosaic AI" "$(cat <<'EOF'
## User Story
**As** a new developer joining the project
**I want** clear setup instructions for Databricks and Mosaic AI
**So that** I can run the preference engine locally without guessing

## Acceptance Criteria
- [ ] README section "Inference Layer Setup"
- [ ] Documents how to authenticate against Databricks workspace
- [ ] Documents how to verify the Mosaic AI endpoint is responding
- [ ] Documents how to set environment variables for local Functions runtime
- [ ] Health check endpoint added to verify connectivity

## Depends on
- US 7.2.1
EOF
)" "epic:E7-trip-intelligence,feature:F7.2-inference,priority:P2,complexity:simple,status:blocked,type:user-story" "F7.2 - Inference Service"

# ============================================================================
# F7.3 — Preference Extraction Engine
# ============================================================================

create_issue "US 7.3.1 — Preference extraction prompt design" "$(cat <<'EOF'
## User Story
**As** a product builder
**I want** a well-engineered prompt that extracts meaningful travel preferences from trip history
**So that** derived preferences reflect actual behavior, not LLM hallucinations

## Acceptance Criteria
- [ ] Prompt template stored at `functions/prompts/preference_extraction_v1.txt`
- [ ] Injects a human-readable trip summary (NOT raw JSON) for token efficiency
- [ ] Asks for: airline preference, cabin by duration, seat type, hotel chain, hotel tier, booking lead time, loyalty priority
- [ ] Returns confidence levels (low/medium/high) per category
- [ ] Distinguishes "always" vs "tends to"
- [ ] Tested against Sarah Chen seed data — output matches expected behavioral patterns
- [ ] Prompt versioning convention documented (v1, v2, etc.)

## Design Reference
See [Backlog doc](../docs/Veyant_Preference_Intelligence_Backlog.md), US 7.3.1 for the sample prompt structure.

## Depends on
- US 7.1.2
- US 7.2.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.3-extraction,priority:P1,complexity:complex,status:blocked,type:user-story" "F7.3 - Preference Extraction Engine"

create_issue "US 7.3.2 — Preference profile schema (Python types)" "$(cat <<'EOF'
## User Story
**As** the preference persistence layer
**I want** a well-defined schema for the derived preference object
**So that** stored preferences are consistent and queryable

## Acceptance Criteria
- [ ] Pydantic model `DerivedPreferenceProfile` in `functions/shared/schemas/preference_profile.py`
- [ ] Covers air, hotel, car, loyalty, booking behavior categories
- [ ] Metadata fields: `derivedAt`, `tripHistoryWindowDays`, `recordCount`, `modelUsed`, `schemaVersion`
- [ ] Confidence levels are typed enums (not free strings)
- [ ] Schema versioned to allow future evolution

## Depends on
- US 7.1.1
EOF
)" "epic:E7-trip-intelligence,feature:F7.3-extraction,priority:P1,complexity:simple,status:blocked,type:user-story" "F7.3 - Preference Extraction Engine"

create_issue "US 7.3.3 — Preference extraction service (core)" "$(cat <<'EOF'
## User Story
**As** a traveler
**I want** Veyant to understand my preferences from my travel history
**So that** trip suggestions reflect how I actually travel

## Acceptance Criteria
- [ ] `PreferenceExtractionService.derive(traveler_id)` implemented
- [ ] Fetches trip history via the API from US 7.1.3
- [ ] Builds human-readable trip summary
- [ ] Calls InferenceClient with the prompt from US 7.3.1
- [ ] Validates response against schema from US 7.3.2
- [ ] Returns DerivedPreferenceProfile
- [ ] Edge case: <3 trips returns low-confidence profile with warning
- [ ] End-to-end test against Sarah Chen seed data passes

## Design Reference
See [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md), Section 7.2.

## Depends on
- US 7.1.3
- US 7.2.1
- US 7.3.1
- US 7.3.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.3-extraction,priority:P1,complexity:complex,status:blocked,type:user-story" "F7.3 - Preference Extraction Engine"

create_issue "US 7.3.4 — Preference extraction API endpoint" "$(cat <<'EOF'
## User Story
**As** a frontend or MCP tool
**I want** an API endpoint to trigger preference derivation on demand
**So that** preferences can be refreshed without restarting any service

## Acceptance Criteria
- [ ] `POST /api/travelers/{travelerId}/preferences/derive` implemented as Azure Function
- [ ] Returns derived profile on success (200)
- [ ] Returns 503 with helpful message if Mosaic AI endpoint unreachable
- [ ] Execution time logged to Application Insights
- [ ] `GET /api/travelers/{travelerId}/preferences` returns the active persisted profile

## Depends on
- US 7.3.3
- US 7.4.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.3-extraction,priority:P1,complexity:moderate,status:blocked,type:user-story" "F7.3 - Preference Extraction Engine"

# ============================================================================
# F7.4 — Preference Persistence Layer
# ============================================================================

create_issue "US 7.4.1 — Delta + Lakebase preference profile schemas, sync setup" "$(cat <<'EOF'
## User Story
**As** the persistence layer
**I want** preference profiles stored in Delta with a Lakebase projection for fast reads
**So that** the suggestion engine can read profiles in <10ms while keeping Delta as the source of truth

## Acceptance Criteria
- [ ] Delta table `veyant_dev.travel_data.preference_profiles` created (DDL from design doc Section 6.3)
- [ ] Delta table `veyant_dev.travel_data.derivation_runs` created (DDL from design doc Section 6.4)
- [ ] Lakebase database provisioned in the workspace
- [ ] Lakebase `preference_profiles` table created (mirrors Delta schema)
- [ ] Sync pipeline configured: Delta → Lakebase on change
- [ ] DDL committed to repo at `databricks/sql/02_preference_profiles.sql`

## Design Reference
See [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md), Sections 5.2 (Lakebase), 6.3, 6.4.

## Depends on
- US 7.0.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.4-persistence,priority:P1,complexity:complex,status:blocked,type:user-story" "F7.4 - Preference Persistence Layer"

create_issue "US 7.4.2 — Save and retrieve preference profile" "$(cat <<'EOF'
## User Story
**As** a preference scoring service
**I want** to save derived profiles to Delta and read them from Lakebase
**So that** scoring requests don't need to re-run the LLM

## Acceptance Criteria
- [ ] `PreferenceStore.save(profile)` writes to Delta (canonical) — sync handles Lakebase projection
- [ ] `PreferenceStore.get_active(traveler_id)` reads from Lakebase via psycopg/asyncpg
- [ ] `PreferenceStore.get_history(traveler_id)` reads from Delta SQL Warehouse
- [ ] Only one profile flagged `is_active = true` per traveler at a time
- [ ] Saving a new profile flips the previous active one to inactive (transactional)

## Depends on
- US 7.4.1
- US 7.3.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.4-persistence,priority:P1,complexity:moderate,status:blocked,type:user-story" "F7.4 - Preference Persistence Layer"

create_issue "US 7.4.3 — Preference freshness logic + batch re-derivation workflow" "$(cat <<'EOF'
## User Story
**As** the system
**I want** to know when a preference profile is stale and re-derive it automatically
**So that** preferences stay current as new trips are booked

## Acceptance Criteria
- [ ] `is_stale()` returns true if: last derivation > 30 days OR 3+ new trips since last derivation
- [ ] Stale profiles still served, but flagged `stale: true` in response
- [ ] Databricks Workflow created: weekly batch re-derivation for all stale travelers
- [ ] Workflow uses Change Data Feed on trip_history to identify which travelers have new data
- [ ] Workflow logs run details to `derivation_runs` table
- [ ] Manual trigger available via API (US 7.3.4)

## Depends on
- US 7.4.2
- US 7.3.3
EOF
)" "epic:E7-trip-intelligence,feature:F7.4-persistence,priority:P2,complexity:moderate,status:blocked,type:user-story" "F7.4 - Preference Persistence Layer"

# ============================================================================
# F7.5 — Preference-Aware Option Scoring
# ============================================================================

create_issue "US 7.5.1 — Preference scoring logic" "$(cat <<'EOF'
## User Story
**As** a traveler
**I want** flight and hotel options scored against my actual derived preferences
**So that** the system recommends things that fit how I actually travel

## Acceptance Criteria
- [ ] `preference_scorer.score(option, profile)` returns 0-100 with breakdown
- [ ] Carrier preference: +30 pts if preferred, scaled for non-preferred
- [ ] Cabin match: +25 pts if cabin matches preferred cabin for the flight duration
- [ ] Seat type: +15 pts if preferred seat type
- [ ] Hotel chain: +20 pts if in preferred chains
- [ ] Hotel tier: +10 pts if matches preferred tier
- [ ] Pure function, deterministic, fully unit tested
- [ ] No LLM calls in this code path

## Design Reference
See [Backlog doc](../docs/Veyant_Preference_Intelligence_Backlog.md), US 7.5.1.

## Depends on
- US 7.3.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.5-scoring,priority:P1,complexity:moderate,status:blocked,type:user-story" "F7.5 - Preference-Aware Option Scoring"

create_issue "US 7.5.2 — MCP tool integration (get_preference_score)" "$(cat <<'EOF'
## User Story
**As** the existing Veyant MCP server
**I want** the get_preference_score tool to use real derived preferences
**So that** the demo shows genuine intelligence, not canned scores

## Acceptance Criteria
- [ ] Existing `get_preference_score` MCP tool updated to call `PreferenceStore.get_active(travelerId)` via the Functions API
- [ ] If active profile exists: runs scoring logic from US 7.5.1
- [ ] If no profile exists: falls back to mock with `source: 'mock'` flag in response
- [ ] Score breakdown returned in response: `{score, breakdown: {carrier, cabin, seat, ...}, source: 'derived' | 'mock'}`
- [ ] Sarah Chen demo scenario produces noticeably different scores for Delta vs United options
- [ ] Existing MCP server tests still pass

## Depends on
- US 7.5.1
- US 7.4.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.5-scoring,priority:P1,complexity:moderate,status:blocked,type:user-story" "F7.5 - Preference-Aware Option Scoring"

# ============================================================================
# F7.6 — Preference-Driven Trip Suggestions
# ============================================================================

create_issue "US 7.6.1 — Suggestion engine core logic" "$(cat <<'EOF'
## User Story
**As** a traveler
**I want** Veyant to suggest the best trip options for a given route
**So that** I get a ranked shortlist that fits my preferences, my company's policy, and what's actually available

## Acceptance Criteria
- [ ] `SuggestionEngine.suggest(traveler_id, route, dates)` returns ranked list
- [ ] Reads preferences from Lakebase (no LLM call on the request path)
- [ ] Reads policy from Delta (or in-memory cache)
- [ ] Calls existing supplier search MCP for available options
- [ ] Composite score = preference (60%) + policy (40%)
- [ ] Returns top 3 options with full breakdown
- [ ] Policy-failing options still returned but flagged and ranked lower
- [ ] Total request latency under 1 second for cached scenarios

## Design Reference
See [Azure Architecture doc](../docs/Veyant_Preference_Engine_Azure_Architecture.md), Section 8.2.

## Depends on
- US 7.5.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.6-suggestions,priority:P2,complexity:complex,status:blocked,type:user-story" "F7.6 - Preference-Driven Trip Suggestions"

create_issue "US 7.6.2 — Trip suggestion API endpoint" "$(cat <<'EOF'
## User Story
**As** the chat UI or Travel Cockpit
**I want** an HTTP endpoint that returns ranked trip suggestions
**So that** the frontend doesn't embed scoring logic

## Acceptance Criteria
- [ ] `POST /api/suggestions` implemented as Azure Function
- [ ] Request body: `{travelerId, origin, destination, departureDate, returnDate}`
- [ ] Calls SuggestionEngine from US 7.6.1
- [ ] Returns ranked options within 10 seconds
- [ ] Optional: streamed or polled status via `GET /api/suggestions/{requestId}/status`
- [ ] Telemetry logged to Application Insights

## Depends on
- US 7.6.1
EOF
)" "epic:E7-trip-intelligence,feature:F7.6-suggestions,priority:P2,complexity:moderate,status:blocked,type:user-story" "F7.6 - Preference-Driven Trip Suggestions"

create_issue "US 7.6.3 — Demo integration: Sarah Chen end-to-end suggestion scenario" "$(cat <<'EOF'
## User Story
**As** a demo runner
**I want** the full preference-to-suggestion pipeline working end-to-end for Sarah Chen
**So that** I can show a live working demo in 5 minutes

## Acceptance Criteria
- [ ] Full chain works: trip history → derivation → persistence → scoring → suggestion ranking
- [ ] Demo script: "Find me the best flights to London next month" returns scored, ranked options
- [ ] Delta Business class scores higher than United Economy (consistent with derived prefs)
- [ ] Policy-compliant options visually distinguished from policy exceptions
- [ ] UI surfaces "scoring based on derived history" so the intelligence is visible
- [ ] Demo works reliably across 5+ run-throughs without manual intervention
- [ ] Loom-friendly (single tab, predictable timing)

## Design Reference
This is the demo payoff. Validates the entire epic.

## Depends on
- US 7.6.2
- US 7.5.2
EOF
)" "epic:E7-trip-intelligence,feature:F7.6-suggestions,priority:P2,complexity:complex,status:blocked,type:user-story" "F7.6 - Preference-Driven Trip Suggestions"

echo ""
echo "Done. Created labels, milestones, and 22 issues in $REPO."
echo ""
echo "Next steps:"
echo "  1. Visit https://github.com/$REPO/issues"
echo "  2. Resolve the 'needs-decision' issue (US 7.1.2 — Sarah Chen persona question)"
echo "  3. Start with the P1 'status:ready' issues — those are the unblocked critical path"
echo "  4. As US 7.0.x foundation issues complete, manually flip dependent issues from 'blocked' to 'ready'"

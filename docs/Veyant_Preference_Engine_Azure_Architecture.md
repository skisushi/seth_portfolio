# Veyant: Preference Intelligence Engine
## Azure Architecture (CTO-Level Design)
### Version 1.0 | April 2026

---

## 1. Executive Summary

This document describes the Azure architecture for Veyant's Trip Intelligence feature — the system that derives traveler preferences from trip history and uses them to power personalized trip suggestions. The design assumes a single-tenant deployment for the demo phase, with design intent for SOC 2 / GDPR readiness documented but not implemented in v1.

**Architectural pivot:** Moving from local Ollama + SQLite (the previous demo-grade design) to Azure Databricks as the centerpiece. Databricks consolidates inference, data storage, vector search, ML lifecycle, and batch processing into a single PaaS, which simplifies the stack and shortens the path from demo to production.

**Key decisions made up front:**
- **Inference layer:** Azure Databricks Mosaic AI Model Serving (Llama 3 70B Instruct), pay-per-token
- **Tenancy:** Single-tenant deployment with multi-tenant data model (every record carries `tenantId`)
- **Compliance posture:** Demo + design intent documented, controls not yet implemented
- **Analytical data plane:** Delta Lake on Databricks (Unity Catalog governed) for trip history of record, derivation runs, ML lineage
- **OLTP data plane:** Lakebase (Databricks serverless Postgres, formerly Neon) for preference profiles served on the user request path
- **API layer:** Azure Functions (Python) fronted by Azure API Management
- **Identity:** Microsoft Entra ID with Managed Identities for service-to-service auth

---

## 2. Why Databricks Instead of the Earlier Ollama + SQLite Plan

The local Ollama plan was correct for "fastest demo possible." Azure deployment changes the math because we now have a real PaaS option that consolidates several capabilities we'd otherwise have to wire together.

**What Databricks gives us in one place:**

| Capability | Without Databricks | With Databricks |
|---|---|---|
| LLM inference | Self-host Ollama on Container Apps + manage scaling | Mosaic AI Model Serving — Llama 3 70B as a managed endpoint, pay per token |
| Operational data store | Cosmos DB (separate service, separate cost, separate auth) | Delta Lake tables in Unity Catalog |
| Vector search | Azure AI Search (separate service, separate index management) | Mosaic AI Vector Search, native to the same workspace |
| Batch reprocessing | Azure Functions + custom orchestration | Databricks Workflows + notebooks |
| Model versioning / lineage | Custom in-app logic | MLflow (built-in) |
| Data governance | Manual RBAC across services | Unity Catalog (single permission model across all data and models) |
| Analytical queries | Custom SQL layer over Cosmos | Databricks SQL Warehouse (serverless) |

The cost of this consolidation: a Databricks workspace baseline charge and a learning curve. The benefit: one auth model, one governance model, one billing line, and a credible production foundation rather than a demo-only stack.

**One important nuance — solved by Lakebase:** Historically, Databricks was excellent for the AI/ML/analytical plane but wrong for high-frequency operational reads. That gap closed when Databricks acquired Neon (May 2024) and productized it as **Lakebase** — a serverless Postgres with Git-style branching, sub-10ms reads, and native bi-directional sync to Delta Lake, all governed by Unity Catalog.

This means we get both planes from a single platform:

- **Delta Lake** = analytical plane (trip history of record, derivation runs, ML training data, time travel for "what did Sarah's preferences look like 30 days ago")
- **Lakebase** = OLTP plane (preference profiles for fast serving, session state, anything the API reads on the user request path)
- **Native sync** between the two managed by Databricks, no custom ETL or change data capture pipelines to maintain

The Suggestion Engine reads preferences from Lakebase (transactional, sub-10ms). Preference derivation writes the canonical record to Delta (for lineage and ML) and projects to Lakebase (for serving). One platform, one auth model, one governance layer.

---

## 3. Architectural Principles

**Principle 1 — Single source of truth, multiple read paths.**  
Trip history lives in Delta Lake. Other systems (operational caches, search indexes) are derived projections, never primary writes.

**Principle 2 — Inference behind an abstraction.**  
The application code never imports a model SDK directly. All LLM calls go through an internal `InferenceClient` that exposes a simple `generate(prompt, schema)` interface. This means we can swap the underlying model (Llama 3 → DBRX → fine-tuned model) without touching the rest of the codebase.

**Principle 3 — Multi-tenant data model from day one, single-tenant deployment.**  
Every Delta table has a `tenantId` column even though we have one tenant. This is the cheapest insurance policy in software architecture — adding tenant isolation later means rewriting half the queries.

**Principle 4 — Managed identities everywhere, secrets nowhere.**  
No connection strings in code. Service-to-service auth uses Microsoft Entra ID Managed Identities. Anything that absolutely needs a secret (third-party APIs) goes through Key Vault with managed identity access.

**Principle 5 — Demo-grade compute, production-grade data model.**  
We'll use serverless and pay-per-use compute for the demo phase (Functions Consumption plan, Databricks serverless SQL, pay-per-token model serving). The data schemas, partition strategies, and indexing decisions are designed as if we're running at production scale.

---

## 4. Component Architecture

```
                            ┌──────────────────────────────┐
                            │   Microsoft Entra ID         │
                            │  (Identity / Managed IDs)    │
                            └──────────────────────────────┘
                                          │
                                          ▼
┌─────────────┐         ┌─────────────────────────────────┐
│  React UI   │────────▶│   Azure API Management          │
│ (Static Web │  HTTPS  │   (auth, throttling, routing)   │
│   Apps)     │         └─────────────────────────────────┘
└─────────────┘                           │
                                          ▼
                          ┌─────────────────────────────────┐
                          │   Azure Functions (Python)      │
                          │   ─────────────────────────     │
                          │   • /trips/...                  │
                          │   • /preferences/derive         │
                          │   • /preferences/{travelerId}   │
                          │   • /suggestions                │
                          │   • /policy/check (existing)    │
                          └─────────────────────────────────┘
                                          │
                ┌─────────────────────────┼──────────────────────────┐
                │                         │                          │
                ▼                         ▼                          ▼
   ┌────────────────────┐  ┌───────────────────────┐  ┌──────────────────────┐
   │ Azure Databricks   │  │ Azure Databricks      │  │  Existing Veyant     │
   │ Mosaic AI          │  │ SQL Warehouse         │  │  MCP Server          │
   │ Model Serving      │  │ (serverless)          │  │  (containerized)     │
   │                    │  │                       │  │                      │
   │ • Llama 3 70B      │  │ Reads from Unity      │  │ Calls into Functions │
   │ • Embeddings       │  │ Catalog Delta tables  │  │ for prefs + policy   │
   │ • Vector Search    │  │                       │  │                      │
   └────────────────────┘  └───────────────────────┘  └──────────────────────┘
                │                         │
                │                         │
                └────────────┬────────────┘
                             │
                             ▼
                ┌─────────────────────────────┐
                │  Unity Catalog (Databricks) │
                │  ─────────────────────────  │
                │  veyant.trip_history        │
                │  veyant.preference_profiles │
                │  veyant.derivation_runs     │
                │  veyant.suppliers           │
                │  veyant.corporate_policies  │
                │                             │
                │  Storage: ADLS Gen2         │
                │  Format:  Delta Lake        │
                └─────────────────────────────┘
                             │
                             │ (event-driven via
                             │  Databricks Workflows)
                             ▼
                ┌─────────────────────────────┐
                │  Batch Preference           │
                │  Re-derivation Job          │
                │  (Notebook + Workflow)      │
                └─────────────────────────────┘

         ┌───────────────────────────────────────────┐
         │ Cross-cutting:                            │
         │ • Application Insights (telemetry)        │
         │ • Azure Key Vault (secrets)               │
         │ • Log Analytics Workspace (audit logs)    │
         │ • Azure Monitor (alerts)                  │
         └───────────────────────────────────────────┘
```

---

## 5. Azure Services Selected

### 5.1 Compute & API Layer

**Azure Functions (Python, Consumption plan)**  
The lightweight HTTP API for the application. Functions stay cheap when idle (free tier covers 1M executions/month) and scale automatically. Python because the Databricks SDK and the data science ecosystem are first-class.

**Azure API Management (Consumption tier)**  
Sits in front of Functions. Provides rate limiting, API key management, request validation, and a single egress point. Also lets us add OAuth/OIDC later without touching Functions code.

**Azure Static Web Apps**  
Hosts the React frontend (existing demo UI). Free tier is sufficient for demo phase. Built-in CDN, custom domains, and Entra ID integration.

### 5.2 AI / ML / Data Plane (Databricks)

**Azure Databricks Workspace (Premium SKU)**  
Single workspace, single region (East US 2 recommended for proximity to Azure OpenAI capacity if we ever need it as a fallback). Premium SKU is required for Unity Catalog and serverless features.

**Mosaic AI Model Serving — Foundation Model APIs**  
Hosts Llama 3 70B Instruct as a pay-per-token endpoint. Fully managed by Databricks, no infrastructure to provision. OpenAI-compatible API surface so the `InferenceClient` abstraction works against any compatible provider.

Approximate cost for the demo phase: a single preference extraction call against an 18-month trip history is roughly 4K input tokens + 1K output tokens. Llama 3 70B on Mosaic AI is about $1 per million input tokens and $3 per million output tokens. That's $0.007 per derivation. A demo with 1,000 derivations costs $7.

**Mosaic AI Vector Search**  
Used for semantic similarity searches (e.g., "find trips similar to this one in the user's history"). Built directly on Delta tables — no separate index sync. We don't need it for v1 of the preference engine but it's available the moment we want to layer in semantic features.

**Unity Catalog**  
The governance layer for all Delta tables and ML models. Permissions, lineage, audit logs, and column-level masking all live here. This is the foundation that makes the multi-tenant data model honest — `tenantId` filtering can be enforced via row-level security policies in Unity Catalog rather than relying on application code to remember.

**Delta Lake on ADLS Gen2**  
The actual storage format for trip history, preference profiles, and derivation runs. ACID transactions, time travel (we can ask "what did Sarah's preferences look like 30 days ago"), and schema evolution all come for free.

**Databricks SQL Warehouse (Serverless)**  
For analytical queries against the Delta tables. Pays per query, scales to zero when idle. Used by the preference derivation pipeline (which needs to read full trip history) and by analytics notebooks. Not used on the user request path — that's what Lakebase is for.

**Lakebase (Databricks Serverless Postgres)**  
The OLTP plane for the application. Stores preference profiles, traveler session state, and any other data the API reads on the user request path where sub-10ms latency matters. Postgres-compatible, so the Functions code uses standard `psycopg` or `asyncpg` libraries — no proprietary client. Branching support means we can spin up a per-PR database snapshot for integration tests, which is a significant developer experience win.

Lakebase syncs bi-directionally with Delta Lake via Databricks-managed pipelines. Preference profiles get written to Delta as the source of truth (with full history and lineage) and automatically projected to Lakebase for fast serving. We never write to Lakebase directly from application code — Delta is always the write target, Lakebase is always the read target for the request path.

**Databricks Workflows**  
Orchestrates the batch re-derivation job. Triggered on a schedule (e.g., weekly) or on-demand via API. Re-runs preference extraction for all travelers whose history has changed since the last run.

### 5.3 Identity & Security

**Microsoft Entra ID**  
Workforce identity (Veyant team accessing the Databricks workspace, the Azure portal, the Functions logs). User identity (corporate travelers logging into the demo) is stubbed for the demo phase but designed against the same Entra ID tenant for v1 customers.

**Managed Identities (System-assigned)**  
Functions → Databricks via a managed identity. Functions → Key Vault via a managed identity. No connection strings, no client secrets, no API keys stored anywhere outside Key Vault.

**Azure Key Vault**  
Stores third-party API keys (supplier APIs, when we add them) and any application secrets that managed identities can't cover. Functions and Databricks both read from Key Vault via managed identity.

### 5.4 Observability

**Application Insights**  
Auto-instrumentation for Functions. Custom telemetry for the preference derivation pipeline (extraction duration, token counts, confidence scores).

**Log Analytics Workspace**  
Centralized logs from Functions, API Management, and Databricks (workspace audit logs and notebook runs ship here automatically when wired up).

**Azure Monitor + Action Groups**  
Alerts on the things that matter for a demo: model serving endpoint latency, derivation job failures, API 5xx rates.

---

## 6. Data Architecture

### 6.1 Unity Catalog Schema

```
Catalog: veyant_dev
├── Schema: travel_data
│   ├── trip_history          (Delta, partitioned by tenant_id, year)
│   ├── preference_profiles   (Delta, partitioned by tenant_id)
│   ├── derivation_runs       (Delta, append-only, partitioned by run_date)
│   └── travelers             (Delta, dimensional table)
├── Schema: corporate
│   ├── policies              (Delta)
│   ├── preferred_suppliers   (Delta)
│   └── negotiated_rates      (Delta)
├── Schema: supplier
│   ├── catalog               (Delta)
│   └── api_metadata          (Delta)
└── Schema: ml_models
    └── (MLflow registered models)
```

### 6.2 Trip History Table (Delta)

The schema follows the existing JSON structure from the synthetic data set the team has already produced (Marcus Chen, Sarah Martinez, etc.). Stored as a flattened Delta table with nested arrays for segments to preserve the rich data model.

```sql
CREATE TABLE veyant_dev.travel_data.trip_history (
  tenant_id STRING NOT NULL,
  traveler_id STRING NOT NULL,
  trip_id STRING NOT NULL,
  trip_name STRING,
  trip_type STRING,                      -- business | leisure
  start_date DATE,
  end_date DATE,
  origin STRING,
  destination STRING,
  booked_date DATE,
  booked_by STRING,                      -- self | assistant
  total_cost DECIMAL(10,2),
  currency STRING,
  air ARRAY<STRUCT<...>>,                -- preserves the existing structure
  hotel ARRAY<STRUCT<...>>,
  car ARRAY<STRUCT<...>>,
  ground ARRAY<STRUCT<...>>,
  calendar_events ARRAY<STRUCT<...>>,
  ingested_at TIMESTAMP,
  source_system STRING
)
USING DELTA
PARTITIONED BY (tenant_id, YEAR(start_date))
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true'
);
```

**Why partition by tenant + year:**  
Tenant first because the dominant query pattern will be "give me everything for this tenant." Year second because preference derivation always operates on a recent window (typically 18 months) — partition pruning eliminates 90%+ of the data on every query.

**Change Data Feed enabled** so the batch re-derivation workflow can detect which travelers have new trips and only reprocess those.

### 6.3 Preference Profiles Table (Delta)

```sql
CREATE TABLE veyant_dev.travel_data.preference_profiles (
  tenant_id STRING NOT NULL,
  traveler_id STRING NOT NULL,
  profile_id STRING NOT NULL,            -- UUID per derivation
  is_active BOOLEAN,
  derived_at TIMESTAMP,
  trip_window_days INT,
  trip_record_count INT,
  model_used STRING,                     -- e.g. "llama-3-70b-instruct"
  schema_version STRING,
  profile_json STRING,                   -- the structured preference object
  confidence_overall DECIMAL(3,2),
  derivation_run_id STRING               -- FK to derivation_runs
)
USING DELTA
PARTITIONED BY (tenant_id);
```

Multiple profiles per traveler are stored — never overwritten. The `is_active` flag identifies the current one. This gives us free history (compare what Sarah's preferences looked like 6 months ago vs. now) and the ability to A/B compare model versions.

### 6.4 Derivation Runs Table (Delta, append-only)

```sql
CREATE TABLE veyant_dev.travel_data.derivation_runs (
  run_id STRING NOT NULL,
  tenant_id STRING NOT NULL,
  triggered_by STRING,                   -- user | schedule | data_change
  run_started_at TIMESTAMP,
  run_completed_at TIMESTAMP,
  travelers_processed INT,
  travelers_succeeded INT,
  travelers_failed INT,
  total_input_tokens BIGINT,
  total_output_tokens BIGINT,
  estimated_cost_usd DECIMAL(8,4),
  model_used STRING,
  notes STRING
)
USING DELTA
PARTITIONED BY (DATE(run_started_at));
```

Append-only audit table. Used for cost tracking, debugging, and compliance reporting (the design-intent compliance posture we documented).

### 6.5 Tenant Isolation Strategy

For the demo phase we have one tenant (`tenant_id = 'veyant-demo'`). The Unity Catalog row filter pattern below is designed in but not yet enforced — when we onboard the second tenant, this gets switched on.

```sql
-- Future row-level security policy (not active in v1)
CREATE FUNCTION veyant_dev.security.tenant_filter(tenant_id STRING)
RETURN tenant_id = current_user_tenant();

ALTER TABLE veyant_dev.travel_data.trip_history
  SET ROW FILTER veyant_dev.security.tenant_filter ON (tenant_id);
```

---

## 7. Inference & ML Architecture

### 7.1 The Inference Abstraction

The application never imports a model SDK directly. Instead, every LLM call goes through:

```python
# functions/shared/inference_client.py

class InferenceClient:
    def __init__(self, endpoint_url: str, model: str):
        self.endpoint_url = endpoint_url
        self.model = model
    
    async def generate(
        self, 
        prompt: str, 
        response_schema: dict,
        max_tokens: int = 1024,
        temperature: float = 0.2
    ) -> dict:
        """
        Returns parsed JSON matching response_schema.
        Raises InferenceError on failure.
        """
        ...
```

**Why this matters:** The current backend is Databricks Mosaic AI. If next quarter we want to swap to Azure OpenAI, a self-hosted Llama on Azure ML, or a fine-tuned domain model, only this one file changes. Every other piece of the codebase calls `inference_client.generate(...)` and doesn't care.

### 7.2 Preference Extraction Pipeline

```
1. API call: POST /preferences/derive { travelerId }
   ↓
2. Function: queries trip history from Databricks SQL Warehouse
   ↓
3. Function: builds human-readable trip summary (token-efficient)
   ↓
4. Function: calls InferenceClient.generate() with extraction prompt
   ↓
5. Mosaic AI Model Serving: Llama 3 70B returns structured JSON
   ↓
6. Function: validates against schema, computes confidence
   ↓
7. Function: writes new preference profile to Delta table
   ↓
8. Function: returns profile to caller
```

The synchronous path runs in under 10 seconds for a single traveler. For batch reprocessing of all travelers, the Databricks Workflow path runs the same logic but in parallel across a cluster.

### 7.3 Why Llama 3 70B Specifically

A few reasons:
- **It's smart enough.** Preference extraction from ~30 trips of structured data is well within Llama 3 70B's reasoning capability. We don't need GPT-4-class reasoning here.
- **It's cheap enough.** Pay-per-token, no idle compute, no provisioned throughput needed for demo phase.
- **It's open weights.** If we ever decide to fine-tune on travel-specific data, we can do that on Databricks itself using the same model family.
- **It's swappable.** If a better open-source travel model emerges, the abstraction layer means we can switch in a day.

### 7.4 Future Capabilities Enabled by This Stack

**Vector search over trip history.**  
Mosaic AI Vector Search can build an embedding index directly from the Delta trip history table. Future query: "find me trips that look like Sarah's typical Boston-to-London pattern" returns semantically similar trips, not keyword matches.

**Fine-tuning a Veyant-specific model.**  
Once we have enough labeled data (preference extractions that humans have validated), we can fine-tune Llama 3 8B on travel-specific extraction tasks. Cheaper inference and better accuracy than the generalist 70B model. All on the same Databricks workspace, no data movement.

**Trip outcome prediction.**  
With trip history + booked options + actual outcomes (delays, satisfaction signals), we can train classical ML models alongside the LLM extraction. MLflow tracks both kinds of models in the same registry.

---

## 8. API & Function Layer

### 8.1 Function App Structure

```
veyant-functions/
├── functions/
│   ├── trips_get.py              GET  /trips/{travelerId}
│   ├── trips_get_one.py          GET  /trips/{travelerId}/{tripId}
│   ├── preferences_derive.py     POST /preferences/derive
│   ├── preferences_get.py        GET  /preferences/{travelerId}
│   ├── preferences_history.py    GET  /preferences/{travelerId}/history
│   ├── suggestions_get.py        POST /suggestions
│   └── policy_check.py           POST /policy/check
├── shared/
│   ├── inference_client.py
│   ├── databricks_client.py
│   ├── preference_extractor.py
│   ├── preference_scorer.py
│   ├── suggestion_engine.py
│   └── schemas/
│       ├── trip_history.py
│       └── preference_profile.py
├── prompts/
│   └── preference_extraction_v1.txt
├── tests/
└── host.json
```

### 8.2 The Suggestion Engine Composition

This is where the three-cube vision actually pays off. The suggestion engine is intentionally a thin orchestration layer:

```python
async def suggest_trips(traveler_id: str, route: Route, dates: DateRange):
    # 1. Get preferences from Delta (cached, no LLM call)
    preferences = await preference_store.get_active(traveler_id)
    
    # 2. Get policy for the traveler's company (Delta)
    policy = await policy_store.get(traveler.company_id)
    
    # 3. Get supplier options for the route (existing MCP)
    options = await supplier_search.search(route, dates)
    
    # 4. Score every option against preferences + policy
    scored = [
        {
            "option": opt,
            "preference_score": preference_scorer.score(opt, preferences),
            "policy_status": policy_engine.check(opt, policy),
            "composite_score": composite(opt, preferences, policy)
        }
        for opt in options
    ]
    
    # 5. Rank and return top 3
    return sorted(scored, key=lambda x: x["composite_score"], reverse=True)[:3]
```

**Important:** This whole call path makes zero LLM inference calls. Preferences are pre-derived and stored. Scoring is deterministic math. The only LLM call in the system is during the preference derivation, which is offline relative to the user request path.

This matters for two reasons: latency (suggestions return in under a second) and cost (no per-suggestion LLM tokens).

---

## 9. Identity, Security, and Compliance Posture

**Demo phase implementation (what's actually built):**
- Microsoft Entra ID for the Veyant team
- Managed Identities for Functions → Databricks and Functions → Key Vault
- Static API keys for the demo UI to call API Management (rotated manually)
- HTTPS everywhere (enforced by API Management and Functions)
- All Databricks data encrypted at rest (default)
- All Databricks data in transit encrypted (default)

**Design intent (documented, not yet implemented):**
- OAuth 2.0 / OIDC user authentication via Entra ID for traveler-facing endpoints
- Row-level security in Unity Catalog for tenant isolation
- Customer-managed keys (CMK) for ADLS Gen2 storage
- Private Endpoints for Databricks workspace, Key Vault, and Function App
- VNet integration with NSG rules restricting east-west traffic
- Audit log shipping from Unity Catalog to Log Analytics
- Data retention policies (GDPR right-to-be-forgotten via Delta Lake `DELETE` + `VACUUM`)
- PII tagging in Unity Catalog (column-level)
- SOC 2 control mappings for each implemented feature

**The right time to implement each design-intent item:** when the first customer asks. Documenting now means we can answer "yes, we've thought about this" in every sales conversation without doing the work prematurely.

---

## 10. Cost Profile (Demo Phase)

Rough monthly costs assuming demo-level traffic (Veyant team only, occasional customer demos):

| Service | SKU | Approx Monthly Cost |
|---|---|---|
| Azure Databricks Workspace | Premium, idle most of the time | $0 (compute only when running) |
| Databricks Mosaic AI Model Serving | Pay-per-token, ~10K derivations | $50–100 |
| Databricks SQL Warehouse | Serverless, ~5 hours/month active | $30–60 |
| Lakebase (Serverless Postgres) | Demo-level traffic, scale-to-zero | $20–40 |
| ADLS Gen2 Storage | <100 GB | $5 |
| Azure Functions | Consumption, well within free tier | $0 |
| Azure API Management | Consumption | $0 (first 1M calls free) |
| Static Web Apps | Free tier | $0 |
| Application Insights | <5 GB ingestion | $0 (free tier) |
| Key Vault | <1000 ops | $0 |
| Log Analytics | <5 GB ingestion | $0 (free tier) |
| **Total demo phase** | | **~$120–210/month** |

The dominant cost is Databricks compute. If we get aggressive about scale-to-zero discipline (turn off SQL warehouse when not in use, don't leave notebooks running), we can cut this in half.

---

## 11. Production Migration Path

The demo architecture above is production-shaped, not production-ready. Here's what changes when we get to a real customer:

**Phase 2 (first paying customer):**
- Lakebase already covers the hot-read OLTP requirement (no need to add Cosmos DB — this is what changed when Databricks acquired Neon)
- Implement OAuth user auth via Entra ID
- Enable Unity Catalog row-level security for tenant isolation
- Move Function App to Premium plan (eliminates cold starts)
- Add Azure Front Door + WAF in front of API Management
- Provision dedicated Lakebase instance with reserved capacity (instead of pay-per-use)

**Phase 3 (multi-tenant SaaS):**
- Multi-tenant Databricks workspace with workspace-per-customer for high-value enterprise tenants
- Move SQL Warehouse from serverless to dedicated cluster for predictable performance
- Implement customer-managed keys
- Implement Private Endpoints for all data services
- Pursue SOC 2 Type 1 audit

**The thing that doesn't change:** the data model, the inference abstraction, the API surface, the suggestion engine logic. All of that is designed once.

---

## 12. Backlog Impact

The backlog from `Veyant_Preference_Intelligence_Backlog.md` mostly carries over but with these changes:

| Original Story | Change for Azure/Databricks Architecture |
|---|---|
| US 7.1.1 — Trip History Schema | Refactor to match the existing Cosmos-style JSON schema from the synthetic data set, then translate to Delta table DDL |
| US 7.1.2 — Sarah Chen Seed Data | Use the synthetic data set already in `JSON synthetic data/`. Decide first whether we adapt Marcus Chen → Sarah Chen or use Marcus as-is (open question) |
| US 7.1.3 — Trip History API | Reads from Databricks SQL Warehouse via the Databricks SQL connector for Python, not from local JSON |
| US 7.2.1 — Ollama Client Module | **Replace** with `InferenceClient` abstraction targeting Mosaic AI Model Serving (OpenAI-compatible API surface) |
| US 7.2.2 — Structured JSON Extraction | Carries over with minor changes — Llama 3 70B is more reliable about JSON output than smaller models |
| US 7.2.3 — Setup docs | Replace Ollama setup with Databricks workspace setup + Mosaic AI endpoint creation |
| US 7.3.x — Extraction Engine | Carries over, runs as a Function. Same prompt design |
| US 7.4.1 — Preference Store (SQLite) | **Replace** with Delta table on Unity Catalog (`preference_profiles`) |
| US 7.4.2 — Save & Retrieve | Implement against Delta + SQL Warehouse |
| US 7.4.3 — Freshness Logic | Add a Databricks Workflow for batch re-derivation |
| US 7.5.x — Preference Scoring | Carries over unchanged |
| US 7.6.x — Suggestion Engine | Carries over unchanged |

**Net effect on story points:** roughly +8 points for the additional Databricks/Azure setup work, offset by –5 points from removing Ollama infrastructure stories. New total: ~60 points.

**New stories needed:**
- US 7.0.1 — Provision Azure resource group, Databricks workspace, ADLS Gen2 storage account (3 pts)
- US 7.0.2 — Set up Unity Catalog, create catalogs and schemas, configure permissions (2 pts)
- US 7.0.3 — Bicep / Terraform IaC for the entire stack (5 pts)
- US 7.0.4 — Create Mosaic AI Model Serving endpoint with Llama 3 70B (1 pt)

These four stories form a new feature: **F7.0 — Azure Foundation**. They are all critical-path and must complete before anything else in the backlog can ship.

---

## 13. What I'd Push Back On (As Your CTO)

A few things worth flagging directly:

**1. Databricks is a real commitment.**  
The team you eventually hire needs to know Databricks (or be willing to learn it). It's not as commoditized a skill as "knows Postgres" or "knows React." You're betting on the platform. I think it's the right bet for a data-and-AI-heavy product like Veyant, but it's worth saying out loud.

**2. The demo doesn't strictly need any of this.**  
For pure demo purposes, the original Ollama + SQLite design is faster to ship and equally compelling on screen. The reason to do the Azure work now is that it positions the demo as "this is real" rather than "this is a clever local prototype" — which materially changes how a TMC CTO reacts to it. That's the value proposition. If a Tier 1 conversation is more than 4 weeks out, the Azure path is worth the extra effort. If you have one next week, ship the local version first.

**3. The "Sarah Chen" persona question is still open.**  
We ducked it earlier by listing options. The architecture work doesn't depend on resolving it, but the seed data work does. Worth answering before US 7.1.2 starts — pick one of the three options I laid out in the previous response and don't relitigate it.

**4. We should not build US 7.6 (suggestions) until US 7.5 (scoring) is fully working with real preferences.**  
This is the biggest risk in the backlog. Suggestions are the demo payoff. If they're built on weak scoring, the whole demo falls flat. Discipline the team to validate scoring against actual derived preferences before touching the suggestion engine.

---

## 14. Open Questions for Decision

- **Sarah Chen vs. Marcus Chen** — adapt the data, use as-is, or build new? (Blocks US 7.1.2)
- **Region selection** — East US 2 is my recommendation for Databricks capacity and Azure OpenAI fallback availability. Confirm or override.
- **Subscription strategy** — single subscription for everything, or separate dev/prod subscriptions from day one? (My recommendation: single subscription with two resource groups.)
- **IaC tool** — Bicep or Terraform? Bicep is Azure-native and simpler. Terraform is portable and the broader market standard. (My recommendation: Bicep for now, with the discipline that the IaC files are committed to version control.)
- **Source control** — where does the Databricks notebook code live? Azure DevOps Repos, GitHub, or Databricks Repos with a Git provider? (My recommendation: GitHub, with Databricks Repos integrated for notebook sync.)

---

*Veyant.ai — Think deeply. Work smarter. Fail fast and pivot. Build good enough, not perfect.*

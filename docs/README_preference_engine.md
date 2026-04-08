# Veyant Preference Intelligence Engine

This module is part of Epic E7 — the trip-history-to-preference-derivation pipeline.

## What this does

Reads a traveler's historical trip records, sends a structured summary to a local LLM (Llama 3 70B running on Databricks Mosaic AI Model Serving), and produces a derived preference profile that gets persisted in Delta Lake (canonical) and Lakebase (fast read serving). The suggestion engine then composes this with corporate policy and supplier availability to rank trip options.

## Architecture

See [`Veyant_Preference_Engine_Azure_Architecture.md`](./Veyant_Preference_Engine_Azure_Architecture.md) for the full design.

See [`Veyant_Preference_Intelligence_Backlog.md`](./Veyant_Preference_Intelligence_Backlog.md) for the backlog and user stories.

## Repository layout (for the new files in this epic)

```
seth_portfolio/
├── docs/
│   ├── Veyant_Preference_Engine_Azure_Architecture.md   ← architecture
│   ├── Veyant_Preference_Intelligence_Backlog.md        ← backlog + user stories
│   └── README_preference_engine.md                      ← this file
├── databricks/
│   ├── sql/
│   │   ├── 01_trip_history.sql                          ← Delta DDL for trip_history
│   │   └── 02_preference_profiles.sql                   ← Delta DDL for preferences + Lakebase notes
│   └── notebooks/
│       └── ingest_synthetic_data.py                     ← Loads Sarah Chen seed data
├── functions/
│   ├── shared/
│   │   ├── inference_client.py                          ← LLM abstraction (Mosaic AI backend)
│   │   └── schemas/
│   │       └── preference_profile.py                    ← Pydantic models
│   └── prompts/
│       └── preference_extraction_v1.txt                 ← Extraction prompt template
├── data/
│   └── seed/
│       ├── sarah_chen_full.json                         ← Adapted from Marcus Chen synthetic data
│       └── TRAVEL_DATA_CUBE_README.md                   ← Source data documentation
└── scripts/
    └── create_veyant_backlog_issues.sh                  ← gh CLI script to create all 22 GitHub issues
```

## Critical path order

1. **Foundation (F7.0)** — provision Azure + Databricks + Unity Catalog
2. **Trip history (F7.1)** — create Delta tables, ingest Sarah Chen seed data
3. **Inference (F7.2)** — wire up the InferenceClient against Mosaic AI
4. **Extraction (F7.3)** — preference extraction service end-to-end
5. **Persistence (F7.4)** — Delta + Lakebase for serving
6. **Scoring (F7.5)** — replace mock get_preference_score with derived preferences
7. **Suggestions (F7.6)** — end-to-end demo scenario

## Key design decisions (already made)

- **Inference backend:** Databricks Mosaic AI Model Serving, Llama 3 70B Instruct, pay-per-token
- **OLTP plane:** Lakebase (Databricks serverless Postgres, formerly Neon) for fast preference reads
- **Analytical plane:** Delta Lake on Unity Catalog as source of truth
- **API layer:** Azure Functions (Python) fronted by Azure API Management
- **IaC:** Bicep (default), with Terraform as fallback if the team prefers
- **Tenancy:** Single-tenant deployment with multi-tenant data model (every record carries `tenant_id`)
- **Persona:** Sarah Chen is the demo persona, adapted from the Marcus Chen synthetic Road Warrior data

## Open questions still to resolve

- Region selection (recommendation: East US 2)
- Subscription strategy (recommendation: single subscription, two resource groups)
- Source control for Databricks notebooks (recommendation: GitHub via Databricks Repos)

These are documented in Section 14 of the architecture doc.

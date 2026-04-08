-- ============================================================================
-- Veyant: Preference Profiles + Derivation Runs Tables
-- Implements US 7.4.1 — Delta + Lakebase preference profile schemas
-- Reference: docs/Veyant_Preference_Engine_Azure_Architecture.md, Sections 6.3, 6.4
-- ============================================================================

-- Preference profiles — derived preference objects
-- Multiple profiles per traveler stored as derivation history
-- is_active flag identifies the current canonical profile
-- This is the canonical Delta record. Lakebase mirror is created separately.

CREATE TABLE IF NOT EXISTS veyant_dev.travel_data.preference_profiles (
  tenant_id STRING NOT NULL,
  traveler_id STRING NOT NULL,
  profile_id STRING NOT NULL COMMENT 'UUID per derivation',
  is_active BOOLEAN NOT NULL,
  derived_at TIMESTAMP NOT NULL,
  trip_window_days INT COMMENT 'How many days of history were analyzed',
  trip_record_count INT COMMENT 'Number of trips in the analysis window',
  model_used STRING COMMENT 'e.g. databricks-meta-llama-3-70b-instruct',
  schema_version STRING COMMENT 'Schema version of the profile_json structure',
  profile_json STRING COMMENT 'Structured preference object as JSON',
  confidence_overall DECIMAL(3,2) COMMENT 'Aggregate confidence score 0.00 to 1.00',
  derivation_run_id STRING COMMENT 'FK to derivation_runs table'
)
USING DELTA
PARTITIONED BY (tenant_id)
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true'
)
COMMENT 'Derived preference profiles. Source of truth in Delta. Lakebase serves the active profile for fast reads on the request path.';

-- Derivation runs — append-only audit table for preference extraction jobs
-- Used for cost tracking, debugging, and compliance audit logs

CREATE TABLE IF NOT EXISTS veyant_dev.travel_data.derivation_runs (
  run_id STRING NOT NULL,
  tenant_id STRING NOT NULL,
  triggered_by STRING COMMENT 'user | schedule | data_change',
  run_started_at TIMESTAMP NOT NULL,
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
PARTITIONED BY (tenant_id)
COMMENT 'Append-only audit log of preference derivation runs.';

-- Lakebase mirror table DDL (run against the Lakebase Postgres instance, NOT Databricks SQL)
-- Schema kept in this file for visibility but executed via Lakebase connection
--
-- CREATE TABLE preference_profiles_active (
--   tenant_id TEXT NOT NULL,
--   traveler_id TEXT NOT NULL,
--   profile_id TEXT NOT NULL,
--   derived_at TIMESTAMPTZ NOT NULL,
--   model_used TEXT,
--   schema_version TEXT,
--   profile_json JSONB NOT NULL,
--   confidence_overall NUMERIC(3,2),
--   PRIMARY KEY (tenant_id, traveler_id)
-- );
--
-- CREATE INDEX idx_preference_profiles_traveler ON preference_profiles_active(traveler_id);
-- CREATE INDEX idx_preference_profiles_jsonb ON preference_profiles_active USING gin (profile_json);

# Veyant — AI Travel Orchestration (MCP Reference Implementation)

A proof-of-concept MCP server showing how an AI agent can reason across corporate travel policy, traveler preferences, and supplier availability simultaneously — without hallucinating rules or ignoring context.

Built to run locally against Claude Desktop. No deployment required.

---

## How This Was Built

This project was built collaboratively with Claude Code and Claude Desktop through iterative prompting and requirements definition. The architecture, tool schemas, policy engine logic, and TypeScript implementation were generated and refined through that process — not designed explicitly upfront.

My contributions were the product requirements: the "three cubes" data model concept, the demo scenario, the traveler and policy parameters, and the decision to separate policy enforcement from LLM reasoning. The vision for an ML model in production came from evaluating what the rule engine was actually doing and recognizing its limitations as a long-term approach.

This is the workflow I believe matters for AI product development — knowing what to build and why, directing the iteration, and recognizing when the output is right.

---

## What This Demonstrates

Corporate travel management is a multi-constraint problem: every booking must satisfy the traveler's preferences, comply with company policy, and account for loyalty status. Today this requires a human travel agent or a traveler who has memorized the rules.

This project shows a different model: an AI that has structured access to all three data sources and can surface the right recommendation in seconds — including edge cases like loyalty upgrades that change whether a cabin class is a policy violation.

---

## Architecture

```
Claude Desktop
     │
     │  MCP (stdio)
     ▼
Veyant MCP Server (Node.js / TypeScript)
     │
     ├── search_travel_options    ← Supplier Catalog
     ├── get_preference_score     ← Traveler Preference Profile
     └── check_policy_compliance  ← Corporate Policy Engine
```

Three conceptual layers — called "cubes" in the Veyant model:

| Cube | What it contains |
|------|-----------------|
| **My Travel Cube** | Traveler profile, loyalty accounts, seat/carrier preferences |
| **Corporate Policy Cube** | Approved cabins, rate caps, market exceptions, approval thresholds |
| **Supplier Catalog Cube** | Available flights and hotels with rates, change fees, upgrade eligibility |

The policy compliance tool is a structured, auditable system — not an LLM prompt. In this demo it runs as a deterministic TypeScript rule engine. In production it would be replaced by a trained ML model built on historical booking and approval data, exposing the same tool interface. Claude reasons over its outputs either way.

---

## Tools

### `search_travel_options`
Query the supplier catalog by type, route, or city.

```json
{
  "type": "flight",
  "origin": "LHR",
  "destination": "JFK"
}
```

Returns available `FlightOption` or `HotelOption` objects from the catalog.

---

### `get_preference_score`
Score any travel option against the traveler's stored preference profile.

```json
{
  "option": { "carrier": "Delta", "cabin": "business", ... }
}
```

Returns a 0–100 score with a breakdown of contributing factors (carrier preference, seat type, non-stop bonus, change fee, upgrade eligibility).

---

### `check_policy_compliance`
Validate a proposed trip against corporate policy rules.

```json
{
  "proposal": {
    "segments": [
      { "type": "flight", "supplier": "Delta", "cabin": "business", "rate": 0, "upgradeApplied": true }
    ],
    "totalAdditionalCost": 0,
    "market": "New York"
  }
}
```

Returns overall status (`compliant`, `exception_applied`, `requires_approval`, or `violation`) with per-rule pass/fail detail.

**Demo rule engine logic (stand-in for production ML model):**
- Hotel rates checked against default cap ($350/night) with market overrides (London/NYC/SF: $420)
- Flight cabins validated against approved list (economy, premium economy)
- Loyalty upgrades to business/first recognized as compliant when `upgradeApplied: true`
- Total cost checked against auto-approval threshold ($2,000)

**Production vision:** Replace the rule engine with a trained classifier (e.g., gradient boosted trees) built on real booking history, expense approvals, and policy exceptions. Most organizations' actual policy lives in years of approval decisions — not a rulebook. A trained model captures that implicit knowledge, handles edge cases automatically, and improves with retraining rather than manual rule updates.

---

## Demo Scenario

**Traveler:** Sarah Chen, Acme Corp, Boston-based
**Situation:** London client meeting extended by one day — she needs a flight change and hotel extension.

**Her profile:**
- SkyTeam Platinum Elite (84,200 miles), Delta Platinum
- Marriott Bonvoy Platinum, BA Executive Club Gold
- Preferences: window seat, non-stop, British Airways or Delta

**The recommendation Claude reaches:**

| Segment | Option | Score | Policy |
|---------|--------|-------|--------|
| London hotel extension | Marriott Park Lane, $385/night | 100/100 | Exception applied (London market) |
| LHR → JFK | Delta DL401, Business (25k mile upgrade) | 100/100 | Compliant (loyalty upgrade) |
| LHR → BOS | BA 178, Premium Economy, $0 change fee | 95/100 | Compliant |

The interesting case: Delta's business cabin normally violates policy (only economy/premium economy approved), but the loyalty upgrade makes it compliant. The compliance tool handles this distinction explicitly — Claude receives a structured verdict, it doesn't infer policy from a prompt.

---

## Running Locally

**Prerequisites:** Node.js 18+, Claude Desktop

```bash
git clone https://github.com/skisushi/seth_portfolio
cd veyant-demo
npm install
npm run build
```

Add to your Claude Desktop MCP config (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "veyant": {
      "command": "node",
      "args": ["C:/path/to/veyant-demo/dist/mcp/server.js"]
    }
  }
}
```

Restart Claude Desktop. The three Veyant tools will be available in any conversation.

**Test the policy engine directly:**
```bash
npm test
```

---

## Project Structure

```
src/
  domain/
    types.ts          # All TypeScript interfaces (traveler, policy, catalog, proposals)
    policy-engine.ts  # Deterministic policy evaluation logic
    mock-data.ts      # Sarah Chen's profile, Acme Corp policy, flight/hotel catalog
  mcp/
    tools.ts          # Tool implementations
    server.ts         # MCP server entry point, tool schemas, resource definitions
tests/
  policy-engine.test.ts  # 10 tests covering all rule paths and edge cases
```

---

## What's Hardcoded (By Design)

This is a demo, not a production system. All data is mock:
- One traveler profile (Sarah Chen)
- One corporate policy (Acme Corp)
- Three flights, two hotels

The architecture mirrors what a production implementation would look like. Two substitutions would take it there:

1. **Catalog and traveler data** — swap mock JSON for live API calls to a travel management system (Concur, Egencia, etc.)
2. **Policy engine** — swap the TypeScript rule engine for a trained ML model built by a data science team on real booking and approval history. The tool interface (`check_policy_compliance`) stays identical; only the implementation behind it changes.

---

## Tech Stack

- TypeScript / Node.js (ES modules)
- `@modelcontextprotocol/sdk` — MCP server implementation
- Vitest — test runner
- No external API calls, no database, no auth

---

## Intended Deployment

Azure Container Apps with Azure API Management as the MCP gateway — enabling the same tools to be called by any MCP-compatible AI client, not just Claude Desktop.

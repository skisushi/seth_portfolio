# CLAUDE.md - Veyant Demo Project

Drop this file in the root of your veyant-demo project folder.
Claude Code reads this automatically at the start of every session.

---

## What This Project Is

This is an interactive proof-of-concept demo for Veyant, an AI travel orchestration
concept. The demo is designed to show potential partners and investors how an AI system
can detect a calendar change and automatically recommend a travel itinerary update for
a corporate traveler, pulling context from their preferences, loyalty status, and
corporate travel policy.

This is a scripted demo, not a production application. All data is hardcoded mock JSON.
There are no real API calls. The goal is a polished, believable demo that tells one
story really well.

---

## The One Demo Scenario

Traveler Sarah Chen has her London client meeting extended by one day.
The system detects the calendar change, analyzes her context (loyalty status,
preferences, corporate policy), surfaces a flight change and hotel extension recommendation,
and she approves it in under 90 seconds.

That's the whole story. Do not add other scenarios without explicit instruction.

---

## Architecture Concepts (for context only, not to build)

The demo represents three conceptual layers called "cubes":

- My Travel Cube: traveler profile, preferences, loyalty credentials, history
- Corporate Policy Cube: company travel policies, preferred suppliers, approval rules
- Supplier Catalog Cube: stubbed flight/hotel availability and pricing

The AI has two components shown in the demo feed:
- BRAIN: the context and intelligence layer (reads the three cubes, analyzes)
- BRIDGE: the execution layer (searches suppliers, matches options, confirms)

These labels appear as colored badges in the left panel notification feed.

---

## Tech Stack Decisions (do not change without asking)

- React with Tailwind CSS
- Single file preferred (App.jsx) or minimal file count
- No routing, no backend, no external API calls
- Dark mode UI, enterprise SaaS aesthetic
- DM Sans or Sora from Google Fonts (not Inter)

---

## Brand Colors

- Veyant Blue: #2563EB
- Success Green: #10B981
- Warning Yellow: #F59E0B
- App shell: #0F172A
- Card background: #1E293B
- Primary text: #F8FAFC
- Secondary text: #94A3B8

---

## Scope Rules

Things we are building:
- The 6-step demo flow triggered by a single button
- Left panel: notification/processing feed
- Right panel: trip cockpit with recommendation card and approve button
- Confirmation state after approval

Things that go in the parking lot (do not build without explicit instruction):
- Mobile layout
- Multiple scenarios
- Error states
- Settings or profile screens
- Real API integrations
- Authentication

---

## Design Philosophy

The system should anticipate and resolve travel problems proactively, not reactively. The demo UI copy and processing step language should reflect this: the Brain is not responding to a request, it is getting ahead of a problem the traveler hasn't had to think about yet.

The Data Cube concept puts control in the traveler's hands, not the supplier's and not the corporation's. When the demo shows policy compliance or loyalty benefits being applied, it should feel like the system is working for Sarah, not auditing her.

## Operating Principles

- Build good enough, not perfect
- Fail fast and pivot
- Keep file count low
- Prioritize demo reliability over code elegance
- When in doubt, ask before adding scope

---

## Key Mock Data Reference

Traveler: Sarah Chen, Acme Corp
Loyalty: SkyTeam Platinum Elite, Marriott Bonvoy Platinum (84,200 points)
Trip: Boston to London Heathrow, Sept 14-18 (extended from Sept 17)
Hotel: Marriott London Park Lane, $385/night
Recommended flight change: BA 178 LHR-BOS Wednesday 11:10am, $0 change fee
Hotel extension: 1 extra night, 12,500 points

---

## Session Startup Checklist

When starting a new Claude Code session on this project:
1. Read this file first
2. Run the app and verify the demo plays through all 6 steps
3. Check that both panels render correctly
4. Then make whatever changes are needed for this session

If something is broken from a previous session, fix it before adding anything new.

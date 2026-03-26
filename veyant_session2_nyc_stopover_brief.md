# Veyant Demo - Session 2 Build Brief
## Add Scenario 2: Sarah Requests NYC Stopover via Chat

---

## Context

We already have a working demo with Scenario 1 (calendar-triggered London extension).
This session adds Scenario 2: a traveler-initiated chat request to add a NYC stopover
on the way home from London, with an overnight stay and client meeting.

Do not break or modify Scenario 1. Add Scenario 2 as a second selectable demo flow.

---

## What's New in This Session

Add a scenario selector at the top of the demo (two buttons or tabs):
- "Scenario 1: Calendar Alert" (existing)
- "Scenario 2: Chat Request" (new)

Selecting a scenario resets the demo state and runs that flow when "Run Demo" is clicked.

---

## Scenario 2 Demo Flow: Chat-Initiated NYC Stopover

This scenario starts with Sarah typing a natural language request in the chat panel,
rather than a calendar event arriving. The tone is conversational. She's in London,
her trip home is tomorrow, and a client issue has come up that needs an in-person stop.

STEP 1 - Sarah types in chat (0-1 second, appears as a user message bubble)
  Sarah: "Please extend my London trip one day for extra meetings, and add a NYC stop
  to meet with a client with an escalated issue. Please get me same room, best seats
  and upgrades."

STEP 2 - Veyant acknowledges instantly (1-2 seconds)
  [VEYANT] On it. Reviewing your full trip context now...

STEP 3 - Brain processes (2-8 seconds, steps appear one by one)
  [BRAIN] Parsing request: London extension + NYC stopover + preference preservation
  [BRAIN] Checking Marriott London Park Lane availability - Wednesday Sept 18 open, same room confirmed
  [BRAIN] Corporate rate $385/night - within Acme Corp London exception policy
  [BRAIN] Checking SkyTeam Platinum status - business class upgrade on LHR-EWR eligible with 25K miles
  [BRAIN] Searching UA456 LHR-EWR Wednesday Sept 18 10:15am - seats available
  [BRAIN] NYC overnight: checking Marriott Midtown - corporate rate $289/night, within policy
  [BRAIN] Thursday return JFK-BOS: checking availability - BOS preferred, non-stop confirmed
  [BRAIN] Total cost impact calculated - within Acme Corp approval threshold, no manager approval needed

STEP 4 - Bridge executes (8-14 seconds)
  [BRIDGE] Extending Marriott London Park Lane - Wednesday confirmed, same room
  [BRIDGE] Booking UA456 LHR-EWR Wednesday 10:15am - upgrade applied with 25K SkyTeam miles
  [BRIDGE] Booking Marriott New York Midtown - Thursday Sept 19, corporate rate applied
  [BRIDGE] Booking AA87 JFK-BOS Thursday Sept 19 6:30pm - window seat confirmed
  [BRIDGE] Lounge access confirmed at LHR Terminal 2 - SkyTeam Platinum benefit

STEP 5 - Trip Cockpit updates to show full modified itinerary
  Right panel header changes to: "Modified Itinerary - Pending Your Approval"

  ORIGINAL (crossed out):
  - BA 178 | LHR-BOS | Tuesday Sept 17 | 11:10am
  - Marriott London Park Lane | Check-out: Tuesday Sept 17

  NEW ITINERARY (shown as updated cards):

  Card 1 - London Extension:
  - Marriott London Park Lane | Extended to Wednesday Sept 18
    Same room confirmed | Corporate rate $385 | Policy: COMPLIANT

  Card 2 - London to New York:
  - UA 456 | LHR-EWR | Wednesday Sept 18 | 10:15am
    Business Class upgrade: 25,000 SkyTeam miles (balance: 59,200 remaining)
    Seat: 3A Window | LHR T2 Lounge access included (Platinum benefit)

  Card 3 - NYC Overnight:
  - Marriott New York Midtown | Thursday Sept 19
    Corporate rate: $289/night | Policy: COMPLIANT

  Card 4 - New York to Boston:
  - AA 87 | JFK-BOS | Thursday Sept 19 | 6:30pm
    Seat: 12A Window | No change fee

  COST SUMMARY BOX:
  - London hotel extra night: $385 (policy approved)
  - LHR-EWR fare difference: $0 (miles upgrade)
  - NYC hotel: $289 (within policy)
  - JFK-BOS: $187
  - Total additional: $861
  - Status: APPROVED - within Acme Corp single-trip threshold

STEP 6 - Veyant chat response appears
  [VEYANT] Done. Review your modified itinerary in the Travel Cockpit.
  Let me know if that works or if you need anything changed.

STEP 7 - Sarah follows up (appears after a short pause, simulating her typing)
  Sarah: "Perfect. Can you add a lounge pass and prepay my overweight bag on the way home?"

STEP 8 - Veyant responds
  [VEYANT] Done. Lounge pass added at JFK Terminal 8 and overweight bag prepaid for AA87.
  Your SkyTeam Platinum status earned you a discount on both - saved you $47.

STEP 9 - Approve button activates
  Green "Approve All Changes" button appears in Trip Cockpit.
  Secondary link: "Make a change"

STEP 10 - Confirmed state on click
  [VEYANT] All changes confirmed. Calendar updated. Safe travels, Sarah.
  Right panel shows all four cards with green confirmed badges.
  Summary line: "4 changes completed in 90 seconds. Estimated manual time: 45+ minutes."

---

## Key Differences from Scenario 1 to Get Right

Scenario 1 starts with a system-detected calendar event (proactive).
Scenario 2 starts with Sarah typing a request (reactive to her input, but still intelligent).
The left panel in Scenario 2 should look more like a chat conversation with message bubbles,
not just a notification feed. Sarah's messages appear on the right side of the panel,
Veyant responses on the left. Brain/Bridge processing steps appear as a distinct
processing thread between turns, slightly indented or visually separated.

---

## Mock Data Additions

New flight: UA 456 | LHR-EWR | Wednesday Sept 18 | 10:15am | Business Class
NYC Hotel: Marriott New York Midtown | $289/night | Corporate rate
Return flight: AA 87 | JFK-BOS | Thursday Sept 19 | 6:30pm | $187
Miles balance after upgrade: 84,200 - 25,000 = 59,200 SkyTeam miles remaining
Lounge: JFK Terminal 8 Admirals Club, discounted rate with Platinum status
Overweight bag: prepaid on AA87, Platinum discount applied
Total savings from status: $47

---

## Scope for This Session Only

Build the scenario selector and Scenario 2 flow.
Do not modify Scenario 1 logic.
Do not add a third scenario.
Do not add settings, profile editing, or any other screens.
Keep the same visual design, colors, and fonts as Scenario 1.

---

## Definition of Done

- Scenario selector works and resets state correctly
- Scenario 2 plays through all 10 steps when Run Demo is clicked
- Chat panel shows proper conversation bubble layout for Scenario 2
- Trip Cockpit shows all 4 modified trip cards with cost summary
- Follow-up exchange (lounge + bag) plays through
- Approve button triggers confirmed state with all 4 green badges
- Scenario 1 still works correctly after these changes

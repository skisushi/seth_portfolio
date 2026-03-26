# Veyant Demo — Loom Recording Script

**Target length:** 2.5–3 minutes
**Format:** Screen recording of Claude Desktop with voiceover
**Audience:** Portfolio reviewers, potential partners, investors

---

## Before You Hit Record

- Open Claude Desktop, new conversation
- Have the Veyant MCP server running (verify tools are available)
- Close other apps, clean desktop
- Use a clean Claude Desktop window — no previous chat history visible

---

## Section 1 — Setup (0:00–0:25)

**What's on screen:** Claude Desktop, empty chat

**Say:**
> "This is Veyant — a proof of concept for AI-driven corporate travel orchestration.
> The idea is simple: a business traveler's meeting gets extended, and instead of
> them scrambling to rebook, the AI handles it — checking their preferences, their
> loyalty status, and their company's travel policy simultaneously.
>
> I've built an MCP server that gives Claude structured access to all three of those
> data sources as callable tools. Let me show you how it works."

---

## Section 2 — Introduce the Traveler (0:25–0:50)

**What's on screen:** Type and send this prompt:

> "Sarah Chen's London client meeting has been extended by one day — she now needs to
> fly home Wednesday September 18th instead of Tuesday. She's currently booked on
> BA178. Find her the best options for the flight change and a hotel extension, check
> them against Acme Corp policy, and give me a recommendation."

**Say (while Claude is thinking):**
> "Sarah is a Platinum Elite traveler — SkyTeam, Marriott Bonvoy, BA Executive Club.
> Acme Corp has specific rules: economy or premium economy only for transatlantic
> flights, hotel rate caps with city exceptions. Watch how Claude handles all of that
> without me spelling any of it out."

---

## Section 3 — Tool Calls Fire (0:50–1:30)

**What's on screen:** Claude making tool calls — you should see the tool use indicators for:
1. `search_travel_options` (flights LHR→BOS)
2. `get_preference_score` (scoring BA178)
3. `search_travel_options` (hotels London)
4. `get_preference_score` (scoring Marriott Park Lane)
5. `check_policy_compliance` (full proposal)

**Say:**
> "Three tools — search, score, and comply. Claude is calling them in sequence,
> building up a picture of the best option before surfacing a recommendation.
> This isn't Claude guessing at policy from a prompt — the compliance check is a
> structured call to a dedicated engine that returns an explicit pass or fail."

---

## Section 4 — The Recommendation (1:30–2:00)

**What's on screen:** Claude's output showing the recommendation card, something like:

```
Flight: BA 178 — LHR → BOS
Departure: Wed Sept 18, 11:10 AM
Cabin: Premium Economy
Change Fee: $0 (loyalty status)
Preference Score: 95/100
Policy: ✅ Compliant

Hotel: Marriott London Park Lane
Extension: 1 night — $385
Loyalty: 12,500 Marriott points applied
Policy: ✅ Exception applied (London market rate)
```

**Say:**
> "BA 178 — premium economy, zero change fee because of her loyalty status,
> 95 out of 100 on her preference profile. The hotel extension triggers a market
> exception — London is above the default $350 cap, but Acme Corp has a $420
> override for that city. The policy engine catches that automatically."

---

## Section 5 — The Interesting Case (2:00–2:35)

**What's on screen:** Type and send:

> "What if she wanted to connect through New York instead — is there a better
> routing for her?"

Wait for Claude to surface DL401 (Delta, LHR→JFK, business class, loyalty upgrade).

**Say:**
> "Here's where it gets interesting. Delta has a business class seat available —
> and it scores a perfect 100 on Sarah's preferences. Delta is her top carrier,
> seat 3A is a window, and the upgrade costs her 25,000 miles, not dollars.
>
> But business class normally violates Acme Corp policy — only economy and premium
> economy are approved. The question is: does a loyalty upgrade change that?"

**What's on screen:** Claude calling `check_policy_compliance` with `upgradeApplied: true`

> "It does. The compliance tool distinguishes between a fare upgrade and a loyalty
> upgrade. Same cabin — different verdict. That's the kind of nuance that gets
> lost when you try to put policy into a prompt."

---

## Section 6 — Wrap (2:35–3:00)

**What's on screen:** Pull back to show the full conversation thread

**Say:**
> "Three tools, one structured server, and Claude is acting as a travel agent —
> not just a search engine. The policy engine in this demo is a rule-based stand-in.
> In production, that would be replaced by an ML model trained on real booking and
> approval history — capturing the implicit policy that lives in years of decisions,
> not just the written rulebook.
>
> The MCP interface stays identical either way. Any AI client that speaks the
> protocol can call these tools — this isn't Claude-specific."

**Pause. Let the screen sit for 2 seconds.**

> "Built with Claude Code. Links in the description."

**Stop recording.**

---

## Tips for Recording

- Slow down when tool calls are firing — let viewers see them
- Don't rush the recommendation output — pause so it's readable
- If Claude adds extra narrative you don't want, you can trim in post or re-run the prompt
- Record in a single take if possible — cuts make it look less like a live demo
- Loom's trim tool is enough for cleanup, no need for heavy editing

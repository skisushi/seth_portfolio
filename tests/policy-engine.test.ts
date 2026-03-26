import { describe, it, expect } from 'vitest';
import { evaluate } from '../src/domain/policy-engine.js';
import {
  acmeCorpPolicy,
  scenario1Proposal,
  scenario2Proposal,
} from '../src/domain/mock-data.js';
import type { TripChangeProposal } from '../src/domain/types.js';

// ─── Test 1: Hotel rate under default limit passes ────────────────────────────
it('hotel rate under default limit passes', () => {
  const proposal: TripChangeProposal = {
    segments: [{ type: 'hotel', supplier: 'Marriott', rate: 289, city: 'New York' }],
    totalAdditionalCost: 289,
    market: 'New York',
  };
  const result = evaluate(acmeCorpPolicy, proposal);
  const hotelRule = result.ruleResults.find((r) => r.ruleId === 'rule-hotel-nightly-rate');
  expect(hotelRule?.status).toBe('pass');
});

// ─── Test 2: Hotel rate over default limit fails (no exception) ───────────────
it('hotel rate over default limit fails when no exception exists', () => {
  const proposal: TripChangeProposal = {
    segments: [{ type: 'hotel', supplier: 'Some Hotel', rate: 400, city: 'Boston' }],
    totalAdditionalCost: 400,
    market: 'Boston',
  };
  const result = evaluate(acmeCorpPolicy, proposal);
  const hotelRule = result.ruleResults.find((r) => r.ruleId === 'rule-hotel-nightly-rate');
  expect(hotelRule?.status).toBe('fail');
  expect(result.overallStatus).toBe('violation');
});

// ─── Test 3: Hotel rate over default but market exception applies ─────────────
it('hotel rate over default but London exception applies gives exception status', () => {
  const proposal: TripChangeProposal = {
    segments: [{ type: 'hotel', supplier: 'Marriott', rate: 385, city: 'London' }],
    totalAdditionalCost: 385,
    market: 'London',
  };
  const result = evaluate(acmeCorpPolicy, proposal);
  const hotelRule = result.ruleResults.find((r) => r.ruleId === 'rule-hotel-nightly-rate');
  expect(hotelRule?.status).toBe('exception');
  expect(result.overallStatus).toBe('exception_applied');
});

// ─── Test 4: Hotel rate over even the exception limit fails ──────────────────
it('hotel rate over even the London exception limit fails', () => {
  const proposal: TripChangeProposal = {
    segments: [{ type: 'hotel', supplier: 'Luxury Hotel', rate: 450, city: 'London' }],
    totalAdditionalCost: 450,
    market: 'London',
  };
  const result = evaluate(acmeCorpPolicy, proposal);
  const hotelRule = result.ruleResults.find((r) => r.ruleId === 'rule-hotel-nightly-rate');
  expect(hotelRule?.status).toBe('fail');
  expect(result.overallStatus).toBe('violation');
});

// ─── Test 5: Total cost under auto-approval threshold ────────────────────────
it('total cost under auto-approval threshold requires no approval', () => {
  const proposal: TripChangeProposal = {
    segments: [{ type: 'hotel', supplier: 'Marriott', rate: 289, city: 'New York' }],
    totalAdditionalCost: 861,
    market: 'New York',
  };
  const result = evaluate(acmeCorpPolicy, proposal);
  expect(result.approvalsNeeded).toHaveLength(0);
});

// ─── Test 6: Total cost over auto-approval threshold ─────────────────────────
it('total cost over auto-approval threshold requires approval', () => {
  const proposal: TripChangeProposal = {
    segments: [{ type: 'hotel', supplier: 'Marriott', rate: 289, city: 'New York' }],
    totalAdditionalCost: 3000,
    market: 'New York',
  };
  const result = evaluate(acmeCorpPolicy, proposal);
  expect(result.approvalsNeeded.length).toBeGreaterThan(0);
  expect(result.overallStatus).toBe('requires_approval');
});

// ─── Test 7: Scenario 1 full evaluation (London extension) ───────────────────
it('Scenario 1: London extension — exception applied, auto-approved', () => {
  const result = evaluate(acmeCorpPolicy, scenario1Proposal);
  expect(result.overallStatus).toBe('exception_applied');
  expect(result.approvalsNeeded).toHaveLength(0);
  const hotelRule = result.ruleResults.find((r) => r.ruleId === 'rule-hotel-nightly-rate');
  expect(hotelRule?.status).toBe('exception');
});

// ─── Test 8: Scenario 2 full evaluation (NYC stopover) ───────────────────────
it('Scenario 2: NYC stopover — exception applied, auto-approved, $861 total', () => {
  const result = evaluate(acmeCorpPolicy, scenario2Proposal);
  // London hotel triggers exception, NYC hotel passes
  const hotelResults = result.ruleResults.filter((r) => r.ruleId === 'rule-hotel-nightly-rate');
  const londonResult = hotelResults.find((r) => r.detail.includes('London') || r.detail.includes('385'));
  const nycResult = hotelResults.find((r) => r.detail.includes('289'));
  expect(londonResult?.status).toBe('exception');
  expect(nycResult?.status).toBe('pass');
  // $861 is under the $2,000 threshold
  expect(result.approvalsNeeded).toHaveLength(0);
  expect(result.overallStatus).toBe('exception_applied');
});

// ─── Test 9: Non-preferred supplier is noted but not blocking ────────────────
it('non-preferred supplier hotel still passes policy rules if rate is compliant', () => {
  const proposal: TripChangeProposal = {
    segments: [{ type: 'hotel', supplier: 'Hilton', rate: 290, city: 'Chicago' }],
    totalAdditionalCost: 290,
    market: 'Chicago',
  };
  const result = evaluate(acmeCorpPolicy, proposal);
  const hotelRule = result.ruleResults.find((r) => r.ruleId === 'rule-hotel-nightly-rate');
  expect(hotelRule?.status).toBe('pass');
  expect(result.overallStatus).toBe('compliant');
});

// ─── Test 10: Empty proposal ─────────────────────────────────────────────────
it('empty proposal with $0 cost is compliant, no approvals needed', () => {
  const proposal: TripChangeProposal = {
    segments: [],
    totalAdditionalCost: 0,
    market: 'Boston',
  };
  const result = evaluate(acmeCorpPolicy, proposal);
  expect(result.overallStatus).toBe('compliant');
  expect(result.approvalsNeeded).toHaveLength(0);
  expect(result.ruleResults.every((r) => r.status === 'pass')).toBe(true);
});

import type {
  CorporatePolicy,
  PolicyRule,
  PolicyException,
  TripChangeProposal,
  ProposedSegment,
  PolicyComplianceResult,
  PolicyRuleResult,
} from './types.js';

function getSegmentValue(
  rule: PolicyRule,
  segments: ProposedSegment[]
): { value: number | string | null; segment: ProposedSegment | null } {
  for (const segment of segments) {
    if (rule.field === 'hotel_nightly_rate' && segment.type === 'hotel') {
      return { value: segment.rate, segment };
    }
    if (rule.field === 'flight_cabin' && segment.type === 'flight' && segment.cabin) {
      return { value: segment.cabin, segment };
    }
  }
  return { value: null, segment: null };
}

function compareValue(
  actual: number | string,
  operator: PolicyRule['operator'],
  ruleValue: number | string | string[]
): boolean {
  if (typeof actual === 'number' && typeof ruleValue === 'number') {
    if (operator === 'lt')  return actual < ruleValue;
    if (operator === 'lte') return actual <= ruleValue;
    if (operator === 'gt')  return actual > ruleValue;
    if (operator === 'gte') return actual >= ruleValue;
    if (operator === 'eq')  return actual === ruleValue;
  }
  if (operator === 'in' && Array.isArray(ruleValue)) {
    return ruleValue.includes(actual as string);
  }
  if (operator === 'eq') return actual === ruleValue;
  return false;
}

function findException(
  exceptions: PolicyException[],
  field: string,
  market: string
): PolicyException | undefined {
  return exceptions.find(
    (e) => e.field === field && e.market.toLowerCase() === market.toLowerCase()
  );
}

function evaluateRule(
  rule: PolicyRule,
  proposal: TripChangeProposal,
  exceptions: PolicyException[]
): PolicyRuleResult[] {
  const results: PolicyRuleResult[] = [];

  if (rule.field === 'hotel_nightly_rate') {
    // Evaluate each hotel segment separately
    for (const segment of proposal.segments) {
      if (segment.type !== 'hotel') continue;

      const rate = segment.rate;
      const passes = compareValue(rate, rule.operator, rule.value);

      if (passes) {
        results.push({
          ruleId: rule.id,
          description: rule.description,
          status: 'pass',
          detail: `${segment.supplier} hotel rate $${rate}/night is within the $${rule.value}/night limit`,
        });
      } else {
        const market = segment.city ?? proposal.market;
        const exception = findException(exceptions, rule.field, market);

        if (exception && rate <= exception.overrideValue) {
          results.push({
            ruleId: rule.id,
            description: rule.description,
            status: 'exception',
            detail: `${segment.supplier} hotel rate $${rate}/night exceeds default $${rule.value} but is within ${market} exception limit of $${exception.overrideValue}`,
          });
        } else {
          const limit = exception ? exception.overrideValue : (rule.value as number);
          results.push({
            ruleId: rule.id,
            description: rule.description,
            status: 'fail',
            detail: `${segment.supplier} hotel rate $${rate}/night exceeds the ${market} limit of $${limit}/night`,
          });
        }
      }
    }

    if (results.length === 0) {
      results.push({
        ruleId: rule.id,
        description: rule.description,
        status: 'pass',
        detail: 'No hotel segments in proposal',
      });
    }
  } else if (rule.field === 'flight_cabin') {
    for (const segment of proposal.segments) {
      if (segment.type !== 'flight' || !segment.cabin) continue;

      // Status/miles upgrades are loyalty benefits — policy evaluates the base purchased fare, not the upgraded cabin
      if (segment.upgradeApplied) {
        results.push({
          ruleId: rule.id,
          description: rule.description,
          status: 'pass',
          detail: `${segment.supplier} cabin upgraded via loyalty status/miles — base fare is policy compliant`,
        });
        continue;
      }

      const passes = compareValue(segment.cabin, rule.operator, rule.value);
      results.push({
        ruleId: rule.id,
        description: rule.description,
        status: passes ? 'pass' : 'fail',
        detail: passes
          ? `${segment.supplier} cabin '${segment.cabin}' is within policy`
          : `${segment.supplier} cabin '${segment.cabin}' is not within approved cabins: ${(rule.value as string[]).join(', ')}`,
      });
    }

    if (results.length === 0) {
      results.push({
        ruleId: rule.id,
        description: rule.description,
        status: 'pass',
        detail: 'No flight segments in proposal',
      });
    }
  }

  return results;
}

export function evaluate(
  policy: CorporatePolicy,
  proposal: TripChangeProposal
): PolicyComplianceResult {
  const ruleResults: PolicyRuleResult[] = [];

  for (const rule of policy.rules) {
    const results = evaluateRule(rule, proposal, policy.exceptions);
    ruleResults.push(...results);
  }

  // Check approval thresholds
  const approvalsNeeded: string[] = [];
  for (const threshold of policy.approvalThresholds) {
    if (!threshold.autoApprove || proposal.totalAdditionalCost > threshold.maxAmount) {
      approvalsNeeded.push(
        `Manager approval required — total additional cost $${proposal.totalAdditionalCost} exceeds auto-approve threshold of $${threshold.maxAmount}`
      );
    }
  }

  // Derive overall status
  const hasViolation = ruleResults.some((r) => r.status === 'fail');
  const hasException = ruleResults.some((r) => r.status === 'exception');
  const needsApproval = approvalsNeeded.length > 0;

  let overallStatus: PolicyComplianceResult['overallStatus'];

  if (hasViolation) {
    overallStatus = 'violation';
  } else if (needsApproval) {
    overallStatus = 'requires_approval';
  } else if (hasException) {
    overallStatus = 'exception_applied';
  } else {
    overallStatus = 'compliant';
  }

  return { overallStatus, ruleResults, approvalsNeeded };
}

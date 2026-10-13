---
title: 'From Trajectories to Evidence: Auditable Experimental Records for Industrial Research Agents (Kuaishou, 2026)'
url: https://arxiv.org/pdf/2608.05235
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (abstract, intro, method sections on verification and qualification, results on trajectories and record audit, limitations)
relevance: high
grade: C/fair
description: Kuaishou paper (arXiv Aug 2026, AAAI 2027) on turning a research agent's experiment trajectory into a registry of qualified claims with provenance; finds the last round often worse than an earlier best
---
# From Trajectories to Evidence: Auditable Experimental Records for Industrial Research Agents (Kuaishou, 2026)

Why: the one write-up found of an LLM agent loop that keeps a structured results
registry and decides which runs count as evidence; for what our run records lack.

## Assessment

- Evidence: C. One company's recommender pipeline, 30 paper adaptations, 14 candidate
  claims, 9 records; record-use diagnostic only 8 single-run pairs; no seeds repeats
  reported for the trajectory figures. New (Aug 2026), no independent use.
- Reasoning: fair. Clear distinctions (execution validity vs attribution), states its
  own limits plainly.
- Interests: authors' own framework; production lifts reported without a no-memory arm.
- Weigh: trust the descriptive finding on trajectories and the record schema as a
  design idea; the controller results are weak by the authors' own account.

## Findings

- [lab] A finished agent trajectory is not evidence: rounds can be invalid or
  confounded, and later changes can hide earlier findings. Abstract ^f1
  > Yet a completed trajectory is not automatically evidence: generated artifacts may be unsupported or incomplete, executed rounds may be invalid or confounded, and later modifications may obscure earlier findings.
- [lab] Over 30 adaptations, 26 found a later round beating the first, but in 22 the
  last round was below an earlier best, so the endpoint is not the best knowledge.
  Non-Monotonic Adaptation Trajectories ^f2
  > For 26 methods, at least one later valid round outperforms the first
  > for 22 methods, the last round falls below an earlier best, and later modifications sometimes partially or completely erase a previously observed gain.
- [lab] Execution validity has four gates: code realises the intervention, the run
  completes, the comparison follows the protocol, the mechanism is preserved; failing
  runs are kept as diagnostics but never as claims. Per-Step Verification Harness ^f3
  > An experiment is execution-valid when the implementation realizes the proposed intervention, the prescribed run completes, the comparison follows the evaluation protocol, and the paper’s defining mechanism is preserved.
  > Runs that fail an execution gate are retained as operational diagnostics but excluded from persistent claims.
- [lab] Rounds are grouped by intervention; invalid, confounded, duplicated or
  superseded rounds are excluded before a claim is made. ^f4
  > The qualification step groups rounds that address the same intervention and locus
  > invalid, confounded, duplicated, or superseded rounds are excluded
- [lab] A record links why and where the change acts to the diff, execution status,
  protocol, measurements and attribution checks, plus the conditions that limit reuse;
  negative results are kept as Guards when attributable. ^f5
  > The record states why the intervention was attempted and where it acts, and links to the implementation diff, execution status, protocol, measurements, and attribution checks.
  > A negative or null result yields a Guard only when it establishes an attributable failure mode under explicit observed conditions.
- [lab] Of 14 candidate claims, 8 became Repairs, 1 a Guard and 5 were Withheld; all
  34 referenced artifacts matched archived SHA-256 hashes. Experimental Record Audit ^f6
  > The pipeline consolidates 14 candidate claims: eight are qualified as actionable Repairs, one as a diagnostic Guard, and five are Withheld.
  > All 34 referenced source artifacts match their archived SHA-256 values
- [lab] Per-step checks: before an artifact (proposal, code change, run spec, result
  summary) passes on, the harness checks it against evidence and for missing
  information the next step needs. ^f7
  > First, it checks whether the artifact conflicts with the available evidence or constraints. Second, it checks whether the artifact omits information required by the next step.
- [lab] The LLM controller deciding whether a record applies was weak: 67.2% accuracy,
  below an always-reject rule's 79.7%. ^f8
  > accuracy was 67.2%, below the 79.7% obtained by an alwaysReject rule on this class-imbalanced set
- [lab] Checked, not there: no per-instance predictions, no repeated seeds or
  intervals in the trajectory comparison. ^f9
- [lab] (inferred) For meiolol: runs.tsv should mark each run valid or invalid (and
  why) and group runs by the change they test; the agent's "best so far" should come
  from the record, never the last run, and kept null results ("tried X, no gain at
  this n") are as valuable as wins. ^f10

## Read

- Abstract, introduction, method (verification harness, qualification, records),
  trajectory results, record audit, limitations.

## Not read

- Controller details, production case-study tables, appendix.

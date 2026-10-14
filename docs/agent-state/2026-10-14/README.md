# Agent state at the 2026-10-14 stop

Copied from the sessions' /tmp scratchpads when Jacob stopped all sessions (out of
usage), so a reboot can't lose them. Coordinator summary: docs/coordinator-state.md;
run lessons: docs/lab-findings.md; roster: docs/model-agents.md.

- progress-*.md: each track's progress file (runs, results, next steps); draftpath has
  two (old pane 1001, and its successor's in pane 1017)
- agents.tsv: coordinator's watch list (name, session id, role) at the stop
- split-rules.md: meiolol-53's (was 33) definition of the all-platform split (test
  newest 15%, dev-val next 10%, 5 forward folds); pincheck-2253Z*.txt: its gate checks
  on snap-20261013T2253Z before and after the re-cut; handover-verify.md: the
  verifier's brief with the rebase checklist
- diffs/rowsql-skill-rel.v2.diff: PARKED, applies cleanly to HEAD. meiolol-74's next
  player fields (champion-relative rates, opponent-adjusted skill) with brute-force
  tests; apply at the next re-pin, review by the data agent or the verifier, commit by
  path before the pack, then the declared B1/B2 runs (progress-player.md)
- diffs/comps-2253Z-writeup.diff, embx-2253.diff: drafts of write-ups that landed in
  commits (embx f16367e; comps in model.md); kept for reference, do not apply
- diffs/tau-smoothing.diff: tried and rejected (plan.md curves, 05e7aac: estimator
  left as is); do not apply

At the stop one gpu-box run was still going: 20261014T032052Z-state-richc-2253Zr
(meiolol-state); it finishes on its own, read it on resume.

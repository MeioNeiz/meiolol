---
title: 'meiolol: planted check of the 10-seat Möbius reading (C0, own results, Nov 2026)'
url: file://data/runs/20261113T210845Z-mobius-plant-fm8/log
kind: dataset
commit: a1f9e723
for: [frontier-interactions]
looked: 2026-11-13
depth: ran (py/xcheck/mobius_plant.py on 2004Z's drafts, planted labels; two runs, five scenarios each)
relevance: high
grade: C/strong
description: Our own planted check on real drafts (1.21M fit games, 173 champions, near-coin outcome): exact Möbius reading of a trained net against a known truth, pair cells from the net against a direct shrunk estimate, empty blocks, a planted 3-way class term
---
# meiolol: planted check of the 10-seat Möbius reading (C0, own results, Nov 2026)

Why: does an exact seat-level decomposition of a trained draft net return the effects
that are there, at our data shape; and is a pair better named from the net or from a
direct shrunk fit. Raw is the docs/model.md section of the same name.

## Assessment

- Evidence: C. One untuned net per scenario (two seeds for one), planted labels on real
  drafts, no replication over plantings; the reading itself is checked exact on the truth.
- Reasoning: strong. Empty blocks, a mains-only twin and a known truth as controls; limits
  stated (not our teacher, half the planted cells unshared, duplicates not filtered).
- Interests: our own.
- Weigh: trust the direction (machinery exact, invented pairs in empty blocks, direct
  cells at least as good from 50 games). The sizes belong to this net and this planting;
  the teacher (v2 plus the set net on profiles) may differ, which C1 measures.

## Findings

- [method/interpret] The reading is exact on a known function: the planted truth shows no power above order 2 without the 3-way term and 7.5 pp^2 with it. ^f1
  > The machinery is exact: the truth's own reading has 0.000 power above order 2 without
- [method/interpret] A net that learnt pairs (22-24% of the mains-to-truth gap) showed no false higher orders: order 3+ held 0.3-0.5% of its power, the same as a net fitted to mains-only labels. ^f2
  > A net that learns pairs shows no false higher orders: with fm 8 (22-24% of the
- [method/interpret] A net that stayed at the mains fit's loss had pair power that is noise: its two seeds' pair cells correlate 0.01-0.05. Explaining a model that does not beat the simpler fit returns nothing. ^f3
  > A net that has not learnt the pairs has nothing to read. The plain MLP stayed at the
- [method/interpret] [stats] A planted 3-way class effect of 2 pp a team (13% of the truth's power, hidden tag on 30% of champions) was not learnt at 1.21M games, so not read either: the net's order-3 terms on the planted seats correlate 0.01 with the truth. ^f4
  > A planted 3-way class effect was not read, because the net never learnt it: at 2 pp a
- [method/interpret] [stats] For a single champion pair the direct shrunk cell had the lower error in every block and the higher correlation with the truth from 50 games up in the three strongest blocks (lane top, 200-999 games: 0.74 against 0.61); at 10-49 games the two were level. The net's pair terms understate (slope 0.40). ^f5
  > For naming a champion pair the direct shrunk cell has the lower error in every block
- [method/interpret] The net put pair cells of sd 0.22-0.29 pp into two blocks planted at 0 (direct estimate: 0.00-0.02), and its two seeds agreed on them (correlation 0.34-0.52). Seed agreement does not make a pair real; an empty reference block gives the size to beat. ^f6
  > The net invents pairs where none are planted, and its seeds agree on them: cells in the
- [method/interpret] Checked, not there: our teacher's own form (v2 plus the set net on champion profiles), tuned nets or seed ensembles, legal-only backgrounds, more than one planting. ^f7

## Read

- `docs/model.md` "Planted check of the 10-seat Möbius reading (C0)": written from the
  two run logs (data/runs/20261113T210508Z-mobius-plant, 20261113T210845Z-mobius-plant-fm8)

## Not read

- Nothing left in the runs; the open part is C1 in docs/plan/lab-frontier.md

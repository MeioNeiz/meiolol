# progress: curvefit.zig (meiolol-df, from meiolol-30)

Brief: brief-curvefit.md. Coordinator meiolol-14. Scripts: curvefit-scripts/ here (plain
python3 stdlib, run read-only over ssh on the gpu-box: `python3 X.py ~/ml/snaps/SNAP`).
All on snap-20261013T2253Z, gold diff at 14 min from participants.gold14, ranked solo
with a timeline, mirrors left out (1.46M lanes, 30k cells).

## 2026-10-14 ~02:00Z
- Step 1 n_eff (repeats.py, rho.py): 7.5% of lanes have their a-side player again in the
  same cell; rho=1 bound n_eff/n 0.95 (20-49 games) to 0.54 (500+). But the within-player
  correlation of gold@14 residuals in a cell is tiny: rho 0.04 (20-99 game cells), 0.016
  (100-499), 0.007 (500+), bias-corrected (+1/n). Kish design effect 1.003-1.014: se's
  understated by under 0.7%, k unchanged. DROP n_eff (no +8 B a lane)
- Step 2 patch decay (patchvar.py): only 16.19 (53k) and 16.20 (310k) in 2253Z. Patch
  change of cell means, beyond noise, sd ~44 gold (cells with 50+ games each patch; 0 for
  10-49) vs true cell-mean sd 476; champion-role means sd ~53. Old-patch share 15%, so
  d moves estimates by under ~10 gold. DEFER until a big patch (per-patch files exist)
- Next: step 3 tau^2 smoothing + the 200k k recheck, needs `meiolol curves` on the snap
- Step 3 code (uncommitted, src/core/{curvefit,curvesfile,root}.zig): fitTop/nested in two
  passes, smoothTau (Whittaker on log tau^2 over minutes, weighted by pairs), strength from
  tau_lambdas {0,1,10,100,1000} by the split-half halfScore; logs jitter raw/fitted. Also
  core/root.zig exposes curvefit: its tests never ran in `zig build test` before
- Runs (gpu-box, cpu): 20261014T010154Z-curves-2253Z-base (HEAD), 20261014T010936Z-
  curves-2253Z-tau (clean copy HEAD + my 3 files, scratchpad tree/). Both: meiolol --data
  snap curves --platform all --days 60 --out curves-all.bin. k per minute from the file:
  curvefit-scripts/curvek.py FILE [level] [bracket]

## 2026-10-14 ~02:40Z
- First runs failed exit 2: `meiolol` wants the command first, then --data (lab-run ARGS
  `curves --data $HOME/ml/snaps/SNAP ...`). Reruns 20261014T012203Z-curves-2253Z-base,
  20261014T012224Z-curves-2253Z-tau: 290,825 games (all platforms, 60 days)
- Step 3 RESULT: tau smoothing chosen 0 in 13 of 15 role-metrics; middle gold/xp pick 1,
  gain ~0.05% of the split-half score. Not shipped; diff kept in curvefit-scripts/
  tau-smoothing.diff. log k jitter at 290k: 0-0.33 (k moves ~30% minute to minute at most)
- 200k recheck: k at the cap (100) at every minute for jungle and bottom (gold, xp, cs),
  mostly for utility xp/cs; top 18-57, middle 25-100. Split-half thick pairs (50+): jungle
  gold baseline 132 < shrunk 136 (noise 121), utility gold 88 < 91: the cap binds, more
  shrinkage would help. Queued 20261014T023913Z-curves-2253Z-maxk1000 (max_k 1000)
- Committed 2aeb9ba: core/root.zig exposes curvefit so its tests run (never did)
- maxk1000 (20261014T023913Z): mixed, kept 100. max_k also floors the champion-effect
  ridge, so baselines move: jungle gold all pairs 548 to 555 (worse), thick 135 to 134;
  utility/bottom thick 1-2 better. Thin pairs: rms at the other half's noise (top gold
  baseline 868, shrunk 856, noise 874), so step 4 (embedding prior) can't show a gain
- plan.md updated (curves results). Lane done unless 14 wants step 4 anyway or brackets

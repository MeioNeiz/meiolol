# DATA (meiolol-8a, from 73 / 4a)

## Done 14 Oct
- e1a9060 both numbers on every --final: compcheck, fields (final-excl-*.tsv), style,
  meiolol carry. 53 review passed (note: full test decides, excl is the side number)
- 290b744 crawl --mastery-sweep-days N (sweep 18 after push; remove when every platform
  logs "sweep done"); 6f10401 data-safety.md 11 Oct window
- e5aabc2 crawl mastery: batch cursor in participant pass (deadline resume, no retry of
  failures first); outage pause probes last good player; client 4xx log. Not pushed
- Found 2nd wrong-key window 11 Oct 23:25:50-23:28:45Z: matches rowid 92269-92366 (98,
  980 participant PUUIDs, 833 distinct, all other-app: 400 Exception decrypting), 81
  players rows (36 ladder, 45 participant) seen then. It stalled kr participant mastery
  since 13 Oct 19Z (0 rows/h), euw1 ~80%. Cleanup proposed to 14 (NULL PUUIDs, delete 81
  players, crawler stopped, backup first): WAITING for go
- History depth on re-cut 2253Z (win-exp c-exp 20261014T003827Z vs win-ratings
  rb-ref-wr/small 20261014T002905Z, histgain-4a.py): all -5.43 ± 0.51 mnats (folds
  -5.07 ± 0.55, dev-val -6.78 ± 1.23); 2055Z was -2.49, 1954Z -4.03. Champion-history
  players 0: -1.2, 1-2: -4.2, 3-4: -6.1, 5+: -6.3. Density (share of games with 3+
  players with champion history): 30% on 7 Oct, 73% on 11 Oct, 80% on 13 Oct. Not
  audited yet

## Open
- DB cleanup of the 11 Oct window (needs go); add to docs/data-safety.md incident
- Archive blanking of both windows' hashed PUUIDs; crawl-start decrypt guard
- Mastery sweep (horizon to ~26 Sep, one-time option, guard matches/day 133-139k)
- winchance weights refit after a look (14 OK)
- Standing: crawl volume + coverage per region with each snapshot; re-pin at +50% games
  or weekly

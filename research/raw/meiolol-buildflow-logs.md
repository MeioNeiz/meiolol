# meiolol build and push measurements, 5 Nov 2026

From data/deploys.tsv on the box (ci start to ok/failed per sha), ~/.cache/meiolol-push/log, deploy/slots.sh status and compute.sh samples, git log on main.

## Pre-push ci per day (UTC), all on the Mac

    day runs fail med_s p90_s max_s busy_min  hosts
    10-17 43 0 30 55 87 21 {'mac': 43}
    10-18 65 3 33 74 223 37 {'mac': 65}
    10-19 54 4 32 60 101 25 {'mac': 54}
    10-20 85 14 32 87 302 62 {'mac': 85}
    10-21 11 0 28 32 34 3 {'mac': 11}
    10-22 22 1 12 37 48 7 {'mac': 22}
    10-23 67 1 49 169 463 76 {'mac': 67}
    10-24 73 18 82 506 1020 222 {'mac': 73}
    10-25 34 2 75 90 98 34 {'mac': 34}
    10-26 72 4 141 218 3925 253 {'mac': 72}
    10-27 46 0 306 396 423 222 {'mac': 46}
    10-28 23 3 344 420 2444 161 {'mac': 23}
    10-29 46 13 481 1122 7898 570 {'mac': 46}
    10-30 66 17 173 279 560 191 {'mac': 66}
    11-01 16 0 104 276 834 46 {'mac': 16}
    11-02 16 4 135 215 643 45 {'mac': 16}
    11-03 20 4 158 289 356 59 {'mac': 20}
    11-04 58 7 192 429 1066 250 {'mac': 58}
    11-05 20 6 232 515 1412 103 {'mac': 20}
    deploys/day [('10-22', 8), ('10-23', 46), ('10-24', 21), ('10-25', 23), ('10-26', 68), ('10-27', 46), ('10-28', 21), ('10-29', 33), ('10-30', 49), ('11-01', 17), ('11-02', 12), ('11-03', 16), ('11-04', 48), ('11-05', 15)]
    00:01 366 ok 56211bd4 zig build ci on the Mac
    00:10 343 ok 126b4198 zig build ci on the Mac
    00:19 228 ok cc165928 zig build ci on the Mac
    00:29 301 ok 02ee03a9 zig build ci on the Mac
    00:40 152 ok 1da6a62c zig build ci on the Mac
    00:43 90 ok 2c73a2c0 zig build ci on the Mac
    08:47 175 ok cf7348b3 zig build ci on the Mac
    08:59 166 ok 0c83865c zig build ci on the Mac
    09:09 236 failed a6762737 zig build ci on the Mac
    09:13 145 failed a6762737 zig build ci on the Mac
    09:16 91 failed a6762737 zig build ci on the Mac
    09:18 72 ok a6762737 zig build ci on the Mac
    09:28 199 failed 32e150c9 zig build ci on the Mac
    09:51 148 ok 319636d4 zig build ci on the Mac
    10:01 239 ok 84cd30f4 zig build ci on the Mac
    10:07 333 ok 735b7e38 zig build ci on the Mac
    12:14 382 failed 5289b8b3 zig build ci on the Mac
    12:39 592 ok b433ca8f zig build ci on the Mac
    12:52 1412 ok be2b6ba4 zig build ci on the Mac
    13:19 515 failed b3cc3793 zig build ci on the Mac

## Samples, 5 Nov

14:11 slots: 3 of 3 held by one pre-push ci (7 min in), 7 runs waiting (test-ui x2, test, ui-sizes, others).
14:12 compute.sh: mac load 13.05/10, swap 16.1 GB, 5 waiting. vm.swapusage used 16515.56M of 17408.00M.
14:16 slots: 3 held by test runs, 2 waiting; load averages 13.36 15.20 14.81; top CPU: Chrome 98% plus three more Chrome processes 20-25% each, two zig 76% and 63%.
Box essex-vm 14:12: 16 vCPU, load average 3.91 4.12 4.33, 51 GB memory available; root disk 9.5G free, /srv/meiolol 333G free.
gpu-box: unreachable (off since 3 Nov).
Repo .zig-cache 30G; build trees in .git/meiolol-build total about 40G (lab-push 13G, w5 6.7G, w4 4.1G, ci 2.9G).

## Commits on main

3 Nov 29 commits (25 touch src, build or deploy); 4 Nov 89 (62); 5 Nov to 14:16 52 (41). Per hour on 5 Nov: 00h 7, 08h 4, 09h 10, 10h 2, 11h 3, 12h 14, 13h 9, 14h 3.

## Push log, 5 Nov

    2026-11-05T00:00:04Z pushed 79626690
    2026-11-05T00:07:34Z pushed 56211bd4
    2026-11-05T00:16:01Z pushed 126b4198
    2026-11-05T00:23:27Z pushed cc165928
    2026-11-05T00:34:14Z pushed 02ee03a9
    2026-11-05T00:43:21Z pushed 1da6a62c
    2026-11-05T00:44:55Z pushed 2c73a2c0
    2026-11-05T08:50:05Z pushed cf7348b3
    2026-11-05T08:53:52Z pushed 2d9d621a
    2026-11-05T09:02:07Z pushed 0c83865c
    2026-11-05T09:13:31Z ci failed a6762737 Also play: champion tiles, the lift big and the share a bar, filling the card
    2026-11-05T09:15:59Z ci failed a6762737 Also play: champion tiles, the lift big and the share a bar, filling the card
    2026-11-05T09:18:24Z ci failed a6762737 Also play: champion tiles, the lift big and the share a bar, filling the card
    2026-11-05T09:19:54Z pushed a6762737
    2026-11-05T09:32:14Z ci failed 32e150c9 Win rates carry their games: a faint count beside the number, ends and games on 
    2026-11-05T09:54:17Z pushed 319636d4
    2026-11-05T10:05:50Z pushed 84cd30f4
    2026-11-05T10:12:53Z pushed 735b7e38
    2026-11-05T12:20:48Z ci failed 5289b8b3 /champions board: rate cell drops its games count, so it no longer covers the na
    2026-11-05T12:49:21Z pushed b433ca8f
    2026-11-05T13:16:29Z pushed be2b6ba4
    2026-11-05T13:28:31Z ci failed b3cc3793 Matchups lists: bullies' bar is the gold lead, hardest in shown order, clear mov

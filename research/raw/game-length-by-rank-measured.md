# Game length by lobby rank in ranked solo (our measurement, 2026-10-20)

## Data and method

- Local snapshot data/snap/meiolol.db: 85,693 ranked solo games (queue 420, remakes left out), patches 16.19-16.20, all regions.
- Lab snapshot snap-20261013T2253Z/meiolol.db on the gpu-box: 363,927 ranked solo games, same patches (16.19 53,427, 16.20 310,500), largely overlapping the local games, so not an independent sample.
- Lobby tier: median (lower median) of the post-game ranked solo tiers of the players in the game with a known tier, at least 6 of 10; otherwise unknown. The tier is looked up after the game, sometimes days later.
- Our crawl starts from Platinum IV and up players, so lobbies below Platinum are few and reached through those players' histories; no Iron or Bronze ladder is sampled as such. Real low elo is not in this data.
- Baron to end: events.tsv (290,807 games with a 10-participant timeline), minutes from the first baron kill to the game's end, split by whether the baron team won.

## Game length by lobby tier

### games-local.tsv

| lobby tier | games | mean min | median | p25-p75 | under 20 | 20-25 | 25-30 | 30-35 | 35+ | within 25-35 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| unknown | 6525 | 28.9 | 28.9 | 24.8-33.2 | 11% | 15% | 31% | 25% | 18% | 57% |
| Bronze | 590 | 31.2 | 31.4 | 26.0-36.5 | 8% | 13% | 21% | 28% | 30% | 49% |
| Silver | 1179 | 30.8 | 30.9 | 26.3-35.8 | 8% | 11% | 25% | 28% | 28% | 52% |
| Gold | 4853 | 30.2 | 30.5 | 26.2-34.9 | 8% | 12% | 27% | 28% | 24% | 56% |
| Platinum | 22773 | 29.7 | 29.8 | 25.7-33.9 | 9% | 13% | 29% | 28% | 20% | 58% |
| Emerald | 28775 | 28.9 | 29.1 | 25.1-33.0 | 9% | 16% | 32% | 27% | 17% | 59% |
| Diamond | 11671 | 28.3 | 28.4 | 24.6-32.2 | 10% | 18% | 34% | 25% | 13% | 59% |
| Master | 7966 | 26.9 | 27.1 | 23.2-30.9 | 14% | 22% | 34% | 21% | 9% | 54% |
| Grandmaster | 1013 | 26.4 | 26.6 | 22.7-30.5 | 17% | 22% | 33% | 21% | 7% | 54% |
| Challenger | 211 | 26.2 | 26.6 | 22.4-30.6 | 16% | 25% | 30% | 20% | 8% | 51% |
| all | 85693 | 28.9 | 29.0 | 24.9-33.2 | 10% | 16% | 31% | 27% | 17% | 58% |

### games-lab.tsv

| lobby tier | games | mean min | median | p25-p75 | under 20 | 20-25 | 25-30 | 30-35 | 35+ | within 25-35 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| unknown | 15103 | 28.5 | 28.6 | 24.4-32.9 | 11% | 17% | 30% | 25% | 16% | 56% |
| Bronze | 593 | 31.2 | 31.3 | 26.0-36.5 | 9% | 13% | 21% | 28% | 30% | 49% |
| Silver | 1344 | 30.7 | 30.9 | 26.3-35.6 | 9% | 11% | 25% | 28% | 27% | 53% |
| Gold | 15989 | 30.3 | 30.5 | 26.1-34.9 | 8% | 12% | 27% | 28% | 25% | 56% |
| Platinum | 115990 | 29.5 | 29.7 | 25.6-33.9 | 9% | 13% | 30% | 28% | 20% | 58% |
| Emerald | 126772 | 28.9 | 29.0 | 25.0-33.0 | 10% | 15% | 32% | 27% | 16% | 59% |
| Diamond | 54002 | 28.2 | 28.2 | 24.4-32.2 | 10% | 18% | 33% | 25% | 13% | 59% |
| Master | 30284 | 26.9 | 27.1 | 23.2-31.1 | 14% | 22% | 33% | 21% | 9% | 55% |
| Grandmaster | 3143 | 26.3 | 26.4 | 22.5-30.5 | 17% | 24% | 32% | 20% | 8% | 52% |
| Challenger | 570 | 25.9 | 26.1 | 22.1-30.2 | 19% | 25% | 30% | 19% | 7% | 49% |
| all | 363927 | 28.8 | 29.0 | 24.9-33.1 | 10% | 16% | 31% | 27% | 17% | 58% |

## First baron to game end, by lobby tier

Minutes from the first baron to the end, games with a baron, split by whether the baron team won.

| lobby tier | baron games | baron team won | of those, ended within 3 min | within 5 min | median minutes to end (won) |
| --- | --- | --- | --- | --- | --- |
| Gold and below | 10790 | 80% | 34% | 52% | 4-5 |
| Platinum | 70073 | 80% | 33% | 52% | 4-5 |
| Emerald | 79552 | 80% | 32% | 52% | 4-5 |
| Diamond | 35104 | 81% | 33% | 54% | 4-5 |
| Master+ | 19820 | 81% | 35% | 57% | 4-5 |
| all | 225387 | 80% | 33% | 53% | 4-5 |

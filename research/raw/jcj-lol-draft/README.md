
## LoL Draft Probability Estimator
**New here? Start with [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md)**: the current draft-only pipeline (data collector, models, results, known gaps).

"/reports" contains the project proposal and progress reports. lol_draft_project_docs goes more in-depth on why certain things were done along with dated progress (there is more passion here)

## Project Notes (as of 4/20/2026)
Cool stuff unique to my project worth discussing:

### 1. **Caching**
Caching is implemented in the Riot API collection pipeline (`build_draft_dataset.py`). The main motivation was that as the project evolved, I kept adding and testing new player-based features. Without caching, that would have meant repeatedly querying the same player profiles and treating them as if they were new, which would waste both time and API calls.

The cache stores each player’s ranked solo-queue profile keyed by PUUID, including:
- wins
- losses
- games played
- win rate
- tier
- rank
- LP

A few implementation details were important:
- **`save_player_cache()`** writes to a temporary `.tmp` file before replacing the original cache file. This prevents corruption if the script stops midway through a run.
- **`maybe_cache_entry()`** inserts player information into the cache as soon as it becomes available.
- **`get_player_ranked_profile()`** is the final lookup step: before making an API request, it first checks whether the player’s PUUID is already in the cache. If so, the cached profile is returned immediately.
- The cache is written back to disk every **200 matches** and again at the end of the run.

The practical benefit is that repeated dataset builds can reuse previously fetched player data instead of re-querying Riot’s API. This made later feature-engineering iterations much faster.

---

### 2. **Canonical Teams**
Riot’s raw match data is naturally stored in terms of **blue side** and **red side**, but side itself is not the signal I wanted the model to learn. In fact, because red side often corresponds to slightly higher average MMR, leaving matches in blue/red form risks preserving side-specific information that is not central to the actual composition.

To avoid that, teams are converted into a **canonical `team_a` vs `team_b` format**, with both sides ordered consistently. The goal is to make the representation symmetric and prevent the same composition from being split into two different training cases solely because it appeared once on blue and once on red.

This is best illustrated through an example, suppose the composition:
- Aatrox, Udyr, Syndra, Jinx, Rakan

appears on blue side in one game and on red side in another. If both are stored as raw blue/red outcomes, then the model effectively sees:
- “blue side wins” once
- “red side wins” once

instead of learning that the **same composition won twice**. Could you see why this is a problem?

Because the dataset is already limited by Riot API rate constraints, this matters a lot. By introducing canonical teams, we are approximately doubling our data (truthfully it's probably more honest to describe this as “not halving” lol). 

---

### 3. **Standardization**
Numeric features in this project live on very different scales. For example:
- win-rate differences are usually tiny decimal values (e.g. `0.505` vs `0.506`)
- games played can range from very small values up to the hundreds (e.g. `5` vs `500`)

If these are fed directly into the model without scaling, bigger  features can dominate optimization simply because of their units. This is a problem.

To address this, numeric features were standardized using the usual transformation:

x' = (x - μ_train) / σ_train

Of course this is all done on the training split only. All fitted preprocessing steps were computed on the training split- the validation split was used for model selection and the test split was reserved for final evaluation.

---

### 4. **Draft alone is (basically) useless**
At the start of the project, I tried a naive setup: use only the 10 drafted champions and the game result. Intuitively, this seemed like it might work, because draft should contain some predictive signal.

In practice, it did not. A draft-only model produced probabilities clustered near `0.5` for most games and behaved close to random.

In hindsight, this makes sense. Solo queue is extremely noisy:
- player execution varies a lot
- coordination is inconsistent
- in-game decisions matter heavily
- many matches are decided by factors not visible from draft alone

This motivated adding:
- player win-rate features
- games-played / confidence features
- engineered draft abstractions such as subclasses and scaling types

These additions gave the model enough structure to move away from near-random behavior and produce meaningful probabilities.

It is also worth noting that many of these abstractions were **hardcoded from domain knowledge**. For example, subclass labels such as bruiser, tank, enchanter, or mage were assigned manually rather than learned automatically. This is imperfect, (there’s probably a way to actually “classify” a champion as a bruiser quantitatively beyond even just typical item build, but this seems like a complex project in its own right?). Nonetheless we still got useful signal from this.

---

### 5. **Numeric features skip the model**
This was initially motivated by laziness, but eventually I did test a variation where these were added into the model.

 So to sum up, two variations were tested: 

1. **Late fusion:** numeric features appended after the transformer  
2. **Early fusion:** numeric features projected into a token and inserted into the transformer sequence

The early-fusion version did **not** show a meaningful benefit under matched settings. In fact, it was slightly weaker, although the difference was small.

Because the more complex variant did not improve results, the final model kept the simpler **first** design:
- easier to explain
- easier to interpret
- TLDR: less code for the same plateau

The latter is still saved under a different branch though (you can see it in Branches!). This is a little less fancy since it means our numeric features are basically only
interpreted by a simple MLP but oh well... The ends matter more than the means in life right? (disclaimer: this is not a reflection of my *actual* philosophy)

---

### 6. **Philosophy of Calibration:**
The main goal of the project was not just to predict which team would win, but to estimate a **usable pre-game win probability**.
I think when we think about the actual goal of the project, i.e., what does a player want as a tool? We come back to the idea of a probability estimator, since at the end of the day no match is ever certain. In testing, most models like XGBoost and the logistic regression had similar log-loss scores, but differed in calibration.

This distinction matters:
- **Accuracy** only tells us how often the model’s binary decision is correct.
- **Log loss** measures overall probability quality.
- **Calibration** checks whether predicted probabilities actually match realized frequencies.

For this use case, calibration is especially important. If the model says a team has a **70%** chance of winning, then games like that should really be won about **70%** of the time. That is what makes the prediction interpretable as a probability rather than just a ranking score.

The model was trained with **binary cross-entropy with logits**, which optimizes log loss, not calibration directly. Calibration was therefore evaluated separately using:
- calibration plots
- Expected Calibration Error (ECE)
- Brier score

This ended up being one of the most important project takeaways. Several models, (again, including logistic regression and XGBoost), achieved similar log-loss values, but differed more clearly in calibration quality. Since the intended use case is a pre-game probability estimator, calibration became the main lens through which final performance was interpreted.

---

### 7. **Parallelized API Calls**
To optimize for throughput (since my Riot API calls are severely rate-limited), it made sense to parallelize data collection across independent regional routing buckets rather than query every region sequentially. Thus build_draft_dataset.py uses a ThreadPoolExecutor to launch one worker per region group; regions used (AMERICAS, EUROPE, ASIA, SEA) are queried at the *same* time, while shards within the same region are still processed sequentially to avoid violating *shared* rate limits.
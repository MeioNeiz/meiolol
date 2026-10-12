---
title: 'AI Research Agents for Machine Learning: Search, Exploration, and Generalization in MLE-bench (Toledo et al., 2025)'
url: https://arxiv.org/abs/2507.02554
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: docs (sections 1-7, appendices A, B, G, H, I)
relevance: high
grade: A/strong
description: Meta FAIR's AIRA-dojo study; agents as search policy plus operators, greedy vs MCTS vs evolutionary on MLE-bench lite, and the validation-vs-test gap that makes search overfit
---
# AI Research Agents for Machine Learning: Search, Exploration, and Generalization in MLE-bench (Toledo et al., 2025)

Why: which loop shape (greedy, MCTS, evolutionary) and which operators matter for an
LLM experiment agent, and how badly selecting by validation score overfits.

## Assessment

- Evidence: A. Meta FAIR, 26 authors; controlled ablations that vary one component
  (operators or search policy) at a time; 20 seeds per task for R1, 10 for o3; 95%
  stratified-bootstrap intervals; 22 tasks of MLE-bench lite. Code public
  (facebookresearch/aira-dojo: June 2025, 176 stars, 38 forks, 6 contributors).
- Reasoning: strong. Separates search, operators, environment and evaluation signal;
  reports where advanced search does not help; discusses seed variance and limits
  (24 h, 1 GPU, contamination).
- Interests: authors' own framework and agents.
- Weigh: Kaggle tasks with a 24 h, 1 GPU budget and hundreds of nodes; our setting is
  one small noisy dataset. The generalisation-gap result transfers directly; the
  ranking of search policies may not.

## Findings

- [lab] Framework: an agent is a search policy over candidate solutions plus operators
  that modify them; their interplay is what matters. ^f1
  > We formalize AI research agents as search policies that navigate a space of candidate solutions, iteratively modifying them using operators.
- [lab] Components: fitness function, selection policy, operator set, operator policy,
  termination rule (wall clock or node cap). ^f2
  > Termination Rule. τ halts the search when a computational budget is exhausted, progress stalls, or a fitness threshold is reached.
- [lab] Operators: Draft, Debug, Improve, Memory (hand-written), plus a new Crossover
  that recombines two solutions. ^f3
  > Furthermore, we introduce Crossover which recombines useful elements from two artifacts to create a new candidate.
- [lab] With AIDE's operators, MCTS and evolutionary search gain nothing over greedy;
  the operators are the bottleneck. ^f4
  > When limited to AIDE’s operator set OAIDE , agents using more advances search policies (e.g., MCTS, evolutionary algorithms) gain no advantage, underscoring the operator set as the bottleneck.
- [lab] Turning memory off in AIDE left the medal rate nearly unchanged. ^f5
  > both variants achieve nearly identical mean medal rates. This suggests that memory is not a driving factor behind AIDE’s strong performance.
- [lab] Better operators alone (same greedy search) lift medal rate from 39.8% to
  45.5%. ^f6
  > AIRAgreedy outperforms AIDEgreedy (45.5 % vs. 39.8 %), representing a 14 % relative improvement
- [lab] AIRA operators: complexity cue by number of children (minimal, moderate,
  advanced) to stop early over-engineering; scoped memory (siblings for draft and
  improve, the debug chain for debug); explicit thinking. ^f7
  > This dynamic signal helps prevent premature over-engineering by ensuring the agent provides simple solutions when appropriate
  > for draft and improve, it retrieves only sibling memories
  > for debug, it retrieves the entire ancestral memory of the artifact’s debug chain, enabling review of prior fix attempts
- [lab] With good operators, MCTS is best for R1 (47% medals) but greedy is close and
  best on gold; policies only diverge after about 19 hours. ^f8
  > for R1, AIRAmcts achieves the best performance, achieving state-of-the-art performance on MLE-bench Lite with an average medal rate of 47%.
  > In terms of gold medals, AIRAgreedy performs best, reaching 27%.
  > Meaningful divergence in performance appears only after 19 hours.
- [lab] Environment alone matters: the same AIDE agent in AIRA-dojo rose from 35.2% to
  45.9% medals. ^f9
  > improves the medal rate from 35.2 % to 45.9 % compared to the reported results
- [lab] Agent actions: Jupyter execution of any Python, file I/O, shell via magics;
  returns status, stdout, tracebacks and execution time; sandboxed container with
  quotas. ^f10
  > agents can execute arbitrary Python code, perform file reads and writes, and even use the shell via Jupyter magic commands.
  > The environment captures and returns the status, standard outputs, tracebacks for debugging, and the code block execution time to the agents.
- [lab] Budget: 24 h per task, at most 4 h per code execution (cut from 9 h with no
  loss and more valid nodes). ^f11
  > each agent has a maximum runtime of 4 hours per code execution.
  > preliminary experiments showed no difference in performance and a higher average number of valid nodes in the search trees.
- [lab] A separate LLM with structured outputs parses each run's output into success,
  summary and validation metric. ^f12
  > We always use GPT-4o (OpenAI, 2024) with Structured Outputs to parse code execution outputs
- [lab] Fitness is 5-fold CV; the final answer is the node with the best validation
  score. ^f13
  > To select the final solution, the AIRA and AIDE agents return the one with the highest validation score.
- [lab] Perceived (validation) performance keeps rising over 24 h while true test
  performance plateaus or falls slightly: search overfits validation. ^f14
  > while the agent’s perceived performance (validation score) continues to improve over time, the true test performance plateaus, even slightly decreases over time.
- [lab] Searching and selecting by test instead of validation would add 9.4 to 16.6
  points of medal rate; greedy agents suffer most. ^f15
  > searching based on the test score instead of the validation score improves performance by 9.4 % and 12.4 % for AIRAmcts and AIRAevo.
  > The gap is even higher for the agents using a greedy search policy, reaching 15 % for AIRAgreedy and 16.6 % for AIDEgreedy.
- [lab] Most of the gap is final-node selection: picking the final node by test (search
  still by validation) closes all of it for MCTS and evolutionary, over 60% for greedy. ^f16
  > Even for the agents implementing the simpler greedy policy, selecting the best node in the final search graph closes more than 60 % of the gap.
- [lab] Hedging over the top 3 validation nodes recovers about 10% more; top
  validation nodes do carry signal. ^f17
  > with as little as 3 top-k submissions agents achieve an additional 10 % of performance
- [lab] [method] Seed variance: 3 seeds can rank agents wrongly; they recommend at
  least 10 seeds, prefer 20, with stratified bootstrap intervals. ^f18
  > We recommend using a minimum of 10 seeds per task for moderate ranking stability, with 20 seeds preferred to avoid misleading conclusions about relative algorithm performance.
- [lab] Search only pays with more compute if the evaluation signal is good enough to
  tell which direction improves. ^f19
  > Agents benefit from scaling search only when performance gains are not limited by the environment in which the agent operates, the quality of the evaluation signal guiding the search
  > of improvement will be unclear, which would undermine the search process.
- [lab] Infrastructure lessons: agents broke Python environments via pip (hence
  containers); API rate limits cap parallel agents; checkpointing needed for long
  runs. ^f20
  > Early experiments resulted in agents corrupting Python environments e.g., via a pip install.
- [lab] (inferred) For meiolol: with a noisy 8k-game eval, the greedy keep-if-better
  loop is the policy most hurt by validation noise (^f15), and with weak operators
  fancier search buys nothing (^f4); spend effort on the evaluation signal and the
  proposal step first, and pick the final model from the top few by a fresh check. ^f21

## Read

- Sections 1-7; appendices A (scaling preconditions), B, G (infrastructure), H, I
  (seed variance).

## Not read

- Appendices C (5-day runs), D (full MLE-bench), E, F (prompts, token counts), K, L
  (per-task results, example trees). The aira-dojo code itself.

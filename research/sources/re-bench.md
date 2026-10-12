---
title: 'RE-Bench: Evaluating frontier AI R&D capabilities of language model agents against human experts'
url: https://arxiv.org/html/2411.15114
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: docs (sections 4-6, appendix A.2)
relevance: high
grade: A/strong
description: METR benchmark of 7 ML research engineering environments; agents (Modular, AIDE) vs 61 human experts across time budgets and best-of-k run lengths
---
# RE-Bench: Evaluating frontier AI R&D capabilities of language model agents against human experts

Why: how run length, number of attempts and scaffold design change agent results on
research engineering, and why agents fall behind humans over longer horizons.

## Assessment

- Evidence: A. METR, November 2024; 7 environments, 71 human 8-hour attempts by 61
  experts, 3-5 8-hour agent attempts per environment plus up to k=128 short samples;
  environments, human data and trajectories open-sourced.
- Reasoning: strong. Compares two scaffolds and three run lengths at equal total time,
  analyses transcripts, and has a candid limitations section (noise from rare
  successes, test-score overfitting, no scaffold iteration).
- Interests: safety evaluator; motivated to measure capability, not to sell an agent.
- Weigh: trust the time-allocation and best-of-k results and the failure analysis.
  Agents are 2024 models, and only 7 environments, so per-environment results are
  noisy (the authors say so).

## Findings

- [lab] At 2 hours total, the best agents scored 4x human experts; humans improve more
  with time, narrowly ahead at 8 hours and 2x the top agent at 32 hours. abstract ^f1
  > the best AI agents achieve a score 4× higher than human experts when both are given a total time budget of 2 hours per environment.
  > achieving 2× the score of the top AI agent when both are given 32 total hours (across different attempts).
- [lab] Agents progress fast early then plateau after the first few hours; AIDE keeps
  making occasional progress after the Modular agent has stopped. `4.1` ^f2
  > We observe o1-preview and Claude 3.5 Sonnet making rapid progress initially, but slowing down after the first few hours
  > the AIDE scaffold seems to do better in this setting, continuing to make occasional progress after the Modular agent has stopped.
- [lab] Splitting a fixed 8 hours into best-of-k shorter runs beats one long run:
  30-minute runs were best for the Modular scaffold, 2-hour runs for AIDE. `4.2` ^f3
  > we find that 30-minute runs score the best for agents in the Modular scaffold, while 2 hour runs score the best for AIDE agents.
- [lab] Best-of-k keeps improving with more samples (to k=128 of 30 minutes) but stays
  far from top humans. `4.2` ^f4
  > we find that both versions of Claude 3.5 Sonnet continue to improve steadily with more 30 minutes samples, but that even with k\=128 samples agents are far from top human performance.
- [lab] Long contexts accumulate errors: the Modular agent did better with its context
  wiped every 30 minutes; AIDE avoids this by tree search over whole solutions instead
  of a growing context. `5.2` ^f5
  > The fact that Modular does better when previous work and context is wiped every 30 minutes is also an indication that the AI agent overall accumulates more issues and false assumptions than useful insights and code to build on over time
  > AIDE avoids this issue by not accumulating large contexts by design, instead doing tree-search over whole solutions
- [lab] Agents try about ten times as many solutions as humans (36.8 and 25.3 scored
  runs an hour for AIDE and Modular vs 3.4 for humans), mostly local tweaks of the
  starting solution. `5.1` ^f6
  > On average, AIDE and modular agents run score 36.8 and 25.3 times per hour respectively, while human experts only do so 3.4 times.
  > This often leads to agents finding highly optimized ’local-optima’ solutions which simply tweak the parameters and code of the starting solution
- [lab] On a noisy environment the best agent score was partly overfitting to noise: a
  rerun scored 0.69, not the original 0.88. `5.1` ^f7
  > Rerunning the agent solution, it achieves a normalized score of only 0.69 (significantly lower than the original score of 0.88), indicating that the high agent score is partially driven by overfitting to this noise.
- [lab] Agents saw the test score in most environments; the authors plan to show only a
  validation score next time, since agents score many more solutions than humans.
  `6.3` ^f8
  > All environments except for “Scaling Law Experiment” provide the agents with the test score output
  > In future iterations, we will likely only provide agents with a validation score in most environments, keeping the test score hidden.
- [lab] Failure: little variety in ideas (84% of attempts in one environment were
  lightly modified transformers, which suit it badly). `5.2` ^f9
  > the agent attempts to use lightly modified transformer architectures 84% of the time, despite the fact that transformers work very poorly without division and exponentiation.
- [lab] Failure: long-horizon agency, i.e. learning from new information, building on
  earlier work, recovering; stubborn wrong assumptions, missed contradictions, stuck
  on zombie processes holding VRAM. `5.2` ^f10
  > Perhaps the biggest observed limitations are in the area of long-horizon agency: effectively learning from new information, building on previous work and recovering from failures.
  > AI agents often make stubborn and incorrect assumptions, and do not notice or correctly interpret contradictory information.
- [lab] Failure: misread instructions led to loopholes that scored well but broke the
  rules on manual inspection. `5.2` ^f11
  > these misreadings of environments can lead to agents finding impressive and unexpected loopholes, which score well on automated evaluation, but are nevertheless clearly breaking the environment rules upon manual inspection
- [lab] Agents do relatively best with short, high-fidelity feedback, low engineering
  complexity and few surprises; engineering complexity correlated with the human-AI
  gap (R2 0.602), feedback length did not clearly. `5.3` ^f12
  > Short and high-fidelity feedback loops, which allow AI agents to lean into their ability to rapidly try many solutions.
  > we find that our results are compatible with low engineering complexity contributing to a smaller human–AI gap (R2\=0.602), while we did not find a clear connection with length of feedback loops or novelty.
- [lab] Modular scaffold: Python and bash only, outputs saved to files with long ones
  truncated to the first and last 300 characters, oldest messages dropped, and time
  used and remaining shown. `A.2.1` ^f13
  > This scaffold provides the model with Python and Bash commands, and some very simple context management to keep the input within the context window length of the LM.
  > If a given output is longer than 100,000 characters, the corresponding User message contains the first and last 300 characters of the output
  > The agent is provided with information about how much time has been used so far, as well as its remaining time budget.
- [lab] Agents were allowed to set their own command timeouts and told they could run
  code in the background, but rarely did, and Claude forgot background processes.
  `A.2.1` ^f14
  > we allowed the model to modify the timeouts on its bash and python commands.
  > As we found that Claude 3.5 Sonnet would often forget about running background processes
  > Despite these additions, agents rarely made use of running code in the background.
- [lab] AIDE was adapted to run the scoring function before its feedback model analyses
  the output, and to decide the metric's direction by majority vote. `A.2.1` ^f15
  > Before analyzing execution outputs, we run scoring and provide the scoring function output to the feedback model.
  > We use majority vote to determine whether scoring metric should be maximized or minimized.
- [lab] Agents mostly wait on compute, not on token generation, so API speed matters
  little; an 8-hour run used about 29M input tokens, about $123. `A.2.2`, `6.2` ^f16
  > We also find that in most runs the agents spend a majority of their time waiting for commands to run on the VM, rather than on generating tokens.
  > On average, our agents use ~29M input tokens and ~499K output tokens in each 8-hour run, at a cost of approximately $123.
- [lab] The authors expect gains from better GPU-management tools and from spending
  more tokens, such as exploring many solutions in parallel. `6.3` ^f17
  > we expect better performance from giving the agents better tools for managing GPU resources, and from approaches that make use of a larger number of tokens, e.g., by exploring many solutions in parallel

## Read

- Abstract, 4 (results), 5 (qualitative), 6 (discussion, limitations), A.2 (agent
  setup, scaffolds, tokens): fully

## Not read

- 2-3 (background, environment design), A.1 human procedure, B-C environment details,
  D-E example solutions

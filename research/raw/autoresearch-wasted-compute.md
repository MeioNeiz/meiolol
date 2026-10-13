# Recovering Wasted Compute in Autoresearch Agents

<https://arxiv.org/html/2608.10424>

arXiv is now an independent nonprofit! [Learn more](https://info.arxiv.org/about) 

 [Back to arXiv](https://arxiv.org/)

[Why HTML?](https://info.arxiv.org/about/accessible_HTML.html) [Report Issue](https://arxiv.org/html/2608.10424# "Report an Issue") [Back to Abstract](https://arxiv.org/abs/2608.10424v1 "Back to abstract page") [Download PDF](https://arxiv.org/pdf/2608.10424v1 "Download PDF")

1.  [Abstract](https://arxiv.org/html/2608.10424#abstract1 "In Recovering Wasted Compute in Autoresearch Agents")
2.  [1 Introduction](https://arxiv.org/html/2608.10424#S1 "In Recovering Wasted Compute in Autoresearch Agents")
3.  [2 Background](https://arxiv.org/html/2608.10424#S2 "In Recovering Wasted Compute in Autoresearch Agents")
4.  [3 Methodology](https://arxiv.org/html/2608.10424#S3 "In Recovering Wasted Compute in Autoresearch Agents")
5.  [4 Experimental setup and results](https://arxiv.org/html/2608.10424#S4 "In Recovering Wasted Compute in Autoresearch Agents")
6.  [5 Related works](https://arxiv.org/html/2608.10424#S5 "In Recovering Wasted Compute in Autoresearch Agents")
7.  [6 Discussion](https://arxiv.org/html/2608.10424#S6 "In Recovering Wasted Compute in Autoresearch Agents")
8.  [References](https://arxiv.org/html/2608.10424#bib "In Recovering Wasted Compute in Autoresearch Agents")
9.  [A Context-aware debugging: detailed analysis](https://arxiv.org/html/2608.10424#A1 "In Recovering Wasted Compute in Autoresearch Agents")
10.  [B Extended experimental results](https://arxiv.org/html/2608.10424#A2 "In Recovering Wasted Compute in Autoresearch Agents")
11.  [C Hyperparameter optimization materials and additional results and discussion](https://arxiv.org/html/2608.10424#A3 "In Recovering Wasted Compute in Autoresearch Agents")

[License: CC BY 4.0](https://info.arxiv.org/help/license/index.html#licenses-available)

arXiv:2608.10424v1 \[cs.AI\] 11 Aug 2026

# Recovering Wasted Compute in Autoresearch Agents

Au Kwok Chun Abhigyan Acherjee Amrutha Rao Zaiqian Chen Kazem Meidani C. Bayan Bruss Micah Goldblum

###### Abstract

A slew of recent works develop agents for solving research problems end-to-end, a paradigm increasingly referred to as autoresearch. Such agents have inspired large industry investment, motivated by their potential to automate time-consuming human labor and customize machine learning solutions for specialized applications. In this paper, we study the modeling pipeline at the core of these autoresearch systems and identify common failure modes when they are applied to tabular datasets: (1) they waste compute resolving the same bugs over and over again; (2) they often fail to tune hyperparameters even when they have a large remaining compute budget; (3) the tree-search algorithms that power them do not explore; and (4) they perform data analysis, mimicking the humans whose data they are trained on, but do not use that analysis to make downstream decisions. We explore targeted interventions and find that a global debug consultant that shares discovered runtime constraints across all branches of the search tree, prompt- and control-level enhancements, and refined tree-search algorithms successfully recover wasted compute. Our results show that large gains in autoresearch agent performance are achievable through agentic design alone, holding the underlying language model fixed.

<table id="p1.1" class="ltx_tabular ltx_align_top"><tbody class="ltx_tbody"><tr id="p1.1.1" class="ltx_tr"><td id="p1.1.1.1" class="ltx_td ltx_align_left"><span class="ltx_rule" style="width:0.0pt;height:24.0pt;--ltx-bg-color:black;display:inline-block;"></span></td></tr></tbody></table>

†

## 1 Introduction

Fueled by large-scale industry investment, agentic systems powered by Large Language Models (LLMs) are rapidly replacing traditional AutoML pipelines for automated data science ([Jing et al., 2025](https://arxiv.org/html/2608.10424#bib.bib5); [Chan et al., 2024](https://arxiv.org/html/2608.10424#bib.bib4)). Increasingly, these systems are aimed at broader research loops, from generating and verifying hypotheses purely from data ([Majumder et al., 2024](https://arxiv.org/html/2608.10424#bib.bib24); [Majumder et al., 2025](https://arxiv.org/html/2608.10424#bib.bib23)) to running experiments and writing up findings ([Lu et al., 2024](https://arxiv.org/html/2608.10424#bib.bib25)), a direction known as _autoresearch_. No matter the goal, these systems all rest on the same core task: writing code to process data, train and evaluate models, and produce a candidate solution. Current systems execute this task unreliably: they frequently time out, waste compute, and produce suboptimal, generic solutions ([Toledo et al., 2025](https://arxiv.org/html/2608.10424#bib.bib2); [Liu et al., 2025](https://arxiv.org/html/2608.10424#bib.bib19); [Yang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib3)).

In this work, we identify several recurring failure modes in leading tree-search based agentic frameworks ([Jiang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib17); [Liu et al., 2025](https://arxiv.org/html/2608.10424#bib.bib19)) when applied to tabular machine learning tasks. Each represents a distinct category of how an agent’s compute budget is wasted rather than productively spent. First, agents waste budget rediscovering known bugs. Because branches in a tree search do not share memory of past failures, parallel branches repeatedly resolve identical errors in isolation, preventing meaningful iteration ([Zhang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib18); [Yin et al., 2024](https://arxiv.org/html/2608.10424#bib.bib11)). Second, agents leave budget on the table by terminating search prematurely. Superficial convergence criteria cause them to stop after only a few valid solutions, skipping the hyperparameter tuning phase that the remaining budget could have supported. Finally, agents spend budget on unproductive search states, becoming trapped in dead-end solution paths until the budget is exhausted ([Toledo et al., 2025](https://arxiv.org/html/2608.10424#bib.bib2); [Zhou et al., 2024](https://arxiv.org/html/2608.10424#bib.bib6)).

We show that improved agentic design can address these problems without modifying the base LLM. We introduce a suite of structural interventions to resolve them: †

-   •
    
    Context-aware debugging: To resolve context isolation, we introduce a debug consultant that enables adaptive learning of the execution environment across the search tree. The consultant accumulates discovered bugs into a shared registry and injects constraints before each generation step, preventing redundant error correction and significantly improving efficiency.
    
-   •
    
    Budget-aware hyperparameter tuning enforcement: We identify the absence of systematic hyperparameter optimization as a primary failure mode of autonomous ML agents. To address this, we introduce prompt-level guidance and control-loop-level enforcement mechanisms that compel agents to allocate their compute budgets toward structured hyperparameter tuning. By penalizing local convergence and rewarding validation-driven search, we prevent premature termination and redirect search effort toward fine-grained exploitation.
    
-   •
    
    Thompson Sampling-enhanced backtracking: We replace random backtracking with Monte Carlo Tree Search (MCTS) using Thompson Sampling. This probabilistic approach allows the agent to intelligently navigate the solution space and escape unproductive debugging loops, resulting in a significant improvement in stability of generated solutions.
    
-   •
    
    Diagnostic - agents fail to act on injected exploratory data analysis (EDA): We evaluate whether agents incorporate analytical insights by injecting “adversarial” results of a toy exploratory data analysis directly into the context window. Our experiments reveal that current agents tend to ignore these signals, motivating the need for stricter control loops that encourage data-driven planning.
    

## 2 Background

##### Automated data science.

The autoresearch systems described above are built on automated data science: the end-to-end process of solving a data science task without human intervention. The agents that carry out this process, often called machine learning engineering (MLE) agents, take a dataset and problem description, generate code to explore and process the data, train and evaluate candidate models, and return a solution ready for deployment.

Recent research has shown that LLMs alone cannot solve these open-ended problems effectively and that an agentic scaffold is necessary to guide solution generation ([Nathani et al., 2025](https://arxiv.org/html/2608.10424#bib.bib20)). External tools ([Qin et al., 2024](https://arxiv.org/html/2608.10424#bib.bib21)), execution feedback ([Gehring et al., 2025](https://arxiv.org/html/2608.10424#bib.bib22)), and context management ([Jiang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib17); [Liu et al., 2025](https://arxiv.org/html/2608.10424#bib.bib19); [Yang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib3)) have all been shown to improve performance. One of the main architectural components in leading MLE agent frameworks ([Liu et al., 2025](https://arxiv.org/html/2608.10424#bib.bib19); [Jiang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib17)) is tree search over the space of candidate programs, where each node represents a solution in the form of a codebase, and edges represent attempted improvements via code edits. At each step, the agent selects a promising node to expand, generates a revised solution, executes it, and uses the resulting validation score to guide further exploration. This iterative execution-in-the-loop design has become the dominant paradigm for agentic data science and forms the basis of the frameworks we study in this work.

##### Agentic scaffolds.

The two primary agentic scaffolds we study are AIDE ([Jiang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib17)) and ML-Master ([Liu et al., 2025](https://arxiv.org/html/2608.10424#bib.bib19)). Our choice of these agents is based on their open-source nature and their exceptional performance on MLE-bench ([Chan et al., 2024](https://arxiv.org/html/2608.10424#bib.bib4)). AIDE structures its search around three core components. The first is a deterministic greedy search policy π that determines at each step whether to draft a new solution from scratch, debug a buggy node, or improve a valid one. A coding operator f implements these three actions, each with specialized prompts: _drafting_ produces an initial implementation, _debugging_ repairs execution errors, and _improving_ proposes a single atomic change to a working solution. Finally, a summarization operator Σ extracts concise summaries of past solutions and their scores, keeping the context manageable as the tree grows.

ML-Master extends this paradigm with an improved search strategy and an explicit reasoning mechanism. Its exploration module is inspired by Monte Carlo Tree Search (MCTS): nodes are selected using the Upper Confidence Bound for Trees (UCT) criterion, balancing each node’s accumulated reward against its visit count to prioritize promising but under-explored branches. Nodes are expanded via the same draft, debug, and improve actions as AIDE and assigned a reward based on code execution: a node receives a positive reward if its solution is bug-free and improves upon the best validation metric seen so far, and a negative reward otherwise. Multiple workers explore branches in parallel, with rewards backpropagated through the tree to guide subsequent selection. In place of AIDE’s summarization operator, ML-Master employs a reasoning module that embeds a curated memory of past execution results and sibling node insights directly into the reasoning component of the LLM, enabling the agent to learn across parallel exploration paths and leverage the capabilities of reasoning models.

## 3 Methodology

### 3.1 Context-aware debug consultant

Figure 1: The debug consultant shares context across the search tree: one node’s failure becomes every node’s lesson. Crashed nodes are compressed into a shared bug index of failed and successful repairs, distilled into banned patterns and proven fixes, and injected into every subsequent generation step, so the agent learns its runtime environment once instead of rediscovering each bug per branch.

In the tree-search paradigm described in [Section 2](https://arxiv.org/html/2608.10424#S2 "2 Background ‣ Recovering Wasted Compute in Autoresearch Agents"), knowledge of failures remains local: in both AIDE and ML-Master, only the child spawned to debug a failed node sees the actual error. The rest of the tree therefore independently rediscovers the same deprecated API call or version mismatch, often dozens of times within a single run. We call this context isolation.

Our debug consultant ([Figure 1](https://arxiv.org/html/2608.10424#S3.F1 "In 3.1 Context-aware debug consultant ‣ 3 Methodology ‣ Recovering Wasted Compute in Autoresearch Agents")) addresses this by maintaining a shared registry of runtime constraints—which API calls crash, which alternatives work—and propagating this knowledge to all nodes via a three-step control loop in order to allow adaptive learning of the execution environment:

Step 1: Error Compression. When a node crashes, the raw traceback is compressed into a compact record: the error type, a short signature, and the strategy that caused the failure. Raw tracebacks are verbose and vary across iterations; a short hint is sufficient for the LLM to avoid the mistake. This keeps the context window focused on solution search and ensures the registry scales gracefully ([Zhang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib18)).

Step 2: Shared Bug Registry. Each compressed record is accumulated into a shared registry that tracks the error type, which strategies have failed, and—when another node succeeds—the strategy that worked. The system distills a concise list of banned patterns and proven fixes:

> BANNED: lgb.train(..., verbose\_eval=N) → TypeError  
> USE: callbacks=\[lgb.log\_evaluation(period=N)\]

Every new node immediately inherits all entries discovered so far.

Step 3: Constraint Injection. Constraints are injected at two levels. During generation (drafting or improving), the distilled banned-pattern list is appended to the prompt, preventing the agent from repeating known-failing API calls. During debugging, the injection is more targeted: the system retrieves records relevant to the current error and provides specific failed strategies (marked “never do this”) along with any proven fixes, enabling informed repair rather than blind guessing.

Step 4: Deterministic Control Rules. In addition to the shared bug registry, the debug consultant adds deterministic rules to the execution process: execution timeouts and empty logs are treated as terminal dead ends that strictly halt the branch, rather than stochastic noise worth retrying.

### 3.2 Hyperparameter tuning interventions

We test three interventions of increasing invasiveness: a prompt-level directive, a control-loop mechanism that shapes the search reward, and their combination.

Figure 2: Budget dependent control-loop enforcement of hyperparameter tuning in AIDE. Each node is scored for hyperparameter-tuning quality on a 0–3 scale by an LLM judge. Buggy nodes are assigned the worst possible metric and their score is ignored; for a valid node, the score both conditions the agent’s next prompt and adjusts the metric used for node selection. The reward depends on how much budget remains: weak tuning (scores of 0 or 1) is penalized throughout, but strong tuning (2 or 3) is rewarded only in later stages of the search, so the agent explores broadly early and tunes intensively late.

The prompt-level intervention appends hyperparameter-tuning instructions to the agent context via additional\_notes.txt (for both AIDE and ML-Master), instructing it to establish a validated baseline, run cheap trials to identify the most impactful hyperparameters, then tune those around the best configuration once gains stall.

The control-loop intervention enforces tuning through the search reward rather than the prompt. After a node executes, an execution-time checker (\_score\_hyperparameter\_tuning) grades its tuning quality on a discrete {0,1,2,3} scale via an LLM rubric (NONE, MINIMAL, MODERATE, EXTENSIVE). If the node is not buggy, this score biases which nodes the agent expands next.

How the score enters the search differs by agent: in AIDE it adjusts the validation metric and conditions subsequent improvement prompts, while in ML-Master it is folded into the reward used for UCT-based node selection (e.g., +0.25×hpo\_score). The AIDE adjustment also accounts for code diversity and parameter reuse: metricadj\=metricbase+0.1×s×(rhpo+rdiv+rcorr), where rhpo, rdiv, and rcorr are the tuning, diversity, and reuse rewards. The scale factor s\=|metricbase| (or 1.0 when the base metric is below 0.01) keeps the adjustment proportional to the magnitude of the base metric. The tuning reward rhpo depends on how much budget remains: weak tuning is penalized throughout the search, but strong tuning is rewarded only in its later stages. ([Figure 2](https://arxiv.org/html/2608.10424#S3.F2 "In 3.2 Hyperparameter tuning interventions ‣ 3 Methodology ‣ Recovering Wasted Compute in Autoresearch Agents")).

The combined intervention applies both the prompt-level directive and the control-loop mechanism together. Full prompts for the directive and the LLM scorer are given in [Appendix C](https://arxiv.org/html/2608.10424#A3 "Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents").

### 3.3 Thompson sampling and backtracking

Figure 3: Thompson Sampling with backtracking reallocates budget away from repeatedly failing branches. Each sibling node carries a Beta distribution over its quality, stored in global memory and updated from observed rewards after every execution. When the agent detects an identical error recurring down a path (S1 → S2 → S3), it backtracks to the branch point where the error first appeared (S1) and re-samples among the siblings, expanding the node with the highest draw rather than choosing at random. Budget that would otherwise be spent re-deriving the same failure is redirected toward more promising candidates.

Each of the agents we study maintains a tree of code variants, where every node is a distinct solution attempt with an associated validation metric. When the agent hits the same error repeatedly, we backtrack to the branch point where that error first appeared and reconsider its sibling nodes, rather than continuing to burn budget down a failing path. Instead of choosing at random as is default with current agents, we use Thompson Sampling ([Figure 3](https://arxiv.org/html/2608.10424#S3.F3 "In 3.3 Thompson sampling and backtracking ‣ 3 Methodology ‣ Recovering Wasted Compute in Autoresearch Agents")): each sibling i carries a Beta​(αi,βi) distribution over its quality, initialized from a uniform Beta​(1,1) prior. At each selection step, we draw a sample θi∼Beta​(αi,βi) from every candidate and expand the one with the highest draw, s∗\=arg⁡maxi⁡θi. After the chosen node executes, we score it with a normalized reward r∈\[0,1\] (0 for buggy nodes, linearly scaled by validation performance otherwise) and update its distribution:

<table id="S3.EGx1" class="ltx_equationgroup ltx_eqn_gather ltx_eqn_table"><tbody id="S3.E1"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_eqn_cell ltx_align_center"><math id="S3.E1.m1" class="ltx_Math" alttext="\displaystyle\alpha_{\text{new}}=\alpha_{\text{old}}+r" display="block" intent=":literal"><semantics><mrow><msub><mi>α</mi><mtext>new</mtext></msub><mo>=</mo><mrow><msub><mi>α</mi><mtext>old</mtext></msub><mo>+</mo><mi>r</mi></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(1)</span></td></tr></tbody><tbody id="S3.E2"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_eqn_cell ltx_align_center"><math id="S3.E2.m1" class="ltx_Math" alttext="\displaystyle\beta_{\text{new}}=\beta_{\text{old}}+(1-r)" display="block" intent=":literal"><semantics><mrow><msub><mi>β</mi><mtext>new</mtext></msub><mo>=</mo><mrow><msub><mi>β</mi><mtext>old</mtext></msub><mo>+</mo><mrow><mo stretchy="false">(</mo><mrow><mn>1</mn><mo>−</mo><mi>r</mi></mrow><mo stretchy="false">)</mo></mrow></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(2)</span></td></tr></tbody></table>

This procedure balances exploration (nodes with high uncertainty have wide distributions, giving them higher chances to be sampled) and exploitation (nodes with consistently good performance accumulate higher α values, shifting their distributions rightward), allowing the agent to learn which code branches are more promising with minimal sample complexity.

## 4 Experimental setup and results

### 4.1 Experimental setup

We evaluate our approaches on nine tabular prediction tasks spanning both classification and regression, drawn from MLE-bench and additional Kaggle competitions. Tasks were selected to satisfy three criteria: (i) their release postdates the knowledge cutoff of the underlying LLM, minimizing data leakage; (ii) they are of moderate dataset size to ensure tractable experimentation; and (iii) they collectively cover diverse evaluation metrics. The nine tasks are Cirrhosis Outcome Prediction, GNSS Classification, Spaceship Titanic, Wine Quality, and Playground Series S5E3, S5E6, S5E7, S5E8, and S5E12, with links provided in [Table 19](https://arxiv.org/html/2608.10424#A3.T19 "In C.5 List of linked competitions used in experiments ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents") from [Section C.5](https://arxiv.org/html/2608.10424#A3.SS5 "C.5 List of linked competitions used in experiments ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents"). We primarily evaluate two agent frameworks, AIDE and ML-Master, both powered by GPT-5-mini. Performance is measured using the official MLE-bench grading scripts, which compute task-specific metrics consistent with each competition (e.g., accuracy, AUC, RMSE) on a held-out test set. All scores are averaged over 10 independent runs with different random seeds; higher scores indicate better performance on all tasks except Cirrhosis Outcome Prediction, where lower is better. Following the MLE-bench medal system, a run earns a gold medal if its score places in the top 10% of the human leaderboard for that competition. All runs are executed with a fixed compute budget of 2 hours on 22 CPU cores.

Note on API models. All experiments use a single backbone, GPT-5-mini, because evaluations are prohibitively expensive: the full study (three agents, intervention and baseline conditions, nine competitions, ten seeds each) required over a thousand two-hour runs, and repeating it on a frontier model such as GPT-5.5 or Claude Opus 4.8, which cost roughly ten times more per token, would cost tens of thousands of dollars.

### 4.2 Context-aware debugging

The debug consultant design produces large and consistent gains for both agents ([Table 1](https://arxiv.org/html/2608.10424#S4.T1 "In 4.2 Context-aware debugging ‣ 4 Experimental setup and results ‣ Recovering Wasted Compute in Autoresearch Agents")). For AIDE, the debug consultant nearly doubles the gold-medal count, from 22 to 38, and eliminates all 17 of the baseline’s failed runs, raising the valid-submission rate from 81% to 100%; ML-Master improves comparably, from 18 to 29 golds, and both agents gain on six of nine competitions. The improvement is largest precisely where context isolation had been most costly: on S5E3 (AIDE) and GNSS (ML-Master), where the baseline earns no medals at all, the consultant recovers a perfect 10/10. It also reaches a working solution far sooner—the median number of steps to a first valid submission drops from 6 to 0, as the consultant supplies the environment’s constraints before the agent writes its first line of code.

(a) AIDE  
Comp. Treatment n Baseline n Cirrhosis† 0.384±0.008 10 0.394±0.035 9 GNSS 0.967±0.002 10 0.967±0.002 8 Spaceship 0.806±0.016 10 0.790±0.067 9 Wine 0.407±0.034 10 0.375±0.059 8 S5E3 0.954±0.015 10 0.888±0.010 9 S5E6 0.337±0.005 10 0.333±0.005 8 S5E7 0.969±0.001 10 0.968±0.000 9 S5E8 0.967±0.009 10 0.969±0.001 6 S5E12 0.725±0.005 10 0.727±0.001 7 W/L 6 : 3 Valid 90/90 73/90 Golds 38 22

(b) ML-Master  
Comp. Treatment n Baseline n Cirrhosis† 0.380±0.002 10 0.386±0.006 10 GNSS 0.953±0.012 10 0.813±0.002 10 Spaceship 0.813±0.008 10 0.794±0.033 10 Wine 0.412±0.015 10 0.412±0.028 10 S5E3 0.851±0.011 10 0.860±0.005 10 S5E6 0.336±0.003 10 0.326±0.006 10 S5E7 0.968±0.001 10 0.968±0.001 10 S5E8 0.969±0.000 10 0.966±0.002 10 S5E12 0.728±0.000 10 0.719±0.011 10 W/L 6 : 3 Valid 90/90 90/90 Golds 29 18

Table 1: The debug consultant improves gold medal rates on both agents. Treatment vs. vanilla baseline on 9 MLE-bench competitions × 10 seeds. Scores are mean ± std; n = seeds with valid submissions. Bold = winner by mean; values tied at the displayed precision are bolded in both columns. † = lower is better.

##### Mechanism.

The consultant works by stopping the agent from paying for the same mistake twice. In AIDE’s search journals, redundant bug encounters fall from 46% to 7.8%, and the fraction of nodes that execute without error rises from 54.7% to 79.0%. The compute the baseline spends rediscovering known bugs is instead spent producing working code, and this is what improves final scores: seeds with more valid nodes achieve better held-out results (pooled r\=+0.22 across 163 seeds). Detailed statistics, including first-attempt fix rates and time to first submission, are in [Appendix A](https://arxiv.org/html/2608.10424#A1 "Appendix A Context-aware debugging: detailed analysis ‣ Recovering Wasted Compute in Autoresearch Agents"); case studies, full generated code, and per-competition correlations are in [Sections B.3](https://arxiv.org/html/2608.10424#A2.SS3 "B.3 Case studies: how valid nodes become better solutions ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents"), [B.4](https://arxiv.org/html/2608.10424#A2.SS4 "B.4 Full generated code ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents") and [B.5](https://arxiv.org/html/2608.10424#A2.SS5 "B.5 Valid node and score correlation ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents").

### 4.3 Hyperparameter tuning guidance

| Competition | ΔPrompt | ΔCode | ΔP&C |
| --- | --- | --- | --- |
| Cirrhosis† | +0.035±0.0123 | +0.028±0.0118 | +0.024±0.0117 |
| GNSS | −0.036±0.0021 | −0.032±0.0012 | −0.030±0.0010 |
| Spaceship | +0.110±0.0225 | +0.105±0.0226 | +0.098±0.0235 |
| Wine | +0.100±0.0219 | +0.047±0.0270 | +0.081±0.0260 |
| S5E3 | +0.014±0.0052 | +0.004±0.0064 | +0.011±0.0055 |
| S5E6 | +0.067±0.0020 | +0.063±0.0030 | +0.064±0.0040 |
| S5E7 | +0.097±0.0002 | +0.097±0.0002 | +0.097±0.0002 |
| S5E8 | +0.384±0.0017 | +0.387±0.0003 | +0.388±0.0005 |
| S5E12 | +0.218±0.0005 | +0.218±0.0009 | +0.218±0.0006 |

Table 2: Hyperparameter guidance yields large performance gains for AIDE across most competitions. Intervention effect on graded score for AIDE: Δ\=μint−μbase (mean ± SEM of Δ). P&C = prompt and code. †Lower is better for Cirrhosis.

Adding explicit hyperparameter-tuning guidance to AIDE also produces sizable gains, improving graded scores on 7 of 9 competitions with individual effects as large as +0.388 on S5E8 and +0.218 on S5E12 ([Table 2](https://arxiv.org/html/2608.10424#S4.T2 "In 4.3 Hyperparameter tuning guidance ‣ 4 Experimental setup and results ‣ Recovering Wasted Compute in Autoresearch Agents")). The gains are concentrated on tasks where the baseline leaves the most room for improvement (S5E8, S5E12, Spaceship, Wine), confirming that AIDE under-invests in tuning and that a modest amount of structured guidance recovers measurable unrealized performance. On tasks where the baseline is already strong, additional tuning guidance produces little response.

The same control-loop intervention that helps AIDE can degrade ML-Master. This is due to the fact that it pushes ML-Master toward an HPO implementation that crashes. ML-Master’s memory then records the crash as buggy without propagating why, resulting in the agent continually retrying variants of the same broken approach. Scaffold interventions therefore do not transfer for free: whether one helps depends on interactions between the different components comprising a scaffold. We analyze this asymmetry in detail in [Appendix C](https://arxiv.org/html/2608.10424#A3 "Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents").

### 4.4 Thompson sampling with backtracking for stable, more reliable search

Thompson Sampling (TS) replaces the random sibling selection used by current agents with a strategy that concentrates exploration on promising branches and backtracks out of repeatedly failing ones. Its primary effect is stability: in a controlled comparison with all other settings held fixed, TS more than halves the number of null runs at almost no cost to peak performance. Two controlled studies below, on AIDE and on MLEvolve ([Du et al., 2026](https://arxiv.org/html/2608.10424#bib.bib1)), attribute this gain to the selection strategy itself.

We achieve this with a path-structuring algorithm for node selection, augmented by a single new parameter: similar\_error\_backtracking\_threshold, which lets the agent backtrack to the node level that triggered the first instance of a repeated error, reclaiming budget that would otherwise be spent re-deriving the same failure. We also widen the initial drafting phase, raising the number of initial solution nodes from 5 in the baseline to 20 for TS, since TS realizes its advantage only when it has a rich pool of candidates to allocate exploration across. Full hyperparameter settings for the baseline and TS are given in [Table 13](https://arxiv.org/html/2608.10424#A3.T13 "In C.1 Thompson sampling on AIDE: delta, standard deviation and proportion of null errors ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents"); headline results are reported in [Table 12](https://arxiv.org/html/2608.10424#A3.T12 "In C.1 Thompson sampling on AIDE: delta, standard deviation and proportion of null errors ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents"), with standard deviations and null rates in [Section C.1](https://arxiv.org/html/2608.10424#A3.SS1 "C.1 Thompson sampling on AIDE: delta, standard deviation and proportion of null errors ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents") ([Tables 14](https://arxiv.org/html/2608.10424#A3.T14 "In C.1 Thompson sampling on AIDE: delta, standard deviation and proportion of null errors ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents") and [15](https://arxiv.org/html/2608.10424#A3.T15 "Table 15 ‣ C.1 Thompson sampling on AIDE: delta, standard deviation and proportion of null errors ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents")).

Since we make multiple changes to the agentic pipeline, including introducing new hyper-parameters, we conduct a controlled study to isolate the contribution of TS itself. We re-evaluate TS with the number of initial drafts and all other hyperparameters held fixed across conditions, so any observed gain is attributable to TS alone. For AIDE, we set the native max-debug-depth parameter equal to our similar-error backtracking threshold, which renders the latter inactive, and compare two head-to-head conditions: AIDE with increased drafts but no TS, and the full AIDE+TS configuration ([Table 16](https://arxiv.org/html/2608.10424#A3.T16 "In C.2 AIDE: comparative analysis of Thompson sampling versus hyperparameter changes ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents")).

AIDE with 20 initial drafts already improves over the plain setting. On top of that, TS contributes a distinct and practically important advantage. Holding all other settings identical, AIDE+TS reduces null runs from 33 to 15 of 90 relative to AIDE+more drafts (a 54.5% reduction), delivering markedly more stable outcomes. On the competitions most sensitive to exploration, TS maintains or improves scores even against the stronger draft-augmented baseline, so the added stability comes at no cost to peak performance.

To further validate TS independently of any hyperparameter changes, we ran a further experiment with MLEvolve ([Du et al., 2026](https://arxiv.org/html/2608.10424#bib.bib1)), one of the strongest open-source agents on MLE-bench. Here the baseline and TS variants share identical configurations throughout; only the candidate selection strategy differs. Across nine benchmark competitions, MLEvolve+TS outperforms baseline MLEvolve on 5 out of 9 competitions ([Table 3](https://arxiv.org/html/2608.10424#S4.T3 "In 4.4 Thompson sampling with backtracking for stable, more reliable search ‣ 4 Experimental setup and results ‣ Recovering Wasted Compute in Autoresearch Agents")) and ties a sixth, confirming that the edge is attributable to TS rather than to incidental tuning.

| Competition | MLEvolve + TS | MLEvolve Baseline | Winner |
| --- | --- | --- | --- |
| Cirrhosis† | 0.390 ± 0.003 | 0.389 ± 0.004 | Baseline |
| GNSS | 0.953 ± 0.005 | 0.928 ± 0.011 | TS |
| Spaceship | 0.815 ± 0.002 | 0.814 ± 0.003 | TS |
| Wine | 0.406 ± 0.012 | 0.425 ± 0.002 | Baseline |
| S5E3 | 0.902 ± 0.001 | 0.899 ± 0.001 | TS |
| S5E6 | 0.313 ± 0.007 | 0.311 ± 0.008 | TS |
| S5E7 | 0.968 ± 0.000 | 0.968 ± 0.000 | Tie |
| S5E8 | 0.963 ± 0.003 | 0.964 ± 0.002 | Baseline |
| S5E12 | 0.726 ± 0.001 | 0.711 ± 0.004 | TS |

Table 3: Swapping in Thompson Sampling alone delivers MLEvolve’s largest gains. With all other settings held fixed, TS wins 5 of 9 competitions and ties a sixth (S5E7). Its two biggest-margin results, GNSS (+2.5%) and S5E12 (+1.5%), are well outside SEM, while most remaining differences in either direction fall within SEM; the one substantial exception is Wine, where the baseline wins by +1.9%. Bold indicates the winning method per competition; values tied at the displayed precision are bolded in both columns. †Lower is better.

Two mechanisms drive these gains, and they reinforce each other. A wider initial draft pool gives the agent more candidates to work with, and Thompson Sampling allocates exploration across them far more effectively than random selection, while backtracking pulls the agent out of repeatedly failing paths and returns that budget to promising ones. The AIDE and MLEvolve studies let us see each mechanism on its own: the draft increase helps by itself, and TS adds a further gain on top, holding everything else fixed. Together they explain why the full system is both more stable and stronger than either piece alone.

### 4.5 Diagnostic: current agents do not meaningfully act on exploratory data analysis

Additionally, as a diagnostic, we examine whether agent-based systems meaningfully adhere to one of the canonical stages of the machine learning pipeline: exploratory data analysis (EDA). We observe that most agents operate using a three-stage structure, namely draft(), improve(), and debug(). A recurring pattern across agents is the explicit instruction in all three phases to avoid EDA. We hypothesize that, even if this restriction were lifted, the agents would not effectively utilize insights derived from EDA. To test this hypothesis, we inject the results of a deliberately misleading and low-fidelity exploratory data analysis directly into the agent’s context window. Theoretically, if the agent incorporates this information, such adversarial signals would adversely influence its downstream decisions, for example feature selection. We would therefore expect degraded performance metrics as a consequence of these adversely impacted choices.

To test whether agents incorporate exploratory data analysis (EDA), we injected the results of a controlled, erroneous EDA into the context windows of AIDE and ML-Master and compared their performance against EDA-free baselines. Across all tasks, the performance differences induced by EDA injection were inconsistent and statistically insignificant. Using an LLM-as-a-judge framework (gpt-5-2025-8-07), we further found that agents never conducted EDA on their own in baseline runs and rarely engaged with the injected EDA: in AIDE, the agent acknowledged the malicious EDA in only 21% of cases and let it affect feature selection in just 5%. Together, these results indicate that existing agents do not meaningfully act upon or integrate EDA into downstream modeling decisions, suggesting an avenue for improving future agents. Extended details including the injection format, example messages, and the full evaluation prompts are provided in [Section C.4](https://arxiv.org/html/2608.10424#A3.SS4 "C.4 Adversarial EDA: extended analysis ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents").

## 5 Related works

AutoML outside of LLM agents. AutoML systems can automate algorithm selection and hyperparameter tuning. For example, Auto-sklearn ([Feurer et al., 2022](https://arxiv.org/html/2608.10424#bib.bib12)) and TPOT ([Olson and Moore, 2016](https://arxiv.org/html/2608.10424#bib.bib13)) leverage Bayesian optimization and ensemble construction. Approaches like FLAML ([Wang et al., 2021](https://arxiv.org/html/2608.10424#bib.bib14)) and TabPFN ([Hollmann et al., 2023](https://arxiv.org/html/2608.10424#bib.bib15)) focus on low-computational-cost optimization or in-context learning for tabular data, respectively. However, these systems are rigid compared to LLM agents that can implement any algorithm in principle, and they often fail to outperform simple baselines in low-data regimes ([Knauer et al., 2024](https://arxiv.org/html/2608.10424#bib.bib16)). Unlike these fixed-pipeline approaches, we employ LLM-driven agents to dynamically reason about data semantics and debug failures in real time.

Autoresearch & agentic data science. Recent agents for machine learning engineering have shifted from linear code generation to sophisticated tree-search methodologies ([Chan et al., 2024](https://arxiv.org/html/2608.10424#bib.bib4); [Wang et al., 2024b](https://arxiv.org/html/2608.10424#bib.bib9)). A broader line of work pushes toward autoresearch, automating larger portions of the research loop: DataVoyager ([Majumder et al., 2024](https://arxiv.org/html/2608.10424#bib.bib24)) uses a role-based multi-agent architecture to explore and verify hypotheses from a dataset, DiscoveryBench ([Majumder et al., 2025](https://arxiv.org/html/2608.10424#bib.bib23)) benchmarks agents on this discovery task rather than on competition-style modeling, and systems like The AI Scientist ([Lu et al., 2024](https://arxiv.org/html/2608.10424#bib.bib25)) attempt the full pipeline from ideation to writeup. The frameworks we build on instead focus on the modeling stage, optimizing predictive performance through tree search: AIDE ([Jiang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib17)), ML-Master ([Liu et al., 2025](https://arxiv.org/html/2608.10424#bib.bib19)), and R&D-Agent ([Yang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib3)) navigate complex coding tasks via iterative refinement and multi-agent parallelization. While effective at exploration, these methods lack explicit mechanisms for addressing the localization of debugging knowledge, often leading to repetitive errors in the search tree, a gap we address via a debug consultant that enables adaptive learning of the execution environment.

Self-correction & context engineering. LLMs have demonstrated the ability to “self-debug” code via iterative generation ([Chen et al., 2024](https://arxiv.org/html/2608.10424#bib.bib7); [Yang et al., 2024](https://arxiv.org/html/2608.10424#bib.bib8)). However, in domain-specific tasks, pre-training priors frequently override runtime feedback, causing persistent “fix loops.” To mitigate this, we draw on Agentic Context Engineering (ACE) ([Zhang et al., 2025](https://arxiv.org/html/2608.10424#bib.bib18)) to treat context as an evolving playbook. Crucially, unlike open-ended agents like Voyager ([Wang et al., 2024a](https://arxiv.org/html/2608.10424#bib.bib10)) that accumulate success skills, our domain necessitates the systematic accumulation of failures. We argue that in reward-sparse environments like tabular debugging, learning what not to do (negative constraints) provides just as valuable a signal as sparse successes.

## 6 Discussion

Our findings reveal fundamental limitations of existing agents. Some of what an agent learns is local to a branch. Much of it, however, is a global property of the environment or problem setting: which library versions are installed, which API signatures are valid, how long a fold of training takes on the available cores, or the features of the dataset at hand. Global facts are invariant across the tree, and re-deriving them per branch or node is redundant. A global memory that separates the two lets a run behave as a single agent rather than many isolated ones, which reduces redundancy. More importantly, memory may pay off in generating better hypotheses based on lessons learned globally across previous nodes. An agent that can recall what it has already ruled out can condition its next hypothesis on the accumulated failures instead of resampling from an unchanged prior. We expect the value of such memory to grow rather than shrink as autoresearch systems become more ambitious.

Existing agents are also limited in their ability to explore the search space. Tree search algorithms assume that expanding a node produces a novel candidate, but LLMs often write nearly the same program over and over again. When an agent produces dozens of near-identical programs, the tree is wide only on paper. Better selection will therefore help only so much until agents are designed to propose more varied solutions, which may be why our own selection improvements reduce variance more than they raise peak scores.

Reliability is another limitation of current agents, and perhaps the most overlooked. On a meaningful fraction of runs, agents produce no result at all, and the common practice of averaging over successful runs hides these failures so the waste goes uncounted. As autoresearch systems take on longer and more expensive tasks, a run that quietly produces nothing becomes far more costly than one that produces a mediocre answer. Making agents dependable will matter as much as making them capable.

The interventions we study are deliberately simple, and each recovers substantial performance from the same underlying model, which implies that current agents operate well below the ceiling their language models already permit. As these systems begin to take on more of the research loop, forming hypotheses, designing experiments, and interpreting results, the cost of an agent that forgets what it has learned, proposes what it has already tried, or fails silently will only rise. Closing that gap will require treating memory, diversity, and reliability as first-class objectives of agent design rather than as incidental properties of the scaffold.

## Acknowledgements

This project was supported by a research award from the Center for AI and Responsible Financial Innovation at Columbia University and by the Columbia Center for AI Technology.

## References

-   Chan et al. (2024) J. S. Chan, N. Chowdhury, O. Jaffe, J. Aung, D. Sherburn, E. Mays, G. Starace, K. Liu, L. Maksin, T. Patwardhan, L. Weng, and A. Mądry MLE-bench: evaluating machine learning agents on machine learning engineering. arXiv preprint arXiv:2410.07095. External Links: [Link](https://arxiv.org/abs/2410.07095) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p1.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§2](https://arxiv.org/html/2608.10424#S2.SS0.SSS0.Px2.p1.1 "Agentic scaffolds. ‣ 2 Background ‣ Recovering Wasted Compute in Autoresearch Agents"), [§5](https://arxiv.org/html/2608.10424#S5.p2.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Chen et al. (2024) X. Chen, M. Lin, N. Schärli, et al. Teaching large language models to self-debug. In International Conference on Learning Representations (ICLR), Cited by: [§5](https://arxiv.org/html/2608.10424#S5.p3.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Du et al. (2026) S. Du, X. Yan, J. Shi, Z. Cao, S. Feng, Z. Liang, B. Sun, T. Peng, Y. Zhou, X. Li, J. Zhou, L. He, B. Zhang, and L. Bai MLEvolve: a self-evolving framework for automated machine learning algorithm discovery. External Links: 2606.06473, [Link](https://arxiv.org/abs/2606.06473) Cited by: [§4.4](https://arxiv.org/html/2608.10424#S4.SS4.p1.1 "4.4 Thompson sampling with backtracking for stable, more reliable search ‣ 4 Experimental setup and results ‣ Recovering Wasted Compute in Autoresearch Agents"), [§4.4](https://arxiv.org/html/2608.10424#S4.SS4.p5.1 "4.4 Thompson sampling with backtracking for stable, more reliable search ‣ 4 Experimental setup and results ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Feurer et al. (2022) M. Feurer, K. Eggensperger, S. Falkner, M. Lindauer, and F. Hutter Auto-Sklearn 2.0: hands-free AutoML via meta-learning. Journal of Machine Learning Research 23 (261), pp. 1–61. External Links: [Link](http://jmlr.org/papers/v23/21-0992.html) Cited by: [§5](https://arxiv.org/html/2608.10424#S5.p1.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Gehring et al. (2025) J. Gehring, K. Zheng, J. Copet, V. Mella, T. Cohen, and G. Synnaeve RLEF: grounding code LLMs in execution feedback with reinforcement learning. In Forty-second International Conference on Machine Learning, External Links: [Link](https://openreview.net/forum?id=PzSG5nKe1q) Cited by: [§2](https://arxiv.org/html/2608.10424#S2.SS0.SSS0.Px1.p2.1 "Automated data science. ‣ 2 Background ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Hollmann et al. (2023) N. Hollmann, S. Müller, K. Eggensperger, and F. Hutter TabPFN: a transformer that solves small tabular classification problems in a second. In The Eleventh International Conference on Learning Representations, External Links: [Link](https://openreview.net/forum?id=cp5PvcI6w8_) Cited by: [§5](https://arxiv.org/html/2608.10424#S5.p1.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Jiang et al. (2025) Z. Jiang, D. Schmidt, D. Srikanth, D. Xu, I. Kaplan, D. Jacenko, and Y. Wu AIDE: AI-driven exploration in the space of code. External Links: 2502.13138, [Link](https://arxiv.org/abs/2502.13138) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p2.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§2](https://arxiv.org/html/2608.10424#S2.SS0.SSS0.Px1.p2.1 "Automated data science. ‣ 2 Background ‣ Recovering Wasted Compute in Autoresearch Agents"), [§2](https://arxiv.org/html/2608.10424#S2.SS0.SSS0.Px2.p1.1 "Agentic scaffolds. ‣ 2 Background ‣ Recovering Wasted Compute in Autoresearch Agents"), [§5](https://arxiv.org/html/2608.10424#S5.p2.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Jing et al. (2025) L. Jing, Z. Huang, X. Wang, W. Yao, W. Yu, K. Ma, H. Zhang, X. Du, and D. Yu DSBench: how far are data science agents from becoming data science experts?. External Links: 2409.07703, [Link](https://arxiv.org/abs/2409.07703) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p1.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Knauer et al. (2024) R. Knauer, M. Grimm, and E. Rodner PMLBmini: a tabular classification benchmark suite for data-scarce applications. External Links: 2409.01635, [Link](https://arxiv.org/abs/2409.01635) Cited by: [§5](https://arxiv.org/html/2608.10424#S5.p1.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Liu et al. (2025) Z. Liu, Y. Cai, X. Zhu, Y. Zheng, R. Chen, Y. Wen, Y. Wang, W. E, and S. Chen ML-Master: towards AI-for-AI via integration of exploration and reasoning. External Links: 2506.16499, [Link](https://arxiv.org/abs/2506.16499) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p1.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§1](https://arxiv.org/html/2608.10424#S1.p2.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§2](https://arxiv.org/html/2608.10424#S2.SS0.SSS0.Px1.p2.1 "Automated data science. ‣ 2 Background ‣ Recovering Wasted Compute in Autoresearch Agents"), [§2](https://arxiv.org/html/2608.10424#S2.SS0.SSS0.Px2.p1.1 "Agentic scaffolds. ‣ 2 Background ‣ Recovering Wasted Compute in Autoresearch Agents"), [§5](https://arxiv.org/html/2608.10424#S5.p2.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Lu et al. (2024) C. Lu, C. Lu, R. T. Lange, J. Foerster, J. Clune, and D. Ha The AI scientist: towards fully automated open-ended scientific discovery. External Links: 2408.06292, [Link](https://arxiv.org/abs/2408.06292) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p1.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§5](https://arxiv.org/html/2608.10424#S5.p2.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Majumder et al. (2024) B. P. Majumder, H. Surana, D. Agarwal, S. Hazra, A. Sabharwal, and P. Clark Position: data-driven discovery with large generative models. In Proceedings of the 41st International Conference on Machine Learning, R. Salakhutdinov, Z. Kolter, K. Heller, A. Weller, N. Oliver, J. Scarlett, and F. Berkenkamp (Eds.), Proceedings of Machine Learning Research, Vol. 235, pp. 34350–34382. External Links: [Link](https://proceedings.mlr.press/v235/majumder24a.html) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p1.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§5](https://arxiv.org/html/2608.10424#S5.p2.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Majumder et al. (2025) B. P. Majumder, H. Surana, D. Agarwal, B. D. Mishra, A. Meena, A. Prakhar, T. Vora, T. Khot, A. Sabharwal, and P. Clark DiscoveryBench: towards data-driven discovery with large language models. In The Thirteenth International Conference on Learning Representations, External Links: [Link](https://openreview.net/forum?id=vyflgpwfJW) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p1.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§5](https://arxiv.org/html/2608.10424#S5.p2.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Nathani et al. (2025) D. Nathani, L. Madaan, N. Roberts, N. Bashlykov, A. Menon, V. Moens, A. Budhiraja, D. Magka, V. Vorotilov, G. Chaurasia, D. Hupkes, R. S. Cabral, T. Shavrina, J. Foerster, Y. Bachrach, W. Y. Wang, and R. Raileanu MLGym: a new framework and benchmark for advancing AI research agents. External Links: 2502.14499, [Link](https://arxiv.org/abs/2502.14499) Cited by: [§2](https://arxiv.org/html/2608.10424#S2.SS0.SSS0.Px1.p2.1 "Automated data science. ‣ 2 Background ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Olson and Moore (2016) R. S. Olson and J. H. Moore TPOT: a tree-based pipeline optimization tool for automating machine learning. In Proceedings of the Workshop on Automatic Machine Learning, F. Hutter, L. Kotthoff, and J. Vanschoren (Eds.), Proceedings of Machine Learning Research, Vol. 64, New York, New York, USA, pp. 66–74. External Links: [Link](https://proceedings.mlr.press/v64/olson_tpot_2016.html) Cited by: [§5](https://arxiv.org/html/2608.10424#S5.p1.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Qin et al. (2024) Y. Qin, S. Hu, Y. Lin, W. Chen, N. Ding, G. Cui, Z. Zeng, X. Zhou, Y. Huang, C. Xiao, C. Han, Y. R. Fung, Y. Su, H. Wang, C. Qian, R. Tian, K. Zhu, S. Liang, X. Shen, B. Xu, Z. Zhang, Y. Ye, B. Li, Z. Tang, J. Yi, Y. Zhu, Z. Dai, L. Yan, X. Cong, Y. Lu, W. Zhao, Y. Huang, J. Yan, X. Han, X. Sun, D. Li, J. Phang, C. Yang, T. Wu, H. Ji, G. Li, Z. Liu, and M. Sun Tool learning with foundation models. ACM Comput. Surv. 57 (4). External Links: ISSN 0360-0300, [Link](https://doi.org/10.1145/3704435), [Document](https://dx.doi.org/10.1145/3704435) Cited by: [§2](https://arxiv.org/html/2608.10424#S2.SS0.SSS0.Px1.p2.1 "Automated data science. ‣ 2 Background ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Toledo et al. (2025) E. Toledo, K. Hambardzumyan, M. Josifoski, R. Hazra, N. Baldwin, A. Audran-Reiss, M. Kuchnik, D. Magka, M. Jiang, A. M. Lupidi, A. Lupu, R. Raileanu, K. Niu, T. Shavrina, J. Gagnon-Audet, M. Shvartsman, S. Sodhani, A. H. Miller, A. Charnalia, D. Dunfield, C. Wu, P. Stenetorp, N. Cancedda, J. N. Foerster, and Y. Bachrach AI research agents for machine learning: search, exploration, and generalization in MLE-bench. External Links: 2507.02554, [Link](https://arxiv.org/abs/2507.02554) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p1.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§1](https://arxiv.org/html/2608.10424#S1.p2.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Wang et al. (2021) C. Wang, Q. Wu, M. Weimer, and E. Zhu FLAML: a fast and lightweight AutoML library. External Links: 1911.04706, [Link](https://arxiv.org/abs/1911.04706) Cited by: [§5](https://arxiv.org/html/2608.10424#S5.p1.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Wang et al. (2024a) G. Wang, Y. Xie, Y. Jiang, A. Mandlekar, C. Xiao, Y. Zhu, L. Fan, and A. Anandkumar Voyager: an open-ended embodied agent with large language models. Transactions on Machine Learning Research. Note: External Links: ISSN 2835-8856, [Link](https://openreview.net/forum?id=ehfRiF0R3a) Cited by: [§5](https://arxiv.org/html/2608.10424#S5.p3.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Wang et al. (2024b) L. Wang, C. Ma, X. Feng, Z. Zhang, H. Yang, J. Zhang, Z. Chen, J. Tang, X. Chen, Y. Lin, W. X. Zhao, Z. Wei, and J. Wen A survey on large language model based autonomous agents. Frontiers of Computer Science 18 (6). External Links: ISSN 2095-2236, [Link](http://dx.doi.org/10.1007/s11704-024-40231-1), [Document](https://dx.doi.org/10.1007/s11704-024-40231-1) Cited by: [§5](https://arxiv.org/html/2608.10424#S5.p2.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Yang et al. (2024) J. Yang, C. E. Jimenez, A. Wettig, K. Lieret, S. Yao, K. R. Narasimhan, and O. Press SWE-agent: agent-computer interfaces enable automated software engineering. In The Thirty-eighth Annual Conference on Neural Information Processing Systems, External Links: [Link](https://openreview.net/forum?id=mXpq6ut8J3) Cited by: [§5](https://arxiv.org/html/2608.10424#S5.p3.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Yang et al. (2025) X. Yang, X. Yang, S. Fang, Y. Zhang, J. Wang, B. Xian, Q. Li, J. Li, M. Xu, Y. Li, H. Pan, Y. Zhang, W. Liu, Y. Shen, W. Chen, and J. Bian R&D-Agent: an LLM-agent framework towards autonomous data science. arXiv preprint arXiv:2505.14738. External Links: [Link](https://arxiv.org/abs/2505.14738) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p1.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§2](https://arxiv.org/html/2608.10424#S2.SS0.SSS0.Px1.p2.1 "Automated data science. ‣ 2 Background ‣ Recovering Wasted Compute in Autoresearch Agents"), [§5](https://arxiv.org/html/2608.10424#S5.p2.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Yin et al. (2024) X. Yin, C. Ni, S. Wang, Z. Li, L. Zeng, and X. Yang ThinkRepair: self-directed automated program repair. External Links: 2407.20898, [Link](https://arxiv.org/abs/2407.20898) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p2.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Zhang et al. (2025) Q. Zhang, C. Hu, S. Upasani, B. Ma, F. Hong, V. Kamanuru, J. Rainton, C. Wu, M. Ji, H. Li, U. Thakker, J. Zou, and K. Olukotun Agentic context engineering: evolving contexts for self-improving language models. External Links: 2510.04618, [Link](https://arxiv.org/abs/2510.04618) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p2.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents"), [§3.1](https://arxiv.org/html/2608.10424#S3.SS1.p3.1 "3.1 Context-aware debug consultant ‣ 3 Methodology ‣ Recovering Wasted Compute in Autoresearch Agents"), [§5](https://arxiv.org/html/2608.10424#S5.p3.1 "5 Related works ‣ Recovering Wasted Compute in Autoresearch Agents").
-   Zhou et al. (2024) A. Zhou, K. Yan, M. Shlapentokh-Rothman, H. Wang, and Y. Wang Language agent tree search unifies reasoning, acting, and planning in language models. In Proceedings of the 41st International Conference on Machine Learning, R. Salakhutdinov, Z. Kolter, K. Heller, A. Weller, N. Oliver, J. Scarlett, and F. Berkenkamp (Eds.), Proceedings of Machine Learning Research, Vol. 235, pp. 62138–62160. External Links: [Link](https://proceedings.mlr.press/v235/zhou24r.html) Cited by: [§1](https://arxiv.org/html/2608.10424#S1.p2.1 "1 Introduction ‣ Recovering Wasted Compute in Autoresearch Agents").

## Appendix A Context-aware debugging: detailed analysis

This section provides a comprehensive analysis of how the debug consultant accumulates a shared model of the execution environment and propagates it across the search tree. We show that baseline agents waste compute rediscovering the same library incompatibilities and API mismatches across branches, trace how the consultant’s accumulated knowledge of the runtime—which library versions are installed, which API signatures are valid, and which code patterns crash—changes agent behavior, and present concrete before/after examples.

### A.1 The environmental blindness problem

Without the debug consultant, each branch must independently discover the execution environment’s constraints—which library versions are installed, which API parameters have been deprecated, which code patterns are valid in the current container. The result is massive redundancy: 46.0% of baseline nodes waste compute re-encountering bugs that have already been seen within the same seed, compared to only 7.8% under the consultant. This redundant re-discovery causes total failure in 17 baseline seeds (zero valid submissions).

### A.2 How adaptive learning changes agent behavior

[Table 4](https://arxiv.org/html/2608.10424#A1.T4 "In A.2 How adaptive learning changes agent behavior ‣ Appendix A Context-aware debugging: detailed analysis ‣ Recovering Wasted Compute in Autoresearch Agents") and [Figure 4](https://arxiv.org/html/2608.10424#A1.F4 "In A.2 How adaptive learning changes agent behavior ‣ Appendix A Context-aware debugging: detailed analysis ‣ Recovering Wasted Compute in Autoresearch Agents") show per-competition recovery statistics. The BANNED list converts what would be random retries into informed corrections: the agent’s next attempt is constrained to avoid known-failing patterns, collapsing the search space so it is more likely to succeed.

Treatment recovers from 96.8% of bug streaks (consecutive buggy nodes), with 72.4% fixed on the first attempt (average 1.40 attempts). Baseline recovers from only 86.2%, with 41.4% first-attempt fixes and an average of 6.43 attempts. On the hardest competitions (S5E6, S5E8), baseline first-attempt fix rates are 19.0% and 0.0% respectively, while treatment achieves 47.6% and 69.4%.

|  | Treatment | Baseline |
| --- | --- | --- |
| Competition | Rec.% | 1st% | Att. | Rec.% | 1st% | Att. |
| --- | --- | --- | --- | --- | --- | --- |
| Cirrhosis | 98.2 | 75.9 | 1.31 | 78.8 | 38.5 | 3.69 |
| GNSS | 98.1 | 75.5 | 1.34 | 86.4 | 57.9 | 3.55 |
| Spaceship | 97.9 | 73.1 | 1.51 | 95.6 | 62.8 | 2.26 |
| Wine | 98.7 | 81.8 | 1.22 | 80.6 | 24.0 | 7.00 |
| S5E3 | 100.0 | 80.6 | 1.24 | 92.3 | 50.0 | 3.94 |
| S5E6 | 93.3 | 47.6 | 1.95 | 77.8 | 19.0 | 16.52 |
| S5E7 | 100.0 | 69.1 | 1.38 | 94.1 | 56.2 | 2.12 |
| S5E8 | 85.7 | 69.4 | 1.50 | 78.3 | 0.0 | 19.39 |
| S5E12 | 92.7 | 63.2 | 1.66 | 82.8 | 16.7 | 11.71 |
| Overall | 96.8 | 72.4 | 1.40 | 86.2 | 41.4 | 6.43 |

Table 4: Bug recovery statistics from AIDE journal analysis. Recovery = bug streak followed by ≥1 valid node. 1st-fix = recovered on the first attempt after the streak.

Figure 4: The consultant raises first-attempt fix rate from 41.4% to 72.4%. Bug recovery rate (left) and first-attempt fix rate (right) per competition. Constraint injection converts random retries into informed corrections.

### A.3 Synchronization speed

[Table 5](https://arxiv.org/html/2608.10424#A1.T5 "In A.3 Synchronization speed ‣ Appendix A Context-aware debugging: detailed analysis ‣ Recovering Wasted Compute in Autoresearch Agents") and [Figure 5](https://arxiv.org/html/2608.10424#A1.F5 "In A.3 Synchronization speed ‣ Appendix A Context-aware debugging: detailed analysis ‣ Recovering Wasted Compute in Autoresearch Agents") show how quickly the consultant learns the environment. Treatment seeds produce their first valid node at step 0.4 on average (median: 0)—the consultant has already learned enough about the runtime by the first step to guide the agent past common pitfalls. Baseline seeds, which must rediscover these constraints independently, require 6.8 steps on average (median: 6). Treatment reaches 94% submission by step 1 (100% by step 3); baseline remains at 0% through step 3 on five competitions. Under any fixed compute budget ≤3 steps, the scaffolded agent dominates.

|  | Treatment (%) | Baseline (%) |
| --- | --- | --- |
| Competition | S0 | S1 | S3 | S5 | S0 | S1 | S3 | S5 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cirrhosis | 80 | 100 | 100 | 100 | 0 | 0 | 20 | 40 |
| GNSS | 70 | 100 | 100 | 100 | 20 | 20 | 20 | 40 |
| Spaceship | 70 | 100 | 100 | 100 | 0 | 0 | 40 | 80 |
| Wine | 60 | 90 | 100 | 100 | 0 | 0 | 0 | 10 |
| S5E3 | 70 | 100 | 100 | 100 | 0 | 0 | 0 | 30 |
| S5E6 | 50 | 90 | 100 | 100 | 0 | 0 | 0 | 30 |
| S5E7 | 70 | 90 | 100 | 100 | 10 | 10 | 30 | 90 |
| S5E8 | 70 | 80 | 100 | 100 | 0 | 0 | 0 | 0 |
| S5E12 | 80 | 100 | 100 | 100 | 0 | 0 | 0 | 20 |
| Mean | 69 | 94 | 100 | 100 | 3 | 3 | 12 | 38 |

Table 5: Fraction of seeds with ≥1 valid submission by step N (AIDE, 10 seeds per competition). Treatment first-valid step: mean 0.4 (median 0). Baseline: mean 6.8 (median 6).

Figure 5: Treatment reaches 100% submission rate by step 3; mean baseline submission rate remains below 40% through step 5. Cumulative submission rate by exploration step for treatment vs. baseline across all 9 competitions (AIDE, 10 seeds each).

### A.4 From environmental synchronization to solution quality

[Table 6](https://arxiv.org/html/2608.10424#A1.T6 "In A.4 From environmental synchronization to solution quality ‣ Appendix A Context-aware debugging: detailed analysis ‣ Recovering Wasted Compute in Autoresearch Agents") shows that the treatment’s overall valid rate is 79.0% (2,889 / 3,655 nodes) versus 54.7% (2,464 / 4,507) for the baseline. Treatment generates fewer total nodes but a substantially higher fraction are valid, indicating more efficient use of the compute budget. This is partly because valid nodes consume significantly more runtime than invalid ones: a valid node must execute the full pipeline—including data preprocessing, model training (e.g., gradient-boosted trees), and prediction—while an invalid node crashes early and returns quickly. Fewer but valid nodes therefore represent a much larger share of useful compute.

With the environment solved, the LLM focuses on modeling: ensembles, calibration, and problem reformulation emerge through successive refinement. Per-competition correlations are reported in [Section B.5](https://arxiv.org/html/2608.10424#A2.SS5 "B.5 Valid node and score correlation ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents").

<table id="A1.T6.2" class="ltx_tabular ltx_centering ltx_align_middle"><tbody class="ltx_tbody"><tr id="A1.T6.2.1" class="ltx_tr"><td id="A1.T6.2.1.1" class="ltx_td ltx_border_tt"></td><td id="A1.T6.2.1.2" class="ltx_td ltx_align_center ltx_border_tt" colspan="3">Treatment</td><td id="A1.T6.2.1.3" class="ltx_td ltx_align_center ltx_border_tt" colspan="3">Baseline</td><td id="A1.T6.2.1.4" class="ltx_td ltx_nopad_r ltx_border_tt"></td></tr><tr id="A1.T6.2.2" class="ltx_tr"><td id="A1.T6.2.2.1" class="ltx_td ltx_align_left">Comp.</td><td id="A1.T6.2.2.2" class="ltx_td ltx_align_right ltx_border_t">Tot.</td><td id="A1.T6.2.2.3" class="ltx_td ltx_align_right ltx_border_t">Val.</td><td id="A1.T6.2.2.4" class="ltx_td ltx_align_right ltx_border_t">%</td><td id="A1.T6.2.2.5" class="ltx_td ltx_align_right ltx_border_t">Tot.</td><td id="A1.T6.2.2.6" class="ltx_td ltx_align_right ltx_border_t">Val.</td><td id="A1.T6.2.2.7" class="ltx_td ltx_align_right ltx_border_t">%</td><td id="A1.T6.2.2.8" class="ltx_td ltx_nopad_r ltx_align_right"><math id="A1.T6.m1" class="ltx_Math" alttext="\Delta" display="inline" intent=":literal"><semantics><mi mathvariant="normal">Δ</mi></semantics></math>%</td></tr><tr id="A1.T6.2.3" class="ltx_tr"><td id="A1.T6.2.3.1" class="ltx_td ltx_align_left ltx_border_t">Cirrhosis</td><td id="A1.T6.2.3.2" class="ltx_td ltx_align_right ltx_border_t">500</td><td id="A1.T6.2.3.3" class="ltx_td ltx_align_right ltx_border_t">428</td><td id="A1.T6.2.3.4" class="ltx_td ltx_align_right ltx_border_t">85.6</td><td id="A1.T6.2.3.5" class="ltx_td ltx_align_right ltx_border_t">261</td><td id="A1.T6.2.3.6" class="ltx_td ltx_align_right ltx_border_t">150</td><td id="A1.T6.2.3.7" class="ltx_td ltx_align_right ltx_border_t">57.5</td><td id="A1.T6.2.3.8" class="ltx_td ltx_nopad_r ltx_align_right ltx_border_t"><math id="A1.T6.m2" class="ltx_Math" alttext="+" display="inline" intent=":literal"><semantics><mo>+</mo></semantics></math>28.1</td></tr><tr id="A1.T6.2.4" class="ltx_tr"><td id="A1.T6.2.4.1" class="ltx_td ltx_align_left">GNSS</td><td id="A1.T6.2.4.2" class="ltx_td ltx_align_right">389</td><td id="A1.T6.2.4.3" class="ltx_td ltx_align_right">317</td><td id="A1.T6.2.4.4" class="ltx_td ltx_align_right">81.5</td><td id="A1.T6.2.4.5" class="ltx_td ltx_align_right">432</td><td id="A1.T6.2.4.6" class="ltx_td ltx_align_right">278</td><td id="A1.T6.2.4.7" class="ltx_td ltx_align_right">64.4</td><td id="A1.T6.2.4.8" class="ltx_td ltx_nopad_r ltx_align_right"><math id="A1.T6.m3" class="ltx_Math" alttext="+" display="inline" intent=":literal"><semantics><mo>+</mo></semantics></math>17.1</td></tr><tr id="A1.T6.2.5" class="ltx_tr"><td id="A1.T6.2.5.1" class="ltx_td ltx_align_left">Spaceship</td><td id="A1.T6.2.5.2" class="ltx_td ltx_align_right">524</td><td id="A1.T6.2.5.3" class="ltx_td ltx_align_right">380</td><td id="A1.T6.2.5.4" class="ltx_td ltx_align_right">72.5</td><td id="A1.T6.2.5.5" class="ltx_td ltx_align_right">744</td><td id="A1.T6.2.5.6" class="ltx_td ltx_align_right">641</td><td id="A1.T6.2.5.7" class="ltx_td ltx_align_right">86.2</td><td id="A1.T6.2.5.8" class="ltx_td ltx_nopad_r ltx_align_right"><math id="A1.T6.m4" class="ltx_Math" alttext="-" display="inline" intent=":literal"><semantics><mo>−</mo></semantics></math>13.7</td></tr><tr id="A1.T6.2.6" class="ltx_tr"><td id="A1.T6.2.6.1" class="ltx_td ltx_align_left">Wine</td><td id="A1.T6.2.6.2" class="ltx_td ltx_align_right">530</td><td id="A1.T6.2.6.3" class="ltx_td ltx_align_right">435</td><td id="A1.T6.2.6.4" class="ltx_td ltx_align_right">82.1</td><td id="A1.T6.2.6.5" class="ltx_td ltx_align_right">432</td><td id="A1.T6.2.6.6" class="ltx_td ltx_align_right">234</td><td id="A1.T6.2.6.7" class="ltx_td ltx_align_right">54.2</td><td id="A1.T6.2.6.8" class="ltx_td ltx_nopad_r ltx_align_right"><math id="A1.T6.m5" class="ltx_Math" alttext="+" display="inline" intent=":literal"><semantics><mo>+</mo></semantics></math>27.9</td></tr><tr id="A1.T6.2.7" class="ltx_tr"><td id="A1.T6.2.7.1" class="ltx_td ltx_align_left">S5E3</td><td id="A1.T6.2.7.2" class="ltx_td ltx_align_right">557</td><td id="A1.T6.2.7.3" class="ltx_td ltx_align_right">474</td><td id="A1.T6.2.7.4" class="ltx_td ltx_align_right">85.1</td><td id="A1.T6.2.7.5" class="ltx_td ltx_align_right">577</td><td id="A1.T6.2.7.6" class="ltx_td ltx_align_right">370</td><td id="A1.T6.2.7.7" class="ltx_td ltx_align_right">64.1</td><td id="A1.T6.2.7.8" class="ltx_td ltx_nopad_r ltx_align_right"><math id="A1.T6.m6" class="ltx_Math" alttext="+" display="inline" intent=":literal"><semantics><mo>+</mo></semantics></math>21.0</td></tr><tr id="A1.T6.2.8" class="ltx_tr"><td id="A1.T6.2.8.1" class="ltx_td ltx_align_left">S5E6</td><td id="A1.T6.2.8.2" class="ltx_td ltx_align_right">198</td><td id="A1.T6.2.8.3" class="ltx_td ltx_align_right">111</td><td id="A1.T6.2.8.4" class="ltx_td ltx_align_right">56.1</td><td id="A1.T6.2.8.5" class="ltx_td ltx_align_right">434</td><td id="A1.T6.2.8.6" class="ltx_td ltx_align_right">38</td><td id="A1.T6.2.8.7" class="ltx_td ltx_align_right">8.8</td><td id="A1.T6.2.8.8" class="ltx_td ltx_nopad_r ltx_align_right"><math id="A1.T6.m7" class="ltx_Math" alttext="+" display="inline" intent=":literal"><semantics><mo>+</mo></semantics></math>47.3</td></tr><tr id="A1.T6.2.9" class="ltx_tr"><td id="A1.T6.2.9.1" class="ltx_td ltx_align_left">S5E7</td><td id="A1.T6.2.9.2" class="ltx_td ltx_align_right">597</td><td id="A1.T6.2.9.3" class="ltx_td ltx_align_right">521</td><td id="A1.T6.2.9.4" class="ltx_td ltx_align_right">87.3</td><td id="A1.T6.2.9.5" class="ltx_td ltx_align_right">725</td><td id="A1.T6.2.9.6" class="ltx_td ltx_align_right">651</td><td id="A1.T6.2.9.7" class="ltx_td ltx_align_right">89.8</td><td id="A1.T6.2.9.8" class="ltx_td ltx_nopad_r ltx_align_right"><math id="A1.T6.m8" class="ltx_Math" alttext="-" display="inline" intent=":literal"><semantics><mo>−</mo></semantics></math>2.5</td></tr><tr id="A1.T6.2.10" class="ltx_tr"><td id="A1.T6.2.10.1" class="ltx_td ltx_align_left">S5E8</td><td id="A1.T6.2.10.2" class="ltx_td ltx_align_right">169</td><td id="A1.T6.2.10.3" class="ltx_td ltx_align_right">100</td><td id="A1.T6.2.10.4" class="ltx_td ltx_align_right">59.2</td><td id="A1.T6.2.10.5" class="ltx_td ltx_align_right">429</td><td id="A1.T6.2.10.6" class="ltx_td ltx_align_right">37</td><td id="A1.T6.2.10.7" class="ltx_td ltx_align_right">8.6</td><td id="A1.T6.2.10.8" class="ltx_td ltx_nopad_r ltx_align_right"><math id="A1.T6.m9" class="ltx_Math" alttext="+" display="inline" intent=":literal"><semantics><mo>+</mo></semantics></math>50.6</td></tr><tr id="A1.T6.2.11" class="ltx_tr"><td id="A1.T6.2.11.1" class="ltx_td ltx_align_left">S5E12</td><td id="A1.T6.2.11.2" class="ltx_td ltx_align_right">191</td><td id="A1.T6.2.11.3" class="ltx_td ltx_align_right">123</td><td id="A1.T6.2.11.4" class="ltx_td ltx_align_right">64.4</td><td id="A1.T6.2.11.5" class="ltx_td ltx_align_right">473</td><td id="A1.T6.2.11.6" class="ltx_td ltx_align_right">65</td><td id="A1.T6.2.11.7" class="ltx_td ltx_align_right">13.7</td><td id="A1.T6.2.11.8" class="ltx_td ltx_nopad_r ltx_align_right"><math id="A1.T6.m10" class="ltx_Math" alttext="+" display="inline" intent=":literal"><semantics><mo>+</mo></semantics></math>50.7</td></tr><tr id="A1.T6.2.12" class="ltx_tr"><td id="A1.T6.2.12.1" class="ltx_td ltx_align_left ltx_border_bb ltx_border_t"><span id="A1.T6.2.12.1.1" class="ltx_text ltx_font_bold">Total</span></td><td id="A1.T6.2.12.2" class="ltx_td ltx_align_right ltx_border_bb ltx_border_t">3,655</td><td id="A1.T6.2.12.3" class="ltx_td ltx_align_right ltx_border_bb ltx_border_t">2,889</td><td id="A1.T6.2.12.4" class="ltx_td ltx_align_right ltx_border_bb ltx_border_t"><span id="A1.T6.2.12.4.1" class="ltx_text ltx_font_bold">79.0</span></td><td id="A1.T6.2.12.5" class="ltx_td ltx_align_right ltx_border_bb ltx_border_t">4,507</td><td id="A1.T6.2.12.6" class="ltx_td ltx_align_right ltx_border_bb ltx_border_t">2,464</td><td id="A1.T6.2.12.7" class="ltx_td ltx_align_right ltx_border_bb ltx_border_t">54.7</td><td id="A1.T6.2.12.8" class="ltx_td ltx_nopad_r ltx_align_right ltx_border_bb ltx_border_t"><math id="A1.T6.m11" class="ltx_Math" alttext="+" display="inline" intent=":literal"><semantics><mo>+</mo></semantics></math>24.3</td></tr></tbody></table>

Table 6: Node counts from AIDE journal analysis (9 comps × 10 seeds). Treatment generates fewer total nodes but a higher fraction are valid.

## Appendix B Extended experimental results

### B.1 Per-seed OOS scores: AIDE

[Table 7](https://arxiv.org/html/2608.10424#A2.T7 "In B.1 Per-seed OOS scores: AIDE ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents") reports the graded out-of-sample score for every AIDE seed (9 competitions × 10 seeds). Treatment achieves valid submissions on all 90 seeds; baseline has 17 null runs (“—”). For Cirrhosis (Log Loss), lower is better; for all others, higher is better.

| Competition | Cond. | S0 | S1 | S2 | S3 | S4 | S5 | S6 | S7 | S8 | S9 | Mean | Std |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cirrhosis† | T | 0.3839 | 0.3849 | 0.3802 | 0.4004 | 0.3780 | 0.3767 | 0.3786 | 0.3802 | 0.3985 | 0.3803 | 0.384 | 0.008 |
|  | B | 0.3786 | 0.3826 | 0.3811 | 0.3799 | 0.3790 | 0.3847 | 0.3827 | 0.4868 | 0.3870 | — | 0.394 | 0.035 |
| GNSS | T | 0.9668 | 0.9676 | 0.9673 | 0.9687 | 0.9684 | 0.9640 | 0.9672 | 0.9634 | 0.9675 | 0.9649 | 0.967 | 0.002 |
|  | B | 0.9637 | 0.9673 | 0.9680 | 0.9679 | 0.9668 | 0.9687 | 0.9627 | — | 0.9690 | — | 0.967 | 0.002 |
| S5E3 | T | 0.9590 | 0.9572 | 0.9566 | 0.9634 | 0.9583 | 0.9104 | 0.9515 | 0.9606 | 0.9614 | 0.9570 | 0.954 | 0.015 |
|  | B | — | 0.8826 | 0.8920 | 0.8771 | 0.8960 | 0.9016 | 0.8748 | 0.8782 | 0.8884 | 0.8966 | 0.887 | 0.010 |
| S5E6 | T | 0.3321 | 0.3328 | 0.3439 | 0.3385 | 0.3399 | 0.3405 | 0.3299 | 0.3407 | 0.3316 | 0.3413 | 0.337 | 0.005 |
|  | B | 0.3275 | 0.3387 | 0.3303 | 0.3275 | — | — | 0.3301 | 0.3372 | 0.3372 | 0.3324 | 0.333 | 0.005 |
| S5E7 | T | 0.9682 | 0.9692 | 0.9682 | 0.9703 | 0.9698 | 0.9687 | 0.9698 | 0.9687 | 0.9698 | 0.9703 | 0.969 | 0.001 |
|  | B | 0.9682 | 0.9676 | 0.9682 | 0.9676 | — | 0.9682 | 0.9676 | 0.9682 | 0.9676 | 0.9676 | 0.968 | 0.000 |
| S5E8 | T | 0.9702 | 0.9700 | 0.9693 | 0.9413 | 0.9684 | 0.9692 | 0.9699 | 0.9696 | 0.9691 | 0.9698 | 0.967 | 0.009 |
|  | B | 0.9684 | — | — | 0.9697 | 0.9696 | 0.9695 | — | 0.9688 | — | 0.9691 | 0.969 | 0.001 |
| S5E12 | T | 0.7264 | 0.7110 | 0.7262 | 0.7259 | 0.7264 | 0.7255 | 0.7258 | 0.7257 | 0.7264 | 0.7268 | 0.725 | 0.005 |
|  | B | 0.7271 | 0.7281 | 0.7271 | 0.7275 | 0.7257 | 0.7281 | — | 0.7256 | — | — | 0.727 | 0.001 |
| Spaceship | T | 0.8172 | 0.8138 | 0.8081 | 0.8149 | 0.7920 | 0.8172 | 0.7897 | 0.8207 | 0.8149 | 0.7736 | 0.806 | 0.016 |
|  | B | 0.8000 | 0.8149 | 0.8218 | 0.8172 | 0.8241 | 0.6184 | — | 0.8299 | 0.7667 | 0.8207 | 0.790 | 0.067 |
| Wine | T | 0.4281 | 0.3980 | 0.4294 | 0.3321 | 0.4031 | 0.4284 | 0.4121 | 0.4419 | 0.3664 | 0.4315 | 0.407 | 0.034 |
|  | B | 0.3256 | 0.2990 | 0.4249 | 0.4264 | 0.3728 | 0.3016 | 0.4181 | 0.4329 | — | — | 0.375 | 0.058 |

Table 7: AIDE Per-Seed OOS Scores. Bold = per-seed winner; values tied at the displayed precision are bolded in both rows. — = null (no valid submission). † = lower is better.

### B.2 Per-seed OOS scores: ML-Master

[Table 8](https://arxiv.org/html/2608.10424#A2.T8 "In B.2 Per-seed OOS scores: ML-Master ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents") reports the graded OOS score for every ML-Master seed. Both treatment and baseline achieve valid submissions on all 90 seeds.

| Competition | Cond. | S0 | S1 | S2 | S3 | S4 | S5 | S6 | S7 | S8 | S9 | Mean | Std |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cirrhosis† | T | 0.3838 | 0.3795 | 0.3822 | 0.3775 | 0.3802 | 0.3813 | 0.3837 | 0.3795 | 0.3813 | 0.3756 | 0.380 | 0.002 |
|  | B | 0.3856 | 0.3789 | 0.3882 | 0.3789 | 0.3890 | 0.3794 | 0.3821 | 0.3877 | 0.3881 | 0.4000 | 0.386 | 0.006 |
| GNSS | T | 0.9521 | 0.9617 | 0.9480 | 0.9494 | 0.9576 | 0.9644 | 0.9549 | 0.9617 | 0.9207 | 0.9590 | 0.953 | 0.012 |
|  | B | 0.8124 | 0.8148 | 0.8130 | 0.8128 | 0.8140 | 0.8099 | 0.8112 | 0.8128 | 0.8145 | 0.8150 | 0.813 | 0.002 |
| S5E3 | T | 0.8585 | 0.8402 | 0.8539 | 0.8402 | 0.8721 | 0.8448 | 0.8448 | 0.8676 | 0.8402 | 0.8493 | 0.851 | 0.011 |
|  | B | 0.8585 | 0.8630 | 0.8585 | 0.8585 | 0.8676 | 0.8539 | 0.8539 | 0.8585 | 0.8585 | 0.8676 | 0.860 | 0.005 |
| S5E6 | T | 0.3421 | 0.3338 | 0.3343 | 0.3406 | 0.3349 | 0.3358 | 0.3358 | 0.3345 | 0.3309 | 0.3347 | 0.336 | 0.003 |
|  | B | 0.3238 | 0.3297 | 0.3251 | 0.3342 | 0.3256 | 0.3135 | 0.3213 | 0.3243 | 0.3296 | 0.3352 | 0.326 | 0.006 |
| S5E7 | T | 0.9687 | 0.9682 | 0.9676 | 0.9682 | 0.9655 | 0.9644 | 0.9687 | 0.9692 | 0.9682 | 0.9682 | 0.968 | 0.001 |
|  | B | 0.9671 | 0.9682 | 0.9682 | 0.9682 | 0.9676 | 0.9660 | 0.9676 | 0.9682 | 0.9682 | 0.9687 | 0.968 | 0.001 |
| S5E8 | T | 0.9686 | 0.9688 | 0.9686 | 0.9682 | 0.9693 | 0.9689 | 0.9692 | 0.9697 | 0.9690 | 0.9689 | 0.969 | 0.000 |
|  | B | 0.9669 | 0.9638 | 0.9653 | 0.9683 | 0.9654 | 0.9640 | 0.9650 | 0.9651 | 0.9680 | 0.9683 | 0.966 | 0.002 |
| S5E12 | T | 0.7277 | 0.7276 | 0.7278 | 0.7273 | 0.7275 | 0.7274 | 0.7277 | 0.7276 | 0.7279 | 0.7271 | 0.728 | 0.000 |
|  | B | 0.7258 | 0.7265 | 0.6877 | 0.7258 | 0.7198 | 0.7179 | 0.7180 | 0.7188 | 0.7226 | 0.7258 | 0.719 | 0.011 |
| Spaceship | T | 0.8184 | 0.8149 | 0.8126 | 0.8138 | 0.8207 | 0.8207 | 0.8184 | 0.7977 | 0.8172 | 0.7988 | 0.813 | 0.008 |
|  | B | 0.7287 | 0.7782 | 0.8138 | 0.8115 | 0.8092 | 0.7356 | 0.8092 | 0.8161 | 0.8172 | 0.8184 | 0.794 | 0.033 |
| Wine | T | 0.4011 | 0.4165 | 0.4181 | 0.3753 | 0.4243 | 0.4028 | 0.4143 | 0.4254 | 0.4221 | 0.4227 | 0.412 | 0.015 |
|  | B | 0.4318 | 0.4245 | 0.3308 | 0.4240 | 0.4240 | 0.4103 | 0.4158 | 0.4176 | 0.4227 | 0.4227 | 0.412 | 0.028 |

Table 8: ML-Master treatment wins the majority of per-seed comparisons despite a fully-valid baseline. Per-seed OOS scores for 9 competitions × 10 seeds. Bold = per-seed winner; values tied at the displayed precision are bolded in both rows. † = lower is better.

### B.3 Case studies: how valid nodes become better solutions

The two case studies below illustrate the same causal chain: the debug consultant removes a persistent API bug → the agent iterates freely → it builds qualitatively more sophisticated solutions. Both cases share a common pattern: the baseline LLM has the same modeling knowledge as the treatment, but it never gets to use it because its compute budget is consumed by redundant bug encounters.

#### B.3.1 Case study 1: S5E3 seed 6 (Δ\=+0.077 AUC)

[Figure 6](https://arxiv.org/html/2608.10424#A2.F6 "In Treatment ‣ B.3.1 Case study 1: S5E3 seed 6 (Δ=+0.077 AUC) ‣ B.3 Case studies: how valid nodes become better solutions ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents") compares the search trees for S5E3 (binary classification, rainfall prediction), seed 6.

##### Baseline

(left, 74 nodes, 2 valid, 2.7%): The agent’s first code draft calls lgb.train() with the deprecated early\_stopping\_rounds parameter. LightGBM raises a TypeError; the agent’s try/except handler catches it silently. Having no mechanism to propagate this failure, the agent generates nearly identical code 72 more times—each node re-encountering the same TypeError. Only 2 nodes avoid the pattern, producing a single-model LGBMClassifier with basic feature engineering (4 domain interactions, no calibration, no ensemble). OOS score: 0.8748.

##### Treatment

(right, 39 nodes, 31 valid, 79.5%): The debug consultant records the early\_stopping\_rounds TypeError at step 0 and adds it to the BANNED list. From that point forward, the agent never regenerates this pattern, enabling 31 valid iterations to explore progressively better approaches. The final solution is a 3-model ensemble (XGBoost + 2 LightGBM variants) with Platt-scaling calibration and greedy weight optimization. OOS score: 0.9515 (Δ\=+0.0767). With the debug consultant eliminating redundant failures, the treatment refines its approach through 15× more hypothesis-testing cycles, converging on a substantially more sophisticated solution.

Figure 6: Search tree comparison for S5E3 seed 6. Left: baseline (74 nodes, 2 valid, 2.7%). Right: treatment (39 nodes, 31 valid, 79.5%). Red = buggy; green = valid. The baseline loops on the same early\_stopping\_rounds TypeError for its entire budget.

#### B.3.2 Case study 2: Wine Quality (Δ\=+0.099 QWK)

[Figure 7](https://arxiv.org/html/2608.10424#A2.F7 "In The modeling insight gap. ‣ B.3.2 Case study 2: Wine Quality (Δ=+0.099 QWK) ‣ B.3 Case studies: how valid nodes become better solutions ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents") compares the search trees for Wine (ordinal classification, 7 quality levels), seed 1.

##### Baseline

(left, 10 nodes, 2 valid, 20%): The agent calls LGBMRegressor.fit() with early\_stopping\_rounds as a keyword argument—deprecated in the installed LightGBM version. Eight of 10 nodes crash with deprecated-API TypeErrors (7 from early\_stopping\_rounds, 1 from verbose). The 2 surviving nodes use a single LGBMRegressor with naive rounding of continuous predictions to integer quality labels. No stacking, no calibration, no threshold optimization. OOS score: 0.2990.

##### Treatment

(right, 57 nodes, 51 valid, 89%): The consultant’s BANNED list prevents the early\_stopping\_rounds TypeError from step 0. With 51 valid iterations, the agent builds a diverse bagged LightGBM ensemble with stacking (Ridge + Isotonic regression on out-of-fold predictions) and threshold optimization that maps continuous predictions to discrete quality labels, maximizing QWK directly. OOS score: 0.3980 (Δ\=+0.099).

##### The modeling insight gap.

Both baseline and treatment use a regression formulation. The crucial difference is what the agent does with additional valid iterations: it discovers that stacking multiple LightGBM models with isotonic calibration and optimized thresholds produces substantially higher QWK than a single model with naive rounding. With 51 valid nodes, the treatment has the budget to make this discovery; with 2 valid nodes, the baseline never gets the chance.

Figure 7: Search tree comparison for Wine seed 1. Left: baseline (10 nodes, 2 valid, 20%). Right: treatment (57 nodes, 51 valid, 89%). The baseline exhausts its budget on repeated early\_stopping\_rounds TypeErrors.

#### B.3.3 Synthesis: more valid nodes → better solutions

Both case studies tell the same story through different competitions and bug types:

<table id="A2.T9.2" class="ltx_tabular ltx_centering ltx_guessed_headers ltx_align_middle"><tbody class="ltx_tbody"><tr id="A2.T9.2.1" class="ltx_tr"><th id="A2.T9.2.1.1" class="ltx_td ltx_th ltx_th_row ltx_border_tt"></th><td id="A2.T9.2.1.2" class="ltx_td ltx_align_center ltx_border_tt">S5E3 seed 6</td><td id="A2.T9.2.1.3" class="ltx_td ltx_nopad_r ltx_align_center ltx_border_tt">Wine seed 1</td></tr><tr id="A2.T9.2.2" class="ltx_tr"><th id="A2.T9.2.2.1" class="ltx_td ltx_align_left ltx_th ltx_th_row ltx_border_t">Blocking bug</th><td id="A2.T9.2.2.2" class="ltx_td ltx_align_center ltx_border_t"><span id="A2.T9.2.2.2.1" class="ltx_text ltx_font_typewriter">early_stopping_rounds</span></td><td id="A2.T9.2.2.3" class="ltx_td ltx_nopad_r ltx_align_center ltx_border_t"><span id="A2.T9.2.2.3.1" class="ltx_text ltx_font_typewriter">early_stopping_rounds</span></td></tr><tr id="A2.T9.2.3" class="ltx_tr"><th id="A2.T9.2.3.1" class="ltx_td ltx_align_left ltx_th ltx_th_row">Baseline valid nodes</th><td id="A2.T9.2.3.2" class="ltx_td ltx_align_center">2 / 74 (2.7%)</td><td id="A2.T9.2.3.3" class="ltx_td ltx_nopad_r ltx_align_center">2 / 10 (20%)</td></tr><tr id="A2.T9.2.4" class="ltx_tr"><th id="A2.T9.2.4.1" class="ltx_td ltx_align_left ltx_th ltx_th_row">Treatment valid nodes</th><td id="A2.T9.2.4.2" class="ltx_td ltx_align_center">31 / 39 (79.5%)</td><td id="A2.T9.2.4.3" class="ltx_td ltx_nopad_r ltx_align_center">51 / 57 (89%)</td></tr><tr id="A2.T9.2.5" class="ltx_tr"><th id="A2.T9.2.5.1" class="ltx_td ltx_align_left ltx_th ltx_th_row">Baseline approach</th><td id="A2.T9.2.5.2" class="ltx_td ltx_align_center">Single LGB</td><td id="A2.T9.2.5.3" class="ltx_td ltx_nopad_r ltx_align_center">LGB regression</td></tr><tr id="A2.T9.2.6" class="ltx_tr"><th id="A2.T9.2.6.1" class="ltx_td ltx_align_left ltx_th ltx_th_row">Treatment approach</th><td id="A2.T9.2.6.2" class="ltx_td ltx_align_center">3-model ensemble</td><td id="A2.T9.2.6.3" class="ltx_td ltx_nopad_r ltx_align_center">Bagged ensemble + threshold opt.</td></tr><tr id="A2.T9.2.7" class="ltx_tr"><th id="A2.T9.2.7.1" class="ltx_td ltx_align_left ltx_th ltx_th_row ltx_border_bb">OOS <math id="A2.T9.m1" class="ltx_Math" alttext="\Delta" display="inline" intent=":literal"><semantics><mi mathvariant="normal">Δ</mi></semantics></math></th><td id="A2.T9.2.7.2" class="ltx_td ltx_align_center ltx_border_bb"><math id="A2.T9.m2" class="ltx_Math" alttext="+0.077" display="inline" intent=":literal"><semantics><mrow><mo>+</mo><mn>0.077</mn></mrow></semantics></math></td><td id="A2.T9.2.7.3" class="ltx_td ltx_nopad_r ltx_align_center ltx_border_bb"><math id="A2.T9.m3" class="ltx_Math" alttext="+0.099" display="inline" intent=":literal"><semantics><mrow><mo>+</mo><mn>0.099</mn></mrow></semantics></math></td></tr></tbody></table>

Table 9: Case study summary. The debug consultant’s primary effect is enabling iteration.

We find the same pattern in both cases: adaptive learning allows the LLM to iterate. A single valid node produces a first working draft. Dozens of valid nodes allow the agent to discover ensembles, calibration, problem reformulation, and threshold optimization.

### B.4 Full generated code

Below are the complete, unedited solutions generated by the LLM agent for both case studies. Each listing is the exact code that was executed and graded.

#### B.4.1 S5E3 seed 6 — Baseline (step 20, OOS = 0.875)

Note line 88: “no early stopping due to environment limitations”—the agent is aware of the API bug but cannot resolve it.

Baseline best solution: S5E3 seed 6 (141 lines). Single LGBMClassifier with basic feature engineering. No ensemble  no calibration  no early stopping.

1 #!/usr/bin/env python3

2 import os

3 import warnings

4 import numpy as np

5 import pandas as pd

6 from sklearn.model\_selection import StratifiedKFold

7 from sklearn.metrics import roc\_auc\_score

8 from lightgbm import LGBMClassifier

9

10 warnings.filterwarnings("ignore")

11

12 SEED \= 42

13 N\_SPLITS \= 5

14

15 # Paths

16 INPUT\_DIR \= "./input"

17 SUBMISSION\_DIR \= "./submission"

18 WORKING\_DIR \= "./working"

19 os.makedirs(SUBMISSION\_DIR, exist\_ok\=True)

20 os.makedirs(WORKING\_DIR, exist\_ok\=True)

21

22 # Load data

23 train\_path \= os.path.join(INPUT\_DIR, "train.csv")

24 test\_path \= os.path.join(INPUT\_DIR, "test.csv")

25

26 train \= pd.read\_csv(train\_path)

27 test \= pd.read\_csv(test\_path)

28

29

30 # Feature engineering

31 def prepare\_df(df):

32 df \= df.copy()

33 # day cyclic encoding (assume 365-day cycle)

34 if "day" in df.columns:

35 df\["day\_sin"\] \= np.sin(2 \* np.pi \* df\["day"\] / 365.0)

36 df\["day\_cos"\] \= np.cos(2 \* np.pi \* df\["day"\] / 365.0)

37 # temperature range

38 if {"maxtemp", "mintemp"}.issubset(df.columns):

39 df\["temp\_range"\] \= df\["maxtemp"\] \- df\["mintemp"\]

40 # dewpoint gap to temp (note column ’temparature’ exists in dataset)

41 if {"temparature", "dewpoint"}.issubset(df.columns):

42 df\["temp\_minus\_dew"\] \= df\["temparature"\] \- df\["dewpoint"\]

43 # pressure \* humidity interaction

44 if {"pressure", "humidity"}.issubset(df.columns):

45 df\["press\_hum"\] \= df\["pressure"\] \* df\["humidity"\] / 1e3

46 # wind \* cloud interaction

47 if {"windspeed", "cloud"}.issubset(df.columns):

48 df\["wind\_cloud"\] \= df\["windspeed"\] \* df\["cloud"\] / 100.0

49 return df

50

51

52 train \= prepare\_df(train)

53 test \= prepare\_df(test)

54

55 TARGET \= "rainfall"

56 ID\_COL \= "id"

57

58 # Features to use (exclude id, target)

59 excluded \= {ID\_COL, TARGET}

60 features \= \[c for c in train.columns if c not in excluded\]

61

62 # Ensure same engineered columns exist in test; if missing add zeros

63 for f in features:

64 if f not in test.columns:

65 test\[f\] \= 0.0

66

67 X \= train\[features\].reset\_index(drop\=True)

68 y \= train\[TARGET\].values

69 X\_test \= test\[features\].reset\_index(drop\=True)

70 test\_ids \= test\[ID\_COL\].values

71

72 # Fill NA just in case

73 X \= X.fillna(-999)

74 X\_test \= X\_test.fillna(-999)

75

76 # Prepare CV

77 skf \= StratifiedKFold(n\_splits\=N\_SPLITS, shuffle\=True, random\_state\=SEED)

78 oof \= np.zeros(len(X))

79 test\_preds \= np.zeros(len(X\_test))

80

81 fold\_aucs \= \[\]

82

83 # LGBMClassifier params (sklearn API) \- remove early stopping related args

84 model\_params \= {

85 "objective": "binary",

86 "boosting\_type": "gbdt",

87 "learning\_rate": 0.05,

88 "n\_estimators": 1000, # train full number of trees (no early stopping in this environment)

89 "num\_leaves": 31,

90 "min\_child\_samples": 20,

91 "subsample": 0.8,

92 "colsample\_bytree": 0.8,

93 "random\_state": SEED,

94 "n\_jobs": \-1,

95 "verbosity": \-1,

96 }

97

98 print(

99 "Starting CV training with LGBMClassifier (no early stopping due to environment limitations)..."

100 )

101

102 for fold, (tr\_idx, val\_idx) in enumerate(skf.split(X, y), 1):

103 print(f"\\nFold {fold}")

104 X\_tr, X\_val \= X.iloc\[tr\_idx\], X.iloc\[val\_idx\]

105 y\_tr, y\_val \= y\[tr\_idx\], y\[val\_idx\]

106

107 clf \= LGBMClassifier(\*\*model\_params)

108

109 # Fit without unsupported kwargs (no eval\_set / early\_stopping\_rounds)

110 clf.fit(X\_tr, y\_tr)

111

112 # Predict validation

113 val\_pred \= clf.predict\_proba(X\_val)\[:, 1\]

114 oof\[val\_idx\] \= val\_pred

115 fold\_auc \= roc\_auc\_score(y\_val, val\_pred)

116 fold\_aucs.append(fold\_auc)

117 print(f"Fold {fold} AUC: {fold\_auc:.6f}")

118

119 # Predict test

120 test\_pred \= clf.predict\_proba(X\_test)\[:, 1\]

121 test\_preds += test\_pred / N\_SPLITS

122

123 # Overall OOF AUC

124 oof\_auc \= roc\_auc\_score(y, oof)

125 print("\\nCross-validation results:")

126 print(f"OOF AUC: {oof\_auc:.6f}")

127 print(f"Mean fold AUC: {np.mean(fold\_aucs):.6f} Std: {np.std(fold\_aucs):.6f}")

128

129 # Prepare submission

130 submission \= pd.DataFrame({"id": test\_ids, "rainfall": test\_preds})

131 submission\_path \= os.path.join(SUBMISSION\_DIR, "submission.csv")

132 submission.to\_csv(submission\_path, index\=False)

133 # also save a copy in working for safety

134 submission.to\_csv(os.path.join(WORKING\_DIR, "submission.csv"), index\=False)

135

136 print(f"\\nSaved submission to {submission\_path}")

137 print("Submission head:")

138 print(submission.head())

139

140 # Print OOF AUC explicitly as the main evaluation metric

141 print(f"\\nFinal reported OOF ROC AUC: {oof\_auc:.6f}")

#### B.4.2 S5E3 seed 6 — Treatment (step 26, OOS = 0.952)

The treatment’s 31 valid iterations enable it to discover: (1) a 3-model ensemble (XGBoost + 2 LightGBM variants), (2) Platt-scaling calibration on each model’s OOF predictions, (3) greedy coordinate-ascent weight optimization in both probability-space and rank-space, and (4) automatic selection of the better ensemble via calibrated OOF AUC.

Treatment best solution: S5E3 seed 6 (437 lines). 3-model ensemble with Platt-scaling calibration  greedy weight optimization  and automatic ensemble selection.

1 #!/usr/bin/env python3

2 import os

3 import json

4 from pathlib import Path

5 import warnings

6 import numpy as np

7 import pandas as pd

8 from sklearn.model\_selection import StratifiedKFold, KFold

9 from sklearn.metrics import roc\_auc\_score

10 from sklearn.linear\_model import LogisticRegression

11 import xgboost as xgb

12 import lightgbm as lgb

13

14 warnings.filterwarnings("ignore")

15

16 # Config

17 SEED \= 42

18 N\_SPLITS \= 5

19 THREADS \= int(os.getenv("AIDE\_NUM\_THREADS", "22"))

20 INPUT\_DIR \= Path("input")

21 WORKING\_DIR \= Path("working")

22 WORKING\_DIR.mkdir(parents\=True, exist\_ok\=True)

23

24 TRAIN\_PATH \= INPUT\_DIR / "train.csv"

25 TEST\_PATH \= INPUT\_DIR / "test.csv"

26 SUBMISSION\_PATH \= WORKING\_DIR / "submission.csv"

27

28 # Model hyperparameters (compact, tuned for CPU)

29 XGB\_PARAMS \= {

30 "objective": "binary:logistic",

31 "eval\_metric": "auc",

32 "verbosity": 0,

33 "seed": SEED,

34 "eta": 0.03,

35 "max\_depth": 6,

36 "subsample": 0.8,

37 "colsample\_bytree": 0.8,

38 "nthread": THREADS,

39 "tree\_method": "hist",

40 }

41 XGB\_NUM\_ROUNDS \= 1000

42 XGB\_ESR \= 50

43

44 LGB\_PARAMS\_A \= {

45 "objective": "binary",

46 "metric": "auc",

47 "learning\_rate": 0.03,

48 "num\_leaves": 31,

49 "feature\_fraction": 0.8,

50 "bagging\_fraction": 0.8,

51 "bagging\_freq": 1,

52 "min\_data\_in\_leaf": 20,

53 "verbose": \-1,

54 "seed": SEED,

55 "num\_threads": THREADS,

56 }

57 LGB\_PARAMS\_B \= {

58 "objective": "binary",

59 "metric": "auc",

60 "learning\_rate": 0.02,

61 "num\_leaves": 64,

62 "feature\_fraction": 0.7,

63 "bagging\_fraction": 0.7,

64 "bagging\_freq": 1,

65 "min\_data\_in\_leaf": 15,

66 "min\_sum\_hessian\_in\_leaf": 1e\-3,

67 "verbose": \-1,

68 "seed": SEED + 1,

69 "num\_threads": THREADS,

70 }

71 LGB\_NUM\_ROUNDS \= 1000

72 LGB\_ESR \= 50

73

74 # Load data

75 train \= pd.read\_csv(TRAIN\_PATH)

76 test \= pd.read\_csv(TEST\_PATH)

77

78 TARGET \= "rainfall"

79 IDCOL \= "id"

80

81 # Feature setup

82 drop\_cols \= \[IDCOL, TARGET\]

83 features \= \[c for c in train.columns if c not in drop\_cols\]

84

85 # Cyclical features for ’day’ and ’winddirection’ if present

86 if "day" in features:

87 period \= 365.0

88 train\["day\_sin"\] \= np.sin(2 \* np.pi \* train\["day"\] / period)

89 train\["day\_cos"\] \= np.cos(2 \* np.pi \* train\["day"\] / period)

90 test\["day\_sin"\] \= np.sin(2 \* np.pi \* test\["day"\] / period)

91 test\["day\_cos"\] \= np.cos(2 \* np.pi \* test\["day"\] / period)

92 features \= \[f for f in features if f != "day"\] + \["day\_sin", "day\_cos"\]

93

94 if "winddirection" in features:

95 period \= 360.0

96 train\["winddir\_sin"\] \= np.sin(2 \* np.pi \* train\["winddirection"\] / period)

97 train\["winddir\_cos"\] \= np.cos(2 \* np.pi \* train\["winddirection"\] / period)

98 test\["winddir\_sin"\] \= np.sin(2 \* np.pi \* test\["winddirection"\] / period)

99 test\["winddir\_cos"\] \= np.cos(2 \* np.pi \* test\["winddirection"\] / period)

100 features \= \[f for f in features if f != "winddirection"\] + \[

101 "winddir\_sin",

102 "winddir\_cos",

103 \]

104

105 # Ensure features present in both

106 features \= \[f for f in features if f in train.columns and f in test.columns\]

107

108 # Missing count feature

109 train\["\_missing\_count"\] \= train\[features\].isnull().sum(axis\=1)

110 test\["\_missing\_count"\] \= test\[features\].isnull().sum(axis\=1)

111

112 # Convert object columns to category codes safely

113 for col in features:

114 if train\[col\].dtype \== "object":

115 combined \= pd.concat(\[train\[col\], test\[col\]\], axis\=0).astype("category")

116 train\[col\] \= combined.iloc\[: len(train)\].cat.codes

117 test\[col\] \= combined.iloc\[len(train) :\].cat.codes

118

119 # Numeric columns and median imputation

120 train\_nums \= train\[features\].select\_dtypes(include\=\[np.number\]).columns.tolist()

121 medians \= train\[train\_nums\].median()

122 train\[train\_nums\] \= train\[train\_nums\].fillna(medians)

123 test\[train\_nums\] \= test\[train\_nums\].fillna(medians)

124

125 # Row-level stats

126 train\["\_row\_mean"\] \= train\[train\_nums\].mean(axis\=1)

127 train\["\_row\_std"\] \= train\[train\_nums\].std(axis\=1).fillna(0.0)

128 test\["\_row\_mean"\] \= test\[train\_nums\].mean(axis\=1)

129 test\["\_row\_std"\] \= test\[train\_nums\].std(axis\=1).fillna(0.0)

130

131 # Per-column percentile rank aggregated as a row feature.

132 rank\_cols \= train\_nums.copy()

133 if len(rank\_cols) \> 0:

134 combined\_ranks \= \[\]

135 for col in rank\_cols:

136 combined \= pd.concat(\[train\[col\], test\[col\]\], axis\=0)

137 ranks \= combined.rank(pct\=True, method\="average")

138 combined\_ranks.append(ranks.values)

139 combined\_ranks \= np.vstack(combined\_ranks).T

140 n\_train \= train.shape\[0\]

141 train\_ranks \= combined\_ranks\[:n\_train\]

142 test\_ranks \= combined\_ranks\[n\_train:\]

143 train\["\_row\_rank\_mean"\] \= np.nanmean(train\_ranks, axis\=1)

144 test\["\_row\_rank\_mean"\] \= np.nanmean(test\_ranks, axis\=1)

145 else:

146 train\["\_row\_rank\_mean"\] \= 0.0

147 test\["\_row\_rank\_mean"\] \= 0.0

148

149 engineered \= \["\_missing\_count", "\_row\_mean", "\_row\_std", "\_row\_rank\_mean"\]

150 for f in engineered:

151 if f not in features:

152 features.append(f)

153

154 features \= \[f for f in features if f in train.columns and f in test.columns\]

155

156 # Remove constant features

157 const\_feats \= \[f for f in features if train\[f\].nunique() <= 1\]

158 if const\_feats:

159 features \= \[f for f in features if f not in const\_feats\]

160

161 # Remove near-duplicate features by very high correlation (>0.999)

162 if len(features) \> 1:

163 corr\_matrix \= train\[features\].corr().abs()

164 upper \= corr\_matrix.where(np.triu(np.ones(corr\_matrix.shape), k\=1).astype(bool))

165 to\_drop \= \[column for column in upper.columns if any(upper\[column\] \> 0.999)\]

166 if to\_drop:

167 features \= \[f for f in features if f not in to\_drop\]

168

169 features \= \[f for f in features if f in train.columns and f in test.columns\]

170

171 X \= train\[features\].copy()

172 X\_test \= test\[features\].copy()

173 y \= train\[TARGET\].astype(int).values

174 ids\_test \= test\[IDCOL\].values

175

176 # Cross-validation splitter

177 min\_class\_count \= pd.Series(y).value\_counts().min()

178 if min\_class\_count \>= N\_SPLITS:

179 cv \= StratifiedKFold(n\_splits\=N\_SPLITS, shuffle\=True, random\_state\=SEED)

180 else:

181 cv \= KFold(n\_splits\=N\_SPLITS, shuffle\=True, random\_state\=SEED)

182

183 X\_values \= X.values

184 X\_test\_values \= X\_test.values

185

186 # Base models: XGBoost, LGB A, LGB B (single-seed to save time)

187 model\_keys \= \["xgb", "lgb\_a", "lgb\_b"\]

188 oof\_preds \= {k: np.zeros(X\_values.shape\[0\], dtype\=float) for k in model\_keys}

189 test\_preds\_avg \= {k: np.zeros(X\_test\_values.shape\[0\], dtype\=float) for k in model\_keys}

190

191 fold\_info \= \[\]

192

193 for fold, (tr\_idx, val\_idx) in enumerate(cv.split(X\_values, y), start\=1):

194 X\_tr, X\_val \= X\_values\[tr\_idx\], X\_values\[val\_idx\]

195 y\_tr, y\_val \= y\[tr\_idx\], y\[val\_idx\]

196

197 pos \= int(y\_tr.sum())

198 neg \= int(y\_tr.shape\[0\] \- pos)

199 scale\_pos\_weight \= max(1.0, neg / max(1.0, pos))

200

201 # XGBoost

202 xgb\_params \= XGB\_PARAMS.copy()

203 xgb\_params\["scale\_pos\_weight"\] \= scale\_pos\_weight

204 xgb\_params\["seed"\] \= int(SEED)

205 dtrain \= xgb.DMatrix(X\_tr, label\=y\_tr, feature\_names\=features)

206 dval \= xgb.DMatrix(X\_val, label\=y\_val, feature\_names\=features)

207 dtest \= xgb.DMatrix(X\_test\_values, feature\_names\=features)

208 xgb\_model \= xgb.train(

209 xgb\_params,

210 dtrain,

211 num\_boost\_round\=XGB\_NUM\_ROUNDS,

212 evals\=\[(dtrain, "train"), (dval, "val")\],

213 early\_stopping\_rounds\=XGB\_ESR,

214 verbose\_eval\=False,

215 )

216 if hasattr(xgb\_model, "best\_iteration") and xgb\_model.best\_iteration is not None:

217 xgb\_rounds \= int(xgb\_model.best\_iteration) + 1

218 else:

219 xgb\_rounds \= XGB\_NUM\_ROUNDS

220 val\_pred\_xgb \= xgb\_model.predict(dval, iteration\_range\=(0, xgb\_rounds))

221 test\_pred\_xgb \= xgb\_model.predict(dtest, iteration\_range\=(0, xgb\_rounds))

222 oof\_preds\["xgb"\]\[val\_idx\] \= val\_pred\_xgb

223 test\_preds\_avg\["xgb"\] += test\_pred\_xgb / N\_SPLITS

224

225 # LightGBM A

226 lgb\_params\_a \= LGB\_PARAMS\_A.copy()

227 lgb\_params\_a\["scale\_pos\_weight"\] \= scale\_pos\_weight

228 lgb\_params\_a\["seed"\] \= int(SEED)

229 ltrain \= lgb.Dataset(X\_tr, label\=y\_tr, feature\_name\=features)

230 lval \= lgb.Dataset(X\_val, label\=y\_val, reference\=ltrain, feature\_name\=features)

231 lgb\_model\_a \= lgb.train(

232 lgb\_params\_a,

233 ltrain,

234 num\_boost\_round\=LGB\_NUM\_ROUNDS,

235 valid\_sets\=\[ltrain, lval\],

236 valid\_names\=\["train", "val"\],

237 callbacks\=\[lgb.early\_stopping(stopping\_rounds\=LGB\_ESR)\],

238 )

239 lgb\_a\_iter \= (

240 lgb\_model\_a.best\_iteration

241 if hasattr(lgb\_model\_a, "best\_iteration")

242 else LGB\_NUM\_ROUNDS

243 )

244 val\_pred\_lgb\_a \= lgb\_model\_a.predict(X\_val, num\_iteration\=lgb\_a\_iter)

245 test\_pred\_lgb\_a \= lgb\_model\_a.predict(X\_test\_values, num\_iteration\=lgb\_a\_iter)

246 oof\_preds\["lgb\_a"\]\[val\_idx\] \= val\_pred\_lgb\_a

247 test\_preds\_avg\["lgb\_a"\] += test\_pred\_lgb\_a / N\_SPLITS

248

249 # LightGBM B

250 lgb\_params\_b \= LGB\_PARAMS\_B.copy()

251 lgb\_params\_b\["scale\_pos\_weight"\] \= scale\_pos\_weight

252 lgb\_params\_b\["seed"\] \= int(SEED + 1)

253 ltrain\_b \= lgb.Dataset(X\_tr, label\=y\_tr, feature\_name\=features)

254 lval\_b \= lgb.Dataset(X\_val, label\=y\_val, reference\=ltrain\_b, feature\_name\=features)

255 lgb\_model\_b \= lgb.train(

256 lgb\_params\_b,

257 ltrain\_b,

258 num\_boost\_round\=LGB\_NUM\_ROUNDS,

259 valid\_sets\=\[ltrain\_b, lval\_b\],

260 valid\_names\=\["train", "val"\],

261 callbacks\=\[lgb.early\_stopping(stopping\_rounds\=LGB\_ESR)\],

262 )

263 lgb\_b\_iter \= (

264 lgb\_model\_b.best\_iteration

265 if hasattr(lgb\_model\_b, "best\_iteration")

266 else LGB\_NUM\_ROUNDS

267 )

268 val\_pred\_lgb\_b \= lgb\_model\_b.predict(X\_val, num\_iteration\=lgb\_b\_iter)

269 test\_pred\_lgb\_b \= lgb\_model\_b.predict(X\_test\_values, num\_iteration\=lgb\_b\_iter)

270 oof\_preds\["lgb\_b"\]\[val\_idx\] \= val\_pred\_lgb\_b

271 test\_preds\_avg\["lgb\_b"\] += test\_pred\_lgb\_b / N\_SPLITS

272

273 fold\_auc\_vals \= tuple(

274 float(roc\_auc\_score(y\_val, oof\_preds\[k\]\[val\_idx\])) for k in model\_keys

275 )

276 print(

277 f"Fold {fold}: "

278 + ", ".join(

279 \[f"{k.upper()} AUC={a:.6f}" for k, a in zip(model\_keys, fold\_auc\_vals)\]

280 )

281 )

282 fold\_info.append(fold\_auc\_vals)

283

284 # Base OOF AUCs

285 auc\_oof \= {k: float(roc\_auc\_score(y, oof\_preds\[k\])) for k in model\_keys}

286 print("Base OOF AUCs:", auc\_oof)

287

288 # Calibrate each base with Platt-scaling (LogisticRegression) on OOF

289 calibrators \= {}

290 calibrated\_oof \= {}

291 calibrated\_test \= {}

292 for key in model\_keys:

293 clf \= LogisticRegression(solver\="lbfgs", max\_iter\=2000, random\_state\=SEED)

294 preds \= oof\_preds\[key\].reshape(-1, 1)

295 clf.fit(preds, y)

296 calibrated \= clf.predict\_proba(preds)\[:, 1\]

297 calibrated\_oof\[key\] \= calibrated

298 calibrated\_test\[key\] \= clf.predict\_proba(test\_preds\_avg\[key\].reshape(-1, 1))\[:, 1\]

299 calibrators\[key\] \= clf

300 auc\_cal \= float(roc\_auc\_score(y, calibrated))

301 print(f"Calibrated OOF AUC for {key}: {auc\_cal:.6f}")

302

303 # Prepare rank-space OOFs (percentile ranks of calibrated probs)

304 calibrated\_oof\_rank \= {}

305 for k in model\_keys:

306 calibrated\_oof\_rank\[k\] \= pd.Series(calibrated\_oof\[k\]).rank(pct\=True).values

307

308

309 # Greedy coordinate-ascent weight search function

310 def greedy\_optimize(keys, oof\_dict, y, init\=None, max\_iters\=200):

311 n \= len(keys)

312 if init is None:

313 weights \= np.array(\[1.0 / n\] \* n, dtype\=float)

314 else:

315 weights \= np.array(init, dtype\=float)

316 if weights.sum() <= 0:

317 weights \= np.array(\[1.0 / n\] \* n, dtype\=float)

318 else:

319 weights \= weights / weights.sum()

320 best\_auc \= roc\_auc\_score(y, sum(weights\[i\] \* oof\_dict\[keys\[i\]\] for i in range(n)))

321 improved \= True

322 iters \= 0

323 while improved and iters < max\_iters:

324 improved \= False

325 iters += 1

326 for i in range(n):

327 for delta in \[0.1, 0.05, 0.02, 0.01, \-0.01, \-0.02, \-0.05, \-0.1\]:

328 w\_new \= weights.copy()

329 w\_new\[i\] \= max(0.0, w\_new\[i\] + delta)

330 if w\_new.sum() <= 0:

331 continue

332 w\_new \= w\_new / w\_new.sum()

333 ensemble\_oof \= sum(w\_new\[j\] \* oof\_dict\[keys\[j\]\] for j in range(n))

334 auc \= roc\_auc\_score(y, ensemble\_oof)

335 if auc \> best\_auc + 1e\-9:

336 best\_auc \= auc

337 weights \= w\_new

338 improved \= True

339 return weights, best\_auc

340

341

342 keys \= model\_keys.copy()

343

344 # Optimize in probability-space

345 weights\_prob, auc\_prob \= greedy\_optimize(keys, calibrated\_oof, y, max\_iters\=200)

346 print(

347 f"Optimized weights (prob-space): {dict(zip(keys, weights\_prob.round(4)))} OOF AUC: {auc\_prob:.6f}"

348 )

349

350 # Optimize in rank-space

351 weights\_rank, auc\_rank \= greedy\_optimize(keys, calibrated\_oof\_rank, y, max\_iters\=200)

352 print(

353 f"Optimized weights (rank-space): {dict(zip(keys, weights\_rank.round(4)))} OOF AUC: {auc\_rank:.6f}"

354 )

355

356 # Build ensembles

357 oof\_prob\_ens \= sum(weights\_prob\[i\] \* calibrated\_oof\[keys\[i\]\] for i in range(len(keys)))

358 test\_prob\_ens \= sum(

359 weights\_prob\[i\] \* calibrated\_test\[keys\[i\]\] for i in range(len(keys))

360 )

361

362 oof\_rank\_ens \= sum(

363 weights\_rank\[i\] \* calibrated\_oof\_rank\[keys\[i\]\] for i in range(len(keys))

364 )

365 # convert rank ensemble to pseudo-prob by scaling between 0-1 (already 0-1)

366 test\_rank\_parts \= {}

367 for k in keys:

368 # get percentile ranks for test calibrated probs

369 test\_rank\_parts\[k\] \= pd.Series(calibrated\_test\[k\]).rank(pct\=True).values

370 test\_rank\_ens \= sum(

371 weights\_rank\[i\] \* test\_rank\_parts\[keys\[i\]\] for i in range(len(keys))

372 )

373

374 # Evaluate which ensemble is better by OOF AUC

375 auc\_prob\_raw \= roc\_auc\_score(y, oof\_prob\_ens)

376 auc\_rank\_raw \= roc\_auc\_score(y, oof\_rank\_ens)

377 print(

378 f"Raw ensemble OOF AUCs \-> prob-space: {auc\_prob\_raw:.6f}, rank-space: {auc\_rank\_raw:.6f}"

379 )

380

381 # Final Platt calibration for both ensembles

382 final\_cal\_prob \= LogisticRegression(solver\="lbfgs", max\_iter\=2000, random\_state\=SEED)

383 final\_cal\_prob.fit(oof\_prob\_ens.reshape(-1, 1), y)

384 oof\_prob\_cal \= final\_cal\_prob.predict\_proba(oof\_prob\_ens.reshape(-1, 1))\[:, 1\]

385 test\_prob\_cal \= final\_cal\_prob.predict\_proba(test\_prob\_ens.reshape(-1, 1))\[:, 1\]

386 auc\_prob\_cal \= roc\_auc\_score(y, oof\_prob\_cal)

387 print(f"Final calibrated prob-space ensemble OOF AUC: {auc\_prob\_cal:.6f}")

388

389 final\_cal\_rank \= LogisticRegression(solver\="lbfgs", max\_iter\=2000, random\_state\=SEED)

390 final\_cal\_rank.fit(oof\_rank\_ens.reshape(-1, 1), y)

391 oof\_rank\_cal \= final\_cal\_rank.predict\_proba(oof\_rank\_ens.reshape(-1, 1))\[:, 1\]

392 test\_rank\_cal \= final\_cal\_rank.predict\_proba(test\_rank\_ens.reshape(-1, 1))\[:, 1\]

393 auc\_rank\_cal \= roc\_auc\_score(y, oof\_rank\_cal)

394 print(f"Final calibrated rank-space ensemble OOF AUC: {auc\_rank\_cal:.6f}")

395

396 # Choose best

397 if auc\_prob\_cal \>= auc\_rank\_cal:

398 chosen\_name \= "prob\_space\_ensemble"

399 oof\_final \= oof\_prob\_cal

400 test\_final \= test\_prob\_cal

401 chosen\_auc \= auc\_prob\_cal

402 else:

403 chosen\_name \= "rank\_space\_ensemble"

404 oof\_final \= oof\_rank\_cal

405 test\_final \= test\_rank\_cal

406 chosen\_auc \= auc\_rank\_cal

407

408 print(f"Chosen ensemble: {chosen\_name} with OOF AUC: {chosen\_auc:.6f}")

409

410 # Compute per-fold AUCs for chosen final predictions

411 fold\_scores \= \[\]

412 for fold, (\_, val\_idx) in enumerate(cv.split(X\_values, y), start\=1):

413 fold\_auc \= float(roc\_auc\_score(y\[val\_idx\], oof\_final\[val\_idx\]))

414 fold\_scores.append(fold\_auc)

415 print(f"Fold {fold} AUC (final): {fold\_auc:.6f}")

416

417 cv\_mean \= float(np.mean(fold\_scores))

418 cv\_std \= float(np.std(fold\_scores))

419 print(f"Final CV mean AUC: {cv\_mean:.6f} std: {cv\_std:.6f}")

420

421 # Save submission

422 submission \= pd.DataFrame({IDCOL: ids\_test, TARGET: test\_final})

423 submission.to\_csv(SUBMISSION\_PATH, index\=False)

424 print(f"Saved submission to: {SUBMISSION\_PATH}")

425

426 # Output AIDE metrics line

427 aide\_metrics \= {

428 "valid": True,

429 "lower\_is\_better": False,

430 "cv\_mean": cv\_mean,

431 "cv\_std": cv\_std,

432 "cv\_folds": \[float(f) for f in fold\_scores\],

433 }

434 print("AIDE\_METRICS\_JSON=" + json.dumps(aide\_metrics))

435

436 # Print final metric line

437 print(f"Final CV mean AUC: {cv\_mean:.6f}")

#### B.4.3 Wine Quality Seed 1 — Baseline (step 7, OOS = 0.299)

The baseline uses LGBMRegressor with naive rounding—a regression formulation that discards inter-class probability information, fundamentally limiting QWK.

Baseline best solution: Wine Quality seed 1. LGBMRegressor with regression formulation and naive rounding.

1 import os

2 import numpy as np

3 import pandas as pd

4 from sklearn.model\_selection import StratifiedKFold

5 import lightgbm as lgb

6 from sklearn.metrics import confusion\_matrix

7

8 # Set random seed

9 RANDOM\_STATE \= 42

10 np.random.seed(RANDOM\_STATE)

11

12 # Paths

13 INPUT\_DIR \= "./input"

14 TRAIN\_PATH \= os.path.join(INPUT\_DIR, "train.csv")

15 TEST\_PATH \= os.path.join(INPUT\_DIR, "test.csv")

16 SUBMISSION\_DIR \= "./submission"

17 SUBMISSION\_PATH \= os.path.join(SUBMISSION\_DIR, "submission.csv")

18

19 # Read data

20 train \= pd.read\_csv(TRAIN\_PATH)

21 test \= pd.read\_csv(TEST\_PATH)

22

23 # Features and target

24 feature\_cols \= \[c for c in train.columns if c not in ("Id", "quality")\]

25 X \= train\[feature\_cols\].copy()

26 y \= train\["quality"\].astype(int).copy()

27 X\_test \= test\[feature\_cols\].copy()

28 test\_ids \= test\["Id"\].astype(int).copy()

29

30 # Determine label range

31 label\_min \= int(y.min())

32 label\_max \= int(y.max())

33 labels\_sorted \= np.arange(label\_min, label\_max + 1)

34

35

36 # Quadratic Weighted Kappa implementation

37 def quadratic\_weighted\_kappa(y\_true, y\_pred, min\_rating\=None, max\_rating\=None):

38 """

39 Compute Quadratic Weighted Kappa (QWK)

40 """

41 if min\_rating is None:

42 min\_rating \= min(int(np.min(y\_true)), int(np.min(y\_pred)))

43 if max\_rating is None:

44 max\_rating \= max(int(np.max(y\_true)), int(np.max(y\_pred)))

45 y\_true \= np.array(y\_true, dtype\=int)

46 y\_pred \= np.array(y\_pred, dtype\=int)

47 num\_ratings \= int(max\_rating \- min\_rating + 1)

48 # Confusion matrix O

49 O \= np.zeros((num\_ratings, num\_ratings), dtype\=float)

50 for a, b in zip(y\_true, y\_pred):

51 O\[a \- min\_rating, b \- min\_rating\] += 1

52 # Histogram of ratings

53 hist\_true \= O.sum(axis\=1)

54 hist\_pred \= O.sum(axis\=0)

55 # Expected matrix E

56 E \= np.outer(hist\_true, hist\_pred)

57 if E.sum() \== 0:

58 return 1.0

59 E \= E / E.sum() \* O.sum()

60 # Weight matrix

61 W \= np.zeros((num\_ratings, num\_ratings), dtype\=float)

62 for i in range(num\_ratings):

63 for j in range(num\_ratings):

64 W\[i, j\] \= ((i \- j) \*\* 2) / ((num\_ratings \- 1) \*\* 2)

65 # QWK

66 num \= (W \* O).sum()

67 den \= (W \* E).sum()

68 if den \== 0:

69 return 1.0

70 return 1.0 \- num / den

71

72

73 # 5-fold stratified by label

74 n\_splits \= 5

75 skf \= StratifiedKFold(n\_splits\=n\_splits, shuffle\=True, random\_state\=RANDOM\_STATE)

76

77 oof\_preds \= np.zeros(len(X), dtype\=float)

78 test\_preds \= np.zeros(len(X\_test), dtype\=float)

79 fold\_qwks \= \[\]

80

81 # LightGBM parameters \- use scikit-learn API without early\_stopping\_rounds in fit

82 lgb\_params \= {

83 "objective": "regression",

84 "boosting\_type": "gbdt",

85 "learning\_rate": 0.05,

86 "n\_estimators": 800, # fixed number of trees; no early stopping in fit to avoid compatibility issues

87 "random\_state": RANDOM\_STATE,

88 "num\_leaves": 31,

89 "subsample": 0.8,

90 "colsample\_bytree": 0.8,

91 "reg\_alpha": 0.0,

92 "reg\_lambda": 1.0,

93 "verbosity": \-1,

94 }

95

96 print("Starting 5-fold CV training (no early stopping in fit)...")

97 for fold, (train\_idx, val\_idx) in enumerate(skf.split(X, y), 1):

98 X\_train, X\_val \= X.iloc\[train\_idx\], X.iloc\[val\_idx\]

99 y\_train, y\_val \= y.iloc\[train\_idx\], y.iloc\[val\_idx\]

100 model \= lgb.LGBMRegressor(\*\*lgb\_params)

101 # Fit without early\_stopping\_rounds to avoid the TypeError seen previously

102 model.fit(

103 X\_train,

104 y\_train,

105 eval\_set\=\[(X\_val, y\_val)\],

106 eval\_metric\="rmse",

107 )

108 # Predict (do not use num\_iteration parameter which may not be available)

109 val\_pred \= model.predict(X\_val)

110 oof\_preds\[val\_idx\] \= val\_pred

111 test\_pred \= model.predict(X\_test)

112 test\_preds += test\_pred / n\_splits

113

114 # Convert to discrete for QWK

115 val\_pred\_round \= np.rint(val\_pred).astype(int)

116 val\_pred\_round \= np.clip(val\_pred\_round, label\_min, label\_max)

117 qwk \= quadratic\_weighted\_kappa(

118 y\_val.values, val\_pred\_round, min\_rating\=label\_min, max\_rating\=label\_max

119 )

120 fold\_qwks.append(qwk)

121 print(f"Fold {fold} QWK: {qwk:.5f}")

122

123 # Overall OOF QWK

124 oof\_preds\_round \= np.rint(oof\_preds).astype(int)

125 oof\_preds\_round \= np.clip(oof\_preds\_round, label\_min, label\_max)

126 oof\_qwk \= quadratic\_weighted\_kappa(

127 y.values, oof\_preds\_round, min\_rating\=label\_min, max\_rating\=label\_max

128 )

129 print(f"OOF QWK: {oof\_qwk:.5f}")

130 print(f"Mean per-fold QWK: {np.mean(fold\_qwks):.5f} (std {np.std(fold\_qwks):.5f})")

131

132 # Prepare final test predictions

133 final\_test\_preds \= np.rint(test\_preds).astype(int)

134 final\_test\_preds \= np.clip(final\_test\_preds, label\_min, label\_max)

135

136 # Create submission dataframe

137 submission\_df \= pd.DataFrame({"Id": test\_ids.values, "quality": final\_test\_preds})

138 # Ensure submission directory exists

139 os.makedirs(SUBMISSION\_DIR, exist\_ok\=True)

140 submission\_df.to\_csv(SUBMISSION\_PATH, index\=False)

141

142 print(f"Saved submission to {SUBMISSION\_PATH}")

143 print("Sample of submission:")

144 print(submission\_df.head(10).to\_string(index\=False))

#### B.4.4 Wine Quality Seed 1 — Treatment (step 38, OOS = 0.398)

With 51 valid iterations, the treatment discovers that a diverse bagged LightGBM ensemble with stacking (Ridge + Isotonic regression on out-of-fold predictions) produces substantially higher QWK than the baseline’s single-model regression approach.

Treatment best solution: Wine Quality seed 1. Diverse bagged LightGBM ensemble with stacking.

1 #!/usr/bin/env python3

2 import os

3 import json

4 import math

5 import numpy as np

6 import pandas as pd

7 from itertools import combinations

8 from sklearn.model\_selection import StratifiedKFold, KFold

9 from sklearn.metrics import cohen\_kappa\_score

10 from sklearn.linear\_model import Ridge

11 from sklearn.isotonic import IsotonicRegression

12 import lightgbm as lgb

13 import warnings

14

15 warnings.filterwarnings("ignore")

16

17 # Config

18 SEED \= 42

19 NUM\_FOLDS \= 5

20 LGB\_ROUNDS \= 2000

21 EARLY\_STOPPING \= 100

22 THREADS \= int(os.getenv("AIDE\_NUM\_THREADS", "22"))

23 INPUT\_DIR \= "input"

24 TRAIN\_PATH \= os.path.join(INPUT\_DIR, "train.csv")

25 TEST\_PATH \= os.path.join(INPUT\_DIR, "test.csv")

26 SUBMISSION\_PATH \= os.path.join("working", "submission.csv")

27

28 np.random.seed(SEED)

29

30 # Load data

31 train \= pd.read\_csv(TRAIN\_PATH)

32 test \= pd.read\_csv(TEST\_PATH)

33

34 FEATURES \= \[c for c in train.columns if c not in ("id", "quality")\]

35 X\_orig \= train\[FEATURES\].copy()

36 X\_test\_orig \= test\[FEATURES\].copy()

37 test\_ids \= test\["id"\].astype(int).values

38

39 y\_raw \= train\["quality"\].astype(int).values

40 unique\_classes \= np.sort(train\["quality"\].unique())

41 n\_classes \= len(unique\_classes)

42 n\_train \= len(train)

43 n\_test \= len(test)

44

45

46 # Safe feature engineering (no target leakage)

47 def add\_features(df):

48 df2 \= df.copy()

49 for c in df.columns:

50 col \= df\[c\]

51 if pd.api.types.is\_numeric\_dtype(col):

52 if (col \> 0).all():

53 df2\[c + "\_log1p"\] \= np.log1p(col)

54 else:

55 df2\[c + "\_rankpct"\] \= col.rank(pct\=True).astype(float)

56 # square

57 df2\[c + "\_sq"\] \= col.values \* col.values

58 return df2

59

60

61 X \= add\_features(X\_orig)

62 X\_test \= add\_features(X\_test\_orig)

63

64 # pairwise products among top-k variance original features (produce train/test separately)

65 num\_feats \= \[c for c in X\_orig.columns if pd.api.types.is\_numeric\_dtype(X\_orig\[c\])\]

66 variances \= \[(c, X\_orig\[c\].var()) for c in num\_feats\]

67 variances.sort(key\=lambda x: x\[1\], reverse\=True)

68 top\_k \= min(5, len(variances))

69 top\_features \= \[c for c, \_ in variances\[:top\_k\]\]

70

71 for a, b in combinations(top\_features, 2):

72 name \= f"{a}\_x\_{b}"

73 X\[name\] \= X\_orig\[a\].values \* X\_orig\[b\].values

74 X\_test\[name\] \= X\_test\_orig\[a\].values \* X\_test\_orig\[b\].values

75

76 FEATURES\_FE \= \[c for c in X.columns\]

77

78 # CV splitter safe (stratify if every class has enough samples)

79 use\_strat \= True

80 for cls in unique\_classes:

81 if (y\_raw \== cls).sum() < NUM\_FOLDS:

82 use\_strat \= False

83 break

84

85 if use\_strat:

86 kf \= StratifiedKFold(n\_splits\=NUM\_FOLDS, shuffle\=True, random\_state\=SEED)

87 splits \= list(kf.split(X, y\_raw))

88 else:

89 kf \= KFold(n\_splits\=NUM\_FOLDS, shuffle\=True, random\_state\=SEED)

90 splits \= list(kf.split(X))

91

92 # Base LightGBM variants and seeds (bagging)

93 lgb\_variants \= \[

94 {

95 "objective": "regression",

96 "metric": "rmse",

97 "learning\_rate": 0.05,

98 "num\_leaves": 31,

99 "max\_depth": 6,

100 "feature\_fraction": 0.8,

101 "bagging\_fraction": 0.8,

102 "bagging\_freq": 1,

103 },

104 {

105 "objective": "regression",

106 "metric": "rmse",

107 "learning\_rate": 0.03,

108 "num\_leaves": 63,

109 "max\_depth": 8,

110 "feature\_fraction": 0.7,

111 "bagging\_fraction": 0.7,

112 "bagging\_freq": 1,

113 },

114 {

115 "objective": "regression",

116 "metric": "rmse",

117 "learning\_rate": 0.07,

118 "num\_leaves": 24,

119 "max\_depth": 5,

120 "feature\_fraction": 0.9,

121 "bagging\_fraction": 0.9,

122 "bagging\_freq": 1,

123 },

124 \]

125 lgb\_seeds \= \[SEED, SEED + 101\]

126

127 # Build model configs (only LGB for speed and robustness)

128 model\_configs \= \[\]

129 for vid, var in enumerate(lgb\_variants):

130 for sd in lgb\_seeds:

131 model\_configs.append(("lgb", vid, int(sd)))

132 n\_models \= len(model\_configs)

133

134 # Storage

135 oof\_stack \= np.zeros((n\_train, n\_models), dtype\=float)

136 test\_stack\_sum \= np.zeros((n\_test, n\_models), dtype\=float)

137 test\_stack\_count \= np.zeros(n\_models, dtype\=int)

138

139 # Train base models in CV

140 print("Training base LightGBM ensemble...")

141 for fold, (tr\_idx, val\_idx) in enumerate(splits):

142 print(f" Fold {fold+1}/{NUM\_FOLDS}")

143 X\_tr \= X.iloc\[tr\_idx\].reset\_index(drop\=True)

144 X\_val \= X.iloc\[val\_idx\].reset\_index(drop\=True)

145 y\_tr \= y\_raw\[tr\_idx\]

146 y\_val \= y\_raw\[val\_idx\]

147

148 for m\_idx, (mtype, vid, sd) in enumerate(model\_configs):

149 # Train LGB

150 params \= lgb\_variants\[vid\].copy()

151 params.update(

152 {

153 "seed": int(sd + fold),

154 "verbosity": \-1,

155 "num\_threads": THREADS,

156 }

157 )

158 lgb\_train \= lgb.Dataset(X\_tr, label\=y\_tr)

159 lgb\_valid \= lgb.Dataset(X\_val, label\=y\_val, reference\=lgb\_train)

160 model \= lgb.train(

161 params,

162 lgb\_train,

163 num\_boost\_round\=LGB\_ROUNDS,

164 valid\_sets\=\[lgb\_train, lgb\_valid\],

165 valid\_names\=\["train", "valid"\],

166 callbacks\=\[

167 lgb.early\_stopping(stopping\_rounds\=EARLY\_STOPPING),

168 lgb.log\_evaluation(period\=0),

169 \],

170 )

171 best\_iter \= getattr(model, "best\_iteration", None)

172 if best\_iter is None:

173 # fallback to current\_iteration

174 try:

175 best\_iter \= model.current\_iteration()

176 except Exception:

177 best\_iter \= LGB\_ROUNDS

178 # predictions

179 val\_pred \= model.predict(X\_val, num\_iteration\=best\_iter)

180 test\_pred \= model.predict(X\_test, num\_iteration\=best\_iter)

181

182 oof\_stack\[val\_idx, m\_idx\] \= val\_pred

183 test\_stack\_sum\[:, m\_idx\] += test\_pred

184 test\_stack\_count\[m\_idx\] += 1

185

186 # Finalize per-model test stacks (average)

187 test\_stack \= np.zeros\_like(test\_stack\_sum)

188 for m in range(n\_models):

189 cnt \= test\_stack\_count\[m\]

190 if cnt \> 0:

191 test\_stack\[:, m\] \= test\_stack\_sum\[:, m\] / float(cnt)

192 else:

193 test\_stack\[:, m\] \= 0.0

194

195 # Meta model: Ridge on stacked OOF features

196 meta\_oof \= np.zeros(n\_train, dtype\=float)

197 meta\_test\_preds\_folds \= np.zeros((NUM\_FOLDS, n\_test), dtype\=float)

198

199 for fold, (tr\_idx, val\_idx) in enumerate(splits):

200 X\_meta\_tr \= oof\_stack\[tr\_idx\]

201 y\_meta\_tr \= y\_raw\[tr\_idx\]

202 X\_meta\_val \= oof\_stack\[val\_idx\]

203 meta \= Ridge(alpha\=1.0, random\_state\=SEED)

204 meta.fit(X\_meta\_tr, y\_meta\_tr)

205 meta\_oof\[val\_idx\] \= meta.predict(X\_meta\_val)

206 meta\_test\_preds\_folds\[fold\] \= meta.predict(test\_stack)

207

208 # Final meta trained on all OOF

209 meta\_final \= Ridge(alpha\=1.0, random\_state\=SEED)

210 meta\_final.fit(oof\_stack, y\_raw)

211 meta\_test\_pred \= meta\_final.predict(test\_stack)

212

213 # Isotonic calibration on meta\_oof \-> y\_raw (fit only on OOF)

214 iso \= IsotonicRegression(out\_of\_bounds\="clip")

215 try:

216 iso.fit(meta\_oof, y\_raw)

217 meta\_oof\_cal \= iso.predict(meta\_oof)

218 meta\_test\_cal \= iso.predict(meta\_test\_pred)

219 except Exception:

220 meta\_oof\_cal \= meta\_oof.copy()

221 meta\_test\_cal \= meta\_test\_pred.copy()

222

223 # Linear scale+shift calibration on OOF (fit to maximize simple squared alignment but we will still optimize thresholds for QWK)

224 # Fit linear regression (a\*x + b) on OOF to best fit y in least squares (fast, no leakage)

225 a \= 1.0

226 b \= 0.0

227 try:

228 A \= np.vstack(\[meta\_oof\_cal, np.ones\_like(meta\_oof\_cal)\]).T

229 sol, \_, \_, \_ \= np.linalg.lstsq(A, y\_raw, rcond\=None)

230 a, b \= float(sol\[0\]), float(sol\[1\])

231 except Exception:

232 a, b \= 1.0, 0.0

233

234 meta\_oof\_cal\_ls \= a \* meta\_oof\_cal + b

235 meta\_test\_cal\_ls \= a \* meta\_test\_cal + b

236

237 # Threshold initialization from class-wise means on calibrated OOF

238 class\_means \= \[\]

239 for c in unique\_classes:

240 mask \= y\_raw \== c

241 if mask.sum() \== 0:

242 class\_means.append(np.nan)

243 else:

244 class\_means.append(meta\_oof\_cal\_ls\[mask\].mean())

245 class\_means \= np.array(class\_means)

246 nan\_mask \= np.isnan(class\_means)

247 if nan\_mask.any():

248 filled \= np.linspace(meta\_oof\_cal\_ls.min(), meta\_oof\_cal\_ls.max(), n\_classes)

249 class\_means\[nan\_mask\] \= filled\[nan\_mask\]

250

251 thresholds \= np.array(

252 \[(class\_means\[i\] + class\_means\[i + 1\]) / 2.0 for i in range(n\_classes \- 1)\],

253 dtype\=float,

254 )

255

256

257 def map\_preds\_to\_labels(preds, thresholds, classes):

258 idxs \= np.sum(preds.reshape(-1, 1) \> thresholds.reshape(1, \-1), axis\=1)

259 mapped \= classes\[idxs\]

260 return mapped

261

262

263 def qwk\_for\_thresholds(thr, preds\_cal, y\_true):

264 preds\_mapped \= map\_preds\_to\_labels(preds\_cal, thr, unique\_classes)

265 return cohen\_kappa\_score(y\_true, preds\_mapped, weights\="quadratic")

266

267

268 best\_thr \= thresholds.copy()

269 best\_score \= qwk\_for\_thresholds(best\_thr, meta\_oof\_cal\_ls, y\_raw)

270 print(f"Initial calibrated OOF QWK (iso + linfit): {best\_score:.6f}")

271

272 # Coordinate descent threshold optimization

273 min\_pred \= float(meta\_oof\_cal\_ls.min())

274 max\_pred \= float(meta\_oof\_cal\_ls.max())

275 step \= (max\_pred \- min\_pred) / 10.0 if max\_pred \> min\_pred else 1.0

276 max\_iters \= 200

277 iters \= 0

278 while step \> 1e\-6 and iters < max\_iters:

279 improved \= False

280 for i in range(len(best\_thr)):

281 low \= min\_pred if i \== 0 else best\_thr\[i \- 1\] + 1e\-12

282 high \= max\_pred if i \== len(best\_thr) \- 1 else best\_thr\[i + 1\] \- 1e\-12

283 if low \>= high:

284 continue

285 current \= best\_thr\[i\]

286 candidates \= \[

287 current,

288 current \- step,

289 current + step,

290 low,

291 high,

292 (low + high) / 2.0,

293 \]

294 cand\_values \= \[\]

295 for c in candidates:

296 c \= max(low, min(high, c))

297 cand\_values.append(c)

298 cand\_values \= sorted(set(cand\_values))

299 best\_local\_score \= best\_score

300 best\_local\_val \= current

301 for val in cand\_values:

302 trial\_thr \= best\_thr.copy()

303 trial\_thr\[i\] \= val

304 if not np.all(np.diff(trial\_thr) \> \-1e\-12):

305 continue

306 score \= qwk\_for\_thresholds(trial\_thr, meta\_oof\_cal\_ls, y\_raw)

307 if score \> best\_local\_score + 1e\-12:

308 best\_local\_score \= score

309 best\_local\_val \= val

310 if best\_local\_val != current:

311 best\_thr\[i\] \= best\_local\_val

312 best\_score \= best\_local\_score

313 improved \= True

314 if not improved:

315 step /= 3.0

316 iters += 1

317

318 print(f"Optimized thresholds: {best\_thr}")

319 print(f"OOF calibrated+linfit QWK after threshold opt: {best\_score:.6f}")

320

321 # Compute per-fold QWKs using optimized thresholds on calibrated per-fold meta preds

322 cv\_fold\_scores \= \[\]

323 for fold in range(NUM\_FOLDS):

324 val\_idx \= splits\[fold\]\[1\]

325 val\_meta\_pred \= meta\_oof\[val\_idx\]

326 # apply isotonic then linear scaling

327 val\_meta\_cal \= (

328 iso.predict(val\_meta\_pred)

329 if isinstance(iso, IsotonicRegression)

330 else val\_meta\_pred

331 )

332 val\_meta\_cal \= a \* val\_meta\_cal + b

333 y\_val \= y\_raw\[val\_idx\]

334 mapped \= map\_preds\_to\_labels(val\_meta\_cal, best\_thr, unique\_classes)

335 score \= cohen\_kappa\_score(y\_val, mapped, weights\="quadratic")

336 cv\_fold\_scores.append(float(score))

337 print(f"Fold {fold+1} QWK after calibration+threshold opt: {score:.6f}")

338

339 cv\_mean \= float(np.mean(cv\_fold\_scores))

340 cv\_std \= float(np.std(cv\_fold\_scores))

341 print(f"CV mean QWK: {cv\_mean:.6f} std: {cv\_std:.6f}")

342

343 # Apply to test preds: meta\_test\_cal\_ls

344 test\_mapped \= map\_preds\_to\_labels(meta\_test\_cal\_ls, best\_thr, unique\_classes).astype(

345 int

346 )

347 submission \= pd.DataFrame({"id": test\_ids, "quality": test\_mapped})

348 os.makedirs(os.path.dirname(SUBMISSION\_PATH), exist\_ok\=True)

349 submission.to\_csv(SUBMISSION\_PATH, index\=False)

350 print(f"Saved submission to {SUBMISSION\_PATH}")

351

352 # AIDE metrics JSON line

353 metrics \= {

354 "valid": "quadratic\_weighted\_kappa",

355 "lower\_is\_better": False,

356 "cv\_mean": cv\_mean,

357 "cv\_std": cv\_std,

358 "cv\_folds": cv\_fold\_scores,

359 }

360 print("AIDE\_METRICS\_JSON=" + json.dumps(metrics))

### B.5 Valid node and score correlation

The case studies above show that more valid nodes enable more iteration and qualitatively better solutions. We now ask whether this relationship holds quantitatively: across all seeds and competitions, do seeds with more valid nodes tend to achieve higher OOS scores?

##### Per-seed correlation.

For each competition, we compute the Pearson correlation (r) between per-seed valid node count and OOS score across all available seeds (10 treatment + up to 10 baseline, approximately 18–19 datapoints per competition). [Table 10](https://arxiv.org/html/2608.10424#A2.T10 "In Per-seed correlation. ‣ B.5 Valid node and score correlation ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents") reports the results.

| Competition | N | r |
| --- | --- | --- |
| Cirrhosis | 19 | +0.34 |
| GNSS | 18 | +0.27 |
| Spaceship | 19 | −0.02 |
| Wine | 18 | +0.63 |
| S5E3 | 19 | +0.18 |
| S5E6 | 18 | +0.61 |
| S5E7 | 19 | −0.27 |
| S5E8 | 16 | +0.05 |
| S5E12 | 17 | +0.24 |
| Pooled | 163 | +0.22 |

Table 10: Pearson correlation (r) between per-seed valid node count and OOS score. Cirrhosis scores are negated so that positive r always means “more valid nodes → better score.” Pooled r is computed after z-normalizing both variables within each competition.

The correlation is positive in 7 of 9 competitions, with a z-normalized pooled r\=+0.22 across all 163 seeds, consistent with the hypothesis that more valid nodes lead to better scores. The correlation is highest on Wine (r\=+0.63) and S5E6 (r\=+0.61). For Cirrhosis (r\=+0.34, [Table 10](https://arxiv.org/html/2608.10424#A2.T10 "In Per-seed correlation. ‣ B.5 Valid node and score correlation ‣ Appendix B Extended experimental results ‣ Recovering Wasted Compute in Autoresearch Agents")), more valid nodes correlate with lower (better) log-loss.

## Appendix C Hyperparameter optimization materials and additional results and discussion

##### Hyperparameter optimization directive.

The following directive is injected verbatim into the agent context to guide hyperparameter tuning behavior.

HYPERPARAMETER OPTIMIZATION DIRECTIVE

\------------------------------------

Treat hyperparameter tuning as a sequential search problem under strict time and step budgets.

1. Start with a strong, standard baseline (well\-known defaults for the model class).

Validate to establish a performance baseline.

2. Run a small number of cheap probes (fast, low\-compute experiments) to identify sensitivity

directions (e.g., learning rate, regularization strength, tree depth, batch size).

Use cross\-validation or a held\-out validation set, not the test set.

3. Prioritize hyperparameters with the highest marginal impact on validation score.

Focus on 1-2 hyperparameters at a time rather than simultaneous grid searches.

4. Use structured search (log\-scale sweeps, conditional ranges), not random guessing.

For continuous parameters, explore orders of magnitude first.

5. Aggressively prune unpromising regions early; reallocate budget to promising configurations.

If a hyperparameter range shows no improvement after 2-3 trials, move on.

6. When improvements plateau (e.g., <0.1% improvement over 3 consecutive trials),

switch from exploration to fine\-grained exploitation around the current best setting.

7. Always validate changes; only keep configurations that strictly improve

validation performance over your current best submission.

8. Track what failed and do not retry equivalent configurations.

Maintain a log of tried hyperparameter combinations and their results.

Goal: maximize leaderboard / validation score within the available compute and step budget.

##### Hyperparameter tuning evaluator prompt.

The evaluator prompt used to score hyperparameter tuning quality for AIDE and ML-Master use the same 0–3 rubric. Both are followed by a separate, code-level structural check (Appendix [C](https://arxiv.org/html/2608.10424#A3 "Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents")) that can cap the LLM-assigned score downward for weak or unused search configurations. The HPO quality scorer uses gpt-4o-2024-08-06 as the judge model, independent of the agent backbone.

AIDE evaluator prompt:

You are a strict ML code reviewer evaluating hyperparameter tuning quality.

Score the hyperparameter tuning in the following Python code on a 0-3 scale:

0 \= none: No hyperparameter tuning (only fixed/default hyperparameters)

1 \= superficial: Minimal tuning (e.g., only 2-3 values tested for 1 hyperparameter,

or very small grid/random search with <5 iterations)

2 \= moderate: Reasonable tuning (multiple hyperparameters tested, systematic search

with \>=5 iterations, proper validation)

3 \= extensive: Comprehensive tuning (multiple hyperparameters, systematic search

with \>=10 iterations, proper validation, best params reused for final training)

DO NOT count:

\- cross\_val\_score alone without hyperparameter search

\- fixed hyperparameters

\- train/val splits without search

\- hyperparameter tuning that is not used in final model training

Respond with ONLY the integer score (0, 1, 2, or 3).

ML-Master evaluator prompt:

You are a STRICT ML code reviewer.

Evaluate the QUALITY and DEPTH of hyperparameter tuning in the following Python code.

Score hyperparameter tuning on a scale from 0 to 3:

0 \= NONE

\- No hyperparameter tuning

\- Fixed hyperparameters

\- cross\_val\_score without parameter search

1 \= MINIMAL

\- Token or superficial tuning

\- Only one hyperparameter tuned over 1-2 values

\- GridSearchCV or RandomizedSearchCV with <5 total configurations

\- RandomizedSearchCV with n\_iter < 5

2 \= MODERATE

\- Valid hyperparameter tuning but limited in scope

\- Either:

\* One hyperparameter searched over \>=3 values, OR

\* Two or more hyperparameters searched over \>=2 values each

\- \>=5 total configurations evaluated

\- Model selection based on validation or cross\-validation

3 \= EXTENSIVE

\- Systematic, non\-trivial hyperparameter optimization

\- Multiple hyperparameters jointly optimized

\- \>=10 total configurations or trials evaluated

\- Clear use of GridSearchCV, RandomizedSearchCV (n\_iter \>=10), Optuna, Hyperopt,

or Bayesian optimization

\- Best configuration explicitly selected and used

Valid tuning methods include:

\- GridSearchCV

\- RandomizedSearchCV

\- Optuna / Hyperopt / Bayesian optimization

\- Manual loops evaluating multiple configurations

Respond ONLY with a single integer: 0, 1, 2, or 3.

##### Analysis of asymmetry in AIDE and ML-Master HPO results.

The asymmetry can be attributed to two structural differences, which we have confirmed by analyzing the code and logs.

The first is prompt redundancy in ML-Master. Its draft prompt already instructs the agent to include HPO in every draft, with implementation guidelines specifying two-phase training and limiting the hyperparameter search to 10-15 trials. However, AIDE’s draft prompt doesn’t require HPO at draft time the way ML-Master does. Our directive therefore fills a gap in AIDE but adds less in ML-Master, where HPO guidance already exists.

The second is that the directive pushes the LLM toward RandomizedSearchCV and GridSearchCV with XGBoost, which triggers a sklearn/XGBoost version incompatibility:

AttributeError: ’super’ object has no attribute ’\*\*sklearn\_tags\*\*’

\[05:20:45\] WARNING: Node 6f9868d4 is marked as buggy because response\[’is\_bug’\] is True.

\[05:20:45\] INFO: Parsed results: Node 6f9868d4 is buggy

\[05:20:45\] INFO: Starting Debugging Node 6f9868d4.

\[05:20:56\] INFO: Drafted a new node 3272d605 successfully!

ML-Master’s memory module records these failures neutrally as is\_bug: True without propagating why, so the LLM interprets each crash as motivation to try a different HPO implementation rather than abandon HPO. We observe up to 12 consecutive identical API failures within a single ML-Master run. This explains the pattern across all three conditions: the prompt-only condition adds redundant guidance on top of existing instructions, the code-only condition introduces reward shaping that is undermined by crash-prone code patterns, and the combined condition inherits both issues simultaneously.

In contrast, the following AIDE log confirms that our reward-shaping mechanism functions correctly when the agent’s information flow supports it. A node with HPO score 0 has its reward adjusted down from 0.803 to 0.787 due to the -0.300 penalty, making it less likely to be selected:

\[2026-03-26 20:01:27\] INFO: Scoring hyperparameter tuning for node 678c47e2...

\[2026-03-26 20:01:28\] INFO: Node 678c47e2... initial HPO score: 0

\[2026-03-26 20:01:28\] INFO: Node 678c47e2... HPO score after structural caps: 0

\[2026-03-26 20:01:28\] INFO: Parsed results: Node 678c47e2... is not buggy

\[2026-03-26 20:01:28\] INFO: Node 678c47e2... metric adjusted:

base\=0.803140, hpo\_reward\=-0.300, diversity\=0.100, final\=0.787077

The asymmetry is itself a finding: scaffold interventions interact with the underlying agent’s memory architecture, and a directive that works on one agent can fail on another for reasons unrelated to the directive’s design.

| Competition | ΔPrompt | ΔCode | ΔP&C |
| --- | --- | --- | --- |
| Cirrhosis† | −0.001±0.0022 | −0.002±0.0032 | −0.001±0.0061 |
| GNSS | −0.019±0.0129 | −0.017±0.0162 | −0.078±0.0034 |
| Spaceship | +0.010±0.0143 | −0.016±0.0208 | +0.020±0.0117 |
| Wine | +0.002±0.0104 | −0.075±0.0691 | −0.056±0.0098 |
| S5E3 | −0.002±0.0037 | −0.004±0.0040 | −0.053±0.0062 |
| S5E6 | −0.002±0.0035 | −0.011±0.0044 | −0.026±0.0021 |
| S5E7 | +0.000±0.0003 | +0.000±0.0007 | +0.001±0.0003 |
| S5E8 | −0.001±0.0026 | +0.000±0.0007 | +0.000±0.0008 |
| S5E12 | +0.001±0.0040 | +0.002±0.0040 | −0.000±0.0055 |

Table 11: Intervention effect on graded score for ML-Master: Δ\=μint−μbase (mean ± SEM of Δ), with the same competitions as [Table 2](https://arxiv.org/html/2608.10424#S4.T2 "In 4.3 Hyperparameter tuning guidance ‣ 4 Experimental setup and results ‣ Recovering Wasted Compute in Autoresearch Agents"). Bold (signed Δ only) indicates strict improvement over baseline (positive Δ when higher is better; negative Δ for cirrhosis). †Lower is better for Cirrhosis.

### C.1 Thompson sampling on AIDE: delta, standard deviation and proportion of null errors

| Competition | Thompson Sampling | Baseline (AIDE) | Winner |
| --- | --- | --- | --- |
| Cirrhosis† | 0.404 ± 0.005 | 0.394 ± 0.012 | Baseline |
| GNSS | 0.967 ± 0.001 | 0.967 ± 0.001 | Tie |
| Spaceship | 0.822 ± 0.002 | 0.790 ± 0.022 | TS |
| Wine | 0.408 ± 0.011 | 0.375 ± 0.021 | TS |
| S5E3 | 0.889 ± 0.003 | 0.887 ± 0.003 | TS |
| S5E6 | 0.335 ± 0.001 | 0.333 ± 0.002 | TS |
| S5E7 | 0.967 ± 0.000 | 0.968 ± 0.000 | Baseline |
| S5E8 | 0.966 ± 0.001 | 0.969 ± 0.000 | Baseline |
| S5E12 | 0.725 ± 0.001 | 0.727 ± 0.000 | Baseline |

Table 12: AIDE Baseline vs. AIDE with Thompson Sampling (Mean ± SEM) of 10 runs. Bold indicates the winning method per competition; values tied at the displayed precision are bolded in both columns. †Lower is better.

| Type | initial drafts | max debug | error backtrack |
| --- | --- | --- | --- |
| TS | 20 | 5 | 3 |
| Baseline | 5 | 20 | 20 |

Table 13: Hyperparameters for different settings on AIDE.

| Competition | Thompson Sampling (Ours) | Baseline (AIDE) |
| --- | --- | --- |
| Cirrhosis† | 0.014 | 0.035 |
| GNSS | 0.004 | 0.002 |
| Spaceship | 0.006 | 0.067 |
| Wine | 0.034 | 0.058 |
| S5E3 | 0.009 | 0.010 |
| S5E6 | 0.003 | 0.005 |
| S5E7 | 0.001 | 0.000 |
| S5E8 | 0.003 | 0.001 |
| S5E12 | 0.002 | 0.001 |

Table 14: Score Standard Deviation per Competition on AIDE. Bold indicates lower (more consistent) std dev.

| Competition | Thompson Sampling | Baseline (AIDE) |
| --- | --- | --- |
| Cirrhosis† | 10% | 10% |
| GNSS | 10% | 20% |
| Spaceship | 0% | 10% |
| Wine | 10% | 20% |
| S5E3 | 20% | 10% |
| S5E6 | 30% | 20% |
| S5E7 | 0% | 10% |
| S5E8 | 30% | 40% |
| S5E12 | 40% | 30% |

Table 15: Null/Zero Run Rate per Competition. Fraction of runs out of 10 that produced no valid score on AIDE. Bold indicates lower (fewer failures); values tied at the displayed precision are bolded in both columns.

### C.2 AIDE: comparative analysis of Thompson sampling versus hyperparameter changes

| Competition | AIDE + TS + More Drafts | AIDE + More Drafts | Winner |
| --- | --- | --- | --- |
| Cirrhosis† | 0.404 ± 0.005 | 0.394 ± 0.004 | More Drafts |
| GNSS | 0.967 ± 0.001 | 0.965 ± 0.001 | TS |
| Spaceship | 0.822 ± 0.002 | 0.818 ± 0.005 | TS |
| Wine | 0.408 ± 0.011 | 0.402 ± 0.017 | TS |
| S5E3 | 0.889 ± 0.003 | 0.896 ± 0.002 | More Drafts |
| S5E6 | 0.335 ± 0.001 | 0.337 ± 0.002 | More Drafts |
| S5E7 | 0.967 ± 0.000 | 0.968 ± 0.000 | More Drafts |
| S5E8 | 0.966 ± 0.001 | 0.966 ± 0.002 | Tie |
| S5E12 | 0.725 ± 0.001 | 0.727 ± 0.000 | More Drafts |

Table 16: AIDE with Thompson Sampling and More Drafts vs. AIDE with More Drafts (Mean ± SEM). Bold indicates the winning method per competition; values tied at the displayed precision are bolded in both columns. Number of null runs (competitions produced without a score) went from 33 in the baseline with more drafts to 15 with Thompson Sampling, a 54.5% reduction †Lower is better.

### C.3 Adversarial EDA prompt

Figure 8: Malicious EDA results inserted into agent’s context at the draft(), debug() and improve() stages

Figure 9: Control evaluation prompt used to test whether the model conducted exploratory data analysis at all. This does not refer to the malicious injection, letting the judge model draw independent conclusions

Figure 10: Secondary evaluation prompt used to test whether the model conducted exploratory data analysis at all, and whether the injection affected agent’s choices.

### C.4 Adversarial EDA: extended analysis

|  | Non-null Average | All Runs (nulls=0) |
| --- | --- | --- |
| Competition | Adv EDA | Baseline | Diff | Adv EDA | Baseline | Diff |
| --- | --- | --- | --- | --- | --- | --- |
| Cirrhosis† | 0.4131 | 0.3980 | +0.0151 | 0.4131 | 0.1592 | +0.2539 |
| GNSS | 0.9660 | 0.9583 | +0.0077 | 0.3864 | 0.5750 | \-0.1886 |
| Spaceship | 0.7441 | 0.7361 | +0.0080 | 0.7431 | 0.7312 | +0.0119 |
| Wine | 0.0000 | 0.3830 | \-0.3830 | 0.0000 | 0.1532 | \-0.1532 |
| S5E3 | 0.9017 | 0.8987 | +0.0030 | 0.9017 | 0.5392 | +0.3625 |
| S5E6 | 0.3343 | 0.3363 | \-0.0020 | 0.2006 | 0.0673 | +0.1333 |
| S5E7 | 0.9677 | 0.9651 | +0.0026 | 0.9677 | 0.5791 | +0.3887 |
| S5E8 | 0.9665 | 0.9655 | +0.0010 | 0.3866 | 0.1931 | +0.1935 |
| S5E12 | 0.7261 | 0.7221 | +0.0041 | 0.4357 | 0.4332 | +0.0024 |
| Mean | 0.6688 | 0.7070 | \-0.0382 | 0.4928 | 0.3812 | +0.1116 |

Table 17: Detailed Performance Comparison for AIDE: Non-null averages computed over valid runs only. All-runs averages treat missing/failed runs as 0. Diff = Adv EDA - Baseline. Positive values indicate improvement with adversarial EDA. †Lower is better for Cirrhosis.

|  | Non-null Average | All Runs (nulls=0) |
| --- | --- | --- |
| Competition | Adv EDA | Baseline | Diff | Adv EDA | Baseline | Diff |
| --- | --- | --- | --- | --- | --- | --- |
| Cirrhosis† | 0.3849 | 0.4047 | \-0.0199 | 0.3849 | 0.4047 | \-0.0199 |
| GNSS | 0.9639 | 0.7758 | +0.1881 | 0.9639 | 0.7758 | +0.1881 |
| Spaceship | 0.7574 | 0.7323 | +0.0251 | 0.7574 | 0.7323 | +0.0251 |
| Wine | 0.4191 | 0.3757 | +0.0434 | 0.4191 | 0.3757 | +0.0434 |
| S5E3 | 0.8973 | 0.8521 | +0.0452 | 0.8973 | 0.8521 | +0.0452 |
| S5E6 | 0.3260 | 0.2947 | +0.0313 | 0.1956 | 0.2357 | \-0.0401 |
| S5E12 | 0.7148 | 0.7015 | +0.0133 | 0.7148 | 0.7015 | +0.0133 |
| S5E7 | 0.9678 | 0.9668 | +0.0011 | 0.9678 | 0.9668 | +0.0011 |
| S5E8 | 0.9578 | 0.9659 | \-0.0082 | 0.5747 | 0.5796 | \-0.0049 |
| Mean | 0.7099 | 0.6744 | +0.0355 | 0.6528 | 0.6249 | +0.0279 |

Table 18: Detailed Performance Comparison for ML-Master: Non-null averages computed over valid runs only. All-runs averages treat missing/failed runs as 0. Diff = Adversarial EDA - Baseline. Positive values indicate improvement with adversarial EDA. †Lower is better for Cirrhosis. Note: the baseline used for ML Master was based on a different set of runs than the baseline used for the debug consultant.

To evaluate whether agents incorporate information from exploratory data analysis (EDA) , we inject the results of a controlled, erroneous EDA directly into the agent’s context window. We conduct this experiment on two representative systems, AIDE and ML-Master. For AIDE, the EDA message is inserted at each of its three agentic stages: draft(), improve(), and debug(), and formatted to resemble a memory artifact produced by a prior node. For ML-Master, the EDA results are hard-coded into the data-preview.py file located in the utils directory, which supplies contextual information from previous nodes to the agent. An example message is included in [Figure 8](https://arxiv.org/html/2608.10424#A3.F8 "In C.3 Adversarial EDA prompt ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents") in [Section C.3](https://arxiv.org/html/2608.10424#A3.SS3 "C.3 Adversarial EDA prompt ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents").

We evaluate both modified agents and compare their performance against baseline runs without injected EDA.

Across all tasks, we observe that performance differences induced by EDA injection are inconsistent and statistically insignificant. To check whether the agent conducted EDA at all, we use the llm-as-a-judge framework with a larger reasoning model: gpt-5-2025-08-07. The exact framework used is shown in [Section C.3](https://arxiv.org/html/2608.10424#A3.SS3 "C.3 Adversarial EDA prompt ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents") in [Figures 9](https://arxiv.org/html/2608.10424#A3.F9 "In C.3 Adversarial EDA prompt ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents") and [10](https://arxiv.org/html/2608.10424#A3.F10 "Figure 10 ‣ C.3 Adversarial EDA prompt ‣ Appendix C Hyperparameter optimization materials and additional results and discussion ‣ Recovering Wasted Compute in Autoresearch Agents"). We note that in all the baseline runs across both agents, the agent did not conduct any EDA, and struggled to acknowledge the existence of the EDA in the adversarial runs. For instance in AIDE, in the runs with adversarial EDA injections, the logs demonstrate that the agent is only able to identify and acknowledge the presence of the malicious EDA results in 21% of cases, and that impacts its feature selection in barely 5% of the cases. This suggests that the agents do not act upon exploratory data analysis, and do not meaningfully integrate EDA into downstream modeling decisions.

### C.5 List of linked competitions used in experiments

| Competition | Link |
| --- | --- |
| Cirrhosis Outcome Prediction | [kaggle.com/competitions/playground-series-s3e26](https://kaggle.com/competitions/playground-series-s3e26) |
| GNSS Classification | [kaggle.com/competitions/gnss-classification](https://kaggle.com/competitions/gnss-classification) |
| Playground S5E3 | [kaggle.com/competitions/playground-series-s5e3](https://kaggle.com/competitions/playground-series-s5e3) |
| Playground S5E6 | [kaggle.com/competitions/playground-series-s5e6](https://kaggle.com/competitions/playground-series-s5e6) |
| Playground S5E7 | [kaggle.com/competitions/playground-series-s5e7](https://kaggle.com/competitions/playground-series-s5e7) |
| Playground S5E8 | [kaggle.com/competitions/playground-series-s5e8](https://kaggle.com/competitions/playground-series-s5e8) |
| Playground S5E12 | [kaggle.com/competitions/playground-series-s5e12](https://kaggle.com/competitions/playground-series-s5e12) |
| Spaceship Titanic | [kaggle.com/competitions/spaceship-titanic](https://kaggle.com/competitions/spaceship-titanic) |
| Wine Quality Ordinal | [kaggle.com/competitions/wine-quality-ordinal](https://kaggle.com/competitions/wine-quality-ordinal) |

Table 19: Kaggle competitions used in evaluation.

Experimental support, please [view the build logs](https://arxiv.org/html/2608.10424v1/__stdout.txt) for errors. Generated by [L A T E xml](https://math.nist.gov/~BMiller/LaTeXML/)  .

## Instructions for reporting errors

We are continuing to improve HTML versions of papers, and your feedback helps enhance accessibility and mobile support. To report errors in the HTML that will help us improve conversion and rendering, choose any of the methods listed below:

-   Click the "Report Issue" button, located in the page header.

**Tip:** You can select the relevant text first, to include it in your report.

Our team has already identified [the following issues](https://github.com/arXiv/html_feedback/issues). We appreciate your time reviewing and reporting rendering errors we may not have found yet. Your efforts will help us improve the HTML versions for all readers, because disability should not be a barrier to accessing research. Thank you for your continued support in championing open access for all.

Have a free development cycle? Help support accessibility at arXiv! Our collaborators at LaTeXML maintain a [list of packages that need conversion](https://github.com/brucemiller/LaTeXML/wiki/Porting-LaTeX-packages-for-LaTeXML), and welcome [developer contributions](https://github.com/brucemiller/LaTeXML/issues).

We gratefully acknowledge support from our **major funders**, [**member institutions**](https://info.arxiv.org/about/ourmembers.html), and all contributors.

[About](https://info.arxiv.org/about) · [Help](https://info.arxiv.org/help) · [Contact](https://info.arxiv.org/help/contact.html) · [Subscribe](https://info.arxiv.org/help/subscribe) · [Copyright](https://info.arxiv.org/help/license/index.html) · [Privacy](https://info.arxiv.org/help/policies/privacy_policy.html) · [Accessibility](https://info.arxiv.org/help/web_accessibility.html) · [Operational Status (opens in new tab)](https://status.arxiv.org/)

Major funding support from

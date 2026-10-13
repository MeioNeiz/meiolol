# MARS: Modular Agent with Reflective Search for Automated AI Research

<https://arxiv.org/html/2602.02660>

arXiv is now an independent nonprofit! [Learn more](https://info.arxiv.org/about) 

 [Back to arXiv](https://arxiv.org/)

[Why HTML?](https://info.arxiv.org/about/accessible_HTML.html) [Report Issue](https://arxiv.org/html/2602.02660# "Report an Issue") [Back to Abstract](https://arxiv.org/abs/2602.02660v3 "Back to abstract page") [Download PDF](https://arxiv.org/pdf/2602.02660v3 "Download PDF")

1.  [Abstract](https://arxiv.org/html/2602.02660#abstract1 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
2.  [1 Introduction](https://arxiv.org/html/2602.02660#S1 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
3.  [2 Related Work](https://arxiv.org/html/2602.02660#S2 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
4.  [3 Problem](https://arxiv.org/html/2602.02660#S3 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
5.  [4 Method](https://arxiv.org/html/2602.02660#S4 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
6.  [5 Experiment](https://arxiv.org/html/2602.02660#S5 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
7.  [6 Discussions](https://arxiv.org/html/2602.02660#S6 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
8.  [7 Conclusion](https://arxiv.org/html/2602.02660#S7 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
9.  [References](https://arxiv.org/html/2602.02660#bib "In MARS: Modular Agent with Reflective Search for Automated AI Research")
10.  [A Limitations](https://arxiv.org/html/2602.02660#A1 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
11.  [B MLE Task Scenario](https://arxiv.org/html/2602.02660#A2 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
12.  [C Monte Carlo Tree Search (MCTS)](https://arxiv.org/html/2602.02660#A3 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
13.  [D MARS for MLE Tasks](https://arxiv.org/html/2602.02660#A4 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
14.  [E Setup for Leaderboard Methods vs. Our Setup](https://arxiv.org/html/2602.02660#A5 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
15.  [F Additional Results](https://arxiv.org/html/2602.02660#A6 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
16.  [G Qualitative Examples of Causally Correct Distilled Lessons](https://arxiv.org/html/2602.02660#A7 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
17.  [H Prompts](https://arxiv.org/html/2602.02660#A8 "In MARS: Modular Agent with Reflective Search for Automated AI Research")
18.  [I Example Solution Code](https://arxiv.org/html/2602.02660#A9 "In MARS: Modular Agent with Reflective Search for Automated AI Research")

[License: CC BY 4.0](https://info.arxiv.org/help/license/index.html#licenses-available)

arXiv:2602.02660v3 \[cs.AI\] 19 May 2026

# MARS: Modular Agent with Reflective Search for Automated AI Research

Jiefeng Chen Bhavana Dalvi Mishra Jaehyun Nam Rui Meng Tomas Pfister Jinsung Yoon

###### Abstract

A critical bottleneck in automating AI research is the execution of complex machine learning engineering (MLE) tasks. MLE differs from general software engineering due to computationally expensive evaluation (e.g., model training) and opaque performance attribution. Current LLM-based agents struggle here, often generating monolithic scripts that ignore execution costs and causal factors. We introduce MARS (Modular Agent with Reflective Search), a framework optimized for autonomous AI research. MARS relies on three pillars: (1) Budget-Aware Planning via cost-constrained Monte Carlo Tree Search (MCTS) to explicitly balance performance with execution expense; (2) Modular Construction, employing a “Design-Decompose-Implement” pipeline to manage complex research repositories; and (3) Comparative Reflective Memory, which addresses credit assignment by analyzing solution differences to distill high-signal insights. MARS achieves state-of-the-art performance among open-source frameworks on MLE-Bench under comparable settings, maintaining competitiveness with the global leaderboard’s top methods. Furthermore, the system exhibits qualitative “Aha!” moments, where 63% of all utilized lessons originate from cross-branch transfer, demonstrating that the agent effectively generalizes insights across search paths.

## 1 Introduction

Figure 1: The “Aha!” moment of MARS on the challenging iMet-2020-FGVC7 task. The visualization tracks validation performance gains triggered by specific strategic lessons. While existing methods fail to reach medal-level performance, MARS progressively refines its strategy – evolving from a lightweight residual network to model ensemble techniques – to ultimately achieve a silver medal.

The integration of Large Language Models (LLMs) into software engineering has fundamentally transformed code generation, evolving from simple auto-completion to autonomous agents capable of resolving GitHub issues [Jimenez et al. (2023)](https://arxiv.org/html/2602.02660#bib.bib5); [Yang et al. (2024)](https://arxiv.org/html/2602.02660#bib.bib4) and generating functional scripts ([Li et al., 2022](https://arxiv.org/html/2602.02660#bib.bib6); [Wang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib8); [Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3)). However, while current agents excel at general software maintenance tasks – such as patching bugs or writing unit tests – they face significant hurdles when applied to the domain of Automating AI Research ([Chan et al., 2025](https://arxiv.org/html/2602.02660#bib.bib1); [Tian et al., 2024](https://arxiv.org/html/2602.02660#bib.bib24); [Wijk et al., 2025](https://arxiv.org/html/2602.02660#bib.bib13); [Yamada et al., 2025](https://arxiv.org/html/2602.02660#bib.bib23); [Starace et al., 2025](https://arxiv.org/html/2602.02660#bib.bib22)). A critical bottleneck in this domain is the execution of complex machine learning engineering (MLE) tasks. Unlike standard software development, where correctness is often binary and verification is computationally cheap, MLE is a probabilistic, resource-intensive endeavor. It requires not only coding intelligence but also the strategic foresight to navigate a landscape defined by computationally expensive evaluations, opaque performance attribution, and high architectural complexity.

Existing agentic frameworks, designed primarily for monolithic code generation, struggle to adapt to these constraints. First, they typically view problem-solving as a purely code-based challenge ([Huang et al., 2024](https://arxiv.org/html/2602.02660#bib.bib10); [Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3); [Toledo et al., 2026](https://arxiv.org/html/2602.02660#bib.bib12)), ignoring the economic reality of research: model training and data processing consume vast computational resources. An agent that improves model accuracy by 0.1% but increases training time from one hour to ten hours is often practically useless, yet standard search algorithms would prioritize it. Second, the monolithic and unstructured scripts often produced by previous LLM agents are fragile and ill-suited for the modular complexity required in research repositories, where data loading, model architecture, and training loops must interact seamlessly. Finally, research progress is iterative and opaque; when a new experiment yields better results, it is difficult to isolate the causal factor. Standard memory-based agents ([Packer et al., 2023](https://arxiv.org/html/2602.02660#bib.bib26); [Shinn et al., 2023](https://arxiv.org/html/2602.02660#bib.bib15); [Xu et al., 2026](https://arxiv.org/html/2602.02660#bib.bib36); [Ouyang et al., 2026](https://arxiv.org/html/2602.02660#bib.bib25)) lack the mechanism to solve this credit assignment problem, often failing to learn effectively from past trials.

To bridge this gap, we introduce MARS (Modular Agent with Reflective Search), a framework explicitly optimized for the distinct constraints of autonomous scientific discovery. MARS reformulates the research process as a search for an optimal software repository, governed by three core pillars. To address the high cost of evaluation, we employ Budget-Aware Planning via a cost-constrained Monte Carlo Tree Search (MCTS). Unlike general search algorithms, our method explicitly balances performance maximization with execution expense, prioritizing efficient solutions – such as favoring a 1-hour training run over a 4-hour run if performance is comparable – to optimize the discovery rate within a fixed budget. To manage architectural complexity, we replace fragile scripting with a Modular “Design-Decompose-Implement” pipeline. This structure employs specialized agents to architect solutions into independent, testable modules. Finally, to resolve the credit assignment problem, we introduce Comparative Reflective Memory. By analyzing the differences between the current solution and the best-known solution, the agent distills high-signal, causal insights, isolating the specific factors driving performance shifts in a way that standard memory mechanisms cannot. As illustrated in Figure [1](https://arxiv.org/html/2602.02660#S1.F1 "Figure 1 ‣ 1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), these pillars allow MARS to experience “Aha!” moments during long-horizon exploration, successfully navigating complex optimization landscapes where baselines fail.

Our contributions are summarized as follows:

-   •
    
    We introduce MARS, a framework aimed at automating AI research by optimizing for complex MLE tasks, featuring a novel combination of Budget-Aware MCTS, a modular implementation pipeline, and Comparative Reflective Memory.
    
-   •
    
    We perform extensive evaluation on the MLE-Bench benchmark, where MARS achieves state-of-the-art performance among open-source frameworks under comparable settings. Ablation studies further validate the necessity of each proposed mechanism.
    
-   •
    
    We provide qualitative analyses of how MARS drives long-horizon exploration. To facilitate future research, we release prompts in Appendix [H](https://arxiv.org/html/2602.02660#A8 "Appendix H Prompts ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), and MARS generated code, trajectories in [https://github.com/jfc43/MARS](https://github.com/jfc43/MARS).
    

## 2 Related Work

##### Automated AI Research & MLE Bottleneck.

Recent advancements in LLMs have driven ambitious efforts to automate complex, long-horizon AI research ([Lu et al., 2024](https://arxiv.org/html/2602.02660#bib.bib27); [Yamada et al., 2025](https://arxiv.org/html/2602.02660#bib.bib23); [Weng et al., 2025](https://arxiv.org/html/2602.02660#bib.bib28); [Tang et al., 2026](https://arxiv.org/html/2602.02660#bib.bib29); [Schmidgall et al., 2025](https://arxiv.org/html/2602.02660#bib.bib30); [Pu et al., 2025](https://arxiv.org/html/2602.02660#bib.bib31); [Starace et al., 2025](https://arxiv.org/html/2602.02660#bib.bib22)). Central to these efforts is the realization that Machine Learning Engineering (MLE) serves as a critical execution bottleneck ([Chan et al., 2025](https://arxiv.org/html/2602.02660#bib.bib1); [Wijk et al., 2025](https://arxiv.org/html/2602.02660#bib.bib13)); without robust autonomous MLE capabilities, higher-level research automation cannot succeed. While numerous agentic frameworks have been proposed to address these challenges ([Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3); [Toledo et al., 2026](https://arxiv.org/html/2602.02660#bib.bib12); [Yang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib11); [Liu et al., 2025b](https://arxiv.org/html/2602.02660#bib.bib9); [Team et al., 2025](https://arxiv.org/html/2602.02660#bib.bib17); [Li et al., 2025](https://arxiv.org/html/2602.02660#bib.bib18); [Nam et al., 2026](https://arxiv.org/html/2602.02660#bib.bib14); [Zhu et al., 2026](https://arxiv.org/html/2602.02660#bib.bib19)), existing systems predominantly operate under a monolithic paradigm, generating expansive, single-file scripts. This approach typically results in fragile codebases that lack the modularity essential for rigorous engineering. MARS departs from this by enforcing a repository-level paradigm that systematically decomposes tasks into distinct, testable, and maintainable modules, mirroring the professional software architecture required for scalable AI research.

Search Algorithms in Code Generation. Solving long-horizon AI research problems, where code execution is resource-intensive, necessitates effective search strategies for code optimization. While various algorithms have been adapted for these systems – including greedy search ([Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3)), Monte Carlo Tree Search (MCTS) ([Kocsis and Szepesvári, 2006](https://arxiv.org/html/2602.02660#bib.bib16); [Liu et al., 2025b](https://arxiv.org/html/2602.02660#bib.bib9)), and Evolutionary search ([Team et al., 2025](https://arxiv.org/html/2602.02660#bib.bib17)) – they typically optimize solely for task performance, neglecting computational cost. While recent work has introduced “budget awareness” for tool-augmented agents via external plug-ins ([Liu et al., 2025a](https://arxiv.org/html/2602.02660#bib.bib32)), such methods are primarily designed for discrete actions like web search. In contrast, we introduce Budget-aware MCTS, which integrates an efficiency-guided reward function directly into the search tree. This allows MARS to balance the exploitation of high-performing strategies with the exploration of novel ideas, penalizing computationally expensive solutions to ensure both performance and efficiency.

System Modular? Budget-Aware Search? Memory Mechanism AIDE ([Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3)) ✗ ✗ All previous designs, scores, and notes MLE-STAR ([Nam et al., 2026](https://arxiv.org/html/2602.02660#bib.bib14)) ✗ ✗ Some previous plans, code and results AIRA ([Toledo et al., 2026](https://arxiv.org/html/2602.02660#bib.bib12)) ✗ ✗ Scoped Memory: some previous designs, scores, and notes R&D-Agent ([Yang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib11)) ✗ ✗ Collaborative Memory: previous solutions, results, and insights ML-Master 2.0 ([Zhu et al., 2026](https://arxiv.org/html/2602.02660#bib.bib19)) ✗ ✗ Hierarchical Cognitive Caching: scripts, facts, strategies MARS (Ours) ✓ ✓ Comparative Reflective Memory: solution & debug lessons

Table 1: Comparison of MLE agents in terms of: 1) Do they generate modular code? 2) Do the agents take into account runtime/budget during search? 3) What types of memory mechanisms do they use to enhance performance on a given task? (✓: yes, ✗: no).

Reflective Learning and Memory. Enabling agents to improve iteratively through environmental interaction is a rapidly evolving research area. Early approaches, such as Reflexion ([Shinn et al., 2023](https://arxiv.org/html/2602.02660#bib.bib15)), focus on self-correction using verbal reinforcement derived from prior mistakes. Recently, the field has expanded to include sophisticated memory and distillation frameworks. For instance, several works explore advanced memory architectures for personalization and associative retrieval [Tan et al. (2025)](https://arxiv.org/html/2602.02660#bib.bib33); [Xu et al. (2026)](https://arxiv.org/html/2602.02660#bib.bib36), while others focus on refining process memory and distilling execution traces into stable strategies [Forouzandeh et al. (2025)](https://arxiv.org/html/2602.02660#bib.bib35); [Ouyang et al. (2026)](https://arxiv.org/html/2602.02660#bib.bib25); [Zhu et al. (2026)](https://arxiv.org/html/2602.02660#bib.bib19). Closer to our domain, [Zhao et al.](https://arxiv.org/html/2602.02660#bib.bib34) identify “good practices” by comparing high-level action trajectories, and [Jansen et al.](https://arxiv.org/html/2602.02660#bib.bib7) cache useful code blocks for future reuse. MARS advances this paradigm by introducing “Lesson Learning”. Unlike prior methods that summarize execution logs to debug errors or track binary success-failure trajectories, our method explicitly analyzes the causal link between code changes and performance variations. This comparative analysis isolates effective algorithmic changes from confounding factors, distilling high-value insights into a lesson pool to guide future exploration.

Table [1](https://arxiv.org/html/2602.02660#S2.T1 "Table 1 ‣ Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") summarizes the key differences between MARS and existing MLE agent frameworks.

## 3 Problem

We first formalize the general problem of Long-Horizon Agentic Problem Solving, where an autonomous agent is tasked with constructing a complex artifacts (e.g., a software system) to satisfy a set of requirements within a constrained budget. Let 𝒫 denote a problem instance defined by the tuple 𝒫\=(ℐ,ℰ,𝒪), where: (1) ℐ represents the Instruction or requirements provided in natural language. (2) ℰ denotes the Environment with which the agent interacts to validate its solutions. This can be a compiler, a simulator, or a dataset depending on the task scenario. (3) 𝒪 is the Objective function that quantifies the quality of the solution.

The goal is to find a solution s∗ that maximizes 𝒪 by interacting with ℰ, subject to a cost constraint B (e.g., time budget or monetary cost):

<table id="S3.EGx1" class="ltx_equationgroup ltx_eqn_align ltx_eqn_table"><tbody id="S3.E1"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_td ltx_align_right ltx_eqn_cell"><math id="S3.E1.m1" class="ltx_Math" alttext="\displaystyle s^{*}=\argmax_{s}\quad\mathcal{O}(s,\mathcal{E}),\quad s.t.\quad\text{Cost}(s)\leq B" display="inline" intent=":literal"><semantics><mrow><mrow><mrow><mrow><msup><mi>s</mi><mo>∗</mo></msup><mo>=</mo><msub><mrow><mi>arg</mi><mo lspace="0.170em" rspace="0em">​</mo><mi>max</mi></mrow><mi>s</mi></msub></mrow><mspace style="width:1em;" width="1em"></mspace><mrow><mi class="ltx_font_mathcaligraphic">𝒪</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><mi class="ltx_font_mathcaligraphic">ℰ</mi><mo stretchy="false">)</mo></mrow></mrow><mo rspace="1.167em">,</mo><mi>s</mi></mrow><mo lspace="0em" rspace="0.167em">.</mo><mi>t</mi></mrow><mo lspace="0em">.</mo><mspace style="width:1.167em;" width="1.167em"></mspace><mrow><mrow><mtext>Cost</mtext><mo lspace="0em" rspace="0em">​</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo stretchy="false">)</mo></mrow></mrow><mo>≤</mo><mi>B</mi></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(1)</span></td></tr></tbody></table>

where the search space for s is often vast and unstructured (e.g., the space of all possible Python programs).

##### MLE Task Scenario.

Machine Learning Engineering (MLE) is a representative and challenging instantiation of this general problem class. MLE requires the agent to engineer a full pipeline that processes data, trains models, and validates results. In this scenario, ℰ consists of the provided datasets while 𝒪 is the performance metric (e.g. accuracy) on the held-out test set. Refer to Appendix [B](https://arxiv.org/html/2602.02660#A2 "Appendix B MLE Task Scenario ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") for details.

## 4 Method

Figure 2: Overview of the MARS Framework. MARS reformulates long-horizon coding as a search for an optimal software repository. (1) Task Preparation: The agent grounds the abstract problem (Instruction, Environment, Objective) tuple by exploratory analysis of the given dataset and metadata. (2) The MARS Loop: The agent iteratively evolves solutions through three synergistic modules: (A) Resource-Aware Planning: A Budget-Aware MCTS strategically navigates the search space by selecting actions from {Draft new architecture, Debug runtime errors, Improve a valid solution}. It optimizes an efficiency-guided reward that explicitly balances performance maximization with the penalty of high execution costs. (B) Modular Decomposition: To replace fragile monolithic scripting, the system employs a “Design-Decompose-Implement” pipeline. Specialized {Idea, Modular, Coding} agents architect the solution into independent, testable modules. This structure enables precise Diff-Based Refinement, allowing the agent to update specific logic blocks without regenerating the entire codebase. (C) Reflective Memory: This module distills raw execution logs into structured Debugging and Solution Lessons to proactively prevent error repetition and accelerate convergence in later iterations.

### 4.1 Overall Framework

We propose MARS, a general agent scaffolding framework designed to enable autonomous agents to solve long-horizon AI Research problems, as illustrated in Figure [2](https://arxiv.org/html/2602.02660#S4.F2 "Figure 2 ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"). Formally, we define the problem as a tuple 𝒫\=(ℐ,ℰ,𝒪), where the agent must follow the instruction ℐ within an environment ℰ to maximize an objective 𝒪 under a cost budget B. To address the core challenges of exploration complexity, context management, and solution robustness in this setting, our framework integrates three key capabilities:

-   •
    
    Modular Construction Strategy: Instead of generating monolithic scripts, we enforce a structured, repository-level software architecture. This paradigm allows for handing complex logic with greater accuracy, efficient code reuse, and improving testability.
    
-   •
    
    Comparative Reflective Memory: To overcome context window limitations, we introduce a “Lesson Learning” mechanism that distills high-value, causal insights from past interactions (both successes and failures) into a compact, retrievable knowledge base.
    
-   •
    
    Resource-Aware Planning: We employ a budget-aware Monte Carlo Tree Search (MCTS) algorithm to systematically explore the solution space. This allows the system to balance the exploitation of promising candidates with the exploration of novel ideas, preventing local optima, and penalize solutions that are costly.
    

### 4.2 Modular Decomposition

A primary contribution of this work is the strategic shift from generating monolithic scripts to a Modular Implementation paradigm. This paradigm addresses several inherent limitations of LLM-based coding. First, it bypasses token output limits by distributing code across multiple files. Second, it enhances precision; by focusing on smaller logical units, the agent encounters less context noise and can handle complex logic with greater accuracy. Third, it enables efficiency via caching, as validated modules can be reused without regeneration. Finally, it significantly improves testability, as debugging is localized to specific files rather than requiring full-script diagnosis.

We define a node solution sn as a tuple comprising a set of l independent modules and one orchestration script:

<table id="S4.EGx2" class="ltx_equationgroup ltx_eqn_align ltx_eqn_table"><tbody id="S4.E2"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_td ltx_align_right ltx_eqn_cell"><math id="S4.E2.m1" class="ltx_Math" alttext="\displaystyle s_{n}=\langle\{\mathcal{M}_{j}\}_{j=1}^{l},\pi_{main}\rangle" display="inline" intent=":literal"><semantics><mrow><msub><mi>s</mi><mi>n</mi></msub><mo>=</mo><mrow><mo stretchy="false">⟨</mo><mrow><msubsup><mrow><mo stretchy="false">{</mo><msub><mi class="ltx_font_mathcaligraphic">ℳ</mi><mi>j</mi></msub><mo stretchy="false">}</mo></mrow><mrow><mi>j</mi><mo>=</mo><mn>1</mn></mrow><mi>l</mi></msubsup><mo>,</mo><msub><mi>π</mi><mrow><mi>m</mi><mo lspace="0em" rspace="0em">​</mo><mi>a</mi><mo lspace="0em" rspace="0em">​</mo><mi>i</mi><mo lspace="0em" rspace="0em">​</mo><mi>n</mi></mrow></msub></mrow><mo stretchy="false">⟩</mo></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(2)</span></td></tr></tbody></table>

Each module ℳj encapsulates a specific sub-task (e.g., data preprocessing, configuration), while the main script πmain orchestrates the end-to-end pipeline.

To instantiate this structure, we employ a three-stage “Design-Decompose-Implement” workflow:

-   •
    
    Idea Generation: An Idea Generation Agent articulates a comprehensive natural language plan covering various aspects of the solution.
    
-   •
    
    Module Decomposition: A Modular Agent parses the plan and decomposes the solution into logical, independent functional modules.
    
-   •
    
    Component Implementation and Debugging: A Coding Agent sequentially implements each module ℳj, employing a validation script to debug and verify functionality. Once validated, the agent orchestrates the modules via the main script πmain.
    

To prevent wasteful full-repository regeneration, we adopt a Diff-Based Editing mechanism. Code modifications are structured in a standardized diff format, specifying the target file, the block to replace, and the new code. This enables atomic, multi-file updates in a single inference step.

### 4.3 Comparative Reflective Memory

Solving complex tasks requires long-horizon exploration, generating extensive interaction trajectories that often exceed context window constraints. More importantly, research progress is inherently iterative and opaque; when a new experiment yields improved results, isolating the specific causal factors remains a challenge. Standard memory-based agents often lack the mechanisms to solve this credit assignment problem, failing to learn effectively from past trials. To address this, we propose Comparative Reflective Memory, a mechanism designed to distill high-signal, causal insights from the exploration process into a compact lesson pool.

##### Solution Improvement via Comparative Reflection.

We employ a two-stage process to resolve the credit assignment problem by synthesizing lessons from valid solutions. First, an Empirical Analysis Agent reviews execution logs to extract objective findings (e.g., metric trends). Subsequently, a Lesson Distillation Agent performs a comparative reflection by analyzing the delta between the current solution and the previous best-known solution. This isolates the specific algorithmic changes driving performance shifts, resulting in a structured lesson containing: (1) The isolated causal change, (2) A comparative impact analysis, and (3) A generalized rule for future iterations.

##### Debugging Lessons.

For failed executions, a dedicated agent analyzes the buggy code, error logs, and the applied fix. It outputs a lesson confirming the fix’s efficacy, explaining the failure logic, and providing guidelines to preemptively identify similar errors.

##### Lesson Management.

To maintain a high-signal lesson pool, a Review Agent evaluates new lessons against the existing pool through LLM-based reasoning, filtering out redundant insights to ensure the retrieved context remains diverse and relevant.

##### Lesson Utilization.

When executing solution improvement or debugging actions, the agent utilizes relevant knowledge from the corresponding lesson categories. We retain the Km most recent lessons in the agent’s memory to manage context. To ensure interpretability, the agent is instructed to explicitly cite specific lessons whenever they are applied.

### 4.4 Budget-Aware MCTS

We adopt the Monte Carlo Tree Search (MCTS) framework to explore the solution space, which iterates through four phases: Selection, Expansion, Simulation, and Backpropagation. In this section, we detail our domain-specific modifications: (1) specialized expansion operators, (2) a coherent node selection strategy, and (3) an Efficiency-Guided Reward Function that balances performance with cost. Appendix [C](https://arxiv.org/html/2602.02660#A3 "Appendix C Monte Carlo Tree Search (MCTS) ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") provides a review of standard MCTS principles.

#### 4.4.1 Actions and Expansion

We define three distinct operators to transform a parent state sp​a​r​e​n​t into a child solution sn​e​w:

-   •
    
    Drafting (Root Expansion): Generates a completely new solution sn​e​w from scratch.
    
-   •
    
    Improvement: Applied to valid, executable nodes. The agent modifies the modules and the main script from sp​a​r​e​n​t to maximize the objective 𝒪.
    
-   •
    
    Debugging: Applied to nodes where execution failed. The agent inherits the solution structure from sp​a​r​e​n​t but modifies specific modules or the orchestration script to resolve runtime errors. Buggy children enter an automatic debugging loop with up to Nd debugging actions to fix the errors.
    

#### 4.4.2 Node Selection

We employ the Upper Confidence Bound for Trees (UCT) algorithm to navigate the solution space, balancing the exploitation of high-performing solutions with the exploration of new solutions.

The selection phase begins at the root node. In each step, we select the child node that maximizes the UCT value. This traversal continues recursively until we identify a candidate node, defined as a node that is not yet “fully expanded”.

The root node is set fully expanded unless any of the follow condition occurs: (1) It does not have any children; (2) the best solution has not been improved after implementing ns valid nodes.

If the traversal reaches a leaf node that is already fully expanded (it implies that no further debugging or improvement is permitted for that branch), then the root node is re-activated to allow for new drafts.

The buggy nodes are always set fully expanded. The valid nodes are set fully expanded if they have ≥Ni children (attempts to improve).

#### 4.4.3 Efficiency-Guided Reward Function

To guide the search efficiently, we design a reward function R⁡(v) that rewards performance gains and penalizes long execution time. Let M⁡(v) denote the performance metric of a node v, and let t⁡(v) and L⁡(v) represent its execution time and time limit, respectively. We first normalize the performance metric relative to the history of explored nodes 𝒱. Let Mm​a​x\=maxv′∈𝒱⁡M⁡(v′) and Mm​i​n\=minv′∈𝒱⁡M⁡(v′). We define the global normalized score G⁡(v) as:

<table id="S4.EGx3" class="ltx_equationgroup ltx_eqn_align ltx_eqn_table"><tbody id="S4.E3"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_td ltx_align_right ltx_eqn_cell"><math id="S4.E3.m1" class="ltx_Math" alttext="\displaystyle G(v):=\begin{cases}0.5\quad\text{if }M_{max}=M_{min},\\
\frac{M(v)-M_{min}}{M_{max}-M_{min}}\quad\text{otherwise}\end{cases}" display="inline" intent=":literal"><semantics><mrow><mrow><mi>G</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>v</mi><mo stretchy="false">)</mo></mrow></mrow><mo>:=</mo><mrow><mo>{</mo><mtable columnspacing="5pt" rowspacing="0pt"><mtr><mtd class="ltx_align_left" columnalign="left"><mrow><mrow><mn>0.5</mn><mspace style="width:1em;" width="1em"></mspace><mrow><mrow><mtext>if&nbsp;</mtext><mo lspace="0em" rspace="0em">​</mo><msub><mi>M</mi><mrow><mi>m</mi><mo lspace="0em" rspace="0em">​</mo><mi>a</mi><mo lspace="0em" rspace="0em">​</mo><mi>x</mi></mrow></msub></mrow><mo>=</mo><msub><mi>M</mi><mrow><mi>m</mi><mo lspace="0em" rspace="0em">​</mo><mi>i</mi><mo lspace="0em" rspace="0em">​</mo><mi>n</mi></mrow></msub></mrow></mrow><mo>,</mo></mrow></mtd><mtd></mtd></mtr><mtr><mtd class="ltx_align_left" columnalign="left"><mrow><mfrac><mrow><mrow><mi>M</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>v</mi><mo stretchy="false">)</mo></mrow></mrow><mo>−</mo><msub><mi>M</mi><mrow><mi>m</mi><mo lspace="0em" rspace="0em">​</mo><mi>i</mi><mo lspace="0em" rspace="0em">​</mo><mi>n</mi></mrow></msub></mrow><mrow><msub><mi>M</mi><mrow><mi>m</mi><mo lspace="0em" rspace="0em">​</mo><mi>a</mi><mo lspace="0em" rspace="0em">​</mo><mi>x</mi></mrow></msub><mo>−</mo><msub><mi>M</mi><mrow><mi>m</mi><mo lspace="0em" rspace="0em">​</mo><mi>i</mi><mo lspace="0em" rspace="0em">​</mo><mi>n</mi></mrow></msub></mrow></mfrac><mspace style="width:1em;" width="1em"></mspace><mtext>otherwise</mtext></mrow></mtd><mtd></mtd></mtr></mtable></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(3)</span></td></tr></tbody></table>

To incorporate budget constraints, we modulate this score by execution latency, defining efficiency-guided reward as:

<table id="S4.EGx4" class="ltx_equationgroup ltx_eqn_align ltx_eqn_table"><tbody id="S4.E4"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_td ltx_align_right ltx_eqn_cell"><math id="S4.E4.m1" class="ltx_Math" alttext="\displaystyle R(v):=G(v)\cdot[t(v)/L(v)]^{w}" display="inline" intent=":literal"><semantics><mrow><mrow><mi>R</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>v</mi><mo stretchy="false">)</mo></mrow></mrow><mo>:=</mo><mrow><mrow><mi>G</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>v</mi><mo rspace="0.055em" stretchy="false">)</mo></mrow></mrow><mo rspace="0.222em">⋅</mo><msup><mrow><mo stretchy="false">[</mo><mrow><mrow><mi>t</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>v</mi><mo stretchy="false">)</mo></mrow></mrow><mo>/</mo><mrow><mi>L</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>v</mi><mo stretchy="false">)</mo></mrow></mrow></mrow><mo stretchy="false">]</mo></mrow><mi>w</mi></msup></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(4)</span></td></tr></tbody></table>

Where w is a penalty weight hyperparameter. A similar function has been proposed in [Tan et al. (2019)](https://arxiv.org/html/2602.02660#bib.bib2).

Table 2: Performance comparison on MLE-Bench. Results are reported as mean ± SEM across three independent runs. All values are in percentages (%). Bold and underlined values denote the best and second-best performance, respectively. Refer to Appendix [E](https://arxiv.org/html/2602.02660#A5 "Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") for a detailed comparison of evaluation setups.

Agent Model Valid Submission Above Median Bronze Silver Gold Any Medal Official MLE-Bench Leaderboard Results ML-Master ([Liu et al., 2025b](https://arxiv.org/html/2602.02660#bib.bib9)) Deepseek-R1 93.3±1.3 44.9±1.2 4.4±0.9 7.6±0.4 17.3±0.8 29.3±0.8 R&D-Agent ([Yang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib11)) GPT-5 53.3±0.0 40.4±0.9 6.7±1.5 12.0±0.8 16.4±0.9 35.1±0.4 InternAgent ([Team et al., 2025](https://arxiv.org/html/2602.02660#bib.bib17)) Deepseek-R1 96.4±0.4 48.4±1.2 7.1±1.6 10.7±0.8 18.7±0.8 36.4±1.2 Famou-Agent ([Li et al., 2025](https://arxiv.org/html/2602.02660#bib.bib18)) Gemini-2.5-Pro 96.9±1.2 51.6±1.2 8.4±0.4 12.4±1.9 22.7±0.8 43.6±0.9 Leeroo ([Nadaf et al., 2025](https://arxiv.org/html/2602.02660#bib.bib20)) Gemini-3-Pro-Preview 50.7±1.3 50.7±1.3 14.2±1.2 15.1±0.9 21.3±2.0 50.7±1.3 ML-Master 2.0 ([Zhu et al., 2026](https://arxiv.org/html/2602.02660#bib.bib19)) Deepseek-V3.2-Speciale 95.6±1.2 63.1±1.2 11.1±0.4 25.8±2.5 19.6±0.9 56.4±2.5 Controlled Evaluation in Our Environment AIDE ([Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3)) Gemini-2.5-Pro 84.4±0.4 40.0±0.8 5.8±0.9 4.9±1.2 12.4±0.9 23.1±0.4 Gemini-3-Pro-Preview 82.7±0.8 48.0±0.0 4.9±0.4 11.1±1.2 16.4±1.8 32.4±2.5 AIRA-dojo ([Toledo et al., 2026](https://arxiv.org/html/2602.02660#bib.bib12)) Gemini-2.5-Pro 83.6±2.4 38.7±0.8 2.7±0.8 6.7±2.3 15.1±1.2 24.4±1.2 Gemini-3-Pro-Preview 98.2±1.2 55.6±1.2 5.8±1.9 8.0±0.8 24.0±1.5 37.8±2.5 MARS (ours) Gemini-2.5-Pro 94.2±0.4 52.4±0.9 11.6±1.9 12.4±0.9 19.1±0.4 43.1±1.6 Gemini-3-Pro-Preview 98.7±0.0 65.8¯±1.6 9.3±0.0 15.6±1.2 31.1¯±0.4 56.0¯±1.5 MARS+ (ours) Gemini-3-Pro-Preview 100.0±0.0 74.2±0.9 12.4±1.9 16.4±1.2 33.8±0.4 62.7±0.8

### 4.5 Task Specific Components

While MARS is a general framework, its application requires task-specific components. For Machine Learning Engineering (MLE) tasks, we integrate the following:

Task preparation. We employ a multi-agent system to extract task metadata, formalizing the optimization objective and preparing training, validation, and test datasets.

Data analysis. We employ an agent to perform Exploratory Data Analysis (EDA) to generate a report that guides downstream feature engineering.

Curriculum-Based Exploration. We implement a curriculum-based idea generation strategy that progressively explores simple baselines to complex methods.

Refer to the Appendix [D](https://arxiv.org/html/2602.02660#A4 "Appendix D MARS for MLE Tasks ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") for the details.

## 5 Experiment

### 5.1 Setup

Datasets. We evaluate our agent on MLE-Bench ([Chan et al., 2025](https://arxiv.org/html/2602.02660#bib.bib1)), which consists of 75 challenging competitions from Kaggle, forming a diverse collection of tasks covering natural language processing, computer vision, and tabular data analysis.

Environments. We adhere to the standard MLE-Bench protocol, where agents are allocated a strict 24-hour wall-clock time budget per competition. This budget encompasses the entire pipeline, including dataset preparation, feature engineering, model training, and inference. The experiment for each agent on each competition is conducted on a standard node equipped with one NVIDIA A100 GPU (40GB), 12 vCPUs, 220 GB of RAM, and 1 TB of SSD storage. This setup simulates a realistic, resource-constrained machine learning engineering environment.

Baselines. We compare our method to the agents in the MLE-Bench leaderboard 1 and two state-of-the-art open-source agents: AIDE ([Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3)) and AIRA ([Toledo et al., 2026](https://arxiv.org/html/2602.02660#bib.bib12)). For open-source baselines, we ensure a strictly fair comparison by running them under identical environment configurations and using the same underlying LLMs.

Metrics. Following the standard MLE-Bench evaluation protocol, we report the mean and standard error of the mean (SEM) across three independent runs. Our evaluation focuses on three primary metrics: Above Median Rate (percentage of runs outperforming the median participant), Any Medal Rate (percentage achieving at least a Bronze medal), and Gold Medal Rate (percentage securing a Gold medal).

Hyperparameters. We set the maximum number of lessons in the agent’s memory to Km\=30 to maintain relevant context without context window overflow. We allow up to Nd\=10 debugging actions per failure to resolve runtime errors effectively. The branching factor for valid nodes is set to Ni\=2, balancing exploration breadth with depth. We set w\=−0.07 in the reward function ([4](https://arxiv.org/html/2602.02660#S4.E4 "Equation 4 ‣ 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research")) following [Tan et al. (2019)](https://arxiv.org/html/2602.02660#bib.bib2) to penalize excessive execution time.

### 5.2 Main Results

We compare MARS against state-of-the-art baselines in Table [2](https://arxiv.org/html/2602.02660#S4.T2 "Table 2 ‣ 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"). In the controlled evaluation, MARS establishes a new state-of-the-art among open-source frameworks, significantly outperforming AIDE and AIRA-dojo under identical constraints. When compared to the official leaderboard, our method remains highly competitive despite using significantly fewer resources (see Appendix [E](https://arxiv.org/html/2602.02660#A5 "Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") for setup disparities). Notably, the standard MARS achieves the highest Gold Medal rate (31.1%) among all reported agents. To assess scalability, we evaluate MARS+, a variant configured to execute two concurrent search trees with increased compute (2×H100 GPUs and 48 vCPUs). This scaled approach achieves the highest Above Median rate (74.2%), Gold Medal rate (33.8%), and Any Medal rate (62.7%), outperforming strong competitors like ML-Master 2.0. Finally, Table [3](https://arxiv.org/html/2602.02660#S5.T3 "Table 3 ‣ 5.2 Main Results ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") decomposes performance by task complexity, demonstrating that MARS consistently outperforms baselines across the Lite, Medium, and High splits.

Table 3: Controlled evaluation in our environment across different splits of MLE-Bench. Results are reported as mean ± SEM across three independent runs. The best performance is highlighted in bold, and the second-best is underlined. The complete results including leaderboard results and other metrics are in Appendix [F.1](https://arxiv.org/html/2602.02660#A6.SS1 "F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").

<table id="S5.T3.7" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="S5.T3.7.1" class="ltx_tr"><td id="S5.T3.7.1.1" class="ltx_td ltx_align_left ltx_border_tt" style="padding-left:5.0pt;padding-right:5.0pt;" rowspan="2"><span id="S5.T3.7.1.1.1" class="ltx_text ltx_font_bold">Agent</span></td><td id="S5.T3.7.1.2" class="ltx_td ltx_align_left ltx_border_tt" style="padding-left:5.0pt;padding-right:5.0pt;" rowspan="2"><span id="S5.T3.7.1.2.1" class="ltx_text ltx_font_bold">Model</span></td><td id="S5.T3.7.1.3" class="ltx_td ltx_align_center ltx_border_tt" style="padding-left:5.0pt;padding-right:5.0pt;" colspan="3"><span id="S5.T3.7.1.3.1" class="ltx_text ltx_font_bold">Any Medal</span></td></tr><tr id="S5.T3.7.2" class="ltx_tr"><td id="S5.T3.7.2.1" class="ltx_td ltx_align_center" style="padding-left:5.0pt;padding-right:5.0pt;">Lite (%)</td><td id="S5.T3.7.2.2" class="ltx_td ltx_align_center" style="padding-left:5.0pt;padding-right:5.0pt;">Medium (%)</td><td id="S5.T3.7.2.3" class="ltx_td ltx_align_center" style="padding-left:5.0pt;padding-right:5.0pt;">High (%)</td></tr><tr id="S5.T3.7.3" class="ltx_tr"><td id="S5.T3.7.3.1" class="ltx_td ltx_align_left ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;" rowspan="2"><span id="S5.T3.7.3.1.1" class="ltx_text ltx_font_bold">AIDE</span></td><td id="S5.T3.7.3.2" class="ltx_td ltx_align_left ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;">Gemini-2.5-Pro</td><td id="S5.T3.7.3.3" class="ltx_td ltx_align_center ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m3" class="ltx_Math" alttext="36.4\pm 4.5" display="inline" intent=":literal"><semantics><mrow><mn>36.4</mn><mo>±</mo><mn>4.5</mn></mrow></semantics></math></td><td id="S5.T3.7.3.4" class="ltx_td ltx_align_center ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m4" class="ltx_Math" alttext="18.4\pm 2.6" display="inline" intent=":literal"><semantics><mrow><mn>18.4</mn><mo>±</mo><mn>2.6</mn></mrow></semantics></math></td><td id="S5.T3.7.3.5" class="ltx_td ltx_align_center ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m5" class="ltx_Math" alttext="15.6\pm 2.2" display="inline" intent=":literal"><semantics><mrow><mn>15.6</mn><mo>±</mo><mn>2.2</mn></mrow></semantics></math></td></tr><tr id="S5.T3.7.4" class="ltx_tr"><td id="S5.T3.7.4.1" class="ltx_td ltx_align_left" style="padding-left:5.0pt;padding-right:5.0pt;">Gemini-3-Pro-Prev.</td><td id="S5.T3.7.4.2" class="ltx_td ltx_align_center" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m6" class="ltx_Math" alttext="53.0\pm 6.1" display="inline" intent=":literal"><semantics><mrow><mn>53.0</mn><mo>±</mo><mn>6.1</mn></mrow></semantics></math></td><td id="S5.T3.7.4.3" class="ltx_td ltx_align_center" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m7" class="ltx_Math" alttext="26.3\pm 3.0" display="inline" intent=":literal"><semantics><mrow><mn>26.3</mn><mo>±</mo><mn>3.0</mn></mrow></semantics></math></td><td id="S5.T3.7.4.4" class="ltx_td ltx_align_center" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m8" class="ltx_Math" alttext="17.8\pm 2.2" display="inline" intent=":literal"><semantics><mrow><mn>17.8</mn><mo>±</mo><mn>2.2</mn></mrow></semantics></math></td></tr><tr id="S5.T3.7.5" class="ltx_tr"><td id="S5.T3.7.5.1" class="ltx_td ltx_align_left ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><span id="S5.T3.7.5.1.1" class="ltx_text ltx_font_bold">AIRA</span></td><td id="S5.T3.7.5.2" class="ltx_td ltx_align_left ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;">Gemini-2.5-Pro</td><td id="S5.T3.7.5.3" class="ltx_td ltx_align_center ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m9" class="ltx_Math" alttext="40.9\pm 2.6" display="inline" intent=":literal"><semantics><mrow><mn>40.9</mn><mo>±</mo><mn>2.6</mn></mrow></semantics></math></td><td id="S5.T3.7.5.4" class="ltx_td ltx_align_center ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m10" class="ltx_Math" alttext="16.7\pm 3.5" display="inline" intent=":literal"><semantics><mrow><mn>16.7</mn><mo>±</mo><mn>3.5</mn></mrow></semantics></math></td><td id="S5.T3.7.5.5" class="ltx_td ltx_align_center ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m11" class="ltx_Math" alttext="20.0\pm 0.0" display="inline" intent=":literal"><semantics><mrow><mn>20.0</mn><mo>±</mo><mn>0.0</mn></mrow></semantics></math></td></tr><tr id="S5.T3.7.6" class="ltx_tr"><td id="S5.T3.7.6.1" class="ltx_td ltx_align_left" style="padding-left:5.0pt;padding-right:5.0pt;"><span id="S5.T3.7.6.1.1" class="ltx_text ltx_font_bold">-dojo</span></td><td id="S5.T3.7.6.2" class="ltx_td ltx_align_left" style="padding-left:5.0pt;padding-right:5.0pt;">Gemini-3-Pro-Prev.</td><td id="S5.T3.7.6.3" class="ltx_td ltx_align_center" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m12" class="ltx_Math" alttext="56.1\pm 1.5" display="inline" intent=":literal"><semantics><mrow><mn>56.1</mn><mo>±</mo><mn>1.5</mn></mrow></semantics></math></td><td id="S5.T3.7.6.4" class="ltx_td ltx_align_center" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m13" class="ltx_Math" alttext="29.8\pm 3.8" display="inline" intent=":literal"><semantics><mrow><mn>29.8</mn><mo>±</mo><mn>3.8</mn></mrow></semantics></math></td><td id="S5.T3.7.6.5" class="ltx_td ltx_align_center" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m14" class="ltx_Math" alttext="\underline{31.1}\pm 4.4" display="inline" intent=":literal"><semantics><mrow><munder accentunder="true"><mn>31.1</mn><mo stretchy="true">¯</mo></munder><mo>±</mo><mn>4.4</mn></mrow></semantics></math></td></tr><tr id="S5.T3.7.7" class="ltx_tr"><td id="S5.T3.7.7.1" class="ltx_td ltx_align_left ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><span id="S5.T3.7.7.1.1" class="ltx_text ltx_font_bold">MARS</span></td><td id="S5.T3.7.7.2" class="ltx_td ltx_align_left ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;">Gemini-2.5-Pro</td><td id="S5.T3.7.7.3" class="ltx_td ltx_align_center ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m15" class="ltx_Math" alttext="\underline{68.2}\pm 2.6" display="inline" intent=":literal"><semantics><mrow><munder accentunder="true"><mn>68.2</mn><mo stretchy="true">¯</mo></munder><mo>±</mo><mn>2.6</mn></mrow></semantics></math></td><td id="S5.T3.7.7.4" class="ltx_td ltx_align_center ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m16" class="ltx_Math" alttext="\underline{33.3}\pm 1.8" display="inline" intent=":literal"><semantics><mrow><munder accentunder="true"><mn>33.3</mn><mo stretchy="true">¯</mo></munder><mo>±</mo><mn>1.8</mn></mrow></semantics></math></td><td id="S5.T3.7.7.5" class="ltx_td ltx_align_center ltx_border_t" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m17" class="ltx_Math" alttext="\underline{31.1}\pm 2.2" display="inline" intent=":literal"><semantics><mrow><munder accentunder="true"><mn>31.1</mn><mo stretchy="true">¯</mo></munder><mo>±</mo><mn>2.2</mn></mrow></semantics></math></td></tr><tr id="S5.T3.7.8" class="ltx_tr"><td id="S5.T3.7.8.1" class="ltx_td ltx_align_left ltx_border_bb" style="padding-left:5.0pt;padding-right:5.0pt;"><span id="S5.T3.7.8.1.1" class="ltx_text ltx_font_bold">(ours)</span></td><td id="S5.T3.7.8.2" class="ltx_td ltx_align_left ltx_border_bb" style="padding-left:5.0pt;padding-right:5.0pt;">Gemini-3-Pro-Prev.</td><td id="S5.T3.7.8.3" class="ltx_td ltx_align_center ltx_border_bb" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m18" class="ltx_Math" alttext="\textbf{74.2}\pm 1.5" display="inline" intent=":literal"><semantics><mrow><mtext class="ltx_mathvariant_bold">74.2</mtext><mo>±</mo><mn>1.5</mn></mrow></semantics></math></td><td id="S5.T3.7.8.4" class="ltx_td ltx_align_center ltx_border_bb" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m19" class="ltx_Math" alttext="\textbf{52.6}\pm 3.0" display="inline" intent=":literal"><semantics><mrow><mtext class="ltx_mathvariant_bold">52.6</mtext><mo>±</mo><mn>3.0</mn></mrow></semantics></math></td><td id="S5.T3.7.8.5" class="ltx_td ltx_align_center ltx_border_bb" style="padding-left:5.0pt;padding-right:5.0pt;"><math id="S5.T3.m20" class="ltx_Math" alttext="\textbf{37.8}\pm 2.2" display="inline" intent=":literal"><semantics><mrow><mtext class="ltx_mathvariant_bold">37.8</mtext><mo>±</mo><mn>2.2</mn></mrow></semantics></math></td></tr></tbody></table>

### 5.3 Ablation Study

(a) Effect of modular decomposition.

(b) Effect of memory mechanisms.

(c) Comparison of tree search strategies.

(d) Effect of the penalty weight w.

Figure 3: Ablation study results on MLE-Bench Lite. Results for the Medium and High splits are provided in the Appendix [F.3](https://arxiv.org/html/2602.02660#A6.SS3 "F.3 Ablation Study Results on MLE-Bench Medium and High Splits ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").

We evaluate the individual components of MARS on 22 competitions from the MLE-Bench Lite dataset (Figure [3](https://arxiv.org/html/2602.02660#S5.F3 "Figure 3 ‣ 5.3 Ablation Study ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research")).

Modular Decomposition. As illustrated in Figure [3(a)](https://arxiv.org/html/2602.02660#S5.F3.sf1 "Figure 3(a) ‣ Figure 3 ‣ 5.3 Ablation Study ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), removing the modular decomposition component degrades the agent’s overall success, validating its ability to reduce context noise and improve testability across independent functional modules.

Memory Mechanisms. Figure [3(b)](https://arxiv.org/html/2602.02660#S5.F3.sf2 "Figure 3(b) ‣ Figure 3 ‣ 5.3 Ablation Study ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") highlights the critical importance of our memory architecture. Complete removal of memory mechanisms results in a drastic performance drop. Furthermore, to isolate the specific benefits of comparative distillation, we tested a variant of our method against a baseline utilizing only empirical analysis to distill lessons, without comparing them to the best-known solution. The results demonstrate that the comparative component provides a consistent performance boost. This confirms that code-level comparisons are essential for isolating causal factors. Without this “delta” analysis, the agent often over-generalizes from noisy logs. In contrast, comparative reflective memory allows it to distill precise, actionable heuristics, effectively mirroring human-led ablation experiments.

Tree Search Strategies. Figure [3(c)](https://arxiv.org/html/2602.02660#S5.F3.sf3 "Figure 3(c) ‣ Figure 3 ‣ 5.3 Ablation Study ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") compares different tree search algorithms for MARS. While Greedy Search selects the node with the best validation metric for expansion at each step, Vanilla MCTS operates as a variant of Budget-Aware MCTS where w\=0 (Eq. [4](https://arxiv.org/html/2602.02660#S4.E4 "Equation 4 ‣ 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research")). The results indicate that the proposed Budget-Aware MCTS consistently yields superior performance over time by effectively balancing exploration with resource constraints.

Penalty Weight w. Figure [3(d)](https://arxiv.org/html/2602.02660#S5.F3.sf4 "Figure 3(d) ‣ Figure 3 ‣ 5.3 Ablation Study ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") evaluates Budget-Aware MCTS across varying penalty weights. The default setting of w\=−0.07 proves optimal. Removing the penalty entirely (w\=0) causes performance degradation, underscoring the importance of penalizing long execution times alongside rewarding performance. Conversely, a stronger penalty (w\=−0.15) excessively biases the reward toward latency, causing the search to prioritize trivial, fast nodes over high-performing ones.

## 6 Discussions

##### How does Modular Decomposition impact solution complexity?

We investigate whether Modular Decomposition facilitates the construction of complex solutions for each task. Table [4](https://arxiv.org/html/2602.02660#S6.T4 "Table 4 ‣ How does Modular Decomposition impact solution complexity? ‣ 6 Discussions ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") compares the repository statistics of MARS with and without modular decomposition for the best solution. The results show that the modular approach encourages the generation of more extensive and structured codebases (measured by lines of code and number of files in the best solution). To illustrate this structural adaptability, Table [5](https://arxiv.org/html/2602.02660#S6.T5 "Table 5 ‣ How does Modular Decomposition impact solution complexity? ‣ 6 Discussions ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") enumerates the specific modules synthesized for five representative competitions. The diversity of these modules – tailored to specific sub-tasks such as preprocessing and model architecture – demonstrates the agent’s ability to decompose intricate problems into logical components. This capacity to architect organized, repository-level solutions closely mirrors professional software engineering workflows.

Table 4: Comparison of repository statistics between MARS and the variant without Modular Decomposition on MLE-Bench Lite.

<table id="S6.T4.5" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="S6.T4.5.1" class="ltx_tr"><td id="S6.T4.5.1.1" class="ltx_td ltx_align_left ltx_border_tt"><span id="S6.T4.5.1.1.1" class="ltx_text ltx_font_bold">Metric</span></td><td id="S6.T4.5.1.2" class="ltx_td ltx_align_center ltx_border_tt"><span id="S6.T4.5.1.2.1" class="ltx_text ltx_font_bold">MARS without Modular</span></td><td id="S6.T4.5.1.3" class="ltx_td ltx_align_center ltx_border_tt"><span id="S6.T4.5.1.3.1" class="ltx_text ltx_font_bold">MARS</span></td></tr><tr id="S6.T4.5.2" class="ltx_tr"><td id="S6.T4.5.2.1" class="ltx_td ltx_align_left ltx_border_t">Lines of Code</td><td id="S6.T4.5.2.2" class="ltx_td ltx_align_center ltx_border_t"><math id="S6.T4.m1" class="ltx_Math" alttext="474.8\pm 13.5" display="inline" intent=":literal"><semantics><mrow><mn>474.8</mn><mo>±</mo><mn>13.5</mn></mrow></semantics></math></td><td id="S6.T4.5.2.3" class="ltx_td ltx_align_center ltx_border_t"><math id="S6.T4.m2" class="ltx_Math" alttext="1103.9\pm 35.9" display="inline" intent=":literal"><semantics><mrow><mn>1103.9</mn><mo>±</mo><mn>35.9</mn></mrow></semantics></math></td></tr><tr id="S6.T4.5.3" class="ltx_tr"><td id="S6.T4.5.3.1" class="ltx_td ltx_align_left ltx_border_bb">Number of Files</td><td id="S6.T4.5.3.2" class="ltx_td ltx_align_center ltx_border_bb"><math id="S6.T4.m3" class="ltx_Math" alttext="1.0\pm 0.0" display="inline" intent=":literal"><semantics><mrow><mn>1.0</mn><mo>±</mo><mn>0.0</mn></mrow></semantics></math></td><td id="S6.T4.5.3.3" class="ltx_td ltx_align_center ltx_border_bb"><math id="S6.T4.m4" class="ltx_Math" alttext="6.7\pm 0.1" display="inline" intent=":literal"><semantics><mrow><mn>6.7</mn><mo>±</mo><mn>0.1</mn></mrow></semantics></math></td></tr></tbody></table>

Table 5: Modules generated by MARS on challenging competitions.

Competition Modules aptos2019-blindness-detection dataset.py, engine.py, model.py, utils.py jigsaw-toxic-comment-classification-challenge data\_processing.py, model\_definitions.py, training\_engine.py, utils.py us-patent-phrase-to-phrase-matching config.py, cpc\_utils.py, dataset.py, engine.py, loss.py, model.py, utils.py h-and-m-personalized-fashion-recommendations config.py, data\_factory.py, embedder.py, features.py, ranker.py, retrieval.py multi-modal-gesture-recognition config.py, data\_loader.py, inference.py, losses.py, model.py, trainer.py, utils.py

Figure 4: Reward modulation: Budget-aware MCTS assigns higher rewards to faster candidates when performance is comparable.

##### Does Budget-aware MCTS improve exploration?

We examine whether Budget-aware MCTS discovers high-quality solutions more frequently than the Vanilla MCTS. We define the effective solution rate as the proportion of explored solutions that improve upon the current best validation metric per task. Empirically, Budget-aware MCTS achieves an effective solution rate of 19.5%±1.5%, notably higher than the 16.1%±1.3% observed with Vanilla MCTS. This suggests that the latency penalty acts as a heuristic to prune inefficient trajectories. As illustrated in Figure [4](https://arxiv.org/html/2602.02660#S6.F4 "Figure 4 ‣ How does Modular Decomposition impact solution complexity? ‣ 6 Discussions ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), when the agent encounters solutions with comparable accuracy but differing costs, our efficiency-guided reward favors the faster candidate. This bias directs computational resources toward efficient nodes, accelerating the discovery of optimal solutions within the time limit.

##### How lessons guide the evolution process?

We examine the role of Lesson Learning in guiding the agent’s solution exploration. Figure [1](https://arxiv.org/html/2602.02660#S1.F1 "Figure 1 ‣ 1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") illustrates an example where the agent formulates lessons from early failures or partial successes and applies them to refine subsequent solutions. To quantify this behavior, we introduce two metrics: the lesson-utilization rate (the proportion of solutions that incorporate existing lessons) and the lesson-transfer rate (the proportion of utilized solution lessons originating from a different tree branch). MARS achieves a lesson-utilization rate of 65.8%±1.1% and a lesson-transfer rate of 63.0%±1.8% on MLE-Bench. These results demonstrate that the agent actively leverages learned knowledge and cross-branch transfer to steer the search toward high-quality strategies.

Figure 5: Distribution of maximum code similarity scores for medal-winning submissions from AIRA-dojo and MARS, compared against top public Kaggle notebooks.

##### Does MARS follow the MLE-Bench rules?

To verify compliance, we employ the official MLE-Bench log analysis tool, which utilizes gpt-4.1-mini to audit the logs and code outputs of all medal-winning submissions. The evaluation confirms that MARS strictly adheres to the protocol, registering a 0% violation rate across all monitored dimensions, including “Tried to access unauthorized resources”, “Tried to call external LLM API service”, and “Manually-written submission”. Furthermore, we assess code originality using the provided plagiarism detection tool based on Dolos ([Maertens et al., 2024](https://arxiv.org/html/2602.02660#bib.bib21)). We calculate the maximum similarity score between our agent’s code – concatenated into a single file for multi-module repositories – and the top public notebooks for each competition. As shown in Figure [5](https://arxiv.org/html/2602.02660#S6.F5 "Figure 5 ‣ How lessons guide the evolution process? ‣ 6 Discussions ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), the similarity distribution of MARS mirrors that of the baseline AIRA-dojo. Crucially, no submission exceeds a 60% similarity threshold, demonstrating that MARS generates distinct, original solutions rather than reproducing existing public code.

##### Are the Distilled Lessons Causally Correct?

To verify whether MARS performs genuine credit assignment, we conducted a systematic evaluation of its distilled lessons. First, we utilized Claude 4.6 Sonnet to audit all 3,611 solution lessons generated by Gemini-3-Pro-Preview for causal accuracy. This audit confirmed that 88.34% of the lessons correctly attributed validation metric shifts to specific code changes, rather than relying on hallucinated narratives. Second, we manually inspected a representative subset of 20 lessons. This human evaluation yielded a 90% causal accuracy rate, confirming that the LLM-based audit serves as a reliable proxy for expert judgment. Together, this analysis provides concrete evidence that our method effectively resolves the credit assignment problem. Qualitative examples demonstrating this are provided in the Appendix [G](https://arxiv.org/html/2602.02660#A7 "Appendix G Qualitative Examples of Causally Correct Distilled Lessons ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").

##### Cost Analysis.

As detailed in Appendix [F.4](https://arxiv.org/html/2602.02660#A6.SS4 "F.4 Cost-Performance Trade-off ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), maintaining a comprehensive memory context results in a higher cost for the 24-hour version of MARS compared to AIRA-dojo ($60.5 vs. $39.0). However, this investment nearly doubles the Any Medal Rate (from 24.4% to 43.1%). More importantly, a cost-controlled evaluation demonstrates that a 4-hour version of MARS achieves a higher Any Medal Rate (28.4%) while spending significantly less ($9.6) than the 24-hour baselines. This Pareto improvement confirms that our performance gains stem from architectural efficiency rather than simply a larger resource budget.

## 7 Conclusion

In this work, we addressed the limitations of current autonomous agents in Long-Horizon AI Research by introducing MARS. Unlike traditional code generation approaches, our framework treats research as a rigorous, repository-level engineering challenge. By integrating Resource-Aware Planning via Budget-Aware MCTS, Modular Construction, and Comparative Reflective Memory, MARS effectively resolves the credit assignment problem while balancing exploration with computational efficiency. Our extensive evaluation on MLE-Bench demonstrates that this structured approach – mimicking the strategic foresight of human engineers – enables state-of-the-art performance in complex Machine Learning Engineering tasks. Future work will focus on extending MARS to broader scientific discovery domains and optimizing the framework’s economic viability through advanced context caching and early stopping mechanisms.

## Impact Statement

MARS contributes to the advancement of autonomous AI agents. While our work aims to enhance the reliability and efficiency of automated software engineering, we acknowledge potential broader impacts. The deployment of LLM-based agents involves risks related to the generation of incorrect or hallucinatory code; we mitigate this through iterative self-correction with code execution feedback. We do not foresee immediate negative societal consequences beyond those generally associated with the advancement of generative AI.

\\nobibliography

\*

## References

-   Chan et al. (2025) J. S. Chan, N. Chowdhury, O. Jaffe, J. Aung, D. Sherburn, E. Mays, G. Starace, K. Liu, L. Maksin, T. Patwardhan, et al. MLE-bench: evaluating machine learning agents on machine learning engineering. In International Conference on Learning Representations, Vol. 2025, pp. 50466–50494. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§5.1](https://arxiv.org/html/2602.02660#S5.SS1.p1.1 "5.1 Setup ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Forouzandeh et al. (2025) S. Forouzandeh, W. Peng, P. Moradi, X. Yu, and M. Jalili Learning hierarchical procedural memory for llm agents through bayesian selection and contrastive refinement. arXiv preprint arXiv:2512.18950. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p3.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Huang et al. (2024) Q. Huang, J. Vora, P. Liang, and J. Leskovec MLAgentBench: evaluating language agents on machine learning experimentation. In International Conference on Machine Learning, pp. 20271–20309. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p2.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Jansen et al. (2025) P. Jansen, O. Tafjord, M. Radensky, P. Siangliulue, T. Hope, B. Dalvi Mishra, B. P. Majumder, D. S. Weld, and P. Clark CodeScientist: end-to-end semi-automated scientific discovery with code-based experimentation. In Findings of the Association for Computational Linguistics: ACL 2025, W. Che, J. Nabende, E. Shutova, and M. T. Pilehvar (Eds.), Vienna, Austria. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p3.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Jiang et al. (2025) Z. Jiang, D. Schmidt, D. Srikanth, D. Xu, I. Kaplan, D. Jacenko, and Y. Wu Aide: ai-driven exploration in the space of code. arXiv preprint arXiv:2502.13138. Cited by: [Table 6](https://arxiv.org/html/2602.02660#A5.T6.3.1.1.1.1.1.8.1.1.1 "In Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 7](https://arxiv.org/html/2602.02660#A6.T7.7.1.1.1.1.1.10.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 8](https://arxiv.org/html/2602.02660#A6.T8.7.1.1.1.1.1.10.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 9](https://arxiv.org/html/2602.02660#A6.T9.7.1.1.1.1.1.10.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§1](https://arxiv.org/html/2602.02660#S1.p2.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p2.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 1](https://arxiv.org/html/2602.02660#S2.T1.3.1.1.1.1.1.1.2.1 "In Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 2](https://arxiv.org/html/2602.02660#S4.T2.7.1.1.1.1.1.10.1.1 "In 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§5.1](https://arxiv.org/html/2602.02660#S5.SS1.p3.1 "5.1 Setup ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Jimenez et al. (2023) C. E. Jimenez, J. Yang, A. Wettig, S. Yao, K. Pei, O. Press, and K. Narasimhan SWE-bench: can language models resolve real-world github issues?. CoRR abs/2310.06770. External Links: [Link](https://doi.org/10.48550/arXiv.2310.06770) Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Kocsis and Szepesvári (2006) L. Kocsis and C. Szepesvári Bandit based monte-carlo planning. In European conference on machine learning, pp. 282–293. Cited by: [item 1](https://arxiv.org/html/2602.02660#A3.I1.i1.p1.1 "In Appendix C Monte Carlo Tree Search (MCTS) ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p2.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Li et al. (2025) A. Li, C. Wu, Z. Ge, Y. H. Chong, Z. Hou, L. Cao, C. Ju, J. Wu, H. Li, H. Zhang, et al. The fm agent. arXiv preprint arXiv:2510.26144. Cited by: [Table 6](https://arxiv.org/html/2602.02660#A5.T6.3.1.1.1.1.1.5.1.1.1 "In Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 7](https://arxiv.org/html/2602.02660#A6.T7.7.1.1.1.1.1.6.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 8](https://arxiv.org/html/2602.02660#A6.T8.7.1.1.1.1.1.6.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 9](https://arxiv.org/html/2602.02660#A6.T9.7.1.1.1.1.1.6.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 2](https://arxiv.org/html/2602.02660#S4.T2.7.1.1.1.1.1.6.1.1 "In 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Li et al. (2022) Y. Li, D. Choi, J. Chung, N. Kushman, J. Schrittwieser, R. Leblond, T. Eccles, J. Keeling, F. Gimeno, A. Dal Lago, et al. Competition-level code generation with alphacode. Science 378 (6624), pp. 1092–1097. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Liu et al. (2025a) T. Liu, Z. Wang, J. Miao, I. Hsu, J. Yan, J. Chen, R. Han, F. Xu, Y. Chen, K. Jiang, et al. Budget-aware tool-use enables effective agent scaling. arXiv preprint arXiv:2511.17006. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p2.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Liu et al. (2025b) Z. Liu, Y. Cai, X. Zhu, Y. Zheng, R. Chen, Y. Wen, Y. Wang, S. Chen, et al. ML-master: towards ai-for-ai via integration of exploration and reasoning. arXiv preprint arXiv:2506.16499. Cited by: [Table 6](https://arxiv.org/html/2602.02660#A5.T6.3.1.1.1.1.1.2.1.1.1 "In Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 7](https://arxiv.org/html/2602.02660#A6.T7.7.1.1.1.1.1.3.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 8](https://arxiv.org/html/2602.02660#A6.T8.7.1.1.1.1.1.3.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 9](https://arxiv.org/html/2602.02660#A6.T9.7.1.1.1.1.1.3.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p2.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 2](https://arxiv.org/html/2602.02660#S4.T2.7.1.1.1.1.1.3.1.1 "In 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Lu et al. (2024) C. Lu, C. Lu, R. T. Lange, J. Foerster, J. Clune, and D. Ha The AI scientist: towards fully automated open-ended scientific discovery. arXiv preprint arXiv:2408.06292. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Maertens et al. (2024) R. Maertens, M. Van Neyghem, M. Geldhof, C. Van Petegem, N. Strijbol, P. Dawyndt, and B. Mesuere Discovering and exploring cases of educational source code plagiarism with dolos. SoftwareX 26, pp. 101755. Cited by: [§6](https://arxiv.org/html/2602.02660#S6.SS0.SSS0.Px4.p1.1 "Does MARS follow the MLE-Bench rules? ‣ 6 Discussions ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Nadaf et al. (2025) A. Nadaf, A. Mohammadshahi, M. Yazdani, and Leeroo Coding Agent Kapso: a knowledge-grounded framework for autonomous program synthesis and optimization. External Links: [Link](https://github.com/leeroo-ai/kapso) Cited by: [Table 6](https://arxiv.org/html/2602.02660#A5.T6.3.1.1.1.1.1.6.1.1.1 "In Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 7](https://arxiv.org/html/2602.02660#A6.T7.7.1.1.1.1.1.7.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 8](https://arxiv.org/html/2602.02660#A6.T8.7.1.1.1.1.1.7.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 9](https://arxiv.org/html/2602.02660#A6.T9.7.1.1.1.1.1.7.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 2](https://arxiv.org/html/2602.02660#S4.T2.7.1.1.1.1.1.7.1.1 "In 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Nam et al. (2026) J. Nam, J. Yoon, J. Chen, J. Shin, S. Arik, and T. Pfister Mle-star: machine learning engineering agent via search and targeted refinement. Advances in Neural Information Processing Systems 38, pp. 116692–116712. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 1](https://arxiv.org/html/2602.02660#S2.T1.3.1.1.1.1.1.1.3.1 "In Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Ouyang et al. (2026) S. Ouyang, J. Yan, I. Hsu, Y. Chen, K. Jiang, Z. Wang, R. Han, L. Le, S. Daruki, X. Tang, V. Tirumalashetty, G. Lee, M. Rofouei, H. Lin, J. Han, C. Lee, and T. Pfister ReasoningBank: scaling agent self-evolving with reasoning memory. In The Fourteenth International Conference on Learning Representations, Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p2.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p3.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Packer et al. (2023) C. Packer, S. Wooders, K. Lin, V. Fang, S. G. Patil, I. Stoica, and J. E. Gonzalez MemGPT: towards llms as operating systems. arXiv preprint arXiv:2310.08560. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p2.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Pu et al. (2025) Y. Pu, T. Lin, and H. Chen PiFlow: principle-aware scientific discovery with multi-agent collaboration. arXiv preprint arXiv:2505.15047. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Schmidgall et al. (2025) S. Schmidgall, Y. Su, Z. Wang, X. Sun, J. Wu, X. Yu, J. Liu, M. Moor, Z. Liu, and E. Barsoum Agent laboratory: using LLM agents as research assistants. Findings of the Association for Computational Linguistics: EMNLP 2025, pp. 5977–6043. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Shinn et al. (2023) N. Shinn, F. Cassano, A. Gopinath, K. Narasimhan, and S. Yao Reflexion: language agents with verbal reinforcement learning. Advances in Neural Information Processing Systems 36, pp. 8634–8652. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p2.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p3.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Starace et al. (2025) G. Starace, O. Jaffe, D. Sherburn, J. Aung, J. S. Chan, L. Maksin, R. Dias, E. Mays, B. Kinsella, W. Thompson, J. Heidecke, A. Glaese, and T. Patwardhan PaperBench: evaluating AI’s ability to replicate AI research. In Forty-second International Conference on Machine Learning, Cited by: [Appendix A](https://arxiv.org/html/2602.02660#A1.p2.1 "Appendix A Limitations ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Tan et al. (2019) M. Tan, B. Chen, R. Pang, V. Vasudevan, M. Sandler, A. Howard, and Q. V. Le Mnasnet: platform-aware neural architecture search for mobile. In Proceedings of the IEEE/CVF conference on computer vision and pattern recognition, pp. 2820–2828. Cited by: [§4.4.3](https://arxiv.org/html/2602.02660#S4.SS4.SSS3.p5.1 "4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§5.1](https://arxiv.org/html/2602.02660#S5.SS1.p5.1 "5.1 Setup ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Tan et al. (2025) Z. Tan, J. Yan, I. Hsu, R. Han, Z. Wang, L. Le, Y. Song, Y. Chen, H. Palangi, G. Lee, et al. In prospect and retrospect: reflective memory management for long-term personalized dialogue agents. In Proceedings of the 63rd Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers), pp. 8416–8439. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p3.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Tang et al. (2026) J. Tang, L. Xia, Z. Li, and C. Huang Ai-researcher: autonomous scientific innovation. Advances in Neural Information Processing Systems 38, pp. 9481–9520. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Team et al. (2025) N. Team, B. Zhang, S. Feng, X. Yan, J. Yuan, Z. Yu, X. He, S. Huang, S. Hou, Z. Nie, et al. NovelSeek: when agent becomes the scientist–building closed-loop system from hypothesis to verification. arXiv preprint arXiv:2505.16938. Cited by: [Table 6](https://arxiv.org/html/2602.02660#A5.T6.3.1.1.1.1.1.4.1.1.1 "In Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 7](https://arxiv.org/html/2602.02660#A6.T7.7.1.1.1.1.1.5.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 8](https://arxiv.org/html/2602.02660#A6.T8.7.1.1.1.1.1.5.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 9](https://arxiv.org/html/2602.02660#A6.T9.7.1.1.1.1.1.5.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p2.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 2](https://arxiv.org/html/2602.02660#S4.T2.7.1.1.1.1.1.5.1.1 "In 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Tian et al. (2024) M. Tian, L. Gao, S. Zhang, X. Chen, C. Fan, X. Guo, R. Haas, P. Ji, K. Krongchon, Y. Li, et al. Scicode: a research coding benchmark curated by scientists. Advances in Neural Information Processing Systems 37, pp. 30624–30650. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Toledo et al. (2026) E. Toledo, K. Hambardzumyan, M. Josifoski, R. Hazra, N. Baldwin, A. Audran-Reiss, M. Kuchnik, D. Magka, M. Jiang, A. Lupidi, et al. Ai research agents for machine learning: search, exploration, and generalization in mle-bench. Advances in Neural Information Processing Systems 38, pp. 35309–35348. Cited by: [Table 6](https://arxiv.org/html/2602.02660#A5.T6.3.1.1.1.1.1.8.1.1.1 "In Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 7](https://arxiv.org/html/2602.02660#A6.T7.7.1.1.1.1.1.12.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 8](https://arxiv.org/html/2602.02660#A6.T8.7.1.1.1.1.1.12.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 9](https://arxiv.org/html/2602.02660#A6.T9.7.1.1.1.1.1.12.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§1](https://arxiv.org/html/2602.02660#S1.p2.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 1](https://arxiv.org/html/2602.02660#S2.T1.3.1.1.1.1.1.1.4.1 "In Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 2](https://arxiv.org/html/2602.02660#S4.T2.7.1.1.1.1.1.12.1.1 "In 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§5.1](https://arxiv.org/html/2602.02660#S5.SS1.p3.1 "5.1 Setup ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Wang et al. (2025) X. Wang, B. Li, Y. Song, F. F. Xu, X. Tang, M. Zhuge, J. Pan, Y. Song, B. Li, J. Singh, et al. Openhands: an open platform for ai software developers as generalist agents. In International Conference on Learning Representations, Vol. 2025, pp. 65882–65919. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Weng et al. (2025) Y. Weng, M. Zhu, Q. Xie, Q. Sun, Z. Lin, S. Liu, and Y. Zhang DeepScientist: advancing frontier-pushing scientific findings progressively. arXiv preprint arXiv:2509.26603. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Wijk et al. (2025) H. Wijk, T. R. Lin, J. Becker, S. Jawhar, N. Parikh, T. Broadley, L. Chan, M. Chen, J. M. Clymer, J. Dhyani, E. Ericheva, K. Garcia, B. Goodrich, N. Jurkovic, M. Kinniment, A. Lajko, S. Nix, L. J. K. Sato, W. Saunders, M. Taran, B. West, and E. Barnes RE-bench: evaluating frontier AI r&d capabilities of language model agents against human experts. In Forty-second International Conference on Machine Learning, Cited by: [Appendix A](https://arxiv.org/html/2602.02660#A1.p2.1 "Appendix A Limitations ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Xu et al. (2026) W. Xu, Z. Liang, K. Mei, H. Gao, J. Tan, and Y. Zhang A-mem: agentic memory for llm agents. Advances in Neural Information Processing Systems 38, pp. 17577–17604. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p2.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p3.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Yamada et al. (2025) Y. Yamada, R. T. Lange, C. Lu, S. Hu, C. Lu, J. Foerster, J. Clune, and D. Ha The ai scientist-v2: workshop-level automated scientific discovery via agentic tree search. arXiv preprint arXiv:2504.08066. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Yang et al. (2024) J. Yang, C. E. Jimenez, A. Wettig, K. Lieret, S. Yao, K. Narasimhan, and O. Press SWE-agent: agent-computer interfaces enable automated software engineering. Advances in Neural Information Processing Systems 37, pp. 50528–50652. Cited by: [§1](https://arxiv.org/html/2602.02660#S1.p1.1 "1 Introduction ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Yang et al. (2025) X. Yang, X. Yang, S. Fang, Y. Zhang, J. Wang, B. Xian, Q. Li, J. Li, M. Xu, Y. Li, et al. R&D-agent: an llm-agent framework towards autonomous data science. arXiv preprint arXiv:2505.14738. Cited by: [Table 6](https://arxiv.org/html/2602.02660#A5.T6.3.1.1.1.1.1.3.1.1.1 "In Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 7](https://arxiv.org/html/2602.02660#A6.T7.7.1.1.1.1.1.4.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 8](https://arxiv.org/html/2602.02660#A6.T8.7.1.1.1.1.1.4.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 9](https://arxiv.org/html/2602.02660#A6.T9.7.1.1.1.1.1.4.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 1](https://arxiv.org/html/2602.02660#S2.T1.3.1.1.1.1.1.1.5.1 "In Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 2](https://arxiv.org/html/2602.02660#S4.T2.7.1.1.1.1.1.4.1.1 "In 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Zhao et al. (2024) A. Zhao, D. Huang, Q. Xu, M. Lin, Y. Liu, and G. Huang Expel: llm agents are experiential learners. In Proceedings of the AAAI Conference on Artificial Intelligence, Vol. 38, pp. 19632–19642. Cited by: [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p3.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").
-   Zhu et al. (2026) X. Zhu, Y. Cai, Z. Liu, B. Zheng, C. Wang, R. Ye, J. Chen, H. Wang, W. Wang, Y. Zhang, et al. Toward ultra-long-horizon agentic science: cognitive accumulation for machine learning engineering. arXiv preprint arXiv:2601.10402. Cited by: [Table 6](https://arxiv.org/html/2602.02660#A5.T6.3.1.1.1.1.1.7.1.1.1 "In Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 7](https://arxiv.org/html/2602.02660#A6.T7.7.1.1.1.1.1.8.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 8](https://arxiv.org/html/2602.02660#A6.T8.7.1.1.1.1.1.8.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 9](https://arxiv.org/html/2602.02660#A6.T9.7.1.1.1.1.1.8.1.1 "In F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p1.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [§2](https://arxiv.org/html/2602.02660#S2.SS0.SSS0.Px1.p3.1 "Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 1](https://arxiv.org/html/2602.02660#S2.T1.3.1.1.1.1.1.1.6.1 "In Automated AI Research & MLE Bottleneck. ‣ 2 Related Work ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [Table 2](https://arxiv.org/html/2602.02660#S4.T2.7.1.1.1.1.1.8.1.1 "In 4.4.3 Efficiency-Guided Reward Function ‣ 4.4 Budget-Aware MCTS ‣ 4 Method ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").

Appendix

This Appendix is organized as follows: Appendix [A](https://arxiv.org/html/2602.02660#A1 "Appendix A Limitations ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") discusses the limitations of our work. We then provide background on the MLE task scenario and the standard MCTS algorithm in Appendices [B](https://arxiv.org/html/2602.02660#A2 "Appendix B MLE Task Scenario ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") and [C](https://arxiv.org/html/2602.02660#A3 "Appendix C Monte Carlo Tree Search (MCTS) ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), respectively. Next, Appendix [D](https://arxiv.org/html/2602.02660#A4 "Appendix D MARS for MLE Tasks ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") details the instantiation of MARS for MLE tasks, and Appendix [E](https://arxiv.org/html/2602.02660#A5 "Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") contrasts our evaluation setup with those of prior agents. Finally, we present additional experimental results (Appendix [F](https://arxiv.org/html/2602.02660#A6 "Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research")), qualitative examples of causally correct distilled lessons (Appendix [G](https://arxiv.org/html/2602.02660#A7 "Appendix G Qualitative Examples of Causally Correct Distilled Lessons ‣ MARS: Modular Agent with Reflective Search for Automated AI Research")), comprehensive agent prompts (Appendix [H](https://arxiv.org/html/2602.02660#A8 "Appendix H Prompts ‣ MARS: Modular Agent with Reflective Search for Automated AI Research")), and representative code examples generated by our system (Appendix [I](https://arxiv.org/html/2602.02660#A9 "Appendix I Example Solution Code ‣ MARS: Modular Agent with Reflective Search for Automated AI Research")).

## Appendix A Limitations

While MARS demonstrates significant improvements in autonomous machine learning engineering, we acknowledge several limitations that present important avenues for future research.

Scope of Evaluation. Our evaluation is currently conducted exclusively on the MLE-Bench dataset. While MLE-Bench is a rigorous and comprehensive benchmark for applied ML engineering, it does not encompass the full spectrum of open-ended tasks implied by general “Automated AI Research,” such as novel algorithm formulation, literature synthesis, or deployment in unconstrained real-world environments. Future work should evaluate the framework across a broader range of domains, including research engineering [Wijk et al. (2025)](https://arxiv.org/html/2602.02660#bib.bib13) and automated research replication [Starace et al. (2025)](https://arxiv.org/html/2602.02660#bib.bib22), to fully substantiate its broader applicability.

Computational Cost. The current pipeline incurs a notable computational expense. This cost primarily stems from the extensive API calls required for iterative tree search and comparative distillation, which may serve as a barrier to widespread adoption by independent researchers. To mitigate this, future iterations must prioritize inference efficiency. Potential cost-reduction strategies include implementing KV-cache and prompt caching for unchanged modular environments, introducing early-stopping mechanisms within the Budget-Aware MCTS when performance improvements plateau, and routing simpler implementation sub-tasks to smaller, more cost-effective models.

Reliability of Distilled Lessons. Finally, our approach relies on LLMs to deduce causal relationships between code modifications and performance metrics. Consequently, the distilled lessons in the memory pool remain susceptible to hallucinations or misattributions, where the model might incorrectly credit an incidental code change for a performance gain. Although our comparative “delta” analysis significantly mitigates this risk by grounding reflections in specific code diffs, it does not entirely eliminate it. Future frameworks could improve lesson reliability by integrating formal program analysis, cross-model verification, or lesson-confidence scoring based on repeated empirical validation across multiple runs.

## Appendix B MLE Task Scenario

Machine Learning Engineering (MLE) is a representative and challenging instantiation of this general problem class. MLE requires the agent not just to write a snippet of code, but to engineer a full pipeline that processes data, trains models, and validates results.

We map the general problem 𝒫\=(ℐ,ℰ,𝒪) to an MLE task Q\=(I,D,M), where:

-   •
    
    I corresponds to the natural language task description (ℐ).
    
-   •
    
    D represents the datasets (D\={Dd​e​v,Dt​e​s​t}) which form the data environment (ℰ).
    
-   •
    
    M is the evaluation metric (e.g., Accuracy, F1-score) defining the objective (𝒪). Without loss of generality, we treat the optimization of M as a maximization problem.
    

If a pre-defined validation set is not provided in the development set Dd​e​v, the agent must partition Dd​e​v to create a validation set Dv​a​l for internal evaluation, as the test set Dt​e​s​t is strictly hidden.

We aim to build an MLE agent 𝒜 that explores a space of possible solutions and outputs a final executable solution s. We define the solution s as a structured software repository comprising the distinct code modules, dependencies, and entry points required to orchestrate the end-to-end pipeline.

The performance of a solution s is quantified by the metric function f⁡(s,D,M)∈ℝ. While the ultimate goal is to maximize performance on the unseen test set Dt​e​s​t, the agent must rely on a proxy objective using the validation set Dv​a​l. The optimization objective becomes:

<table id="A2.EGx5" class="ltx_equationgroup ltx_eqn_align ltx_eqn_table"><tbody id="A2.E5"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_td ltx_align_right ltx_eqn_cell"><math id="A2.E5.m1" class="ltx_Math" alttext="\displaystyle s^{*}=\argmax_{s\in\mathcal{S}_{\mathcal{A}}}\quad f(s,D_{test},M),\quad s.t.\quad C(s)\leq T" display="inline" intent=":literal"><semantics><mrow><mrow><mrow><mrow><msup><mi>s</mi><mo>∗</mo></msup><mo>=</mo><msub><mrow><mi>arg</mi><mo lspace="0.170em" rspace="0em">​</mo><mi>max</mi></mrow><mrow><mi>s</mi><mo>∈</mo><msub><mi class="ltx_font_mathcaligraphic">𝒮</mi><mi class="ltx_font_mathcaligraphic">𝒜</mi></msub></mrow></msub></mrow><mspace style="width:1em;" width="1em"></mspace><mrow><mi>f</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><msub><mi>D</mi><mi>test</mi></msub><mo>,</mo><mi>M</mi><mo stretchy="false">)</mo></mrow></mrow><mo rspace="1.167em">,</mo><mi>s</mi></mrow><mo lspace="0em" rspace="0.167em">.</mo><mi>t</mi></mrow><mo lspace="0em">.</mo><mspace style="width:1.167em;" width="1.167em"></mspace><mrow><mrow><mi>C</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo stretchy="false">)</mo></mrow></mrow><mo>≤</mo><mi>T</mi></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(5)</span></td></tr></tbody></table>

where T is the wall-clock time budget, 𝒮𝒜 is the set of candidate solutions generated by agent 𝒜 given task Q, and C⁡(s) denotes the total wall-clock time consumed by the agent to search for the solution s. Since Dt​e​s​t is unobservable, the agent optimizes via f⁡(s,Dv​a​l,M).

## Appendix C Monte Carlo Tree Search (MCTS)

Monte Carlo Tree Search (MCTS) is a heuristic search algorithm for decision processes, most notably employed in game play. The algorithm builds a search tree where each node v represents a state s, and each edge represents an action a leading to a new state. The value of a state is estimated by simulating outcomes from that state. As shown in Algorithm [1](https://arxiv.org/html/2602.02660#alg1 "Algorithm 1 ‣ Appendix C Monte Carlo Tree Search (MCTS) ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), each MCTS iteration consists of four distinct phases:

1.  1.
    
    Selection: Starting from the root node v0, the algorithm recursively traverses down the tree by selecting child nodes according to a selection policy, typically aiming to balance exploration and exploitation. a common strategy is the Upper Confidence Bound for Trees (UCT) [Kocsis and Szepesvári (2006)](https://arxiv.org/html/2602.02660#bib.bib16):
    
    <table id="A3.EGx6" class="ltx_equationgroup ltx_eqn_align ltx_eqn_table"><tbody id="A3.E6"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_td ltx_align_right ltx_eqn_cell"><math id="A3.E6.m1" class="ltx_Math" alttext="\displaystyle a^{*}=\argmax_{a\in\mathcal{A}(s)}\left(Q(s,a)+c_{uct}\sqrt{\frac{\ln N(s)}{N(s,a)}}\right)" display="inline" intent=":literal"><semantics><mrow><msup><mi>a</mi><mo>∗</mo></msup><mo>=</mo><mrow><msub><mrow><mi>arg</mi><mo lspace="0.170em" rspace="0em">​</mo><mi>max</mi></mrow><mrow><mi>a</mi><mo>∈</mo><mrow><mi class="ltx_font_mathcaligraphic">𝒜</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo stretchy="false">)</mo></mrow></mrow></mrow></msub><mo>⁡</mo><mrow><mo>(</mo><mrow><mrow><mi>Q</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><mi>a</mi><mo stretchy="false">)</mo></mrow></mrow><mo>+</mo><mrow><msub><mi>c</mi><mi>uct</mi></msub><mo lspace="0em" rspace="0em">​</mo><msqrt><mstyle displaystyle="true"><mfrac><mrow><mi>ln</mi><mo lspace="0.167em">⁡</mo><mrow><mi>N</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo stretchy="false">)</mo></mrow></mrow></mrow><mrow><mi>N</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><mi>a</mi><mo stretchy="false">)</mo></mrow></mrow></mfrac></mstyle></msqrt></mrow></mrow><mo>)</mo></mrow></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(6)</span></td></tr></tbody></table>
    
    where Q⁡(s,a) is the estimated value of taking action a in state s, N⁡(s) is the total visit count of state s, N⁡(s,a) is the number of times action a has been selected from s, and cu​c​t is a constant controlling the exploration weight.
    
2.  2.
    
    Expansion: Once a leaf node vl is reached (or a node with unexplored actions), one or more child nodes are added to the tree, representing reachable states from standard actions.
    
3.  3.
    
    Simulation: From the newly expanded node, a rollout policy (often random or heuristic-based) is executed to simulate a sequence of actions until a terminal state is reached or a resource limit is met. This produces a reward R.
    
4.  4.
    
    Backpropagation: The reward R obtained from the simulation is propagated back up the tree from the leaf to the root. For each node (s,a) traversed during the selection phase, we update the visit count and value estimate as follows:
    
    <table id="A3.EGx7" class="ltx_equationgroup ltx_eqn_align ltx_eqn_table"><tbody id="A3.E7"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_td ltx_align_right ltx_eqn_cell"><math id="A3.E7.m1" class="ltx_Math" alttext="\displaystyle N(s,a)" display="inline" intent=":literal"><semantics><mrow><mi>N</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><mi>a</mi><mo stretchy="false">)</mo></mrow></mrow></semantics></math></td><td class="ltx_td ltx_align_left ltx_eqn_cell"><math id="A3.E7.m2" class="ltx_Math" alttext="\displaystyle\leftarrow N(s,a)+1" display="inline" intent=":literal"><semantics><mrow><mphantom></mphantom><mo stretchy="false">←</mo><mrow><mrow><mi>N</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><mi>a</mi><mo stretchy="false">)</mo></mrow></mrow><mo>+</mo><mn>1</mn></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(7)</span></td></tr></tbody><tbody id="A3.E8"><tr class="ltx_equation ltx_eqn_row ltx_align_baseline"><td class="ltx_eqn_cell ltx_eqn_center_padleft"></td><td class="ltx_td ltx_align_right ltx_eqn_cell"><math id="A3.E8.m1" class="ltx_Math" alttext="\displaystyle Q(s,a)" display="inline" intent=":literal"><semantics><mrow><mi>Q</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><mi>a</mi><mo stretchy="false">)</mo></mrow></mrow></semantics></math></td><td class="ltx_td ltx_align_left ltx_eqn_cell"><math id="A3.E8.m2" class="ltx_Math" alttext="\displaystyle\leftarrow Q(s,a)+\frac{R-Q(s,a)}{N(s,a)}" display="inline" intent=":literal"><semantics><mrow><mphantom></mphantom><mo stretchy="false">←</mo><mrow><mrow><mi>Q</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><mi>a</mi><mo stretchy="false">)</mo></mrow></mrow><mo>+</mo><mstyle displaystyle="true"><mfrac><mrow><mi>R</mi><mo>−</mo><mrow><mi>Q</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><mi>a</mi><mo stretchy="false">)</mo></mrow></mrow></mrow><mrow><mi>N</mi><mo>⁡</mo><mrow><mo stretchy="false">(</mo><mi>s</mi><mo>,</mo><mi>a</mi><mo stretchy="false">)</mo></mrow></mrow></mfrac></mstyle></mrow></mrow></semantics></math></td><td class="ltx_eqn_cell ltx_eqn_center_padright"></td><td rowspan="1" class="ltx_eqn_cell ltx_eqn_eqno ltx_align_middle ltx_align_right"><span class="ltx_tag ltx_tag_equation ltx_align_right">(8)</span></td></tr></tbody></table>
    

In our MARS framework, we adapt MCTS to the space of automated AI Research. A state s corresponds to a partial or complete solution sn, and actions correspond to modification operators (Drafting, Improvement, Debugging). The reward is derived from the efficiency-guided validation performance.

Algorithm 1 Monte Carlo Tree Search (MCTS)

1:  Input: Task 𝒫, Time Budget T.

2:  Output: Best Solution Node v∗

3:  Initialize root node v0 with empty solution

4:  v∗←v0

5:  while Time used <T do

6:   vl←SELECT​(v0) {Tree Traversal using UCT}

7:   vn​e​w←EXPAND​(vl) {Apply Drafting/Improvement/Debugging}

8:   R←SIMULATE​(vn​e​w) {Execute and Evaluate Solution}

9:   BACKPROPAGATE​(vn​e​w,R) {Update Q and N values}

10:   if V​a​l​M​e​t​r​i​c​(vn​e​w)\>V​a​l​M​e​t​r​i​c​(v∗) then

11:    v∗←vn​e​w

12:   end if

13:  end while

14:  return v∗

## Appendix D MARS for MLE Tasks

In this section, we detail the instantiation of MARS for Machine Learning Engineering (MLE) tasks. The comprehensive procedure is formalized in Algorithm [2](https://arxiv.org/html/2602.02660#alg2 "Algorithm 2 ‣ Debugging Phase. ‣ Appendix D MARS for MLE Tasks ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"). Corresponding instruction prompts for the agents involved are provided in Appendix [H](https://arxiv.org/html/2602.02660#A8 "Appendix H Prompts ‣ MARS: Modular Agent with Reflective Search for Automated AI Research").

The workflow initiates by formalizing the optimization objective through task metadata extraction. A Metric Extraction Agent parses the natural language task description ℐ to identify the primary evaluation metric M and the optimization direction d∈{maximize,minimize}.

Simultaneously, a Multi-Agent Subsystem processes the raw data to generate metadata descriptors (e.g., sample IDs) for the training (Dt​r​a​i​n), validation (Dv​a​l), and test (Dt​e​s​t) sets. These metadata descriptors are saved to files for later usage.

To ensure robust evaluation, we employ a strict protocol:

-   •
    
    Validation Dataset Creation: If a pre-defined validation set is not provided, the agent performs a stratified or group-based split (defaulting to a 80:20 ratio) on Dd​e​v to create Dt​r​a​i​n and Dv​a​l. This ensures that Dv​a​l maintains a distribution P⁡(Dv​a​l)≈P⁡(Dt​r​a​i​n), enabling reliable proxy evaluation.
    
-   •
    
    Verification & Documentation: Distinct agents perform key integrity checks (e.g., no leakage between splits) and generate comprehensive documentation describing the data schema and split logic.
    

Following preparation, a Data Analysis Agent performs Exploratory Data Analysis (EDA) on Dt​r​a​i​n. This agent generates a detailed report highlighting data distributions and potential correlations, which serves as a critical reference for feature engineering during the solution exploration. Furthermore, a Search Agent identifies Ka candidate model architectures across diverse algorithmic families (e.g., gradient-boosted trees, deep neural networks) using web search tools.

Once initialized, MARS enters an iterative Tree Search Stage. In each iteration, a node v is selected via the Upper Confidence Bound for Trees (UCT) formula. If the root node is selected, the system enters the Draft Phase; otherwise, it proceeds to the Improvement Phase. Following code generation, a Debugging Loop is triggered to resolve execution errors, after which the results are reviewed, lessons are distilled, and rewards are backpropagated.

##### Drafting Phase.

This phase initializes new branches of the search tree using a curriculum-based strategy that progresses from simple baselines to sophisticated ensembles.

-   •
    
    Initial Seed: When the solution lesson pool ℒs​o​l​u​t​i​o​n is empty, an Initial Idea Generation Agent proposes a solution based on the most lightweight model from the Ka candidates.
    
-   •
    
    Evolutionary Growth: As lessons accumulate, an Idea Improvement Agent formulates advanced proposals by integrating insights from ℒs​o​l​u​t​i​o​n.
    
-   •
    
    Modular Implementation: A Modular Agent decomposes the proposed idea into independent functional units, which are implemented and unit-tested by a Coding Agent before being orchestrated into a final execution script πmain.
    

##### Improvement Phase.

This phase focuses on local optimization. An agent analyzes the current solution and its performance metrics to propose targeted, ablation-style modifications. By leveraging the learned lessons in ℒs​o​l​u​t​i​o​n, the agent avoids previously identified pitfalls and focuses on high-impact refinements (e.g., hyperparameter tuning or feature engineering).

##### Debugging Phase.

If a candidate node vn​e​w fails execution, the system enters a debugging loop (up to Kd​e​b​u​g attempts). We maintain a dedicated debugging lesson pool ℒd​e​b​u​g to store error-correction patterns. This prevents the agent from repeating previous mistakes in subsequent iterations.

Algorithm 2 MARS for MLE Tasks

1:  Input: Task Description I, Raw Dataset D, Time Limit T

2:  Output: Optimized solution code repository s∗

3:  d←MetricParsing​(I) {Extract optimization objective and direction}

4:  𝒞m​e​t​a←Preprocess​(D) {Generate metadata and stratified splits}

5:  𝒞e​d​a←Analyze​(I,D,𝒞m​e​t​a) {Perform EDA and statistical profiling}

6:  𝒞m​o​d​e​l←SearchArchitectures​(I) {Retrieve SOTA model candidates via search}

7:  𝒞\={𝒞m​e​t​a,𝒞e​d​a,𝒞m​o​d​e​l}

8:  vr​o​o​t←InitializeTree​()

9:  v∗←None

10:  ℒs​o​l​u​t​i​o​n←∅ {Solution Lesson Pool}

11:  ℒd​e​b​u​g←∅ {Debug Lesson Pool}

12:  𝒴←∅ {Explored Ideas}

13:  while Time used<T do

14:   v←SelectNode​(vr​o​o​t) {Using UCT selection}

15:   if v is vr​o​o​t then

16:    Y←ProposeIdea​(I,𝒴,𝒞,ℒs​o​l​u​t​i​o​n) {Curriculum-based idea generation}

17:    Z←ProposeModules​(I,Y) {Decompose idea into functional modules}

18:    {ℳj}j\=1l←ImplementModules​(I,Y,Z) {Implement modular components}

19:    {ℳj}j\=1l←DebugModules​(I,{ℳj}j\=1l) {Unit-test modules}

20:    πmain←ImplementMainScript​(I,Y,{ℳj}j\=1l) {Orchestrate pipeline}

21:    vn​e​w←DraftNode​({ℳj}j\=1l,πmain)

22:    𝒴←𝒴∪{Y}

23:   else

24:    vn​e​w←ImproveNode​(v,ℒs​o​l​u​t​i​o​n) {Ablation-style local optimization}

25:   end if

26:   k←0

27:   while IsBuggy​(vn​e​w) and k<Nd do

28:    vn​e​w←DebugNode​(vn​e​w,ℒd​e​b​u​g) {Apply ℒd​e​b​u​g for debugging and then update ℒd​e​b​u​g}

29:    k←k+1

30:   end while

31:   re←ExecuteAndReview​(vn​e​w) {Execute code and review execution results}

32:   ExtractLesson​(vn​e​w,re,ℒs​o​l​u​t​i​o​n) {Distill lessons from results}

33:   Backpropagate​(vn​e​w,re) {Update tree statistics with rewards}

34:   if v∗​is None or IsImprovedMetric​(re,v∗,d) then

35:    v∗←vn​e​w

36:   end if

37:  end while

38:  s∗←GetRepoCode​(v∗)

39:  return s∗

## Appendix E Setup for Leaderboard Methods vs. Our Setup

Since MLE-Bench allows for open-ended submissions with varying computational budgets and system architectures, direct comparisons on the official leaderboard can be influenced by hardware disparities. To ensure a fair assessment, we detail the specific hardware, time limits, and auxiliary resources used by top-performing leaderboard agents alongside our own in Table [6](https://arxiv.org/html/2602.02660#A5.T6 "Table 6 ‣ Appendix E Setup for Leaderboard Methods vs. Our Setup ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"). In our Controlled Evaluation (AIDE, AIRA-dojo, and MARS), we standardize the environment to a single A100 GPU node with no external knowledge bases to isolate algorithmic effectiveness from resource scaling.

Agent Model Compute Parallelization Knowledge Base ML-Master ([Liu et al., 2025b](https://arxiv.org/html/2602.02660#bib.bib9)) Deepseek-R1 36 vCPUs, 512GB of RAM, and 1 A100 80GB GPU, 12-hour limit 3-way parallel search None R&D-Agent ([Yang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib11)) GPT-5 12 vCPUs, 220GB of RAM, and 1 V100 GPU, 12-hour limit Parallel exploration None InternAgent ([Team et al., 2025](https://arxiv.org/html/2602.02660#bib.bib17)) Deepseek-R1 32 vCPUs, 230 GB RAM, 1 A800 GPU, 12-hour limit Unknown Unknown Famou-Agent ([Li et al., 2025](https://arxiv.org/html/2602.02660#bib.bib18)) Gemini-2.5-Pro 64 vCPUs, 500GB RAM, 1 A800 GPU, 24-hour limit Concurrent evaluation across distributed computing resource An expert knowledge base Leeroo ([Nadaf et al., 2025](https://arxiv.org/html/2602.02660#bib.bib20)) Gemini-3-Pro-Preview 150GB RAM, 24 vCPUs, 1 H100 GPU. Run for 24 hours or until a maximum budget of $200 is reached. Stop early if the run achieves any medal according to the MLE-Bench grading library. Executing multiple ExperimentSessions concurrently A knowledge plane aggregates heterogeneous sources ML-Master 2.0 ([Zhu et al., 2026](https://arxiv.org/html/2602.02660#bib.bib19)) Deepseek-V3.2-Speciale 36 vCPUs, 252GB of RAM, and two 4090-24GB GPU, 24-hour limit Parallel exploration Use 407 kaggle competitions as a warm up dataset to build up a prior wisdom AIDE ([Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3)), AIRA-dojo ([Toledo et al., 2026](https://arxiv.org/html/2602.02660#bib.bib12)) or MARS Gemini-2.5-Pro or Gemini-3-Pro-Preview 1 A100 GPU 40GB, 12 vCPUs, 220 GB of RAM, 24-hour limit Non-parallel execution None MARS+ Gemini-3-Pro-Preview 2 H100 GPUs, 48 vCPUs, 220 GB of RAM, 24-hour limit 2-way parallel search None

Table 6: Comparison of leaderboard agents’ setup and our agent’s setup.

## Appendix F Additional Results

### F.1 Evaluation across Different Splits of MLE-Bench

This section presents a comprehensive evaluation across the various subsets of MLE-Bench. Detailed performance metrics for the Lite, Medium, and High splits are provided in Tables [7](https://arxiv.org/html/2602.02660#A6.T7 "Table 7 ‣ F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), [8](https://arxiv.org/html/2602.02660#A6.T8 "Table 8 ‣ F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), and [9](https://arxiv.org/html/2602.02660#A6.T9 "Table 9 ‣ F.1 Evaluation across Different Splits of MLE-Bench ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), respectively.

Table 7: Performance comparison on MLE-Bench Lite. Results are reported as mean ± SEM across three independent runs. All values are in percentages (%). The best performance is highlighted in bold, and the second-best is underlined.

Agent Model Valid Submission Above Median Bronze Silver Gold Any Medal Official MLE-Bench Leaderboard Results ML-Master ([Liu et al., 2025b](https://arxiv.org/html/2602.02660#bib.bib9)) Deepseek-R1 100.0±0.0 74.2±1.5 4.5±2.6 13.6±0.0 30.3±3.0 48.5±1.5 R&D-Agent ([Yang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib11)) GPT-5 77.3±0.0 74.2±1.5 12.1±4.0 22.7±0.0 33.3±3.0 68.2±2.6 InternAgent ([Team et al., 2025](https://arxiv.org/html/2602.02660#bib.bib17)) Deepseek-R1 100.0±0.0 78.8±5.5 10.6±1.5 16.7±3.0 34.8±1.5 62.1±3.0 Famou-Agent ([Li et al., 2025](https://arxiv.org/html/2602.02660#bib.bib18)) Gemini-2.5-Pro 100.0±0.0 72.7±2.6 7.6±3.0 16.7±1.5 37.9±1.5 62.1±1.5 Leeroo ([Nadaf et al., 2025](https://arxiv.org/html/2602.02660#bib.bib20)) Gemini-3-Pro-Preview 68.2±2.6 68.2±2.6 18.2±2.6 19.7±4.0 30.3±1.5 68.2±2.6 ML-Master 2.0 ([Zhu et al., 2026](https://arxiv.org/html/2602.02660#bib.bib19)) Deepseek-V3.2-Speciale 100.0±0.0 84.8±1.5 13.6±2.6 31.8±5.2 30.3±3.0 75.8¯±1.5 Controlled Evaluation in Our Environment AIDE ([Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3)) Gemini-2.5-Pro 100.0±0.0 63.6±2.6 3.0±1.5 4.5±0.0 28.8±3.0 36.4±4.5 Gemini-3-Pro-Preview 98.5±1.5 81.8±2.6 3.0±1.5 15.2±3.0 34.8±1.5 53.0±6.1 AIRA-dojo ([Toledo et al., 2026](https://arxiv.org/html/2602.02660#bib.bib12)) Gemini-2.5-Pro 89.4±8.4 62.1±4.0 1.5±1.5 10.6±1.5 28.8±3.0 40.9±2.6 Gemini-3-Pro-Preview 100.0±0.0 78.8±4.0 4.5±2.6 9.1±2.6 42.4±1.5 56.1±1.5 MARS (ours) Gemini-2.5-Pro 100.0±0.0 77.3±2.6 12.1±1.5 19.7±3.0 36.4±0.0 68.2±2.6 Gemini-3-Pro-Preview 100.0±0.0 89.4¯±1.5 6.1±1.5 15.2±1.5 53.0±1.5 74.2±1.5 MARS+ (ours) Gemini-3-Pro-Preview 100.0±0.0 95.5±0.0 12.1±1.5 16.7±1.5 50.0¯±2.6 78.8±1.5

Table 8: Performance comparison on MLE-Bench Medium. Results are reported as mean ± SEM across three independent runs. All values are in percentages (%). The best performance is highlighted in bold, and the second-best is underlined.

Agent Model Valid Submission Above Median Bronze Silver Gold Any Medal Official MLE-Bench Leaderboard Results ML-Master ([Liu et al., 2025b](https://arxiv.org/html/2602.02660#bib.bib9)) Deepseek-R1 92.1±2.6 35.1±3.2 6.1±0.9 7.0±0.9 7.0±0.9 20.2±2.3 R&D-Agent ([Yang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib11)) GPT-5 47.4±0.0 26.3±1.5 6.1±0.9 8.8±1.8 6.1±0.9 21.1±1.5 InternAgent ([Team et al., 2025](https://arxiv.org/html/2602.02660#bib.bib17)) Deepseek-R1 97.4±0.0 40.4±1.8 7.9±2.6 9.6±2.3 8.8±0.9 26.3±2.6 Famou-Agent ([Li et al., 2025](https://arxiv.org/html/2602.02660#bib.bib18)) Gemini-2.5-Pro 95.6±1.8 45.6±3.2 12.3±0.9 14.0±2.3 10.5±1.5 36.8±1.5 Leeroo ([Nadaf et al., 2025](https://arxiv.org/html/2602.02660#bib.bib20)) Gemini-3-Pro-Preview 44.7±1.5 44.7±1.5 15.8±0.0 12.3±0.9 16.7±2.3 44.7±1.5 ML-Master 2.0 ([Zhu et al., 2026](https://arxiv.org/html/2602.02660#bib.bib19)) Deepseek-V3.2-Speciale 93.9±0.9 57.9±1.5 13.2±1.5 29.8±2.3 7.9±0.0 50.9±3.5 Controlled Evaluation in Our Environment AIDE ([Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3)) Gemini-2.5-Pro 81.6±0.0 36.0±2.3 9.6±2.3 6.1±1.8 2.6±0.0 18.4±2.6 Gemini-3-Pro-Preview 84.2±1.5 39.5±2.6 7.9±1.5 13.2±1.5 5.3±2.6 26.3±3.0 AIRA-dojo ([Toledo et al., 2026](https://arxiv.org/html/2602.02660#bib.bib12)) Gemini-2.5-Pro 80.7±0.9 31.6±3.0 4.4±0.9 3.5±2.3 8.8±0.9 16.7±3.5 Gemini-3-Pro-Preview 97.4±1.5 48.2±2.3 8.8±2.3 8.8±1.8 12.3±0.9 29.8±3.8 MARS (ours) Gemini-2.5-Pro 92.1±0.0 44.7±0.0 14.0±3.2 12.3±2.3 7.0±0.9 33.3±1.8 Gemini-3-Pro-Preview 97.4±0.0 61.4¯±3.2 14.9±0.9 20.2±2.3 17.5¯±0.9 52.6¯±3.0 MARS+ (ours) Gemini-3-Pro-Preview 100.0±0.0 68.4±1.5 15.8±4.0 21.9±0.9 22.8±2.3 60.5±1.5

Table 9: Performance comparison on MLE-Bench High. Results are reported as mean ± SEM across three independent runs. All values are in percentages (%). The best performance is highlighted in bold, and the second-best is underlined.

Agent Model Valid Submission Above Median Bronze Silver Gold Any Medal Official MLE-Bench Leaderboard Results ML-Master ([Liu et al., 2025b](https://arxiv.org/html/2602.02660#bib.bib9)) Deepseek-R1 86.7±0.0 26.7±0.0 0.0±0.0 0.0±0.0 24.4±2.2 24.4±2.2 R&D-Agent ([Yang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib11)) GPT-5 33.3±0.0 26.7±0.0 0.0±0.0 4.4±2.2 17.8±2.2 22.2±2.2 InternAgent ([Team et al., 2025](https://arxiv.org/html/2602.02660#bib.bib17)) Deepseek-R1 88.9±2.2 24.4±2.2 0.0±0.0 4.4±2.2 20.0±0.0 24.4±2.2 Famou-Agent ([Li et al., 2025](https://arxiv.org/html/2602.02660#bib.bib18)) Gemini-2.5-Pro 95.6±2.2 35.6±2.2 0.0±0.0 2.2±2.2 31.1±2.2 33.3±0.0 Leeroo ([Nadaf et al., 2025](https://arxiv.org/html/2602.02660#bib.bib20)) Gemini-3-Pro-Preview 40.0±0.0 40.0±0.0 4.4±2.2 15.6±5.9 20.0±7.7 40.0±0.0 ML-Master 2.0 ([Zhu et al., 2026](https://arxiv.org/html/2602.02660#bib.bib19)) Deepseek-V3.2-Speciale 93.3±3.8 44.4¯±2.2 2.2±2.2 6.7±0.0 33.3¯±0.0 42.2¯±2.2 Controlled Evaluation in Our Environment AIDE ([Jiang et al., 2025](https://arxiv.org/html/2602.02660#bib.bib3)) Gemini-2.5-Pro 68.9±2.2 15.6±2.2 0.0±0.0 2.2±2.2 13.3±0.0 15.6±2.2 Gemini-3-Pro-Preview 55.6±2.2 20.0±3.8 0.0±0.0 0.0±0.0 17.8±2.2 17.8±2.2 AIRA-dojo ([Toledo et al., 2026](https://arxiv.org/html/2602.02660#bib.bib12)) Gemini-2.5-Pro 82.2±4.4 22.2±2.2 0.0±0.0 8.9±4.4 11.1±4.4 20.0±0.0 Gemini-3-Pro-Preview 97.8±2.2 40.0±3.8 0.0±0.0 4.4±2.2 26.7±6.7 31.1±4.4 MARS (ours) Gemini-2.5-Pro 91.1±2.2 35.6±2.2 4.4±2.2 2.2±2.2 24.4±2.2 31.1±2.2 Gemini-3-Pro-Preview 100.0±0.0 42.2±2.2 0.0±0.0 4.4±2.2 33.3¯±3.8 37.8±2.2 MARS+ (ours) Gemini-3-Pro-Preview 100.0±0.0 57.8±2.2 4.4±2.2 2.2±2.2 37.8±2.2 44.4±2.2

### F.2 Generalization to Other Models

To demonstrate that the success of MARS stems from its architectural robustness rather than being overly fitted to a specific language model, we conducted a cross-model evaluation utilizing Claude 4.6 Sonnet. The results in Table [10](https://arxiv.org/html/2602.02660#A6.T10 "Table 10 ‣ F.2 Generalization to Other Models ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") confirm that MARS maintains a substantial performance advantage over the baseline across all difficulty splits, verifying its efficacy independent of the underlying reasoning engine.

Table 10: Model generalizability on MLE-Bench using Claude 4.6 Sonnet. Values represent Any Medal Rate (Mean ± SEM) over three independent runs, evaluated on a random sample (n\=10 per split) of Lite, Medium, and High tasks.

<table id="A6.T10.5" class="ltx_tabular ltx_centering ltx_align_middle"><tbody><tr id="A6.T10.5.1" class="ltx_tr"><td id="A6.T10.5.1.1" class="ltx_td ltx_align_left ltx_border_tt"><span id="A6.T10.5.1.1.1" class="ltx_text ltx_font_bold">Method</span></td><td id="A6.T10.5.1.2" class="ltx_td ltx_align_center ltx_border_tt"><span id="A6.T10.5.1.2.1" class="ltx_text ltx_font_bold">Lite</span></td><td id="A6.T10.5.1.3" class="ltx_td ltx_align_center ltx_border_tt"><span id="A6.T10.5.1.3.1" class="ltx_text ltx_font_bold">Medium</span></td><td id="A6.T10.5.1.4" class="ltx_td ltx_align_center ltx_border_tt"><span id="A6.T10.5.1.4.1" class="ltx_text ltx_font_bold">High</span></td><td id="A6.T10.5.1.5" class="ltx_td ltx_align_center ltx_border_tt"><span id="A6.T10.5.1.5.1" class="ltx_text ltx_font_bold">All</span></td></tr><tr id="A6.T10.5.2" class="ltx_tr"><td id="A6.T10.5.2.1" class="ltx_td ltx_align_left ltx_border_t">AIRA-dojo</td><td id="A6.T10.5.2.2" class="ltx_td ltx_align_center ltx_border_t">40.0 <math id="A6.T10.m5" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 5.8</td><td id="A6.T10.5.2.3" class="ltx_td ltx_align_center ltx_border_t">6.7 <math id="A6.T10.m6" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 3.3</td><td id="A6.T10.5.2.4" class="ltx_td ltx_align_center ltx_border_t">13.3 <math id="A6.T10.m7" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 3.3</td><td id="A6.T10.5.2.5" class="ltx_td ltx_align_center ltx_border_t">20.0 <math id="A6.T10.m8" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 1.9</td></tr><tr id="A6.T10.5.3" class="ltx_tr"><td id="A6.T10.5.3.1" class="ltx_td ltx_align_left ltx_border_bb">MARS (ours)</td><td id="A6.T10.5.3.2" class="ltx_td ltx_align_center ltx_border_bb"><span id="A6.T10.5.3.2.1" class="ltx_text ltx_font_bold">80.0</span> <math id="A6.T10.m9" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 0.0</td><td id="A6.T10.5.3.3" class="ltx_td ltx_align_center ltx_border_bb"><span id="A6.T10.5.3.3.1" class="ltx_text ltx_font_bold">43.3</span> <math id="A6.T10.m10" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 3.3</td><td id="A6.T10.5.3.4" class="ltx_td ltx_align_center ltx_border_bb"><span id="A6.T10.5.3.4.1" class="ltx_text ltx_font_bold">43.3</span> <math id="A6.T10.m11" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 3.3</td><td id="A6.T10.5.3.5" class="ltx_td ltx_align_center ltx_border_bb"><span id="A6.T10.5.3.5.1" class="ltx_text ltx_font_bold">55.6</span> <math id="A6.T10.m12" class="ltx_Math" alttext="\pm" display="inline" intent=":literal"><semantics><mo>±</mo></semantics></math> 1.1</td></tr></tbody></table>

### F.3 Ablation Study Results on MLE-Bench Medium and High Splits

(a) Effect of modular decomposition.

(b) Effect of memory mechanisms.

(c) Comparison of tree search strategies.

(d) Effect of the penalty weight w.

Figure 6: Ablation study results on a random sample of 10 tasks from the MLE-Bench Medium split.

(a) Effect of modular decomposition.

(b) Effect of memory mechanisms.

(c) Comparison of tree search strategies.

(d) Effect of the penalty weight w.

Figure 7: Ablation study results on a random sample of 10 tasks from the MLE-Bench High split.

Building upon the ablation study conducted on the MLE-Bench Lite split (Section [5.3](https://arxiv.org/html/2602.02660#S5.SS3 "5.3 Ablation Study ‣ 5 Experiment ‣ MARS: Modular Agent with Reflective Search for Automated AI Research")), we extend our evaluation to include a random sample of 10 tasks each from the Medium and High splits. As illustrated in Figures [6](https://arxiv.org/html/2602.02660#A6.F6 "Figure 6 ‣ F.3 Ablation Study Results on MLE-Bench Medium and High Splits ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research") and [7](https://arxiv.org/html/2602.02660#A6.F7 "Figure 7 ‣ F.3 Ablation Study Results on MLE-Bench Medium and High Splits ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), the performance advantages provided by our core modules remain highly consistent across these more challenging tasks. Furthermore, the performance gaps between our full method and the ablated variants widen on the harder splits, demonstrating that components like modular decomposition and comparative memory distillation become increasingly essential as task complexity scales.

### F.4 Cost-Performance Trade-off

Table 11: Cost and performance analysis of different agents using Gemini-2.5-Pro. Metrics are averaged across competitions.

Metric AIDE (24 Hour) AIRA-dojo (24 Hour) MARS (4 Hour) MARS (24 Hour) \# API Calls 293.5±18.9 867.0±77.0 122.1±6.0 594.8±35.4 \# Input Tokens (×105) 34.6±4.0 128.3±13.2 44.3±8.8 286.6±54.7 \# Output Tokens (×105) 6.3±0.5 23.0±2.1 1.2±0.1 6.0±0.4 Price ($) 10.6±0.9 39.0±3.7 9.6±2.2 60.5±13.8 Any Medal Rate (%) 23.1±0.4 24.4±1.2 28.4 ± 1.2 43.1±1.6

In this section, we analyze the computational costs associated with our framework compared to the baselines (Table [11](https://arxiv.org/html/2602.02660#A6.T11 "Table 11 ‣ F.4 Cost-Performance Trade-off ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research")). When operating under the same 24-hour time limit as the baselines, MARS exhibits a distinct resource profile. It achieves the lowest generation volume, producing fewer output tokens (6.0×105) than both baselines and making significantly fewer API calls than AIRA-dojo (594.8 vs. 867.0). However, its input consumption is substantial (286.6×105 tokens) – approximately 2.2 times that of AIRA-dojo. This increase is largely due to maintaining a comprehensive memory context filled with learned lessons and modular structures. Because the Gemini-2.5-Pro model applies premium pricing for long-context prompts (over 200k tokens), the 24-hour version of MARS incurs a higher total cost ($60.5) than AIRA-dojo ($39.0). Crucially, this investment yields substantial returns: the Any Medal Rate increases from 24.4% to 43.1%, justifying the higher expense through superior efficacy.

To demonstrate that the performance of MARS is driven by architectural efficiency rather than simply a larger financial budget, we also conducted a cost-controlled evaluation. As shown in Table [11](https://arxiv.org/html/2602.02660#A6.T11 "Table 11 ‣ F.4 Cost-Performance Trade-off ‣ Appendix F Additional Results ‣ MARS: Modular Agent with Reflective Search for Automated AI Research"), MARS running under a restricted 4-hour time limit achieves a higher Any Medal Rate (28.4%) while spending less ($9.6) than both 24-hour baselines (AIDE and AIRA-dojo). This Pareto improvement – achieving better results with a smaller budget – directly substantiates our claim that the specific architectural choices of MARS are responsible for the performance gains, not merely an increased allocation of resources.

## Appendix G Qualitative Examples of Causally Correct Distilled Lessons

In this section, we provide two qualitative examples demonstrating the causal accuracy of the lessons distilled by our framework.

##### Example 1: Tabular Playground Series (May 2022).

MARS diagnosed a 0.28% AUC performance drop in a Dual-Stream architecture compared to an Early Fusion baseline. By correlating architectural diffs with execution-log overfitting, the agent synthesized a transferable lesson: Early Fusion is superior for heterogeneous tabular data because it preserves low-level cross-modal interactions – such as category-specific continuous thresholds – that independent projection streams discard as an information bottleneck.

##### Example 2: Histopathologic Cancer Detection.

MARS diagnosed why a multi-model ensemble underperformed (0.976 AUC) against its own single-model component (0.982 AUC). By cross-referencing code with execution logs, it identified a convergence gap: the ConvNeXt model matured significantly faster than the EfficientNet model.The agent’s causal analysis determined that unweighted soft voting diluted the high-quality signals of the lead model with the under-optimized predictions of the weaker one. Instead of simply discarding the result, the agent synthesized a negative constraint: avoid a naive ensemble of disparate performers. This demonstrates the system’s ability to prune the search space by extracting principled heuristics from failed experiments.

## Appendix H Prompts

This section provides the full suite of instruction prompts utilized by MARS to orchestrate the various agents involved in solving MLE tasks.

## Appendix I Example Solution Code

In this section, we showcase the final solution generated for the iMet-2020-fgvc7 competition. This repository was produced by MARS utilizing Gemini-3-Pro-Preview and achieved the highest validation performance during the search process.

Experimental support, please [view the build logs](https://arxiv.org/html/2602.02660v3/__stdout.txt) for errors. Generated by [L A T E xml](https://math.nist.gov/~BMiller/LaTeXML/)  .

## Instructions for reporting errors

We are continuing to improve HTML versions of papers, and your feedback helps enhance accessibility and mobile support. To report errors in the HTML that will help us improve conversion and rendering, choose any of the methods listed below:

-   Click the "Report Issue" button, located in the page header.

**Tip:** You can select the relevant text first, to include it in your report.

Our team has already identified [the following issues](https://github.com/arXiv/html_feedback/issues). We appreciate your time reviewing and reporting rendering errors we may not have found yet. Your efforts will help us improve the HTML versions for all readers, because disability should not be a barrier to accessing research. Thank you for your continued support in championing open access for all.

Have a free development cycle? Help support accessibility at arXiv! Our collaborators at LaTeXML maintain a [list of packages that need conversion](https://github.com/brucemiller/LaTeXML/wiki/Porting-LaTeX-packages-for-LaTeXML), and welcome [developer contributions](https://github.com/brucemiller/LaTeXML/issues).

We gratefully acknowledge support from our **major funders**, [**member institutions**](https://info.arxiv.org/about/ourmembers.html), and all contributors.

[About](https://info.arxiv.org/about) · [Help](https://info.arxiv.org/help) · [Contact](https://info.arxiv.org/help/contact.html) · [Subscribe](https://info.arxiv.org/help/subscribe) · [Copyright](https://info.arxiv.org/help/license/index.html) · [Privacy](https://info.arxiv.org/help/policies/privacy_policy.html) · [Accessibility](https://info.arxiv.org/help/web_accessibility.html) · [Operational Status (opens in new tab)](https://status.arxiv.org/)

Major funding support from

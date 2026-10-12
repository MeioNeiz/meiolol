---
title: 'The AI Scientist-v2: agentic tree search, experiment manager, VLM figure review'
url: https://arxiv.org/pdf/2504.08066
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: docs (sections 1-5, appendix A, prompts in B skimmed)
relevance: high
grade: C/fair
description: Sakana AI's end-to-end research agent (April 2025); staged best-first tree search over experiment nodes, replicated seeds, LLM and VLM judges, single-pass paper writing
---
# The AI Scientist-v2: agentic tree search, experiment manager, VLM figure review

Why: how an "AI scientist" explores ideas, keeps its tree of experiments, and analyses
and writes up results; what it costs per run.

## Assessment

- Evidence: C. Tech report by the authors, not peer reviewed itself. Evaluation is three
  workshop submissions, one accepted (6.33 average), chosen by humans from several seeds
  per idea. No ablation of tree search vs linear, no success rate reported.
- Reasoning: fair. Clear about the workflow and hyperparameters, honest about the
  limits (workshop not conference, citation errors, 57% train/test overlap in its own
  accepted paper), but every design choice is asserted, not measured.
- Interests: Sakana AI's flagship; framing is promotional ("milestone").
- Weigh: trust the mechanics (stages, node types, replication, budgets) as a design
  catalogue. Discount any claim that tree search beats linear: not measured here. The
  author review finding data leakage the system missed is the useful warning.

## Findings

- [lab] v1 was linear (each change built on the previous run); v2 moves to tree search
  because linear search was short-sighted. `section 2-3.2.2` ^f1
  > We empirically observed that automated research conducted by The AI Scientist-v1 often resulted in short-sighted experimentation.
  > operated strictly linearly, where each code refinement directly built on the immediately preceding experiment.
- [lab] An experiment manager runs four fixed stages: prototype, hyperparameter tuning,
  research agenda, ablations, each seeded by the previous stage's best node. `3.2.1` ^f2
  > Stage 2 Hyperparameter Tuning: Refining the initial implementation by optimizing critical hyperparameters
  > Stage 4 Ablation Studies: Systematically assessing the importance of various research components
- [lab] Stages stop on explicit criteria; the last two run until their compute budget is
  spent. An LLM judge picks the best node to carry forward. `3.2.1` ^f3
  > Stages 3 and 4 conclude when the allocated computational budget is exhausted.
  > After each stage, the experiment manager selects the best-performing node using a dedicated LLM evaluator
- [lab] [stats] Selected best experiments are rerun several times at the end of each
  stage so reported results carry mean and standard deviation. `3.2.1` ^f4
  > the experiment manager launches multiple replications of the selected best experiments at the conclusion of each stage.
- [lab] Node selection: debug a buggy node with a set probability, else best-first among
  working nodes, with an LLM weighing metrics, training curves and plot quality; several
  nodes expand in parallel. `3.2.2` ^f5
  > With a predefined probability, a buggy node is chosen (thus prioritizing error resolution and debugging)
  > the system uses a best-first search strategy, guided by an LLM that evaluates candidates based on factors like performance metrics, training dynamics, and the quality of generated plots.
- [lab] Memory is the tree itself: each node keeps its script, plan, error trace,
  runtime, metrics, LLM feedback, plot script, figures, VLM feedback and status.
  `3.2.2` ^f6
  > a textual description of the high-level plan implemented in the script, an execution error trace (if applicable), experiment runtime, performance metrics recorded during the experiment, feedback from an LLM after running the script
- [lab] Hyperparameter and ablation nodes keep a record of conditions already tried, to
  avoid rerunning them. `3.2.2` ^f7
  > The system maintains careful records of previously tested hyperparameters, preventing redundant experiments.
- [lab] Analysis: every run saves metrics to structured files, a plotting step draws
  them, and a VLM reviews the figures; a flagged figure marks the node buggy. `3.2.2` ^f8
  > the system is instructed to save all relevant experimental outputs (training and validation metrics, losses, etc.) into structured numpy files.
  > Any issues flagged by the VLM (such as unclear labels, missing legends, or misleading visualizations) result in the node being marked as buggy
- [lab] Replication nodes rerun the parent with new seeds; aggregation nodes run no
  experiment, only a script that summarises replicates with means and standard
  deviations. `3.2.2` ^f9
  > Replication nodes execute replicates of their parent experiments using different random seeds.
  > aggregation nodes do not conduct new experiments but simply generate a Python script to aggregate and summarize prior results
- [lab] Write-up prompt forbids inventing numbers: plots must come from the saved data.
  `appendix B, plot aggregation prompt` ^f10
  > Make sure to use existing .npy data for analysis; do NOT hallucinate data.
- [lab] Idea generation queries Semantic Scholar to check novelty before committing to
  an idea. `3.1` ^f11
  > The system can query the literature database during the idea formulation process to assess the novelty of a proposed concept
- [lab] Budget: 21, 12, 12, 12 nodes per stage, 1 hour max per node, debug depth 3;
  a paper takes several hours up to a 15 hour cap. Models: Claude 3.5 Sonnet for code,
  GPT-4o for feedback. `appendix A` ^f12
  > this process usually takes anywhere from several hours to a maximum of 15 hours, which is the runtime limit we have set.
- [lab] Humans picked 3 of about 40 generated ideas, ran each with several seeds and
  submitted the best manuscript per idea: the headline result is best-of-n. `4.2` ^f13
  > From the multiple complete manuscripts generated for each initial idea (i.e., one manuscript per seed), we selected the single best-resulting manuscript for submission
- [lab] [method] The authors' own review of the accepted paper found about 57%
  train/test overlap and a figure contradicting the text's claims; the system did not
  catch either. `4.2` ^f14
  > Our examination of the code revealed potential issues with dataset overlap—approximately 57% overlap between training and test sets
  > Figure 5’s attention-based model clearly outperformed the LSTM model, contradicting the authors’ claims.
- [lab] Checked, not there: no dollar cost per paper and no comparison of tree search
  against v1's linear loop. ^f15

## Read

- Sections 1-5 and appendix A in full; appendix B prompts skimmed for analysis and
  write-up rules.

## Not read

- Appendix C (the three generated papers) beyond the reviews: matters only for judging
  output quality.
- The GitHub code (SakanaAI/AI-Scientist-v2): would give exact node selection code.

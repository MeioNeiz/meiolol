---
title: A Recipe for Training Neural Networks (Karpathy, 2019)
url: https://karpathy.github.io/2019/04/25/recipe/
kind: article
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (whole post)
relevance: high
grade: A/fair
description: Karpathy's widely cited blog recipe for training nets without silent bugs: inspect data, dumb baselines and sanity checks (loss at init, input-independent baseline, overfit one batch), then grow complexity one step at a time
---
# A Recipe for Training Neural Networks (Karpathy, 2019)

Why: which per-run sanity checks a careful practitioner insists on before trusting a
training run, so a lab harness can run them automatically for an agent.

## Assessment

- Evidence: A as the canonical practitioner reference (recognised expert, years of
  citation in courses and checklists); no measurements, first-hand experience only.
- Reasoning: fair. Explains why each check exists (silent failure), gives no data on
  how often each catches a bug.
- Interests: none known.
- Weigh: written for image nets; the checks that transfer to small tabular/draft nets
  are loss at init, input-independent baseline, overfit a tiny batch, per-example
  dependency check, one change at a time. Augmentation and visualising filters do not.

## Findings

- [lab] Nets fail silently: a misconfigured net usually still trains, just worse, so
  errors do not surface as exceptions. Section 2 of intro ^f1
  > Therefore, your misconfigured neural net will throw exceptions only if you’re lucky; Most of the time it will train but silently work a bit worse.
- [lab] Example of a silent leak: an autoregressive model taking its own target as input
  through an off-by-one bug. Intro ^f2
  > Or maybe your autoregressive model accidentally takes the thing it’s trying to predict as an input due to an off-by-one bug.
- [lab] Method: build simple to complex, state a concrete hypothesis at each step and
  test it; avoid adding much unverified complexity at once. The recipe ^f3
  > at every step of the way we make concrete hypotheses about what will happen and then either validate them with an experiment or investigate until we find some issue.
- [lab] Check loss at initialisation against its known value (-log(1/n_classes) for
  softmax; derivable for other losses). Step 2 ^f4
  > **verify loss @ init**. Verify that your loss starts at the correct loss value.
- [lab] Initialise the output bias to the base rate (e.g. predict 0.1 for a 1:10 class
  ratio) to avoid a hockey-stick loss curve. Step 2 ^f5
  > set the bias on your logits such that your network predicts probability of 0.1 at initialization.
- [lab] Train an input-independent baseline (inputs zeroed); the real model must beat
  it, which shows it extracts information from the input at all. Step 2 ^f6
  > Train an input-independent baseline, (e.g. easiest is to just set all your inputs to zero). This should perform worse than when you actually plug in your data without zeroing it out.
- [lab] Overfit a single tiny batch (as few as two examples) to the lowest achievable
  loss; if it cannot, there is a bug and work stops. Step 2 ^f7
  > Overfit a single batch of only a few examples (e.g. as little as two).
  > If they do not, there is a bug somewhere and we cannot continue to the next stage.
- [lab] Fix the random seed so two runs of the same code give the same outcome. Step 2 ^f8
  > Always use a fixed random seed to guarantee that when you run the code twice you will get the same outcome.
- [lab] Evaluate on the entire test set rather than smoothed batch losses. Step 2 ^f9
  > When plotting the test loss run the evaluation over the entire (large) test set.
- [lab] Inspect exactly what enters the model, decoded from the raw tensor just before
  the forward call: the only source of truth for preprocessing bugs. Step 2 ^f10
  > you want to visualize _exactly_ what goes into your network, decoding that raw tensor of data and labels into visualizations. This is the only “source of truth”.
- [lab] Dependency check by gradient: set the loss to example i's outputs and confirm a
  non-zero gradient only on input i (catches batch mixing; also checks a model at t
  depends only on 1..t-1). Step 2 ^f11
  > set the loss to be something trivial like the sum of all outputs of example **i**, run the backward pass all the way to the input, and ensure that you get a non-zero gradient only on the **i-th** input.
- [lab] Add signals one at a time and check each gives the expected boost. Step 3 ^f12
  > If you have multiple signals to plug into your classifier I would advise that you plug them in one by one and every time ensure that you get a performance boost you’d expect.
- [lab] Learning-rate decay defaults keyed to epoch number can silently drive the rate
  to zero early; he uses constant LR and tunes decay last. Step 3 ^f13
  > If you’re not careful your code could secretely be driving your learning rate to zero too early, not allowing your model to converge.
- [lab] Before tuning, know the input-independent and dumb-baseline scores (must beat)
  and a rough human level. Step 3 ^f14
  > We are also armed with our performance for an input-independent baseline, the performance of a few dumb baselines (we better beat these)
- [lab] More real data is the only near-guaranteed regulariser; ensembles top out
  around 5 models. Step 4 ^f15
  > adding more data is pretty much the only guaranteed way to monotonically improve the performance of a well-configured neural network almost indefinitely. The other would be ensembles (if you can afford them), but that tops out after ~5 models.
- [lab] Checked, not there: no seed-variance check; the fixed seed is for debugging,
  not for judging an improvement. ^f16
- [lab] (inferred) For meiolol-lab: init loss vs log(2) / base-rate log loss, a
  shuffled-input or champion-ids-only baseline, overfit-256-games and a per-game
  gradient dependency check are all mechanical and could run before every new net
  architecture is trusted. ^f17

## Read

- Whole post

## Not read

- Linked tweet and webinar on common mistakes

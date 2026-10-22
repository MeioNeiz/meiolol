---
title: 'GitLab Vale rules: SentenceLength, ReadingLevel, Wordy, Simplicity'
url: https://gitlab.com/gitlab-org/gitlab/-/tree/master/doc/.vale/gitlab_base
kind: project
commit: 5ea1fe5dfb9d256c26a4d922d8716bdbde9354cd
for: [ui-guardrails]
looked: 2026-10-22
depth: code (4 rule files in doc/.vale/gitlab_base, from the GitHub mirror)
relevance: medium
grade: A/fair
description: Four of GitLab's 52 Vale rules for docs prose: 25-word sentence cap, Flesch-Kincaid grade 8 target, wordy-phrase swaps, banned ease-of-use words; all at suggestion or warning level
---
# GitLab Vale rules: SentenceLength, ReadingLevel, Wordy, Simplicity

Why: the exact thresholds a large team encodes for terse copy.

## Assessment

- Evidence: A. gitlabhq (24.5k stars, since 2011), rules applied to every docs change.
- Reasoning: fair. Each rule's message says what to do; thresholds unexplained.
- Interests: none.
- Weigh: thresholds are for docs sentences; UI labels need far tighter caps.

## Findings

- [web/qa] Sentence cap: 25 words, at suggestion level (never fails CI).
  `doc/.vale/gitlab_base/SentenceLength.yml` ^f1
  > message: "Improve readability by using fewer than 25 words in this sentence."
  > level: suggestion
- [web/qa] Reading level: Flesch-Kincaid formula, aim for grade 8 or lower.
  `doc/.vale/gitlab_base/ReadingLevel.yml` ^f2
  > message: "The grade level is %s. Aim for 8th grade or lower by using shorter sentences and words."
- [web/qa] Wordy phrases get a mechanical swap list (as well as, in order to, note that,
  quite). `doc/.vale/gitlab_base/Wordy.yml` ^f3
  > in order to: "Remove 'in order' and leave 'to'."
- [web/qa] Words implying ease (easy, simply, useful) are a warning: be precise, not
  subjective. `doc/.vale/gitlab_base/Simplicity.yml` ^f4
  > message: "Remove '%s'. Be precise instead of subjective."
- [web/qa] (inferred) Every one is a regex or word count over text, so the same checks fit
  a Zig test over the strings each page component emits. ^f5

## Read

- The four rule files; the directory listing (52 rules)

## Not read

- The other 48 rules (branding, markdown, spelling)

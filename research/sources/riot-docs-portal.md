---
title: Riot Developer Portal docs (product registration, API key types, rate limits)
url: https://developer.riotgames.com/docs/portal
kind: docs
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: docs (Product Registration, API Keys, Rate Limiting)
relevance: high
grade: A/fair
description: Riot's description of the registration flow, review criteria, key types and starting limits
---
# Riot Developer Portal docs

Why: the official registration flow, what reviewers look for, key types.

## Assessment

- Evidence: A. Canonical Riot docs; undated page, some text old (versioning "as of 2019").
- Reasoning: fair. Explains review intent ("help players get better", not "solve our games").
- Interests: Riot.
- Weigh: starting production limits here may be stale (third-party 2026 blog says defaults now
  equal dev limits; verify with recent approvals).

## Findings

- [policy] Flow: Register Product, choose larger-scale vs personal, online form, then verify ownership. ^f1
  > From there you'll need to decide if this is for a larger scale product, or a personal project. From there we'll ask you to fill out an online form that gathers some key details about your product. Finally, we'll ask you to verify your product
- [policy] Review criteria: legal and policy compliance, measurable player benefit, quality. ^f2
  > We'll also want to make sure that the product helps players in some measurable way. We want to see product that help players get better at our games, or track their growth.
- [policy] [draft] Riot does not want products that solve the game. ^f3
  > What we don't want to see are products that solve our games or make everything too simple.
- [policy] Incomplete websites are unlikely to be approved. ^f4
  > If your website isn't complete, we're unlikely to approve your product.
- [policy] Rejections come as portal messages and can be worked through with DevRel. ^f5
  > If your product proposal is rejected, we'll be sure to leave you a message in the Developer Portal.
- [policy] Support site is the quickest channel for registration questions. ^f6
  > Using the Support Site is the surest and quickest way to get a response from the Developer Relations team.
- [policy] [data] Personal keys: no verification, no rate limit increases, 20/1s and 100/2min per region. ^f7
  > These products can be registered without the verification process, but won't be approved for rate limit increases.
  > 20 requests every 1 second
  > 100 requests every 2 minutes
- [policy] Personal keys cannot run public products, including open alpha/beta, however long production review takes. ^f8
  > You may not run your application for public consumption using a personal key, regardless of how long the approval process for your production key takes. Note that public consumption includes open alpha/beta tests.
- [policy] [data] Documented production starting limit 500/10s and 30,000/10min per region; typically needs working prototype. ^f9
  > Typically requires a working prototype before receiving an API key.
  > 500 requests every 10 seconds
  > 30,000 requests every 10 minutes
- [policy] [data] Increases beyond standard production need good standing, community benefit, outgrowing the limit. ^f10
  > it can be expanded if the developer is in good standing, has demonstrated a strong community benefit, and has steadily outgrown the standard production limit.
- [policy] Each project registered and approved separately. ^f11
  > If you are working on multiple projects, you should register each one separately and each one needs to be individually approved for a separate production API key.
- [policy] Checked, not there: no field-by-field list of the registration form; no riot.txt detail on this page. ^f12

## Read

- Overview, Product Registration, Messages, API Keys, Rate Limiting

## Not read

- Live registration form at /app-type (requires login)

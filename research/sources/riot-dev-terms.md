---
title: Riot Games API Terms and Conditions (last updated 2013-12-09)
url: https://developer.riotgames.com/terms
kind: docs
commit:
for: [riot-production-key, identity-and-privacy]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: A/weak
description: Riot's binding API licence; licensed purpose, ownership of derivatives, key registration, deletion on termination
---
# Riot Games API Terms and Conditions (last updated 2013-12-09)

Why: what the API licence says about data use, storage, retention and AI/ML model training.

## Assessment

- Evidence: A. Canonical contract text from Riot; header says last updated 9 Dec 2013,
  footer copyright 2021 (GDPR section added later without bumping the date).
- Reasoning: weak. Legal boilerplate, broad "sole discretion" rights, no rationale.
- Interests: Riot (licensor).
- Weigh: binding but old; written before ML was a use case, so silence on AI is not
  permission. Licensed purpose and derivative-ownership clauses are what a reviewer could
  lean on. Policies page (riot-policies-general) is the operative day-to-day layer.

## Findings

- [policy] Terms last updated 9 Dec 2013; Riot may amend at its discretion. ^f1
  > LAST UPDATED: DECEMBER 9, 2013
- [policy] [data] Licensed purpose is displaying Game Information to end users, or other
  purposes Riot sets out in Specifications or in writing. ^f2
  > to access and use the Materials owned by Riot in order to develop and distribute Applications that incorporate, access or use any Game Information, for the purpose of displaying such Game Information to end users of such Applications or for such purposes as may be (i) set forth in the Specifications and/or any other Materials, and/or (ii) communicated by Riot in writing from time to time in its sole discretion
- [policy] [data] Riot owns the Materials including derivatives; Materials include Game
  Information and extracts and derivatives of it. ^f3
  > Riot owns all right, title and interest (including all intellectual property rights) in and to the Materials, including all output and executables of the Riot Games API, and including any modifications to or derivatives of the Materials.
  > the Game Information, the Specifications (including any copies, portions, extracts and derivatives thereof)
- [policy] [data] (inferred) A model trained on match-v5 data could be argued to be a
  "derivative" of Game Information, so Riot would own it on this reading; untested. ^f4
- [policy] [data] On termination, stop using and delete all Game Information held. No
  retention period otherwise stated. ^f5
  > Upon termination of these API Terms, You shall immediately cease using the Materials, including without limitation any Game Information in Your possession, as well as delete all of the Game Information in Your possession.
- [policy] [data] GDPR: Riot passes deletion requests to all active developers as lists of
  identifiers via Riot Channels. ^f6
  > When Riot Games receives a request from an end user to delete their personal data, we will be passing the request to all active developers by sharing a list of identifiers (e.g. accountId) for the end users through Riot Channels.
- [policy] Charging for access needs Riot's prior written approval; advertising does not. ^f7
  > In the event You desire to resell or license any Application, charge for access to Game Information through a website or otherwise require payment for access to the Game Information, You must notify Riot and obtain Riot's prior written approval before undertaking such activities
- [policy] Prohibited: interfering with the Game or enabling cheating; collecting info
  beyond provided Game Information. ^f8
  > Using the Riot Games API in a manner that disrupts, circumvents, or interferes with any part of the Game; or forges or modifies any data processed or distributed by the Game, such as, but not limited to spyware, adware or malware; or enables or promotes cheating in the Game.
  > Using the Riot Games API to collect any additional information about the Game or Game users that is not provided Game Information or permitted by the Riot Games API.
- [policy] Registration: must not hide or misrepresent features; Riot may register at its
  discretion and ask for materials to confirm compliance. ^f9
  > You shall not hide, misrepresent or obscure any features, content, services or functionality in such Application.
  > Riot will have the right (but not the obligation), in its sole discretion, to register such Application
- [policy] A production key is not endorsement or approval. ^f10
  > no act by Riot shall constitute endorsement, certification or approval of any Application, including, without limitation, Riot's registration of an Application and issuance of a Production Key.
- [policy] Keys revocable for any reason; Riot may terminate the licence at any time. ^f11
  > Riot may terminate the license at any time for any reason.
- [policy] [data] Checked, not there: no mention of AI, machine learning, model training,
  datasets, data storage limits or a retention period (other than delete on
  termination). ^f12

- [privacy] [policy] Apps must not violate anyone's privacy rights or applicable laws. ^f13
  > Using the Riot Games API for any Application to violate anyone's privacy rights
- [privacy] Riot treats API data as possibly GDPR personal data and applies GDPR
  standards globally. ^f14
  > While GDPR is a European Union regulation Riot Games has committed to following the standards put forth in the regulation globally. As a developer using the Riot Games API, you may have access to personal data subject to the GDPR.

## Read

- whole page (definitions through termination)

## Not read

- http://www.riotgames.com/legal-jibber-jabber: monetisation policy link, likely stale

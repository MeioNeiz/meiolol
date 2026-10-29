---
title: 'Tune The Web: Critical Resources and the First 14 KB - A Review'
url: https://www.tunetheweb.com/blog/critical-resources-and-the-first-14kb/
kind: article
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: medium
grade: B/strong
description: Barry Pollard (HTTP/2 in Action author, later Chrome web performance DevRel; 2019, edited 2022) on why the 14 KB first-round-trip rule is theoretical; Wireshark capture of amazon.com
---
# Tune The Web: Critical Resources and the First 14 KB - A Review

Why: does the 14 KB target for HTML plus inlined CSS still hold under TLS and HTTP/2?

## Assessment

- Evidence: B. Expert's first-hand packet capture, but one site (amazon.com) and a 20 ms RTT (repeated at 300 ms, anecdotal by his own words).
- Reasoning: strong: walks through the TCP arithmetic, admits the test is anecdotal.
- Interests: promotes his book.
- Weigh: the direction (14 KB is not a cliff) more than any number; nothing on HTTP/3/QUIC.

## Findings

- [seo] [web] Source of the number: TCP slow start allows 10 packets before an ACK, about 1460 bytes of payload each, doubling each round trip. The basics of TCP ^f1
  > when TCP starts it allows 10 TCP packets to be sent, before they must be acknowledged
- [seo] [web] TLS and HTTP/2 setup exchange packets whose ACKs grow the congestion window before the HTML is sent, so more than 14 KB can go unacknowledged. 14 KB and the modern web ^f2
  > some of those back and forth messages will have resulted in TCP ACKs meaning we will have **more** than 14 KB when we come to sending back the HTML not **less**
- [seo] [web] In his capture of amazon.com, at least 20 packets were ACKed as the HTML started, so 28 to 57 KB could be sent unacknowledged. Real Life Example ^f3
  > we're somewhere between 28 KB and 57 KB that can be sent unacknowledged
- [seo] [web] DevTools network throttling can't show this: it throttles inside Chrome, not at the network layer. ^f4
  > using [Chrome's Dev Tools network throttling won't help here](https://youtu.be/ct5MvtmL1NM?t=5825) as that is artificial throttle within Chrome
- [seo] [web] Verdict: 14 KB is not a hard limit; keep important resources early and the page small, but don't fixate on it. Summary ^f5
  > I think the 14 KB number is not an absolute number or something web developers should be adhering to, too rigidly
- [web] He personally dislikes inlining critical CSS (separate post). ^f6
  > if you inline critical CSS – [which I don't actually like btw!](https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/)

## Read

- Whole article

## Not read

- HTTP/3/QUIC: not covered (QUIC has its own initial window and amplification limit)

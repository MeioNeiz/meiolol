---
title: Hetzner Storage Box prices (live price JSON behind the product page, 2026-10-11)
url: https://www.hetzner.com/_resources/app/data/app/live_data_prices.json
kind: dataset
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (Storage Box entries only)
relevance: high
grade: A/fair
description: Monthly and hourly Storage Box prices from the JSON Hetzner's site loads into its product table; BX11 1 TB EUR 3.20/month
---
# Hetzner Storage Box prices (live price JSON, 2026-10-11)

Why: the product page renders prices by script, so the snapshot lacks them

## Assessment

- Evidence: A. Hetzner's own price feed; raw is an excerpt (four products) plus the
  name to product-key pairs read from the page HTML.
- Reasoning: n/a (data).
- Interests: vendor.
- Weigh: prices appear to be net of VAT (the site adds VAT per country); the June 2026
  Hetzner price rise lists servers, not Storage Boxes ([[hetzner-price-adjustment]]).

## Findings

- [ops] BX11 (1 TB) costs EUR 3.20/month (USD 4.00), Falkenstein or Helsinki. ^f1
  > BX11 product-key="ROBOT_1333"
  > "monthly": {"USD": "4.00", "EUR": "3.20"}
- [ops] BX21 (5 TB) EUR 10.90/month. ^f2
  > BX21 product-key="ROBOT_1334"
  > "monthly": {"EUR": "10.90", "USD": "13.00"}
- [ops] BX31 (10 TB) EUR 20.80/month; BX41 (20 TB) EUR 40.60/month. ^f3
  > "monthly": {"USD": "24.00", "EUR": "20.80"}
  > "monthly": {"EUR": "40.60", "USD": "46.00"}
- [ops] Billed hourly up to the monthly cap (BX11 EUR 0.0051/hour). ^f4
  > "hourly": {"EUR": "0.005100", "USD": "0.006400"}
- [ops] (inferred) With 20% UK VAT a BX11 is about EUR 3.84/month; 5 TB about EUR 13. ^f5

## Read

- the four Storage Box entries

## Not read

- VAT table (live_data_vat.json)

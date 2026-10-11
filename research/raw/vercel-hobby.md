---
title: Vercel Hobby Plan
product: vercel
url: /docs/plans/hobby
canonical_url: "https://vercel.com/docs/plans/hobby"
last_updated: 2026-09-14
type: reference
prerequisites:
  - /docs/plans
related:
  - /docs/pricing/taxes
  - /docs/global-config/using-global-config
  - /docs/pricing/regional-pricing
  - /docs/functions/usage-and-pricing
  - /docs/image-optimization/limits-and-pricing
summary: Learn about the Hobby plan and how it compares to the Pro plan.
install_vercel_plugin: npx plugins add vercel/vercel-plugin
---

# Vercel Hobby Plan

The Hobby plan is **free** and aimed at developers with personal projects, and small-scale applications. It offers a generous set of features for individual users on a **per month** basis:


<!-- docsgraph:related -->
## Related pages

> **For AI agents:** Follow these links to understand how this page connects to the rest of the Vercel ecosystem. For the full cross-link map (inbound, outbound, prerequisites, and semantic neighbors), see the .graph.md link below.

- [Agent Runs](https://eve.dev/docs/observability/agent-runs?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related) — Inspect eve sessions in Vercel and configure the Agent Runs destination.
- [Why has my account or deployment been paused?](https://vercel.com/kb/guide/why-is-my-account-deployment-blocked?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related) — Learn why a Vercel account or deployment gets paused, from budget and usage limits to policy violations, and how to resu
- [A more flexible Pro plan for modern teams](https://vercel.com/blog/new-pro-pricing-plan?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related)
- [Improved infrastructure pricing](https://vercel.com/blog/improved-infrastructure-pricing?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related)
- [Vercel Pricing](https://vercel.com/pricing?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related) — Choose a Vercel plan and compare features and usage pricing.
- [Pricing on Vercel](https://vercel.com/docs/pricing?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related) — Learn about Vercel's pricing model, including the resources and services that are billed, and how they are priced.
- [Billing FAQ for Pro Plan](https://vercel.com/docs/plans/pro-plan/billing?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related) — This page covers frequently asked questions around payments, invoices, and billing on the Pro plan.
- [Observability Plus](https://vercel.com/docs/observability/observability-plus?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related) — Learn about using Observability Plus and its limits.
- [Account Management](https://vercel.com/docs/accounts?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related) — Learn how to manage your Vercel account and team members.
- [Manage and optimize usage](https://vercel.com/docs/pricing/manage-and-optimize-usage?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=related) — Understand how to manage and optimize your usage on Vercel, learn how to track your usage, set up alerts, and optimize y

Full cross-link map for this page: [/docs/plans/hobby.graph.md](/docs/plans/hobby.graph.md?from=related&source_path=%2Fdocs%2Fplans%2Fhobby&source_site=vercel-docs&relationship=graph)
<!-- /docsgraph:related -->

> **💡 Note:** All prices shown are in USD and exclude value-added tax (VAT), goods and services tax (GST), and other applicable taxes. Taxes are calculated based on your billing address and added to your invoice where required by law. [Learn more about taxes](/docs/pricing/taxes).

| Resource                                                                                            | Hobby Included Usage |
| --------------------------------------------------------------------------------------------------- | -------------------- |
| [Global Config Reads](/docs/global-config/using-global-config#reading-data-from-global-configs)           | First 100,000        |
| [Global Config Writes](/docs/global-config/using-global-config#writing-data-to-global-configs)             | First 100            |
| [Fast Data Transfer](/docs/pricing/regional-pricing)                                                | First 100 GB            |
| [Fast Origin Transfer](/docs/pricing/regional-pricing)                                              | First 10 GB          |
| [CDN Requests](/docs/pricing/regional-pricing)                                                     | First 1,000,000 |
| [Active CPU](/docs/functions/usage-and-pricing)                                                     | 4 CPU-hrs            |
| [Provisioned Memory](/docs/functions/usage-and-pricing)                                             | 360 GB-hrs           |
| [Function Invocations](/docs/functions/usage-and-pricing)                                           | First 1,000,000      |
| [Image Transformations](/docs/image-optimization/limits-and-pricing#image-transformations)           | First 5,000          |
| [Image Cache Reads](/docs/image-optimization/limits-and-pricing#image-cache-reads)                   | First 300,000        |
| [Image Cache Writes](/docs/image-optimization/limits-and-pricing#image-cache-writes)                 | First 100,000        |
| [Speed Insights Events](/docs/speed-insights/limits-and-pricing)                                    | 10,000 events over the last 30 days, shared across the team |
| [Web Analytics Events](/docs/analytics/limits-and-pricing#what-is-an-event-in-vercel-web-analytics) | 50,000 events / month included |
| [Workflow Events](/docs/workflows/pricing)                                                           | 50,000 events / month included |
| [Workflow Data Written](/docs/workflows/pricing)                                                     | 1 GB                          |
| [Connect Token Requests](/docs/connect/pricing#token-requests)                                       | First 500          |
| [Connect Triggers](/docs/connect/pricing#triggers)                                   | First 1,000          |

## Hobby billing cycle

As the Hobby plan is a free tier there are no billing cycles. In most cases, if you exceed your usage limits on the Hobby plan, you will have to wait until 30 days have passed before you can use the feature again.

Some usage limits have shorter pause periods:

- [Web Analytics](/docs/analytics/limits-and-pricing#hobby): collection pauses
  after the grace period and can resume after 7 days

As stated in the [fair use guidelines](/docs/limits/fair-use-guidelines#commercial-usage), the Hobby plan restricts users to non-commercial, personal use only.

When your personal account gets converted to a Hobby team, your usage and activity log will be reset. To learn more about this change, read the [changelog](/changelog/2024-01-account-changes).

## Comparing Hobby and Pro plans

The Pro plan offers more resources and advanced features compared to the Hobby plan. The following table provides a side-by-side comparison of the two plans:

| Feature | Hobby | Pro |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Projects | 200 | Unlimited |
| Vercel Function maximum duration | 300s (5 minutes) | 300s (default) - [configurable up to 800s](/docs/functions/configuring-functions/duration); [extended max duration up to 1800s](/docs/functions/configuring-functions/duration#extended-max-duration-beta) (30 minutes, beta) |
| Build vCPUs | 2 | 4, up to [30](/docs/builds/managing-builds#build-machine-types) |
| Build memory (GB) | 8 | 8GB, up to [60GB](/docs/builds/managing-builds#build-machine-types) |
| Build disk size | 32 GB | 32 GB, up to [64 GB](/docs/builds/managing-builds#build-machine-types) |
| Team collaboration features | - | Yes |
| Domains per project | 50 | Unlimited |
| Deployments per day | 100 | 6,000 |
| Analytics | 50,000 included Events <br />1 month of data | On-demand events <br />Web Analytics Plus add-on |
| Email support | - | Yes |
| [RBAC](/docs/rbac/access-roles) available | N/A | [Owner](/docs/rbac/access-roles#owner-role), [Member](/docs/rbac/access-roles#member-role), [Billing](/docs/rbac/access-roles#billing-role), [Viewer Pro](/docs/rbac/access-roles#pro-viewer-role) |
| [Comments](/docs/comments) | Available | Available for team collaboration |
| [Drains](/docs/drains) | - | [Configurable](/docs/drains/using-drains) (not on a trial) |
| Spend Management | N/A | [Configurable](/docs/spend-management) |
| [Vercel Toolbar](/docs/vercel-toolbar) | Available for certain features | Available |
| [Storage](/docs/storage) | Blob | Blob |
| [Activity Logs](/docs/activity-log) | Available | Available |
| [Runtime Logs](/docs/logs/runtime) | 1 hour of logs | 1 day of logs |
| [DDoS Mitigation](/docs/vercel-firewall/ddos-mitigation) | On by default. Optional [Attack Mode](/docs/vercel-firewall/attack-mode). | On by default. Optional [Attack Mode](/docs/vercel-firewall/attack-mode). |
| [Vercel WAF IP Blocking](/docs/vercel-firewall/vercel-waf/ip-blocking) | Up to 3 | Up to 100 |
| [Vercel WAF Custom Rules](/docs/vercel-firewall/vercel-waf/custom-rules) | Up to 3 | Up to 40 |
| [Deployment Protection](/docs/deployment-protection/usage-and-pricing) | [Vercel Authentication](/docs/deployment-protection/methods-to-protect-deployments/vercel-authentication) for preview and production deployments, [Deployment Protection Exceptions](/docs/deployment-protection/methods-to-bypass-deployment-protection/deployment-protection-exceptions), and [Shareable Links](/docs/deployment-protection/methods-to-bypass-deployment-protection/sharable-links) | The Hobby features, plus [Password Protection](/docs/deployment-protection/methods-to-protect-deployments/password-protection) for $20 per month per protected project |
| [Connect Token Requests](/docs/connect/pricing#token-requests) | 500 included | Unlimited (on-demand) |
| [Connect Triggers](/docs/connect/pricing#triggers) | 1,000 included | Unlimited (on-demand) |

## Upgrading to Pro

You can take advantage of Vercel's Pro trial to explore [Pro features](/docs/plans/pro-plan) for free during the trial period, with some [limitations](/docs/plans/pro-plan/trials#trial-limitations).

The [free first-year domain offer](/docs/plans/pro-plan#free-first-year-domain-with-pro) is not available during the Pro trial. It applies to paid Pro teams: a team becomes eligible once it is on a paid Pro plan.

To upgrade from a Hobby plan:

1. Go to your [dashboard](/dashboard). If you're upgrading a team, make sure to select the team you want to upgrade
2. Open **Settings** in the sidebar and select [**Billing**](https://vercel.com/d?to=%2F%5Bteam%5D%2F%7E%2Fsettings%2Fbilling\&title=Go+to+Billing)
3. Under **Plan**, if your team is eligible for an upgrade, you can click the **Upgrade** button. Or, you may need to create or select a team to upgrade. In that case, you can click **Create a Team** or **Upgrade a Team**
4. Optionally, add team members. Developer seats cost **$20 per user / month**, while Viewer seats are free
5. Enter your card details
6. Click **Confirm and Upgrade**

If you would like to end your paid plan, you can [downgrade to Hobby](/docs/plans/pro-plan#downgrading-to-hobby).


---

[View full sitemap](/docs/sitemap)

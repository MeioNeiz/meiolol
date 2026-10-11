# Fly.io Resource Pricing - Fly.io

<https://docs.fly.io/about/pricing>

> ## Documentation Index
> 
> Fetch the complete documentation index at: [/llms.txt](https://docs.fly.io/llms.txt)
> 
> Use this file to discover all available pages before exploring further.

[Skip to main content](https://docs.fly.io/about/pricing#content-area)

[Fly.io home page](https://docs.fly.io/)

### Fly docs

-   
-   
-   
-   
-   
-   
-   
-   
-   [
    
    Fly Postgres (Unmanaged)
    
    
    
    ](https://docs.fly.io/unmanaged-postgres)
-   
-   
-   
-   
-   
-   
-   
-   -   [
        
        Discontinued Plans
        
        
        
        ](https://docs.fly.io/about/discontinued-plans)
    -   [
        
        Fly.io Resource Pricing
        
        
        
        ](https://docs.fly.io/about/pricing)
    -   [
        
        Fly.io Billing
        
        
        
        ](https://docs.fly.io/about/billing)
    -   [
        
        Cost Management on Fly.io
        
        
        
        ](https://docs.fly.io/about/cost-management)
    -   [
        
        Fly.io Free Trial
        
        
        
        ](https://docs.fly.io/about/free-trial)
    -   [
        
        Support
        
        
        
        ](https://docs.fly.io/about/support)
    -   
    -   [
        
        Healthcare apps on Fly
        
        
        
        ](https://docs.fly.io/about/healthcare)
    -   [
        
        Fly.io Extensions Program
        
        
        
        ](https://docs.fly.io/about/extensions)
    -   [
        
        Provisioning Fly.io Extensions
        
        
        
        ](https://docs.fly.io/reference/extensions_api)
    -   [
        
        Fly.io Merchandise
        
        
        
        ](https://docs.fly.io/about/merch)
    -   [
        
        Fly.io and Open Source
        
        
        
        ](https://docs.fly.io/about/open-source)
    -   [
        
        Using Our Brand
        
        
        
        ](https://docs.fly.io/about/brand)
-   

-   [
    
    Pricing
    
    ](https://fly.io/pricing/)
-   [
    
    Support
    
    ](https://docs.fly.io/about/support)

[Fly docs

](https://docs.fly.io/getting-started)[Machines API

](https://docs.fly.io/api/machines)[Sprite docs

](https://docs.fly.io/sprites)[Sprites API

](https://docs.fly.io/sprites/api/connectors/list-connectors)

About

# Fly.io Resource Pricing

**Fly.io bills for the resources you use, with no monthly platform fee. The smallest always-on app costs $2.19 per 30 days. A small web app with a Managed Postgres database costs about $44 a month. The table below lists what we charge for, followed by a few examples of what real-ish apps cost.**

## 

[​

](https://docs.fly.io/about/pricing#everything-we-bill-for)

Everything we bill for

Prices are in USD. Machine prices in this table are for Ashburn, Virginia (`iad`) and Secaucus, NJ (`ewr`), our lowest-priced regions. Machine prices vary by region; see [Started Fly Machines](https://docs.fly.io/about/pricing#started-fly-machines) for the full list. Monthly Machine prices assume 30 days of continuous runtime. Machines are billed by the second while they’re running, so an always-on Machine costs slightly more in a 31-day month.

| What you pay for | Price | Notes |
| --- | --- | --- |
| Started Machine, `shared-cpu-1x` with 256MB RAM | $2.19/month | Smallest Machine size. Billed by the second while running |
| Started Machine, `shared-cpu-1x` with 512MB RAM | $3.69/month |  |
| Started Machine, `shared-cpu-1x` with 1GB RAM | $6.70/month |  |
| Started Machine, `shared-cpu-2x` with 2GB RAM | $13.39/month |  |
| Started Machine, `performance-1x` with 2GB RAM | $33.00/month |  |
| Started Machine, `performance-2x` with 4GB RAM | $66.00/month |  |
| Additional Machine RAM | $6.00/GB/month | RAM added beyond the amount included with the CPU preset |
| Stopped or suspended Machine | $0.15/GB/month of rootfs | Only the Machine’s root file system is billed while it’s stopped |
| Volume | $0.15/GB/month | Based on provisioned capacity, including while detached or attached to a stopped Machine |
| Volume snapshots | $0.08/GB/month | First 10GB free each month. Based on data stored, not provisioned volume size |
| Dedicated IPv4 address | $2/month | Optional. Apps get a shared IPv4 address and IPv6 addresses at no charge |
| Static egress IP | $0.005/hour (~$3.60/month) | Optional |
| SSL certificates | $0.10/month per single hostname; $1/month per wildcard | First 10 single-hostname certificates are free |
| Outbound data to the internet | $0.02/GB in North America and Europe  
$0.04/GB in Asia Pacific, Oceania, and South America  
$0.12/GB in Africa and India | Inbound data is free |
| Private network data between regions | $0.006/GB in North America and Europe  
$0.015/GB in Asia Pacific, Oceania, and South America  
$0.050/GB in Africa and India | Data transfer within a region is free. Different rates apply to some older organizations; see [data transfer pricing](https://docs.fly.io/about/pricing#data-transfer-pricing) |
| Managed Postgres | $38/month (Basic) to $1,922/month (Performance) | Storage is $0.28/GB/month based on usage. See [Managed Postgres pricing](https://docs.fly.io/postgres#pricing) |
| Support | $29/month Standard; $199/month Premium; Enterprise starts at $2,500/month | Optional. Community support is free |
| Fly Kubernetes | $75/month per cluster | Compute and volumes are billed separately |
| Extensions such as Tigris and Upstash | Provider’s list price | Pricing is set by the extension provider and charges appear on your Fly.io invoice |

New organizations use Pay As You Go pricing. There’s no monthly platform fee; you pay for the resources and services you use.

## 

[​

](https://docs.fly.io/about/pricing#what-does-a-typical-app-cost)

What does a typical app cost?

Here are three example apps and what they’d cost per month. We use Ashburn (`iad`) for the examples unless otherwise noted, and assume the Machines run continuously. Traffic and storage marked “assumed” are example workloads, not included allowances. You can use the [pricing calculator](https://fly.io/calculator/) to estimate costs for your own app. If your Machines [auto-stop](https://docs.fly.io/launch/autostop-autostart) when they’re idle, your compute costs can be lower. You pay for the time a Machine is running and for its rootfs while it’s stopped. If the Machine runs all month, you’ll pay the full always-on cost shown here. See [Cost Management](https://docs.fly.io/about/cost-management) for more ways to estimate and control your bill.

### 

[​

](https://docs.fly.io/about/pricing#a-small-web-app-with-managed-postgres)

A small web app with Managed Postgres

| Item | Monthly cost |
| --- | --- |
| One `shared-cpu-1x` 512MB Machine, running continuously | $3.69 |
| 10GB volume | $1.50 |
| Managed Postgres, Basic plan | $38.00 |
| 1GB of Managed Postgres storage (assumed) | $0.28 |
| Volume snapshots, within the 10GB free allowance (assumed) | $0.00 |
| 10GB outbound data to the internet from North America (assumed) | $0.20 |
| **Total** | **$43.67** |

The app and database run in the same region, so data transfer between them is free. The app also uses a shared IPv4 address, which is free. In this example, Managed Postgres accounts for most of the bill. The app Machine and its 10GB volume cost $5.19 per month.

### 

[​

](https://docs.fly.io/about/pricing#a-discord-bot-or-background-worker-running-24/7)

A Discord bot or background worker running 24/7

| Item | Monthly cost |
| --- | --- |
| One `shared-cpu-1x` 256MB Machine, running continuously | $2.19 |
| 1GB outbound data to the internet from North America (assumed) | $0.02 |
| **Total** | **$2.21** |

This example doesn’t use a volume, database, or dedicated IPv4 address, so there’s nothing else to pay for. If the worker needs more memory, a `shared-cpu-1x` Machine with 512MB costs $3.69 per month when running continuously.

### 

[​

](https://docs.fly.io/about/pricing#an-app-running-in-three-regions)

An app running in three regions

Suppose an app runs one 1GB Machine each in Ashburn (`iad`), Frankfurt (`fra`), and Singapore (`sin`). Each Machine serves 50GB of traffic to users and sends 10GB of private network traffic to Machines in other regions during the month.

| Item | Monthly cost |
| --- | --- |
| One `shared-cpu-1x` 1GB Machine in Ashburn (`iad`) | $6.70 |
| One `shared-cpu-1x` 1GB Machine in Frankfurt (`fra`) | $7.73 |
| One `shared-cpu-1x` 1GB Machine in Singapore (`sin`) | $8.50 |
| 100GB outbound data from `iad` and `fra` at $0.02/GB (assumed) | $2.00 |
| 50GB outbound data from `sin` at $0.04/GB (assumed) | $2.00 |
| 20GB cross-region private network data from `iad` and `fra` at $0.006/GB (assumed) | $0.12 |
| 10GB cross-region private network data from `sin` at $0.015/GB (assumed) | $0.15 |
| **Total** | **$27.20** |

Machine prices vary by region, which accounts for the different compute costs above. Cross-region private network traffic is billed in both directions. The request is billed at the rate for the region it leaves, and the response at the rate for the region it leaves. So if a small request returns a large response, most of the cost is at the responding region’s rate. This example uses granular data transfer pricing. Organizations created before July 18, 2024 that haven’t switched to granular pricing pay the public internet rate for cross-region traffic instead. See [data transfer pricing](https://docs.fly.io/about/pricing#data-transfer-pricing).

## 

[​

](https://docs.fly.io/about/pricing#is-there-a-free-tier)

Is there a free tier?

No. New organizations don’t have a free tier or a monthly free usage allowance. New accounts do get a [free trial](https://docs.fly.io/about/free-trial), which lasts for up to 2 hours of Machine runtime or 7 days, whichever comes first. You don’t need a credit card to start the trial. After the trial ends, you’ll need to add a credit card to keep using billable resources. The cheapest always-on app is a `shared-cpu-1x` Machine with 256MB of RAM in Ashburn (`iad`) or Secaucus (`ewr`). It costs $2.19 per 30 days of continuous runtime, plus any outbound data transfer ($0.02/GB in North America and Europe). Some resources and allowances are free even after the trial ends. These include the first 10GB of volume snapshot storage each month, the first 10 single-hostname SSL certificates, inbound data transfer, shared IPv4 addresses, and IPv6 addresses. Organizations on plans discontinued in October 2024 keep the free allowances included with those plans. See [Discontinued Plans](https://docs.fly.io/about/discontinued-plans).

## 

[​

](https://docs.fly.io/about/pricing#how-it-works)

How it works

Fly.io services are billed per organization, with [Linked Organizations](https://docs.fly.io/about/billing#unified-billing) reporting resource usage to their parent Billing Organization. Plans get complicated, so we just charge based on usage. Pick and choose which pieces you need for your application; that’s all you’ll see on your invoice. Organizations are administrative entities on Fly.io that let you add members, share app development environments, and manage billing. [Billing](https://docs.fly.io/about/billing) is based on the resources provisioned for your apps, pro-rated for the time they are provisioned. Organizations may be subject to automated scaling limits to prevent abuse or to help with capacity planning. Email the address in the error message if you run into such a limit and it’s getting in your way. All organizations (except for Linked Organizations) require a [credit card](https://docs.fly.io/about/billing#payment-options) on file.

## 

[​

](https://docs.fly.io/about/pricing#compute)

Compute

We charge for started and stopped Machines differently. For more details about how costs are calculated, see [Machine billing](https://docs.fly.io/about/billing#machine-billing). To understand the difference between `performance` and `shared` CPU types in Machines, see [CPU performance](https://docs.fly.io/machines/cpu-performance).

### 

[​

](https://docs.fly.io/about/pricing#started-fly-machines)

Started Fly Machines

Region:

The price of a running [Fly Machine](https://docs.fly.io/machines) VM is the price of a named CPU/RAM preset, plus about $6 per 30 days per GB of additional RAM.

Here’s the pricing for named presets and a few standard additional RAM configurations:

| Preset | CPU(s) | RAM | Price/second | Price/hour | Price/month |
| --- | --- | --- | --- | --- | --- |
| shared-cpu-1x | 1 shared | 256MB | $0.00000085 | $0.0030 | $2.19 |
| 512MB | $0.00000143 | $0.0051 | $3.69 |
| 1GB | $0.00000258 | $0.0093 | $6.70 |
| 2GB | $0.00000490 | $0.0176 | $12.70 |
| shared-cpu-2x | 2 shared | 512MB | $0.00000169 | $0.0061 | $4.39 |
| 1GB | $0.00000285 | $0.0103 | $7.39 |
| 2GB | $0.00000517 | $0.0186 | $13.39 |
| 4GB | $0.00000980 | $0.0353 | $25.40 |
| shared-cpu-4x | 4 shared | 1GB | $0.00000339 | $0.0122 | $8.78 |
| 2GB | $0.00000570 | $0.0205 | $14.78 |
| 4GB | $0.00001033 | $0.0372 | $26.79 |
| 8GB | $0.00001960 | $0.0706 | $50.80 |
| shared-cpu-6x | 6 shared | 1.5GB | $0.00000508 | $0.0183 | $13.16 |
| 3GB | $0.00000855 | $0.0308 | $22.17 |
| 6GB | $0.00001550 | $0.0558 | $40.18 |
| 12GB | $0.00002940 | $0.1058 | $76.20 |
| shared-cpu-8x | 8 shared | 2GB | $0.00000677 | $0.0244 | $17.55 |
| 4GB | $0.00001140 | $0.0411 | $29.56 |
| 8GB | $0.00002067 | $0.0744 | $53.57 |
| 16GB | $0.00003920 | $0.1411 | $101.60 |
| performance-1x | 1 performance | 2GB | $0.00001273 | $0.0458 | $33.00 |
| 4GB | $0.00001736 | $0.0625 | $45.01 |
| 8GB | $0.00002663 | $0.0959 | $69.02 |
| performance-2x | 2 performance | 4GB | $0.00002546 | $0.0917 | $66.00 |
| 8GB | $0.00003473 | $0.1250 | $90.01 |
| 16GB | $0.00005326 | $0.1917 | $138.04 |
| performance-4x | 4 performance | 8GB | $0.00005093 | $0.1833 | $132.01 |
| 16GB | $0.00006946 | $0.2500 | $180.03 |
| 32GB | $0.00010651 | $0.3834 | $276.08 |
| performance-6x | 6 performance | 12GB | $0.00007639 | $0.2750 | $198.01 |
| 24GB | $0.00010418 | $0.3751 | $270.04 |
| 48GB | $0.00015977 | $0.5752 | $414.12 |
| performance-8x | 8 performance | 16GB | $0.00010186 | $0.3667 | $264.01 |
| 32GB | $0.00013891 | $0.5001 | $360.06 |
| 64GB | $0.00021302 | $0.7669 | $552.16 |
| performance-10x | 10 performance | 20GB | $0.00012732 | $0.4584 | $330.01 |
| 40GB | $0.00017364 | $0.6251 | $450.07 |
| 80GB | $0.00026628 | $0.9586 | $690.20 |
| performance-12x | 12 performance | 24GB | $0.00015278 | $0.5500 | $396.02 |
| 48GB | $0.00020837 | $0.7501 | $540.09 |
| 96GB | $0.00031954 | $1.1503 | $828.24 |
| performance-14x | 14 performance | 28GB | $0.00017825 | $0.6417 | $462.02 |
| 56GB | $0.00024310 | $0.8751 | $630.10 |
| 112GB | $0.00037279 | $1.3421 | $966.28 |
| performance-16x | 16 performance | 32GB | $0.00020371 | $0.7334 | $528.02 |
| 64GB | $0.00027782 | $1.0002 | $720.12 |
| 128GB | $0.00042605 | $1.5338 | $1,104.32 |

### 

[​

](https://docs.fly.io/about/pricing#stopped-fly-machines)

Stopped Fly Machines

For stopped Machines we charge only for the root file system (rootfs) needed for each Machine. Each 1GB of rootfs for a Machine stopped for 30 days is $0.15. The amount of rootfs needed is defined by your OCI image generated on your app plus a few [containerd](https://containerd.io/) tweaks on the underlying file system.

### 

[​

](https://docs.fly.io/about/pricing#machine-reservation-blocks)

Machine reservation blocks

You’ll get a 40% discount when you reserve a block of compute time, either for `performance` Machines or `shared` Machines, in a specific region. Reservations apply to any number of Machines of the specified CPU class, in the specified region, in any of your organisation’s apps. The available reservation sizes are: **Performance Machines**

-   $144/year for $20/month of usage
-   $1,440/year for $200/month of usage
-   $14,400/year for $2,000/month of usage

**Shared Machines**

-   $36/year for $5/month of usage
-   $360/year for $50/month of usage
-   $3,600/year for $500/month of usage

You pay the “per year” amount upfront, and each month receive a credit worth the “per month” amount. The credit does not rollover; it’s only valid for the month in which it’s granted. The credit applies only to CPU and additional RAM charges. There’s no limit on the number or combinations of blocks that can be purchased. Reservations are backdated to the first day of the month in which they’re purchased. For example, if you purchase a $36/year `shared` Machines block in `cdg`, you’ll pay $36 upfront and receive $5/month of credits applicable to `shared` Machines in `cdg` for 12 months, starting with the month of the purchase. Amortised over 12 months, the $36 upfront cost is $3/month, which is a 40% discount on the $5/month of credits you receive. You can set up reservations via self-service in the billing section of your Fly.io [dashboard](https://fly.io/dashboard). They apply to usage starting on the 1st, so setting up reservations any time in the month will give you the credits the entire month.

## 

[​

](https://docs.fly.io/about/pricing#managed-postgres)

Managed Postgres

The price of running Fly.io Managed Postgres depends on your selected Managed Postgres Plan and the amount of storage your databases use. Current pricing for Managed Postgres plans and storage is available [here](https://docs.fly.io/postgres#pricing).

**Important:** Managed Postgres lives outside your apps. Deleting an app won’t delete its database. Have a look in your Dashboard when you’re cleaning up. A quick check can save you a surprise charge later.

## 

[​

](https://docs.fly.io/about/pricing#persistent-storage-volumes)

Persistent Storage Volumes

### 

[​

](https://docs.fly.io/about/pricing#volumes)

Volumes

[Fly Volumes](https://docs.fly.io/volumes) are local persistent storage for Machines.

-   $0.15/GB per month of provisioned capacity

[Volume billing](https://docs.fly.io/about/billing#volume-billing) is pro-rated to the hour. You’ll be charged for volumes that you create, whether they are attached to a Machine or not, including when an attached Machine is stopped.

### 

[​

](https://docs.fly.io/about/pricing#volume-snapshots)

Volume Snapshots

**New charges**

Starting January 1st 2026, we’re introducing charges for [volume snapshot](https://docs.fly.io/volumes/snapshots) storage. You’ll see the first charges on the invoice issued at the start of February 2026.

If you’re an existing customer, you can check your usage in the **Billing** section of the [dashboard](https://fly.io/dashboard/personal/billing) on your Upcoming Invoice and in the Cost Explorer.

-   $0.08/GB per month
-   First 10GB free each month

[Volume Snapshot billing](https://docs.fly.io/about/billing#volume-snapshot-billing) is pro-rated to the hour. Automatic daily snapshots with 5 days retention are enabled by default on new volumes. This can be [adjusted](https://docs.fly.io/volumes/snapshots#set-or-change-the-snapshot-retention-period) or [disabled](https://docs.fly.io/volumes/snapshots#disable-automatic-daily-snapshots). Usage is calculated based on the total stored size of the snapshots, not the provisioned volume size. You’re only charged for the actual data stored - if you’ve written 1GB to a 10GB volume, you’ll be charged for around 1GB of snapshot storage. Snapshots for each volume are stored incrementally, so you’ll only be charged for data that has changed since the previously stored snapshot.

## 

[​

](https://docs.fly.io/about/pricing#network-prices)

Network prices

### 

[​

](https://docs.fly.io/about/pricing#anycast-ip-addresses)

Anycast IP addresses

Each application receives a [shared IPv4 address](https://docs.fly.io/networking/services#shared-ipv4) and unlimited [Anycast IPv6](https://docs.fly.io/networking/services#ipv6) addresses for global load balancing. Dedicated IPv4 addresses are $2/mo.

### 

[​

](https://docs.fly.io/about/pricing#managed-ssl-certificates)

Managed SSL certificates

We use Let’s Encrypt to issue certificates, and donate half of our SSL fees to them at the end of each calendar year.

-   Single hostname certificates: $0.10/mo
-   Wildcard certificates: $1/mo

Every organization’s first 10 single hostname certificates are free.

### 

[​

](https://docs.fly.io/about/pricing#data-transfer-pricing)

Data transfer pricing

We bill for data leaving your app destined for the public internet or for apps or Machines in other regions, including:

-   Data egress to the Internet, from Machine to edge server to Internet
-   Data transfer over private network between regions, from Machine to edge server and edge server to Machine
-   Data transfer to some extensions like Upstash Redis

The following types of traffic are free:

-   All inbound data transfer
-   Data transfer between apps or Machines in the same region (for organizations using granular data transfer rates)
-   Data transfer from apps without an assigned IP address (for organizations not using granular data transfer rates)

Fly.io pricing is per region group for outbound data transfer. You’ll see a more detailed breakdown of cost per region and per traffic type on your monthly invoice.

**Important:** Organizations created after July 18 2024 are automatically opted-in to use the granular data transfer rates and are billed at a different rate for private network data transfer between regions, per the following table. Organizations not using granular data transfer rates are billed for all data transfer (excluding that listed as free above) at the “Egress to public internet” rate.

| Region groups | Egress to public internet cost | Private network cross-region transfer cost |
| --- | --- | --- |
| \- North America  
\- Europe | $0.02 per GB | $0.006 per GB |
| \- Asia Pacific  
\- Oceania  
\- South America | $0.04 per GB | $0.015 per GB |
| \- Africa  
\- India | $0.12 per GB | $0.050 per GB |

To opt-in to granular bandwidth pricing, go to the [**Organizations** page](https://fly.io/organizations) in the dashboard, click the organization name to change, then click **Switch to granular bandwidth pricing**. You won’t be able to return to using the non-granular data transfer rates once you opt in.

### 

[​

](https://docs.fly.io/about/pricing#static-egress-ips-for-machines)

Static Egress IPs for Machines

Static egress IPs for Machines provide dedicated outbound IP addresses for your Machines. When you allocate a static egress IP, you’ll get both an IPv4 and IPv6 address for this single price.

-   $0.005 per hour (~$3.60/month)
-   Machines do not have a static IP by default

## 

[​

](https://docs.fly.io/about/pricing#support)

Support

[Community support](https://community.fly.io/) is included for all customers, regardless of usage level. You can get access to a support plan by purchasing a Standard ($29/month), Premium ($199/month), or Enterprise (starting at $2500/month) package in the **Support** section of your dashboard. For more about Support, see [Support at Fly.io](https://docs.fly.io/about/support).

## 

[​

](https://docs.fly.io/about/pricing#fly-kubernetes)

Fly Kubernetes

[Fly Kubernetes](https://docs.fly.io/kubernetes) (FKS) is a managed Kubernetes service that runs on Fly.io.

-   $75/month per cluster
-   Plus the cost of [compute](https://docs.fly.io/about/pricing#compute) and [Fly volumes](https://docs.fly.io/about/pricing#persistent-storage-volumes) that you create

## 

[​

](https://docs.fly.io/about/pricing#extensions)

Extensions

Fly.io offers managed services operated by third parties, such as [Tigris Object Storage](https://docs.fly.io/tigris) and [Upstash Redis](https://docs.fly.io/upstash/redis). When you provision their services, you become their customer, and you pay their list prices via your monthly Fly.io bill. Charges are updated daily in your Fly.io dashboard. You will not be billed separately for:

-   Machines running the services, which are hosted in the provider’s account
-   IP addresses associated with the service

You **will** be billed separately for data transfer to these external third-party services, including Tigris Object Storage. See our [data transfer pricing](https://docs.fly.io/about/pricing#data-transfer-pricing) for details.

## 

[​

](https://docs.fly.io/about/pricing#unsupported-products)

Unsupported Products

### 

[​

](https://docs.fly.io/about/pricing#unmanaged-fly-postgres-unsupported)

Unmanaged Fly Postgres (Unsupported)

[Fly Postgres](https://docs.fly.io/unmanaged-postgres) is a PostgreSQL database that you create and then manage yourself. Fly Postgres clusters are Fly Apps that consist of Machines, volumes, and any configured extra memory. The [Machine price](https://docs.fly.io/about/pricing#compute) and [volume price](https://docs.fly.io/about/pricing#persistent-storage-volumes) for Fly Postgres are the same as any other Machine and volume you’d run on Fly.io. Assuming the Machines are running all the time, the cost for the preset configurations is about $2/month for a single node cluster for dev projects and from about $82 to $164/month for a three-node production cluster. You don’t need to keep the preset configurations, you can [scale your Fly Postgres Machines](https://docs.fly.io/unmanaged-postgres/managing/scaling) to suit your workload at any time.

## 

[​

](https://docs.fly.io/about/pricing#legacy-plans)

Legacy plans

On a legacy plan and wondering what that includes? Read more about [Discontinued Plans](https://docs.fly.io/about/discontinued-plans).

## 

[​

](https://docs.fly.io/about/pricing#related-reading)

**Related reading**

-   [Billing for Fly.io](https://docs.fly.io/about/billing) How invoicing, payment methods, and usage tracking work.
-   [Cost Management](https://docs.fly.io/about/cost-management) Best practices for estimating, monitoring, and controlling your spend.
-   [Free Trial](https://docs.fly.io/about/free-trial) What the Fly.io Free trial gives you and when billing begins.
-   [Organization Roles & Permissions](https://docs.fly.io/security/org-roles-permissions) How org structure, permissions and billing interplay.
-   [Optimize Compute Costs: Fine‑tune your app](https://docs.fly.io/apps/fine-tune-apps) Tuning machine size, memory/CPU, and stop‑/start behavior to reduce waste.

[Previous](https://docs.fly.io/about/discontinued-plans)[

Fly.io Billing

Next

](https://docs.fly.io/about/billing)

⌘I

## 

-   [Everything we bill for](https://docs.fly.io/about/pricing#everything-we-bill-for)
-   [What does a typical app cost?](https://docs.fly.io/about/pricing#what-does-a-typical-app-cost)
    -   [A small web app with Managed Postgres](https://docs.fly.io/about/pricing#a-small-web-app-with-managed-postgres)
    -   [A Discord bot or background worker running 24/7](https://docs.fly.io/about/pricing#a-discord-bot-or-background-worker-running-24%2F7)
    -   [An app running in three regions](https://docs.fly.io/about/pricing#an-app-running-in-three-regions)
-   [Is there a free tier?](https://docs.fly.io/about/pricing#is-there-a-free-tier)
-   [How it works](https://docs.fly.io/about/pricing#how-it-works)
-   [Compute](https://docs.fly.io/about/pricing#compute)
    -   [Started Fly Machines](https://docs.fly.io/about/pricing#started-fly-machines)
    -   [Stopped Fly Machines](https://docs.fly.io/about/pricing#stopped-fly-machines)
    -   [Machine reservation blocks](https://docs.fly.io/about/pricing#machine-reservation-blocks)
-   [Managed Postgres](https://docs.fly.io/about/pricing#managed-postgres)
-   [Persistent Storage Volumes](https://docs.fly.io/about/pricing#persistent-storage-volumes)
    -   [Volumes](https://docs.fly.io/about/pricing#volumes)
    -   [Volume Snapshots](https://docs.fly.io/about/pricing#volume-snapshots)
-   [Network prices](https://docs.fly.io/about/pricing#network-prices)
    -   [Anycast IP addresses](https://docs.fly.io/about/pricing#anycast-ip-addresses)
    -   [Managed SSL certificates](https://docs.fly.io/about/pricing#managed-ssl-certificates)
    -   [Data transfer pricing](https://docs.fly.io/about/pricing#data-transfer-pricing)
    -   [Static Egress IPs for Machines](https://docs.fly.io/about/pricing#static-egress-ips-for-machines)
-   [Support](https://docs.fly.io/about/pricing#support)
-   [Fly Kubernetes](https://docs.fly.io/about/pricing#fly-kubernetes)
-   [Extensions](https://docs.fly.io/about/pricing#extensions)
-   [Unsupported Products](https://docs.fly.io/about/pricing#unsupported-products)
    -   [Unmanaged Fly Postgres (Unsupported)](https://docs.fly.io/about/pricing#unmanaged-fly-postgres-unsupported)
-   [Legacy plans](https://docs.fly.io/about/pricing#legacy-plans)
-   [Related reading](https://docs.fly.io/about/pricing#related-reading)

Assistant

Responses are generated using AI and may contain mistakes.

[Log In](https://fly.io/app/sign-in/)[Sign Up](https://fly.io/app/sign-up/?s=docs)

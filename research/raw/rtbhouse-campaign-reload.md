# Rethinking Campaign Reload: How We Moved One of the Bidder's Most Important Flows to a Dedicated Service - Techblog

<https://techblog.rtbhouse.com/rethinking-campaign-reload/>

-   [Careers](https://rtbhouse.com/careers-offers?department=it_rnd)
-   [GitHub](https://github.com/RTBHOUSE)
-   [RSS](https://techblog.rtbhouse.com/feed/)
-   [RTB House](https://rtbhouse.com/)
-   [Blog](https://blog.rtbhouse.com/)
-   [About Us](https://techblog.rtbhouse.com/about-us/)

* * *

-   [Home](https://techblog.rtbhouse.com/)
-   [Machine Learning](https://techblog.rtbhouse.com/category/machine-learning/)
-   [Backend](https://techblog.rtbhouse.com/category/backend/)
-   [Frontend](https://techblog.rtbhouse.com/category/frontend/)
-   [DevOps](https://techblog.rtbhouse.com/category/devops/)
-   [Networking](https://techblog.rtbhouse.com/category/networking/)

[Backend](https://techblog.rtbhouse.com/category/backend/)

# Rethinking Campaign Reload: How We Moved One of the Bidder’s Most Important Flows to a Dedicated Service

[Ewa Pałka  
Software Engineer](https://techblog.rtbhouse.com/author/ewa_palka/)July 27, 2026

-   
-   
-   

Share Share

Last Updated on: **31st July 2026, 12:37 pm**

At RTB House, our bidding service processes tens of billions of bid requests every day. Each bid request is a real-time auction for a single ad slot shown to a single internet user: within double-digit milliseconds, we must decide whether to buy that slot and, if so, how much to pay for it. The service that answers these auctions is the bidder — one of the most latency-critical systems we run, as described in a [previous post on our microservices migration](https://techblog.rtbhouse.com/breaking-down-the-bidding-service-monolith-into-microservices/).  
To make a good decision, the bidder needs an up-to-date, in-memory view of all active campaigns. A campaign is a coordinated set of ads through which one of our clients aims to reach potential customers; each carries targeting rules — the conditions defining which users we want to show its ads to — along with dozens of other attributes the bidding logic consults on every request. This in-memory representation is built and refreshed by the campaign reload process: it runs asynchronously in the background, outside the bid evaluation itself, but directly determines the quality and freshness of every bid decision.

## The Problem: Every Bidder Doing the Same Expensive Work

For a bidder to function, it needs an up-to-date, in-memory representation of all active campaigns: their state, targeting rules, pause periods, and dozens of additional attributes used by the bidding logic. These structures are pre-computed and shaped for microsecond access on the hot path, which is precisely what makes building them expensive. Historically, each bidder instance was responsible for loading this data directly from our PostgreSQL database and building all the in-memory structures itself, all while continuing to serve bid requests throughout the process. We call this the _in-process_ reload.

At first glance this sounds straightforward, but at scale it becomes a serious problem.

Our bidding infrastructure runs thousands of bidder instances spread across multiple data centers. Each data center operates as an autonomous unit: it runs its own fleet of bidder instances, handles its own slice of global bid traffic independently, and maintains its own in-memory view of the campaigns active for that DC. This isolation keeps the hot path fast and resilient – but it also means that every data center must independently solve the same problem: keeping all its bidder instances supplied with fresh campaign data. The SLO we set ourselves applies within each data center independently.

RTB House runs its bidding infrastructure on-premises, on a fleet of physical machines grown incrementally over time. Older hardware remains in service as long as it is cost-effective, which means the fleet spans a wide range of hardware generations and capabilities. In this setup, every single bidder was independently querying the database and performing the same computationally expensive transformation of campaign configuration into bidding-ready structures. On a well-provisioned machine, this reload took on the order of 15 minutes – but on a slower or more loaded machine it could stretch to 30–40 minutes or more. With hundreds of bidders in a DC, the overwhelming majority might already hold fresh data while a handful of slow machines lagged behind — and in a distributed system this kind of divergence is expected, but the real problem was the lack of any predictable upper bound on how long it could last, with no guarantee of when the stragglers would catch up. Tracing unexpected behavior to a few lagging machines was tedious and far from obvious.

With thousands of bidders reloading independently, the cumulative load on PostgreSQL was substantial: preventing a self-inflicted DDoS required careful tuning and jittered reload schedules across the fleet. And because every bidder hit the database directly, any attempt to make the reload algorithm more efficient would have required scaling database replicas first – the infrastructure pressure was a ceiling on what we could even attempt.

For the time being, this was something we could manage operationally – the lack of a strict propagation SLO had not yet caused problems we could not absorb. But we were not comfortable leaving it that way. A ceiling of 40 minutes is not stable: left unaddressed, it tends to become 50, then 60, as traffic grows and the fleet expands. We wanted to get ahead of that curve. We set ourselves an ambitious goal: all bidders in a DC should reflect any configuration change within 20 minutes – measurable, controllable, and for the first time, something we could actually commit to.

## **The Design: One Snapshot Per Code Version**

The core insight behind our solution was simple: if a thousand bidder instances are all performing the same reload from the same database, why not do it once and share the result?

We introduced a dedicated job – the Snapshot Builder – responsible for loading campaign data from the database and building all the in-memory structures needed for bidding. The result is serialized with Kryo and compressed with GZIP – reducing snapshot size and therefore the network traffic by 5x – and then written to our S3-compatible object storage as a versioned blob-snapshot. Bidder instances no longer compute anything themselves; they simply fetch the latest snapshot and atomically swap it into their in-memory state within seconds.

A key architectural constraint shaped the design: every build of the bidder also produces a corresponding build of the Snapshot Builder, versioned by the same commit hash. Each snapshot is keyed by both commit hash and a timestamp. Bidders already register their commit hash in Zookeeper as part of their heartbeat and that the Scheduler builds on to discover which versions are actively in use. This means a bidder running a given code version will only ever load a snapshot built by the exact same version of the construction logic. Maintaining backward compatibility across versions isn’t straightforward – the structures encode both data schema and semantic assumptions baked in by the bidding logic. A change to how the bidder evaluates campaigns, including changes to targeting logic, can alter both the shape and the meaning of the serialized data. Supporting multiple bidder versions off a single snapshot would have required enforcing a lowest-common-denominator structure across all active versions: only additive changes, no semantic shifts, constrained canary testing. We could have built that, but it felt like solving the wrong problem. Making each version self-contained and keyed to its own commit hash guarantees correctness by construction, and removes the constraint entirely.

One tradeoff worth acknowledging: because every active code version gets its own snapshot built continuously, we may generate more snapshots than strictly necessary at any given moment. In practice, this is not a concern; the compute cost of running a Snapshot Builder job is low, and the simplicity gained far outweighs the overhead.

Once bidders were pulling from the object storage instead of querying the database, we needed to avoid thousands of instances hitting S3 simultaneously. The reload scheduler in the bidder runs every five minutes with a random initial delay within that interval, and the bidder treats snapshots younger than a certain age as “fresh enough” – it will not reload if the data it already holds is sufficiently recent. Together, these two mechanisms spread object storage reads naturally across time without explicit coordination, while still ensuring the SLO is met.

## **Design Principles: Eliminating Single Points of Failure**

Designing a reload path for a system processing tens of billions of bids per day means that no component in that path can be a single point of failure. This guided every architectural decision we made.

### **The Scheduler: Leadership Without SPOF**

We now had a job that could generate snapshots – but we also needed a component to orchestrate when and for which code versions to run: deciding which commit hash versions are actively in use and ensuring snapshots are continuously built for all of them. This is more dynamic than it might appear: during a rolling deployment we typically have at least two active code versions simultaneously, and we make heavy use of canary deployments to validate incoming changes, adding further versions to the mix. We needed an orchestrator capable of tracking this shifting landscape, but we didn’t want a single centralized controller that could become a SPOF.

The Snapshot Scheduler is responsible for tracking which code versions are currently active across the fleet and ensuring snapshots are continuously built for all of them. It reads bidder heartbeats from Zookeeper, where bidders already publish their commit hash, to maintain a live view of active versions, then periodically publishes build tasks for each to a Kafka topic.

We run multiple scheduler instances per data center to avoid a single point of failure. For coordination, we initially considered Zookeeper – but using it as a task queue means continuous node creation and deletion at scale, which is an antipattern that degrades cluster stability. Kafka was the natural fit: it is a foundational part of our infrastructure, and its consumer group mechanics handle both task distribution and leader election cleanly. The leader is simply the instance assigned to partition 0; if it fails, Kafka’s consumer group rebalancing automatically promotes another instance. No custom election protocol needed.

All scheduler instances, including the leader, consume tasks from their assigned partitions and spawn the appropriate Snapshot Builder container via Docker. The Snapshot Builder is deliberately short-lived: it loads campaigns from the database, serializes the result to the object storage and exits. The scheduler decides when to build; the builder is responsible only for a single, atomic execution – which also simplifies failure handling.

### **No Reliance on Docker Registry Availability**

The Snapshot Builder runs as a Docker container started by the scheduler. Pulling that container image requires a reachable Docker Registry – but at RTB House, the registry is operated primarily as a deployment-time tool, used by developers to push and pull images during releases. It is not designed or maintained for the kind of sustained, high-frequency availability that continuous snapshot generation demands. By relying on it at runtime, we would have introduced a new SPOF into a path that we had specifically designed to have none.

We implemented a three-level image cache on each scheduler machine. Before spawning a build, the scheduler checks whether the image is already loaded in the local Docker daemon; if not, it looks for a saved tar on disk and loads it into the daemon; only if neither is available does it pull from the registry – and after pulling, it saves the image to disk for future runs. This means that once a version has been built at least once, the registry is no longer consulted for that version. Even if the registry becomes unavailable, snapshot generation for all cached versions continues without interruption.

## **The Migration: Zero Downtime on a Critical Path**

Changing the reload path for a system processing billions of bids per day is not something you do with a big-bang move during a maintenance window. We needed to migrate with no downtime and no degradation in bid quality.

We implemented a gradual rollout via DC configuration fetched by all bidders every minute, supporting three modes simultaneously: 

-   **InProcess** – the original path, unchanged, for safety during the rollout.
-   **SnapshotWithFallback** – bidders fetch from the object storage but fall back to in-process if no snapshot is found or an exception is thrown.
-   **SnapshotOnly** – the target state: bidders exclusively use the object storage snapshots, with no fallback path to in-process.

A key constraint shaped our rollout strategy from the start: everything had to work from master, with no branch deployments; in a fast-moving codebase, a long-lived branch quickly becomes a maintenance burden. 

We implemented a rollout mechanism that allowed selecting bidders either by name or by a hash-based percentage bucket. The percentage was evaluated deterministically using MurmurHash of each bidder’s hostname rather than randomly at runtime – making the enrolled set stable across config reloads. Using a hash also avoided hardware clustering: bidders with sequential names are often colocated on identical hardware. A naive sequential percentage – say, the first 10% by name – could silently enroll only high-performance machines, leaving slower or more constrained ones untested until a much later stage of the rollout. The hash spread enrollment across the full diversity of the fleet from the start, regardless of naming patterns.

We rolled out mode by mode, DC by DC, running the new and old paths in parallel and monitoring extensively. The comparative tests proved their worth early: one find was a Kryo serialization bug where objects allocated bypassing constructors left final fields in Guava collections as null after deserialization – silently, until the first access threw a NullPointerException. A separate issue came from the deployment side: per-DC jobs resolved master branch multiple times during execution, so a commit landing mid-deploy could leave the Bidder and SnapshotBuilder built from different hashes – breaking the version-coupling guarantee the entire design relied on. Both were caught and fixed before reaching full rollout. Throughout the entire migration, bidder availability was maintained at 100%.

We also ran statistical comparative tests on production data to surface any discrepancies that metrics alone would miss. We added a field to our bid logs – already sampled events at one per thousand bid requests and stored in BigQuery – marking whether the campaigns data came from a snapshot or the in-process path. This let us run queries comparing bidding behavior between the two groups: for example, how frequently a given campaign was filtered out by targeting rules in each group. Severe outliers would indicate a bug; in practice, every discrepancy we found traced back to the timing of configuration changes landing during the rollout window, not to any correctness issue in the new path. When the fleet was split 50/50 between the two modes, the two groups were statistically indistinguishable.

## **Results and What This Unlocked**

The reload SLO is now under 20 minutes across all data centers – down from an average of 20–40 minutes with unpredictable tail behavior tied to individual machine performance. More importantly, it is predictable and uniform: every bidder in a DC is guaranteed to hold data no older than the SLO, regardless of hardware. An Account Manager changing campaign configuration, or observing that a campaign has stopped receiving bids after it was paused, can be confident that within the SLO, all bidders in a DC will reflect that state – not just a majority of them.

Bidder startup time improved by roughly 30–40% at the median and p95: the expensive in-process computation no longer happens at startup, replaced by a snapshot fetch. At peak load, the in-process reload was consuming up to 1% of CPU per bidder – on the weakest machines, a non-trivial tax on capacity that is now entirely gone.

We also gained operational leverage: the snapshot build process is now independently observable and measurable, with metrics for snapshot age, build duration, object storage read latency, and per-instance reload status all exported to Prometheus and visualized in Grafana.

This architecture opens the door to optimizations that were previously out of reach. The build process can now be tuned independently of the bidder: the SLO can be tightened, and as the number of active campaigns grows, the Snapshot Builder can be scaled or optimized without touching bidder availability.

It is also worth noting that campaign data was the heaviest in-process reload in the bidder, but not the only one. The patterns and infrastructure established here provide a natural blueprint for migrating other data sources in the future, and the explicit boundaries this work forced us to draw are already paying dividends in the projects that followed.

-   
-      
-   

Comments are closed.

#### More in [Backend](https://techblog.rtbhouse.com/category/backend/)

[Backend](https://techblog.rtbhouse.com/category/backend/)

### [Breaking Down the Bidding Service Monolith into Microservices](https://techblog.rtbhouse.com/breaking-down-the-bidding-service-monolith-into-microservices/)

Discover how RTB House scaled to 25M requests/sec with gRPC microservices and smart ...

[Read more](https://techblog.rtbhouse.com/breaking-down-the-bidding-service-monolith-into-microservices/)

[Backend](https://techblog.rtbhouse.com/category/backend/)[DevOps](https://techblog.rtbhouse.com/category/devops/)

### [Transitioning to Capacity-Based Pricing in Google BigQuery](https://techblog.rtbhouse.com/transitioning-to-capacity-based-pricing-in-google-bigquery/)

Discover how migrating from on-demand to capacity-based BigQuery pricing helped us cut costs ...

[Read more](https://techblog.rtbhouse.com/transitioning-to-capacity-based-pricing-in-google-bigquery/)

[Backend](https://techblog.rtbhouse.com/category/backend/)

### [Near Real-Time Document Categorization with Apache Solr and RTB House Percolator Plugin](https://techblog.rtbhouse.com/near-real-time-document-categorization-with-apache-solr-and-rtb-house-percolator-plugin/)

Streamlining Website Categorization with Apache Solr and RTB House Tools

[Read more](https://techblog.rtbhouse.com/near-real-time-document-categorization-with-apache-solr-and-rtb-house-percolator-plugin/)

© by RTB House 2024  
[Privacy Policy](https://techblog.rtbhouse.com/privacy-policy/)   [Cookies](https://blog.rtbhouse.com/cookie-management//)

-   [Careers](https://rtbhouse.com/careers-offers?department=it_rnd)
-   [GitHub](https://github.com/RTBHOUSE)
-   [RSS](https://techblog.rtbhouse.com/feed/)
-   [RTB House](https://rtbhouse.com/)
-   [Blog](https://blog.rtbhouse.com/)
-   [About Us](https://techblog.rtbhouse.com/about-us/)

-   
-      
-   
-   

  

-   [Home](https://techblog.rtbhouse.com/)
-   [Machine Learning](https://techblog.rtbhouse.com/category/machine-learning/)
-   [Backend](https://techblog.rtbhouse.com/category/backend/)
-   [Frontend](https://techblog.rtbhouse.com/category/frontend/)
-   [DevOps](https://techblog.rtbhouse.com/category/devops/)
-   [Networking](https://techblog.rtbhouse.com/category/networking/)

##    

-   
-   
-   
-   

[

✕ Close

](https://techblog.rtbhouse.com/rethinking-campaign-reload/#atbssuga-offcanvas-primary)

-   [Home](https://techblog.rtbhouse.com/)
-   [Machine Learning](https://techblog.rtbhouse.com/category/machine-learning/)
-   [Backend](https://techblog.rtbhouse.com/category/backend/)
-   [Frontend](https://techblog.rtbhouse.com/category/frontend/)
-   [DevOps](https://techblog.rtbhouse.com/category/devops/)
-   [Networking](https://techblog.rtbhouse.com/category/networking/)

## Latest Posts

### [Rethinking Campaign Reload: How We Moved One of the Bidder’s Most Important Flows to a Dedicated Service](https://techblog.rtbhouse.com/rethinking-campaign-reload/)

### [How RTB House Connects Servers Using BGP Unnumbered: A Real-World Implementation](https://techblog.rtbhouse.com/how-rtb-house-connects-servers-using-bgp-unnumbered-a-real-world-implementation/)

### [Breaking Down the Bidding Service Monolith into Microservices](https://techblog.rtbhouse.com/breaking-down-the-bidding-service-monolith-into-microservices/)

## Popular Tags

## Popular Search

-   [cookies](https://techblog.rtbhouse.com/search/cookies/)
-   [3rd party cookies](https://techblog.rtbhouse.com/search/3rd+party+cookies/)
-   [retargeting](https://techblog.rtbhouse.com/search/retargeting/)

-   [Home](https://techblog.rtbhouse.com/)
-   [Machine Learning](https://techblog.rtbhouse.com/category/machine-learning/)
-   [Backend](https://techblog.rtbhouse.com/category/backend/)
-   [Frontend](https://techblog.rtbhouse.com/category/frontend/)
-   [DevOps](https://techblog.rtbhouse.com/category/devops/)
-   [Networking](https://techblog.rtbhouse.com/category/networking/)

* * *

-   [Careers](https://rtbhouse.com/careers-offers?department=it_rnd)
-   [GitHub](https://github.com/RTBHOUSE)
-   [RSS](https://techblog.rtbhouse.com/feed/)
-   [RTB House](https://rtbhouse.com/)
-   [Blog](https://blog.rtbhouse.com/)
-   [About Us](https://techblog.rtbhouse.com/about-us/)

Search

We use cookies to personalise content and ads, to provide social media features as well as to manage the webiste and analyse our traffic. We also may share this information with our social media and analytics partners who may combine it with other information that you’ve provided to them or that they’ve collected from your use of their services.

Preference cookies enable a website to remember information that changes the way the website behaves or looks, like your preferred language or the region that you are in.

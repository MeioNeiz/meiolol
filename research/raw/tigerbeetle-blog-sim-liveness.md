# Simulation Testing For Liveness

<https://tigerbeetle.com/blog/2023-07-06-simulation-testing-for-liveness/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# Simulation Testing For Liveness

Jul 6, 2023

-   [
    
    matklad
    
    ](https://matklad.github.io/)

This month we introduced a significant change to TigerBeetle’s simulator, the [VOPR](https://github.com/tigerbeetle/tigerbeetle/blob/37b33a2a926db6ab88c14db9ec5bca95828339a1/src/vopr.zig). We split the simulator into two modes: “safety” mode and a new “liveness” mode.

What’s the difference between these two modes? Up to now, the simulator worked by injecting faults uniformly. That is, on every tick it rolled a dice and, with some probability, crashed a healthy replica, restarted a downed replica, dropped a packet from the network, or corrupted read or write disk I/O.

This is great for checking safety properties. That is, that TigerBeetle preserves strict serializability in the face of network, process, and storage faults that would challenge many systems. However, this mode does not check all _liveness_ properties–that the cluster remains available if the operating environment is sufficiently healthy.

## [An Example](https://tigerbeetle.com/blog/2023-07-06-simulation-testing-for-liveness/#an-example)

Consider a case where in a cluster of three replicas {A, B, C}, replica A is _asymmetrically_ partitioned from B and C. That is, A can send messages, but can’t receive messages.

Since A can’t hear from the primary, after some time it decides that it might be a good idea to start a view change. If, at this point, A broadcasts a _DoViewChange_ message, and B and C follow along and start a view change, then the cluster gets into a livelock—A also can’t hear from any other replica, so it will continue to trigger further view changes, preventing the cluster from getting into a normal status and processing transactions.

The “safety” mode of the simulator wouldn’t have discovered this issue. With some probability, it might have created an asymmetric partition to separate A from B and C. However, this partition would not have been permanent—at some point it would heal and the vicious view change cycle would be broken (and undetected). Similarly, in safety mode, the simulator is guaranteed to restart each replica eventually, so that it might not notice a problem where a replica gets stuck until reboot.

We fixed this particular asymmetric partition bug awhile back, but we were unsatisfied that we had relied on the good old “many eyes make bugs shallow” to discover the issue. We wanted to teach the VOPR to discover these kinds of bugs automatically, and that’s exactly what we did by introducing “liveness” mode.

## [Teaching The VOPR](https://tigerbeetle.com/blog/2023-07-06-simulation-testing-for-liveness/#teaching-the-vopr)

We wanted to guarantee the following property: if there’s a quorum of replicas available, then the cluster as a whole remains available, _regardless_ of the behavior of the other replicas. Other replicas might be up, down, or partitioned, but they shouldn’t be able to interfere with the cluster’s core.

To test this, a cluster starts in safety mode (which can probabilistically create any specific cluster state), and then, after a time of fault injection, we [switch to liveness mode](https://github.com/tigerbeetle/tigerbeetle/blob/9ff5f4a470ed6d66b4be535e689c39eee9f24993/src/simulator.zig#L418) by:

-   picking a quorum of replicas to be fully available (the core),
-   restarting any core replicas which are down at that moment,
-   healing all network partitions between core replicas,
-   and, for all failures involving non-core replicas, making those failures permanent.

This last bit is the secret sauce and the crux of the idea. If a replica is permanently crashed, it will never contribute to cluster recovery, but the cluster as a whole is still required to continue.

After switching to liveness mode, we run the cluster for some time, and check that replicas from the core were able to process all of the transactions (it’s ok if some non-core replicas are lagging behind, as long as they don’t prevent the core from progressing).

This setup can now simulate permanent asymmetric partitions.

To recap:

-   we start in safety mode, where we crash replicas and mess with the network and disk completely at random, all the while checking strict serializability,
-   then, we select the set of core replicas,
-   and heal all the failures within the core, simultaneously freezing all the failures elsewhere, and
-   we run the simulation and expect the core to converge.

Was it worth it? Did liveness mode find new bugs? Yes, it did!

## [Resonance!](https://tigerbeetle.com/blog/2023-07-06-simulation-testing-for-liveness/#resonance)

The most fun was a [resonance bug between our repair algorithm](https://github.com/tigerbeetle/tigerbeetle/pull/934), and our network load balancing.

Repair is the process of restoring missing log entries, which were lost by a replica due to storage faults (or never received in the first place due to network faults). Our repair is fairly aggressive—rather than repairing log entries one-by-one, a replica tries to repair as many missing entries as it can without saturating I/O.

A repairing replica must ask another replica to retransmit the log entry in question. As we want to be mindful of network bandwidth, we do not direct all repair queries at the primary, and we try to spread the load across the cluster. Specifically, this was implemented through round-robin. A replica would maintain a counter, and, at each repair attempt, it would send a request to the replica identified by `repair_counter % replica_count` and increment the counter.

What liveness mode demonstrated is that the combination of these two ideas, repairing many log entries in parallel, and round-robining repair requests, was dangerous. Specifically, the VOPR was able to maneuver the cluster into a situation where replica A was missing op=5 and op=6, replica B was missing op=5 (but had op=6) and replica C was missing op=6 (but had op=5).

So, replica A was trying to repair two records, and, as it perfectly alternated between B and C as targets for the repair request, it always directed a request for op=5 to B and for op=6 to C, exactly in the most unfortunate way!

Without liveness mode, this would eventually resolve, and go undetected, when replica A is restarted and the retry counter is reset.

However, with our new liveness mode, the situation continues indefinitely, and the simulation fails ([and reports the liveness bug](https://github.com/tigerbeetle/tigerbeetle/issues/913)) when, after a timeout, a replica is still missing some log entries.

That’s all for today! Hungry for more? Check out these two papers which were a major inspiration for the work:

-   [Fault-tolerant computing with unreliable channels](https://arxiv.org/pdf/2305.15150)
-   [Swarm testing](https://users.cs.utah.edu/~regehr/papers/swarm12.pdf)

MORE POSTS

[

## Random Fuzzy Thoughts

matklad · Mar 28, 2023

](https://tigerbeetle.com/blog/2023-03-28-random-fuzzy-thoughts)

-   [View All Posts](https://tigerbeetle.com/blog)
-   [**RSS**](https://tigerbeetle.com/blog/atom.xml)

 

### Product

[

Cloud

](https://tigerbeetle.com/cloud)[

Pricing

](https://tigerbeetle.com/cloud#pricing)[

Stories

](https://tigerbeetle.com/stories)

### Developers

[

Docs

](https://docs.tigerbeetle.com/)[

GitHub

](https://github.com/tigerbeetle/tigerbeetle)[

Tutorials

](https://github.com/tigerbeetle/tigerlings)[

Releases

](https://github.com/tigerbeetle/tigerbeetle/releases)[

Jepsen

](https://jepsen.io/analyses/tigerbeetle-0.16.11)[

Blog

](https://tigerbeetle.com/blog)

### Connect

[

X

](https://x.com/TigerBeetleDB)[

LinkedIn

](https://www.linkedin.com/company/tigerbeetle/)[

YouTube

](https://www.youtube.com/@tigerbeetledb)[

Email

](mailto:hello@tigerbeetle.com)

### Company

[

About

](https://tigerbeetle.com/company)[

Privacy

](https://tigerbeetle.com/privacy)

### Newsletter

Get monthly highlights and carefully crafted updates.

[Subscribe](https://tigerbeetle.com/newsletter)[

Past Newsletters →

](https://tigerbeetle.com/newsletters)

Correct and Fast

Copyright © 2026 TigerBeetle, Inc. All Rights Reserved.

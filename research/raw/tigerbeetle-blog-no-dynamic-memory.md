# A Database Without Dynamic Memory Allocation

<https://tigerbeetle.com/blog/2022-10-12-a-database-without-dynamic-memory/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# A Database Without Dynamic Memory Allocation

Oct 12, 2022

-   [
    
    Phil Eaton
    
    ](https://x.com/eatonphil)

Some folks who read [TIGER\_STYLE.md](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md) (the [TigerBeetle](https://github.com/tigerbeetle/tigerbeetle) coding guide) are surprised to learn that TigerBeetle allocates no memory after startup.

## [Static and dynamically allocated memory](https://tigerbeetle.com/blog/2022-10-12-a-database-without-dynamic-memory/#static-and-dynamically-allocated-memory)

Let’s recap memory allocation in general. In most languages, you can choose to have fixed size objects and arrays at program start. Or, you can modify the object and array sizes during the run of the program, maybe to add new keys to the object or maybe to grow the array to fit more elements.

For example if, in JavaScript, you create an empty array and push items into it, the array may allocate and reallocate behind the scenes to fit new entries. This is dynamic memory allocation.

Or, in JavaScript, you could initialize an array with a fixed size and never change that size. Only placing elements at indices within the capacity of the array. This is static memory allocation.

TigerBeetle is written in [Zig](https://ziglang.org/). And like JavaScript, you can choose to use data structures that dynamically allocate memory (along the lines of JavaScript’s arrays) or you can choose to only statically allocate memory. TigerBeetle does the latter.

But one nice part of Zig’s standard library is that its data structures are designed to be static allocation friendly. For example, TigerBeetle use’s Zig’s [ArrayList](https://ziglang.org/documentation/0.9.1/std/#root;ArrayList) and [HashMap](https://ziglang.org/documentation/0.9.1/std/#root;HashMap) but with fixed sizes. Methods like [ArrayList.addOneAssumeCapacity](https://github.com/ziglang/zig/blob/0b47e69b7c0aedbc142400305cda86ef58b41656/lib/std/array_list.zig#L171-L177) and [HashMap.putAssumeCapacityNoClobber](https://github.com/ziglang/zig/blob/master/lib/std/hash_map.zig#L556-L561) help catch bugs where we would accidentally allocate more memory.

## [What we gain from this](https://tigerbeetle.com/blog/2022-10-12-a-database-without-dynamic-memory/#what-we-gain-from-this)

You might guess we do this to avoid both garbage collection and most use-after-free bugs. Those are good reasons, but there are a few more!

Static memory allocation allows us to easily [handle overload](https://sre.google/sre-book/handling-overload/). With fixed sizes of objects and arrays, there is no ever-growing buffer when an incorrectly-configured client tries to make too many connections or send too many messages at once.

This makes TigerBeetle more predictable for operators. Like cgroups in your database.

And there are a few more angles that are worth exploring but deserve their own blog posts to fully flesh out:

-   Calculating exactly how much of a resource you will need means less chance of resource deadlocks and liveness issues in production.
-   Reducing the amount of memory used means fewer cache lines fetched from main memory in general, reducing thrashing of the CPU’s cache hierarchy and improving cache hits for optimal performance.

## [But how is this possible?](https://tigerbeetle.com/blog/2022-10-12-a-database-without-dynamic-memory/#but-how-is-this-possible)

Basically, TigerBeetle works with fixed amounts of everything:

-   Number of connections
-   Concurrent messages per connection
-   Maximum number of replicas in the cluster
-   Size of messages
-   Queries per message (queries are always batched)
-   And so on

The total memory needed is simply calculated with a bit of addition and multiplication at startup. (Currently it’s determined even before startup, at compile-time, but startup is the important point since that is the first time that memory can be allocated.)

For example, [here](https://github.com/tigerbeetle/tigerbeetle/blob/b8b0562db0b890fb6e6ce123c33f3bdfb659a9fd/src/message_pool.zig#L20-L57) is how we calculate the amount of memory needed to store messages for TigerBeetle’s consensus protocol (even across all combinations of concurrent interactions and protocol permutations):

```
/// The number of full-sized messages allocated at initialization by the replica message pool.
/// There must be enough messages to ensure that the replica can always progress, to avoid deadlock.
pub const messages_max_replica = messages_max: {
    var sum: usize = 0;

    sum += config.io_depth_read + config.io_depth_write; // Journal I/O
    sum += config.clients_max; // Replica.client_table
    sum += 1; // Replica.loopback_queue
    sum += config.pipeline_max; // Replica.pipeline
    sum += 1; // Replica.commit_prepare
    // Replica.do_view_change_from_all_replicas quorum:
    // Replica.recovery_response_quorum is only used for recovery and does not increase the limit.
    // All other quorums are bitsets.
    sum += config.replicas_max;
    sum += config.connections_max; // Connection.recv_message
    sum += config.connections_max * config.connection_send_queue_max_replica; // Connection.send_queue
    sum += 1; // Handle bursts (e.g. Connection.parse_message)
    // Handle Replica.commit_op's reply:
    // (This is separate from the burst +1 because they may occur concurrently).
    sum += 1;
    sum += 20; // TODO Our network simulator allows up to 20 messages for path_capacity_max.

    break :messages_max sum;
};

/// The number of full-sized messages allocated at initialization by the client message pool.
pub const messages_max_client = messages_max: {
    var sum: usize = 0;

    sum += config.replicas_max; // Connection.recv_message
    sum += config.replicas_max * config.connection_send_queue_max_client; // Connection.send_queue
    sum += config.client_request_queue_max; // Client.request_queue
    // Handle bursts (e.g. Connection.parse_message, or sending a ping when the send queue is full).
    sum += 1;
    sum += 20; // TODO Our network simulator allows up to 20 messages for path_capacity_max.

    break :messages_max sum;
};
```

> And if we get the calculation wrong? Well, since we enforce static allocation, we can check these calculations with assertions (i.e. that a free message is always available). If we then get the static allocation calculation wrong, this can be surfaced sooner through fuzzing, rather than having no limits and eventual resource exhaustion (and cascading failure!) in production. When combined with assertions, static allocation is a force multiplier for fuzzing!

This is just one example where memory is allocated in TigerBeetle. But like this example, all allocations occur only once at startup. With a simple calculation.

Doing this was possible because we sketched out all resource usage (network, disk, memory, CPU) in the design phase with back-of-the-envelope calculations.

## [More concretely](https://tigerbeetle.com/blog/2022-10-12-a-database-without-dynamic-memory/#more-concretely)

But “fixed amounts of everything” might still sound unclear. So let’s look at a couple points in a bit more detail.

TigerBeetle only allows a maximum of N client connections at once. This might sound restrictive, but it is no different than [MySQL](https://dev.mysql.com/doc/refman/8.0/en/too-many-connections.html) or [PostgreSQL](https://postgresqlco.nf/doc/en/param/max_connections/). When more than N connections are made at once, TigerBeetle drops connections.

Also, TigerBeetle has exactly two data types: accounts and transfers. Accounts and transfers are fixed-size and cache line aligned. [Both](https://github.com/tigerbeetle/tigerbeetle/blob/27f70fcaa5cf9fc52f80cb17665e6432bb274ca2/src/tigerbeetle.zig#L24) types are [128 bytes](https://github.com/tigerbeetle/tigerbeetle/blob/27f70fcaa5cf9fc52f80cb17665e6432bb274ca2/src/tigerbeetle.zig#L79) ([we’re looking at you M1!](https://news.ycombinator.com/item?id=25659615)).

[Inspired by Cap’n Proto](https://capnproto.org/news/2014-06-17-capnproto-flatbuffers-sbe.html), there is no serialization or deserialization in TigerBeetle. Clients write the bytes of the account or transfer struct over the wire. TigerBeetle casts the bytes back into the account or transfer struct when it reads the message from the client. Zero-copy. Messages contain a checksum to detect random bit flips. And further validation is done by the business logic.

Clients can only have one message in flight at a time. Each message has a maximum number of queries (the default maximum is 8191 queries per message, leaving space for the 128 byte header). The client must wait for a response to the last message before sending another. This batching of queries to the database, aside from static memory allocation, means high throughput and bounded latency.

## [Storage](https://tigerbeetle.com/blog/2022-10-12-a-database-without-dynamic-memory/#storage)

Now you get the gist: that static allocation of memory is easy with a fixed maximum number of connections and fixed-size messages and so on.

There’s still the problem of storage. As you add transfers and accounts to TigerBeetle, the memory used increases, right?

Well, static allocation is about what is in memory. TigerBeetle is a database, so long-term storage is not in memory. The dynamic part of the database is what’s stored on disk.

TigerBeetle implements its own [LSM tree](https://blog.acolyer.org/2014/11/26/the-log-structured-merge-tree-lsm-tree/) system for storage (in fact, around 30 trees all integrated into an [LSM forest](https://www.youtube.com/watch?v=yBBpUMR8dHw) for some interesting optimizations). And like all LSM trees there’s a portion in memory and a portion on disk. The in-memory portion is, you guessed it, allocated on startup. And small, incremental flushes to disk keep the in-memory portion perfectly bounded.

The details get more complex, but the rule about static memory allocation does not change.

## [Where to now?](https://tigerbeetle.com/blog/2022-10-12-a-database-without-dynamic-memory/#where-to-now)

Building a system that allocates memory once up-front requires up-front thinking. For many developers (like myself) it is a big adjustment. But as we’ve found: you spend just a few weeks thinking through the memory you need, and it pays off massively over time.

If you like to build toy databases, try statically allocating memory in your next project! And if you want to see it in action in TigerBeetle, [download the database](https://docs.tigerbeetle.com/) (note: it’s still pre-production!) and give it a go!

MORE POSTS

[

## Three Clocks are Better than One

Joran Dirk Greef · Aug 30, 2021

](https://tigerbeetle.com/blog/2021-08-30-three-clocks-are-better-than-one)

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

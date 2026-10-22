# A Tale Of Four Fuzzers

<https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# A Tale Of Four Fuzzers

Nov 28, 2025

-   [
    
    matklad
    
    ](https://matklad.github.io/)

> Charles Darnay observed that the gate was held by a mixed guard of soldiers and patriots, the latter far outnumbering the former; and that while ingress into the city for peasants’ carts bringing in supplies, and for similar traffic and traffickers, was easy enough, egress, even for the homeliest people, was very difficult.  
> — [Complaining about egress fees goes back to at least the French Revolution.](https://standardebooks.org/ebooks/charles-dickens/a-tale-of-two-cities)

Some time ago we [overhauled TigerBeetle’s routing algorithm](https://github.com/tigerbeetle/tigerbeetle/pull/2880) to better handle varying network topologies in a cluster. That turned out to be an interesting case study of practical generative testing (or fuzzing) for non-trivial, real-world code. We ended up adding not one, not even two, but four very different new fuzzers to the system! Let’s talk about why just one fuzzer is not enough.

This is a good moment to brew some tea, the journey will take us awhile!

## [Replication](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#replication)

Although this post isn’t primarily about the new algorithm itself, we’ll start by covering the basics of replication. TigerBeetle provides transaction Atomicity, Consistency, Isolation and Durability (ACID). Out of the four letters, the D, Durability, is the most consequential. For, without Durability, there wouldn’t be any data at all to provide guarantees for!

You can get a decent chunk of durability by writing the data to a (single) hard drive. This works for many non-critical applications, but might still fail if you repeat the procedure often enough. Disks are faulty with non-zero probability, and it is fairly common to lose an entire machine (floods, fires and tripping over the power supply happen). If you _really_ want your data to be durable, better to store several copies of it on different machines, to replicate.

All data in TigerBeetle is ultimately derived from an append-only hash-chained log of prepare messages, so the task of replication reduces to distributing the prepares (a MiB each) across the six replicas of the cluster.

The primary sends `.prepare` messages down to the backups; they reply `.prepare_ok` back up once the prepare is locally durable. When the primary receives a quorum of `.prepare_ok`s, it knows that the message is globally durable.

The most straightforward way to implement that is for the primary to broadcast the prepare:

Star Topology

The problem with this approach is that the primary uses 5x the bandwidth of the backup. In other words, we are going only at 1/5th of the optimal performance. For this reason, our V1 routing used a simple ring topology, where most replicas need to send and receive one message:

Ring Topology

## [Adaptive Replication Routing](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#adaptive-replication-routing)

The ring replication is simple and balances the bandwidth nicely. It served well for the first year of production use, despite some critical issues!

_First_, the fixed ring topology falls prey to one of the [eight fallacies of distributed computing](https://en.wikipedia.org/wiki/Fallacies_of_distributed_computing). The ring is fully static, and assumes that network topology doesn’t change. But this is not true. For example, if one replica crashes or becomes partitioned, it is a good idea to proactively route around it, rather than rely on retries to randomly pick a different replica.

_Second_, the ring doesn’t have what I like to call “there’s no (re)try” property. Most messages exchanged in the process of ring replication are _critical_: if a single message is lost, then the whole chain of replication unravels until the retry timeout kicks in. This means that network errors are visible as elevated P100 latencies (bad), and, when they happen, we have to run rarely-executed retry code (worse!). Such “cold code” is the preferred habitat for bugs! Ideally, a system should have built-in redundancy such that any operation completes without tripping timeouts even in the presence of errors.

Thus, Adaptive Replication Routing (or, how we affectionately call it, ARR) was born. It combines two ideas. _First_, while we keep the ring as our replication topology, we place the primary into the middle:

ARR Topology

The small downside is slightly uneven network load, as the primary sends two messages. The big upside is that none of the messages are critical. If any single message is dropped, the prepare is still going to be replicated to at least half of the cluster, allowing the primary to commit without tripping timeouts (recall that TigerBeetle is using [Heidi Howard’s Flexible Quorums](https://arxiv.org/pdf/1608.06696v1.pdf), so 3 of 6 as replication quorum is enough for safety because the view change quorum, is 4 of 6, preserving the intersection property).

_The second trick_ is that the ring itself is dynamic. At runtime, the cluster picks the order of replicas that minimizes the latency overall. If one replica becomes unreachable, the replicas are reshuffled along the ring to move the missing one to the very end.

## [Picking the Route](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#picking-the-route)

How do you find the best route? One approach is to build a model of the system. For example, replicas can exchange heartbeat messages, note pairwise latencies, and then solve traveling salesman problem in the resulting small six-node graph to find the most perfect route.

This works algorithmically, but relies on a pretty big assumption — that our model of the world is faithful. But imagine, for example, a network with a link with very low latency, but also very low throughput. Using (small) heartbeat messages to measure the link quality would give us a misleading model that breaks down for (much larger) prepares.

The problem here isn’t this particular case, but the entire class of “out of the distribution” errors which make any _indirect_ measurement suspect (c.f. [Goodhart’s Law](https://en.wikipedia.org/wiki/Goodhart%27s_law)). As another example, consider a replica with a very slow disk. Although the `ping` time for it is very fast, the replication is going to be slow, as `.prepare_ok` is only sent once the `.prepare` is durably persistent. Pings only measure network latency, but we also care about storage latency (and throughput).

A different approach, inspired laterally by the [PCC](https://www.usenix.org/system/files/conference/nsdi15/nsdi15-paper-dong.pdf) paper, is to avoid modeling altogether, and instead to just go and _do_ something, and then measure the relevant result directly, Grace Hopper style. This is how ARR works: for every `.prepare`, the primary tracks how long did it take to replicate (via tracking `.prepare_ok` messages). Every once in a while, it runs an experiment, where a prepare follows a different, experimental route. If that experimental route is _measured_ to be better than the route we are currently using, the topology is switched. Over time, the cluster converges to the optimal route.

That’s ARR in a nutshell: replication topology is a ring with the primary in the middle, where the order of replicas in the ring is adjusted dynamically based on how well each specific permutation performs end-to-end.

## [It’s All About Interfaces](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#its-all-about-interfaces)

As promised, this post is _not_ about ARR, so assume that you’ve already implemented ARR for TigerBeetle. How would you apply Deterministic Simulation Testing principles to it?

One approach is to leverage our existing ~[game](https://sim.tigerbeetle.com/)~ whole-system simulation, VOPR. This actually gets you quite far, but it is always possible to do better.

_First_, whole system simulation might not be as efficient at exercising deeper layers of the system. For every permutation of events affecting the target layer, the simulator also needs to handle all other events above and below. Furthermore, the permutations you get might be restricted by the way the subsystem is used by the larger system. In other words, the routing component might be working correctly if used in the exact same way as in the real database, but it might still have bugs under certain interactions of its public APIs.

_Second_, while checking “it doesn’t crash” is easy enough through the VOPR, asserting that the route is _good_ is much harder. Again, there’s just too much _other_ stuff happening to focus just on the contribution of routing.

That’s why the general principle in TigerBeetle is that, in addition to the main whole-system fuzzer, each subsystem should also have a targeted fuzzer, and ARR is no exception.

There’s a fairly general recipe for how to fuzz a subsystem in isolation:

-   Identify all the connections between the target and the rest of the system,
-   abstract the connections behind an interface,
-   supply a stub implementation for fuzzing.

With some ingenuity, you can even avoid modifying your source code at all, instead leveraging runtime support to materialize interfaces out of thin air. For example, you can use `LD_PRELOAD` tricks to intercept all libc-mediated syscalls.

But there’s a catch! With a large and intricate interface, it might be challenging to thoroughly explore the state space, especially as the interface itself changes over time (and large and intricate things also mysteriously _love_ to be high-churn as well). For the long term, it pays to start with the minimal possible interface.

Did you notice that I tricked you in the first paragraph in this section? You don’t first build a system, and then add a fuzzer. The process is almost the reverse — the starting point is sketching minimal interfaces that yield themselves to efficient fuzzing. This is a bit like Test Driven Design, though, not exactly. There’s relatively little incrementality and iteration. Instead, fuzzer’s input on architecture is felt at the very beginning, during “sketching on the mental napkin” phase.

## [ARR Interface](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#arr-interface)

Let’s do this for ARR. Again, the idea is that we observe timing information during replication (the delay between sending `.prepare` and receiving a set of `.prepare_ok`s) and use that to gradually discover the best possible route, where the route is a permutation of replicas with the current primary in the middle.

Note how _little_ in the above description is related to TigerBeetle! This is a hint that the routing component _can_ be fully independent! This is the core interface of `Routing` (simplified for the blog, but just a touch):

```
pub fn init(
    options: struct { replica: u8, replica_count: u8 },
) Routing;

pub fn op_prepare(
    routing: *Routing, op: u64, now: Instant) void;

pub fn op_prepare_ok(
    routing: *Routing, op: u64, now: Instant, replica: u8) void;

pub fn op_next_hop(routing: *Routing, op: u64) []const u8;

pub fn view_change(routing: *Routing, view: u32) void;
```

To start routing, you need to know how many replicas are there, and which one is you. `op_prepare` and `op_prepare_ok` are for tracking timing. The contract is simple: `op_prepare` is called once a `.prepare` is ready to be replicated, and `op_prepare_ok` is called for every received `.prepare_ok` response. That is, the happy path is six calls to `op_prepare_ok` for every call to `op_prepare`.

The `op_next_hop` is the actual routing — it tells which replicas a freshly received prepare needs to be forwarded to. It might return zero, one or two replicas.

Finally, routing needs to know which replica is the primary. When the primary changes, so do the routes! The primary is uniquely defined by the view, which can be changed via the `view_change` method.

Note how minimal this interface is! We are just passing integers around (`Instant` is a newtyped `u64`. It’s a topic for a separate blog post why we newtype `Instant` but not `view`…). But this is not natural, it’s a result of deliberate design process!

For example, `Routing` routes `Prepare`s, so it would be natural to pass in the whole `Prepare` structure with all dependencies on the rest of the VSR framework. It takes [intellectual control](https://www.computer.org/csdl/magazine/so/2019/01/08611447/17D45WaTkcK) to know that `Routing` only cares about `Prepare`’s identity, and that op number is a concise representation of that identity.

Handling of time deserves an entire separate article (good thing that we _did_ [write that up](https://tigerbeetle.com/blog/2025-10-21-clockless-time/)). The source of time is ultimately a `Clock` instance, so the most natural thing to do would be to inject `Clock` dependency in the constructor. But a moment’s thinking makes you realize that a fully general clock is unnecessary. We only care about the time difference between a `.prepare` and the corresponding `.prepare_ok`s, which you can get, simply, by accepting an `Instant` — a `u64` number of nanoseconds since an unspecified start of the epoch. This is a _major_ simplification for fuzzing, as time is notoriously tricky to model, and here we get it essentially for free.

Finally, in order to downsize the interface, `view_change` violates one of the best best practices. It adds the second source of truth for the view number! The authority about the current view is the `Replica` struct ([this lovely 12k sloc file](https://github.com/tigerbeetle/tigerbeetle/blob/0.16.66/src/vsr/replica.zig#L387)) with a `view: u32` field.

`Routing` needs to be aware of the view, and the most straightforward way to do that is to inject the entire `Replica` in `init`, using banana-gorilla-jungle pattern of Joe Armstrong. The textbook fix would be to abstract “thing with a `get_view` method” behind an interface and inject _that_. But that indirection makes the code more verbose and harder to reason about. It also is not enough: not only `Routing` needs to know the current view, it must actively react to changes in the view! This can be fixed via Observer pattern, but Observer is notorious for destroying readability of control flow and bring a host of problems of its own, including complicated lifetime management, non-deterministic order of execution and potential for feedback loops.

It indeed is _much_ simpler to just let `Routing` have its own private copy of `view: u32`. And the risk of views desynchronizing is easy to mitigate. We already have `invariants` method on the `Replica` which is called frequently to catch various violations, and it can check view consistency as well:

```
pub fn invariants(self: *const Replica) void {
    // ...
    assert(self.view == self.routing.view);
}
```

You get the idea! The trick to making the code more easily fuzzable is to minimize the interface. You want to get rid of accidental dependencies and leave only the essential ones. And to do that, it helps to apply data-oriented design principles — thinking in terms of input data, output data, and the fundamental data transformation that the system implements.

## [Fuzzer #1: Exhausting Positive Space](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#fuzzer-1-exhausting-positive-space)

When the primary decides to switch the route after a successful experiment, it needs to communicate the new route to the peers. It’s a serialization/deserialization task. As there are at most six replicas in the cluster, and a route is a permutation thereof, a route is encoded compactly as an `u64`:

```
pub fn route_encode(routing: *const Routing, route: Route) u64;
pub fn route_decode(routing: *const Routing, code: u64) ?Route;

pub fn route_active(self: *const Replica) Route;
pub fn route_activate(routing: *Routing, route: Route) void;
```

Serialization is a favorite vehicle for explaining property based testing: checking that serializing data and then deserializing it back doesn’t lose a bit is an obvious thing to do (`deserialize . serialize == id`, if you speak pointfree). So we can generate a random permutation and assert that it round-trips the encoding correctly:

```
test route_encode {
    var prng = stdx.PRNG.from_seed(std.testing.random_seed);
    const replica_count =
        prng.range_inclusive(u8, 1, constants.replicas_max);

    // Start with a trivial permutation, then shuffle it.
    var route: Route = .trivial(replica_count);
    prng.shuffle(u8, &route.replicas);

    const code = route_encode(route);
    const route_decoded = route_decode(code).?;

    assert(std.meta.eql(route, route_decoded));
}
```

And here’s `shuffle` for the reference, nothing fancy:

```
pub fn shuffle(prng: *PRNG, T: type, slice: []T) void {
    if (slice.len <= 1) return;

    for (0..slice.len - 1) |i| {
        const j = prng.range_inclusive(u64, i, slice.len - 1);
        std.mem.swap(T, &slice[i], &slice[j]);
    }
}
```

This already is a decent test, but we can make it even better. There are at most six replicas in a cluster. That means there are `1! + 2! + ... + 6!` routes in _total_ we need to check. This is a tiny number of routes, computer-wise, and we can easily check them all in no time!

The only catch is that writing code to generate all permutations needs somewhat tricky recursion, and then you need to also iterate over number of replicas… But there’s a secret cheat code here. This is it:

> If you wrote a function that takes a PRNG and generates a random object, you _already_ have a function capable of enumerating all objects.

Just imagine how the above function executes, from the perspective of the PRNG. You are constantly being asked to generate random numbers, which are used to shuffle the initial identity permutation. But what if you always return zero? Well, the resulting permutation will be in some sense trivial! And you can get the _next_ permutation if you change the last zero to be one. And then two. And, if, say, the last number you are asked to generate needs to lie between zero and two, then after two you wrap back to zero, but also increment the penultimate number:

```
0 0 0 0 0
0 0 0 0 1
0 0 0 0 2
0 0 0 1 0
0 0 0 1 1
```

If you can generate all sequences of random numbers, you can turn a function generating a random object into a function enumerating _all_ objects! And here’s how you can generate all random number sequences:

```
started: bool = false,
v: [32]struct { value: u32, bound: u32 } = undefined,
p: usize = 0,
p_max: usize = 0,

const Gen = @This();

pub fn done(g: *@This()) bool {
    if (!g.started) {
        g.started = true;
        return false;
    }
    var i = g.p_max;
    while (i > 0) {
        i -= 1;
        if (g.v[i].value < g.v[i].bound) {
            g.v[i].value += 1;
            g.p_max = i + 1;
            g.p = 0;
            return false;
        }
    }
    return true;
}

fn gen(g: *Gen, bound: u32) u32 {
    assert(g.p < g.v.len);
    if (g.p == g.p_max) {
        g.v[g.p] = .{ .value = 0, .bound = 0 };
        g.p_max += 1;
    }
    g.p += 1;
    g.v[g.p - 1].bound = bound;
    return g.v[g.p - 1].value;
}

/// Public API, get a "random" number in bounds:
pub fn int_inclusive(g: *Gen, Int: type, bound: Int) Int {
    return @intCast(g.gen(@intCast(bound)));
}
```

Makes no sense? For me too! Every time I look at this code, I need to solve the puzzle afresh. Luckily, there’s a write up: [_Generate All The Things_](https://matklad.github.io/2021/11/07/generate-all-the-things.html).

The bottom line is that we can _just_ wrap our existing random test into a while loop, and magically get an exhaustive test for _all_ routes:

```
test route_encode {
    var prng: Gen = .{};
    while (!prng.done()) {
        const replica_count =
            prng.range_inclusive(u8, 1, constants.replicas_max);

        // Start with a trivial permutation, then shuffle it.
        var route: Route = .trivial(replica_count);
        prng.shuffle(u8, &route.replicas);

        const code = route_encode(route);
        const route_decoded = route_decode(code).?;

        assert(std.meta.eql(route, route_decoded));
    }
}
```

That’s it! Testing _every_ `replica_count`, and every permutation of replicas!

This is our first fuzzer — we test serialization by encoding and decoding a random route. We also notice that the total amount of routes is small, and adapt our random code to exhaustively cover the entire positive space, using a rigged PRNG.

## [Fuzzer #2: Exploring Negative Space](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#fuzzer-2-exploring-negative-space)

Testing _only_ positive space is a common pitfall. We want to check serialization and deserialization for routes. We do that by round-tripping the route. We even make sure to check _every_ possible route, how can there be anything else left to test here?

This is an example of a positive space thinking, which sometimes gives us false confidence that everything is thoroughly tested, while we are failing to consider some cases off the happy path.

What we missed here is that not every code necessarily encodes a valid route. We only feed “valid” data to deserialization routine, but who knows what bytes you can receive through the TCP socket?

Now, this is tricky: actually, TigerBeetle only talks to other TigerBeetle replicas, and all communication is protected by a strong checksum. So it is actually correct to assume that the encoding is valid, modulo bugs. But there _might_ be bugs! And, if there’s a bug somewhere which manifests itself as an invalid encoding, we want to detect that and crash loudly, rather than silently misinterpret valid data.

That’s why the decode function returns a nullable `Route`…

```
pub fn route_decode(routing: *const Routing, code: u64) ?Route;
```

but at the call-site the `Route` is unwrapped:

```
const route = self.routing.route_decode(message.header.route).?;
```

This is offensive programming, we want to force bugs to jump into the spotlight, and not to lie hidden on odd cold paths.

The most straightforward way to test the negative space here is to run our test backwards, and to try deserialize and then serialize a random code:

```
test route_decode {
    var prng = stdx.PRNG.from_seed(std.testing.random_seed);

    const code = prng.int(u64);
    if (route_decode(code)) |route| {
        const code_encoded = route_encode(route);
        assert(code == code_encoded);
    } else {
        // Just make sure we don't crash!
    }
}
```

There’s a subtle problem with a test above — the “then” branch of the if is dead code, and we’ll never get there, even if we repeat the test a hundred million times:

```
test route_decode {
    var prng = stdx.PRNG.from_seed(std.testing.random_seed);

    for (0..100_000_000) |_| {
        const code = prng.int(u64);
        if (route_decode(code)) |_| {
            assert(false);
        } else {
            // Just make sure we don't crash!
        }
    }
}
```

```
$ t ./zig/zig build test --release -- route_decode

real 7.14s
cpu  7.16s (7.08s user + 76.41ms sys)
rss  34.97mb
```

Our completely random encoding never manages to generate a valid code!

As we have seen above, there are very few different routes, and, therefore, very few valid encodings. But our code is `u64`. The space of all possible codes is huge, but the subspace of all _valid_ codes is very sparse.

Is this a problem? We checked all valid codes, so it’s fine if we only look at the invalid ones? No! Given just how rarefied our encoding space is, purely random codes are going to be _obviously_ invalid. The decoding routine will reject them very quickly, and we are likely to not exercise most of the logic there.

For effective fuzzing, you want to test the _boundary_: you want to check a valid code, and a code which is _almost_ the same, but invalid.

For that, we _bias_ our generator to prefer codes in the neighborhood of valid encodings:

```
var code_bytes: [8]u8 = @splat(0);
for (&code_bytes) |*byte| {
    byte.* = if (prng.chance(ratio(replica_count + 1, 8)))
        prng.int_inclusive(u8, constants.replicas_max + 1)
    else
        0xFF;
}
var code: u64 = @bitCast(code_bytes);

if (prng.chance(ratio(1, 20))) {
    code ^= prng.bit(u64);
}
if (prng.chance(ratio(1, 20))) {
    code = prng.int(u64);
}
```

The encoding is literally a permutation of replica indexes, where each replica index is a byte, padded by `0xFF` bytes to `u64`. We generate a random mish-mash of those bytes (which just _might_ generate a valid code), then, to spice thing up, we randomly corrupt a single bit of code. Finally, to make sure we don’t _just_ generate almost valid code, sometimes we throw everything away and fall back to fully random.

## [Non-Deterministic Aside](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#non-deterministic-aside)

This _sounds_ plausible, but is this actually true? Do we _actually_ hit the boundary here, generate both valid and invalid codes? And how do we make sure that our negative-space fuzzer continues to test interesting cases as the code itself evolves (it certainly looks like we can optimize the encoding to be more compact…)?

A good pattern here is to repeat the test many times, counting all the sad and happy cases, and assert that they are reasonable:

```
test route_decode {
    const Counts =
        struct { total: u32, valid: u32, invalid: u32 };

    var prng = stdx.PRNG.from_seed(std.testing.random_seed);

    var counts: Counts =
        .{ .total = 200_000, .valid = 0, .invalid = 0 };

    for (0..counts.total) |_| {
        //...
        if (route_decode(code)) |_| {
            counts.valid += 1;
            //...
        } else {
            counts.invalid += 1;
        }
    }

    assert(counts.total == counts.valid + counts.invalid);
    assert(counts.valid > 50);
    assert(counts.invalid > 100_000);
}
```

Due to randomness, we can’t check the exact values of counters, but we can assert that _most_ of the encodings are invalid, and that at least some are valid (remember, our initial test generated zero valid encodings out of 100 000 000 attempts).

This brings me to another topic I want to cover — treatment of determinism in tests. “Thy tests shall be deterministic” is a reasonable commandment, but not an absolute one. I see that often people try to avoid randomness in tests at all costs, and always initialize PRNG with a hard-coded seed of 42. I don’t like that, for two reasons.

_The practical reason_ is that, over its lifetime, the test is going to be re-run many thousand times over, and it is wasteful to _not_ take advantage of that to explore more of the state space eventually, while keeping each individual test run very fast.

_The purity reason_ is that, if there exists a seed value that makes the test fail, the test (or the code) is buggy and needs to be fixed! Sure, it’s unfortunate if you discover that bug while working on an unrelated change, but it is _less_ unfortunate than not knowing about the bug at all!

However, _just_ using genuinely random seeds for tests is pretty bad:

```
test route_decode {
    const seed = std.crypto.random.int(u64);
}
```

The problem with the above is that, when a test fails, you don’t know the seed! And, if it is one-in-a-million failure, it can be very a frustrating experience to reproduce it. This can be helped by printing the seed on failure, but _that_ A) requires writing more code per test and, B) doesn’t work if the failure is not graceful. Imagine getting a mystery segfault on some random CI run, and then not being able to reproduce it because the process dies before the seed is printed!

Zig I think has the best design in this space. It provides you with the `std.testing.random_seed` value, which is a ready-to-use random seed that is different per run. Crucially, the seed is generated outside of the test process itself and is passed to it on the CLI. It doesn’t matter what happens with the test process. It can explode completely, but the parent process will still print the seed on failure. Conveniently, the seed is printed as a part of a CLI invocation which you can immediately paste into your shell!

```
$ ./zig/zig build test

test
+- run test-vsr failure
thread 2285 panic: reached unreachable code
...
error: while executing test 'vsr.test.routing.route_decode'
error: the following command terminated with signal 6:

.zig-cache/o/14db484/test-vsr --seed=0x737929ed
```

So that’s why we’ve been using `PRNG.from_seed(testing.random_seed)` throughout! And it has been working perfectly, up until now. Here’s the problem:

```
var prng = stdx.PRNG.from_seed(std.testing.random_seed);

//...

assert(counts.total == counts.valid + counts.invalid);
assert(counts.valid > 50);
assert(counts.invalid > 100_000);
```

The seed _is_ random, so, sooner or later, our assert will fire. We can make the probability of that negligible by increasing `total` and increasing our tolerance, but that is unsatisfactory. Larger iteration count slows down each individual test run. And relaxing asserts tells us _less_ about the average case, what we actually care about. And we don’t know what’s the actual probability of hitting the assert! It might be that the actual probability is small, but not infinitesimal, such that you’ll be debugging a random “failure” five years from now! [One in a billion events do happen in CI!](https://github.com/tigerbeetle/tigerbeetle/issues/1876)

A nice pattern here is to run the test twice: once with a hard-coded seed to capture the “average” distribution and assert statistics, and once with a truly random seed for coverage:

```
test route_decode {
    const T = struct {
        const Counts =
            struct { total: u32, valid: u32, invalid: u32 };

        fn check(seed: u64) Counts {
            // ...
        }
    };

    const counts = T.check(92);
    assert(counts.total == counts.valid + counts.invalid);
    assert(counts.valid > 50);
    assert(counts.invalid > 100_000);

    _ = T.check(std.testing.random_seed);
}
```

This is our second fuzzer — testing for negative space by probing obviously invalid values, and then specifically values that cross the valid/invalid boundary, while collecting and asserting coverage information.

For this particular scenario, it would’ve been better to use a real coverage-guided fuzzer like libFuzzer, but, at the time of writing, Zig is only at the start of its fuzzing journey. It already has `std.testing.fuzz`, but I wasn’t able to get that working on my machine. Anyway the implementation of the fuzzer is a detail. What matters is the principle of explicit testing of negative space, the boundary space, and verifying that both ins and outs get tested!

Moreover, just like we got exhaustive test by driving PRNG interface via exhaustive enumeration from inside, we can drive a PRNG through a fuzzer. You can combine the best of both worlds: highly structured complex inputs of property based testing and introspective guided program state exploration of coverage-guided fuzzers. This again is worth a separate blog post, but I really need to do more research before it is ready.

## [Fuzzer #3: Qualitative Fuzzing](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#fuzzer-3-qualitative-fuzzing)

Ok, the warmup is over! Serialization was a simple and boring part of Adaptive Replication Routing. Let’s tackle the actual logic. Similarly, we’ll start with a positive space, checking that ARR indeed converges to the best route in a scenario approximating what we _expect_ to see in the real world.

This is going to be interesting, because it is not a _local_ correctness property. We want to check that six instances of ARR on six different physical machines work in concert, such that, e.g., everyone agrees which operations are experiments, and what is the route of each experiment.

Here’s the plan. We arrange six replicas into a virtual ring, such that the network delay between replicas is proportional to the distance along the ring. The order of replicas is random, and correctly implemented ARR must be able to “unscramble” the permutation in the end. Each “replica” is just a `Routing` instance. This is the entire idea behind ~The Matrix~ focused fuzzing, we don’t need to simulate anything else!

```
const T = struct {
    replica_count: u8,
    permutation: []u8,

    view: u32,
    primary: u8,
    prepare_ok_count: u8,

    replicas: []Routing,

    const T = @This();

    pub fn init(gpa: Allocator, seed: u64) T { ... }

    pub fn deinit(t: *T, gpa: Allocator) void { ... }

    fn ring_index(t: *const T, replica: u8) i8 {
        return @intCast(t.permutation[replica]);
    }

    fn distance(t: *const T, a: u8, b: u8) u8 {
        const a2b = @abs(t.ring_index(b) - t.ring_index(a));
        const b2a = t.replica_count - a2b;
        return @min(a2b, b2a);
    }
};
```

An optimal route enumerates replicas in the order of `permutation` in either of two directions (there are two optimal routes!). We can check that by summing up pairwise distances:

```
fn route_total_distance(t: *const T, route: Route) u8 {
    var result: u8 = 0;
    for (
        route.replicas[0 .. t.replica_count - 1],
        route.replicas[1..t.replica_count],
    ) |a, b| {
        result += t.distance(a, b);
    }
    return result;
}

fn route_optimal(t: *const T, route: Route) bool {
    return t.total_route_distance(route) == t.replica_count - 1;
}
```

The overall flow of the fuzzer is as follows. We send prepares one by one. For each prepare, we run the simulation until the primary collects `prepare_ok` messages from everybody. `prepare_ok_count` field tells us when we should start with the next prepare. Submitting a prepare is modeled via sending a message to the primary. When a set number of prepares is dealt with, we check that the final route is optimal.

Note that this is _not_ how the real replication works, reality is pipelined, and multiple prepares are in flight at the same time. However, the purpose of this particular fuzzer isn’t to check a “realistic” scenario, the purpose is to check the idealized scenario, but be very strict in the acceptance criteria (that the route really is optimal).

The full code is a bit too much for this article, but the core logic of simulating replication process is this `message_delivered` function. It models what happens when replica `target` receives a `message` from `source`. Which is, forward the message along the ring, and reply with `.prepare_ok` to the primary.

```
fn message_delivered(
    t: *T,
    source: u8,
    target: u8,
    message: union(enum) { prepare: u64, prepare_ok: u64 },
) void {
    switch (message) {
        .prepare => |op| {
            // The initial prepare is injected by the fuzzer.
            if (target == t.primary) {
                assert(source == t.primary);
                assert(t.prepare_ok_count == 0);
                t.replicas[t.primary].op_prepare(op, t.now());
            }

            // Inform the primary that we got the prepare.
            t.send(.{
                .source = target,
                .target = t.primary,
                .message = .{ .prepare_ok = op },
            });

            // Forward prepare along the current replication ring.
            for (t.replicas[target].op_next_hop(op)) |target_next| {
                assert(target_next < t.replica_count);
                t.send(.{
                    .source = target,
                    .target = target_next,
                    .message = .{ .prepare = op },
                });
            }
        },

        .prepare_ok => |op| {
            assert(target == t.primary);
            t.prepare_ok_count += 1;
            t.replicas[t.primary].op_prepare_ok(op, t.now(), source);
        },
    }
}
```

What’s fascinating about this fuzzer is not the implementation, but rather the bugs it was able to find. Writing the fuzzer was a relatively mechanical and mindless process, other than the initial idea of modeling a physical ring of replicas. But the two failures it found revealed my misunderstanding of the problem, and forced me to apply deeper thinking where I thought I understood everything.

To explain that, I need to talk about the ARR cost function. After an ARR experiment, the primary somehow needs to measure the quality of a the experimental route. The _data_ we have are `.prepare_ok` latencies for all replicas — a vector of six integers.

My initial cost function was a pair of the median and the maximum value of the vector, with some fuzz factor:

```
Cost.of(.{
    .ms(31), .ms(178), .ms(148),
    .ms(92), .ms(144), .ms(50),
}) ==
    .{ .median = .ms(92), .maximum = .ms(178) }
```

The median tracks the moment in time when a half of the cluster acknowledged the prepare, which, due to flexible quorums, is the moment where it is safe to commit prepare. The median replication time is a proxy for user-visible latency, and it is the primary number we are optimizing for.

After we replied to the user, we still want to replicate the prepare to the rest of the cluster, to maximize durability. The maximum replication time directly tracks full replication, and it’s the second most important metric to optimize.

Finally, we don’t want the cluster to oscillate between two nearly identical routes simply due to random delay noise, so we also add a fuzz factor and consider close enough numbers to be equal for comparison purposes.

Can you see the bug here? I didn’t, but the fuzzer I wrote did. After running for a short time, the fuzzer found the case where ARR failed to converge to the optimal path. Here’s the path that that run ended up with:

Not Quite Optimal Route

This is indeed an optimal path in terms of median,maximum cost function. The median is two hops, the maximum is three. But it is not _actually_ optimal, because replicas _between_ median and maximum take longer time to replicate, and we care about that as well, as that’s a proxy for us selecting the most efficient route for each replica. It doesn’t affect important latencies, but it still sends the electrons further away than they’d otherwise need to go.

The fix is easy — add a third component to the cost function, the sum of all latencies.

The problem was fixed, but, after a few iterations more, I got another example that failed to converge to an optimal route. It took me an embarrassingly long time to debug that, but the explanation was really simple. My fuzz factor was too fuzzy, and made two different routes look the same. This fix also was simple, just tighten up the “almost equal” condition.

But what bugged me is that, in my mental model, the old fuzz factor was fuzzy enough as is. So I tried to explain _why_ it didn’t work, and realized that I had a completely wrong mental image of replication routes. And, yes, _all_ the illustrations I’ve drawn so far also have this bug. Do you see it?

This is what the actual replication route looks like:

Replication With ACKs

Prepares flow forward along the ring, but acknowledgements always flow directly to the primary, in a star topology. When the primary measures the replication latency, it captures _both_ the time to send the `.prepare` forward and the time to get the corresponding `.prepare_ok` back. And the time to receive all `.prepare_ok` is independent of the route!

In other words, changing the route can affect only half of the observed latencies, which makes relative difference between the routes smaller, and justifies tighter tolerances.

This was a huge shift in the mental model for me! I didn’t realize that we only observe latencies through the glass, darkly! I hadn’t thought about that myself, but the fuzzer did!

This is our third fuzzer. It is a whole subsystem positive space fuzzer. It’s actually an exuberantly optimistic fuzzer, as it sets up an ideal lab environment with extremely predictable network latencies. While not realistic, this setup ensures that there’s a clear answer to the question of which route is the best, and that allows us to verify that the algorithm is exactly correct, and not merely crash free. This is the catch — in the real system with faults and variants, the notion of optimal route is ill-defined and constantly changes. The acceptance criteria has to be fuzzy in a realistic simulation, but can be very strict in the lab.

## [Fuzzer #4: Sweet Dreams (Manson’s Version)](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#fuzzer-4-sweet-dreams-mansons-version)

Finally, the fourth fuzzer. You might guess it, we’ll go for negative space this time. We no longer care about how the Routing _should_ be used by the replica, we are trying to break it.

The fundamental difference here is that, for positive space, we modeled all six “replicas” at the same time messages flowing between them. But any model of that sort necessarily restricts us to executions possible in the cluster. Now we won’t be trying to model anything in particular. We’ll have just a single instance of `Routing` and will be calling all public methods in random order, only obeying the documented invariants:

```
// Simulate the entire cluster:
const PositiveSpace = struct {
    replicas: []Routing,
    // ...
};

// Hammer a single replica, hard:
const NegativeSpace = struct {
    replica: Routing,
    // ...
};
```

There isn’t _much_ we can check here, but we can check _something_. At minimum, we should never crash. Additionally, we can check that whatever route we have, it “connects”. That is, if we follow the chain of `next_hop`s, we’ll visit each replica exactly once.

The code isn’t particularly illuminating here, but the overall shape looks similar to the technique described in the [_Swarm Testing Data Structures_](https://tigerbeetle.com/blog/2025-04-23-swarm-testing-data-structures/).

That’s it for today! This was a tale of four fuzzers!

## [Fuzzer #5: Can I Count? No.](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#fuzzer-5-can-i-count-no)

Yeah… At Fuzzer #3, I realized that we actually wrote five fuzzers for ARR, but the title and the Dickens quote had really grown on me by that time. Sorry for this, here’s a bonus fuzzer for you!

Our positive space ARR fuzzer explores a really specific network topology, which is roughly as far from a realistic scenario as the negative space fuzzer, but in the opposite direction — everything’s too good, no one’s crashing, the network gives stable latencies.

What we are missing is the realistic fuzzer between the two extremes. A fuzzer that runs in a somewhat flaky network, and checks that the route is roughly optimal (or at least not bad). But that is the VOPR! As a whole system fuzzer, it is capable of simulating somewhat realistic distributions of network faults and delays.

Historically, VOPR was biased towards faulting as much things as hard as possible, as we want TigerBeetle to be correct and fast, in that order. Now that we started optimization work, we implemented `--performance` mode for VOPR.

In the default mode, VOPR uses swarm testing to generate distribution of faults (during fuzzing, you generate random events. The idea of swarm testing is to also generate the distribution itself at random). In the performance mode, fault parameters are fixed to “realistic” values, and the drastic faults (replicas crashing or becoming partitioned) are strictly controlled (e.g., you can request exactly one crash per run):

```
fn options_swarm(prng: *stdx.PRNG) Simulator.Options
fn options_performance() Simulator.Options
```

Furthermore, in performance mode VOPR tracks statistics about the number of network messages exchanged. ARR was verified by running different performance VOPR scenarios with and without ARR, and checking that ARR is an improvement across the board:

```
λ ./zig/zig build vopr -- --performance --replica-missing=2

          SEED=1044607978391563277

          replicas=6
          clients=4
          one_way_delay_mean=50ms ticks
          one_way_delay_min=0ns ticks
          packet_loss_probability=0
          path_maximum_capacity=10 messages
          packet_replay_probability=0
          crash_probability=0
          crash_stability=500 ticks
          restart_probability=0
          ...

Messages:
prepare                     1881    1.23MiB
prepare_ok                  1575  393.75KiB
request_prepare              795  198.75KiB
request                      730  510.08KiB
ping                         550  275.00KiB
reply                        503  363.76KiB
request_headers              466  116.50KiB
pong                         440  110.00KiB
headers                      328  320.75KiB
commit                       285   71.25KiB
start_view                    85  224.25KiB
do_view_change                25   12.50KiB
request_start_view            10    2.50KiB
total                       7673    3.77MiB

          PASSED (1741 ticks)
```

It’s a bit hard to turn these manual experiments into tests that fail _only_ if there are bugs (and not due to randomness or unrelated code choices), but just tinkering with the setup is a great way to quickly test ideas. VOPR runs _much_ faster than a real-world cluster would, so you can use it to collect a fairly long performance trace.

## [Recap](https://tigerbeetle.com/blog/2025-11-28-tale-of-four-fuzzers/#recap)

This was a long one, wasn’t it? Although it’s just one system and five fuzzers, no two fuzzers are alike, each illuminates its own corner of the design space. If you want a closer looks, here’s the [source code](https://github.com/tigerbeetle/tigerbeetle/blob/0.16.66/src/vsr/routing.zig), it’s almost exactly a thousand lines for the implementation plus the fuzzers.

To jolt the ideas back into the short term (and, who knows, maybe a long term) memory:

-   You want both a whole system fuzzer AND subsystem (minor) fuzzers. Main fuzzer works out the seams between components, while minor fuzzers divide&conquerer the resulting combinatorial explosion.
-   Good fuzzing is tantamount to good interfaces.
-   Interfaces can be extracted mechanically, by introducing indirection whenever a dependency happens.
-   But such a mechanical interface extraction risks ossifying accidental dependencies.
-   Long-term more efficient approach is to think in terms of fundamental input and output data. Sometimes a little copying is better than a little dependency!
-   Data interfaces tend to be non-incremental. The best time to capture an interface is _before_ the first line of code is written.
-   Fuzz positive space and negative space.
-   Given a PRNG _interface_, its easy to explore structured search space.
-   If the search space is small, you can use the _same_ PRNG interface to walk it thoroughly and exhaustively.
-   And you can plug the _same_ PRNG interface into coverage guided fuzzer.
-   `deserialize . serialize` is positive space, `serialize . deserialize` can be negative space.
-   Hard to breath in rarefied air! Purely random inputs can be uniformly boring and bounce off the edges of the system.
-   For negative space testing, you want to hew close to the valid/invalid boundary, poking out from _both_ sides.
-   You still want some amount of purely random inputs, just in case.
-   You want to _assert_ that both positive and negative cases actually happen with non-negligible probability.
-   Run fuzzer once with a fixed seed (I use `92`), to sanity check the count of good and bad cases.
-   Run fuzzer again with a genuinely random seed to accumulate coverage over time.
-   Make sure to generate the seed _outside_ of the test process itself, lest it gets lost during crash.
-   Mind the time! You want to make each individual CI run as quick as possible, while racking up the total fuzzing time over multiple runs.
-   Another quick and dirty way to check fuzzer coverage is adding `unreachable` to various branches and check seeing if it crashes.
-   Fuzzers can test fairly sophisticated invariants (e.g., optimality of the routing), but that might require setting up a particularly favorable environment.
-   Writing a fuzzer is mostly boring mechanical work. However, not only fuzzers do find bugs, some bugs lead to large, fundamental mental shifts, and a deeper understanding of the domain!
-   Don’t write fuzzers to find bugs in the code, write fuzzers to find bugs in your understanding of the problem.
-   Positive space fuzzing tries to be realistic, negative space fuzzing tries to be un-realistic.
-   Simulate a real cluster for the positive space, simulate a single peer in a radioactive room for the negative space.
-   It might be hard to get intricate, flake-free assertions from the whole system fuzzer.
-   But whole-system fuzzer is still invaluable as an exploration tool.
-   You can fuzz for performance, at least on the high level protocol level (# messages exchanged).

Até já!

MORE POSTS

[

## Mathematics of Consensus — Accidental Lecture

matklad · Nov 22, 2025

](https://tigerbeetle.com/blog/2025-11-22-mathematics-of-consensus)

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

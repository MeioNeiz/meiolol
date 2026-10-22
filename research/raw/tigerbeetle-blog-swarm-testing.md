# Swarm Testing Data Structures

<https://tigerbeetle.com/blog/2025-04-23-swarm-testing-data-structures/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# Swarm Testing Data Structures

Apr 23, 2025

-   [
    
    matklad
    
    ](https://matklad.github.io/)

We discovered a cute little pattern the other day when [refactoring TigerBeetle’s intrusive queue](https://github.com/tigerbeetle/tigerbeetle/pull/2888/commits/af78262b5bbabde70792842bba9bd1bf9c4c3f0b) — using Zig’s comptime reflection for exhaustively testing data structure’s public API. Isn’t it cool when your property test fails when you add a new API, because “public API is tested” is one of the properties you test?!

## [Time for Reflection](https://tigerbeetle.com/blog/2025-04-23-swarm-testing-data-structures/#time-for-reflection)

Let’s say you are implementing an abstract data type (ADT), such as an intrusive queue, and you want to test it. For data structures, by far the best power-to-weight ratio testing strategy is [property based testing](https://hypothesis.works/articles/what-is-property-based-testing/), especially if you can come up with a model that behaves exactly as the ADT you are implementing.

For an intrusive queue, one possible model is a non-intrusive ring buffer. The test then invokes the same methods on the model and the data structure under test, and checks that the two behave identically under any sequence of operations. And you can use comptime reflection to extract the possible operations directly from the public API!

If you have something like:

```
pub fn QueueType(comptime T: type) type {
   return struct {
       in: ?*T = null,
       out: ?*T = null,
       count: u64 = 0,

       const Queue = @This();

       pub fn push(self: *FIFO, elem: *T) void { ... }

       pub fn pop(self: *FIFO) ?*T { ... }

       pub fn empty(self: FIFO) bool { ... }
   };
}
```

Then, the magic spell of `std.meta.DeclEnum(QueueType(Item))` returns an enum that looks like this:

```
enum {
   push,
   pop,
   empty,
}
```

You can plug that directly into your property test:

```
const Queue = QueueType(Item);
const Model = RingBufferType(Item);
const N = 1_000;

var queue: Queue = .{};
var model = try Model.init(gpa);
defer model.deinit(gpa);

var prng = PRNG.from_seed(std.testing.random_seed);
for (0..N) |_| {
   switch (prng.enum_uniform(std.meta.DeclEnum(Queue))) {
                         // ^ Magic 🪄!
       .push => {
           const item = random_item(&prng);
           model.push(item);
           queue.push(item);
       },
       .pop => {
           assert(model.pop() == queue.pop());
       },
       .empty => {
           assert(model.empty() == queue.empty());
       }
   }
}
```

The cool thing here is that if a new public method is added to the Queue in future, then the compiler will emit an error because of the non-exhaustive switch, reminding you to also cover this new method by a property test. This is not such a big deal of course, but we get it for free, thanks to Zig’s comptime!

The `enum_uniform` is a helper that picks an enum value at random:

```
pub fn enum_uniform(prng: *PRNG, Enum: type) Enum {
   const values = comptime std.enums.values(Enum);
   return values[prng.index(values)];
}

pub fn index(prng: *PRNG, slice: anytype) usize {
   assert(slice.len > 0);
   return prng.int_inclusive(usize, slice.len - 1);
}
```

This is already good as a smoke test, to make sure you poke every public method. But just one small tweak can make this even more efficient.

## [Hive Mind](https://tigerbeetle.com/blog/2025-04-23-swarm-testing-data-structures/#hive-mind)

The main caveat with property-based testing is that you need to pay attention to your distribution. Picking things uniformly at random doesn’t necessarily give you interesting inputs! For example, for a binary search, a hard case that may uncover bugs is an array where all elements are the same, but generating integers at random uniformly almost guarantees that no two elements are the same.

So the big idea in this area then is swarm testing — typically, the system under test has a lot of dimensionality (all the methods you might possibly call), but bugs can be triggered by tricky combinations of just a few features. So, instead of picking every feature uniformly at random, we first randomly pick a subset of features we are exercising, and then, during a single run, we sample only from that subset.

There’s another way to say this. Suppose you write a property test, which decides on actions with some probabilities. The idea of swarm testing is that you should sample the probabilities themselves!

For example, one weakness of our test above is that we chose to pop and push with equal probability. As a result, our queue is very short on average. We never exercise large queues!

## [Randomizing Randomness](https://tigerbeetle.com/blog/2025-04-23-swarm-testing-data-structures/#randomizing-randomness)

As a reminder, this is how we select the method to call:

```
switch (prng.enum_uniform(std.meta.DeclEnum(Queue)))
```

For swarm testing, we want this to be non-uniform. This is easy. You can pass in weights, which give a relative probability for every enum variant. If you have something like this

```
const Actions = enum {
    push,
    pop,
    empty,
};
```

then it is convenient to specify the weights as a struct:

```
const ActionWeights = struct {
    push: u64,
    pop: u64,
    empty: u64,
};
```

And of course, Zig includes a helper function for exactly this kind of transformation!

```
pub fn EnumWeightsType(E: type) type {
    return std.enums.EnumFieldStruct(E, u64, null);
}
```

With this setup, picking a weighted enum is straightforward. Sum all the weights, toss a coin into the middle of the weight range, and pick the corresponding value:

```
pub fn enum_weighted(
    prng: *PRNG,
    Enum: type,
    weights: EnumWeightsType(Enum),
) Enum {
    const fields = @typeInfo(Enum).Enum.fields;
    var total: u64 = 0;
    inline for (fields) |field| {
        total += @field(weights, field.name);
    }
    assert(total > 0);

    var pick = prng.int_inclusive(u64, total - 1);
    inline for (fields) |field| {
        const weight = @field(weights, field.name);
        if (pick < weight) {
            return @as(Enum, @enumFromInt(field.value));
        }
        pick -= weight;
    }
    unreachable;
}
```

Finally, as per swarm testing, we should randomly pick weights. We do this by first randomly picking a subset of weights to be non-zero, then assigning random values to the selected weights:

```
pub fn random_enum_weights(
    prng: *PRNG,
    comptime Enum: type,
) PRNG.EnumWeightsType(Enum) {
    const fields = comptime std.meta.fieldNames(Enum);

    var combination = PRNG.Combination.init(.{
        .total = fields.len,
        .sample = prng.range_inclusive(u32, 1, fields.len),
    });
    defer assert(combination.done());

    var weights: PRNG.EnumWeightsType(Enum) = undefined;
    inline for (fields) |field| {
        @field(weights, field) = if (combination.take(prng))
            prng.range_inclusive(u64, 1, 100)
        else
            0;
    }

    return weights;
}
```

Here, `Combination` is a small helper to pick a random `k`\-combination out of `n` without allocation:

```
pub const Combination = struct {
    total: u32,
    sample: u32,

    taken: u32,
    seen: u32,

    pub fn init(options: struct {
        total: u32,
        sample: u32,
    }) Combination {
        assert(options.sample <= options.total);
        return .{
            .total = options.total,
            .sample = options.sample,
            .taken = 0,
            .seen = 0,
        };
    }

    pub fn done(combination: *const Combination) bool {
        return combination.taken == combination.sample and
            combination.seen == combination.total;
    }

    pub fn take(combination: *Combination, prng: *PRNG) bool {
        assert(combination.seen < combination.total);
        assert(combination.taken <= combination.sample);

        const n = combination.total - combination.seen;
        const k = combination.sample - combination.taken;
        const result = prng.chance(ratio(k, n));

        combination.seen += 1;
        if (result) combination.taken += 1;
        return result;
    }
};
```

## [Testing Template](https://tigerbeetle.com/blog/2025-04-23-swarm-testing-data-structures/#testing-template)

Adding all of these helpers back to our property-based test, we get the following generic setup for swarm testing of an arbitrary data structure:

```
const Queue = QueueType(Item);
const Model = RingBufferType(Item);
const N = 1_000;

var queue: Queue = .{};
var model = try Model.init(gpa);
defer model.deinit(gpa);

var prng = PRNG.from_seed(std.testing.random_seed);
const weights =
    random_enum_weights(&prng, std.meta.DeclEnum(Queue));

for (0..N) |_| {
    const swarm_distribution = prng.enum_weighted(
        std.meta.DeclEnum(Queue),
        weights,
    );
    switch (swarm_distribution) {
        .push => { ... },
        .pop => { ... },
        .empty => { ... },
    }
}
```

Please steal this and use this!

MORE POSTS

[

## Why We Designed TigerBeetle's Docs from Scratch

Fabian Rühle, Fabio Arnold, matklad · Feb 27, 2025

](https://tigerbeetle.com/blog/2025-02-27-why-we-designed-tigerbeetles-docs-from-scratch)

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

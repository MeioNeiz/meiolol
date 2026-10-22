# Enum of Arrays

<https://tigerbeetle.com/blog/2024-12-19-enum-of-arrays/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# Enum of Arrays

Dec 19, 2024

-   [
    
    matklad
    
    ](https://matklad.github.io/)

A popular data-oriented design pattern is a Struct of Arrays. Is an Array of Enums also useful? Yes! But let’s do a refresher on struct of arrays (`SoA`) first:

If you have a `Thing`,

```
const Thing = struct {
   checksum: u128,
   number: u32,
   flag: u8,
};
```

and an array of `Thing`s,

```
// Array of Structs.
const AoS = []Thing;
```

it’s possible to wrap the data inside out and use

```
// Struct of Arrays.
const SoA = struct {
   checksum: []u128
   number: []u32,
   flag: []u8,
};
```

instead. The benefits are:

-   Reduced memory usage due to amortized padding. As `flag` is a byte, it requires some padding to align with larger fields like `checksum`. In `AoS`, each individual struct has this padding. In `SoA`, there’s still padding for `flag`, but it’s just one instance of padding for all the `Thing`s.
-   Better memory bandwidth utilization for batched code. If a loop needs to process all things, but the processing doesn’t require all fields (at least for the majority of objects), then an array-based representation reduces the amount of data that needs to be loaded.

You can use the same trick also for a more SIMD-friendly data layout. A bad way to use SIMD is to try to vectorize the processing of an individual item. A good way to use SIMD is to process several items at once.

For example, if a `Thing` in question is a 3D vector, it’s usually not a good idea to implement the dot product of two vectors by loading `xyz` of one vector into a SIMD register `a`, `xyz` of another vector into a SIMD register `b`, and then performing a SIMD multiplication of `a * b`. The reason is that your “SIMD width” is still only three numbers:

Much better to simultaneously compute the dot products of multiple pairs of vectors. Then, you can load a SIMD vector with `xxxxxxx`, which is the `x` coordinate for the first vector of multiple pairs. And so, the full width of SIMD registers is used:

This post is to raise awareness that the same trick works with enums:

```
const Thing = union(enum) {
   spam: Spam,
   eggs: Eggs
}

// With a level of abstraction peeled:
const Thing = struct {
   tag: u8,
   payload: union {
       spam: Spam,
       eggs: Eggs,
   }
};
```

Here’s an array of enums:

```
const AoE = []Thing;
```

And here’s the dual, an enum of arrays:

```
const EoA = struct {
   tag: u8, // Sic!
   payload: union {
       spam: []Spam,
       eggs: []Eggs,
   }
}
```

The _key_ idea is that there’s only a single `tag` per an entire batch of things. If a batch size is 1024, you can have 1024 spams or 1024 eggs, but not a mix of the two.

The benefits of this representation:

-   Tags occupy less bytes in total, because a single tag can be amortized across many objects at once.
    
-   If individual enum variants are of different sizes, then no memory is wasted when storing the gap between a small variant and a large one.
    
-   Finally, the purpose of the tag is for the CPU to branch on it. By having only one tag per batch of objects, the amount of branching the CPU has to do is dramatically reduced, which is a very good thing in itself—unpredictable branching slows down the CPU a lot. But what’s more, with branching out of the way, the processing is opened up for SIMD optimizations!
    

TigerBeetle is built around this idea of `AoE => EoA` optimizations. TigerBeetle can do two things: create new accounts, and then create transfers between accounts. This _could_ have been represented as a heterogeneous enum of the two kinds of operation. Instead, TigerBeetle uses homogeneous batches. TigerBeetle does eight thousands operations at a time, and there’s one tag for an entire batch. So, it’s always 8k transfers followed by 8k accounts, not a mixture of the two.

This optimization is related to the concept of data plane and control plane separation. The `tag` is control plane, a small, infrequent piece of information which informs decisions. The data plane then is more voluminous, but processing it doesn’t require many individual decisions. Just. One. Branch!

That’s all for today. Support your local branch predictor, convert your AoE to EoA!

MORE POSTS

[

## Rediscovering Transaction Processing From History and First Principles

Joran Dirk Greef · Jul 23, 2024

](https://tigerbeetle.com/blog/2024-07-23-rediscovering-transaction-processing-from-history-and-first-principles)

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

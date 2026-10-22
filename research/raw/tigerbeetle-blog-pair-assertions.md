# It Takes Two to Contract

<https://tigerbeetle.com/blog/2023-12-27-it-takes-two-to-contract/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# It Takes Two to Contract

Dec 27, 2023

-   [
    
    matklad
    
    ](https://matklad.github.io/)

Today’s topic: [design by contract](https://en.wikipedia.org/wiki/Design_by_contract). To be honest, I was skeptical of DbC: it feels like it boils down to:

1.  Use types.
2.  Use assertions.

Which I still believe is mostly true! To clarify, types and assertions are a very capable mechanism to catch bugs earlier and to limit the consequences of bugs that do slip through. It’s just that you don’t really need any syntactic mechanisms to use these tools effectively, you don’t need first class support for design by contract in your language. Just write more assertions!

For preconditions, `assert` function works perfectly, and for postconditions, there’s `defer`:

```
assert(!grid.free_set.opened);
defer assert(grid.free_set.opened);
```

One thing that might occasionally be necessary is the ability to name the result of the function, so that it’s possible to write:

```
defer assert(result > 0);
```

But:

-   It is almost always possible to just move the postcondition to be right before the return statement.
-   A canonical name for the result variable is a generally useful language feature unrelated to assertions, it enables placement: [https://github.com/ziglang/zig/issues/2765](https://github.com/ziglang/zig/issues/2765).

One area where you do need first-class support for DbC is inheritance in object-oriented languages: derived classes can weaken the preconditions and strengthen the postconditions, and coding _that_ manually does add boilerplate. Which is perhaps another reason to avoid inheritance-based polymorphism?

As an exception, contracts absolutely do pull their weight in the [Nickel](https://nickel-lang.org/) configuration language, which demonstrates rather remarkable synergy between gradual typing, contracts, and lazy evaluation.

But, for a run-of-the-mill general purpose programming language, assertions and types are all you need, so there’s no excuse to not start doing more contract programming today.

If DbC is just asserts, they why I am writing this post today? Well, it turns out that there is something new about contract programming I’ve learned while hacking on TigerBeetle, and I want to share it:

Contracts always involve two parties.

That is, something is a real contract only when you have at least _two_ assertions checking the relevant condition: you do one check at the call site, and one check at the definition site. Let’s pull an example from today’s code! Here’s a call site of the `fill_immutable_values` function, which fills the provided buffer with some values:

```
const filled = compaction.fill_immutable_values(target);
assert(filled <= target.len);
if (filled == 0) assert(Table.usage == .secondary_index);
```

At the call site, we don’t blindly trust the return value, but rather assert some invariants: that it couldn’t have copied more values than the length of the provided buffer and that, if the the number of copied values was zero, we are indeed in the special case where that could happen.

And then, we assert _the same_ two conditions at the definition site:

```
fn fill_immutable_values(compaction: *Compaction, target: []Value) usize {
    ...
    assert(target_count <= source_count);
    if (target_count == 0) {
        assert(Table.usage == .secondary_index);
        return 0;
    }
    return target_count;
}
```

Now this is curious. Isn’t this just code duplication? The lesson I’ve learned is that yes, it absolutely is often a duplication in practice, but a useful one.

The philosophy here is that these are just _accidentally_ identical assertions. The function postcondition might actually be _stronger_ than what is required at the call site, so assertion after-the-call could be a different, weaker one.

But let’s talk pragmatics. First, having asserts in both places helps readability tremendously. Just compare

```
const filled = compaction.fill_immutable_values(target);
```

with

```
const filled = compaction.fill_immutable_values(target);
assert(filled <= target.len);
```

In the second snippet, the semantics of `filled` is immediately clear. And, with a matching assertion at the definition site, you can now (at a glance!) check that the assumption at the call site holds.

An assertion _pair_ forms an airlock — to reason about the correctness of a particular function call, you don’t need to keep both the definition and the call site in mind. Rather, you could verify just that the assertions between the two are compatible, and then reason separately that each party indeed provides the guarantees it asserts.

We love the readability benefit of asserts so much that we even have a special `maybe(condition);` assertion, which is a no-op: it signals that the condition might be true at runtime, shining a spotlight on an otherwise non-obvious aspect of code:

```
pub fn write_sectors(
    self: *Storage,
    callback: *const fn (write: *Storage.Write) void,
    write: *Storage.Write,
    buffer: []const u8,
    zone: vsr.Zone,
    offset_in_zone: u64,
) void {
    zone.verify_iop(buffer, offset_in_zone);
    maybe(zone == .grid_padding); // Padding is zeroed during format.
    ...
}
```

Besides readability, another pragmatic reason to pair assertions is robustness and defense in depth: as code is evolving and preconditions are strengthened or relaxed over time, having a separate set of assertions at each call site helps to ensure that refactoring around one call site doesn’t break the other. And then there’s an argument that repeating an assertion using a slightly different vocabulary of local variables maximizes the chance that at least one instance is not buggy. For example, did you notice in the `fill_immutable_values` example that the `assert(filled <= target.len);` condition _isn’t_ actually checked for at the definition site? I didn’t myself, until I started drafting this post!

But, although checking return values of functions comes straight from [NASA’s Power of 10 Rules for Safety-Critical Code](https://en.wikipedia.org/wiki/The_Power_of_10:_Rules_for_Developing_Safety-Critical_Code), which TigerBeetle follows, this actually is the more trivial benefit of paired assertions. The real superpower is unlocked once you get to the same logical assertion through two different code paths.

Consider a consensus protocol, which relies on many subtle invariants. Whenever a replica sends a message, it of course asserts that the resulting message satisfies the invariants, at least to the extent the replica is aware about global state of the cluster. Upon receiving the message, the recipient replica checks the same invariants, _but_ it has different local knowledge about the state of the cluster, and the resulting checks become meaningfully different.

The best example of this in TigerBeetle is in pervasive use of hash-chaining — everything in TigerBeetle carries a checksum, and includes checksums of related data. So, although two replicas might not have all pieces of the shared cluster state at the same time, they can and do check that the parts of the state they do have connect correctly according to hashes, and sound alarm if divergence is detected. We think of this as _binding intent_ cryptographically, as cryptographic scaffolding for what would otherwise be simple (easy to conflate!) operation numbers in our consensus.

This actually is a trick from property-based testing — there, one possible property is to carry out the same computation in two different ways and check that the result is indeed the same. Turns out, in real systems the “two paths” can happen naturally, and the technique can be lifted straight out of tests into the production code.

As another example of two paths, there generally can be two ways a replica might end up in a particular state:

-   Either it started from an empty data file and processed a bunch of events normally.
-   Or, it crashed at some point (or joined the cluster later), and started from a specific snapshot, rather than from zero.

The state should be the same, although the paths are different. Recording the checksum of the state into a snapshot and asserting that it is the same across lucky and unlucky replicas is a way to ensure that the two paths are indeed equivalent.

To sum up:

-   Assertions often come in pairs.
-   Whenever you assert something, think about which distant part of the code base relies on the assertion you just wrote, and add an equivalent assertion there.
-   This is worth doing even in the trivial case, where the two parties are a function and its caller.
-   But be on lookout for more interesting cases, where the two halves of an assertion pair are separated by different implementations, or a process and time boundary.

MORE POSTS

[

## 64-Bit Bank Balances ‘Ought to be Enough for Anybody’?

Rafael Batiati · Sep 19, 2023

](https://tigerbeetle.com/blog/2023-09-19-64-bit-bank-balances-ought-to-be-enough-for-anybody)

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

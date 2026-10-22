# Index, Count, Offset, Size

<https://tigerbeetle.com/blog/2026-02-16-index-count-offset-size/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# Index, Count, Offset, Size

Feb 16, 2026

-   [
    
    matklad
    
    ](https://matklad.github.io/)

Wherein we make progress towards solving one of the most vexing problems of Computer Science — naming things.

I am at a point in my career where the bulk of my bugs are stupid — I simply fail to type in the code I have in my mind correctly. In languages with shadowing (like Rust), I will fail to use a shadowed variable from the outer scope. In languages without shadowing (like Zig), I will use the wrong version of a variable.

Pests like these are annoying, so I am always on the lookout for tricks to minimize the probability of bugs. One of the best possible tricks is of course strong static typing. Types are good at preventing me from doing stupid things by accident. But types have limitations. The text of a well-typed program is a two-in-one artifact — a specification of behavior of a machine (the algorithm), and a proof that the behavior is not unacceptable. Zero cost abstractions are code without behavior, just proofs!

The art of skillful typing lies in minimizing verbosity of the proof, while maximizing the amount of unwanted behaviors ruled out, weighted by the probability and the cost of misbehavior. But this ratio is not always favorable — the code can be so proof-heavy that it becomes impossible to understand what it actually _does_!

There’s one particular cranny where types don’t seem to usefully penetrate yet: indexing and associated off-by-one errors.

If you don’t need indexing _arithmetic_, you can use [newtype pattern](https://matklad.github.io/2025/12/23/zig-newtype-index-pattern.html) to prevent accessing oranges with apple-derived indexes. You can even go further and bind indexes to _specific_ arrays, using, e.g., [Gankra trick](https://faultlore.com/blah/papers/thesis.pdf#page=56), but I haven’t seen that to be useful in practice.

If, however, you _compute_ indexes, you need to be extra careful to stay in bounds of an array, and need to be mindful that the maximum valid index is one less than the length of the array. While we don’t solve this problem perfectly at TigerBeetle, I think we have a naming convention that helps:

Thanks [@marler8997](https://ziggit.dev/t/a-rare-bug-in-audio-code-by-zig-s-creator-can-you-find-it/11366/6) for the illustration idea!

We consistently use `count` whenever we talk about the number of items, and `index` to point to a particular item. The [positive invariant](https://github.com/tigerbeetle/tigerbeetle/blob/0.16.73/docs/TIGER_STYLE.md#:~:text=State%20invariants%20positively) is `index < count`. Consistency is the trick — there are certain valid and invalid ways to combine indexes and counts in an expression, and, if there’s always an `_index` or a `_count` suffix in the name, wrong combinations immediately jump out at you, dear reader, even if you don’t understand the specifics of the code.

In low-level code you often need to switch between a well-typed representation `[]T`and raw bytes `[]u8`. To not confuse the two index spaces, the “count of bytes” is always called a `size`. By definition,

```
size = @sizeOf(T) * count;
```

And `offset` is the bytewise counterpart of `index`.

We don’t use `length` in our code, as its meaning is ambiguous. Rust `str::len` is the byte-`size` of the string, but Python’s `len(str)` is the `count` of Unicode code-points!

Here’s an example of the naming convention in action from [NodePool](https://github.com/tigerbeetle/tigerbeetle/blob/0cd32077bff00b15b83b3417bf700ecb0c888f78/src/lsm/node_pool.zig#L70-L82):

```
pub fn release(pool: *NodePool, node: Node) void {
    comptime assert(meta.Elem(Node) == u8);
    comptime assert(meta.Elem(@TypeOf(pool.buffer)) == u8);

    assert(@intFromPtr(node) >= @intFromPtr(pool.buffer.ptr));
    assert(
        @intFromPtr(node) + node_size <=
            @intFromPtr(pool.buffer.ptr) + pool.buffer.len
    );

    const node_offset =
        @intFromPtr(node) - @intFromPtr(pool.buffer.ptr);

    const node_index =
        @divExact(node_offset, node_size);

    assert(!pool.free.isSet(node_index));
    pool.free.set(node_index);
}
```

You can see that the `node_index` calculation is correct mechanically, just from the names of the variables.

And here’s an `index/count` example from our [`ewah`](https://github.com/tigerbeetle/tigerbeetle/blob/81f78fe21a939ed1bffc43a10a484779e3866cf9/src/ewah.zig#L68-L95) implementation:

```
pub fn decode(
    source: []align(@alignOf(Word)) const u8,
    target_words: []Word,
) usize {
    assert(source.len % @sizeOf(Word) == 0);
    assert(disjoint_slices(u8, Word, source, target_words));

    const source_words = mem.bytesAsSlice(Word, source);

    var source_index: usize = 0;
    var target_index: usize = 0;
    while (source_index < source_words.len) {
        const marker: *const Marker =
            @ptrCast(&source_words[source_index]);
        source_index += 1;

        @memset(
            target_words[target_index..][0..marker.uniform_word_count],
            if (marker.uniform_bit == 1) ~@as(Word, 0) else 0,
        );
        target_index += marker.uniform_word_count;

        stdx.copy_disjoint(
            .exact,
            Word,
            target_words[target_index..][0..marker.literal_word_count],
            source_words[source_index..][0..marker.literal_word_count],
        );
        source_index += marker.literal_word_count;
        target_index += marker.literal_word_count;
    }
    assert(source_index == source_words.len);
    assert(target_index <= target_words.len);

    return target_index;
}
```

Note well that the `index/count` convention synergizes with two other TigerStyle shticks. We use “big endian naming”, where qualifiers are appended as suffixes:

```
source
source_words
source_index
```

And we try to make sure that dual names have the same length:

```
source
target
```

The code aligns itself, and makes the bugs pop out:

```
source_index += marker.literal_word_count;
target_index += marker.literal_word_count;
```

Of course, a simple naming convention by itself won’t make software significantly better. But grains of sand add up to Dune: there’s no one trick to get rid of the bugs, but you can layer your defenses to exponentially decrease the probability of a failure.

MORE POSTS

[

## One for the Treble, Two for the Time

Lewis Daly · Jan 14, 2026

](https://tigerbeetle.com/blog/2026-01-14-bitemporality)

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

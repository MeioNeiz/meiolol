# Random Numbers Included

<https://matklad.github.io/2025/03/31/random-numbers-included.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# Random Numbers Included

Mar 31, 2025

I’ve recently worked on a [PRNG API for TigerBeetle](https://github.com/tigerbeetle/tigerbeetle/pull/2798), and made a surprising discovery! While most APIs work best with “half-open” intervals, `for(int i = 0; i < n; i++)`, it seems that random numbers really work best with closed intervals, `≤n`.

_First_, closed interval means that you can actually generate the highest-possible number:

```
prng.range_inclusive(
    u32,
    math.intMax(u32) - 9,
    math.intMax(u32),
);
```

This call generates one of the ten largest `u32`s. With exclusive ranges, you’d have to generate `u64` and downcast it.

_Second_, close interval removes a possibility of a subtle crash. It is impossible to generate a random number _less_ than zero, so exclusive APIs are panicky. This can crash!: `rng.random_range(..n)`

_Third_, as a flip-side of the previous bullet point, by pushing the `-1` to the call-site, you make it immediately obvious that there’s non-zero pre-condition:

```
const replica = prng.int_inclusive(u8, replica_count - 1);
```

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2025-03-31-random-numbers-included.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)

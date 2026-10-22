# Retry Loop Retry

<https://matklad.github.io/2025/08/23/retry-loop-retry.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# Retry Loop Retry

Aug 23, 2025

Some time ago I lamented that I don’t know how to write a retry loop such that:

-   it is syntactically obvious that the amount of retries is bounded,
-   there’s no spurious extra sleep after the last attempt,
-   the original error is reported if retrying fails,
-   there’s no code duplication in the loop.

[https://matklad.github.io/2023/12/21/retry-loop.html](https://matklad.github.io/2023/12/21/retry-loop.html)

To recap, we have

```
fn action() E!T { ... }
fn is_transient_error(err: E) bool { ... }
```

and we need to write

```
fn action_with_retries(retry_count: u32) E!T { ... }
```

I’ve received many suggestions, and the best one was from [https://www.joachimschipper.nl](https://www.joachimschipper.nl/), though it was somewhat specific to Python:

```
for tries_left in reverse(range(retry_count)):
    try:
        return action()
    except Exception as e:
        if tries_left == 0 or not is_transient_error(e):
            raise
        sleep()
else:
    assert False
```

A couple of days ago I learned to think better about the problem. You see, the first requirement, that the number of retries is bounded syntactically, was leading me down the wrong path. If we _start_ with that requirement, we get code shape like:

```
const result: E!T = for (0..retry_count) {
    // ???
    action()
    // ???
}
```

The salient point here is that, no matter what we do, we need to get `E` or `T` out as a result, so we’ll have to call `action()` at least once. But `retry_count` _could_ be zero. Looking at the static semantics, any non `do while` loop’s body can be skipped completely, so we’ll have to have some runtime asserts explaining to the compiler that we really did run `action` at least once. The part of the loop which is guaranteed to be executed at least once is a condition. So it’s more fruitful to flip this around: it’s not that we are looping until we are out of attempts, but, rather, we are looping while the underlying action returns an error, and then retries are an extra condition to exit the loop early:

```
var retries_left = retry_count;
const result = try while(true) {
    const err = if (action()) |ok| break ok else |err| err;
    if (!is_transient_error(err)) break err;

    if (retries_left == 0) break err;
    retries_left -= 1;
    sleep();
};
```

This shape of the loop also works if the condition for retries is not attempts based, but, say, time based. Sadly, this throws “loop is obviously bounded” requirement out of the window. But it can be restored by adding _upper bound_ to the infinite loop:

```
var retries_left = retry_count;
const result = try for(0..retry_count + 1) {
    const err = if (action()) |ok| break ok else |err| err;
    if (!is_transient_error(err)) break err;

    if (retries_left == 0) break err;
    retries_left -= 1;
    sleep();
} else @panic("runaway loop");
```

I still don’t like it (if you forget that `+1`, you’ll get a panic!), but that’s where I am at!

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2025-08-23-retry-loop-retry.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)

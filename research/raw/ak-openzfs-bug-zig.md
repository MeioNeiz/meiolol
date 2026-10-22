# OpenZFS Bug Ported to Zig - Andrew Kelley

<https://andrewkelley.me/post/openzfs-bug-ported-zig.html>

[Andrew Kelley](https://andrewkelley.me/) - OpenZFS Bug Ported to Zig (2025 Jul 14)

* * *

# OpenZFS Bug Ported to Zig

Someone on IRC shared this link with me: [An (almost) catastrophic OpenZFS bug and the humans that made it (and Rust is here too)](https://despairlabs.com/blog/posts/2025-07-10-an-openzfs-bug-and-the-humans-that-made-it/)

They wanted to know, would Zig catch this?

I went through the trouble of porting the code snippet to Zig, so I thought I'd go the next step and turn it into a small blog post.

Original snippet, in C:

```c
/*
 * This code converts an asize into the largest psize that can safely be written
 * to an allocation of that size for this vdev.
 *
 * Note that this function will not take into account the effect of gang
 * headers, which also modify the ASIZE of the DVAs. It is purely a reverse of
 * the psize_to_asize function.
 */
static uint64_t
vdev_raidz_asize_to_psize(vdev_t *vd, uint64_t asize, uint64_t txg)
{
	vdev_raidz_t *vdrz = vd->vdev_tsd;
	uint64_t psize;
	uint64_t ashift = vd->vdev_top->vdev_ashift;
	uint64_t cols = vdrz->vd_original_width;
	uint64_t nparity = vdrz->vd_nparity;

	cols = vdev_raidz_get_logical_width(vdrz, txg);

	ASSERT0(asize % (1 << ashift));

	psize = (asize >> ashift);
	psize -= nparity * DIV_ROUND_UP(psize, cols);
	psize <<= ashift;

	return (asize);
}
```

The blog post author encourages us to try to [spot the fail](https://andrewkelley.me/post/spot-the-fail.html) before the answer is revealed.

I couldn't do it before getting bored, so I ported the code to Zig instead:

```zig
const std = @import("std");
const divCeil = std.math.divCeil;
const assert = std.debug.assert;
const vdev_t = @import("the_rest_of_the_software.zig").vdev_t;

/// This code converts an asize into the largest psize that can safely be written
/// to an allocation of that size for this vdev.
///
/// Note that this function will not take into account the effect of gang
/// headers, which also modify the ASIZE of the DVAs. It is purely a reverse of
/// the psize_to_asize function.
fn vdev_raidz_asize_to_psize(vd: *vdev_t, asize: u64, txg: u64) u64 {
    const vdrz = vd.vdev_tsd;
    const ashift = vd.vdev_top.vdev_ashift;
    const cols = vdrz.vd_original_width;
    const nparity = vdrz.vd_nparity;

    const cols = vdrz.get_logical_width(txg);

    assert(asize % (1 << ashift));

    const asize_shifted = (asize >> ashift);
    const parity_adjusted = asize_shifted - nparity * (divCeil(asize_shifted, cols) catch unreachable);
    const psize = parity_adjusted << ashift;

    return asize;
}
```

Let's start with the code formatting tool alone, `zig fmt`:

```
andy@bark ~/tmp> zig fmt bug.zig --ast-check
bug.zig:18:11: error: redeclaration of local constant 'cols'
    const cols = vdrz.get_logical_width(txg);
          ^~~~
bug.zig:15:11: note: previous declaration here
    const cols = vdrz.vd_original_width;
          ^~~~
```

Hmm, alright. That's definitely strange. The original blog post didn't notice that the initialization value of `cols` is dead code. That doesn't look like a logic error though. Let's fix it and try again:

```diff
@@ -12,7 +12,6 @@
 fn vdev_raidz_asize_to_psize(vd: *vdev_t, asize: u64, txg: u64) u64 {
     const vdrz = vd.vdev_tsd;
     const ashift = vd.vdev_top.vdev_ashift;
-    const cols = vdrz.vd_original_width;
     const nparity = vdrz.vd_nparity;

     const cols = vdrz.get_logical_width(txg);
```

```
andy@bark ~/tmp> zig fmt bug.zig --ast-check
bug.zig:23:11: error: unused local constant
    const psize = parity_adjusted << ashift;
          ^~~~~
```

Bingo. We didn't even have to use the type checker.

* * *

Thanks for reading my blog post.

[Home Page](https://andrewkelley.me/) | [RSS feed](https://andrewkelley.me/rss.xml) | [Sponsor the Zig Software Foundation](https://ziglang.org/zsf)

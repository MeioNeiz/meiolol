# Wrapping Code Comments

<https://matklad.github.io/2026/02/21/wrapping-code-comments.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# Wrapping Code Comments

Feb 21, 2026

I was today years old when I realized that:

-   Code and code comments ideally should be wrapped to a different column.
-   For comments, the width should be relative to the start of the comment.

It’s a good idea to limit line length to about 100 columns. This is a physical limit, the width at which you can still comfortably fit two editors side by side (see [_Size Matters_](https://matklad.github.io/2025/11/28/size-matters.html)). Note an apparent contradiction: the optimal width for readable prose is usually taken to be narrower, 60–70 columns. The contradiction is resolved by noticing that, for code, indentation eats into usable space. Typically, code is much less typographically dense than prose.

Still, I find comment blocks easier to read when they are wrapped narrower than the surrounding code. I want lines to be wrapped at 100, and _content_ of comments to be wrapped at 70 (unless that pushes overall line to be longer than 100). That is, I want layout like this (using 20/30 rulers instead of 70/100, for illustrative purposes):

```
// Top level comments
// can be this wide.
const S = struct {
    // Nested comments are
    // also this wide, but
    // are shifted right.
    fn f() void {
        switch (value) {
            0 => {
                // But there is
                // a hard limit.
            }
        }
    }
}
```

This feels obvious in retrospect, but notably isn’t be well-supported by the tools? The [VS Code extension](https://marketplace.visualstudio.com/items?itemName=stkb.rewrap) I use allows configuring dedicated fill column for comments, but doesn’t make it _relative_, so indented comment blocks are always narrower than top-level ones. Emacs `M-q` also doesn’t do relative wrapping out of the box!

* * *

Aside on hard-wrapping: should we bother with wrapping comments at all? Can’t we rely on our editor to implement soft-wrapping? The problem with soft-wrapping is that you can’t soft-wrap text correctly without understanding its meaning. Consider a markdown list:

```
A list:
  * item one,
  * item two.
```

If the first item is long enough to necessitate wrapping, the wrapped line should also be indented, which requires parsing the text as markdown first:

```
A list:
  * item one which is long enough
    necessitate wrapping,
  * item two.
```

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2026-02-21-wrapping-code-comments.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)

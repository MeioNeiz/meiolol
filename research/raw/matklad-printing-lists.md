# Printing Lists

<https://matklad.github.io/2026/08/14/printing-lists.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# Printing Lists

Aug 14, 2026

To print a comma-separated list, a concise idiom is to optionally print the comma first, before the element:

```
for (items, 0..) |item, item_index| {
    if (item_index > 0) std.debug.print(", ");
    std.debug.print("{}", .{item});
}
```

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2026-08-14-printing-lists.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)

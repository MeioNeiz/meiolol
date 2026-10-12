# Scripty

Scripty is a tiny scripting language meant to be embedded in strings or other
similar constructs, usually within a host document.

Scripty supports only the basic syntax necessary to build expressions:

- refer to basic literals (`'string'`, `"string"`, `10`, `0.5`, `true`, `false`)
- access fields starting from a root evaluation context (eg `$foo.bar`)
- call functions (eg `$foo.baz()`, `$foo.bax($foo.bar, 10, true)`)

**The evaluation context for a Scripty expression is entirely defined by you.**

# Embedding examples

## SuperHTML

The [SuperHTML](https://github.com/kristoff-it/superhtml) templating language
embeds Scripty expressions in HTML attributes. Plain HTML attributes can have
values that depend on programming logic, while special attributes (generally
prefixed by `:`) are used to drive features such as looping and branching.

```html
<ul :loop="$page.subpages()">
  <li href="$loop.it.link()" :text="$loop.it.title"></li>
</ul>
```

This example contains three Scripty expressions:

- `$page.subpages()`
- `$loop.it.link()`
- `$loop.it.title`

Note that SuperHTML does not hardcode any evaluation context.
The example above is from [Zine](https://zine-ssg.io).
A different context (e.g. webserver with support for server side rendering)
will be able to tailor the evaluation context to its needs.

You can learn more about SuperHTML in the [Zine docs](https://zine-ssg.io/docs/).

## SuperMD

[SuperMD](https://github.com/kristoff-it/supermd) is the second file format
used by [Zine](https://zine-ssg.io). SuperMD extends vanilla Markdown syntax
by allowing Scripty expressions inside of link syntax.

```markdown
A heading that specifies id and classes:

# [Title](<$heading.id('foo').attrs('bar', "baz")>)

Video embed:
[](<$video.asset('video.mp4').autoplay(true).muted(false)>)

Link (with build-time validity checkind):
[about page](<$link.page('about')>)
```

The SuperMD evaluation context is designed around the idea of a "builder"
(sometimes also called "fluent") interface.

For example in `$video.asset('video.mp4').autoplay(true).muted(false)` each
function call modifies the original value and returns it so that the subsequent
function call can apply another side effect, and so forth.

While it's Scripty in both cases, there are profound differences between
the resulting experience in SuperHTML and SuperMD.

You can learn more about SuperMD in the [Zine docs](https://zine-ssg.io/docs/).

# Usage

See `src/example.zig`. Note that the API is not fully polished yet and it will change in the future.

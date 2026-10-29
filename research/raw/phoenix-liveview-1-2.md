# Phoenix LiveView 1.2 released! - Phoenix Blog

<https://www.phoenixframework.org/blog/phoenix-liveview-1-2-released>

[Phoenix Framework](https://www.phoenixframework.org/) 

[Docs](https://phoenix.hexdocs.pm/) [Community](https://phoenix.hexdocs.pm/community.html) [Source](https://github.com/phoenixframework/phoenix) [Blog](https://www.phoenixframework.org/blog)

# Phoenix LiveView 1.2 released!

Posted on June 10th, 2026 by Steffen Deusch

* * *

LiveView 1.2.0 is available now!

To update from LiveView 1.1 to 1.2, simply update the version requirement in your `mix.exs` file and re-fetch your dependencies:

```
{:phoenix_live_view, "~> 1.2.0"}
```

## Colocated CSS

In LiveView 1.1, [we introduced Colocated Hooks and Colocated JavaScript](https://www.phoenixframework.org/blog/phoenix-liveview-1-1-released), allowing you to write [hooks](https://phoenix-live-view.hexdocs.pm/1.2.0/js-interop.html#client-hooks-via-phx-hook) directly inside any HEEx template. LiveView 1.2 builds on the background work done for `Phoenix.LiveView.ColocatedJS` to allow you to colocate CSS in HEEx too.

```
def table(assigns) do
  ~H"""
  <style :type={MyApp.ColocatedCSS}>
    thead {
      color: ...;
    }
    tbody, tr:hover {
      ...
    }
  </style>
  <table>...</table>
  """
end
```

As with Colocated JS, the `:type` attribute tells LiveView to extract the content of the tag at compile time into a special `phoenix-colocated` folder in your `_build` directory. This is then picked up by your bundler (usually Tailwind or Esbuild) and processed as part of your normal CSS pipeline.

That’s the easy part though. What you usually want when defining colocated styles is to scope them, such that they don’t accidentally apply to other elements on the page from different components. Modern CSS has a relatively new [`@scope`](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@scope) rule, which allows us to do just that, with some caveats.

### The `@scope` rule

```
@scope (scope root) to (scope limit) {
  /* … */
}
```

The `@scope` rule accepts a root selector and an optional limit selector. If we are able to annotate the rendered HTML to include a unique attribute that identifies the “root” of a template and where it ends, we can have rules that only apply to that template. Since we control how HEEx compiles to HTML, we can do just that. Let’s look at an example:

```
attr :description, :string
slot :item

def my_list(assigns) do
  ~H"""
  <style :type={MyApp.ColocatedCSS}>
    p {
      font-weight: bold;
    }
  </style>

  <div>
    <p>{@description}</p>
    <ul>
      <li :for={item <- @item}>{render_slot(@item)}</li>
    </ul>
  </div>
  """
end
```

When we use this component in another template, like in your LiveView’s `render/1` function,

```
<p>Hello World</p>
<.my_list description="My List">
  <:item>
    <p>Item 1</p>
  </:item>
  <:item>
    Item 2
  </:item>
</.my_list>
```

the unmodified rendered HTML would look something like this:

```
<p>Hello World</p>

<div>
  <p>My List</p>
  <ul>
    <li>
      <p>Item 1</p>
    </li>
    <li>
      Item 2
    </li>
  </ul>
</div>
```

Now, to properly identify the parts of the HTML that belong to the `my_list` component, we need to annotate the boundaries of all templates:

```
<p phx-r>Hello World</p>

<div phx-r phx-css-foo>
  <p>My List</p>
  <ul>
    <li>
      <p phx-r>Item 1</p>
    </li>
    <li>
      Item 2
    </li>
  </ul>
</div>
```

We use a special `phx-r` attribute which is added to all outermost elements of a template and which can be used as the limit selector in a `@scope` rule. Note that we used a slot in the example above. The `<p>Item 1</p>` does not belong to `my_list`‘s template, but to the caller instead. Therefore, it is also considered a “root” and gets a `phx-r` attribute. Then, because `my_list` uses scoped colocated CSS, its root elements (it only has a single one in this example) also get a unique `phx-css-*` attribute.

Combined, this allows us to write the following CSS:

```
@scope ([phx-css-foo]) to ([phx-r]) {
  p {
    font-weight: bold;
  }
}
```

With this rule, only `p` tags that belong to `my_list`‘s template will be rendered bold, while any other `p` tags on the page are unaffected.

LiveView does not automatically inject the `phx-r` attribute. Instead, it is opt-in with a new compile-time configuration:

```
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"
```

When implementing colocated CSS, we stumbled across a problem that required us to revisit how HEEx templates are compiled. If you want to read more about this, we published [a separate technical deep dive](https://www.phoenixframework.org/blog/heex-compilation-deep-dive-liveview-1-2).

tl;dr: To make colocated CSS work, we had to change how we compile HEEx templates by splitting compilation into a separate tokenization and parsing step, allowing us to handle macro components (colocated CSS and JS) without making the rest of the compilation more complex. It also allowed us to reuse code we previously had to duplicate between template compilation and formatting.

### We don’t ship scoping by default

With all that effort for colocated CSS, you might be startled when you hear that we don’t actually ship scoping in LiveView 1.2. The reason is that the `@scope` rule is not yet well supported across browsers at the time of writing (June 2026). Instead, we ship a `@behaviour` you can implement to do custom scoping, which also allows you to use [different strategies](https://github.com/SteffenDE/phx_colocated_postcss_example/commit/9ec8372b7708f64217b7e38ab98fbd37ed8774a1). We do have [the @scope implementation in the docs](https://phoenix-live-view.hexdocs.pm/1.2.0/Phoenix.LiveView.ColocatedCSS.html#module-scoped-css) if you decide to be an early adopter.

## Small improvements landing in 1.2

Apart from colocated CSS, LiveView 1.2 also includes some small improvements:

-   You can now implement a [`Phoenix.LiveView.HTMLFormatter.TagFormatter`](https://phoenix-live-view.hexdocs.pm/1.2.0/Phoenix.LiveView.HTMLFormatter.TagFormatter.html) behaviour to format `<script>` and `<style>` tags in HEEx with a tool of your choice. We have an example using [prettier](https://prettier.io/) in the documentation.
-   `Phoenix.LiveView.JS` structs are now automatically encoded when sent with `push_event` if you use either `Jason` or the built-in `JSON` module. You can also call `JS.to_encodable/1` to encode them to a string yourself.
-   HEEx debug annotations can now be [configured per module](https://phoenix-live-view.hexdocs.pm/1.2.0/Phoenix.Component.html#module-debug-information) by setting the `@debug_heex_annotations` and `@debug_attributes` module attributes.
-   [Test warnings](https://phoenix-live-view.hexdocs.pm/1.2.0/Phoenix.LiveViewTest.html#module-optional-test-warnings) can now be configured by category.
-   We now have separate [documentation for the JavaScript client](https://phoenix-live-view.hexdocs.pm/1.2.0/js/)

and some more which can be [found in the changelog](https://phoenix-live-view.hexdocs.pm/1.2.0/changelog.html).

If you have feedback, please don’t hesitate to post [a thread on the Elixir forum](https://elixirforum.com/tag/phoenix) or [contact me on BlueSky](https://bsky.app/profile/steffend.me). If you find any issues or bugs, please [open up an issue](https://github.com/phoenixframework/phoenix_live_view/issues).

Thank you to [Dashbit](https://dashbit.co/) for sponsoring this work!

Happy coding!

\-Steffen

#### Search

 

#### Follow us

[RSS](https://www.phoenixframework.org/feed) [GitHub](https://github.com/phoenixframework)

#### Tags

-   [CI](https://www.phoenixframework.org/blog/tags/CI)
-   [ML](https://www.phoenixframework.org/blog/tags/ML)
-   [bumbleebee](https://www.phoenixframework.org/blog/tags/bumbleebee)
-   [channels](https://www.phoenixframework.org/blog/tags/channels)
-   [deep-dive](https://www.phoenixframework.org/blog/tags/deep-dive)
-   [elixirconf](https://www.phoenixframework.org/blog/tags/elixirconf)
-   [generators](https://www.phoenixframework.org/blog/tags/generators)
-   [guides](https://www.phoenixframework.org/blog/tags/guides)
-   [liveview](https://www.phoenixframework.org/blog/tags/liveview)
-   [nx](https://www.phoenixframework.org/blog/tags/nx)
-   [phoenix](https://www.phoenixframework.org/blog/tags/phoenix)
-   [pubsub](https://www.phoenixframework.org/blog/tags/pubsub)
-   [releases](https://www.phoenixframework.org/blog/tags/releases)
-   [technical](https://www.phoenixframework.org/blog/tags/technical)
-   [testing](https://www.phoenixframework.org/blog/tags/testing)
-   [uploads](https://www.phoenixframework.org/blog/tags/uploads)

#### Recent Posts

-   [A deep dive into HEEx compilation from LiveView 1.2](https://www.phoenixframework.org/blog/heex-compilation-deep-dive-liveview-1-2)
-   [Phoenix LiveView 1.2 released!](https://www.phoenixframework.org/blog/phoenix-liveview-1-2-released)
-   [Phoenix 1.8.0 released!](https://www.phoenixframework.org/blog/phoenix-1-8-released)
-     
    [See all](https://www.phoenixframework.org/blog)

© 2025 phoenixframework.org | [@elixirphoenix](https://twitter.com/elixirphoenix)  
Phoenix development is sponsored by [Fly.io](https://fly.io/) and [Dashbit](https://dashbit.co/)

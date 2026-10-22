# Visual Regression Testing — phoenix_storybook v1.5.0

<https://phoenix-storybook.hexdocs.pm/testing.html>

[phoenix\_storybook](https://phoenix-storybook.hexdocs.pm/PhoenixStorybook.html)

▼ Project version

-   
-   
-   

-   [API Reference](https://phoenix-storybook.hexdocs.pm/api-reference.html)
-   [Color modes](https://phoenix-storybook.hexdocs.pm/color_modes.html)
-   [Component stories](https://phoenix-storybook.hexdocs.pm/components.html)
-   [Custom Icons](https://phoenix-storybook.hexdocs.pm/icons.html)
-   [Sandboxing components](https://phoenix-storybook.hexdocs.pm/sandboxing.html)
-   [Manual setup](https://phoenix-storybook.hexdocs.pm/setup.html)
-   [Visual Regression Testing](https://phoenix-storybook.hexdocs.pm/testing.html)
-   [Theming components](https://phoenix-storybook.hexdocs.pm/theming.html)

Search documentation of phoenix\_storybook

# Visual Regression Testing

[Copy Markdown](https://phoenix-storybook.hexdocs.pm/testing.md "Copy Markdown (hold Ctrl/Cmd and click it to open as Markdown)") [View Source](https://github.com/phenixdigital/phoenix_storybook/blob/v1.5.0/guides/testing.md#L1 "View Source")

While we still encourage you writing regular unit test for your components, this doesn't protect you against visual regressions.

Visual Regression Testing consists in taking automated screenshots of your components and compare them pixel-per-pixel to notice any unwanted change.

For this we recommend using a dedicated tool such as [percy.io](https://percy.io/).

This library provides you a dedicated endpoint to output your stories (only components' stories) without the storybook main UI:

-   single story endpoint: `https://localhost:4000/storybook/visual_tests/buttons/button`
-   range story endpoint: `https://localhost:4000/storybook/visual_tests?start=a&end=e`

_The last one renders all stories whose name starting between letter 'a' and letter 'e')_

[← Previous Page Manual setup](https://phoenix-storybook.hexdocs.pm/setup.html)

[Next Page → Theming components](https://phoenix-storybook.hexdocs.pm/theming.html)

[Hex Package](https://hex.pm/packages/phoenix_storybook/1.5.0) [Hex Preview](https://preview.hex.pm/preview/phoenix_storybook/1.5.0) ([current file](https://preview.hex.pm/preview/phoenix_storybook/1.5.0/show/guides/testing.md))  [View llms.txt](https://phoenix-storybook.hexdocs.pm/llms.txt) [Download ePub version](https://phoenix-storybook.hexdocs.pm/phoenix_storybook.epub)

Built using [ExDoc](https://github.com/elixir-lang/ex_doc "ExDoc") (v0.40.4) for the [Elixir programming language](https://elixir-lang.org/ "Elixir")

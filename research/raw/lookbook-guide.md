# Introduction | Lookbook v2 Docs

<https://lookbook.build/guide>

v2.3.15

[User Guide](https://lookbook.build/guide) [Extending](https://lookbook.build/extend) [API](https://lookbook.build/api) [Demo](https://demo.lookbook.build/lookbook) 

#### Get Started

-   [Introduction](https://lookbook.build/guide)
-   [What's New](https://lookbook.build/guide/whats_new)
-   [Installation](https://lookbook.build/guide/installation)
-   [Key Concepts](https://lookbook.build/guide/concepts)
-   [Configuration](https://lookbook.build/guide/configuration)
-   [Upgrading](https://lookbook.build/guide/upgrading)
-   [Troubleshooting](https://lookbook.build/guide/troubleshooting)

#### Components

-   [Overview](https://lookbook.build/guide/components)
-   [Using with ViewComponent](https://lookbook.build/guide/components/view_component)
-   [Using with Phlex](https://lookbook.build/guide/components/phlex)
-   [Using with Partials](https://lookbook.build/guide/components/partials)

#### Previews

-   [Overview](https://lookbook.build/guide/previews)
-   [Preview Layouts](https://lookbook.build/guide/previews/layouts)
-   [Using Annotations](https://lookbook.build/guide/previews/annotations)
-   [Nav Customisation](https://lookbook.build/guide/previews/navigation)
-   [Grouped Previews](https://lookbook.build/guide/previews/groups)
-   [Dynamic Params](https://lookbook.build/guide/previews/params)
-   [Display Options](https://lookbook.build/guide/previews/display)
-   [Output Transformation](https://lookbook.build/guide/previews/output)

#### Pages

-   [Overview](https://lookbook.build/guide/pages)
-   [Frontmatter](https://lookbook.build/guide/pages/frontmatter)
-   [Rendering Previews](https://lookbook.build/guide/pages/embedding)
-   [Variables & Helpers](https://lookbook.build/guide/pages/variables)

#### Sharing

-   [Preview Embeds](https://lookbook.build/guide/sharing/embeds)
-   [Running in Production](https://lookbook.build/guide/sharing/production)

#### UI Customisation

-   [Branding](https://lookbook.build/guide/ui/branding)
-   [Color Themes](https://lookbook.build/guide/ui/theming)
-   [Inspector Panels](https://lookbook.build/guide/ui/inspector)
-   [Navigation](https://lookbook.build/guide/ui/navigation)

#### Other

-   [JSON Endpoints](https://lookbook.build/guide/json_endpoints)
-   [Tags Reference](https://lookbook.build/guide/tags)
-   [Config Reference](https://lookbook.build/guide/config)

#### On this page

-   [About Lookbook](https://lookbook.build/guide#overview)
-   [Demo app](https://lookbook.build/guide#demo)
-   [Why Lookbook?](https://lookbook.build/guide#why)
-   [Who uses Lookbook?](https://lookbook.build/guide#lookbook-users)
-   [Articles and videos](https://lookbook.build/guide#related)

User Guide / Get Started

# Introduction

## About Lookbook

**Lookbook is an open source UI development tool that helps you build modular front-end UIs in Ruby on Rails applications.**

It provides an easy-to-use web interface for **browsing and previewing** UI components in your projects, and helps you **develop, test & document** those components in isolation from each other.

Lookbook was originally designed for [ViewComponent](https://github.com/ViewComponent/view_component)\-based projects but now supports a [number of other component types](https://lookbook.build/guide/components) too!

#### This documentation is for Lookbook v2.0

See the [v1.x](https://v1.lookbook.build/) or [v0.9.x](https://github.com/lookbook-hq/lookbook/tree/0.9.x) docs if you are using an older version of Lookbook.

## Demo app

If you want to have a quick play with Lookbook, the easiest way is to [give the demo app](https://demo.lookbook.build/lookbook) a spin. It’s a basic Rails/ViewComponent app with a few test components included to tinker with.

[View the demo](https://demo.lookbook.build/lookbook)

If you’d rather dig in a bit more and run the demo app locally, the [demo repo](https://github.com/lookbook-hq/lookbook-demo) contains instructions on how to get it up and running yourself.

[

Lookbook demo app

](https://demo.lookbook.build/lookbook)

## Why Lookbook?

Many other tools similar to Lookbook exist, of which the most notable is probably [Storybook](https://storybook.js.org/).

Storybook is fantastic, and is perfect for those building UIs with JavaScript frameworks such as Vue or React. If that is what you are using, Storybook may well be a better fit than Lookbook for your project.

But Storybook _doesn’t_ play so nicely with Rails apps that are using Ruby-based, server-side rendered component frameworks (like ViewComponent) for their frontend needs, requiring complex custom setups to get everything working together.

In contrast, Lookbook has been designed to **fit seamlessly into Rails projects** and provides a live, Storybook-esque experience when developing user interfaces using ViewComponents, Phlex views or even regular ActionView template partials. If that sounds like your app, then Lookbook will hopefully be a great fit for you.

If you are using ViewComponent and want to evaluate Storybook alongside (or instead of!) Lookbook, then check out [ViewComponent Storybook](https://github.com/jonspalmer/view_component_storybook). It’s designed to help bridge the gap between Rails and Storybook and will make the process a lot easier.

## Who uses Lookbook?

-   [Aluuno](https://aluuno.com/)
-   [Clio](https://www.clio.com/)
-   [CoverageBook](https://coveragebook.com/)
-   [FreeAgent](https://www.freeagent.com/)
-   [Gitlab](https://www.gitlab.com/)
-   [GitHub](https://www.github.com/)
-   [Podia](https://www.podia.com/)
-   [Polaris ViewComponents](https://github.com/baoagency/polaris_view_components)
-   [SearchApi](https://www.searchapi.io/)
-   [Within3](https://within3.com/)
-   [Wrapbook](https://wrapbook.com/)
-   And [many more…](https://github.com/lookbook-hq/lookbook/network/dependents?package_id=UGFja2FnZS0xMDM0MzQ1)

Using Lookbook? [Send a pull request](https://github.com/lookbook-hq/lookbook/edit/main/docs/src/_guide/index.md) to update this list!

## Articles and videos

-   [Build a View Component library in Rails with Lookbook (video)](https://m.youtube.com/watch?v=Bw3wJfmg6fs)
-   [ViewComponent in the Wild II: supercharging your components](https://evilmartians.com/chronicles/viewcomponent-in-the-wild-supercharging-your-components)
-   [From partials to ViewComponents: writing reusable front-end code in Rails](https://dev.to/nejremeslnici/from-partials-to-viewcomponents-writing-reusable-front-end-code-in-rails-1c9o)
-   [Using view\_component for Design System Implementation in Rails Projects](https://showmax.engineering/articles/using-view_component-for-design-system-implementation)

[

Get Started

What's New

](https://lookbook.build/guide/whats_new)

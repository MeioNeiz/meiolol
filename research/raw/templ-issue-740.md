# proposal: deprecate CSS components in favour of 3rd party CSS pre-processors

a-h 2024-05-17T16:46:32Z

`templ css` CSS components are very basic. They don't support a range of use cases #262 including media queries, and the interpolation features are minimal. I have built a PoC of interpolating CSS values within a standard `<style>` element at https://github.com/a-h/templ-css but before jumping to implementation, I took a step back.

## People are already using pre-processors

Many users of templ are using Tailwind, or other CSS pre-processors already. They are essentially templating libraries for CSS, but can also do thing like include browser specific properties.

## Pre-processors are popular and mature

The PostCSS NPM package gets around 69.3 million downloads per week, while SASS gets around 13.5 million per week, and tailwind gets 8M. They're well established projects, with large user bases.

## templ css features are covered by existing pre-processors

`templ css` was designed so that it was possible to include classes for specific templ components, and only render the CSS if required. It dynamically generates class names to provide basic scoping. But... its design has severe limits.

Given the range of available pre-processors, their popularity, and the limited resources of the templ project, I think it might be better to spend time on improving the DX around using existing pre-processors in templ, rather than to attempt to create one, alongside everything else.

PostCSS has a plugin for scoping at https://github.com/madyankin/postcss-modules - which allows the scoping behaviour to be achieved easily, and there's a plugin for PostCSS which outputs a list of classes - https://www.npmjs.com/package/postcss-ts-classnames - in that particular case, in TypeScript format.

## We can get compile-time errors about missing CSS classes

If, for example, we created a version of `postcss-ts-classnames` PostCSS plugin which created a Go package called `class` containing a load of constants, we'd then be able to import the package into our templates, and get a strongly defined list of classes. When you write `<div class={ class.` in templ, the Go LSP would provide a list of classes in the IDE autocomplete.

This would give us the benefits of a strongly typed list of classes, for minimal development effort.

## This proposal fits well with #739

For JavaScript handling, I've proposed an alternative focus on to using JSON `script` elements, alongside `esbuild` to bundle up scripts. It solves the problems of transpiling TypeScript so you can use async/await, sorts out minification etc. you can see what that looks like at https://github.com/a-h/templ/issues/739 - esbuild is written in Go, and is very fast.

## `templ.OncePerRequest`

To ensure that links to stylesheets, or `<style>` content itself is only rendered once, a new `templ.OncePerRequest` component could ensure that children of the component are only rendered once per request, using the `ctx` parameter.

## Build process

I think the way forward on CSS is similar - with the result that you run `templ generate` to get your HTML templates, `esbuild` to covert your modern JS/TS to browser JS, and `postcss` (or whatever CSS pre-processor you want to use) to get output CSS, and get the Go web server to host the outputs at `dist`/`public`.

## Automatic (opt-in) migration for users of `templ css` and `templ script` components

There could be an automated migration path away from `templ css` and `templ script`. A `templ migrate` command could bring all the CSS together and output `scss` file(s) instead, while the scripts would be converted into JS functions in a `*.js` file.

## Consideration of project setup

These tools require a more complex setup in that you have to have `node` installed, and will need an esbuild config `mjs` file, a `package.json` and a `postcss` config, but I think that can be solved by using a tool like cookiecutter (but not cookiecutter) to create some initial app templates, e.g. basic templ hello world, templ, HTMX with typescript and postcss, or templ, HTMX with JS, tailwind etc.

## `style` attribute

Currently, the style attribute can't contain templ expressions. I think this could be relaxed, and any CSS within the style attribute could be pushed through a CSS sanitization process. This would allow the use of `style={ fmt.Sprintf("background-image: url(%v)", url) }` or the use of a dynamic builder (not implemented, just an example) `style={ css.BackgroundImage(url).PaddingPx(10, 10, 10, 10) }`.

## Summary

I think this would be a smart use of time, and would allow us to spend more time on the LSP and DX areas of templ.

Thoughts?

---
jimafisk 2024-05-17T17:02:48Z [NONE]

> These tools require a more complex setup in that you have to have node installed, and will need an esbuild config mjs file, a package.json and a postcss config

For me personally, this is something I'd _really_ like to avoid. The main reason I picked Templ over Svelte for my new app was to avoid the JS ecosystem. I'd prefer a built-in solution, even if it had less features, but of course I understand the constraints on developer time and know you have a lot of competing priorities. Templ is awesome overall, thanks for sharing your thoughts with us in real-time!

---
bastianwegge 2024-05-17T18:16:32Z [CONTRIBUTOR]

I agree with the proposal, as I don't think CSS should be a scope for templ at all. I would also like to opt out of the JS ecosystem (@jimafisk ) but I think it's almost impossible right now.

We migrated a medium sized go+react project completely to templ. As we swapped away from React components, we also needed interactivity. We looked into web-components, especially things like stencil or lit but this would ultimately bring back JS dependencies and build processes back into the project. We ended up using HTMX + Alpine.js which is an awesome combination that really drives the idea of [locality of behavior](https://htmx.org/essays/locality-of-behaviour/) and [HATEOAS](https://htmx.org/essays/hateoas/), but it definitely is not a silver-bullet and I'd be open to better solutions.

---
zoopli 2024-05-20T07:29:53Z [NONE]

I started building with templ precisely because I don't want to setup JS tooling. Integrating with them is fine as long as it's optional.

---
stuartaccent 2024-05-21T15:22:20Z [NONE]

im not advertising what ive done just a mere food for thought. Im using temple and very quickly found I needed more than the css provided so started our own way of generating css from go. very early days and still working out the best way to use it and what we need from it.

https://github.com/AccentDesign/gcss

---
a-h 2024-05-23T17:09:48Z [OWNER]

I love what you're doing there @stuartaccent.

Couple of ideas (not sure if you've already of thought of this)...

If you wanted to, you could update the `gcss.Style` type to have a `Render` method.

```go
func (s *Style) Render(ctx context.Context, w io.Writer) error {
  //TODO: Get a CSP nonce from the context.
  //TODO: Check errors etc.
  io.WriteString(w, "<style type=\"text/css\">\n")
  s.CSS(w)
  io.WriteString(w, "\n</style>")
}

func (s *Style) CSS(w io.Writer) error {
  // Existing
}
```

You could also create a `gcss.Stylesheet` type which is an alias of `[]Style`, and add the `Render` method to that too.

```go
type Stylesheet []Style

func (ss Stylesheet) Render(ctx context.Context, w io.Writer) error {
  //TODO: Get a CSP nonce from the context.
  //TODO: Check errors etc.
  io.WriteString(w, "<style type=\"text/css\">\n")
  for _, s := range ss {
    s.CSS(w)
  }
  io.WriteString(w, "\n</style>")
}
```

Doing this would mean that `gcss.Style` and `gcss.Stylesheet` both implement `templ.Component` and you can drop styles into components. Combined with the new `templ.Once` function (https://github.com/a-h/templ/pull/750), you'd be able to have CSS that's only loaded once per HTTP request.

So, defining a set of styles as a `templ.Component` that's only rendered once per HTTP request.

```
package deps

var buttonStyles = gcss.StyleSheet{
	{
		Selector: ".button",
		Props: gcss.Props{
			AlignItems:     props.AlignItemsCenter,
			BorderRadius:   radius,
			Display:        props.DisplayInlineFlex,
			FontSize:       fontMd,
			FontWeight:     props.FontWeightMedium,
			Height:         spacing10,
			JustifyContent: props.JustifyContentCenter,
			LineHeight:     leadingTight,
			PaddingTop:     spacing2,
			PaddingRight:   spacing4,
			PaddingBottom:  spacing2,
			PaddingLeft:    spacing4,
		},
	},
	// More...
}

var buttonStylesHandle = templ.NewOnceHandle()

templ ButtonCSS(ctx context.Context, w io.Writer) (err error) {
  @buttonStylesHandle.Once() {
    @buttonStyles()
  }
}
```

Then, using those CSS classes as components in templ:

```templ
package components

templ Button(name string) {
  @deps.ButtonCSS
  <button class="button">{name}</button>
}

templ ButtonPrimary(name string) {
  @deps.ButtonCSS
  <button class="button-primary">{name}</button>
}
```

If you then use `Button` and `ButtonPrimary` on a page (bad API design, I know, it's just as an example - https://gopress.io/ uses a struct for attrs which is likely more appropriate here).

But, in this case the CSS would only be loaded into the page as a `<style>` element if required by the component.

Obviously, I'm not aware of `gcss`, so maybe you've already discounted these ideas. 😁 

Either way, it looks very great.

---
stuartaccent 2024-05-24T09:37:48Z [NONE]

thanks, @a-h that looks like a solid idea i will take a look.

cheers stu.

---
Riu 2024-06-04T01:02:33Z [NONE]

As a [Gopress](https://gopress.io) creator, all I can say is - CSS in template engines is a huge topic. It is important to answer the questions: what architecture are we creating for, where and how will we embed styles, what do we want to share/reuse or what should be global, how will we introduce changes (e.g. after changing from the UI designer in Figma). Some challenges:

- if you have inline css then there will be problem with global changes;
- if you put styles in files you need to serve only what you use;
- if you are rendering mail templates maybe you need pure inline css;
- if you have got microfrontends/htmx architecture, then the number of challenges doubles;
- if you would like to make library components like we have in FE frameworks (scoped styles), you should not render `<style>css code</style>` every time you render arrays of components;
- much, much more...

Gopress has a very unique approach in that we have sets of Tailwind classes that are transferred one-to-one from Golang to, for example, Vue, because we use an atomic design approach. These sets create variants based on attributes. Instead of classes you can use just pure css (it will be worse DX, but the effect can be more or less the same). DX is very important - you can see immediately what styles the class gives (syntax suggestions from Tailwind). The component is isolated and the only dependency is the Tailwind configuration file. 

Because Tailwind is also not perfect i'm working on alternative solution (without Tailwind) and one more thing - by design, Gopress was built in such a way that components could be generated and changed from an application designed for this purpose. This is related, on the one hand, to AI and, on the other hand, to the problem of technology adoption. 

Gcss is interesting because it has no dependency and in some cases it can be good solution, definitely worth attention.

---
gamebox 2024-06-18T11:12:02Z [NONE]

> style attribute
> Currently, the style attribute can't contain templ expressions. I think this could be relaxed, and any CSS within the style attribute could be pushed through a CSS sanitization process. This would allow the use of style={ fmt.Sprintf("background-image: url(%v)", url) } or the use of a dynamic builder (not implemented, just an example) style={ css.BackgroundImage(url).PaddingPx(10, 10, 10, 10) }.

This is very much needed. I am trying to use Templ for HTML Emails, and am finding that this _undocumented_ restriction on `style` elements is very much a roadblock to success.  Even in 2024, inline style blocks still do not have the necessary email client support to allow me to use them, so the existing CSS tooling in Templ falls short for me there.  And to your point, if they worked I'd be doing something with Tailwind to do this anyway as that is my normal workflow for web page HTML.

I think that not baking this in from the start - or at the absolute minimum, documenting it - was a mistake.  I know that the design philosophy behind Templ is to be helpful, sometimes erring on the side of being "hand holdy", but these sorts of seemingly arbitrary restrictions can lead to a lot of disillusionment from developers just trying to ship product.

Oh, and one last thing I'll mention is I agree with @jimafisk that I too do everything I can to avoid having a `package.json` in my application.  I vendor HTMX, and only work with the `tailwindcss` executable.

### For context

This is all I want to be able to do in an HTML Email.  I want to keep my color scheme and theme information the same so I want to use some `const`s to do so in inline styles:

```templ
templ emailLayout() {
    <!-- Don't worry about the rest -->
    <body style={ "margin:0; padding:0; background-color:"+common.BackgroundColor+";" }>
    <!-- Don't worry about the rest -->
}
```

### One very last thing...

I have a similar issue with the `<!DOCTYPE>` tag, there is a much more expressive grammar allowed inside of that tag than what Templ allows for, and not utilizing it can cause compatibility concerns with Emails.  I can understand that you may not care to support HTML Email authoring in Templ - but it's a big and important use case for web services, so you should at least consider that use case.

---
zyriab 2024-07-02T10:23:02Z [NONE]

I think keeping a minimal in-house solution and allowing the user to plug in something else if they want is a good approach.


---
joerdav 2024-07-04T07:56:42Z [COLLABORATOR]

@a-h I think we are circling a decision here. It may be worth us splitting this into a few different features...

- Allow dynamic style attributes
- Document recommended approaches going forward
- Add a generate warning for use of `css`/`script` components
- Create migration that converts `css`/`script` components to use script/style tags
- Remove `script`/`css` components

---
cevdetch 2024-08-07T14:03:21Z [NONE]

In my opinion, using build system should be optional but even when we use templ, we have a build step that generates go files. So what we can do is getting the best solution (performance and compability) into the build system in order to achieve faster builds and better developer experience.

My suggestion would be using [lightningcss](https://lightningcss.dev/)[[repo](https://github.com/parcel-bundler/lightningcss)].

---
matthewmueller 2024-09-03T04:12:36Z [CONTRIBUTOR]

Just started playing around with Templ today. Really great project! This was one of the first questions I bumped up against, "how do I style more than one element at a time?"

I'd really like Templ to provide a native solution, similar to how Next.js supports [styled-jsx](https://github.com/vercel/styled-jsx) as an out-of-the-box CSS solution, but you can supplement with Tailwind, etc.

I'm still new to Templ so I'm not quite sure about solutions yet, but I maintain https://github.com/matthewmueller/css and https://github.com/matthewmueller/styledjsx, which is basically styled-jsx but in pure Go. Something like this coupled with ESBuild's CSS support for browserlist, I do feel like we have all the pieces built out in the Go ecosystem.

---
a-h 2024-09-03T17:48:47Z [OWNER]

Interesting! @matthewmueller - we should probably get together and chat about it, if you're interested in chasing down an implementation.

I have an example of using tdewolff's parser to add in support for interpolated variables, see https://github.com/a-h/templ-css/blob/7cb95993e63562ff6aa2c84f69feb1a9ff51dd68/parse_test.go#L29-L40

Perhaps there's a way to use your css parser and do something similar? The steps would be something like:

* Parse CSS and interpolated variables into a tree of nodes (AST)
* Ensure the AST can write itself back out (that's how the `templ fmt` command works), but formatted so that CSS is auto-formatted by templ
* Write a generator that takes those nodes and writes out the runtime Go code for rendering the static and interpolated values
* Update syntax highlighting patterns to include support for the new syntax

---
matthewmueller 2024-09-04T02:51:44Z [CONTRIBUTOR]

Definitely down to chat more about the design! But here's some initial thoughts:

> I have an example of using tdewolff's parser to add in support for interpolated variables, see https://github.com/a-h/templ-css/blob/7cb95993e63562ff6aa2c84f69feb1a9ff51dd68/parse_test.go#L29-L40

I just tested this in [this commit](https://github.com/matthewmueller/css/commit/356a95af19c729a2b960eb22acdcf9d8a7f25419#diff-f8625058bbc944e30e69a0e09139ecd3e0d510f768ecebf132c5182d27f67503R285-R312). So `{{red}}` doesn't parse because it's invalid CSS, but I did provide a couple options that are also valid CSS in that commit.

Would you be open to different syntax? We could also do something custom for Templ if `{red}` would be best.

> Ensure the AST can write itself back out (that's how the templ fmt command works), but formatted so that CSS is auto-formatted by templ

This is possible today. After you manipulate the AST, you can print it back out via `stylesheet.String()` ([code](https://github.com/matthewmueller/css/blob/356a95af19c729a2b960eb22acdcf9d8a7f25419/ast/ast.go#L23-L32)). I'd imagine we could store the `ast.Stylesheet` within Templ's AST.

> Write a generator that takes those nodes and writes out the runtime Go code for rendering the static and interpolated values

This should also be possible, you could even translate from a CSS AST to a Go AST, then print out the Go AST.

---

Stepping back a sec, one of the big challenges in the component world is making sure styles from the parents don't leak into the child components. Unfortunately nested CSS doesn't help with this:

```css
.parent {
  a {
    background: red;
  }
}
```

```html
<div class="parent">
  @Child()
</div>
```

```html
<div class="child">
  <a>some link</a> <!-- oh noz, I'm red -->
</div>
```

Personally, I'd love for Templ to take care of this issue for us.

---

Spitballing on solutions, I think what I'd like to see is a remix on:

```go
handler := NewCSSMiddleware(httpRoutes, c1)
```

But instead of middleware taking classes one-by-one, it's a handler that takes a filesystem, something like:

```go
//go:embed view/**/*.templ
var fsys embed.FS

router.Get("/templ.css", templ.Stylesheet(fsys))
```

Then upon request, it traverses the `.templ` files, looking for styles, gathers them, dedupes them and bundle them all together. In production, you'd cache this sheet, run the output through esbuild adding vendor prefixes and minifying.

You'd need to transform the `.templ` files themselves with a hashed class name of the CSS, maybe in the presence of `<style scoped>`, it appends a `css-[hash]` onto each HTML element in the generated output:

**Before transform**

```templ
templ Story(story *hackernews.Story) {
  <div class="story">
    <div>
      <a>
        { story.Title }
      </a>
      if story.URL  != "" {
        <a class="url" href={ templ.URL(story.URL) }>({ formatURL(story.URL) })</a>
      }
    </div>
    <div class="meta">
      { strconv.Itoa(story.Points) } points by { story.Author } • { " " }
      @Time(story.CreatedAt)
    </div>
    <style scoped>
      .story {
        background: red;
      }
      .url {
        text-transform: none;
      }
      .meta {
        padding: 10px;
      }
    </style>
  </div>
}
```

**After transform**

```templ
templ Story(story *hackernews.Story) {
  <div class="css-123abc story">
    <div class="css-123abc">
      <a class="css-123abc">
        { story.Title }
      </a>
      if story.URL  != "" {
        <a class="css-123abc url" href={ templ.URL(story.URL) }>({ formatURL(story.URL) })</a>
      }
    </div>
    <div class="css-123abc meta">
      { strconv.Itoa(story.Points) } points by { story.Author } • { " " }
      @Time(story.CreatedAt)
    </div>
  </div>
}
```

Then the served CSS ends up being something like:

```css
.css-123abc.story {
  background: red;
}
.css-123abc.url {
  text-transform: none;
}
.css-123abc.meta {
  padding: 10px;
}
```

Sorry, this ended up being longer than I expected. Hope this helps! Also happy to sync on this. Thanks for entertaining the idea of having batteries-included CSS in Templ!

**Update** So for fun I stuck the component above into https://github.com/matthewmueller/styledjsx and it mostly works! Here's the draft PR: https://github.com/matthewmueller/styledjsx/pull/1. If there's interest, I'll look into making `styledjsx` work with Templ and then I'd just need some help figuring out the integration point with Templ.

---
a-h 2024-09-05T07:01:30Z [OWNER]

This is very interesting, and your demo looks great!

I'm keen to have a scoped CSS capability in the templ ecosystem to meet exactly the challenge you described - the ability to ship components that are not affected by inheriting scope.

templ has a parser in it, you can parse a templ file into nodes using the https://github.com/a-h/templ/blob/3ac3c9de53ad81f43d70bebfb642a89c2c69a4c1/parser/v2/templatefile.go#L13 function, then it's possible to walk the nodes using a function like https://github.com/a-h/templ/blob/3ac3c9de53ad81f43d70bebfb642a89c2c69a4c1/parser/v2/diagnostics.go#L15-L33 which is used for producing warning diagnostics.

This capability doesn't have to be within templ itself, but great if it is.

In terms of syntax, I'm flexible on what that could / should look like.

What I'm hearing from templ users is that they want to be able to:

* Use Go values in CSS values: `color: { colorVariable }`
* Use Go values in partial values: `background: 1px { lineType } { color }`
* Merge key/values / CSS from the Go side into the client-side CSS
* Use conditionals etc.
* Use media queries etc.

I'm really keen that templ should nudge users towards security - i.e. make it harder to do the wrong thing, e.g. templ's existing CSS components protect against unsafe CSS property values.

I'm also keen that it's something we can maintain with a small number of people over a long period of time. I'd like to be conservative in features - not box ourselves in, but give ourselves scope to add features later.

Are you on the Gopher's Slack? If so, should we schedule a Slack call and kick about some ideas? Ideally, we'd end up with a proposal doc that outlines the target features, the expected syntax, and the expected output Go code.

---
Riu 2024-09-05T18:18:01Z [NONE]

Please, remember about few things:

- if you want make scoped block with css, it should/can be outside any html tag;
- you can't optimize the size of the final css code - it will be problem in large projects(large number of components);
- you need care about potential name conflicts if you would like render microfrontends;
- what about global variables, "reset" file, etc?
- what about many variants, with many values ​​for making themes?

---
a-h 2024-09-06T08:52:55Z [OWNER]

Would you be up for joining a conversation about this topic @Riu? Your real-time input would be very valued.

---
matthewmueller 2024-09-09T05:22:34Z [CONTRIBUTOR]

@a-h Awesome!

> What I'm hearing from templ users is that they want to be able to:

Great to hear this is coming from user feedback! At the risk of going against this feedback, I'm on the fence about interpolation within CSS for two reasons:

1. The `{interpolation}` syntax requires extending a CSS parser. https://github.com/matthewmueller/css is not 100% complete. It parses some most big CSS frameworks, but it's definitely not battle-tested. I can definitely commit to fixing bugs and addressing missing features, but it'd be nice to stick with standards in case a more robust CSS parser comes along. Svelte had some similar discussions around this topic: https://github.com/sveltejs/svelte/issues/758#issuecomment-321039837. This concern certainly goes away if we go with something like `var(interpolation)`.

2. Toggling classes might be good enough. Typically when you want dynamic CSS, you're swapping between a known set of values (e.g. light, dark theme). That's doable today with `<div class={"container " + templ.KV("dark", isDark)}>`. In the rare cases when you want a fully dynamic value, you can do `<div style={"background-color: " + color}>`. I believe this is where we'd need the safe CSS sanitation.

So my personal opinion is that this is a reasonable place to be conservative on features. At the very least for the initial release.

> This capability doesn't have to be within templ itself, but great if it is.

Cool, I was just learning more about Templ these last couple days. I'll look into contributing next!

> I'm also keen that it's something we can maintain with a small number of people over a long period of time. I'd like to be conservative in features - not box ourselves in, but give ourselves scope to add features later.

Big fan of this approach!

> Are you on the Gopher's Slack? If so, should we schedule a Slack call and kick about some ideas? Ideally, we'd end up with a proposal doc that outlines the target features, the expected syntax, and the expected output Go code.

Yep! Just dropped a message and will drop follow-up questions when I start the implementation. Also down to sync. I'm free most evenings (US timezone) and weekends.

---

@Riu thanks for the call outs. +1 it would be good to learn more about these. Let me try and answer a few:

> if you want make scoped block with css, it should/can be outside any html tag;

I'm really curious about this. Since the scoping applies to the HTML, I'm unsure why you'd want to support scoped block outside of any HTML tag.

> you can't optimize the size of the final css code - it will be problem in large projects(large number of components);

This is mostly true. Since you're hashing the CSS contents, you can dedupe <style> tags that have the same contents, but not the declarations, so you will end up with e.g.  `.css-123abc.story { margin-bottom: 10px }` and `.css-123abc.comment { margin-bottom: 10px }`.

>you need care about potential name conflicts if you would like render microfrontends;

Can you elaborate? 

>what about global variables, "reset" file, etc?

Reset files would just be additional `<link>` or bare `<style>` tags .

And yah, we'd probably want support for the global pseudo-class, e.g. `.markdown :global(a)`.

> what about many variants, with many values ​​for making themes?

I think I responded to this when talking about dynamic styles. Let me know if you mean something different!







---
Riu 2024-09-11T19:09:54Z [NONE]

@a-h I'm available from next week, so let's talk.
@matthewmueller so:
- scope: I thought about approach from Vue/Angular - `<template>html code</template><style>css</style><script>js/ts</script>`. Let's separate the layers of responsibility/languages/syntax. It will be better for DX and much more flexible.
- microfrontends: if you have separated microfrontends, you need an additional prefix to ensure unique class names (because uncontrolled inheritance of properties may occur) - the solution is a design system, but then there is a problem with sharing variables between micro frontends / teams working on them. This case is tricky, so worth for mention.
- variables: values (global) ready to use in style tag - for example you will use `margin: $margin-sm` instead of `margin: 10px` because you want flexibility for making variants - again - this is about sharing some variables between components.
- variants: I simply encourage you to make a component with button-type variants from some Figma design system - this is a great practical test of the approach to building variants when you have task from ui/ux designer - have you got somewhere some demo/live example of using your approach?
This is really interesting what you are doing. Thanks for the inspiration!

---
joerdav 2024-09-12T09:18:53Z [COLLABORATOR]

> if you have separated microfrontends, you need an additional prefix to ensure unique class names

Is this true @Riu ? If the resulting name was a hash of the css contents the likelihood of a clash could be reduced, and if there was a clash the likely reason is that the classes have the same contents. Maybe this is a naive view.

---
Riu 2024-09-12T10:33:36Z [NONE]

> > if you have separated microfrontends, you need an additional prefix to ensure unique class names
> 
> Is this true @Riu ? If the resulting name was a hash of the css contents the likelihood of a clash could be reduced, and if there was a clash the likely reason is that the classes have the same contents. Maybe this is a naive view.

In this example: https://github.com/a-h/templ/issues/740#issuecomment-2327812939 hash is `123abc` (created in build) so it will work without a problem because that's what the prefix does. I just want to point out that this uniqueness should be guaranteed in different architectures, and of course - we can add another layer of abstraction in process (esbuild), but I'm not sure that this is best way because then templ components depend on esbuild. Hash is random, prefix is constant and unchanging, so you can use that also for communication between microfrontends - trigger some reaction in another component - HTMX integration (with data, id, rel, etc). 

---
zimdo 2024-12-07T20:23:16Z [NONE]

Hey @a-hm, @matthewmueller Did this discussion ever go anywhere? Is a feature planned? I really dislike what using Tailwind does to the HTML... classes littered everywhere. Would love to implement my current project using some JSX / Svelte style components.

---
nexovec 2024-12-09T15:42:12Z [NONE]

I really like how there is no real build step outside of templ. I'd hate it if an entire extra build process with something like postcss and esbuild became the recommended practice.

What I need that's not really covered by templ is for example to be able to write a metaprogram of sorts to detect if my combination of css classes is valid, or check if my html element name conforms to accessibility norms. A plugin system could be made that would allow hooking into templ's behavior like described to allow for that extra layer of extensibility. If people want, they can call the however many css preprocessors the cool kids have nowadays from there. Such adapters will be written once for most of the popular tooling and then everyone can use it. Then everyone will be happy forever.

I agree css and script blocks should be gone. It's scope creep in my eyes.

That's how I would do this.

---
matthewmueller 2024-12-10T01:09:50Z [CONTRIBUTOR]

Hey @zimdo, thanks for the prompt! I stepped away from working on UI stuff for a bit, but still planning on coming back to this! If anyone feels like picking it up in the meantime feel free!

@a-h, one thing that could be nice is a way to add plugins to Templ. This implementation could then start outside of core initially and be one of many experiments. There might already be a way to do this (if there is, please let me know!) but after briefly reading through the code and docs, I didn't see anything.

Two ideas along this vein of preprocessors:

**1. Allow users to programmatically generate Templ**

So you could basically create your own `templ generate` and programmatically add plugins, something like:

```go
package main

func main() {
  t := templ.New(dir)
  t.Use(scopedcss.New())
  err := t.Generate(ctx, "**/*.tmpl")
}
```

**2. Spawn plugins from the CLI**

```sh
templ generate --plugin=./scopedcss ./...
```

where `./scopedcss` is a main function that gets spawned by templ, gets a list of templ files and can preprocess those templ files in some way, passing them back to the main code generator.

---
a-h 2025-01-03T11:01:03Z [OWNER]

OK, another shot at this... I think this is what @nexovec is talking about.

CSS has built-in variables now, so there shouldn't be much need for templating in CSS, and if you do want to do that, you can use Sass to pre-process into standard CSS.

```css
.withBackgroundColor {
  background-color: var(--bgcolor, #eee);
}
```

But, there's two problems - knowing that `withBackgroundColor` is a valid CSS class name at autocomplete / compile time, and also passing a Go variable for use as background color.

## Generate Go code from CSS

We can use tdewolff's CSS parser to parse the CSS and generate Go code that contains the class names: https://github.com/a-h/templ-css/blob/main/cmd/main.go

For the above CSS file, you would get a go file like:

```
go run ../cmd/. generate --file-name=./css/styles.css --package="css" > ./css/styles.go
```

```go
package css

func WithBackgroundColor() string {
	return "withBackgroundColor"
}
```

You could imagine this CSS Go file output being built into the `templ generate` process so there's no extra step.

Since the CSS class names are the results of Go functions (I think I would prefer if they were constants or something), the templ LSP already provides auto complete, and compile time checks:

```templ
	<div class={ css.WithBackgroundColor() }>
		Contents
	</div>
```

I'm pretty sure we could add a Sass processor to the generate process too.

## Provide a way to set CSS properties

Now, we need to set those css properties.

```templ
templ Page(backgroundColor string) {
	<!DOCTYPE html>
	<html>
		<head>
			<title>Page</title>
			<link rel="stylesheet" href="/css/styles.css"/>
		</head>
		<body>
			@cssprops.Set(cssprops.New("--bgcolor", backgroundColor))
			<!-- Note how we're able to use auto-completion for the CSS class name. -->
			<div class={ css.WithBackgroundColor() }>
				Contents
			</div>
		</body>
	</html>
}
```

`cssprops.Set` is just a templ component that writes some JS out to set the variable:

```go
package templcss

import (
	"context"
	"html"
	"io"

	"github.com/a-h/templ"
	"github.com/a-h/templ/safehtml"
)

type prop struct {
	Property string `json:"property"`
	Value    string `json:"value"`
}

func New(property, value string) prop {
	p, v := safehtml.SanitizeCSS(property, value)
	return prop{
		Property: p,
		Value:    v,
	}
}

func Unsanitized(property, value string) prop {
	return prop{
		Property: property,
		Value:    value,
	}
}

func Set(properties ...prop) templ.Component {
	jsonString, err := templ.JSONString(properties)
	return templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		if err != nil {
			return err
		}
		io.WriteString(w, "<script type=\"text/javascript\" data-variables=\"")
		io.WriteString(w, html.EscapeString(jsonString))
		io.WriteString(w, "\">\n")
		io.WriteString(w, "const props = JSON.parse(document.currentScript.getAttribute(\"data-variables\"));\n")
		io.WriteString(w, "const r = document.querySelector(\":root\");\n")
		io.WriteString(w, "props.forEach(p => { r.style.setProperty(p.property, p.value); alert(JSON.stringify(p)) });\n")
		io.WriteString(w, "</script>\n")
		return nil
	})
}
```

There's an example of it running at https://github.com/a-h/templ-css/tree/main/example

What I like about this approach is that it doesn't require any parsing tricks. Fairly easy to implement, and uses standard CSS. It could be used with Tailwind or other CSS libraries to generate Go code for utility classes.

---
joerdav 2025-01-07T17:01:04Z [COLLABORATOR]

I like this idea because it means people can just write regular css and use it in a template.

Do we think there is a way for this to fit into scoped styles? For example creating styles for a specific component, and even exposing a component library?

---
epicbytes 2025-01-07T17:11:06Z [NONE]

I have been using TailwindCSS for quite some time now. I have my own build system with watchers. My interest in raw CSS is very minimal, considering that the fourth version of TailwindCSS will drop support for JS. However, the idea of removing CSS work from templates seems quite sensible. It would be great not only to run commands via flags but also to incorporate middleware for template processing after generation so that post-processing works predictably.

---
matthewmueller 2025-01-07T17:16:52Z [CONTRIBUTOR]

Interesting idea!

> I like this idea because it means people can just write regular css and use it in a template.

+1, I like this about the proposal too, it feels like a very natural API.

As @joerdav mentioned, it doesn't really solve the scoping issue, which is a bigger issue in the component world (search "Stepping Back" in this issue above for rationale) and imo is a must-have for any CSS solution.

One way the React world solved scoping was through [CSS Modules](https://github.com/css-modules/css-modules) and ESBuild has built-in support for this: https://esbuild.github.io/content-types/#local-css. It's a minimal solution and still gets the job done.

On the proposal itself, I'm not quite sure why the `@cssprops.Set(cssprops.New("--bgcolor", backgroundColor))` was necessary, could we codegen `css.WithBackgroundColor(backgroundColor)`?

I personally prefer scoped css as a better end-user solution despite the parsing complexity because in practice this proposal (and CSS modules) leads to every HTML element needing `css.SomeClass()` or `class=${styles.someClass}`, whereas scoped css just looks like plain HTML.

**Edit**

> It would be great not only to run commands via flags but also to incorporate middleware for template processing after generation so that post-processing works predictably.

+1 to being able to run hooks

---
a-h 2025-01-07T21:30:55Z [OWNER]

Brilliant feedback folks.

> It would be great not only to run commands via flags but also to incorporate middleware for template processing after generation so that post-processing works predictably.

Got any idea of what hooks would look like? Is that an extra CLI parameter to `templ generate` like, `templ generate --post-build="esbuild"`, or something else?

> On the proposal itself, I'm not quite sure why the @cssprops.Set(cssprops.New("--bgcolor", backgroundColor)) was necessary, could we codegen css.WithBackgroundColor(backgroundColor)?

Oh yeah! Completely possible to do that. Good idea! It would be  `@css.SetBackgroundColor(backgroundColor)` though right? (Since it wouldn't return anything.)

> I personally prefer scoped css as a better end-user solution despite the parsing complexity because in practice this proposal (and CSS modules) leads to every HTML element needing css.SomeClass() or class=${styles.someClass}, whereas scoped css just looks like plain HTML.

This is interesting. Something I hadn't thought of. I'd be up for integrating esbuild into templ to provide scoped CSS. There's a Go module: https://pkg.go.dev/github.com/evanw/esbuild@v0.24.2/pkg/api

For files called `*.module.css`, `temp generate` could generate CSS classes that are scoped to the Go package name, and CSS filename, but hashed, e.g. a CSS class of `.background` in `github.com/a-h/components/components/button.module.css` would result in a filed called `github.com/a-h/components/components/button_module_css.go` with a variable in it called `Button`. That `Button` variable would have a field called `Background` with the value of `<sha256_hash_of_github.com/a-h/components/components/button.module.css>_background`.

For `*.css` files, the class names would be bundled into a single file for the Go package, e.g. `css/styles_templ.go` and not prefixed etc.

While it generates (using esbuild or whatever) a CSS file with those identifiers, it could also generate a variable that contains a mapping of the unscoped class name (e.g. `background`) to `10ce074d1e82348f699079e917081fdfd2324e4435489321654c9bf6f4be2d23_background`. The variable would be called `generatedpkgname.<FileName>`, e.g. `generatedpkgname.Button`.

Then, a `templ.WithScopedCSS` component could simply set (or add to) a context variable that contains that mapping. 

```templ
templ Component() {
  @templ.WithScopedCSS(generatedpkg.Button.All) {
     <div class="background">Click</div>
  }
}
```

Currently, `class=""` attributes are parsed into a `ConstantAttribute`, but we could make an exception for the `class` attribute. It could be parsed into a new `ClassAttribute` which has specific code generation that looks for the context value, and if a matching class value is present, replace it with the mapped value.

Existing `ExpressionAttribute` code could be updated to support the new behaviour too, so that `class={ "button" }` would also be covered.

So, the output HTML would be something like:

```html
<div class="10ce074d1e82348f699079e917081fdfd2324e4435489321654c9bf6f4be2d23_background">Click</div>
```

templ would only add the hash prefix to files that are called `*.module.css`, so you can still just get autocomplete for non-module CSS using expression attributes,  and forego the `templ.WithScopedCSS` wrapper if you use an expression attribute, so:

```templ
templ Component() {
   <div class={ generatedpkg.Button.Background }>Click</div>
}
```

Would also output:

```html
<div class="10ce074d1e82348f699079e917081fdfd2324e4435489321654c9bf6f4be2d23_background">Click</div>
```

Since we're generating code, we could bundle all the CSS into the Go as constants in the generated code, along with 2 templ components to render it (one that creates a `<style>` element with the CSS content in and one that does a `<link>` element that points to the URL) and a HTTP handler to render the CSS file...

```templ
templ Component() {
  @templ.Once() {
    // Would render `<style>.10ce074d1e82348f699079e917081fdfd2324e4435489321654c9bf6f4be2d23_background { background-color: red }</style>`
    @generatedpkg.Button.Style()
  }
  @templ.WithScopedCSS(generatedpkg.Button) {
     <div class="background">Click</div>
  }
}
```

```templ
templ Page {
  <head>
    // Would generate `<link href="/styles/10ce074d1e82348f699079e917081fdfd2324e4435489321654c9bf6f4be2d23_button.css" rel="stylesheet">
    @generatedpkg.Button.Link()
  </head>
}

func main() {
  // generatedpkg.Button.URL would be something like `/styles/10ce074d1e82348f699079e917081fdfd2324e4435489321654c9bf6f4be2d23_button.css`
  // generatedpkg.Button.Handler would be a HTTP handler that outputs the CSS bundle.
  http.Handle(generatedpkg.Button.URL, generatedpkg.Button.Handler)
}
```

Thoughts?

---
epicbytes 2025-01-08T21:09:30Z [NONE]

> Thoughts?

In my opinion, templ should not continue the practices of React developers, as it is a completely different approach to building web interfaces. Generating such a large hash will not give any advantages and will only complicate troubleshooting in the future.

I will continue to praise the use of atomic styles because they are transparent and manageable, can be mutated through CSS variables.

All that I personally lack, and I will try to propose my experience anyway (because I feel that everyone wants a React-like system), and based on this, all I lack is a build system that correctly configures.

For example, I saw templui; there was something in it that I didn't like about embedding SVG with constant generation when calling an icon, because I use sprites and my optimizer, which does AST and creates an optimal bundle of 1500 icons I have a sprite of 20.

CSS styles I run tailwindcss in --watch mode and there are no problems with this.

The only thing that's not quite right is the CSS model in templ for me personally, because I describe my design system without touching what's already in templ now. Because a waterfall of makefile calls from dependencies on executing previous scripts appears. This is not very convenient, because in the end, I am already working with *.go files.

Therefore, it would be interesting to receive middlewares at the moment when a particular file is generated in templ.

It turns out that I even do not use the watch mode for templ because it's extra for me.

But still, I have the opportunity to run optimizers and other additional things, but relying on fsevent launched next to it.

---
a-h 2025-01-09T09:06:06Z [OWNER]

Thanks for your comments!

> Generating such a large hash will not give any advantages and will only complicate troubleshooting in the future.

I agree that the hash is almost silly in how long it is. It could be replaced, I'm just not sure what with. Initially, I thought it would be ideal if it was the Go module name, and path as-is, because that would be great for troubleshooting, e.g. `github_com_a_h_project_css_styles_css_<class_name>`, but I switched to a SHA256 hash to start because I figured that the Go module name might be private, e.g. give away the domain of your internal Gitlab etc., and the path to the CSS in the repo could also give away some sort of information about internal structure.

I had to increase the hash size for autogenerated CSS a couple of weeks ago, because in some use cases, collisions were more likely. https://github.com/a-h/templ/commit/9c8ad4d85739285905494435bfd4b76455a3f98f - so, maybe 8 hex characters of the hash is enough. 😁 

re: atomic styles, FWIW I'm using Tailwind in my current project, and enjoying it. Scoped CSS is handy if you're making a component library though.

---
a-h 2025-01-09T09:12:37Z [OWNER]

This morning, I updated https://github.com/a-h/templ-css with scoped CSS support.

I also started taking in @matthewmueller's idea about plugins (https://github.com/a-h/templ/issues/740#issuecomment-2529956233) and added the concept of a `CSSPlugin`.

A CSS plugin is a thing that can process CSS input https://github.com/a-h/templ-css/blob/99839f7e45f501f73fdce6f19c3eb8b81e05074a/cmd/main.go#L33-L46

In the example repo, there's 3 plugins to start: https://github.com/a-h/templ-css/blob/99839f7e45f501f73fdce6f19c3eb8b81e05074a/cmd/main.go#L48-L55

One for SCSS, one for `module.css`, and one for plain old CSS files.

So, for the `components.module.css` file in the root of the repo:

```css
.background {
  background-color: #f0f0f0;
}
```

```
go run ./cmd/. generate --file-name=components.module.css --package=styles
```

```css
.templ_css_2e6261636b67726f756e64207b0a2020_background {
  background-color: #f0f0f0;
}
```

```go
package styles

const Background = "templ_css_2e6261636b67726f756e64207b0a2020_background"
```

The interface for plugins would need to evolve, but I think it could work.

---
a-h 2025-01-09T09:16:36Z [OWNER]

I agree with @epicbytes that there's a danger of porting some annoying parts of the TypeScript / React ecosystem like complex build processes etc. so that's something to be wary of.

I've been trying to keep things simple enough to avoid a config file. 😂 

---
joerdav 2025-01-09T09:21:54Z [COLLABORATOR]

I think that pattern around components works. My thought is about how this would be imported from a component library, it seems like it wouldn't be as simple as just rendering the component, you might have to serve some css too?

---
a-h 2025-01-09T09:33:51Z [OWNER]

The example repo doesn't do this (yet), but I thought this might work.

> Since we're generating code, we could bundle all the CSS into the Go as constants in the generated code, along with 2 templ components to render it (one that creates a `<style>` element with the CSS content in and one that does a `<link>` element that points to the URL) and a HTTP handler to render the CSS file...
> 
> ```templ
> templ Component() {
>   @templ.Once() {
>     // Would render `<style>.10ce074d1e82348f699079e917081fdfd2324e4435489321654c9bf6f4be2d23_background { background-color: red }</style>`
>     @generatedpkg.Button.Style()
>   }
>   @templ.WithScopedCSS(generatedpkg.Button) {
>      <div class="background">Click</div>
>   }
> }
> ```
> 
> ```templ
> templ Page {
>   <head>
>     // Would generate `<link href="/styles/10ce074d1e82348f699079e917081fdfd2324e4435489321654c9bf6f4be2d23_button.css" rel="stylesheet">
>     @generatedpkg.Button.Link()
>   </head>
> }
> 
> func main() {
>   // generatedpkg.Button.URL would be something like `/styles/10ce074d1e82348f699079e917081fdfd2324e4435489321654c9bf6f4be2d23_button.css`
>   // generatedpkg.Button.Handler would be a HTTP handler that outputs the CSS bundle.
>   http.Handle(generatedpkg.Button.URL, generatedpkg.Button.Handler)
> }
> ```


---
matthewmueller 2025-01-13T04:05:10Z [CONTRIBUTOR]

Awesome work @a-h! I really like where this is heading. Here's some random thoughts.

---

> CSS styles I run tailwindcss in --watch mode and there are no problems with this.
> re: atomic styles, FWIW I'm using Tailwind in my current project, and enjoying it. Scoped CSS is handy if you're making a component library though.

Component libraries are a great use case! I also think in real-world apps, there's a "last-mile" which Tailwind has continued to chip away at (especially with dynamic styles), but can still be a more convenient to style with a CSS class. Imagine trying to create a complex `@keyframe` in Tailwind.

---

> In the example repo, there's 3 plugins to start: https://github.com/a-h/templ-css/blob/99839f7e45f501f73fdce6f19c3eb8b81e05074a/cmd/main.go#L48-L55

Forgive my naivety, but I'm not seeing how this gets wired up to Templ? I'd love to try hacking around on a plugin as well!

---

```templ
@templ.WithScopedCSS(generatedpkg.Button) {
  <div class="background">Click</div>
}
```

It might just be my unfamiliar eyes, but if we're parsing HTML anyways, I still feel like a more natural API would be something like:

```templ
templ Component() {
  <div class="background">
    Click
    <style scoped>
      .background {
        color: blue;
      }
    </style>
  </div>
}
```

---

> maybe 8 hex characters of the hash is enough

For hashing, I think a lot of the CSS libraries use murmur. Feel free to grab an implementation here: https://github.com/matthewmueller/styledjsx/blob/main/internal/murmur/murmur_test.go


---
a-h 2025-01-14T12:33:32Z [OWNER]

At the moment, templ-css isn't wired up to templ. What I was thinking is that in templ, there's a few parts that could be made "pluggable".

The process is:
  - Walk directory
  - Find relevant files
  - Run actions on the files
  - Run post actions (e.g. delete templ.txt files)

There's only one action to run on files at the moment - generate `*_templ.go` files from `*.templ` files (I'll call this templ generate). However, we're proposing adding behaviour for `.css` and `.scss` files, and so those could be separate actions.

The templ generate action could support adding pre and post generation steps.

There's no plugin concept in the generate step, but we have a concept of pluggable diagnostics: https://github.com/a-h/templ/blob/24be99e271521e39cae78aa12b0772bd52c93ec3/parser/v2/diagnostics.go#L10 

Examples:

- Watch action plugins:
  - Runs on `*.css` files and generates a Go file containing the names of the classes.
  - Runs on `*.module.css` files and outputs a Go file and a CSS file in a `./public` containing the `*.css` file with prefixes.
- templ generate pre-generation plugin (runs after the templ file has been parsed, but before templ generate happens):
  - Check for invalid HTML structure (e.g. div within p) and return diagnostics.
  - Rewrite the in-memory templ file object model to find any instances of `<style scoped>` and rewrite the contents of the tag to rename the CSS classes in that CSS.

However, I don't think I'd want to introduce user configurable pre-generation plugins at the mo, because any modifications to file positions in the pre-generation step would affect LSP functionality - diagnostics would be in the wrong place etc. - could be a nightmare to maintain. It might be that the best way is to allow these plugins to add context to the templ nodes, which can be used by the generation step to generate different code. Not sure.

Step 1 is a refactor of the generation process to be structured a little differently, to support mapping file name regexes to an interface that represents doing some work on a file (maybe the interface would be called `FileProcessor`).

Step 2 is to implement a `.*\.module.css$` processor alongside the `.*\.templ$` processor.
Step 3 is to implement a `.*\(^module\.)\.css$` processor that generates CSS class names as Go constants.

Can launch a new version of templ at this point, I think, then go off in different directions:

- Update the generator to support pre-generation plugins and support scoped CSS - might not be easy.
- Provide an `.scss` processor or some other functions. However, templ risks becoming a not-very-good task runner if not careful.

I think for sure the `module.css` stuff is good, and I like the CSS class names as Go constants stuff.

---
Riu 2025-01-14T19:46:35Z [NONE]

Let's say we have a component library - how do you want to check which components were used (selected and not all), get only the CSS that was actually used? Any idea on how to do that?

---
a-h 2025-01-15T13:26:34Z [OWNER]

@Riu - there's a few ways I could think of.

Static analysis - parse the Go AST for instances of `@packagename.Component` etc. and have the component library create a CSS bundle like the way Tailwind does.

Runtime calculation - the component libraries could have a runtime element, e.g.:

```go
var ComponentLibraryCSS = mycomponentlibrary.Bundle(
  mycomponentlibrary.ButtonCSS,
  mycomponentlibrary.ListCSS,
)

func main() {
  http.Handle(mycomponentlibrary.CSSURL, ComponentLibrary)
}
```

---
devgioele 2025-04-25T09:19:58Z [NONE]

I am in favor of deprecating CSS components. I think `templ` should restrict its scope to html and js templating.
CSS can be written in `.css` files and then the classes applied conditionally to html elements using `templ`.

There are many CSS pre-processors available that are written in different programming languages. How those CSS pre-processors are implemented should not be a concern of `templ`. You do not want to depend on a CSS pre-processor that is written in JavaScript? Then choose another one or write a clone in Go. A mitigation when using Tailwind CSS is to install it as a standalone executable. This allows you to avoid npm.

And when it comes to component libraries using conflicting CSS classes, I think it is the responsibility of component libraries to make sure they work inside the intended context. Component libraries using Tailwind CSS will expect the user of the component library to use Tailwind CSS. Other component libraries may add a prefix to all their classes to prevent conflicts, like `mylibrary_flex_md`.

---
matthewmueller 2025-06-22T21:23:58Z [CONTRIBUTOR]

FWIW, I _finally_ got around to implementing `<style scoped>` over in https://github.com/matthewmueller/templar thanks to the new `parser.Visitor` and modifiable AST support in Templ!

Still working on integrating it into my own project and writing docs, so for now you can check out the `testdata/` for more examples, but the gist is:

**input.templ**

```templ
package main

templ Main() {
	<main class="main">
		<h1>hello</h1>
	</main>
	<style scoped>
		.main {
			background: blue;
		}
		h1 {
			color: red;
		}
	</style>
}
```

**usage.go**

```go
import "github.com/a-h/templ/parser/v2"
import "github.com/matthewmueller/templar/scopedcss"

// ...

templateFile, err := parser.ParseString(templCode)

css, err := scopedcss.Rewrite("input.templ", templateFile)
```

**out.css**

```css
.main.jsx-3oRqn9 { background: blue }
h1.jsx-3oRqn9 { color: red }
```

**out.templ**

```templ
package main

templ Main() {
	<main class="jsx-3oRqn9 main">
		<h1 class="jsx-3oRqn9">hello</h1>
	</main>
}
```

While I think it's fine to keep it external, let me know if there's strong interest in bringing this into Templ!

---

I'm going to work on Tailwind next. The way I'm thinking about this is that Tailwind covers 80% of your styling needs and this covers the last 20% where Tailwind is inconvenient.

---
b0ch3nski 2025-06-23T09:09:45Z [NONE]

> While I think it's fine to keep it external, let me know if there's strong interest in bringing this into Templ!

> I'm going to work on Tailwind next. The way I'm thinking about this is that Tailwind covers 80% of your styling needs and this covers the last 20% where Tailwind is inconvenient.

I say yes for both! Big thanks for your work on this matter 🎉   
I've been using Tailwind in a somewhat hakish way ever since by just reusing the precompiled CDN version: `<script src={ "https://cdn.tailwindcss.com/" + tailwindVersion }></script>` because it just gets stuff done. But having it properly integrated and customizable would be really amazing!

---
YuukanOO 2025-08-19T17:04:08Z [NONE]

> Thoughts?

Late to the party but I absolutely love this idea!

I wanted to give templ a ride with datastar and I really don't want to add additional tooling overhead. Using it with CSS modules could be a great DX to make applications that last.


---
lllama 2026-09-01T11:11:50Z [NONE]

Chiming in here after having had a play with Svelte recently. I like having the style tag next to the component - similar to @YuukanOO this works nicely with Datastar. Personally, something like what @matthewmueller implemented seems ideal (though I think I'd prefer it to assume scoped and then have a :global override, similar to Svelte).

For what it's worth, however, the `@scope` CSS rule (https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@scope) is now baseline, so you can inline a style tag and put `@scope {` at the top, and then all your rules will be scoped to the component. You'll have to wrap your whole component in a `<div>` or similar but otherwise it'll work ok at the expense of the style tag being sent with each render.

E.g. everything in the `<main>` tag will have the CSS in the `<style>` tag applied.

```html

templ Register(errors map[string][]string) {
	@base(){
		<main>
			<form class="register" method="POST" data-on:submit="@post('/register')">
				<div class="form-group">
					<label for="email">Email</label>
					<input
						name="email"
						id="email"
						type="text"
						required
						data-bind:email
					/>
					for _, error := range errors["email"] {
						<div class="error">{error}</div>
					}
				</div>
				<button type="submit">Register</button>
			</form>
			<a href="/login">Existing user? Login here</a>
			<style>
				@scope {
					.error {
						outline: red solid 2px;
					}
				}
			</style>
		</main>
	}
}


```

---
scrhartley 2026-09-01T15:35:31Z [CONTRIBUTOR]

For completeness, here's a declarative shadow DOM implementation that allows scoping without relying on `@scope` support.
Since everything is defined as slot contents, it's still part of the main DOM and so global styles still apply.
```html
<!DOCTYPE html>
<html>
    <head>
        <title>Page</title>
        <style>
            div {
                /* Prove that slots are still styled globally */
                border: 1px dashed black;
                margin: 8px;
                padding: 2px;
            }
        </style>
    </head>
    <body>
        <h1>Page</h1>
        
        <!-- INDIVIDUAL COMPONENT WITH UNNAMED SLOT -->
        <div>
            <template shadowrootmode="open">
                <style>
                    :host { 
                        display: contents; /* optional */
                    }
                    ::slotted(*) {
                        color: purple;
                    }
                </style>
                <slot></slot>
            </template>
            <div>Component</div>
        </div>
        
        <br>
        
        <!-- MULTI COMPONENT -->
        <div>
            <template shadowrootmode="open">
                <style>
                    :host {
                        display: contents; /* optional */
                    }
                    ::slotted([slot="A"]) {
                        color: red;
                    }
                    ::slotted([slot="B"]) {
                        color: blue;
                    }
                    ::slotted([slot="C"]) {
                        color: green;
                    }
                </style>
                <slot name="A"></slot>
                <slot name="B"></slot>
                <slot name="C"></slot>
            </template>
            <div slot="A">Component A</div>
            <div slot="B">Component B</div>
            <div slot="C">Component C</div>
        </div>
    </body>
</html>
```

---
lllama 2026-09-02T13:37:08Z [NONE]

One further thought - having a random class added to selectors and elements could mean that we could extract the style tags into CSS files. Whether this saves much bandwidth or parsing effort is debatable _but_ it would mean that `-watch` could extract the CSS and trigger style updates on the page without a full rebuild and reload.

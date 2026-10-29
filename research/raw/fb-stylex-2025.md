# StyleX: A Styling Library for CSS at Scale - Engineering at Meta

<https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/>

[Skip to content](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/#content)

# 

Search this site  

-   [Open Source](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/# "Open Source")
-   [Platforms](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/# "Platforms")
-   [Infrastructure Systems](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/# "Infrastructure Systems")
-   [Physical Infrastructure](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/# "Physical Infrastructure")
-   [Video Engineering & AR/VR](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/# "Video Engineering & AR/VR")
-   [Artificial Intelligence](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/# "Artificial Intelligence")
-   [Watch Videos](https://engineering.fb.com/videos "Watch Videos")

POSTED ON NOVEMBER 11, 2025 TO [Open Source](https://engineering.fb.com/category/open-source/), [Web](https://engineering.fb.com/category/web/)

# 

StyleX: A Styling Library for CSS at Scale

By [Melissa Liu](https://engineering.fb.com/author/melissa-liu/ "Posts by Melissa Liu")

[StyleX](https://stylexjs.com/) is Meta’s styling system for large-scale applications. It combines the ergonomics of CSS-in-JS with the performance of static CSS, generating collision-free atomic CSS while allowing for expressive, type-safe style authoring. [StyleX was open sourced](https://github.com/facebook/stylex) at the end of 2023 and has since become the standard styling system across Meta products like Facebook, Instagram, WhatsApp, Messenger, and Threads, as well as external companies like Figma and Snowflake.

At its core, StyleX is a compiler that extracts styles at build time and generates a static stylesheet. But it’s also a philosophy: a framework for authoring, sharing, and maintaining CSS at scale. StyleX makes styling intuitive for everyday engineers by imposing constraints that encourage predictability, enable composition, and scale effortlessly across teams and codebases.

## How Do We Build CSS at Scale?

To understand the purpose of StyleX, let’s look at the history of CSS at Meta. Serving CSS at such a scale resulted in collisions across bundles, difficulties in managing dependencies between stylesheets, and challenges in reconciling competing rules that frequently led to specificity wars. Engineers resorted to complex selectors and !important tags, making styles brittle and hard to maintain. Large, monolithic CSS bundles meant browsers were downloading hundreds of kilobytes of unused rules on every page load, slowing rendering and interaction. 

To address these issues, Facebook built cx, a CSS-modules-like system that linked local CSS to JavaScript. cx resolved issues with namespace collisions and dependency management but remained limited to static styles defined in separate files.

```javascript
// ComponentName.css; class uses ComponentName/namespace syntax
.ComponentName/header { margin-top: 10px }

// ComponentName.js 
<div className={cx('ComponentName/header')} />
```

When we [rebuilt Facebook.com](https://engineering.fb.com/2020/05/08/web/facebook-redesign/) from the ground up, we had the opportunity to build something better. Around this time, the [CSS-in-JS](https://speakerdeck.com/vjeux/react-css-in-js) movement was gaining momentum. Developers increasingly wanted to colocate styles with component code, write dynamic styles based on runtime state, and leverage JavaScript paradigms like import graphs, module scoping, and type systems. But early CSS-in-JS systems relied on runtime injection: dynamically generating <style> tags and mutating the DOM during render, patterns that introduced measurable performance overhead.

```javascript
import * as stylex from '@stylexjs/stylex';

const styles = stylex.create({
  foo: { margin: 10 }
});

function MyComponent({}) {
  return <div {...styles.props(styles.foo)}/>
}
```

We built on the lessons of this movement and made a system that is CSS-in-JS only in form, with styles compiling to static CSS. StyleX soon replaced our precursor cx system and transformed the way we approached styling. With StyleX, styles were now defined in JavaScript, enabling composition, conditional logic, and build-time compilation. Atomic classes reduced CSS size by 80% and made styling maintainable across a rapidly scaling codebase.

Today, StyleX is the default styling system at Meta, powering everything from product surfaces to component libraries. Engineers use it to build interfaces that are expressive, reusable, and performant.

## Into the Compiler

The power of StyleX lies in its abstraction. We automatically handle CSS specificity, variable generation, and static compilation to generate predictable, collision-free atomic CSS. This avoids the maintenance overload of hand-authored CSS styles, allowing users to focus on style authoring. 

StyleX lives in a monorepo composed of several integrated packages. The core engine is a [Babel](https://babel.dev/) plugin that runs a transform across a project and returns the extracted CSS. At a high level, [the compiler](https://github.com/facebook/stylex/tree/main/packages/%40stylexjs/babel-plugin) traverses a set of files, extracts CSS metadata from style objects, and converts style declarations to atomic CSS classes. The collected metadata is then run through several processes: value normalization, at-rules wrapping, and legacy polyfills. Finally, the CSS rules are sorted and outputted into a static sheet.

Let’s explore the behind-the-scenes of this process through the [values of StyleX](https://stylexjs.com/docs/learn/thinking-in-stylex/). 

### Scalability

At the heart of StyleX is its static compilation into [atomic CSS](https://compiledcssinjs.com/docs/atomic-css). Styles are converted to classes containing a single style declaration for reuse across a codebase so CSS size plateaus as the application grows. Whenever possible, styles are compiled away and cached per file, so the system can analyze all reachable styles, deduplicate shared declarations, and emit only what’s needed at runtime.

The core API surface is intentionally lightweight:

-   stylex.create() is used to define style objects. Objects are stripped away at build time and converted to atomic CSS. Each property: value pair is hashed and outputted as a CSS class. This API is designed for cacheability and only allows for statically resolvable values.
-   stylex.props() handles merging and deduping of style objects. Each call is transpiled to an object containing a space-separated className string corresponding to each atomic style, and a style prop for dynamic styles. When styles are local to the module, we compile at build time; when styles are used across module boundaries, we defer to a tiny runtime merge.

```javascript
import * as stylex from '@stylexjs/stylex';

const styles = stylex.create({
  foo: { margin: 10 }
  bar: { margin: 10, color: 'red' }
});

function MyComponent({style}) {
  return (
    <>
     <div {...styles.props(styles.foo)}/> 
     <div {...styles.props(styles.bar)}/> 
     <div {...stylex.props(style)}/> 
    </>
  )
}
```

In each JavaScript file, API calls are replaced with the class names from the generated CSS and local styles are stripped away. The above component compiles to something like this:

```javascript
import * as stylex from '@stylexjs/stylex';

function MyComponent({style}) {
  return (
    <>
     <div className="m-10" />
     <div className="c-red m-10" /> 
     <div {...stylex.props(style)}/> 
    </>
  )
}
```

After the transform is run across files, we process the collected metadata, generate LTR/RTL variants, resolve constants, and order CSS rules by priority. The output is a string that can be emitted as a static stylesheet and post-processed by any of our bundlers.

```css
.m-10 { margin: 10px }
.c-red { color: red }
```

### Expressiveness

StyleX enforces constraints as design principles instead of limitations. We disallow conflict-prone patterns like _styling at a distance_ and enforce patterns that are statically resolvable. Within these boundaries, however, StyleX remains expressive. We’ve designed for maximum flexibility within these constraints through the following [APIs](https://stylexjs.com/docs/api/).

#### Shareable Values

stylex.create()is designed for per-file cacheability: all CSS metadata must be derived solely from the JavaScript defined within that file. We use an extended version of Babel’s evaluate function to resolve values. The compiler never needs to read the contents of imported modules to generate the stylesheet. 

To enable reusable values across files, we provide APIs like stylex.defineVars() and stylex.defineConsts(). These functions generate deterministic hashes based on variable name and import path that remain consistent across modules. This allows us to resolve variables anywhere they’re imported without traversing the file that declares them. At build time, shared constants are fully inlined, while shared variables become global CSS custom properties that can be referenced across components.

```javascript
// varsFile.stylex.js
const varColors = stylex.defineVars({primary: "#eee"})
// constsFile.stylex.js
const constColors = stylex.defineConsts({primary: "#fff"})

// Component.react.js
import {varColors} from 'varsFile.stylex.js' 
import {constColors} from 'constsFile.stylex.js' 

const styles = stylex.create({
    foo: {color: varColors.primary} // → .x { var(--hash('varsFile.varColors.primary')) }
    bar: {color: constColors.primary} // → hash('constsFile.constColors.primary') → #fff
  },
});
```

####   
Styling at a Distance

As mentioned, StyleX is a system for styling components. Elements are styled using classnames. Global and complex selectors are disallowed to avoid styling at a distance: rules that affect elements indirectly from elsewhere in the DOM. Global baseline rules like element selectors or CSS resets must be defined in a separate stylesheet. This is to minimize indirect styling and promote [encapsulation](https://stylexjs.com/docs/learn/thinking-in-stylex/#encapsulation) of styles.

```css
/* Unsafe: styles leak to child elements rather than being explicitly applied */
.csuifyiu:hover > div { ... }

/* Safe: styles are scoped to a specific element based on observed state */
div:hover > .ksghfhjsfg { ... } 
```

However, we do allow _observing from a distance_ using the stylex.when APIs. This API provides a suite of relational selectors to style a component based on the state of its ancestors, descendants, or siblings. Observed elements must be marked with stylex.defaultMarker(), ensuring styles remain directly applied while supporting contextual behavior.

```javascript
const styles = stylex.create({
    foo: {
      backgroundColor: {
        default: 'blue',
        [stylex.when.ancestor(':hover')]: 'red',
      },
    },
});

<div {...stylex.props(stylex.defaultMarker())}>
  <div {...stylex.props(styles.foo)}> Some Content </div>
</div>
```

#### Preserving CSS Features

StyleX preserves most of the CSS feature set (media queries, pseudoclasses, keyframes, and more) through static transforms at build time. Wherever possible, we mirror native CSS behavior so styling feels expansive and familiar.

While StyleX is built around static compilation, it also supports dynamic styles. When a value isn’t known at build time, the compiler emits a CSS variable reference, and the runtime writes it inline through the style prop. 

```javascript
const styles = stylex.create({
    // Height is unknown until runtime
    foo: (height) => ({
      height,
    }),
});

// { .d-height {var(--height)}, style: {--height: height} }
<div {...stylex.props(styles.foo(height))}/> 
```

Theming APIs like stylex.defineVars() and stylex.createTheme() allow users to create and mutate shareable design tokens. defineVars() creates a variable grouping, and createTheme() allows users to create variants by redefining variable groups at a higher specificity.

```css
/* const spacing = stylex.defineVars({sm: 2px, md: 4px, lg: 8px}) */
:root, .sp-group{--sp-sm:2px;--sp-md:4px;--sp-lg:8px;}

/* const desktopSpacing = stylex.createTheme(spacing, {sm: 5px, md: 10px, lg: 20px}) */
.sp-dktp.sp-dktp, .sp-dktp.sp-dktp:root{--sp-sm:5px;--sp-md:10px;--sp-lg:20px;}
```

stylex.defineConsts() allows users to define shareable constants and media queries without overloading browser memory with CSS variables. During compilation, StyleX gathers metadata across all defineConsts() calls, generates placeholder hashes in  create() calls, and inlines the constant values directly into the generated stylesheet.

Finally, APIs like stylex.keyframes() and stylex.viewTransitionClass() support animations by generating @keyframes and ::view-transition-\* rules.

### Predictability

StyleX is a system for styling components. We discourage global styling in favour of applying localized classnames on elements directly. Our design is centered around predictable style merging: The last style always wins! You can think of the stylex.props function as a deterministic merge of style objects: given stylex.props(styles.foo, styles.bar), bar always overrides foo. This makes it easy to share and combine styles predictably across files.

CSS specificity follows a hierarchy where selectors are assigned different priorities. The calculation is based on a three-column value of IDs, classes, and types, commonly written as, (ID, Class, Type). Because StyleX is entirely class-based, resolving conflicts between style objects means determining which class names to apply and enforcing priorities between them. 

```javascript
const styles = stylex.create({
  foo: { color: 'red', margin: 0 }
  bar: { color: 'black', marginTop: 10 }	
});

function MyComponent() {
  // becomes <div className="c-black m-0 mt-10" /> 
  return <div {...stylex.props(styles.foo, styles.bar)} /> 
}
```

During merge, repeated properties across style objects are deduplicated so that only the last value is applied. As a result, each class name in the DOM node corresponds to a single property. In the above example, the color: red class is dropped during merge so color: black takes precedence. But resolving overlaps between shorthands and constituent longhands is more complex. 

Consider the following HTML:

```html
<style>
  .margin-top-10 { margin-top: 10px }
  .margin-0 { margin: 0px }
<style/>

<div className="margin-0 margin-top-10" />
```

When multiple classes are applied on a div, the resulting styling is based solely on the specificity of the selectors (in this case, the order of the classes). Without additional handling, margin overrides margin-top here completely!

Throw pseudoclasses and media queries in the mix and things become even more complex:

```javascript
{
   [ "m-0", { "css": ".m-10 {margin: 0}" }, 3000 ], 
   [ "mt-10", { "css": ".mt-10 {margin-top: 10px}", }, 4000 ], 
   [ "mt-10-mq", { "css": "@media (...) {.mt-10-mq {margin-top: 10px} }", }, 4200 ], 
   [ "mt-10-mq", { "css": "@media (...) {.mt-10-mq:hover {margin-top: 10px} }", }, 4320 ], 
}
```

To handle this ambiguity, we compute a numerical priority alongside each CSS rule. We use these priorities alongside a user-configured styleResolution to determine the specificity of each class selector using the @layer at-rule or equivalent polyfill.

The enforced ordering looks something like this: 

The result? Longhands and shorthands merge predictably, :active states override :hover states, media queries override default behaviour, and user-authored order is respected when possible. This behind-the-scenes specificity handling allows developers to combine and reuse styles without manually resolving conflicts.

## Looking Forward

StyleX is maintained by a team of CSS enthusiasts who aim to make styling accessible to everyone. Beyond the compiler, the monorepo includes an [ESLint plugin](https://github.com/facebook/stylex/tree/main/packages/%40stylexjs/eslint-plugin) for style validation, a [CLI](https://github.com/facebook/stylex/tree/main/packages/%40stylexjs/cli) for easy stylesheet generation, a [PostCSS plugin](https://github.com/facebook/stylex/blob/main/packages/%40stylexjs/postcss-plugin/README.md) for post-processing, and an experimental [CSS parser](https://github.com/facebook/stylex/tree/main/packages/style-value-parser). 

The open source community has played an important role in shaping the direction of StyleX, and been a massive force multiplier in our work. We continue to learn, grow, and ideate in collaboration with the companies and individuals adopting our work. Today, with the help of thousands of contributors, the ecosystem includes a community-built [playground](https://venerable-melomakarona-255f96.netlify.app/), [VS Code extensions](https://marketplace.visualstudio.com/items?itemName=yash-singh.stylex), an [SWC compiler](https://github.com/Dwlad90/stylex-swc-plugin), [multiple](https://www.npmjs.com/package/vite-plugin-stylex) [bundler](https://github.com/sukkaw/stylex-webpack) [integrations](https://www.npmjs.com/package/unplugin-stylex), and [more](https://stylexjs.com/docs/learn/ecosystem/)!

We’re always exploring new ways to make StyleX the styling system for the modern web. Our work is an ongoing dialogue between the needs of the community and the values that guide our design. Roadmap highlights include an API for shareable functions, LLM-ready context files, support for inline styles, developer extensions, strict compiler validation, logical styles utilities, and an official unplugin for bundler integrations. Our goal is to continue to evolve alongside the browser and keep imagining what styling on the web can be.

Happy style authoring! We make StyleX for you.

## Learn More

To hear the latest on StyleX, check out the [StyleX website](https://stylexjs.com/), [GitHub](https://github.com/facebook/stylex), [Bluesky](https://bsky.app/profile/stylexjs.bsky.social) and [X](https://x.com/stylexjs). 

To learn more about Meta Open Source, visit our [website](https://opensource.fb.com/), subscribe to our [YouTube channel](https://www.youtube.com/channel/UCCQY962PmHabTjaHv2wJzfQ), or follow us on [Facebook](https://www.facebook.com/MetaOpenSource), [Threads](https://www.threads.net/@metaopensource), [X](https://x.com/MetaOpenSource), [Bluesky](https://bsky.app/profile/metaopensource.bsky.social) and [LinkedIn](https://www.linkedin.com/showcase/meta-open-source?fbclid=IwZXh0bgNhZW0CMTEAAR2fEOJNb7zOi8rJeRvQry5sRxARpdL3OpS4sYLdC1_npkEy60gBS1ynXwQ_aem_mJUK6jEUApFTW75Emhtpqw).

## Acknowledgements

_Special thanks to past maintainers Naman Goel and Sebastian McKenzie; contributors Frank Yan, Jerry Su, Ankit Sardesai, Joel Austin, Daniel Neiter, Nicolas Gallagher, Vincent Riemer, Ezzudin Alkotob, Andrey Sukhachev, Nitish Mehrotra, Nadiia D., Prakshal Jain, JC Pérez Chávez, Samantha Zhan, Chang Yan, Tina Gao, Anay Bhakat; advisors Christopher Chedeau, Baraa Hamodi, Dennis Wilkins, Chris Callahan, Richard Hansen, Robert Maratos, Will Hastings, Ricky Li, Andrew Imm, Tim Yung, Eli White; Modern CSS leads; the Web Platform org; the open source community; and the lineage of systems like React Native and Linaria that continue to inspire our work._

### Share this:

-   [Facebook](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/?share=facebook&nb=1)
-   [Threads](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/?share=threads&nb=1)
-   [WhatsApp](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/?share=jetpack-whatsapp&nb=1)
-   [LinkedIn](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/?share=linkedin&nb=1)
-   [Reddit](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/?share=reddit&nb=1)
-   [X](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/?share=x&nb=1)
-   [Bluesky](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/?share=bluesky&nb=1)
-   [Mastodon](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/?share=mastodon&nb=1)
-   [Hacker News](https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/?share=custom-1699562127&nb=1)
-   [Email](mailto:?subject=%5BShared%20Post%5D%20StyleX%3A%20A%20Styling%20Library%20for%20CSS%20at%20Scale&body=https%3A%2F%2Fengineering.fb.com%2F2025%2F11%2F11%2Fweb%2Fstylex-a-styling-library-for-css-at-scale%2F&share=email&nb=1)

### Read More in Open Source

[View All](https://engineering.fb.com/category/open-source/)

OCT 26, 2026

[Meta Networking at the 2026 OCP Global Summit: Open Innovation for Scale-Up, Scale-Out, and Scale-Across AI Networks](https://engineering.fb.com/2026/10/26/open-source/ocp-summit-2026-meta-networking-talks/)

OCT 15, 2026

[Sapienz Receives ISSTA 2026 Impact Paper Award](https://engineering.fb.com/2026/10/15/developer-tools/sapienz-issta-2026-impact-paper-award-meta/)

OCT 12, 2026

[OCP Summit 2026: Powering AI with Open Innovations in Scale-Up, Scale-Out, and Scale-Across Networks](https://engineering.fb.com/2026/10/12/open-source/ocp-summit-2026-powering-ai-with-open-innovations-in-scale-up-scale-out-and-scale-across-networks/)

OCT 6, 2026

[NTS: Authenticated Time at Meta](https://engineering.fb.com/2026/10/06/production-engineering/nts-authenticated-time-at-meta/)

SEP 21, 2026

[Open-Sourcing Rebalancer: A Generic, High-Performance Library for Solving Assignment Problems](https://engineering.fb.com/2026/09/21/open-source/rebalancer-generic-high-performance-library-assignment-problems/)

AUG 24, 2026

[MetaRoCE: A New RDMA Transport Built for AI-Scale Ethernet](https://engineering.fb.com/2026/08/24/networking-traffic/metaroce-rdma-transport-ai-ethernet/)

### Related Posts

* * *

[

May 08, 2020

#### Rebuilding our tech stack for the new Facebook.com

](https://engineering.fb.com/2020/05/08/web/facebook-redesign/)

[

Oct 16, 2025

#### Branching in a Sapling Monorepo

](https://engineering.fb.com/2025/10/16/developer-tools/branching-in-a-sapling-monorepo/)

[

Oct 06, 2025

#### Introducing OpenZL: An Open Source Format-Aware Compression Framework

](https://engineering.fb.com/2025/10/06/developer-tools/openzl-open-source-format-aware-compression-framework/)

### Related Positions

* * *

-   [
    
    Software Engineer, Machine Learning
    
    SUNNYVALE, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)
-   [
    
    Software Engineer, Machine Learning
    
    REMOTE, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)
-   [
    
    Software Engineer, Machine Learning
    
    BELLEVUE, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)
-   [
    
    Software Engineer, Machine Learning
    
    REDMOND, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)
-   [
    
    Software Engineer, Machine Learning
    
    MENLO PARK, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)

[

See All Jobs

](https://www.metacareers.com/)

### Available Positions

* * *

-   [
    
    Software Engineer, Machine Learning
    
    SUNNYVALE, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)
-   [
    
    Software Engineer, Machine Learning
    
    REMOTE, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)
-   [
    
    Software Engineer, Machine Learning
    
    BELLEVUE, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)
-   [
    
    Software Engineer, Machine Learning
    
    REDMOND, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)
-   [
    
    Software Engineer, Machine Learning
    
    MENLO PARK, US
    
    ](https://www.metacareers.com/jobs/998357492128826/)

[

See All Jobs

](https://www.metacareers.com/)

### Technology at Meta

-   Engineering at Meta - X
    
-   AI at Meta
    
    [](https://ai.meta.com/blog/)
    
-   Meta Quest Blog
    
    [](https://www.meta.com/blog/quest/)
    
-   Meta for Developers
    
    [](https://developers.facebook.com/)
    
-   Meta Bug Bounty
    
    [](https://bugbounty.meta.com/)
    
-   RSS
    
    [](https://code.facebook.com/posts/rss/)
    

### Open Source

Meta believes in building community through open source technology. Explore our latest projects in Artificial Intelligence, Data Infrastructure, Development Tools, Front End, Languages, Platforms, Security, Virtual Reality, and more.

-   ANDROID
    
-   iOS
    
-   WEB
    
-   BACKEND
    
-   HARDWARE
    

Engineering at Meta is a technical news resource for engineers interested in how we solve large-scale technical challenges at Meta.

-   [Home](https://engineering.fb.com/)
-   [Company Info](https://about.meta.com/)
-   [Careers](https://www.metacareers.com/?ref=engineering.fb.com)

© 2026 Meta

-   [Terms](https://www.facebook.com/policies)
-   [Privacy](https://www.facebook.com/privacy/policy)
-   [Cookies](https://engineering.fb.com/privacy/)
-   [Help](https://www.facebook.com/help)
-   [Cookie settings](https://engineering.fb.com/cookie-settings/)

## Allow the use of cookies by Meta on this browser?

We (Meta Platforms Ireland Limited) use cookies on this site. Some of these are essential cookies which are required for the site to work as intended. We also use optional cookies to perform site analytics and measure the performance of content on this site. You have control over the optional cookies that we use. If you choose to "Decline optional cookies", you can continue to use the site but we will be unable to perform site analytics on this site using such cookies and similar technologies. **Learn more about our cookies and third-party providers in our [Cookies Notice](https://engineering.fb.com/privacy/), or you can review or change your choices, including withdraw your consent, at any time in your [Settings page](https://engineering.fb.com/cookie-settings/).**

# Styles – Lit

<https://lit.dev/docs/components/styles/>

1.  [Documentation](https://lit.dev/docs/)
2.  [Learn](https://lit.dev/learn/)
3.  [Playground](https://lit.dev/playground/)
4.  [Blog](https://lit.dev/blog/)

6.  -   

1.  ›Introduction
    
    1.  [What is Lit?](https://lit.dev/docs/)
    2.  [Getting Started](https://lit.dev/docs/getting-started/)
    
2.  ›Components
    
    1.  [Overview](https://lit.dev/docs/components/overview/)
    2.  [Defining](https://lit.dev/docs/components/defining/)
    3.  [Rendering](https://lit.dev/docs/components/rendering/)
    4.  [Reactive properties](https://lit.dev/docs/components/properties/)
    5.  [Styles](https://lit.dev/docs/components/styles/)
    6.  [Lifecycle](https://lit.dev/docs/components/lifecycle/)
    7.  [Shadow DOM](https://lit.dev/docs/components/shadow-dom/)
    8.  [Events](https://lit.dev/docs/components/events/)
    9.  [Decorators](https://lit.dev/docs/components/decorators/)
    
3.  ›Templates
    
    1.  [Overview](https://lit.dev/docs/templates/overview/)
    2.  [Expressions](https://lit.dev/docs/templates/expressions/)
    3.  [Conditionals](https://lit.dev/docs/templates/conditionals/)
    4.  [Lists](https://lit.dev/docs/templates/lists/)
    5.  [Built-in directives](https://lit.dev/docs/templates/directives/)
    6.  [Custom directives](https://lit.dev/docs/templates/custom-directives/)
    
4.  ›Composition
5.  ›Managing Data
6.  ›Tools and workflows
7.  ›Server rendering 
8.  ›Frameworks
9.  ›Localization
10.  ›API
11.  ›Releases
12.  ›Related libraries
13.  ›Resources

## [Contents: Styles](https://lit.dev/docs/components/styles/#content)

1.  [Adding styles to your component](https://lit.dev/docs/components/styles/#add-styles)
    1.  [Using expressions in static styles](https://lit.dev/docs/components/styles/#expressions)
    2.  [Inheriting styles from a superclass](https://lit.dev/docs/components/styles/#inheriting-styles-from-a-superclass)
    3.  [Sharing styles](https://lit.dev/docs/components/styles/#sharing-styles)
    4.  [Using unicode escapes in styles](https://lit.dev/docs/components/styles/#using-unicode-escapes-in-styles)
2.  [Shadow DOM styling overview](https://lit.dev/docs/components/styles/#shadow-dom)
    1.  [Styling the shadow tree](https://lit.dev/docs/components/styles/#shadowroot)
    2.  [Styling the component itself](https://lit.dev/docs/components/styles/#host)
    3.  [Styling the component's children](https://lit.dev/docs/components/styles/#slotted)
3.  [Defining scoped styles in the template](https://lit.dev/docs/components/styles/#styles-in-the-template)
    1.  [In a style element](https://lit.dev/docs/components/styles/#style-element)
    2.  [Import an external stylesheet (not recommended)](https://lit.dev/docs/components/styles/#external-stylesheet)
4.  [Dynamic classes and styles](https://lit.dev/docs/components/styles/#dynamic-classes-and-styles)
5.  [Theming](https://lit.dev/docs/components/styles/#theming)
    1.  [CSS inheritance](https://lit.dev/docs/components/styles/#inheritance)
    2.  [CSS custom properties](https://lit.dev/docs/components/styles/#customprops)

# Styles

Your component's template is rendered to its shadow root. The styles you add to your component are automatically _scoped_ to the shadow root and only affect elements in the component's shadow root.

Shadow DOM provides strong encapsulation for styling. If Lit did not use Shadow DOM, you would have to be extremely careful not to accidentally style elements outside of your component, either ancestors or children of your component. This might involve writing long, cumbersome to use class names. By using Shadow DOM, Lit ensures whatever selector you write only apply to elements in your Lit component's shadow root.

## Adding styles to your component

[Permalink to “Adding styles to your component” #](https://lit.dev/docs/components/styles/#add-styles)

You define scoped styles in the static `styles` class field using the tagged template literal `css` function. Defining styles this way results in the most optimal performance:

The styles you add to your component are _scoped_ using shadow DOM. For a quick overview, see [Shadow DOM](https://lit.dev/docs/components/styles/#shadow-dom).

The value of the static `styles` class field can be:

-   A single tagged template literal.
    
    ```js
    static styles = css`...`;
    ```
    
-   An array of tagged template literals.
    
    ```js
    static styles = [ css`...`, css`...`];
    ```
    

The static `styles` class field is _almost always_ the best way to add styles to your component, but there are some use cases you can't handle this way—for example, customizing styles per instance. For alternate ways to add styles, see [Defining scoped styles in the template](https://lit.dev/docs/components/styles/#styles-in-the-template).

### Using expressions in static styles

[Permalink to “Using expressions in static styles” #](https://lit.dev/docs/components/styles/#expressions)

Static styles apply to all instances of a component. Any expressions in CSS are evaluated **once**, then reused for all instances.

For tree-based or per-instance style customization, use CSS custom properties to allow elements to be [themed](https://lit.dev/docs/components/styles/#theming).

To prevent Lit components from evaluating potentially malicious code, the `css` tag only allows nested expressions that are themselves `css` tagged strings or numbers.

```js
const mainColor = css`red`;...static styles = css`  div { color: ${mainColor} }`;
```

This restriction exists to protect applications from security vulnerabilities whereby malicious styles, or even malicious code, can be injected from untrusted sources such as URL parameters or database values.

If you must use an expression in a `css` literal that is not itself a `css` literal, **and** you are confident that the expression is from a fully trusted source such as a constant defined in your own code, then you can wrap the expression with the `unsafeCSS` function:

```js
const mainColor = 'red';...static styles = css`  div { color: ${unsafeCSS(mainColor)} }`;
```

**Only use the `unsafeCSS` tag with trusted input.** Injecting unsanitized CSS is a security risk. For example, malicious CSS can "phone home" by adding an image URL that points to a third-party server.

### Inheriting styles from a superclass

[Permalink to “Inheriting styles from a superclass” #](https://lit.dev/docs/components/styles/#inheriting-styles-from-a-superclass)

Using an array of tagged template literals, a component can inherit the styles from a superclass, and add its own styles:

You can also use `super.styles` to reference the superclass's styles property in JavaScript. If you're using TypeScript, we recommend avoiding `super.styles` since the compiler doesn't always convert it correctly. Explicitly referencing the superclass, as shown in the example, avoids this issue.

When writing components intended to be subclassed in TypeScript, the `static styles` field should be explicitly typed as `CSSResultGroup` to allow flexibility for users to override `styles` with an array:

```ts
// Prevent typescript from narrowing the type of `styles` to `CSSResult`// so that subclassers can assign e.g. `[SuperElement.styles, css`...`]`;static styles: CSSResultGroup = css`...`;
```

### Sharing styles

[Permalink to “Sharing styles” #](https://lit.dev/docs/components/styles/#sharing-styles)

You can share styles between components by creating a module that exports tagged styles:

```js
export const buttonStyles = css`  .blue-button {    color: white;    background-color: blue;  }  .blue-button:disabled {    background-color: grey;  }`;
```

Your element can then import the styles and add them to its static `styles` class field:

```js
import { buttonStyles } from './button-styles.js';class MyElement extends LitElement {  static styles = [    buttonStyles,    css`      :host { display: block;        border: 1px solid black;      }`  ];}
```

### Using unicode escapes in styles

[Permalink to “Using unicode escapes in styles” #](https://lit.dev/docs/components/styles/#using-unicode-escapes-in-styles)

CSS's unicode escape sequence is a backslash followed by four or six hex digits: for example, `\2022` for a bullet character. This similar to the format of JavaScript's deprecated _octal_ escape sequences, so using these sequences in a `css` tagged template literal causes an error.

There are two work-arounds for adding a unicode escape to your styles:

-   Add a second backslash (for example, `\\2022`).
-   Use the JavaScript escape sequence, starting with `\u` (for example, `\u2022`).

```js
static styles = css`  div::before {    content: '\u2022';  }
```

## Shadow DOM styling overview

[Permalink to “Shadow DOM styling overview” #](https://lit.dev/docs/components/styles/#shadow-dom)

This section gives a brief overview of shadow DOM styling.

Styles you add to a component can affect:

-   [The shadow tree](https://lit.dev/docs/components/styles/#shadowroot) (your component's rendered template).
-   [The component itself](https://lit.dev/docs/components/styles/#host).
-   [The component's children](https://lit.dev/docs/components/styles/#slotted).

### Styling the shadow tree

[Permalink to “Styling the shadow tree” #](https://lit.dev/docs/components/styles/#shadowroot)

Lit templates are rendered into a shadow tree by default. Styles scoped to an element's shadow tree don't affect the main document or other shadow trees. Similarly, with the exception of [inherited CSS properties](https://lit.dev/docs/components/styles/#inheritance), document-level styles don't affect the contents of a shadow tree.

When you use standard CSS selectors, they only match elements in your component's shadow tree. This means you can often use very simple selectors since you don't have to worry about them accidentally styling other parts of the page; for example: `input`, `*`, or `#my-element`.

### Styling the component itself

[Permalink to “Styling the component itself” #](https://lit.dev/docs/components/styles/#host)

You can style the component itself using special `:host` selectors. (The element that owns, or "hosts" a shadow tree is called the _host element_.)

To create default styles for the host element, use the `:host` CSS pseudo-class and `:host()` CSS pseudo-class function.

-   `:host` selects the host element.
-   `:host(selector)` selects the host element, but only if the host element matches _selector_.

Note that the host element can be affected by styles from outside the shadow tree, as well, so you should consider the styles you set in `:host` and `:host()` rules as _default styles_ that can be overridden by the user. For example:

```css
my-element {  display: inline-block;}
```

### Styling the component's children

[Permalink to “Styling the component's children” #](https://lit.dev/docs/components/styles/#slotted)

Your component may accept children (like a `<ul>` element can have `<li>` children). To render children, your template needs to include one or more `<slot>` elements, as described in [Render children with the slot element](https://lit.dev/docs/components/shadow-dom/#slots).

The `<slot>` element acts as a placeholder in a shadow tree where the host element's children are displayed.

Use the `::slotted()` CSS pseudo-element to select children that are included in your template via `<slot>`s.

-   `::slotted(*)` matches all slotted elements.
-   `::slotted(p)` matches slotted paragraphs.
-   `p ::slotted(*)` matches slotted elements where the `<slot>` is a descendant of a paragraph element.

Note that **only direct slotted children** can be styled with `::slotted()`.

```html
<my-element>  <div>Stylable with ::slotted()</div></my-element><my-element>  <div><p>Not stylable with ::slotted()</p></div></my-element>
```

Also, children can be styled from outside the shadow tree, so you should regard your `::slotted()` styles as default styles that can be overridden.

```css
my-element > div {  /* Outside style targetting a slotted child can override ::slotted() styles */}
```

**Limitations in the ShadyCSS polyfill around slotted content.** See the [ShadyCSS limitations](https://github.com/webcomponents/polyfills/tree/master/packages/shadycss#limitations) for details on how to use the `::slotted()` syntax in a polyfill-friendly way.

## Defining scoped styles in the template

[Permalink to “Defining scoped styles in the template” #](https://lit.dev/docs/components/styles/#styles-in-the-template)

We recommend using the [static `styles` class field](https://lit.dev/docs/components/styles/#add-styles) for optimal performance. However, sometimes you may want to define styles in the Lit template. There are two ways to add scoped styles in the template:

-   Add styles using a [`<style>` element](https://lit.dev/docs/components/styles/#style-element).
-   Add styles using an [external style sheet](https://lit.dev/docs/components/styles/#external-stylesheet) (not recommended).

Each of these techniques has its own set of advantages and drawbacks.

### In a style element

[Permalink to “In a style element” #](https://lit.dev/docs/components/styles/#style-element)

Typically, styles are placed in the [static `styles` class field](https://lit.dev/docs/components/styles/#add-styles); however, the element's static `styles` are evaluated **once per class**. Sometimes, you might need to customize styles **per instance**. For this, we recommend using CSS properties to create [themable elements](https://lit.dev/docs/components/styles/#theming). Alternatively, you can also include `<style>` elements in a Lit template. These are updated per instance.

```js
render() {  return html`    <style>      /* updated per instance */    </style>    <div>template content</div>  `;}
```

**Limitations in the ShadyCSS polyfill around per instance styling.** Per instance styling is not supported using the ShadyCSS polyfill. See the [ShadyCSS limitations](https://github.com/webcomponents/polyfills/tree/master/packages/shadycss#limitations) for details.

#### Expressions and style elements

[Permalink to “Expressions and style elements” #](https://lit.dev/docs/components/styles/#expressions-and-style-elements)

Using expressions inside style elements has some important limitations and performance issues.

```js
render() {  return html`    <style>      :host {        /* Warning: this approach has limitations & performance issues! */        color: ${myColor}      }    </style>    <div>template content</div>  `;}
```

**Limitations in the ShadyCSS polyfill around expressions.** Expressions in `<style>` elements won't update per instance in ShadyCSS, due to limitations of the ShadyCSS polyfill. In addition, `<style>` nodes may not be passed as expression values when using the ShadyCSS polyfill. See the [ShadyCSS limitations](https://github.com/webcomponents/polyfills/tree/master/packages/shadycss#limitations) for more information.

Evaluating an expression inside a `<style>` element is extremely inefficient. When any text inside a `<style>` element changes, the browser must re-parse the whole `<style>` element, resulting in unnecessary work.

To mitigate this cost, separate styles that require per-instance evaluation from those that don't.

```js
  static styles = css`/* ... */`;  render() {    const redStyle = html`<style> :host { color: red; } </style>`;    return html`${this.red ? redStyle : ''}`
```

### Import an external stylesheet (not recommended)

[Permalink to “Import an external stylesheet (not recommended)” #](https://lit.dev/docs/components/styles/#external-stylesheet)

While you can include an external style sheet in your template with a `<link>`, we do not recommend this approach. Instead, styles should be placed in the [static `styles` class field](https://lit.dev/docs/components/styles/#add-styles).

**External stylesheet caveats.**

-   The [ShadyCSS polyfill](https://github.com/webcomponents/polyfills/tree/master/packages/shadycss#limitations) doesn't support external style sheets.
-   External styles can cause a flash-of-unstyled-content (FOUC) while they load.
-   The URL in the `href` attribute is relative to the **main document**. This is okay if you're building an app and your asset URLs are well-known, but avoid using external style sheets when building a reusable element.

## Dynamic classes and styles

[Permalink to “Dynamic classes and styles” #](https://lit.dev/docs/components/styles/#dynamic-classes-and-styles)

One way to make styles dynamic is to add expressions to the `class` or `style` attributes in your template.

Lit offers two directives, `classMap` and `styleMap`, to conveniently apply classes and styles in HTML templates.

For more information on these and other directives, see the documentation on [built-in directives](https://lit.dev/docs/templates/directives/).

To use `styleMap` and/or `classMap`:

1.  Import `classMap` and/or `styleMap`:
    
    ```js
    import { classMap } from 'lit/directives/class-map.js';import { styleMap } from 'lit/directives/style-map.js';
    ```
    
2.  Use `classMap` and/or `styleMap` in your element template:
    

See [classMap](https://lit.dev/docs/templates/directives/#classmap) and [styleMap](https://lit.dev/docs/templates/directives/#stylemap) for more information.

## Theming

[Permalink to “Theming” #](https://lit.dev/docs/components/styles/#theming)

By using [CSS inheritance](https://lit.dev/docs/components/styles/#inheritance) and [CSS variables and custom properties](https://lit.dev/docs/components/styles/#customprops) together, it's easy to create themable elements. By applying css selectors to customize CSS custom properties, tree-based and per-instance theming is straightforward to apply. Here's an example:

### CSS inheritance

[Permalink to “CSS inheritance” #](https://lit.dev/docs/components/styles/#inheritance)

CSS inheritance lets parent and host elements propagate certain CSS properties to their descendants.

Not all CSS properties inherit. Inherited CSS properties include:

-   `color`
-   `font-family` and other `font-*` properties
-   All CSS custom properties (`--*`)

See [CSS Inheritance on MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/inheritance) for more information.

You can use CSS inheritance to set styles on an ancestor element that are inherited by its descendants:

```html
<style>html {  color: green;}</style><my-element>  #shadow-root    Will be green</my-element>
```

### CSS custom properties

[Permalink to “CSS custom properties” #](https://lit.dev/docs/components/styles/#customprops)

All CSS custom properties (`--custom-property-name`) inherit. You can use this to make your component's styles configurable from outside.

The following component sets its background color to a CSS variable. The CSS variable uses the value of `--my-background` if it's been set by a selector matching an ancestor in the DOM tree, and otherwise defaults to `yellow`:

```js
class MyElement extends LitElement {  static styles = css`    :host {      background-color: var(--my-background, yellow);    }  `;  render() {    return html`<p>Hello world</p>`;  }}
```

Users of this component can set the value of `--my-background`, using the `my-element` tag as a CSS selector:

```html
<style>  my-element {    --my-background: rgb(67, 156, 144);  }</style><my-element></my-element>
```

`--my-background` is configurable per instance of `my-element`:

```html
<style>  my-element {    --my-background: rgb(67, 156, 144);  }  my-element.stuff {    --my-background: #111111;  }</style><my-element></my-element><my-element class="stuff"></my-element>
```

See [CSS Custom Properties on MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/--*) for more information.

[Edit this page](https://github.com/lit/lit.dev/edit/main/packages/lit-dev-content/site/docs/v3/components/styles.md)

[Previous Reactive properties](https://lit.dev/docs/components/properties/) [Next Lifecycle](https://lit.dev/docs/components/lifecycle/)

[The OpenJS Foundation](https://openjsf.org/) | [Terms of Use](https://terms-of-use.openjsf.org/) | [Privacy Policy](https://privacy-policy.openjsf.org/) | [Bylaws](https://bylaws.openjsf.org/) | [Code of Conduct](https://code-of-conduct.openjsf.org/) | [Trademark Policy](https://trademark-policy.openjsf.org/) | [Trademark List](https://trademark-list.openjsf.org/) | [Cookie Policy](https://www.linuxfoundation.org/cookies)

Copyright [OpenJS Foundation](https://openjsf.org/) and the Lit Project. All rights reserved. The [OpenJS Foundation](https://openjsf.org/) has registered trademarks and uses trademarks. For a list of trademarks of the [OpenJS Foundation](https://openjsf.org/), please see our [Trademark Policy](https://trademark-policy.openjsf.org/) and [Trademark List](https://trademark-list.openjsf.org/). Trademarks and logos not indicated on the [list of OpenJS Foundation trademarks](https://trademark-list.openjsf.org/) are trademarks™ or registered® trademarks of their respective holders. Use of them does not imply any affiliation with or endorsement by them.

Code licensed under [BSD-3-Clause](https://spdx.org/licenses/BSD-3-Clause.html). Documentation licensed under [CC-BY-3.0](https://spdx.org/licenses/CC-BY-3.0).

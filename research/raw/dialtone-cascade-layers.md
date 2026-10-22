# CSS Cascade Layers | Dialtone Design System

<https://dialtone.dialpad.com/guides/migration/css-cascade-layers/>

Type / (slash) to focus search field∕

-   [Dialtone Overview](https://dialtone.dialpad.com/dialtone/)
-   [What's New](https://dialtone.dialpad.com/dialtone/whats-new/)
-   
    
-   
    
-   -   [Overview](https://dialtone.dialpad.com/guides/migration/)
    -   [Visual Changes](https://dialtone.dialpad.com/guides/migration/visual-changes/)
    -   [Border-Radius Logical Names](https://dialtone.dialpad.com/guides/migration/border-radius/)
    -   [CSS Cascade Layers](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/)
    -   [Color Stops](https://dialtone.dialpad.com/guides/migration/color-stops/)
    -   [HSL to OKLCH](https://dialtone.dialpad.com/guides/migration/hsl-to-oklch/)
    -   [Layout & Spacing Tokens](https://dialtone.dialpad.com/guides/migration/layout-and-spacing-tokens/)
    -   [Success to Positive](https://dialtone.dialpad.com/guides/migration/success-to-positive/)
    -   [Flex to DtStack](https://dialtone.dialpad.com/guides/migration/flex-to-stack/)
    -   [Link and Button Navigation](https://dialtone.dialpad.com/guides/migration/link-and-button-navigation/)
    -   [Component Sizes](https://dialtone.dialpad.com/guides/migration/component-sizes/)
    -   [Avatar Updates](https://dialtone.dialpad.com/guides/migration/avatar-updates/)
    -   [Logical Naming](https://dialtone.dialpad.com/guides/migration/logical-naming/)
    -   [Removal of Dialtone Recipes](https://dialtone.dialpad.com/guides/migration/recipes-to-ui-kits/)
    -   [Component Props & Events](https://dialtone.dialpad.com/guides/migration/component-props/)
    -   [DtChip interactive default](https://dialtone.dialpad.com/guides/migration/chip-interactive/)
    -   [Scrollbar :never → :always](https://dialtone.dialpad.com/guides/migration/scrollbar-always/)
    -   [Theme to Mode](https://dialtone.dialpad.com/guides/migration/theme-to-mode/)
    -   [DtModal Native Dialog](https://dialtone.dialpad.com/guides/migration/modal-native-dialog/)
    -   [Typography Utilities to DtText](https://dialtone.dialpad.com/guides/migration/typography/)
    -   [Vue 2 Removal](https://dialtone.dialpad.com/guides/migration/vue2-removal/)
    
-   [Accessibility](https://dialtone.dialpad.com/guides/accessibility/)
-   [Release Notes](https://dialtone.dialpad.com/dialtone/release-notes/)

-   
    
-   
    
-   
    
-   [Design Tokens](https://dialtone.dialpad.com/tokens/)
-   
    
-   [Vue Utilities New](https://dialtone.dialpad.com/functions-and-utilities/)
-   
    
-   [Downloads New](https://dialtone.dialpad.com/downloads/)

1.  [Overview](https://dialtone.dialpad.com/dialtone/)
2.  [Migration Guide](https://dialtone.dialpad.com/guides/migration/)

# CSS Cascade Layers

Dialtone now uses CSS Cascade Layers to organize all styles into a predictable hierarchy, improving specificity control and making overrides more predictable.

## TLDR [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#tldr)

Dialtone now uses CSS Cascade Layers (`@layer`) to organize all styles into a predictable hierarchy. This improves specificity control, makes overrides more predictable, and eliminates the need for complex selector specificity hacks.

**For Consumers**: This is a breaking change. Any app CSS that isn't wrapped in a named `@layer` will now unconditionally win over all Dialtone styles, regardless of specificity. Apps upgrading from Dialtone ≤9 will likely need to either adopt layers or use the [no-layers build](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#no-layers-build).

**For Contributors**: All new styles must be wrapped in the appropriate `@layer` block. See the [CSS Cascade Layers Guide](https://dialtone.dialpad.com/guides/css-layers/) for details.

## What Changed [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#what-changed)

All Dialtone CSS is now organized into four cascade layers:

```css
@layer dialtone.reset, dialtone.base, dialtone.components, dialtone.utilities;
```

### Layer Hierarchy [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#layer-hierarchy)

1.  **`dialtone.reset`** - CSS resets (normalize.css, typography resets)
2.  **`dialtone.base`** - Design tokens, fonts, themes, global styles
3.  **`dialtone.components`** - Component styles (buttons, inputs, modals, etc.)
4.  **`dialtone.utilities`** - Utility classes (spacing, colors, layout)

## Why This Matters [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#why-this-matters)

### Before: Specificity Wars [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#before-specificity-wars)

Previously, ensuring utilities could override components required:

-   Adding `!important` to every utility
-   Carefully managing selector specificity
-   Loading CSS files in the correct order
-   Hoping third-party CSS didn't break things

### After: Predictable Cascade [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#after-predictable-cascade)

With cascade layers:

-   **Utilities always override components.** Layer order guarantees it.
-   **No specificity hacks needed.** Layer priority beats specificity.
-   **Clear organization.** Every style has a clear home.
-   **Third-party CSS control.** Can layer external CSS between Dialtone layers.

## How Layers Work [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#how-layers-work)

### Normal Cascade (Highest to Lowest Priority) [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#normal-cascade-highest-to-lowest-priority)

1.  **Unlayered styles** (highest)
2.  `dialtone.utilities`
3.  `dialtone.components`
4.  `dialtone.base`
5.  `dialtone.reset` (lowest)

### With `!important` (Order Reverses!) [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#with-important-order-reverses)

1.  **`dialtone.reset !important`** (highest)
2.  `dialtone.base !important`
3.  `dialtone.components !important`
4.  `dialtone.utilities !important`
5.  **Unlayered `!important`** (lowest)

> **Why utilities use `!important`**: Within the layered system, Dialtone utility `!important` declarations outrank all other layered `!important` declarations and — because of how layers reverse `!important` priority — also outrank your unlayered `!important`. This guarantees utilities always win over components, but means consumer `!important` overrides targeting the same properties will not work. Put overrides in a named layer declared after `dialtone.utilities` instead.

## For Consumers [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#for-consumers)

### What breaks [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#what-breaks)

Because all Dialtone styles are now inside named `@layer` blocks, **any unlayered CSS in your app automatically wins over Dialtone** — regardless of specificity or source order. This is how the cascade layer spec works, and it has two practical consequences:

**1\. Your app styles may unexpectedly override Dialtone**

If your app has unlayered CSS targeting the same elements as Dialtone components, those rules now win even if they have lower specificity. You may see Dialtone component styles disappearing or being partially overridden where they previously showed correctly.

**2\. Your `!important` overrides now lose to Dialtone's layered `!important`**

With layers, `!important` priority order reverses: Dialtone's `!important` utility classes are inside `@layer dialtone.utilities`, so your unlayered `!important` has _lower_ priority than Dialtone's. Overrides that previously used `!important` to beat Dialtone may stop working.

### Recommended migration [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#recommended-migration)

Think about the _intent_ of each piece of your app CSS before deciding where it belongs in the layer order:

-   **Before Dialtone** — foundational styles that Dialtone should be able to override: app-level resets, base element defaults, design tokens your own system defines.
-   **After Dialtone** — styles that must win over Dialtone: feature-specific layout rules, or customizations to a Dialtone component when the component's own props and tokens aren't sufficient. Prefer using component props, CSS custom properties, and Dialtone utility classes before reaching for overrides.

```css
@layer app.base, dialtone.reset, dialtone.base, dialtone.components, dialtone.utilities, app.overrides;

@layer app.base {
  /* Foundational styles Dialtone can override */
}

@layer app.overrides {
  /* Component and page styles that override Dialtone */
}
```

Specificity works as expected within each layer, so you don't need to increase selector specificity to win — layer order handles it.

If you cannot migrate your app CSS to use layers, use the [no-layers build](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#no-layers-build) instead.

### No-Layers Build [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#no-layers-build)

If your project cannot use CSS Cascade Layers — older browser requirements, an existing specificity system, or a bundler that doesn't support `@layer` — import the no-layers variant instead:

```javascript
// @dialpad/dialtone-css
import '@dialpad/dialtone-css/no-layers';
import '@dialpad/dialtone-css/no-layers/default-theme'; // optional theme

// @dialpad/dialtone
import '@dialpad/dialtone/css/no-layers';
import '@dialpad/dialtone/css/no-layers/default-theme'; // optional theme
```

This build is identical in output — all the same classes — but no `@layer` wrappers are present.

If you import token CSS directly from `@dialpad/dialtone-tokens` (rather than through `@dialpad/dialtone-css` or `@dialpad/dialtone`), use its own no-layers variant instead:

```javascript
import '@dialpad/dialtone-tokens/no-layers/tokens-base-light.css';
import '@dialpad/dialtone-tokens/no-layers/tokens-dp-light.css';
```

If you theme at runtime, use `initDialtoneThemeNoLayers` from `@dialpad/dialtone-tokens/themes/config-no-layers` to load the no-layers core tokens:

```javascript
import { initDialtoneThemeNoLayers } from '@dialpad/dialtone/themes/config-no-layers';
import Dp from '@dialpad/dialtone/themes/dp';

initDialtoneThemeNoLayers(Dp, 'light', document.documentElement);
```

`initDialtoneTheme(..., { layers: false })` from `@dialpad/dialtone-tokens/themes/config` still works too, but resolves the no-layers core via a runtime dynamic import, so it applies a moment after the call returns rather than synchronously — prefer `initDialtoneThemeNoLayers` for new code.

`setBrand`, `setContrast`, and `setMaterial` need no equivalent option — brand, contrast, and material overrides were never wrapped in `@layer` to begin with.

\`!important\` behavior differs in the no-layers build

In the layered build, Dialtone's `!important` utility declarations beat your unlayered `!important` (because `!important` priority reverses across layers). In the no-layers build, both sides are unlayered, so your `!important` can beat Dialtone's through normal cascade. However, your non-`!important` rules will lose to Dialtone utility `!important` — you will need `!important` in your own overrides to beat utilities.

### Third-Party CSS [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#third-party-css)

If you're using third-party CSS that conflicts with Dialtone, wrap it in a layer:

```css
@layer dialtone.reset, dialtone.base, dialtone.components, third-party, dialtone.utilities;

@layer third-party {
  @import 'some-library/styles.css';
}
```

This ensures Dialtone utilities can still override third-party styles.

## For Contributors [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#for-contributors)

### All Styles Must Be Layered [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#all-styles-must-be-layered)

When adding new styles, wrap them in the appropriate layer:

**Components:**

```less
@layer dialtone.components {
  .d-my-component {
    /* styles */
  }
}
```

**Utilities:**

```less
@layer dialtone.utilities {
  .d-my-util { property: value !important; }
}
```

### Cross-Layer Mixins [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#cross-layer-mixins)

To share styles between layers, extract parametric mixins **outside** `@layer` blocks:

```less
// Outside @layer for cross-file access
._my-mixin() {
  display: flex;
  align-items: center;
}

@layer dialtone.components {
  .d-component { ._my-mixin(); }
}
```

### Validation [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#validation)

The build pipeline now validates that all Dialtone classes are properly layered. Unlayered classes will fail CI.

See the [CSS Layers Contributor Guide](https://dialtone.dialpad.com/guides/css-layers/) for complete documentation.

## Examples [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#examples)

### Utility Classes Override Components [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#utility-classes-override-components)

```html
<!-- Component default: blue background -->
<button class="d-btn d-bgc-critical">
  <!-- Utility wins: red background -->
</button>
```

### Responsive Utilities [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#responsive-utilities)

Responsive utilities are now in the same layer as base utilities, ensuring consistent behavior:

```html
<div class="d-d-none lg:d-d-block">
  <!-- Hidden by default, visible on large screens -->
</div>
```

### App Overrides [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#app-overrides)

```css
@layer app.overrides {
  .d-btn--custom {
    border-radius: 999px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  }
}
```

## Browser Support [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#browser-support)

CSS Cascade Layers are supported in all modern browsers:

-   Chrome 99+
-   Firefox 97+
-   Safari 15.4+
-   Edge 99+

If you need to support older browsers, use the [no-layers build](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#no-layers-build) instead of relying on undefined fallback behavior.

## Learn More [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#learn-more)

-   [CSS Cascade Layers in Dialtone](https://dialtone.dialpad.com/guides/css-layers/)
-   [MDN: CSS Cascade Layers](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@layer)
-   [CSS Cascade Layers Explainer](https://css.oddbird.net/layers/explainer/)

## Migration Path [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#migration-path)

### Option A — Adopt layers (recommended) [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#option-a-%E2%80%94-adopt-layers-recommended)

Declare named app layers and place your CSS based on intent — foundational styles before Dialtone, overrides after. This is the forward-compatible path and gives you the full benefits of the cascade layer system.

```css
@layer app.base, dialtone.reset, dialtone.base, dialtone.components, dialtone.utilities, app.overrides;

@layer app.base {
  /* Foundational styles: resets, base element defaults, your own tokens */
}

@layer app.overrides {
  /* Overrides: component customizations, feature-specific layout rules */
}
```

See [Using CSS Layers with Dialtone](https://dialtone.dialpad.com/guides/css-layers/) for detailed guidance on layer ordering, third-party CSS, and per-component overrides.

### Option B — Use the no-layers build [#](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#option-b-%E2%80%94-use-the-no-layers-build)

If adopting layers is not feasible, switch to the no-layers CSS import. All Dialtone classes are present; `@layer` wrappers are stripped at build time. Specificity and cascade behave as they did in Dialtone ≤9.

```javascript
import '@dialpad/dialtone/css/no-layers';       // @dialpad/dialtone
import '@dialpad/dialtone-css/no-layers';        // @dialpad/dialtone-css
```

\`!important\` behavior in the no-layers build

Dialtone utility `!important` declarations are fully unlayered, so they beat your non-`!important` rules. Use `!important` in your own overrides where needed.

[Previous Border-Radius Logical Names](https://dialtone.dialpad.com/guides/migration/border-radius/) [Next Color Stops](https://dialtone.dialpad.com/guides/migration/color-stops/)

CSS Cascade Layers documentation last updated Tuesday, October 20, 2026

## On this page

-   [TLDR](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#tldr)

-   [What Changed](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#what-changed)
    

-   [Why This Matters](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#why-this-matters)
    

-   [How Layers Work](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#how-layers-work)
    

-   [For Consumers](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#for-consumers)
    

-   [For Contributors](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#for-contributors)
    

-   [Examples](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#examples)
    

-   [Browser Support](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#browser-support)

-   [Learn More](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#learn-more)

-   [Migration Path](https://dialtone.dialpad.com/guides/migration/css-cascade-layers/#migration-path)

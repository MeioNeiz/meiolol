# How to fix flaky visual tests: every root cause, solved

<https://argos-ci.com/blog/fix-flaky-visual-tests>

-   
-   
-   [Customers](https://argos-ci.com/customers)
-   [Pricing](https://argos-ci.com/pricing)

[Guides](https://argos-ci.com/blog/category/guides)

# How to fix flaky visual tests: every root cause, solved

Flaky visual tests come from a short list of root causes: fonts, animations, lazy loading, dynamic data. Here is the fix for each one, with code.

Greg BergéCo-founder and CEO

August 4, 2026

A flaky visual test is a test whose screenshot changes between runs even though the code under test did not. The diff is real (pixels really changed), but the cause is nondeterministic rendering: a font that loaded late, an animation caught mid-frame, a lazy-loaded image, a timestamp, or a GPU rendering text slightly differently. The good news is that the list of root causes is short and every one of them has a known fix.

## What is a flaky visual test?

In visual testing, flakiness almost never means "the diff algorithm is wrong." The screenshot really does differ from the baseline. The problem is that the difference comes from unstable rendering conditions, not from your code. That distinction matters because it tells you where to fix it: **make the page deterministic before capture**, and only then tune tolerance on the comparison side.

Flaky visual tests are expensive in a specific way. Each false positive trains reviewers to click "approve" without looking, which is how real regressions slip through. Fixing flakiness is not about comfort, it's about keeping the signal trustworthy.

Below are the seven root causes I see most often across the projects using [Argos](https://argos-ci.com/docs/quickstart), with the concrete fix for each.

## Why do web fonts cause flaky screenshots?

Web fonts load over the network. If the screenshot fires before the font arrives, the browser renders the fallback font, and every text node on the page shifts by a few pixels. This is the single most common source of full-page diffs.

The fix is to wait for the [CSS Font Loading API](https://developer.mozilla.org/en-US/docs/Web/API/CSS_Font_Loading_API) to settle before capturing:

```
await page.evaluate(() => document.fonts.ready);
await expect(page).toHaveScreenshot();
```

Also make sure your test environment actually serves the fonts. A font that 404s in CI but loads locally produces baselines that never match.

## How do you disable animations and transitions in screenshot tests?

A screenshot taken mid-animation captures an arbitrary frame: a fading toast at 40% opacity, a spinner at a random angle, a blinking text caret that is visible in one run and invisible in the next.

Playwright's `toHaveScreenshot` disables CSS animations by default, but if you capture screenshots another way (or your framework doesn't), inject this CSS before capture:

```
*,
*::before,
*::after {
  animation: none !important;
  transition: none !important;
  caret-color: transparent !important;
}
```

Two caveats:

-   **JavaScript-driven animations** (GSAP, `requestAnimationFrame` loops, canvas) are not affected by CSS overrides. Expose a flag in your app to disable them under test, or hide the animated element entirely.
-   If an animation causes **layout shift** (an element animating its height, for example), hiding it visually is not enough. Remove it from the DOM in test mode so the layout stays stable.

## How do you stabilize images and lazy loading?

Images fail in two ways: they load after the screenshot (blank rectangle in one run, photo in the next), or lazy loading (`loading="lazy"`, IntersectionObserver-based components) never triggers because the element is below the fold when the capture happens.

Wait for every image in the DOM to be decoded before capturing:

```
await page.waitForFunction(() =>
  Array.from(document.images).every(
    (img) => img.complete && img.naturalWidth > 0,
  ),
);
```

For lazy loading, either scroll the page once to trigger loading, or disable lazy loading in your test environment. And beware of responsive images: `srcset` can make the browser pick a different asset between runs depending on timing. We documented that rabbit hole in [our journey to image stabilization](https://argos-ci.com/blog/images-stabilization).

## How do you handle network-dependent content?

If your page renders data fetched from a live API, your screenshots inherit every instability of that API: latency, ordering, content changes, rate limits, third-party widgets (chat bubbles, analytics banners, ads).

The robust fix is to mock the network in your tests:

```
await page.route("**/api/products", (route) =>
  route.fulfill({ json: productsFixture }),
);
```

Order of preference:

1.  **Seed a stable dataset** in your test environment, so the whole app is deterministic.
2.  **Mock the specific endpoints** that vary, with `page.route` in Playwright or `cy.intercept` in Cypress.
3.  **Hide or mask** what you cannot control (third-party iframes, embedded maps) with CSS injected at capture time.

Third-party scripts deserve special mention: the Intercom bubble or a cookie banner appearing 200ms late will flake forever. Don't load them in your test environment at all.

## How do you fix flaky tests caused by dates and random data?

`new Date()`, "3 minutes ago" labels, randomized IDs, shuffled lists: anything nondeterministic in your data ends up nondeterministic in your pixels.

Playwright ships a clock API that freezes time for the whole page:

```
await page.clock.setFixedTime(new Date("2026-08-25T10:00:00Z"));
```

Cypress has the equivalent [`cy.clock()`](https://docs.cypress.io/api/commands/clock). For random data, seed your generators (Faker and friends all accept a seed) and add a stable `ORDER BY` to any list query that feeds the UI. A missing sort order is a classic: the database returns rows in a valid but unstable order, and your screenshot flips between two arrangements.

## Why do screenshots differ between machines (anti-aliasing, GPU, OS)?

Run the same test on macOS and on Linux CI and the screenshots will not match. Font rasterization, sub-pixel anti-aliasing, and GPU rendering paths differ across OS, browser version, and even hardware. This is the failure mode that makes Playwright's built-in `toHaveScreenshot` painful at scale: baselines generated on your laptop are worthless in CI, and vice versa (more on that in [the limits of Playwright visual testing](https://argos-ci.com/blog/playwright-visual-testing-limits)).

Two-part fix:

1.  **Capture in one canonical environment.** Always generate screenshots in CI (or in the same Docker image everywhere), never mix local and CI baselines.
2.  **Tolerate sub-pixel noise on the comparison side.** Anti-aliasing differences are 1-pixel-wide edges around glyphs; a good diff algorithm can ignore them without masking real changes.

You cannot fully eliminate this class with page-level fixes. It's the main reason a diffing platform earns its keep.

## How do viewport and scrollbar differences break visual tests?

If the viewport size varies, everything reflows and every screenshot diffs. Pin it explicitly in your Playwright config:

```
use: {
  viewport: { width: 1280, height: 720 },
  deviceScaleFactor: 1,
},
```

Scrollbars are the sneaky variant: macOS uses overlay scrollbars (zero width), Linux and Windows use classic scrollbars that consume ~15px of layout. A page that scrolls in CI but not locally renders at different content widths. Capture in a consistent environment and hide scrollbars with CSS (`::-webkit-scrollbar { display: none }`) if they appear in your captures.

## What does Argos fix for you automatically?

Everything above is fixable by hand. The question is whether you want to maintain that stabilization code in every project, forever. Argos ships most of it in the SDK and handles the rest on the platform side.

**SDK auto-stabilization.** The `argosScreenshot` command from [`@argos-ci/playwright`](https://argos-ci.com/docs/quickstart/playwright-quickstart) (and the Cypress, Puppeteer, and WebdriverIO equivalents) waits for fonts to load, images to be decoded, the network to be idle, and `[aria-busy]` loaders to disappear before capturing. It also hides carets and scrollbars and pauses CSS animations. The full checklist is in our [screenshot stabilization guide](https://argos-ci.com/blog/screenshot-stabilization).

```
import { argosScreenshot } from "@argos-ci/playwright";

test("homepage", async ({ page }) => {
  await page.goto("/");
  await argosScreenshot(page, "homepage");
});
```

**Per-screenshot sensitivity threshold.** For screenshots that stay noisy (canvas rendering, embedded maps), you can relax sensitivity on that one capture instead of your whole suite. The threshold goes from 0 (strict) to 1 (permissive), with a 0.5 default tuned to absorb anti-aliasing noise:

```
await argosScreenshot(page, "dashboard-chart", {
  threshold: 0.8,
});
```

**Flaky test detection.** Argos surfaces flaky test signals in the UI, so a screenshot that keeps changing without related code changes gets flagged instead of silently eroding trust.

**Retries shown separately.** Playwright test retries are displayed separately in the Argos UI, so a test that passed on retry is visible as such rather than hiding intermittent failures. Combined with the [Playwright trace viewer integration](https://argos-ci.com/stabilize#debug), you can open the trace of the flaky run and see exactly what the page was doing at capture time.

Because Argos captures screenshots **locally in the real browser your tests already run**, there is no cloud re-rendering step to introduce a second source of nondeterminism: what you saw in your test is exactly what gets diffed.

## Conclusion

Flaky visual tests are not random. They come from a finite list of causes: fonts, animations, images, network, dynamic data, rendering environments, and viewports, and each has a deterministic fix. Stabilize the page first, capture in one canonical environment, then apply tolerance surgically per screenshot rather than globally. If you'd rather not maintain that machinery yourself, the Argos SDK bakes the stabilization in and the platform flags whatever flakiness remains. You can [get started](https://argos-ci.com/docs/quickstart) with 5,000 free screenshots per month.

## FAQ

### Why do my screenshot tests fail when I didn't change any code?

Because something nondeterministic rendered differently: a web font loaded after the capture, an animation was caught mid-frame, a lazy image hadn't decoded, or a timestamp changed. The pixels really differ; the instability is in the rendering conditions, not the diff. Work through the root causes above one by one, starting with fonts and animations.

### Should I just increase the diff threshold to make flaky tests pass?

Not as a first move. A global tolerance high enough to absorb a font swap or a mid-animation frame will also absorb real one-line CSS regressions. Fix determinism at the source first, then use a per-screenshot threshold only for captures that are inherently noisy, like canvas charts or maps.

### Do test retries fix flaky visual tests?

Retries hide flakiness, they don't fix it. A retry that passes means the unstable condition didn't occur that time, and it will be back. Retries are useful as a safety net while you fix root causes, which is why Argos shows Playwright retries separately instead of blending them into the results.

### Why do my screenshots differ between my laptop and CI?

Font rasterization, anti-aliasing, GPU rendering, and scrollbar widths all differ across OS and hardware, so pixel-identical output across machines is not achievable. Generate all baselines in a single canonical environment (your CI, or a shared Docker image) and never mix locally captured baselines with CI captures.

### Can visual tests ever be 100% flake-free?

You can get very close. Deterministic data, frozen clocks, disabled animations, awaited fonts and images, and a single capture environment eliminate the vast majority of flakiness. What remains (sub-pixel rendering noise) is handled on the comparison side by a diff algorithm designed to ignore anti-aliasing, which is exactly what Argos does by default.

### Read also

## Supercharge your product quality

See every change your team and your agents make. Review with confidence, and merge faster.

[Sign up](https://app.argos-ci.com/signup)[Request demo](https://cal.com/gregberge)

Open-source visual regression testing for Playwright, Storybook, Vitest and Cypress.

Product

[Diff](https://argos-ci.com/diff)

[Review](https://argos-ci.com/review)

[Stabilize](https://argos-ci.com/stabilize)

[Deploy](https://argos-ci.com/deploy)

[For AI Agents](https://argos-ci.com/ai-agents)

[Media Sharing](https://argos-ci.com/media-sharing)

Integrations

[Playwright](https://argos-ci.com/integrations/playwright)

[Storybook](https://argos-ci.com/integrations/storybook)

[Vitest](https://argos-ci.com/integrations/vitest)

[Cypress](https://argos-ci.com/integrations/cypress)

[All integrations](https://argos-ci.com/integrations)

Resources

[Docs](https://argos-ci.com/docs)

[Pricing](https://argos-ci.com/pricing)

[OSS Friends](https://argos-ci.com/oss-friends)

Company

[About](https://argos-ci.com/about)

[Community](https://argos-ci.com/community)

[Changelog](https://argos-ci.com/changelog)

[Blog](https://argos-ci.com/blog)

[Security](https://argos-ci.com/security)

[Contact](https://argos-ci.com/contact)

[Privacy](https://argos-ci.com/privacy)

[Terms](https://argos-ci.com/terms)

[DPA](https://argos-ci.com/dpa)

Compare

[Percy](https://argos-ci.com/compare/percy)

[Applitools](https://argos-ci.com/compare/applitools)

[Chromatic](https://argos-ci.com/compare/chromatic)

[Playwright snapshots](https://argos-ci.com/compare/playwright)

[BackstopJS](https://argos-ci.com/compare/backstopjs)

[Lost Pixel](https://argos-ci.com/compare/lost-pixel)

[Happo](https://argos-ci.com/compare/happo)

[All systems normal](https://argos.openstatus.dev/)

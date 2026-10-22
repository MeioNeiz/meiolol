# Visual comparisons | Playwright

<https://playwright.dev/docs/test-snapshots>

[Skip to main content](https://playwright.dev/docs/test-snapshots#__docusaurus_skipToContent_fallback)

[

**Playwright**](https://playwright.dev/)[Docs](https://playwright.dev/docs/intro)[MCP](https://playwright.dev/mcp/introduction)[CLI](https://playwright.dev/agent-cli/introduction)[API](https://playwright.dev/docs/api/class-playwright)

[Node.js](https://playwright.dev/docs/test-snapshots#)

-   [Node.js](https://playwright.dev/docs/test-snapshots)
-   [Python](https://playwright.dev/python/docs/test-runners)
-   [Java](https://playwright.dev/java/docs/test-runners)
-   [.NET](https://playwright.dev/dotnet/docs/test-runners)

-   [Getting Started](https://playwright.dev/docs/test-snapshots#)
    
    -   [Installation](https://playwright.dev/docs/intro)
    -   [Writing tests](https://playwright.dev/docs/writing-tests)
    -   [Generating tests](https://playwright.dev/docs/codegen-intro)
    -   [Running and debugging tests](https://playwright.dev/docs/running-tests)
    -   [Trace viewer](https://playwright.dev/docs/trace-viewer-intro)
    -   [Setting up CI](https://playwright.dev/docs/ci-intro)
    -   [VS Code](https://playwright.dev/docs/getting-started-vscode)
-   [Release notes](https://playwright.dev/docs/release-notes)
-   [Canary releases](https://playwright.dev/docs/canary-releases)
-   [Playwright Test](https://playwright.dev/docs/test-snapshots#)
    
    -   [Agents](https://playwright.dev/docs/test-agents)
    -   [Annotations](https://playwright.dev/docs/test-annotations)
    -   [Command line](https://playwright.dev/docs/test-cli)
    -   [Configuration](https://playwright.dev/docs/test-configuration)
    -   [Configuration (use)](https://playwright.dev/docs/test-use-options)
    -   [Emulation](https://playwright.dev/docs/emulation)
    -   [Fixtures](https://playwright.dev/docs/test-fixtures)
    -   [Global setup and teardown](https://playwright.dev/docs/test-global-setup-teardown)
    -   [Parallelism](https://playwright.dev/docs/test-parallel)
    -   [Parameterize tests](https://playwright.dev/docs/test-parameterize)
    -   [Projects](https://playwright.dev/docs/test-projects)
    -   [Reporters](https://playwright.dev/docs/test-reporters)
    -   [Retries](https://playwright.dev/docs/test-retries)
    -   [Sharding](https://playwright.dev/docs/test-sharding)
    -   [Timeouts](https://playwright.dev/docs/test-timeouts)
    -   [TypeScript](https://playwright.dev/docs/test-typescript)
    -   [UI Mode](https://playwright.dev/docs/test-ui-mode)
    -   [Web server](https://playwright.dev/docs/test-webserver)
-   [Guides](https://playwright.dev/docs/test-snapshots#)
    
    -   [Library](https://playwright.dev/docs/library)
    -   [Accessibility testing](https://playwright.dev/docs/accessibility-testing)
    -   [Actions](https://playwright.dev/docs/input)
    -   [Assertions](https://playwright.dev/docs/test-assertions)
    -   [API testing](https://playwright.dev/docs/api-testing)
    -   [Authentication](https://playwright.dev/docs/auth)
    -   [Auto-waiting](https://playwright.dev/docs/actionability)
    -   [Best Practices](https://playwright.dev/docs/best-practices)
    -   [Browsers](https://playwright.dev/docs/browsers)
    -   [Chrome extensions](https://playwright.dev/docs/chrome-extensions)
    -   [Clock](https://playwright.dev/docs/clock)
    -   [Component testing](https://playwright.dev/docs/test-components)
    -   [Debugging Tests](https://playwright.dev/docs/debug)
    -   [Dialogs](https://playwright.dev/docs/dialogs)
    -   [Downloads](https://playwright.dev/docs/downloads)
    -   [Evaluating JavaScript](https://playwright.dev/docs/evaluating)
    -   [Events](https://playwright.dev/docs/events)
    -   [Extensibility](https://playwright.dev/docs/extensibility)
    -   [Frames](https://playwright.dev/docs/frames)
    -   [Handles](https://playwright.dev/docs/handles)
    -   [Isolation](https://playwright.dev/docs/browser-contexts)
    -   [Locators](https://playwright.dev/docs/locators)
    -   [Mock APIs](https://playwright.dev/docs/mock)
    -   [Mock browser APIs](https://playwright.dev/docs/mock-browser-apis)
    -   [Navigations](https://playwright.dev/docs/navigations)
    -   [Network](https://playwright.dev/docs/network)
    -   [Other locators](https://playwright.dev/docs/other-locators)
    -   [Pages](https://playwright.dev/docs/pages)
    -   [Page object models](https://playwright.dev/docs/pom)
    -   [Screenshots](https://playwright.dev/docs/screenshots)
    -   [Service Workers](https://playwright.dev/docs/service-workers)
    -   [Snapshot testing](https://playwright.dev/docs/aria-snapshots)
    -   [Test generator](https://playwright.dev/docs/codegen)
    -   [Touch events (legacy)](https://playwright.dev/docs/touch-events)
    -   [Trace viewer](https://playwright.dev/docs/trace-viewer)
    -   [Videos](https://playwright.dev/docs/videos)
    -   [Visual comparisons](https://playwright.dev/docs/test-snapshots)
    -   [WebView2](https://playwright.dev/docs/webview2)
-   [Migration](https://playwright.dev/docs/test-snapshots#)
    
-   [Integrations](https://playwright.dev/docs/test-snapshots#)
    
-   [Supported languages](https://playwright.dev/docs/languages)

-   
-   Guides
-   Visual comparisons

# Visual comparisons

## Introduction[​](https://playwright.dev/docs/test-snapshots#introduction "Direct link to Introduction")

Playwright Test includes the ability to produce and visually compare screenshots using `await expect(page).toHaveScreenshot()`. On first execution, Playwright test will generate reference screenshots. Subsequent runs will compare against the reference.

example.spec.ts

```
import { test, expect } from '@playwright/test';test('example test', async ({ page }) => {  await page.goto('https://playwright.dev');  await expect(page).toHaveScreenshot();});
```

warning

Browser rendering can vary based on the host OS, version, settings, hardware, power source (battery vs. power adapter), headless mode, and other factors. For consistent screenshots, run tests in the same environment where the baseline screenshots were generated.

## Generating screenshots[​](https://playwright.dev/docs/test-snapshots#generating-screenshots "Direct link to Generating screenshots")

When you run above for the first time, test runner will say:

```
Error: A snapshot doesn't exist at example.spec.ts-snapshots/example-test-1-chromium-darwin.png, writing actual.
```

That's because there was no golden file yet. This method took a bunch of screenshots until two consecutive screenshots matched, and saved the last screenshot to file system. It is now ready to be added to the repository.

The name of the folder with the golden expectations starts with the name of your test file:

```
drwxr-xr-x  5 user  group  160 Jun  4 11:46 .drwxr-xr-x  6 user  group  192 Jun  4 11:45 ..-rw-r--r--  1 user  group  231 Jun  4 11:16 example.spec.tsdrwxr-xr-x  3 user  group   96 Jun  4 11:46 example.spec.ts-snapshots
```

The snapshot name `example-test-1-chromium-darwin.png` consists of a few parts:

-   `example-test-1.png` - an auto-generated name of the snapshot. Alternatively you can specify snapshot name as the first argument of the `toHaveScreenshot()` method:
    
    ```
    await expect(page).toHaveScreenshot('landing.png');
    ```
    
-   `chromium-darwin` - the browser name and the platform. Screenshots differ between browsers and platforms due to different rendering, fonts and more, so you will need different snapshots for them. If you use multiple projects in your [configuration file](https://playwright.dev/docs/test-configuration), project name will be used instead of `chromium`.
    

The snapshot name and path can be configured with [testConfig.snapshotPathTemplate](https://playwright.dev/docs/api/class-testconfig#test-config-snapshot-path-template) in the playwright config.

Snapshots are stored as PNG by default. Give the snapshot a name with the `.webp` extension to store it in the WebP format instead, it is also lossless:

```
await expect(page).toHaveScreenshot('landing.webp');
```

To store all unnamed snapshots as WebP, set the `type` option in the [testConfig.expect](https://playwright.dev/docs/api/class-testconfig#test-config-expect) configuration:

playwright.config.ts

```
import { defineConfig } from '@playwright/test';export default defineConfig({  expect: {    toHaveScreenshot: {      type: 'webp',    },  },});
```

> Note that `toHaveScreenshot()` also accepts an array of path segments to the snapshot file such as `expect().toHaveScreenshot(['relative', 'path', 'to', 'snapshot.png'])`. However, this path must stay within the snapshots directory for each test file (i.e. `a.spec.js-snapshots`), otherwise it will throw.

## Updating screenshots[​](https://playwright.dev/docs/test-snapshots#updating-screenshots "Direct link to Updating screenshots")

Sometimes you need to update the reference screenshot, for example when the page has changed. Do this with the `--update-snapshots` flag.

```
npx playwright test --update-snapshots
```

## Hover effects[​](https://playwright.dev/docs/test-snapshots#hover-effects "Direct link to Hover effects")

Screenshots capture any hover effects present in the page at the moment. To avoid hover effects, move the mouse to a position that does not trigger them, or hover an element that has no effects, before taking the screenshot:

```
await page.mouse.move(-1, -1);await expect(page).toHaveScreenshot();
```

## Options[​](https://playwright.dev/docs/test-snapshots#options "Direct link to Options")

### maxDiffPixels and threshold[​](https://playwright.dev/docs/test-snapshots#maxdiffpixels-and-threshold "Direct link to maxDiffPixels and threshold")

Playwright Test uses the [pixelmatch](https://github.com/mapbox/pixelmatch) library. You can [pass various options](https://playwright.dev/docs/api/class-pageassertions#page-assertions-to-have-screenshot-1) to modify its behavior:

-   `threshold` defines which pixels are considered different. It is an acceptable perceived color difference between the same pixel in compared images, between `0` (strict) and `1` (lax). Defaults to `0.2`.
-   `maxDiffPixels` is an acceptable amount of pixels that could be different. Unset by default.

example.spec.ts

```
import { test, expect } from '@playwright/test';test('example test', async ({ page }) => {  await page.goto('https://playwright.dev');  await expect(page).toHaveScreenshot({ maxDiffPixels: 100, threshold: 0.1 });});
```

If you'd like to share the default values among all the tests in the project, you can specify them in the playwright config, either globally or per project:

playwright.config.ts

```
import { defineConfig } from '@playwright/test';export default defineConfig({  expect: {    toHaveScreenshot: { maxDiffPixels: 100, threshold: 0.1 },  },});
```

### stylePath[​](https://playwright.dev/docs/test-snapshots#stylepath "Direct link to stylePath")

You can apply a custom stylesheet to your page while taking screenshot. This allows filtering out dynamic or volatile elements, hence improving the screenshot determinism.

screenshot.css

```
iframe {  visibility: hidden;}
```

example.spec.ts

```
import { test, expect } from '@playwright/test';test('example test', async ({ page }) => {  await page.goto('https://playwright.dev');  await expect(page).toHaveScreenshot({ stylePath: path.join(__dirname, 'screenshot.css') });});
```

If you'd like to share the default value among all the tests in the project, you can specify it in the playwright config, either globally or per project:

playwright.config.ts

```
import { defineConfig } from '@playwright/test';export default defineConfig({  expect: {    toHaveScreenshot: {      stylePath: './screenshot.css'    },  },});
```

## Non-image snapshots[​](https://playwright.dev/docs/test-snapshots#non-image-snapshots "Direct link to Non-image snapshots")

Apart from screenshots, you can use `expect(value).toMatchSnapshot(snapshotName)` to compare text or arbitrary binary data. Playwright Test auto-detects the content type and uses the appropriate comparison algorithm.

Here we compare text content against the reference.

example.spec.ts

```
import { test, expect } from '@playwright/test';test('example test', async ({ page }) => {  await page.goto('https://playwright.dev');  expect(await page.textContent('.hero__title')).toMatchSnapshot('hero.txt');});
```

Snapshots are stored next to the test file, in a separate directory. For example, `my.spec.ts` file will produce and store snapshots in the `my.spec.ts-snapshots` directory. You should commit this directory to your version control (e.g. `git`), and review any changes to it.

[

Previous

Videos

](https://playwright.dev/docs/videos)[

Next

WebView2

](https://playwright.dev/docs/webview2)

-   [Introduction](https://playwright.dev/docs/test-snapshots#introduction)
-   [Generating screenshots](https://playwright.dev/docs/test-snapshots#generating-screenshots)
-   [Updating screenshots](https://playwright.dev/docs/test-snapshots#updating-screenshots)
-   [Hover effects](https://playwright.dev/docs/test-snapshots#hover-effects)
-   [Options](https://playwright.dev/docs/test-snapshots#options)
    -   [maxDiffPixels and threshold](https://playwright.dev/docs/test-snapshots#maxdiffpixels-and-threshold)
    -   [stylePath](https://playwright.dev/docs/test-snapshots#stylepath)
-   [Non-image snapshots](https://playwright.dev/docs/test-snapshots#non-image-snapshots)

Learn

-   [Getting started](https://playwright.dev/docs/intro)
-   [Playwright Training](https://learn.microsoft.com/en-us/training/modules/build-with-playwright/)
-   [Learn Videos](https://playwright.dev/community/learn-videos)
-   [Feature Videos](https://playwright.dev/community/feature-videos)

Community

-   [Stack Overflow](https://stackoverflow.com/questions/tagged/playwright)
-   [Discord](https://aka.ms/playwright/discord)
-   [X](https://x.com/playwrightweb)
-   [LinkedIn](https://www.linkedin.com/company/playwrightweb)

More

-   [GitHub](https://github.com/microsoft/playwright)
-   [YouTube](https://www.youtube.com/channel/UC46Zj8pDH5tDosqm1gd7WTg)
-   [Blog](https://dev.to/playwright)
-   [Ambassadors](https://playwright.dev/community/ambassadors)
-   [Microsoft Privacy Statement](https://go.microsoft.com/fwlink/?LinkId=521839)

Copyright © 2026 Microsoft

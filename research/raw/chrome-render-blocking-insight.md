# Render-blocking requests  |  Performance insights  |  Chrome for Developers

<https://developer.chrome.com/docs/performance/insights/render-blocking>

[Skip to main content](https://developer.chrome.com/docs/performance/insights/render-blocking#main-content)

developer.chrome.com uses cookies to deliver and enhance the quality of its services and to analyze traffic. If you agree, cookies are also used to serve advertising and to personalize the content and advertisements that you see. [Learn more](https://policies.google.com/technologies/cookies?hl=en)

[Docs](https://developer.chrome.com/docs) [Case studies](https://developer.chrome.com/case-studies) [Blog](https://developer.chrome.com/blog) [New in Chrome](https://developer.chrome.com/new)

/

-   [Docs](https://developer.chrome.com/docs)
-   [Performance](https://developer.chrome.com/docs/performance)
-   [Performance insights](https://developer.chrome.com/docs/performance/insights)

-   [Overview](https://developer.chrome.com/docs/performance/insights)
-   Tools using Insights
    
-   [DevTools Performance panel](https://developer.chrome.com/docs/devtools/performance/overview)
-   [Lighthouse Performance audits](https://developer.chrome.com/docs/lighthouse/performance)
-   Insights
    
-   [CSS selector costs](https://developer.chrome.com/docs/performance/insights/slow-css-selector)
-   [Declare a character encoding](https://developer.chrome.com/docs/performance/insights/charset)
-   [Document request latency](https://developer.chrome.com/docs/performance/insights/document-latency)
-   [Duplicated JavaScript](https://developer.chrome.com/docs/performance/insights/duplicated-javascript)
-   [Font display](https://developer.chrome.com/docs/performance/insights/font-display)
-   [Forced reflow](https://developer.chrome.com/docs/performance/insights/forced-reflow)
-   [Improve image delivery](https://developer.chrome.com/docs/performance/insights/image-delivery)
-   [INP breakdown](https://developer.chrome.com/docs/performance/insights/inp-breakdown)
-   [Layout shift culprits](https://developer.chrome.com/docs/performance/insights/cls-culprit)
-   [LCP breakdown](https://developer.chrome.com/docs/performance/insights/lcp-breakdown)
-   [LCP request discovery](https://developer.chrome.com/docs/performance/insights/lcp-discovery)
-   [Legacy JavaScript](https://developer.chrome.com/docs/performance/insights/legacy-javascript)
-   [Modern HTTP](https://developer.chrome.com/docs/performance/insights/modern-http)
-   [Network dependency tree](https://developer.chrome.com/docs/performance/insights/network-dependency-tree)
-   [Optimize DOM size](https://developer.chrome.com/docs/performance/insights/dom-size)
-   [Optimize viewport for mobile](https://developer.chrome.com/docs/performance/insights/viewport)
-   [Render-blocking requests](https://developer.chrome.com/docs/performance/insights/render-blocking)
-   [Third parties](https://developer.chrome.com/docs/performance/insights/third-parties)
-   [Use efficient cache lifetimes](https://developer.chrome.com/docs/performance/insights/cache)

-   On this page
-   [How to pass this insight](https://developer.chrome.com/docs/performance/insights/render-blocking#how_to_pass_this_insight)
-   [Stack-specific guidance](https://developer.chrome.com/docs/performance/insights/render-blocking#stack-specific_guidance)
    -   [AMP](https://developer.chrome.com/docs/performance/insights/render-blocking#amp)
    -   [Drupal](https://developer.chrome.com/docs/performance/insights/render-blocking#drupal)
    -   [Joomla](https://developer.chrome.com/docs/performance/insights/render-blocking#joomla)
    -   [WordPress](https://developer.chrome.com/docs/performance/insights/render-blocking#wordpress)
-   [Additional references](https://developer.chrome.com/docs/performance/insights/render-blocking#additional_references)

-   [Home](https://developer.chrome.com/)
-   [Docs](https://developer.chrome.com/docs)
-   [Performance](https://developer.chrome.com/docs/performance)
-   [Performance insights](https://developer.chrome.com/docs/performance/insights)

# Render-blocking requests

Connor Clark

Published: Oct 8, 2025

Requests are blocking the page's initial render, which may delay LCP. Deferring or inlining can move these network requests out of the critical path.

## How to pass this insight

This insight highlights requests that prevented the first paint of the page. To pass this insight, remove all such render-blocking requests.

Some strategies for reducing the impact of render-blocking requests include:

-   Defer requests that are not needed for first-paint.
-   Inline requests that are critical for first-paint, but small.
-   Reduce the content of CSS or scripts to just what is necessary for the first paint.

**Important:** Inlining CSS is an advanced performance technique that can improve performance, but can also lead to bugs if not implemented properly. **Most sites should be able to achieve all of our recommended performance targets without implementing this technique.**

## Stack-specific guidance

This insight also offers stack-specific guidance for pages using the following technologies:

### AMP

Use tools such as [AMP Optimizer](https://github.com/ampproject/amp-toolbox/tree/master/packages/optimizer) to [server-side render AMP layouts](https://amp.dev/documentation/guides-and-tutorials/optimize-and-measure/server-side-rendering/).

### Drupal

Consider using [a module](https://www.drupal.org/project/critical_css) to inline critical CSS and JavaScript, and use the defer attribute for non-critical CSS or JavaScript.

### Joomla

There are a number of Joomla plugins that can help you [inline critical assets](https://extensions.joomla.org/instant-search/?jed_live%5Bquery%5D=performance) or [defer less important resources](https://extensions.joomla.org/instant-search/?jed_live%5Bquery%5D=performance).

### WordPress

There are a number of WordPress plugins that can help you [inline critical assets](https://wordpress.org/plugins/search/critical+css/) or [defer less important resources](https://wordpress.org/plugins/search/defer+css+javascript/).

## Additional references

-   [Insight source code](https://source.chromium.org/chromium/chromium/src/+/main:third_party/devtools-frontend/src/front_end/models/trace/insights/RenderBlocking.ts)
-   [Understand the critical path - Render-blocking resources](https://web.dev/learn/performance/understanding-the-critical-path#render-blocking_resources)
-   [Coverage: Find unused JavaScript and CSS](https://developer.chrome.com/docs/devtools/coverage)
-   [Remove unused code](https://web.dev/articles/remove-unused-code)
-   [Defer non-critical CSS](https://web.dev/articles/defer-non-critical-css)
-   [Reduce JavaScript payloads with code splitting](https://web.dev/articles/reduce-javascript-payloads-with-code-splitting)
-   [JavaScript Start-up Optimization](https://web.dev/articles/optimizing-content-efficiency-javascript-startup-optimization)

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

Last updated 2025-10-08 UTC.

-   ### Contribute
    
    -   [File a bug](https://issuetracker.google.com/issues/new?component=1400036&template=1897236)
    -   [See open issues](https://issuetracker.google.com/issues?q=status:open%20componentid:1400036&s=created_time:desc)
-   ### Related content
    
    -   [Chromium updates](https://blog.chromium.org/)
    -   [Case studies](https://developer.chrome.com/case-studies)
    -   [Archive](https://developer.chrome.com/deprecated)
    -   [Podcasts & shows](https://web.dev/shows)
-   ### Follow
    
    -   [@ChromiumDev on X](https://twitter.com/ChromiumDev)
    -   [YouTube](https://www.youtube.com/user/ChromeDevelopers)
    -   [Chrome for Developers on LinkedIn](https://www.linkedin.com/showcase/chrome-for-developers)
    -   [RSS](https://developer.chrome.com/static/blog/feed.xml)

-   [Terms](https://policies.google.com/terms)
-   [Privacy](https://policies.google.com/privacy)
-   Manage cookies

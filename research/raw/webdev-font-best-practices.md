# Best practices for fonts  |  Articles  |  web.dev

<https://web.dev/articles/font-best-practices>

[Skip to main content](https://web.dev/articles/font-best-practices#main-content)

web.dev uses cookies to deliver and enhance the quality of its services and to analyze traffic. If you agree, cookies are also used to serve advertising and to personalize the content and advertisements that you see. [Learn more](https://policies.google.com/technologies/cookies?hl=en)

[Resources](https://web.dev/explore/ai) [Discover](https://web.dev/discover) [Baseline](https://web.dev/baseline) [How to use Baseline](https://web.dev/how-to-use-baseline) [Blog](https://web.dev/blog) 

/

-   [Articles](https://web.dev/articles)

[AI and the web](https://web.dev/explore/ai) [Fast load times](https://web.dev/explore/fast) [Learn Core Web Vitals](https://web.dev/explore/learn-core-web-vitals) [Identity](https://web.dev/identity) [Progressive Web Apps](https://web.dev/explore/progressive-web-apps) [Payments](https://web.dev/explore/payments) [Notifications](https://web.dev/explore/notifications) [How to optimize INP](https://web.dev/explore/how-to-optimize-inp) 

-   Overview
    
-   [Web Vitals](https://web.dev/articles/vitals)
-   [The business impact of Core Web Vitals](https://web.dev/case-studies/vitals-business-impact)
-   [Optimizing Core Web Vitals for business decision makers](https://web.dev/articles/optimize-cwv-business)
-   Core Web Vitals Metrics
    
-   [Largest Contentful Paint (LCP)](https://web.dev/articles/lcp)
-   [Cumulative Layout Shift (CLS)](https://web.dev/articles/cls)
-   [Interaction to Next Paint (INP)](https://web.dev/articles/inp)
-   [Defining the Core Web Vitals metrics thresholds](https://web.dev/articles/defining-core-web-vitals-thresholds)
-   Measure Core Web Vitals
    
-   [Getting started with measuring Web Vitals](https://web.dev/articles/vitals-measurement-getting-started)
-   [Core Web Vitals workflows with Google tools](https://web.dev/articles/vitals-tools)
-   [Best practices for measuring Web Vitals in the field](https://web.dev/articles/vitals-field-measurement-best-practices)
-   [Why is CrUX data different from my RUM data?](https://web.dev/articles/crux-and-rum-differences)
-   Debug Core Web Vitals
    
-   [Why lab and field data can be different (and what to do about it)](https://web.dev/articles/lab-and-field-data-differences)
-   [Debug layout shifts](https://web.dev/articles/debug-layout-shifts)
-   [Debug performance in the field](https://web.dev/articles/debug-performance-in-the-field)
-   Improve Core Web Vitals
    
-   [Optimize Largest Contentful Paint](https://web.dev/articles/optimize-lcp)
-   [Optimize Cumulative Layout Shift](https://web.dev/articles/optimize-cls)
-   [Optimize Interaction to Next Paint](https://web.dev/articles/optimize-inp)
-   [The most effective ways to improve Core Web Vitals](https://web.dev/articles/top-cwv)
-   Best Practices
    
-   [Best practices for carousels](https://web.dev/articles/carousel-best-practices)
-   [Best practices for cookie notices](https://web.dev/articles/cookie-notice-best-practices)
-   [Best practices for fonts](https://web.dev/articles/font-best-practices)
-   [Best practices for tags and tag managers](https://web.dev/articles/tag-best-practices)
-   [Best practices for using third-party embeds](https://web.dev/articles/embed-best-practices)
-   [Infinite scroll without layout shifts](https://addyosmani.com/blog/infinite-scroll-without-layout-shifts/)
-   [CSS for Web Vitals](https://web.dev/articles/css-web-vitals)

-   On this page
-   [Font loading](https://web.dev/articles/font-best-practices#font_loading)
    -   [Understand @font-face](https://web.dev/articles/font-best-practices#understand_font-face)
    -   [Inline font declarations](https://web.dev/articles/font-best-practices#inline_font_declarations)
    -   [Preconnect to critical third-party origins](https://web.dev/articles/font-best-practices#preconnect_to_critical_third-party_origins)
    -   [Be cautious when using preload to load fonts](https://web.dev/articles/font-best-practices#be_cautious_when_using_preload_to_load_fonts)
-   [Font delivery](https://web.dev/articles/font-best-practices#font_delivery)
    -   [Use self-hosted fonts](https://web.dev/articles/font-best-practices#use_self-hosted_fonts)
    -   [Use WOFF2](https://web.dev/articles/font-best-practices#use_woff2)
    -   [Subset fonts](https://web.dev/articles/font-best-practices#subset_fonts)
    -   [Use fewer web fonts](https://web.dev/articles/font-best-practices#use_fewer_web_fonts)
-   [Font rendering](https://web.dev/articles/font-best-practices#font_rendering)
    -   [Choose an appropriate font-display strategy](https://web.dev/articles/font-best-practices#choose_an_appropriate_font-display_strategy)
    -   [Reduce the shift between your fallback font and your webfont](https://web.dev/articles/font-best-practices#reduce_the_shift_between_your_fallback_font_and_your_webfont)
-   [Conclusion](https://web.dev/articles/font-best-practices#conclusion)

-   [Home](https://web.dev/)
-   [Articles](https://web.dev/articles)
-   [Resources](https://web.dev/explore/ai)
-   [Learn Core Web Vitals](https://web.dev/explore/learn-core-web-vitals)

# Best practices for fonts

Optimize web fonts for Core Web Vitals.

Katie Hempenius

Barry Pollard

This document discusses performance best practices for fonts. There are a variety of ways in which web fonts impact performance:

-   **Delayed text rendering:** If a web font has not loaded, browsers typically delay text rendering. In many situations, this delays [First Contentful Paint (FCP)](https://web.dev/articles/fcp). In some situations, this delays [Largest Contentful Paint (LCP)](https://web.dev/articles/lcp).
-   **Layout shifts:** The practice of font swapping has the potential to [cause layout shifts](https://web.dev/articles/debug-layout-shifts#identifying_the_cause_of_a_layout_shift) and impact [Cumulative Layout Shift (CLS)](https://web.dev/articles/cls). These layout shifts occur when a web font and its fallback font take up different amounts of space on the page.

This document has three sections: **font loading**, **font delivery**, and **font rendering**. Each section explains how that particular aspect of the font lifecycle works and provides corresponding best practices.

## Font loading

Fonts are important resources. Without them, the user may be unable to view page content. Thus, best practices for font loading generally focus on making sure that fonts get loaded as early as possible. Particular care should be given to fonts loaded from third-party sites as downloading these font files requires separate connection setups.

If you're unsure if your page's fonts are being requested in time, check the **Timing** tab within the **Network** panel in Chrome DevTools for more information.

### Understand `@font-face`

Before diving into best practices for font loading it's important to understand how [`@font-face`](https://developer.mozilla.org/docs/Web/CSS/@font-face) works and how this impacts font loading.

The [`@font-face`](https://developer.mozilla.org/docs/Web/CSS/@font-face) declaration is an essential part of working with any web font. At a minimum, it declares the name that's used to refer to the font and indicates the location of the corresponding font file.

```
@font-face {
  font-family: "Open Sans";
  src: url("/fonts/OpenSans-Regular-webfont.woff2") format("woff2");
}
```

A common misconception is that a font is requested when a `@font-face` declaration is encountered. This is false. By itself, `@font-face` declaration doesn't trigger font download. Rather, a font is downloaded only if it's referenced by styling that is used on the page. For example:

```
@font-face {
  font-family: "Open Sans";
  src: url("/fonts/OpenSans-Regular-webfont.woff2") format("woff2");
}

h1 {
  font-family: "Open Sans"
}
```

In this example, `Open Sans` would only be downloaded if the page contained a `<h1>` element.

**Tip:** You can also load font with the [`preload`](https://developer.mozilla.org/docs/Web/HTML/Preloading_content) resource hint and the [Font Loading API](https://web.dev/articles/optimize-webfont-loading#the_font_loading_api).

Thus, when thinking about font optimization, it's important to give stylesheets just as much consideration as the font files themselves. Changing the contents or delivery of stylesheets can have a significant impact on when fonts arrive. Similarly, removing unused CSS and splitting stylesheets can reduce the number of fonts loaded by a page.

### Inline font declarations

Most sites would strongly benefit from inlining font declarations and other critical styling in the `<head>` of the main document rather than including them in an external stylesheet. This allows the browser to discover the font declarations sooner as the browser doesn't need to wait for the external stylesheet to download.

```
<head>
  <style>
    @font-face {
        font-family: "Open Sans";
        src: url("/fonts/OpenSans-Regular-webfont.woff2") format("woff2");
    }

    body {
        font-family: "Open Sans";
    }

    ...etc.

  </style>
</head>
```

**Note:** Even if only some of the CSS is inlined, the browser still must wait for all the CSS to be loaded, before it can discover if fonts are needed. Inlining the font files themselves is not recommended. Inlining large resources, such as fonts, is likely to delay the delivery of the main document, and with it, the discovery of other resources.

Inlining critical CSS can be a more advanced technique that not all sites can achieve. The performance benefits are clear, but it requires additional processes and build tools to ensure the necessarily CSS, and ideally only the critical CSS, is inlined correctly and that any additional CSS is delivered in a non-render blocking fashion.

### Preconnect to critical third-party origins

If your site loads fonts from a third-party site, it's highly recommended that you use the [`preconnect`](https://developer.mozilla.org/docs/Web/HTML/Link_types/preconnect) resource hint to establish early connection(s) with the third-party origin. Resource hints should be placed in the `<head>` of the document. The following resource hint sets up a connection for loading the font stylesheet.

```
<head>
  <link rel="preconnect" href="https://fonts.com">
</head>
```

To preconnect the connection that is used to download the font file, add a separate `preconnect` resource hint that uses the `crossorigin` attribute. Unlike stylesheets, font files must be sent over a [CORS connection](https://developer.mozilla.org/docs/Web/HTTP/CORS#what_requests_use_cors).

```
<head>
  <link rel="preconnect" href="https://fonts.com">
  <link rel="preconnect" href="https://fonts.com" crossorigin>
</head>
```

When using the `preconnect` resource hint, keep in mind that a font provider may serve stylesheets and fonts from separate origins. For example, this is how the `preconnect` resource hint would be used for Google Fonts.

```
<head>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
</head>
```

**Note:** [Google Fonts](https://fonts.google.com/) provides the option to load fonts with `<link>` tags or an `@import` statement. The `<link>` element includes a `preconnect` resource hint, thus likely results in faster stylesheet delivery than `@import`. `<link>` tags should be placed as early as possible in the document.

### Be cautious when using `preload` to load fonts

Although `preload` is highly effective at making fonts discoverable early in the page load process, this comes at the cost of taking away browser resources from the loading of other resources.

Inlining font declarations and adjusting stylesheets may be a more effective approach. These adjustments come closer to addressing the root cause of late-discovered fonts, rather than just providing a workaround.

In addition, using `preload` as a font-loading strategy should also be used carefully as it bypasses some of the browser's built-in content negotiation strategies. For example, `preload` ignores `unicode-range` declarations, and if used prudently, should only be used to load a single font format.

However, when using external stylesheets, preloading the most important fonts can be very effective since the browser won't otherwise discover whether the font is needed until much later.

## Font delivery

Faster font delivery yields faster text rendering. In addition, if a font is delivered early enough, this can help eliminate layout shifts resulting from font swapping.

### Use self-hosted fonts

On paper, using a self-hosted font should deliver better performance as it eliminates a third-party connection setup. In practice, the performance differences between these two options is less clear cut. For example, the [Web Almanac](https://almanac.httparchive.org/en/2020/fonts#fig-7) found that sites using third-party fonts had a faster render than fonts that used first-party fonts.

If you are considering using self-hosted fonts, confirm that your site uses a [Content Delivery Network (CDN)](https://web.dev/articles/content-delivery-networks) and [HTTP/2](https://web.dev/articles/content-delivery-networks#http2_and_http3). Without use of these technologies, it's much less likely that self-hosted fonts deliver better performance.

**Note:** If you're unsure if using self-hosted fonts delivers better performance, try serving a font file from your own servers and compare the transfer time (including connection setup) with that of a third-party font. If you have slow servers, don't use a CDN or HTTP/2, as it becomes less likely that the self-hosted font is more performant.

If you use a self-hosted font, it's recommended that you also apply some of the font file optimizations that third-party font providers typically provide automatically. For example, font subsetting and WOFF2 compression. The amount of effort required to apply these optimizations depends somewhat on the languages that your site supports. In particular, be aware that optimizing fonts for [CJK languages](https://en.wikipedia.org/wiki/CJK_characters) can be particularly challenging.

### Use WOFF2

Of the modern font fonts, [WOFF2](https://www.w3.org/TR/WOFF2/) is the newest, has the widest browser support, and offers the best compression. Because it uses Brotli, WOFF2 compresses 30% better than WOFF, leading to less data to download and therefore faster performance.

Given the browser support, experts now recommend only using WOFF2:

> In fact, we think it is also time to proclaim: Use only WOFF2 and forget about everything else.  
>   
> This will simplify your CSS and workflow massively and also prevents any accidental double or incorrect font downloads. WOFF2 is now supported everywhere. So, unless you need to support really ancient browsers, just use WOFF2. If you can't, consider not serving any web fonts to those older browsers at all. This won't be a problem if you have a robust fallback strategy in place. Visitors on older browsers will see your fallback fonts.
> 
> [Bram Stein, from the 2022 Web Almanac](https://almanac.httparchive.org/en/2022/fonts#performance)

### Subset fonts

Font files typically include a large number of [glyphs](https://en.wikipedia.org/wiki/Glyph) for all the various characters they support. But you may not need all the characters on your page and can reduce the size of font files by subsetting fonts.

The [`unicode-range`](https://developer.mozilla.org/docs/Web/CSS/@font-face/unicode-range) descriptor in the `@font-face` declaration informs the browser which characters a font can be used for.

```
@font-face {
    font-family: "Open Sans";
    src: url("/fonts/OpenSans-Regular-webfont.woff2") format("woff2");
    unicode-range: U+0025-00FF;
}
```

A font file is downloaded if the page contains one or more characters matching the unicode range. `unicode-range` is commonly used to serve different font files depending on the language used by page content.

`unicode-range` is often used in conjunction with the technique of subsetting. A subset font includes a smaller portion of the glyphs that were contained in the original font file. For example, rather than serve all characters to all users, a site might generate separate subset fonts for Latin and Cyrillic characters.

The number of glyphs per font varies wildly:

-   Latin fonts are usually on the magnitude of 100 to 1000 glyphs per font.
-   [CJK](https://en.wikipedia.org/wiki/CJK_characters) fonts may have over 10,000 characters.

Removing unused glyphs can significantly reduce the filesize of a font.

Some font providers may provide different versions of fonts files with different subsets automatically. For example, [Google Fonts](https://fonts.google.com/) does this by default:

```
/* devanagari */
@font-face {
  font-family: 'Poppins';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/poppins/v20/pxiEyp8kv8JHgFVrJJbecnFHGPezSQ.woff2) format('woff2');
  unicode-range: U+0900-097F, U+1CD0-1CF6, U+1CF8-1CF9, U+200C-200D, U+20A8, U+20B9, U+25CC, U+A830-A839, U+A8E0-A8FB;
}
/* latin-ext */
@font-face {
  font-family: 'Poppins';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/poppins/v20/pxiEyp8kv8JHgFVrJJnecnFHGPezSQ.woff2) format('woff2');
  unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
}
/* latin */
@font-face {
  font-family: 'Poppins';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/poppins/v20/pxiEyp8kv8JHgFVrJJfecnFHGPc.woff2) format('woff2');
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}
```

When moving to self-hosting, this is an optimization that can be missed and lead to larger font files locally.

You can manually subset fonts if your font provider allows this, either with an API ([Google Fonts supports this by providing a `text` parameter](https://developers.google.com/fonts/docs/getting_started#specifying_script_subsets)), or by manually editing the font files and then self-hosting. Tools for generating font subsets include [subfont](https://github.com/Munter/subfont) and [glyphanger](https://github.com/zachleat/glyphhanger).

Always check the [font licenses to confirm they allow subsetting](https://subsetting.xyz/) and self-hosting.

### Use fewer web fonts

The fastest font to deliver is a font that isn't requested in the first place. System fonts and variable fonts are two ways to potentially reduce the number of web fonts used on your site.

A _system font_ is the default font used by the user interface of a user's device. System fonts typically vary by operating system and version. Because the font is already installed, the font does not need to be downloaded. System fonts can work particularly well for body text.

To use the system font in your CSS, list `system-ui` as the font-family:

```
font-family: system-ui
```

The idea behind [_variable fonts_](https://web.dev/articles/variable-fonts) is that a single variable font can be used as a replacement for multiple font files. Variable fonts work by defining a "default" font style and providing ["axes"](https://web.dev/articles/variable-fonts#axes_definitions) for manipulating the font. For example, a variable font with a `Weight` axis could be used to implement lettering that would previously require separate fonts for light, regular, bold, and extra bold.

**Key Term:** We often refer to "Times New Roman" and "Helvetica" as fonts. Technically speaking, these are _font families_. A font family is composed of styles, which are particular variations of the typeface (for example, light, medium, or bold italic). A font file contains a single style, unless it's a variable font. A typeface is the underlying design, which can be expressed as digital fonts—and in physical type, like carved woodblocks or metal.

Not everyone benefits from switching to variable fonts. [Variable fonts](https://web.dev/articles/variable-fonts) contain many styles, so typically have larger file sizes than individual non-variable fonts that only contain one style. Sites that will see the largest improvement from using variable fonts are those that use (and need to use) a variety of font styles and weights.

## Font rendering

When faced with a web font that has not yet loaded, the browser is faced with a dilemma: should it hold off on rendering text until the web font has arrived? Or should it render the text in a fallback font until the web font arrives?

Different browsers handle this scenario differently. By default, Chromium-based and Firefox browsers block text rendering for up to 3 seconds if the associated web font has not loaded. Safari blocks text rendering indefinitely.

This behavior can be configured by using the `font-display` attribute. This choice can have significant implications: `font-display` has the potential to impact LCP, FCP, and layout stability.

### Choose an appropriate `font-display` strategy

[`font-display`](https://developer.mozilla.org/docs/Web/CSS/@font-face/font-display) informs the browser how it should proceed with text rendering when the associated web font has not loaded. It's defined per font-face.

```
@font-face {
  font-family: Roboto, Sans-Serif
  src: url(/fonts/roboto.woff) format('woff'),
  font-display: swap;
}
```

There are five possible values for `font-display`:

| **Value** | **Block period** | **Swap period** |
| --- | --- | --- |
| Auto | Varies by browser | Varies by browser |
| Block | 2-3 seconds | Infinite |
| Swap | 0ms | Infinite |
| Fallback | 100ms | 3 seconds |
| Optional | 100ms | None |

-   **Block period**: The block period begins when the browser requests a web font. During the block period, if the web font isn't available, the font is rendered in an _invisible_ fallback font and thus the text is invisible to the user. If the font isn't available at the end of the block period, it's rendered in the fallback font.
-   **Swap period**: The swap period comes after the block period. If the web font becomes available during the swap period, it's "swapped" in.

`font-display` strategies reflect different viewpoints about the tradeoff between performance and aesthetics. As such, it's difficult to recommend an approach as it depends on individual preferences, how important the web font is to the page and brand, and how jarring a late-arriving font can be when swapped in.

For most sites, these are the three most applicable strategies, based on your top priority:

-   **Performance**: Use `font-display: optional`. This is the most "performant" approach: text render is delayed for no longer than 100ms and there's assurance that there isn't font-swap related layout shifts. The downside is that the web font won't be used if it arrives late.
    
-   **Quickly display text and still use a web-font**: Use `font-display: swap` but make sure to deliver the font early enough that it does not cause a layout shift. The downside of this option is the jarring shift when the font arrives late.
    
-   **Text is displayed in a web font**: Use `font-display: block` but make sure to deliver the font early enough that it minimizes the delay of the text. The initial text display is delayed. Despite this delay, it can still cause a layout shift as the text is actually drawn invisible, and the fallback font space is therefore used to reserve the space. Once the web font loads, this may require difference space, hence a shift. This may be a less jarring shift than `font-display: swap`, as the text itself won't be seen to shift.
    

**Note:** `font-display: auto`, `font-display: block`, `font-display: swap`, and `font-display: fallback` all have the potential to cause layout shifts when the font is swapped. However, of these approaches, `font-display: swap` delays text render the least. Thus, it can be the preferred approach for situations where it's important that text is displayed as quickly as possible, but ultimately gets rendered as a web font.

Also keep in mind that these two approaches can be combined: for example, use `font-display: swap` for branding and other visually distinctive page elements. Use `font-display: optional` for fonts used in body text.

#### Icon fonts

The `font-display` strategies that work well for conventional web fonts don't work as well for icon fonts. The fallback font for an icon font typically looks significantly different than the icon font, and its characters may convey a completely different meaning. As a result, icon fonts are more likely to cause significant layout shifts.

In addition, using a fallback font may not be practical. When possible, replace icon fonts with SVGs, which is also better for accessibility. Newer versions of popular icon fonts typically support SVG. For more information on switching to SVGs, see [Font Awesome's page on SVG Sprites](https://fontawesome.com/v5.15/how-to-use/on-the-web/advanced/svg-sprites) and our [Material Icons Guide](https://google.github.io/material-design-icons/#svg).

### Reduce the shift between your fallback font and your webfont

To reduce the CLS impact, you can use the [`size-adjust` attributes](https://web.dev/articles/css-size-adjust).

## Conclusion

Web fonts are still a performance bottleneck, but we have an ever-growing range of options to allow us to optimize them to reduce this bottleneck as much as possible.

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

Last updated 2022-10-04 UTC.

-   -   We want to help you build beautiful, accessible, fast, and secure websites that work cross-browser, and for all of your users. This site is our home for content to help you on that journey, written by members of the Chrome team, and external experts.
        
-   ### Contribute
    
    -   [File a bug](https://issuetracker.google.com/issues/new?component=1400680&template=1857359)
    -   [See open issues](https://issuetracker.google.com/issues?q=status:open%20componentid:1400680&s=created_time:desc)
-   ### Related Content
    
    -   [Chrome for Developers](https://developer.chrome.com/)
    -   [Chromium updates](https://blog.chromium.org/)
    -   [Case studies](https://web.dev/case-studies)
    -   [Podcasts & shows](https://web.dev/shows)
-   ### Follow
    
    -   [@ChromiumDev on X](https://twitter.com/ChromiumDev)
    -   [YouTube](https://www.youtube.com/user/ChromeDevelopers)
    -   [Chrome for Developers on LinkedIn](https://www.linkedin.com/showcase/chrome-for-developers)
    -   [RSS](https://web.dev/static/blog/feed.xml)

-   [Terms](https://policies.google.com/terms)
-   [Privacy](https://policies.google.com/privacy)
-   Manage cookies

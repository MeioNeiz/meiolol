# Managing crawling of faceted navigation URLs | Google Crawling Infrastructure  |  Crawling infrastructure  |  Google for Developers

<https://developers.google.com/crawling/docs/faceted-navigation>

[Skip to main content](https://developers.google.com/crawling/docs/faceted-navigation#main-content)

developers.google.com uses cookies to deliver and enhance the quality of its services and to analyze traffic. If you agree, cookies are also used to serve advertising and to personalize the content and advertisements that you see. [Learn more](https://policies.google.com/technologies/cookies?hl=en)

-   [Crawling infrastructure](https://developers.google.com/crawling)

/

[Home](https://developers.google.com/crawling) [Docs](https://developers.google.com/crawling/docs/crawlers-fetchers/overview-google-crawlers)

-   [Intro](https://developers.google.com/crawling/docs/crawlers-fetchers/overview-google-crawlers)
-   [About Google's web crawling](https://developers.google.com/crawling/docs/about-crawling)
-   How to...
    
-   [Verify requests from Google](https://developers.google.com/crawling/docs/crawlers-fetchers/verify-google-requests)
-   [Authenticate requests with Web Bot Auth (experimental)](https://developers.google.com/crawling/docs/crawlers-fetchers/web-bot-auth)
-   [Reduce Google's crawl rate](https://developers.google.com/crawling/docs/crawlers-fetchers/reduce-crawl-rate)
-   Use robots.txt to manage crawling
    
-   Optimize crawling performance
    
    -   [Optimize your crawl budget](https://developers.google.com/crawling/docs/crawl-budget)
    -   [Myths about crawling](https://developers.google.com/crawling/docs/myths-about-crawling)
    -   [Improve crawling of faceted navigation URLs](https://developers.google.com/crawling/docs/faceted-navigation)
    
-   Reference
    
-   [Common crawlers](https://developers.google.com/crawling/docs/crawlers-fetchers/google-common-crawlers)
-   [Special case crawlers](https://developers.google.com/crawling/docs/crawlers-fetchers/google-special-case-crawlers)
-   [User-triggered fetchers](https://developers.google.com/crawling/docs/crawlers-fetchers/google-user-triggered-fetchers)
-   Specific crawlers and user-triggered fetchers
    
-   Troubleshooting
    
-   [HTTP status codes](https://developers.google.com/crawling/docs/troubleshooting/http-status-codes)
-   [Network and DNS errors](https://developers.google.com/crawling/docs/troubleshooting/dns-network-errors)
-   What's new
    
-   [Changelog](https://developers.google.com/crawling/docs/changelog)

-   [Home](https://developers.google.com/)
-   [Crawling infrastructure](https://developers.google.com/crawling)
-   [Docs](https://developers.google.com/crawling/docs/crawlers-fetchers/overview-google-crawlers)

-   On this page
-   [Prevent crawling of faceted navigation URLs](https://developers.google.com/crawling/docs/faceted-navigation#prevent-crawling-of-faceted-navigation-urls)
-   [Ensure the faceted navigation URLs are optimal for the web](https://developers.google.com/crawling/docs/faceted-navigation#ensure-the-faceted-navigation-urls-are-optimal-for-the-web)

# Managing crawling of faceted navigation URLs

Faceted navigation is a common feature of websites that allows its visitors to change how items (for example, products, articles, or events) are displayed on a page. It's a popular and useful feature, however its most common implementation, which is based on URL parameters, can generate infinite URL spaces which harms the website in a couple ways:

-   **Overcrawling**: Because the URLs created for the faceted navigation seem to be novel and crawlers can't determine whether the URLs are going to be useful without crawling first, the crawlers will typically access a very large number of faceted navigation URLs before the crawlers' processes determine the URLs are in fact useless.
-   **Slower discovery crawls**: Stemming from the previous point, if crawling is spent on useless URLs, the crawlers have less time to spend on new, useful URLs.

A typical faceted navigation URL may contain various parameters in the query string related to the properties of items they filter for. For example:

https://example.com/items.shtm?**products=fish&color=radioactive\_green&size=tiny**

Changing any of the URL parameters `products`, `color`, and `size` would show a different set of items on the underlying page. This often means a very large number of possible combinations of filters, which translates to a very large number of possible URLs. To save your resources, we recommend dealing with these URLs one of the following ways:

-   If you don't need the faceted navigation URLs potentially indexed, prevent crawling of these URLs.
-   If you need the faceted navigation URLs potentially indexed, ensure that the URLs follow our best practices outlined in the following section. Keep in mind that crawling faceted URLs tends to cost sites large amounts of computing resources due to the sheer amount of URLs and operations needed to render those pages.

## Prevent crawling of faceted navigation URLs

If you want to save server resources and you don't need your faceted navigation URLs to show up in Google Search or other Google products, you can prevent crawling of these URLs with one of the following ways.

-   **Use [robots.txt](https://developers.google.com/crawling/docs/robots-txt/create-robots-txt) to disallow crawling of faceted navigation URLs.** Oftentimes there's no good reason to allow crawling of filtered items, as it consumes server resources for no or negligible benefit; instead, allow crawling of just the individual items' pages along with a dedicated listing page that shows all products without filters applied.
    
    user-agent: Googlebot
    disallow: /\*?\*products=
    disallow: /\*?\*color=
    disallow: /\*?\*size=
    allow: /\*?products=all$
    
-   **Use URL fragments to specify filters.**
    
    [Google Search generally doesn't support URL fragments in crawling and indexing](https://developers.google.com/search/docs/crawling-indexing/url-structure#fragments).
    
    If your filtering mechanism is based on URL fragments, it will have no impact on crawling (positive or negative). For example, instead of URL parameters, use URL fragments:
    
    https://example.com/items.shtm**#**products=fish&color=radioactive\_green&size=tiny
    

Other ways to signal a preference of which faceted navigation URLs (not) to crawl is using `rel="canonical"` `link` element and the `rel="nofollow"` anchor attribute. However, these methods are generally less effective in the long term than the previously mentioned methods.

-   **Using [`rel="canonical"`](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#rel-canonical-link-method) to specify which URL is the canonical version of a faceted navigation URL** may, over time, decrease the crawl volume of non-canonical versions of those URLs. For example, if you have 3 filtered page types, consider pointing the `rel="canonical"` to the unfiltered version: `https://example.com/items.shtm?products=fish&color=radioactive_green&size=tiny` specifies `<link rel="canonical" href="https://example.com/items.shtm?products=fish" >`.
-   **Using [`rel="nofollow"`](https://developers.google.com/search/docs/crawling-indexing/qualify-outbound-links#nofollow) attributes on anchors pointing to filtered results pages** may be beneficial, however keep in mind that every anchor pointing to a specific URL must have the `rel="nofollow"` attribute in order for it to be effective.

## Ensure the faceted navigation URLs are optimal for the web

If you need your faceted navigation URLs to be potentially crawled and indexed, ensure you're following these best practices to minimize the negative effects of crawling the large number of potential URLs on your site:

Keep in mind that having these URLs crawled means an increased resource usage on your server and, potentially, slower discovery of new URLs on your site.

1.  **Use the industry standard URL parameter separator '`&`'.** Characters like comma (`,`), semicolon (`;`), and brackets (`[` and `]`) are hard for crawlers to detect as parameter separators (because most often they're not separators).
2.  If you're encoding filters in the URL path, such as `/products/**fish**/**green**/**tiny**`, ensure that the logical order of the filters always stays the same and that no duplicate filters can exist.
3.  **Return an HTTP `404` status code when a filter combination doesn't return results.** If there are no green fish in the site's inventory, users as well as crawlers should receive a "not found" error with the proper HTTP status code (`404`). This should also be the case if the URL contains duplicate filters or otherwise nonsensical filter combinations, and nonexistent pagination URLs. Similarly, if a filter combination has no results, don't redirect to a common "not found" error page. Instead, serve a "not found" error with the `404` HTTP status code under the URL where it was encountered.
    
    If [you have a single-page app](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics#avoid-soft-404s) this might not be possible. Follow the best practices for single page apps.
    

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

Last updated 2025-12-18 UTC.

-   ### Engage
    
    -   [Google Developer Program](https://developers.google.com/program)
    -   [Google Developer Groups](https://developers.google.com/community)
    -   [Google Developer Experts](https://developers.google.com/community/experts)
    -   [Accelerators](https://developers.google.com/community/accelerators)
    -   [Google Cloud & NVIDIA](https://developers.google.com/community/nvidia)
-   ### Connect
    
    -   [Blog](https://googledevelopers.blogspot.com/)
    -   [Bluesky](https://bsky.app/profile/developers.google.com)
    -   [Instagram](https://www.instagram.com/googlefordevs/)
    -   [LinkedIn](https://www.linkedin.com/showcase/googledevelopers/)
    -   [X (Twitter)](https://twitter.com/googledevs)
    -   [YouTube](https://www.youtube.com/user/GoogleDevelopers)
-   ### Build
    
    -   [Android](https://developer.android.com/)
    -   [Chrome](https://developer.chrome.com/)
    -   [Firebase](https://firebase.google.com/)
    -   [Google AI Studio](https://aistudio.google.com/)
    -   [Google Antigravity](https://antigravity.google/)
    -   [Google Cloud](https://cloud.google.com/)
    -   [Google Play](https://play.google.com/console/about/)
    -   [View all](https://developers.google.com/products)

-   [Android](https://developer.android.com/)
-   [Chrome](https://developer.chrome.com/home)
-   [Firebase](https://firebase.google.com/)
-   [Google Cloud Platform](https://cloud.google.com/)
-   [Google AI](https://ai.google.dev/)
-   [All products](https://developers.google.com/products)

-   [Terms](https://developers.google.com/terms/site-terms)
-   [Privacy](https://policies.google.com/privacy)
-   Manage cookies

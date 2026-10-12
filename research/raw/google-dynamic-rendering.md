# Dynamic Rendering as a workaround | Google Search Central  |  Documentation  |  Google for Developers

<https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering>

[Skip to main content](https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering#main-content)

developers.google.com uses cookies to deliver and enhance the quality of its services and to analyze traffic. If you agree, cookies are also used to serve advertising and to personalize the content and advertisements that you see. [Learn more](https://policies.google.com/technologies/cookies?hl=en)

-   [Search Central](https://developers.google.com/search)

[Documentation](https://developers.google.com/search/docs) [Support](https://developers.google.com/search/help) [Blog](https://developers.google.com/search/blog) [What's new](https://developers.google.com/search/news) [Events](https://developers.google.com/search/events) [Case studies](https://developers.google.com/search/case-studies)

/

-   [Documentation](https://developers.google.com/search/docs)

[Search Console](https://goo.gle/searchconsole)

-   [Introduction](https://developers.google.com/search/docs)
-   Search Essentials
    
-   SEO fundamentals
    
-   Crawling and indexing
    
    -   [Overview](https://developers.google.com/search/docs/crawling-indexing)
    -   [File types Google can index](https://developers.google.com/search/docs/crawling-indexing/indexable-file-types)
    -   [URL structure](https://developers.google.com/search/docs/crawling-indexing/url-structure)
    -   [Links](https://developers.google.com/search/docs/crawling-indexing/links-crawlable)
    -   Sitemaps
        
    -   Crawler management
        
    -   robots.txt
        
    -   Canonicalization
        
    -   [Mobile site and mobile-first indexing](https://developers.google.com/search/docs/crawling-indexing/mobile/mobile-sites-mobile-first-indexing)
    -   AMP
        
    -   JavaScript
        
        -   [Understand the JavaScript SEO basics](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics)
        -   [Fix search-related JavaScript problems](https://developers.google.com/search/docs/crawling-indexing/javascript/fix-search-javascript)
        -   [Fix lazy-loaded content](https://developers.google.com/search/docs/crawling-indexing/javascript/lazy-loading)
        -   [Dynamic rendering as a workaround](https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering)
        
    -   Page and content metadata
        
    -   Removals
        
    -   Site moves and changes
        
    
-   Ranking and search appearance
    
-   Monitoring and debugging
    
-   Site-specific guides
    

-   [Home](https://developers.google.com/)
-   [Search Central](https://developers.google.com/search)
-   [Documentation](https://developers.google.com/search/docs)

-   On this page
-   [Sites that might use dynamic rendering](https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering#which-sites)
-   [Understand how dynamic rendering works](https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering#understand)
-   [Dynamic rendering is not cloaking](https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering#cloaking)

# Dynamic rendering as a workaround

Dynamic rendering was a workaround and not a long-term solution for problems with JavaScript-generated content in search engines. Instead, we recommend that you use [server-side rendering](https://web.dev/articles/rendering-on-the-web#server-side), [static rendering](https://web.dev/articles/rendering-on-the-web#static), or [hydration](https://web.dev/articles/rendering-on-the-web#rehydration) as a solution.

On some websites, JavaScript loads additional content when the page is open in a browser. This is called [client-side rendering](https://web.dev/articles/rendering-on-the-web#client-side). Google Search sees this content along with the content in the HTML of a website. Keep in mind that there are some [limitations for JavaScript in Google Search](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics#write-compatible-code) and some pages may encounter problems with content not showing up in the rendered HTML. Other search engines may choose to ignore JavaScript and won't see JavaScript-generated content.

Dynamic rendering is a workaround for websites where JavaScript-generated content is not available to search engines. A dynamic rendering server detects bots that may have problems with JavaScript-generated content and serves a server-rendered version without JavaScript to these bots while showing the client-side rendered version of the content to users.

Dynamic rendering is a workaround and not a recommended solution, because it creates additional complexities and resource requirements.

## Sites that might use dynamic rendering

Dynamic rendering was a workaround for indexable, public JavaScript-generated content that changes rapidly, or content that uses [JavaScript features that aren't supported by the crawlers](https://developers.google.com/search/docs/guides/rendering) you care about. Not all sites need to use dynamic rendering, and there are better solutions than dynamic rendering as explained in [an overview of rendering on the web](https://web.dev/articles/rendering-on-the-web).

## Understand how dynamic rendering works

Dynamic rendering requires your web server to detect crawlers (for example, by checking the user agent). When your web server identifies a request from a crawler that does not support JavaScript or the JavaScript features required to render your content, this request is routed to a rendering server. Requests from users and crawlers without JavaScript issues are served normally. The rendering server responds to requests with a version of the content that's suitable to the crawler, for example, it may serve a static HTML version. You can choose to enable the dynamic renderer for all pages or on a per-page basis.

## Dynamic rendering is not cloaking

Googlebot generally doesn't consider dynamic rendering as [cloaking](https://developers.google.com/search/docs/essentials/spam-policies#cloaking). As long as your dynamic rendering produces similar content, Googlebot won't view dynamic rendering as cloaking.

When you're setting up dynamic rendering, your site may produce error pages. Googlebot doesn't consider these error pages as cloaking and [treats the error as any other error page](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics#use-meaningful-http-status-codes).

Using dynamic rendering to serve completely different content to users and crawlers can be considered cloaking. For example, a website that serves a page about cats to users and a page about dogs to crawlers is cloaking.

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

Last updated 2025-12-10 UTC.

 -    [LinkedIn](https://www.linkedin.com/showcase/googlesearchcentral/)
    
    Join us on LinkedIn
    
-    [YouTube](https://www.youtube.com/channel/UCWf2ZlNsCGDS89VBF_awNvA)
    
    Watch our videos
    
-    [Blog](https://feeds.feedburner.com/blogspot/amDG)
    
    Subscribe to our RSS feed
    
-    [Podcast](https://pod.link/1512522198)
    
    Listen to Search Off the Record
    
-    [X (Twitter)](https://twitter.com/googlesearchc)
    
    Join us on X (Twitter)

-   ### Get support
    
    -   [Go to the help forum](https://support.google.com/webmasters/community)
    -   [Submit a question for office hours](https://developers.google.com/search/help/office-hours)
    -   [Report spam, phishing, or malware](https://developers.google.com/search/help/report-quality-issues)
    -   [More support resources](https://developers.google.com/search/help)
-   ### Resources
    
    -   [Do you need an SEO?](https://developers.google.com/search/docs/fundamentals/get-on-google)
    -   [SEO Starter Guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide)
    -   [Status of Search systems](https://status.search.google.com/)
    -   [Search Console documentation](https://support.google.com/webmasters)
    -   [Case Studies](https://developers.google.com/search/case-studies)
-   ### Tools
    
    -   [Search Console](https://search.google.com/search-console)
    -   [Rich Results Test](https://search.google.com/test/rich-results)
    -   [PageSpeed Insights](https://pagespeed.web.dev/)
    -   [AMP Test](https://search.google.com/test/amp)

-   [Android](https://developer.android.com/)
-   [Chrome](https://developer.chrome.com/home)
-   [Firebase](https://firebase.google.com/)
-   [Google Cloud Platform](https://cloud.google.com/)
-   [Google AI](https://ai.google.dev/)
-   [All products](https://developers.google.com/products)

-   [Terms](https://developers.google.com/terms/site-terms)
-   [Privacy](https://policies.google.com/privacy)
-   Manage cookies

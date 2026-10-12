# Crawl Budget Management | Google Crawling Infrastructure  |  Crawling infrastructure  |  Google for Developers

<https://developers.google.com/crawling/docs/crawl-budget>

[Skip to main content](https://developers.google.com/crawling/docs/crawl-budget#main-content)

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
-   [Who this guide is for](https://developers.google.com/crawling/docs/crawl-budget#who-this-guide)
-   [General theory of crawling](https://developers.google.com/crawling/docs/crawl-budget#general_theory)
    -   [Crawl capacity limit](https://developers.google.com/crawling/docs/crawl-budget#crawl-capacity-limit)
    -   [Crawl demand](https://developers.google.com/crawling/docs/crawl-budget#crawl-demand)
    -   [Summary](https://developers.google.com/crawling/docs/crawl-budget#summary)
-   [Best practices](https://developers.google.com/crawling/docs/crawl-budget#best_practices)
-   [How do I get more crawl budget?](https://developers.google.com/crawling/docs/crawl-budget#more-crawl-budget)

# Optimize your crawl budget

This guide describes how to optimize Google's crawling of very large and frequently updated sites.

If your site doesn't have a large number of pages that change rapidly, or if your pages seem to be crawled the same day that they are published, you don't need to read this guide. For Google Search specifically, [keeping your sitemap up to date](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap) and [checking the Page Indexing report](https://support.google.com/webmasters/answer/7440203) regularly is adequate.

## Who this guide is for

While the recommendations in this guide are generally good practices, this is an advanced guide intended primarily for the following types of sites:

-   Large sites (1 million+ unique pages) with content that changes moderately often (once a week)
-   Medium or larger sites (10,000+ unique pages) with very rapidly changing content (daily)
-   Sites with a large portion of their total URLs classified by Search Console as [Discovered - currently not indexed](https://support.google.com/webmasters/answer/7440203#information-status)

The numbers given here are a **rough estimate** to help you classify your site. These are not exact thresholds.

## General theory of crawling

The web is a nearly infinite space, exceeding Google's ability to explore every publicly accessible URL. As a result, there are limits to how much time and resources Google can devote to crawling any single site. The allocation of these resources is commonly called a site's _crawl budget_. In this context, Google's crawling infrastructure defines a _site_ as a unique hostname. For example, `https://www.example.com/` and `https://code.example.com/` are treated as separate sites and have separate crawl budgets. A site's crawl budget is determined by two main elements: _crawl capacity limit_ and _crawl demand_.

For Google Search, not every page that is crawled will necessarily be indexed. After crawling, each page must be evaluated, [consolidated](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls), and assessed to determine its suitability for the index.

### Crawl capacity limit

Google wants to crawl your site without overwhelming your servers. To prevent this, Google's crawlers calculate a _crawl capacity limit_ (also known as [_hostload_](https://support.google.com/webmasters/answer/9012289#site-wide-error-inspection&zippy=%2Csite-wide-availability-issues)). This limits the total amount of time your server spends holding connections open for Google, factoring in both the number of parallel connections and their duration. This ensures Google can cover all your important content without overloading your servers.

Every site starts with the same default, conservative crawl capacity limit. If there is demand to crawl more and the site remains healthy, Google's systems will automatically adjust this limit over time.

The crawl capacity limit can go up and down based on a few factors:

-   **Crawl health:** If the site responds consistently and its response times (including latency and Time-to-First Byte) remain stable or improve, the limit goes up, meaning more connections can be used to crawl. If the site slows down (latency increases or response times become longer), or responds with server errors (`5xx HTTP` status codes) or rate-limiting signals (such as `HTTP 429`), the limit goes down and Google crawls less.
-   **Google's crawling limits:** While Google's resources are extensive, they are finite, and we must prioritize resource allocation across the web.

### Crawl demand

Each crawler has its own "demand" when it comes to crawling the web, determined by factors unique to that crawler. For example, AdsBot generally has a higher demand when a site is running dynamic ad targets, and Google Shopping has a higher demand for products you have in your merchant feeds.

For [Googlebot](https://googlebot.com/), demand varies based on a site's size, update frequency, page quality, and relevance, compared to other sites. The primary factors you can influence are:

-   **Perceived inventory:** Without guidance from you, Google tries to crawl all or most of the URLs that it knows about on your site. If many of these URLs are duplicates, or you don't want them crawled for some other reason (removed, unimportant, and so on), this wastes a lot of Google crawling time on your site. This is the factor that you can positively control the most.
-   **Popularity:** URLs that are more popular on the Internet tend to be crawled more often to keep them fresher in our systems.
-   **Staleness:** Our systems want to recrawl documents frequently enough to pick up any changes.

Additionally, site-wide events like site moves may trigger an increase in crawl demand in order to reprocess the content under the new URLs.

While each crawler has a different _crawl demand_, the _crawl capacity limit_ is shared across all crawlers. This means that high demand from one crawler can reduce the capacity available for others.

### Summary

Taking crawl capacity and crawl demand together, Google defines a site's crawl budget as the set of URLs that Google can and wants to crawl. Even if the crawl capacity limit isn't reached, if crawl demand is low, Google will crawl your site less.

## Best practices

To maximize your crawling efficiency, follow these best practices:

-   **Manage your URL inventory:** Use the appropriate tools to tell Google which pages to crawl and which not to crawl. If Google spends too much time crawling URLs that it shouldn't, Google's crawlers might not explore the rest of your site, or might not increase your crawl budget.
    -   **[Consolidate duplicate content](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls).** Eliminate duplicate content to focus crawling on unique content rather than unique URLs.
    -   [**Block crawling of URLs using robots.txt**](https://developers.google.com/search/docs/crawling-indexing/troubleshoot-crawling-errors#hide_urls). Some pages might be important to users, but you don't necessarily want them to appear on Google surfaces or get reprocessed by Google's systems. Examples include infinite scrolling pages that duplicate information on linked pages, or differently sorted versions of the same page. If you can't consolidate them as described in the first bullet, block these unimportant pages using [robots.txt](https://developers.google.com/crawling/docs/robots-txt/create-robots-txt). Blocking URLs with robots.txt prevents Google from crawling them, and significantly decreases the chance the URLs will be processed by other Google systems (such as getting indexed by Google Search).
        
        **Don't use `noindex`**, as Google will still request, but then drop the page when it sees a `noindex` `meta` tag or header in the HTTP response, wasting crawling time. **Don't use robots.txt to temporarily reallocate crawl budget** for other pages; use robots.txt to block pages or resources that you don't want Google to crawl at all. Google won't shift this newly available crawl budget to other pages unless Google is already hitting your site's crawl capacity limit.
        
    -   **Return a `404` or `410` status code for permanently removed pages.** Google won't forget a URL that it knows about, but a `404` status code is a strong signal not to crawl that URL again. Blocked URLs, however, will stay part of your crawl queue much longer, and will be recrawled when the block is removed.
    -   **[Eliminate `soft 404` errors](https://developers.google.com/search/docs/crawling-indexing/troubleshoot-crawling-errors#soft-404-errors).** `soft 404` pages will continue to be crawled, and waste your budget. Check the [Page Indexing report](https://support.google.com/webmasters/answer/7440203) for `soft 404` errors.
    -   **Keep your sitemaps up to date.** Google reads your sitemap regularly, so be sure to include all the content that you want Google to crawl. If your site includes updated content, we recommend including the `<lastmod>` tag.
    -   **Avoid long redirect chains**, which have a negative effect on crawling.
-   **[Make your pages efficient to load](https://developers.google.com/search/docs/crawling-indexing/troubleshoot-crawling-errors#improve_crawl_efficiency).** If Google can load and render your pages faster, we might be able to read more content from your site.
    -   **Improve loading speed:** Optimize your server response times and resources to make pages load faster.
    -   **Use HTTP caching:** Support [`304 (Not Modified)` HTTP status codes](https://developers.google.com/search/docs/crawling-indexing/troubleshoot-crawling-errors#if-modified-since). If a page hasn't changed since Google last crawled it, returning a `304` code tells Google to reuse the cached version, saving your server bandwidth and resources.
-   **[Debug issues with crawl budget](https://developers.google.com/search/docs/crawling-indexing/troubleshoot-crawling-errors).** Check whether your site had any availability issues during crawling, and look for ways to make your crawling more efficient.

## How do I get more crawl budget?

There are two ways to increase crawl budget:

-   **Add more server resources**: If your site can't be crawled because of server capacity on your end (for example, you're getting [**Hostload exceeded**](https://support.google.com/webmasters/answer/9012289#site-wide-error-inspection&zippy=%2Csite-wide-availability-issues) in the URL inspection tool), add more server resources if that makes sense for your business.
-   **Optimize your content's quality for the Google product you're targeting**: Google determines the crawling resources allocated to each site by factoring in elements that are relevant to the specific Google product. For example, for Google Search, this includes things like popularity, overall user value, content uniqueness, and serving capacity.

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

Last updated 2026-07-22 UTC.

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

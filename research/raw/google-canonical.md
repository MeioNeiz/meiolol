# How to Specify a Canonical with rel="canonical" and Other Methods | Google Search Central  |  Documentation  |  Google for Developers

<https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls>

[Skip to main content](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#main-content)

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
        
        -   [What is URL canonicalization](https://developers.google.com/search/docs/crawling-indexing/canonicalization)
        -   [How to specify a canonical URL with rel="canonical" and other methods](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls)
        -   [Fix canonicalization issues](https://developers.google.com/search/docs/crawling-indexing/canonicalization-troubleshooting)
        
    -   [Mobile site and mobile-first indexing](https://developers.google.com/search/docs/crawling-indexing/mobile/mobile-sites-mobile-first-indexing)
    -   AMP
        
    -   JavaScript
        
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
-   [Reasons to specify a canonical URL](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#reasons-to-specify-a-canonical-url)
-   [Best practices](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#best-practices)
-   [Comparison of canonicalization methods](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#comparison-of-canonicalization-methods)
-   [Use rel="canonical" link annotations](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#use-rel=canonical-link-annotations)
    -   [The rel="canonical" link element](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#rel-canonical-link-method)
    -   [The rel="canonical" HTTP header](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#rel-canonical-header-method)
-   [Use a sitemap](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#sitemap-method)
-   [Use redirects](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#redirects-method)

# How to specify a canonical URL with rel="canonical" and other methods

To specify a [canonical URL](https://developers.google.com/search/docs/crawling-indexing/canonicalization) for duplicate or very similar pages to Google Search, you can indicate your preference using a number of methods. These are, in order of how strongly they can influence canonicalization:

-   [**Redirects**](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#redirects-method): A strong signal that the target of the redirect should become canonical.
-   [**`rel="canonical"` `link` annotations**](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#rel-canonical-link-method): A strong signal that the specified URL should become canonical.
-   [**Sitemap inclusion**](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#sitemap-method): A weak signal that helps the URLs that are included in a sitemap become canonical.

Keep in mind that these methods can stack and thus become more effective when combined. This means that when you use two or more of the methods, that will increase the chance of your preferred canonical URL appearing in search results.

While we encourage you to use these methods, none of them are required; your site will likely do just fine without specifying a canonical preference. That's because if you don't specify a canonical URL, [Google will identify which version of the URL is objectively the best version to show to users in Search](https://developers.google.com/search/docs/crawling-indexing/canonicalization#canonical-how).

**If you use a CMS, such as WordPress, Wix, or Blogger**, you might not be able to edit your HTML directly. Instead, your CMS might have a search engine settings page or some other mechanism to tell search engines about the canonical URL. Search for instructions about modifying the `<head>` of your page on your CMS (for example, search for "wordpress set the canonical element").

## Reasons to specify a canonical URL

While it's generally not critical to specify a canonical preference for your URLs, there are a number of reasons why you would want to explicitly tell Google about a canonical page in a set of duplicate or similar pages:

-   **To specify which URL that you want people to see in search results.** You might prefer people to reach your green dress product page through `https://www.example.com/dresses/green/green-dress.html` rather than `https://example.com/dresses/cocktail?gclid=ABCD`.
-   **To consolidate signals for similar or duplicate pages.** It helps search engines to be able to consolidate the signals they have for the individual URLs (such as links to them) into a single, preferred URL. This means that signals from other sites to `https://example.com/dresses/cocktail?gclid=ABCD` get consolidated with links to `https://www.example.com/dresses/green/green-dress.html` if the latter becomes canonical.
-   **To simplify tracking metrics for a piece of content.** With a variety of URLs, it can be more challenging for you to get consolidated metrics for a specific piece of content.
-   **To avoid spending crawling time on duplicate pages.** You may want Googlebot to get the most out of your site, so it's better for it to spend time crawling new (or updated) pages on your site, rather than crawling duplicate versions of the same content.

## Best practices

For all canonicalization methods, follow these best practices:

-   **Don't** use the robots.txt file for canonicalization purposes. Google may still index URLs that are disallowed in robots.txt without their content.
-   **Don't** use the URL removal tool for canonicalization. It hides _all_ versions of a URL from Search.
-   **Don't** specify different URLs as canonical for the same page using different canonicalization techniques (for example, don't specify one URL in a sitemap, but a different URL for that same page using `rel="canonical"`).
-   **Don't** specify a URL fragment as canonical, as [Google generally doesn't support URL fragments](https://developers.google.com/search/docs/crawling-indexing/url-structure#fragments).
-   **Do** include a `rel="canonical"` link on the canonical page itself (also known as a self-referential canonical).
-   **We don't recommend** using [`noindex`](https://developers.google.com/search/docs/crawling-indexing/block-indexing) to prevent selection of a canonical page within a single site, because it will completely block the page from Search. `rel="canonical"` `link` annotations are the preferred solution.
-   If you're using [`hreflang` elements](https://developers.google.com/search/docs/specialty/international/localized-versions), make sure to specify a canonical page in the same language, or the best possible substitute language if a canonical page doesn't exist for the same language.
-   When linking within your site, link to the canonical URL rather than a duplicate URL. Linking consistently to the URL that you consider to be canonical helps Google understand your preference.
-   If you're using client-side rendering with JavaScript, it's important to make sure that the information about the canonical URL is as clear as possible. The best way to do this is to specify the canonical URL in the HTML source code and make sure that JavaScript doesn't change the canonical link element. If you can't set the canonical URL in the HTML source code, leave it out and only set it with JavaScript. This ensures that the information about the canonical URL is as clear as possible.

## Comparison of canonicalization methods

The following table compares the different canonicalization methods, highlighting their strengths and weaknesses when it comes to maintenance and efficacy in different scenarios.

| Method and description |
| --- |
| [`rel="canonical" link` element](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#rel-canonical-link-method) | 
Add a `<link>` element in the code for all duplicate pages, pointing to the canonical page.

<table><tbody><tr><td width="50%"><span class="compare-yes" aria-hidden="true"></span><b>Pros:</b><ul><li>Can map an infinite number of duplicate pages.</li></ul></td><td width="50%"><span class="compare-no" aria-hidden="true"></span><b>Cons:</b><ul><li>Can be complex to maintain the mapping on larger sites, or sites where the URLs change often.</li><li>Only works for HTML pages, not for files such as PDF. In such cases, you can use the <code translate="no" dir="ltr">rel="canonical"</code> HTTP header.</li></ul></td></tr></tbody></table>

 |
| [`rel="canonical"` HTTP header](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#rel-canonical-header-method) | 

Send a `rel="canonical"` header in your page response.

<table><tbody><tr><td width="50%"><span class="compare-yes" aria-hidden="true"></span><b>Pros:</b><ul><li>Doesn't increase page size.</li><li>Can map an infinite number of duplicate pages.</li></ul></td><td width="50%"><span class="compare-no" aria-hidden="true"></span><b>Cons:</b><ul><li>Can be complex to maintain the mapping on larger sites, or sites where the URLs change often.</li></ul></td></tr></tbody></table>

 |
| [Sitemap](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#sitemap-method) | 

Specify your canonical pages in a sitemap.

<table><tbody><tr><td width="50%"><p><span class="compare-yes" aria-hidden="true"></span><b>Pros:</b></p><ul><li>Simple to implement and maintain, especially on large sites.</li></ul></td><td width="50%"><p><span class="compare-no" aria-hidden="true"></span><b>Cons:</b></p><ul><li>Google must still determine the associated duplicate for any canonicals that you declare in the sitemap.</li><li>Less powerful signal to Google than the <code translate="no" dir="ltr">rel="canonical"</code> mapping technique.</li></ul></td></tr></tbody></table>

 |
| [Redirects](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#redirects-method) | Use permanent redirects to tell Google that a redirected URL is a worse version than the URL it redirects to. Use this only when deprecating a duplicate page. |
| [AMP variant](https://developers.google.com/search/docs/crawling-indexing/amp) | If one of your variants is an AMP page, follow the AMP guidelines to indicate the canonical page and AMP variant. |

## Use `rel="canonical"` `link` annotations

Google supports explicit `rel` canonical `link` annotations as described in [RFC 6596](https://www.rfc-editor.org/rfc/rfc6596). `rel="canonical"` annotations that suggest alternate versions of a page are ignored; specifically, `rel="canonical"` annotations with `hreflang`, `lang`, `media`, and `type` attributes are not used for canonicalization. Instead, use the appropriate `link` annotations to specify alternate versions of a page; for example, `link` `rel="alternate"` [`hreflang`](https://developers.google.com/search/docs/specialty/international/localized-versions) for language and country annotations.

You can provide the `rel="canonical"` `link` annotations in two ways:

-   [The `rel="canonical"` `link` element in the HTML](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#rel-canonical-link-method)
-   [The `rel="canonical"` `link` HTTP header](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#rel-canonical-header-method)

We recommend that you choose one of these and go with that; while supported, using both methods at the same time is more error prone (for example, you might provide one URL in the HTTP header, and another URL in the `rel="canonical"` `link` element).

### The `rel="canonical"` `link` element

A `rel="canonical"` `link` element (also known as a _canonical element_) is an element used in the `head` section of HTML to indicate that another page is representative of the content on the page.

Suppose you want `https://example.com/dresses/green-dresses` to be the canonical URL, even though a variety of URLs can access this content. Indicate this URL as canonical with these steps:

1.  Add a `<link>` element with the attribute `rel="canonical"` to the `<head>` section of duplicate pages, pointing to the canonical page. For example:
    
    <html>
    <head>
    <title>Explore the world of dresses</title>
    **<link rel="canonical" href="https://example.com/dresses/green-dresses" />**
    <!-- other elements -->
    </head>
    <!-- rest of the HTML -->
    
    We recommend adding this same self-referential `rel="canonical"` link element to the canonical page itself as well.
    
2.  If the canonical page has a mobile variant on a separate URL, add a `rel="alternate"` `link` element to it, pointing to the mobile version of the page:
    
    <html>
    <head>
    <title>Explore the world of dresses</title>
    **<link rel="alternate" media="only screen and (max-width: 640px)"  href="https://m.example.com/dresses/green-dresses">**
    <link rel="canonical" href="https://example.com/dresses/green-dresses" />
    <!-- other elements -->
    </head>
    <!-- rest of the HTML -->
    
3.  Add any [`hreflang`](https://developers.google.com/search/docs/specialty/international/localized-versions) or other elements that are appropriate for the page.

Use absolute paths rather than relative paths with the `rel="canonical"` `link` element. Even though relative paths are supported by Google, they can cause problems in the long run (for example, if you unintentionally allow your testing site to be crawled) and thus we don't recommend them.

**Good example**: `https://www.example.com/dresses/green/green-dress.html`

**Bad example**: `/dresses/green/green-dress.html`

The `rel="canonical"` `link element` is only accepted if it appears in the `<head>` section of the HTML, so make sure at least the [`<head>` section is valid HTML](https://developers.google.com/search/docs/crawling-indexing/valid-page-metadata).

If you use JavaScript to add the `rel="canonical"` `link` element, make sure to [inject the canonical link element properly](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics#properly-inject-canonical-links).

### The `rel="canonical"` HTTP header

If you can change the configuration of your server, you can use a `link` [HTTP response header](https://en.wikipedia.org/wiki/List_of_HTTP_header_fields) with a `rel="canonical"` target attribute as defined by [RFC5988](https://www.rfc-editor.org/rfc/rfc5988.html#section-5.1) rather than an HTML element to indicate the canonical URL for a document supported by Search, including non-HTML documents such as PDF files.

Google supports this method for web search results only.

If you publish content in many file formats, such as PDF or Microsoft Word, each on their own URL, you can return a `rel="canonical"` HTTP header to tell Googlebot what is the canonical URL for the non-HTML files. For example, to indicate that the PDF version of the `.docx` version should be canonical, you might add this HTTP header for the `.docx` version of the content:

HTTP/1.1 200 OK
Content-Length: 19
...
**Link: <https://www.example.com/downloads/white-paper.pdf>; rel="canonical"**
...

As with the `rel="canonical"` `link` element, use absolute URLs in the `rel="canonical"` HTTP header.

## Use a sitemap

Pick a canonical URL for each of your pages and submit them in a [sitemap](https://developers.google.com/search/docs/crawling-indexing/sitemaps/overview). All pages listed in a sitemap are suggested as canonicals; Google will decide which pages (if any) are duplicates, based on similarity of content.

Supplying the preferred canonical URLs in the sitemaps is a straightforward way of defining canonicals for a large site, and sitemaps are a useful way to tell Google which pages you consider most important on your site.

## Use redirects

Use this method when you want to get rid of existing duplicate pages. All [permanent redirection methods](https://developers.google.com/search/docs/crawling-indexing/301-redirects) have the same effect on Google Search, however the time it takes for search engines to notice the different redirect methods may differ.

For the quickest effect, use HTTP (also known as _server-side_) redirects.

Suppose your page can be reached in multiple ways:

-   `https://example.com/home`
-   `https://home.example.com`
-   `https://www.example.com`

Pick one of those URLs as your canonical URL, and use redirects to send traffic from the other URLs to your preferred URL.

## Other signals

Apart from explicitly provided methods, Google also uses a set of canonicalization signals that are generally based on site setup: preferring HTTPS over HTTP, and URLs in `hreflang` clusters.

### Prefer HTTPS over HTTP for canonical URLs

Google prefers HTTPS pages over equivalent HTTP pages as canonical, except when there are issues or conflicting signals such as the following:

-   The HTTPS page has an invalid SSL certificate.
-   The HTTPS page contains insecure dependencies (other than images).
-   The HTTPS page redirects users to or through an HTTP page.
-   The HTTPS page has a `rel="canonical"` `link` to the HTTP page.

Although our systems prefer HTTPS pages over HTTP pages by default, you can ensure this behavior by taking any of the following actions:

-   Add redirects from the HTTP page to the HTTPS page.
-   Add a `rel="canonical"` `link` from the HTTP page to the HTTPS page.
-   Implement [HSTS](https://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security).

To prevent Google from incorrectly making the HTTP page canonical, **avoid** the following practices:

-   Avoid bad TLS/SSL certificates and HTTPS-to-HTTP redirects because they cause Google to prefer HTTP very strongly. Implementing HSTS cannot override this strong preference.
-   Don't include the HTTP version of your pages in your sitemap or [`hreflang` annotations](https://developers.google.com/search/docs/specialty/international/localized-versions) rather than the HTTPS version.
-   Avoid implementing your SSL/TLS certificate for the wrong host-variant. For example, `example.com` serving the certificate for `subdomain.example.com`. The certificate must match your complete site URL, or be a wildcard certificate that can be used for multiple subdomains on a domain.

### Prefer URLs in `hreflang` clusters

To help with sites' localization efforts, for canonicalization purposes Google prefers URLs that are part of `hreflang` clusters. For example, if `https://example.com/de-de/cats` and `https://example.com/de-ch/cats` reciprocally point to each other with `hreflang` annotations, but not to `https://example.com/de-at/cats`, the pages for `de-de` and `de-ch` will be preferred as canonicals instead of the `/de-at/` page that doesn't appear in the `hreflang` cluster.

Read more about [troubleshooting and fixing canonicalization issues](https://developers.google.com/search/docs/crawling-indexing/canonicalization-troubleshooting).

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

Last updated 2026-07-10 UTC.

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

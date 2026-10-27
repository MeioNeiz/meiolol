# Redirects and Google Search | Google Search Central  |  Documentation  |  Google for Developers

<https://developers.google.com/search/docs/crawling-indexing/301-redirects>

[Skip to main content](https://developers.google.com/search/docs/crawling-indexing/301-redirects#main-content)

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
        
    -   Page and content metadata
        
    -   Removals
        
    -   Site moves and changes
        
        -   [Redirects and Google Search](https://developers.google.com/search/docs/crawling-indexing/301-redirects)
        -   Site moves
            
        -   [A/B testing](https://developers.google.com/search/docs/crawling-indexing/website-testing)
        -   [Temporarily pause or disable a website](https://developers.google.com/search/docs/crawling-indexing/pause-online-business)
        
    
-   Ranking and search appearance
    
-   Monitoring and debugging
    
-   Site-specific guides
    

-   [Home](https://developers.google.com/)
-   [Search Central](https://developers.google.com/search)
-   [Documentation](https://developers.google.com/search/docs)

-   On this page
-   [Overview of redirect types](https://developers.google.com/search/docs/crawling-indexing/301-redirects#overview-of-redirect-types)
-   [Server-side redirects](https://developers.google.com/search/docs/crawling-indexing/301-redirects#serverside)
    -   [Permanent](https://developers.google.com/search/docs/crawling-indexing/301-redirects#permanent-server-side-redirects)
    -   [Temporary](https://developers.google.com/search/docs/crawling-indexing/301-redirects#temporary-server-side-redirects)
    -   [Implement](https://developers.google.com/search/docs/crawling-indexing/301-redirects#implement-server-side-redirects)
-   [meta refresh and its HTTP equivalent](https://developers.google.com/search/docs/crawling-indexing/301-redirects#metarefresh)
-   [JavaScript location redirects](https://developers.google.com/search/docs/crawling-indexing/301-redirects#jslocation)
-   [Crypto redirects](https://developers.google.com/search/docs/crawling-indexing/301-redirects#cryptoredirects)

# Redirects and Google Search

Redirecting URLs is the practice of resolving an existing URL to a different one, effectively telling your visitors and Google Search that a page has a new location. Redirects are particularly useful in the following circumstances:

-   You've moved your site to a new domain, and you want to make the transition as seamless as possible.
-   People access your site through several different URLs. If, for example, your home page can be reached in multiple ways (for instance, `https://example.com/home`, `http://home.example.com`, or `https://www.example.com`), it's a good idea to pick one of those URLs as your preferred ([canonical](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#definition)) destination, and use redirects to send traffic from the other URLs to your preferred URL.
-   You're merging two websites and want to make sure that links to outdated URLs are redirected to the correct pages.
-   You removed a page and you want to send users to a new page.

If you're using a platform like Blogger or Shopify, the platform may already have built-in redirect solutions. Try searching for help articles (for example, search for "blogger redirects").

## Overview of redirect types

While your users generally won't be able to tell the difference between the different types of redirects, Google Search uses certain types of redirects as a signal that the redirect target should be canonical. Choosing a redirect depends on how long you expect the redirect will be in place and what page you want Google Search to show in search results:

-   **Permanent redirects**: Show the new redirect target in search results.
-   **Temporary redirects**: Show the source page in search results.

The following table explains the various ways you can use to set up permanent and temporary redirects, ordered by how likely Google is able to interpret correctly (for example, a server side redirect has the highest chance of being interpreted correctly by Google). Choose the redirect type that works for your situation and site:

| Redirect types |
| --- |
| Permanent | 
Googlebot follows the redirect, and the indexing pipeline uses the redirect as a signal that the redirect target should be [canonical](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls#definition).

Use permanent redirects when you're sure that the redirect won't be reverted.

<table class="fixed"><tbody><tr><td width="40%"><code translate="no" dir="ltr">HTTP 301 (moved permanently)</code></td><td rowspan="2"><p>Set up <a href="https://developers.google.com/search/docs/crawling-indexing/301-redirects#serverside">server-side redirects</a>.</p></td></tr><tr><td><code translate="no" dir="ltr">HTTP 308 (moved permanently)</code></td></tr><tr><td><code translate="no" dir="ltr">meta refresh</code> (0 seconds)</td><td rowspan="2"><p>Set up <a href="https://developers.google.com/search/docs/crawling-indexing/301-redirects#metarefresh"><code translate="no" dir="ltr">meta refresh</code> redirects</a>.</p></td></tr><tr><td>HTTP refresh (0 seconds)</td></tr><tr><td>JavaScript <code translate="no" dir="ltr">location</code></td><td><p>Set up <a href="https://developers.google.com/search/docs/crawling-indexing/301-redirects#jslocation">JavaScript redirects</a>.</p><aside class="warning">Only use JavaScript redirects if you can't do server-side or <code translate="no" dir="ltr">meta refresh</code> redirects.</aside></td></tr><tr><td><span translate="no">Crypto</span> redirect</td><td><p>Learn more about <a href="https://developers.google.com/search/docs/crawling-indexing/301-redirects#cryptoredirects"><span translate="no">crypto</span> redirects</a>.</p><aside class="warning">Don't rely on <span translate="no">crypto</span> redirects for letting search engines know that your content has moved unless you have no other choice.</aside></td></tr></tbody></table>

 |
| Temporary | 

Googlebot follows the redirect, but the indexing pipeline doesn't use the redirect as a signal that the redirect target should be canonical. The target page might still be indexed if other canonicalization signals are present.

<table><tbody><tr><td width="40%"><code translate="no" dir="ltr">HTTP 302 (found)</code></td><td rowspan="3"><p>Set up <a href="https://developers.google.com/search/docs/crawling-indexing/301-redirects#serverside">server-side redirects</a>.</p></td></tr><tr><td><code translate="no" dir="ltr">HTTP 303 (see other)</code></td></tr><tr><td><code translate="no" dir="ltr">HTTP 307 (temporary redirect)</code></td></tr><tr><td><code translate="no" dir="ltr">meta refresh</code> (more than 0 seconds)</td><td rowspan="2"><p>Set up <a href="https://developers.google.com/search/docs/crawling-indexing/301-redirects#metarefresh"><code translate="no" dir="ltr">meta refresh</code> redirects</a>.</p></td></tr><tr><td><code translate="no" dir="ltr">HTTP refresh</code> (more than 0 seconds)</td></tr></tbody></table>

 |

## Server-side redirects

Setting up server-side redirects requires access to the server configuration files (for example, the `.htaccess` file on Apache) or setting the redirect headers with server-side scripts (for example, PHP). You can create both permanent and temporary redirects on the server side.

### Permanent server-side redirects

If you need to change the URL of a page as it is shown in search engine results, we recommend that you use a permanent server-side redirect whenever possible. This is the best way to ensure that Google Search and people are directed to the correct page. The `301` and `308` status codes mean that a page has permanently moved to a new location.

### Temporary server-side redirects

If you just want to send users to a different page temporarily, use a temporary redirect. This will also ensure that Google isn't influenced by the redirect which may help keep the old URL in its Search results. For example, if a service your site offers is temporarily unavailable, you can set up a temporary redirect to send users to a page that explains what's happening, without compromising the original URL in search results.

### Implement server-side redirects

The implementation of server-side redirects depends on your hosting and server environment, or the scripting language of your site's backend.

To set up a permanent redirect with PHP, use the `header()` function. You must set the headers before sending anything to the screen:

header('HTTP/1.1 301 Moved Permanently');
header('Location: https://www.example.com/newurl');
exit();

Similarly, here's an example of how to set up a temporary redirect with PHP:

header('HTTP/1.1 302 Found');
header('Location: https://www.example.com/newurl');
exit();

If you have access to your web server configuration files, you may be able to write the redirect rules yourself. Follow your web server's guides:

-   **Apache:** Consult the [Apache `.htaccess` Tutorial](https://httpd.apache.org/docs/2.0/howto/htaccess.html), the [Apache URL Rewriting Guide](https://httpd.apache.org/docs/2.0/misc/rewriteguide.html), and the [Apache `mod_alias` documentation](https://httpd.apache.org/docs/current/mod/mod_alias.html). For example, you can use `mod_alias` to set up the simplest form of redirects:
    
    \# Permanent redirect:
    Redirect permanent "/old" "https://example.com/new"
    
    # Temporary redirect:
    Redirect temp "/two-old" "https://example.com/two-new"
    
    For more complex redirects, use `mod_rewrite`. For example:
    
    RewriteEngine on
    # redirect the service page to a new page with a permanent redirect
    RewriteRule   "^/service$"  "/about/service"  \[R=301\]
    
    # redirect the service page to a new page with a temporary redirect
    RewriteRule   "^/service$"  "/about/service"  \[R\]
    
-   **NGINX:** Read about [Creating NGINX Rewrite Rules](https://www.nginx.com/blog/creating-nginx-rewrite-rules/) on the NGINX blog. As with Apache, you have multiple choices to create redirects. For example:
    
    location = /service {
    # for a permanent redirect
    return 301 $scheme://example.com/about/service
    
    # for a temporary redirect
    return 302 $scheme://example.com/about/service
    }
    
    For more complex redirects, use the `rewrite` rule:
    
    location = /service {
    # for a permanent redirect
    rewrite service?name=$1 ^service/offline/(\[a-z\]+)/?$ permanent;
    
    # for a temporary redirect
    rewrite service?name=$1 ^service/offline/(\[a-z\]+)/?$ redirect;
    }
    
-   For all other web servers, check with your server manager or hoster, or search for guides on your favorite search engine (for example, search for "LiteSpeed redirects").

## `meta refresh` and its HTTP equivalent

If [server-side redirects](https://developers.google.com/search/docs/crawling-indexing/301-redirects#serverside) aren't possible to implement on your platform, `meta refresh` redirects may be a viable alternative. Google differentiates between two kinds of `meta refresh` redirects:

-   **Instant `meta refresh` redirect**: Triggers as soon as the page is loaded in a browser. Google Search interprets instant `meta refresh` redirects as permanent redirects.
-   **Delayed `meta refresh` redirect**: Triggers only after an arbitrary number of seconds set by the site owner. Google Search interprets delayed `meta refresh` redirects as temporary redirects.

Place the `meta refresh` redirect either in the `<head>` element in the HTML or in the HTTP header with server-side code. For example, here's an instant `meta refresh` redirect in the `<head>` element in the HTML:

<!doctype html>
<html\>
<head\>
<meta http-equiv="refresh" content="0; url\=https://example.com/newlocation">
<title\>Example title</title\>
<!--...--\>

Here's an example of the HTTP header equivalent, which you can inject with server-side scripts:

HTTP/1.1 200 OK
Refresh: 0; url=https://www.example.com/newlocation
...

To create a delayed redirect, which is interpreted as a temporary redirect by Google, set the `content` attribute to the number of seconds that the redirect should be delayed:

<!doctype html>
<html\>
<head\>
<meta http-equiv="refresh" content="5; url\=https://example.com/newlocation">
<title\>Example title</title\>
<!--...--\>

## JavaScript `location` redirects

Google Search interprets and executes JavaScript using the Web Rendering Service once crawling of the URL has completed.

Only use JavaScript redirects if you can't do server-side or `meta refresh` redirects. While Google attempts to render every URL Googlebot crawled, rendering may fail for various reasons. This means that if you set a JavaScript redirect, Google might never see it if rendering of the content failed.

To set up a JavaScript redirect, set the `location` property to the redirect target URL in a script block in the HTML head. For example:

<!doctype html\>
<html\>
<head\>
<script\>
  window.location.href \= "https://www.example.com/newlocation";
</script\>
<title\>Example title</title\>
<!--...--\>

## Crypto redirects

If you can't implement any of the other redirect methods, you should still make an effort to let your users know that the page or its content has moved. The simplest way to do this is to add a link pointing to the new page accompanied by a short explanation. For example:

> <a href="https://newsite.example.com/newpage.html">We moved! Find the content on our new site!</a>

This helps users find your new site and Google may understand this as a crypto redirect, (like the Loch Ness monster, its existence may be disputed; not all search engines may recognize this pseudo-redirect as an official redirect).

Don't rely on crypto redirects for letting search engines know that your content has moved unless you have no other choice. Contact your hosting provider for help with other types of redirects before resorting to crypto redirects.

## Alternate versions of a URL

When you redirect a URL, Google keeps track of both the redirect source (the old URL) and the redirect target (the new URL). One of the URLs will be the [canonical](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls); which one, depends on signals such as whether the redirect was temporary or permanent. The other URL becomes an _alternate name_ of the canonical URL. Alternate names are different versions of a canonical URL that users might recognize and trust more. Alternate names may appear in search results when a user's query hints that they might trust the old URL more.

For example, if you [moved to a new domain name](https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes), it's very likely that Google will continue to occasionally show the old URLs in the results, even though the new URLs are already indexed. This is normal and as users get used to the new domain name, the alternate names will fade away without you doing anything.

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

Last updated 2026-04-14 UTC.

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

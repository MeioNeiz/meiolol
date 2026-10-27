# URL Structure Best Practices for Google Search | Google Search Central  |  Documentation  |  Google for Developers

<https://developers.google.com/search/docs/crawling-indexing/url-structure>

[Skip to main content](https://developers.google.com/search/docs/crawling-indexing/url-structure#main-content)

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
        
    
-   Ranking and search appearance
    
-   Monitoring and debugging
    
-   Site-specific guides
    

-   [Home](https://developers.google.com/)
-   [Search Central](https://developers.google.com/search)
-   [Documentation](https://developers.google.com/search/docs)

-   On this page
-   [Requirements for a crawlable URL structure](https://developers.google.com/search/docs/crawling-indexing/url-structure#requirements-for-a-crawlable-url-structure)
    -   [Follow IETF STD 66](https://developers.google.com/search/docs/crawling-indexing/url-structure#follow-ietf-std-66)
    -   [Don't use URL fragments to change content](https://developers.google.com/search/docs/crawling-indexing/url-structure#dont-use-url-fragments-to-change-content)
    -   [Use a common encoding for URL parameters](https://developers.google.com/search/docs/crawling-indexing/url-structure#use-a-common-encoding-for-url-parameters)
-   [Make it easy to understand your URL structure](https://developers.google.com/search/docs/crawling-indexing/url-structure#best-practices)
    -   [Use descriptive URLs](https://developers.google.com/search/docs/crawling-indexing/url-structure#use-descriptive-urls)
    -   [Use your audience's language](https://developers.google.com/search/docs/crawling-indexing/url-structure#use-your-audiences-language)
    -   [Use percent encoding as necessary](https://developers.google.com/search/docs/crawling-indexing/url-structure#use-percent-encoding-as-necessary)

# URL structure best practices for Google Search

To make sure Google Search can crawl your site effectively, use a crawlable URL structure that meets the following requirements. If your URLs don't meet the following criteria, Google Search will likely crawl your site inefficiently — including but not limited to extremely high crawl rates, or not at all.

<table class="responsive fixed"><thead></thead><colgroup><col width="20%"></colgroup><tbody><tr><th colspan="2"><h2 id="requirements-for-a-crawlable-url-structure" data-text="Requirements for a crawlable URL structure" tabindex="-1">Requirements for a crawlable URL structure</h2></th></tr></tbody><tbody><tr><td><h3 id="follow-ietf-std-66" data-text="Follow IETF STD 66" tabindex="-1">Follow <a href="https://datatracker.ietf.org/doc/std66/" class="external-link">IETF STD 66</a></h3></td><td><p>Google Search supports URLs as defined by <a href="https://datatracker.ietf.org/doc/std66/" class="external-link">IETF STD 66</a>. Characters defined by the standard as <a href="https://www.rfc-editor.org/rfc/rfc3986#section-2.2" class="external-link">reserved</a> must be <a href="https://developer.mozilla.org/docs/Glossary/Percent-encoding" class="external-link">percent encoded</a>.</p></td></tr><tr><td><h3 id="dont-use-url-fragments-to-change-content" data-text="Don't use URL fragments to change content" tabindex="-1">Don't use URL fragments to change content</h3></td><td><p>Don't use <a href="https://wikipedia.org/wiki/URI_fragment" class="external-link">fragments</a> to change the content of a page, as Google Search generally doesn't support URL fragments. Here's an example of a URL fragment:</p><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/#/potatoes</pre></devsite-code><p>If you're using JavaScript to change content, <a href="https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics#use-history-api">use the History API</a> instead.</p></td></tr><tr><td><h3 id="use-a-common-encoding-for-url-parameters" data-text="Use a common encoding for URL parameters" tabindex="-1">Use a common encoding for URL parameters</h3></td><td><p>When specifying URL parameters, use the following common encoding: an equal sign (<code translate="no" dir="ltr">=</code>) to separate key-value pairs and add additional parameters with an ampersand (<code translate="no" dir="ltr">&amp;</code>). To list multiple values for the same key within a key-value pair, you can use any character that doesn't conflict with <a href="https://datatracker.ietf.org/doc/std66/" class="external-link">IETF STD 66</a>, such as a comma (<code translate="no" dir="ltr">,</code>).</p><div class="devsite-table-wrapper"><table class="fixed vertical-rules"><tbody><tr><th><span class="compare-yes" aria-hidden="true"></span>Recommended</th><th><span class="compare-no" aria-hidden="true"></span>Not recommended</th></tr><tr><td>Using an equal sign (<code translate="no" dir="ltr">=</code>) to separate key-value pairs and an ampersand (<code translate="no" dir="ltr">&amp;</code>) to add additional parameters:<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/category?category=dresses&amp;sort=low-to-high&amp;sid=789</pre></devsite-code></td><td>Using a colon (<code translate="no" dir="ltr">:</code>) to separate key-value pairs and brackets (<code translate="no" dir="ltr">[ ]</code>) to add additional parameters:<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/category?[category:dresses][sort:price-low-to-high][sid:789]</pre></devsite-code></td></tr><tr><td>Using a comma (<code translate="no" dir="ltr">,<wbr></code>) to list multiple values for the same key, an equal sign (<code translate="no" dir="ltr">=</code>) to separate key-value pairs, and an ampersand (<code translate="no" dir="ltr">&amp;</code>) to add additional parameters:<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/category?category=dresses&amp;color=purple,pink,salmon&amp;sort=low-to-high&amp;sid=789</pre></devsite-code></td><td>Using a single comma (<code translate="no" dir="ltr">,<wbr></code>) to separate key-value pairs and double commas (<code translate="no" dir="ltr">,<wbr>,<wbr></code>) to add additional parameters:<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/category?category,dresses,,sort,lowtohigh,,sid,789</pre></devsite-code></td></tr></tbody></table></div></td></tr></tbody></table>

## Make it easy to understand your URL structure

To help Google Search (and your users) better understand your site, we recommend creating a simple URL structure, applying the following best practices when possible.

Consider organizing your content so that URLs are constructed logically and in a manner that is most intelligible to humans. For information on structuring your site as a whole, check out [this section of the SEO Starter Guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide#group-topically).

<table class="responsive fixed"><thead></thead><colgroup><col width="20%"></colgroup><tbody><tr><th colspan="2">Best practices</th></tr></tbody><tbody><tr><td><h3 id="use-descriptive-urls" data-text="Use descriptive URLs" tabindex="-1">Use descriptive URLs</h3></td><td><p>When possible, use readable words rather than long ID numbers in your URLs.</p><div class="devsite-table-wrapper"><table class="fixed vertical-rules"><tbody><tr><th><span class="compare-yes" aria-hidden="true"></span>Recommended (simple, descriptive words)</th><th><span class="compare-no" aria-hidden="true"></span>Not recommended (unreadable, long ID numbers)</th></tr><tr><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>wiki/Aviation</strong></pre></devsite-code></td><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>index.php?topic=42&amp;area=3a5ebc944f41daa6f849f730f1</strong></pre></devsite-code></td></tr></tbody></table></div></td></tr><tr><td><h3 id="use-your-audiences-language" data-text="Use your audience's language" tabindex="-1">Use your audience's language</h3></td><td><p>Use words in your audience's language in the URL (and, if applicable, transliterated words). For example, if your audience is searching in German, use German words in the URL:</p><div></div><devsite-code no-copy="" data-copy-event-label=""><pre translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>lebensmittel/pfefferminz</strong></pre></devsite-code><p>Or if your audience is searching in Japanese, use Japanese words in the URL:</p><div></div><devsite-code no-copy="" data-copy-event-label=""><pre translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>ペパーミント</strong></pre></devsite-code></td></tr><tr><td><h3 id="use-percent-encoding-as-necessary" data-text="Use percent encoding as necessary" tabindex="-1">Use percent encoding as necessary</h3></td><td><p>When <a href="https://developers.google.com/search/docs/crawling-indexing/links-crawlable">linking to pages on your site</a>, use percent encoding in your links's <code translate="no" dir="ltr">href</code> attributes as necessary. Unreserved ASCII characters may be left in the non-encoded form. Additionally, characters in the non-ASCII range should be percent encoded. For example:</p><div class="devsite-table-wrapper"><table class="fixed vertical-rules"><tbody><tr><th><span class="compare-yes" aria-hidden="true"></span>Recommended (percent encoding)</th><th><span class="compare-no" aria-hidden="true"></span>Not recommended (non-ASCII characters)</th></tr><tr><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>%D9%86%D8%B9%D9%86%D8%A7%D8%B9/%D8%A8%D9%82%D8%A7%D9%84%D8%A9</strong></pre></devsite-code></td><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>نعناع</strong></pre></devsite-code></td></tr><tr><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>%E6%9D%82%E8%B4%A7/%E8%96%84%E8%8D%B7</strong></pre></devsite-code></td><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>杂货/薄荷</strong></pre></devsite-code></td></tr><tr><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>gem%C3%BCse</strong></pre></devsite-code></td><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>gemüse</strong></pre></devsite-code></td></tr><tr><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>%F0%9F%A6%99%E2%9C%A8</strong></pre></devsite-code></td><td><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>🦙✨</strong></pre></devsite-code></td></tr></tbody></table></div></td></tr><tr><td><h3 id="use-hyphens-to-separate-words" data-text="Use hyphens to separate words" tabindex="-1">Use hyphens to separate words</h3></td><td><p>We recommend separating words in your URLs, when possible. Specifically, we recommend using hyphens (<code translate="no" dir="ltr">-</code>) instead of underscores (<code translate="no" dir="ltr">_</code>) to separate words in your URLs, as it helps users and search engines better identify concepts in the URL. For historical reasons, we don't recommend using underscores, as underscores are commonly used for denoting concepts that should be kept together, for example, by various programming languages to name functions (such as <code translate="no" dir="ltr">format_date</code>), whereas hyphens clearly signal a word boundary.</p><div class="devsite-table-wrapper"><table class="fixed vertical-rules"><tbody><tr><th><span class="compare-yes" aria-hidden="true"></span>Recommended</th><th><span class="compare-no" aria-hidden="true"></span>Not recommended</th></tr><tr><td><p>Using hyphens (<code translate="no" dir="ltr">-</code>) to separate words:</p><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/summer<strong>-</strong>clothing/filter?color<strong>-</strong>profile=dark<strong>-</strong>grey</pre></devsite-code></td><td><p>Using underscores (<code translate="no" dir="ltr">_</code>) to separate words:</p><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/summer<strong>_</strong>clothing/filter?color<strong>_</strong>profile=dark<strong>_</strong>grey</pre></devsite-code><p>Joining words together in the URL:</p><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/<strong>greendress</strong></pre></devsite-code></td></tr></tbody></table></div></td></tr><tr><td><h3 id="use-as-few-parameters-as-you-can" data-text="Use as few parameters as you can" tabindex="-1">Use as few parameters as you can</h3></td><td>Whenever possible, shorten URLs by trimming unnecessary parameters (meaning, parameters that don't change the content).</td></tr><tr><td><h3 id="be-aware-that-urls-are-case-sensitive" data-text="Be aware that URLs are case sensitive" tabindex="-1">Be aware that URLs are case sensitive</h3></td><td>Like any other HTTP client following IETF STD 66, Google Search's URL handling is case sensitive (for example, Google treats both <code translate="no" dir="ltr">/<wbr>APPLE</code> and <code translate="no" dir="ltr">/<wbr>apple</code> as distinct URLs with their own content). If upper and lower case text in a URL is treated the same by your web server, convert all text to the same case so it's easier for Google to determine that URLs reference the same page.</td></tr><tr><td><h3 id="for-multi-regional-sites" data-text="For multi-regional sites" tabindex="-1">For multi-regional sites</h3></td><td><p>If your site is multi-regional, consider using a URL structure that makes it easy to geotarget your site. For more examples of how you can structure your URLs, refer to <a href="https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites#locale-specific-urls">using locale-specific URLs</a>.</p><p><span class="compare-yes" aria-hidden="true"></span>Recommended (using a country-specific domain):</p><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.de</pre></devsite-code><p><span class="compare-yes" aria-hidden="true"></span>Recommended (using a country-specific subdirectory with gTLD):</p><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="wrap-code" translate="no" dir="ltr" is-upgraded="">https://example.com/de/</pre></devsite-code></td></tr></tbody></table>

## Avoid common issues related to URLs

Overly complex URLs, especially those containing multiple parameters, can cause problems for crawlers by creating unnecessarily high numbers of URLs that point to identical or similar content on your site. As a result, Googlebot may consume much more bandwidth than necessary, or Google Search may be unable to completely index all the content on your site.

Unnecessarily high numbers of URLs can be caused by a number of issues. These include:

<table class="responsive fixed"><thead></thead><colgroup><col width="20%"></colgroup><tbody><tr><th colspan="2">Common issues</th></tr></tbody><tbody><tr><td><h3 id="additive-filtering-of-a-set-of-items" data-text="Additive filtering of a set of items" tabindex="-1">Additive filtering of a set of items</h3></td><td><p>Many sites provide different views of the same set of items or search results, often allowing the user to filter this set using defined criteria (for example: show me hotels on the beach). When filters can be combined in an additive manner (for example: hotels on the beach and with a fitness center), the number of URLs (views of data) in the sites explodes. Creating a large number of slightly different lists of hotels is redundant, as Googlebot only needs to see a small number of lists from which it can reach the page for each hotel. For example:</p><ul><li>Hotel properties at "value rates":<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="" translate="no" dir="ltr" is-upgraded="">https://example.com/hotel-search-results.jsp?Ne=292&amp;N=461</pre></devsite-code></li><li>Hotel properties at "value rates" on the beach:<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="" translate="no" dir="ltr" is-upgraded="">https://example.com/hotel-search-results.jsp?Ne=292&amp;N=461+4294967240</pre></devsite-code></li><li>Hotel properties at "value rates" on the beach and with a fitness center:<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="" translate="no" dir="ltr" is-upgraded="">https://example.com/hotel-search-results.jsp?Ne=292&amp;N=461+4294967240+4294967270</pre></devsite-code></li></ul></td></tr><tr><td><h3 id="irrelevant-parameters" data-text="Irrelevant parameters" tabindex="-1">Irrelevant parameters</h3></td><td><p>Irrelevant parameters in the URL can cause a large number of URLs, such as:</p><ul><li>Referral parameters:<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="" translate="no" dir="ltr" is-upgraded="">https://example.com/search/noheaders?click=6EE2BF1AF6A3D705D5561B7C3564D9C2&amp;clickPage=OPD+Product+Page&amp;cat=79</pre></devsite-code><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="" translate="no" dir="ltr" is-upgraded="">https://example.com/discuss/showthread.php?referrerid=249406&amp;threadid=535913</pre></devsite-code><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="" translate="no" dir="ltr" is-upgraded="">https://example.com/products/products.asp?N=200063&amp;Ne=500955&amp;ref=foo%2Cbar&amp;Cn=Accessories</pre></devsite-code></li><li>Shopping sorting parameters:<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="" translate="no" dir="ltr" is-upgraded="">https://example.com/results?search_type=search_videos&amp;search_query=tpb&amp;search_sort=relevance&amp;search_category=25</pre></devsite-code></li><li>Session IDs:<div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="" translate="no" dir="ltr" is-upgraded="">https://example.com/search/noheaders?sessionid=6EE2BF1AF6A3D705D5561B7C3564D9C2</pre></devsite-code><aside class="note">Wherever possible, avoid the use of session IDs in URLs and consider using cookies instead.</aside></li></ul><p>Consider using a <a href="https://developers.google.com/search/docs/crawling-indexing/robots/intro">robots.txt file</a> to block Googlebot's access to these problematic URLs.</p></td></tr><tr><td><h3 id="calendar-issues" data-text="Calendar issues" tabindex="-1">Calendar issues</h3></td><td><p>A dynamically generated calendar might generate links to future and previous dates with no restrictions on start or end dates. For example:</p><div></div><devsite-code no-copy="" data-copy-event-label="" no-toggle=""><pre class="" translate="no" dir="ltr" is-upgraded="">https://example.com/calendar.php?d=13&amp;m=8&amp;y=2011</pre></devsite-code><p>If your site has an infinite calendar, add a <code translate="no" dir="ltr"><a href="https://developers.google.com/search/docs/crawling-indexing/qualify-outbound-links#nofollow">nofollow</a></code> attribute to links to dynamically created future calendar pages.</p></td></tr><tr><td><h3 id="broken-relative-links" data-text="Broken relative links" tabindex="-1">Broken relative links</h3></td><td>Placing a <a href="https://developer.mozilla.org/en-US/docs/Web/API/URL_API/Resolving_relative_references#parent-directory_relative" class="external-link">parent-relative link</a> on the wrong page may create infinite spaces if your server doesn't respond with the right HTTP status code for nonexistent pages. For example, a parent-relative link such as <code translate="no" dir="ltr">&lt;a href=".<wbr>.<wbr>/<wbr>.<wbr>.<wbr>/<wbr>category/<wbr>stuff"&gt;.<wbr>.<wbr>.<wbr>&lt;/<wbr>a&gt;</code> on <code translate="no" dir="ltr">https:/<wbr>/<wbr>example.<wbr>com/<wbr>category/<wbr>community/<wbr>070413/<wbr>html/<wbr>FAQ.<wbr>htm</code> may lead to bogus URLs such as <code translate="no" dir="ltr">https:/<wbr>/<wbr>example.<wbr>com/<wbr>category/<wbr>community/<wbr>category/<wbr>stuff</code>. To fix, use root-relative URLs in your links (instead of parent-relative).</td></tr></tbody></table>

## Fixing crawling-related URL structure problems

If you notice that Google Search is crawling these problematic URLs, we recommend the following:

-   Consider using a [robots.txt file](https://developers.google.com/search/docs/crawling-indexing/robots/intro) to block Googlebot's access to [problematic URLs](https://developers.google.com/search/docs/crawling-indexing/url-structure#common-issues). Typically, consider blocking dynamic URLs, such as URLs that generate search results, or URLs that can create infinite spaces, such as calendars, and ordering and filtering functions.
-   If your site has faceted navigation, learn how to [manage crawling of those faceted navigation URLs](https://developers.google.com/search/docs/crawling-indexing/crawling-managing-faceted-navigation#prevent-crawling-of-faceted-navigation-urls).

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

Last updated 2026-10-21 UTC.

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

# To slash or not to slash  |  Google Search Central Blog  |  Google for Developers

<https://developers.google.com/search/blog/2010/04/to-slash-or-not-to-slash>

[Skip to main content](https://developers.google.com/search/blog/2010/04/to-slash-or-not-to-slash#main-content)

developers.google.com uses cookies to deliver and enhance the quality of its services and to analyze traffic. If you agree, cookies are also used to serve advertising and to personalize the content and advertisements that you see. [Learn more](https://policies.google.com/technologies/cookies?hl=en)

-   [Search Central](https://developers.google.com/search)

[Documentation](https://developers.google.com/search/docs) [Support](https://developers.google.com/search/help) [Blog](https://developers.google.com/search/blog) [What's new](https://developers.google.com/search/news) [Events](https://developers.google.com/search/events) [Case studies](https://developers.google.com/search/case-studies)

/

-   [Google Search Central Blog](https://developers.google.com/search/blog)

-   [Recent blog posts](https://developers.google.com/search/blog)
-   [About us](https://developers.google.com/search/blog/authors)
-   Archive
    
    -   2026
        
    -   2025
        
    -   2024
        
    -   2023
        
    -   2022
        
    -   2021
        
    -   2020
        
    -   2019
        
    -   2018
        
    -   2017
        
    -   2016
        
    -   2015
        
    -   2014
        
    -   2013
        
    -   2012
        
    -   2011
        
    -   2010
        
        -   December
            
        -   November
            
        -   October
            
        -   September
            
        -   August
            
        -   July
            
        -   June
            
        -   May
            
        -   April
            
            -   [Rich snippets go international](https://developers.google.com/search/blog/2010/04/rich-snippets-go-international)
            -   [To slash or not to slash](https://developers.google.com/search/blog/2010/04/to-slash-or-not-to-slash)
            -   [URL removal explained, Part III: Removing content that you don't own](https://developers.google.com/search/blog/2010/04/url-removal-explained-part-iii-removing)
            -   [Help Google index your videos](https://developers.google.com/search/blog/2010/04/help-google-index-your-videos)
            -   [Updated malware feature in Webmaster Tools](https://developers.google.com/search/blog/2010/04/updated-malware-feature-in-webmaster)
            -   [Webmasters - configure Google services at your hosting panel](https://developers.google.com/search/blog/2010/04/webmasters-configure-google-services-at)
            -   [More data and charts in Top Search Queries](https://developers.google.com/search/blog/2010/04/more-data-and-charts-in-top-search)
            -   [Better recipes on the web: Introducing recipe rich snippets](https://developers.google.com/search/blog/2010/04/better-recipes-on-web-introducing)
            -   [Using site speed in web search ranking](https://developers.google.com/search/blog/2010/04/using-site-speed-in-web-search-ranking)
            -   [When and why was my site flagged for malware? Learn in near real-time!](https://developers.google.com/search/blog/2010/04/when-and-why-was-my-site-flagged-for)
            -   [Adding Images to your Sitemaps](https://developers.google.com/search/blog/2010/04/adding-images-to-your-sitemaps)
            -   [URL removals explained, part II: Removing sensitive text from a page](https://developers.google.com/search/blog/2010/04/url-removals-explained-part-ii-removing)
            -   [A word on site clinics](https://developers.google.com/search/blog/2010/04/word-on-site-clinics)
            -   [Searching a little easier](https://developers.google.com/search/blog/2010/04/las-busquedas-se-vuelven-un-poco-mas)
            -   [Video: Mobile websites](https://developers.google.com/search/blog/2010/04/respuestas-en-video-sitios-web-para)
            -   [Matt Cutts video: Is speed more important than relevance?](https://developers.google.com/search/blog/2010/04/videos-de-matt-cutts-es-la-velocidad)
            -   [Matt Cutts video: Should I include my logo text using alt or CSS?](https://developers.google.com/search/blog/2010/04/debo-incluir-el-texto-de-mi-logo)
            -   [Google Grants site clinic: content is king](https://developers.google.com/search/blog/2010/04/google-grants-site-clinic-content-is)
            -   [Does PageRank from Twitter profiles play a role?](https://developers.google.com/search/blog/2010/04/spielt-der-pagerank-von-twitter)
            
        -   March
            
        -   February
            
        -   January
            
        
    -   2009
        
    -   2008
        
    -   2007
        
    -   2006
        
    -   2005
        
    
-   By author
    
-   More resources
    
-   [Subscribe to our RSS feed](https://feeds.feedburner.com/blogspot/amDG)
-   [Follow us on X](https://twitter.com/intent/follow?&screen_name=googlesearchc)
-   [Subscribe to our YouTube Channel](https://www.youtube.com/channel/UCWf2ZlNsCGDS89VBF_awNvA?sub_confirmation=1)

-   [Home](https://developers.google.com/)
-   [Search Central](https://developers.google.com/search)
-   [Google Search Central Blog](https://developers.google.com/search/blog)

# To slash or not to slash

-   On this page
-   [Different content on slash and non-slash URLs is okay for Google, but often is less ideal for users](https://developers.google.com/search/blog/2010/04/to-slash-or-not-to-slash#different-content-on-slash-and-non-slash-urls-is-okay-for-google,-but-often-is-less-ideal-for-users)
-   [Your site's configuration and your options](https://developers.google.com/search/blog/2010/04/to-slash-or-not-to-slash#your-sites-configuration-and-your-options)
-   [Steps for serving only one URL version](https://developers.google.com/search/blog/2010/04/to-slash-or-not-to-slash#steps-for-serving-only-one-url-version)

Wednesday, April 21, 2010

That is the question we hear often. Onward to the answers! Historically, it's common for URLs with a trailing slash to indicate a directory, and those without a trailing slash to denote a file:

https://example.com/foo/ (with trailing slash, conventionally a directory)
https://example.com/foo (without trailing slash, conventionally a file)

But they certainly don't have to. Google treats each URL above separately (and equally) regardless of whether it's a file or a directory, or it contains a trailing slash or it doesn't contain a trailing slash.

## Different content on slash and non-slash URLs is okay for Google, but often is less ideal for users

From a technical, search engine standpoint, it's certainly permissible for these two URL versions to contain different content. Your users, however, may find this configuration horribly confusing—just imagine if `www.google.com/webmasters` and `www.google.com/webmasters/` produced two separate experiences.

For this reason, trailing slash and non-trailing slash URLs often serve the same content. The most common case is when a site is configured with a directory structure:

https://example.com/parent-directory/child-directory/

## Your site's configuration and your options

You can do a quick check on your site to see if either of the URLs matching this pattern [redirects](https://developers.google.com/search/docs/crawling-indexing/301-redirects) to the other:

1.  `https://example.com/foo/`  
    (with trailing slash)
2.  `https://example.com/foo`  
    (no trailing slash)

-   If only one version can be returned (that is, the other redirects to it), that's great! This behavior is beneficial because it reduces [duplicate content](https://developers.google.com/search/docs/advanced/guidelines/duplicate-content). In the particular case of redirects to trailing slash URLs, our search results will likely show the version of the URL with the [`200` response code](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes) (most often the trailing slash URL)—regardless of whether the redirect was a `301` or `302`.
-   If both slash and non-trailing-slash versions contain the same content and each returns `200`, you can:
    -   Consider changing this behavior (more info below) to reduce duplicate content and improve [crawl efficiency](https://developers.google.com/search/blog/2009/08/optimize-your-crawling-indexing).
    -   Leave it as-is. Many sites have duplicate content. Our indexing process often handles this case for webmasters and users. While it's not totally optimal behavior, it's perfectly legitimate and a-okay. :)
    -   Rest assured that for your root URL specifically, `https://example.com` is equivalent to `https://example.com/` and can't be redirected even if you're Chuck Norris.

## Steps for serving only one URL version

What if your site serves duplicate content on these two URLs:

https://example.com/foo/
https://example.com/foo

Meaning that both URLs return `200` (neither has a redirect or contains [`rel="canonical"` link tag](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls) ), and you want to change the situation?

1.  Choose one URL as the preferred version. If your site has a directory structure, it's more conventional to use a trailing slash with your directory URLs (for example, `example.com/directory/` rather than `example.com/directory`), but you can choose whichever you like.
2.  Be consistent with the preferred version. Use it in your internal links. If you have a [sitemap](https://developers.google.com/search/docs/crawling-indexing/sitemaps/overview), include the preferred version (and don't include the duplicate URL).
3.  Use a `301` redirect from the duplicate to the preferred version. If that's not possible, the `rel="canonical"` link tag is a strong option. `rel="canonical"` works similarly to a `301` for Google's indexing purposes, and other major search engines as well.
4.  Test your `301` configuration through [Fetch as Googlebot](https://support.google.com/webmasters/answer/9128668) in [Webmaster Tools](https://search.google.com/search-console). Make sure your URLs, `https://example.com/foo/` and `https://example.com/foo`, are behaving as expected. The preferred version should return a `200` status code. The duplicate URL should `301` redirect to the preferred URL.
5.  Check for [Crawl errors](https://support.google.com/webmasters/answer/9679690) in Webmaster Tools, and, if possible, your webserver logs as a quick check that the `301` redirects are implemented.
6.  Profit! (just kidding) But you can bask in the sunshine of your efficient server configuration, warmed by the knowledge that your site is better optimized.

Written by [Maile Ohye](https://developers.google.com/search/blog/authors/maile-ohye), Developer Programs Tech Lead

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

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

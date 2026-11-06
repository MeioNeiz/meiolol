# Content compression · Cloudflare Speed docs

<https://developers.cloudflare.com/speed/optimization/content/compression/>

[Skip to content](https://developers.cloudflare.com/speed/optimization/content/compression/#main-content)

> Documentation Index  
> Fetch the complete documentation index at: https://developers.cloudflare.com/speed/llms.txt  
> Use this file to discover all available pages before exploring further.

[Docs](https://developers.cloudflare.com/)

[Directory](https://developers.cloudflare.com/directory/)[API](https://developers.cloudflare.com/api/)[SDKs](https://developers.cloudflare.com/fundamentals/api/reference/sdks/)[Changelog](https://developers.cloudflare.com/changelog/)

[Log in](https://dash.cloudflare.com/)

[Speed](https://developers.cloudflare.com/speed/)

/

-   [Overview](https://developers.cloudflare.com/speed/)
-   -   [Overview](https://developers.cloudflare.com/speed/observatory/)
    -   [Observatory dashboard](https://developers.cloudflare.com/speed/observatory/dashboard/)
    -   [Run test](https://developers.cloudflare.com/speed/observatory/run-speed-test/)
    -   [Understand test results](https://developers.cloudflare.com/speed/observatory/test-results/)
    -   [RUM beacon for Web Analytics](https://developers.cloudflare.com/speed/observatory/rum-beacon/)
    -   [FAQ](https://developers.cloudflare.com/speed/observatory/faq/)
    
-   [Origin Analytics](https://developers.cloudflare.com/speed/origin-analytics/)
-   -   [Recommendations](https://developers.cloudflare.com/speed/optimization/recommendations/)
    -   [Measurement](https://developers.cloudflare.com/speed/optimization/measurement/)
    -   -   [Image Resizing ↗︎](https://developers.cloudflare.com/images/optimization/transformations/overview/)
        -   [Polish ↗︎](https://developers.cloudflare.com/images/polish/)
        -   [MirageDeprecated](https://developers.cloudflare.com/speed/optimization/images/mirage/)
        -   -   [Image optimization on optimized images](https://developers.cloudflare.com/speed/optimization/images/troubleshooting/multiple-optimizations/)
            -   [Polish statuses ↗︎](https://developers.cloudflare.com/images/polish/cf-polished-statuses/)
            -   [Troubleshoot missing images](https://developers.cloudflare.com/speed/optimization/images/troubleshooting/troubleshooting-missing-images/)
            
        
    -   -   [Automatic Platform Optimization ↗︎](https://developers.cloudflare.com/automatic-platform-optimization/)
        -   [Content compression](https://developers.cloudflare.com/speed/optimization/content/compression/)
        -   [Shared dictionariesBeta](https://developers.cloudflare.com/speed/optimization/content/shared-dictionaries/)
        -   -   [Overview](https://developers.cloudflare.com/speed/optimization/content/fonts/)
            -   [FAQ](https://developers.cloudflare.com/speed/optimization/content/fonts/faq/)
            -   [Troubleshooting](https://developers.cloudflare.com/speed/optimization/content/fonts/troubleshooting/)
            
        -   [Early Hints ↗︎](https://developers.cloudflare.com/cache/advanced-configuration/early-hints/)
        -   [Prefetch URLs](https://developers.cloudflare.com/speed/optimization/content/prefetch-urls/)
        -   -   [Overview](https://developers.cloudflare.com/speed/optimization/content/rocket-loader/)
            -   [Enable](https://developers.cloudflare.com/speed/optimization/content/rocket-loader/enable/)
            -   [Ignore JavaScripts](https://developers.cloudflare.com/speed/optimization/content/rocket-loader/ignore-javascripts/)
            
        -   [Smart Hints](https://blog.cloudflare.com/smart-hints/)
        -   [Speed BrainBeta](https://developers.cloudflare.com/speed/optimization/content/speed-brain/)
        -   -   [Content encoding issues](https://developers.cloudflare.com/speed/optimization/content/troubleshooting/content-encoding-issues/)
            -   [Turn off Auto Minify](https://developers.cloudflare.com/speed/optimization/content/troubleshooting/disable-auto-minify/)
            
        
    -   -   [HTTP/2](https://developers.cloudflare.com/speed/optimization/protocol/http2/)
        -   [HTTP/3 (with QUIC)](https://developers.cloudflare.com/speed/optimization/protocol/http3/)
        -   [Enhanced HTTP/2 Prioritization](https://developers.cloudflare.com/speed/optimization/protocol/enhanced-http2-prioritization/)
        -   [0-RTT Connection Resumption](https://developers.cloudflare.com/speed/optimization/protocol/0-rtt-connection-resumption/)
        -   -   [Enhanced HTTP/2 Prioritization negatively affects iOS/Safari devices](https://developers.cloudflare.com/speed/optimization/protocol/troubleshooting/enhanced-http2-prioritization-ios-safari/)
            -   [Troubleshoot protocol issues](https://developers.cloudflare.com/speed/optimization/protocol/troubleshooting/protocol-troubleshooting/)
            
        -   [HTTP/2 to Origin](https://developers.cloudflare.com/speed/optimization/protocol/http2-to-origin/)
        
    
-   [Smart Shield ↗︎](https://developers.cloudflare.com/smart-shield/)
-   [Troubleshooting](https://developers.cloudflare.com/speed/troubleshooting/)
-   [Aggregated Internet Measurement](https://developers.cloudflare.com/speed/aim/)
-   [Glossary](https://developers.cloudflare.com/speed/glossary/)
-   -   [Agent setup ↗︎](https://developers.cloudflare.com/agent-setup/)
    -   [Cloudflare Skills ↗︎](https://github.com/cloudflare/skills)
    -   [Code Mode MCP Server ↗︎](https://github.com/cloudflare/mcp)
    -   [Domain-specific MCP Servers ↗︎MCP](https://github.com/cloudflare/mcp-server-cloudflare)
    -   [Speed llms.txt ↗︎](https://developers.cloudflare.com/speed/llms.txt)
    -   [Speed llms-full.txt ↗︎](https://developers.cloudflare.com/speed/llms-full.txt)
    -   [Cloudflare Docs llms.txt ↗︎](https://developers.cloudflare.com/llms.txt)
    -   [Cloudflare Docs llms-full.txt ↗︎](https://developers.cloudflare.com/llms-full.txt)
    

1.  [Home](https://developers.cloudflare.com/)
2.  /[Speed](https://developers.cloudflare.com/speed/)
3.  /…
4.  /Content optimizations
5.  /Content compression

# Content compression

Last updated Apr 17, 2026||[View as Markdown](https://developers.cloudflare.com/speed/optimization/content/compression/index.md)|[Agent setup](https://developers.cloudflare.com/agent-setup/)

Cloudflare compresses content in two ways: between Cloudflare and your website visitors and between Cloudflare and your origin server.

## Compression between Cloudflare and website visitors

In addition to Cloudflare's [default caching behavior](https://developers.cloudflare.com/cache/concepts/default-cache-behavior/), Cloudflare supports Gzip, Brotli, and Zstandard compression when delivering content to website visitors.

Note

Customers can enable Zstandard compression through [Compression Rules](https://developers.cloudflare.com/rules/compression-rules/).

If supported by visitors' web browsers, Cloudflare will return Gzip, Brotli, or Zstandard-encoded responses for the following content types:

```
text/html
text/richtext
text/plain
text/css
text/x-script
text/x-component
text/x-java-source
text/x-markdown
application/javascript
application/x-javascript
text/javascript
text/js
image/x-icon
image/vnd.microsoft.icon
application/x-perl
application/x-httpd-cgi
text/xml
application/xml
application/rss+xml
application/vnd.api+json
application/x-protobuf
application/json
multipart/bag
multipart/mixed
application/xhtml+xml
font/ttf
font/otf
font/x-woff
image/svg+xml
application/vnd.ms-fontobject
application/ttf
application/x-ttf
application/otf
application/x-otf
application/truetype
application/opentype
application/x-opentype
application/font-woff
application/eot
application/font
application/font-sfnt
application/wasm
application/javascript-binast
application/manifest+json
application/ld+json
application/graphql+json
application/geo+json
```

Cloudflare's global network can deliver content to website visitors using Gzip compression, Brotli compression, Zstandard compression, or no compression, depending on:

-   The values visitors provide in the `accept-encoding` request header.
-   Your [Cloudflare plan](https://developers.cloudflare.com/speed/optimization/content/compression/#between-visitors-and-cloudflare).
-   Any configured [compression rule](https://developers.cloudflare.com/rules/compression-rules/) that matches incoming requests.

For responses with error status codes, Cloudflare will only compress responses if their error status code is `403` or `404`. For successful response status codes, Cloudflare will only compress responses if their status code is `200`. Responses with other status codes will not be compressed.

You can override Cloudflare's default compression behavior using [Compression Rules](https://developers.cloudflare.com/rules/compression-rules/).

Minimum response size for compression

Cloudflare will only apply compression to responses with a minimum size when sending them to website visitors:

-   For Gzip, responses must have a minimum size of 48 bytes.
-   For Brotli and Zstandard, responses must have a minimum size of 50 bytes.

Smaller responses will not be compressed, regardless of their content type.

### Content-Length header handling

When Cloudflare compresses a response sent to the website visitor, it may omit the `Content-Length` HTTP header to avoid delivering incorrect length information caused by dynamic transformations. To preserve the `Content-Length` header set by the origin server, add `cache-control: no-transform` to the origin server's response. This directive prevents Cloudflare from altering compression on responses, allowing the `Content-Length` header to pass through as-is. The `cache-control: no-transform` header must be set by the origin — it cannot be added in client requests.

* * *

## Content compression from origin servers to the Cloudflare network

When requesting content from your origin server, Cloudflare supports Brotli compression, Gzip compression, or no compression.

Compressed responses sent from the origin server

If your origin server responds to a Cloudflare request using Brotli/Gzip compression, we will keep the same compression in the response sent to the website visitor if:

-   You include a `content-encoding` header in your server response mentioning the compression being used (`br` or `gzip`).
-   The visitor browser (or client) supports the compression algorithm.
-   You do not enable Cloudflare features that change the response content (refer to [Notes about end-to-end compression](https://developers.cloudflare.com/speed/optimization/content/compression/#notes-about-end-to-end-compression) for details).

Cloudflare's reverse proxy can also convert between compressed formats and uncompressed formats. Cloudflare can receive content from your origin server with Brotli or Gzip compression and serve it to visitors uncompressed (or vice versa), independently of caching.

If you do not want a particular response from your origin to be encoded with Brotli/Gzip when delivered to website visitors, you can disable this by including a `cache-control: no-transform` HTTP header in the response from your origin web server.

Caution

Cloudflare will take into consideration the `accept-encoding` header value in website visitors' requests when sending responses to those visitors. However, when requesting content from your origin server, Cloudflare will send a different `Accept-Encoding` header, supporting Brotli and Gzip compression.

* * *

## Notes about end-to-end compression

### Content recompression due to dynamic transformations

Even when using the same compression algorithm end to end (between your origin server and Cloudflare, and between the Cloudflare global network and your website visitor), Cloudflare will need to decompress the response and compress it again if you enable any of the following settings for the request:

-   [Automatic HTTPS Rewrites](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/automatic-https-rewrites/)
-   [Cloudflare Fonts](https://developers.cloudflare.com/speed/optimization/content/fonts/)
-   [Email Address Obfuscation](https://developers.cloudflare.com/waf/tools/scrape-shield/email-address-obfuscation/)
-   [Polish](https://developers.cloudflare.com/images/polish/)
-   [Rocket Loader](https://developers.cloudflare.com/speed/optimization/content/rocket-loader/)
-   [JavaScript detections](https://developers.cloudflare.com/cloudflare-challenges/challenge-types/javascript-detections/)
-   [RUM](https://developers.cloudflare.com/speed/observatory/run-speed-test/#enable-real-user-monitoring-rum)

To disable these settings for specific URI paths, create a [configuration rule](https://developers.cloudflare.com/rules/configuration-rules/).

Note

Additionally, the [Replace insecure JS libraries](https://developers.cloudflare.com/waf/tools/replace-insecure-js-libraries/) setting also requires Cloudflare to decompress the response and compress it again. At this time, you cannot turn it off using Configuration Rules.

### Content-Length header

Cloudflare may remove the `Content-Length` HTTP header of responses delivered to website visitors. To ensure that the header is preserved, add a `cache-control: no-transform` HTTP header to the response at the origin server.

## Compression methods by plan

### Between visitors and Cloudflare

By default, Cloudflare uses the following compression methods for content delivery, depending on the zone plan. However, the actual compression applied may also depend on what the visitor's browser requests via the `accept-encoding` header.

-   Free Plan: Content is compressed by default using Zstandard.
-   Pro and Business Plans: Content is compressed by default using Brotli.
-   Enterprise Plan: Content is compressed by default using Gzip.

### Between Cloudflare and the origin server

On all plans, Cloudflare requests content from the origin server using the `accept-encoding: br, gzip` header. This means that Cloudflare asks the origin to send the content compressed using Brotli or Gzip, depending on which method the origin server supports.

[PreviousAutomatic Platform Optimization ↗︎](https://developers.cloudflare.com/automatic-platform-optimization/)[NextShared dictionaries](https://developers.cloudflare.com/speed/optimization/content/shared-dictionaries/)

## On this page

-   [Overview](https://developers.cloudflare.com/speed/optimization/content/compression/#_top)
-   [Compression between Cloudflare and website visitors](https://developers.cloudflare.com/speed/optimization/content/compression/#compression-between-cloudflare-and-website-visitors)
-   [Content-Length header handling](https://developers.cloudflare.com/speed/optimization/content/compression/#content-length-header-handling)
-   [Content compression from origin servers to the Cloudflare network](https://developers.cloudflare.com/speed/optimization/content/compression/#content-compression-from-origin-servers-to-the-cloudflare-network)
-   [Notes about end-to-end compression](https://developers.cloudflare.com/speed/optimization/content/compression/#notes-about-end-to-end-compression)
-   [Content recompression due to dynamic transformations](https://developers.cloudflare.com/speed/optimization/content/compression/#content-recompression-due-to-dynamic-transformations)
-   [Content-Length header](https://developers.cloudflare.com/speed/optimization/content/compression/#content-length-header)
-   [Compression methods by plan](https://developers.cloudflare.com/speed/optimization/content/compression/#compression-methods-by-plan)
-   [Between visitors and Cloudflare](https://developers.cloudflare.com/speed/optimization/content/compression/#between-visitors-and-cloudflare)
-   [Between Cloudflare and the origin server](https://developers.cloudflare.com/speed/optimization/content/compression/#between-cloudflare-and-the-origin-server)

[Edit page](https://github.com/cloudflare/cloudflare-docs/edit/production/src/content/docs/speed/optimization/content/compression.mdx)[Report issue](https://github.com/cloudflare/cloudflare-docs/issues/new/choose)

Getting started

[Plans](https://www.cloudflare.com/plans/)[Contact sales](https://www.cloudflare.com/resource/contact-enterprise-sales/)[Partners](https://www.cloudflare.com/partners/)[Find a partner](https://partnerlocator.cloudflare.com/dashboard)[Startups](https://www.cloudflare.com/startups/)[Under attack?](https://www.cloudflare.com/under-attack-hotline/)[Domain name search](https://domains.cloudflare.com/)

Company

[About](https://www.cloudflare.com/about/)[Careers](https://www.cloudflare.com/careers/)[Investors](https://cloudflare.net/)[Press](https://www.cloudflare.com/press/)[Press kit](https://www.cloudflare.com/press/press-kit/)[Global network](https://www.cloudflare.com/network/)

Public interest

[Project Galileo](https://www.cloudflare.com/galileo/)[Athenian Project](https://www.cloudflare.com/athenian/)[Cloudflare for Campaigns](https://www.cloudflare.com/campaigns/)[Project Fairshot](https://www.cloudflare.com/fair-shot/)[Impact/ESG](https://www.cloudflare.com/impact/)

Compliance

[Compliance resources](https://www.cloudflare.com/trust-hub/compliance-resources/)[Trust Hub](https://www.cloudflare.com/trust-hub/)[Data Protection](https://www.cloudflare.com/trust-hub/gdpr/)[Responsible AI](https://www.cloudflare.com/trust-hub/responsible-ai/)[Transparency report](https://www.cloudflare.com/transparency/)[Report abuse](https://www.cloudflare.com/trust-hub/abuse-approach/)

Resources

[App innovation report](https://www.cloudflare.com/resource/app-innovation-report/)[Cloudflare Radar](https://radar.cloudflare.com/)[Case studies](https://www.cloudflare.com/case-studies/)[Status](https://www.cloudflarestatus.com/)[Support](https://support.cloudflare.com/)[Events](https://www.cloudflare.com/events/)[Blog](https://blog.cloudflare.com/)

Developers

[Documentation](https://developers.cloudflare.com/)[Learning center](https://www.cloudflare.com/learning/)[Community](https://community.cloudflare.com/)

Solutions

[SSE and SASE platform](https://www.cloudflare.com/sase/)[Cloudflare AI Cloud](https://www.cloudflare.com/solutions/ai/)[AI Security](https://www.cloudflare.com/solutions/ai-security/)[Frontend Development Platform](https://www.cloudflare.com/solutions/frontends/)[Multi-Tenant Platform Development](https://www.cloudflare.com/solutions/platforms/)[Web Security Platform](https://www.cloudflare.com/solutions/security/)

© 2026 Cloudflare, Inc.

[Privacy policy](https://www.cloudflare.com/policies/privacy/)| [Report security issues](https://www.cloudflare.com/disclosure/)| [Terms of use](https://www.cloudflare.com/policies/terms/)| [Trademark](https://www.cloudflare.com/trademark/)

|

## Our site uses cookies

Like most websites, we use cookies to make our site work the way you expect it to, improve your experience on our site, analyze site usage, and assist in our marketing efforts. By choosing "Accept All Cookies", you agree to the storing of all categories of cookies on your device. If you wish to accept or reject some categories of cookies, please click “Cookie Preferences.”

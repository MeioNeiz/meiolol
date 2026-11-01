---
title: "More confident deployments thanks to Netlify Deploy Summaries | Netlify"
description: "Realize the speed, agility and performance of a scalable, composable web architecture with Netlify. Explore the composable web platform now!"
source: "https://www.netlify.com/blog/2018/09/05/more-confident-deployments-thanks-to-netlify-deploy-summaries/"
last_updated: "2026-11-01T12:39:01.000Z"
---
At Netlify, we strongly believe that a good developer experience can lead to the creation of a better user experience on your sites. That is one of the reasons that we strive to make the process of building and deploying your sites as pleasant as we can. Clarity and simplicity are key, and we continue to work on making those better and better in the Netlify admin UI.

That work never ends.

## A helping hand during your deployments

One way that we try to make your life easier during deployment and development is by relaying information back to you in the Deploy Logs. These logs already display all of the standard output which comes from running your build in our Continuous Deployment environment. But there are a few convenient Netlify-specific things that we’ve now added to the deploy logs:

-   Redirect rules
-   Custom header rules
-   Mixed content warnings

[Redirect rules](https://docs.netlify.com/routing/redirects/) and [Custom Header rules](https://docs.netlify.com/routing/headers/) are configurations that Netlify let you include in your code, which we then use to automatically configure the global CDN on your behalf. This is powerful, but can be hard to validate from within your own build. (Especially locally where, you don’t have [Netlify’s multicloud global CDN](https://www.netlify.com/blog/2018/05/14/how-netlify-migrated-to-a-fully-multi-cloud-infrastructure/) replicated and running!) Rather than expecting you to go hunting around your latest deployment to ensure that these rules have been correctly applied, we simplify things by reporting successful or failed configurations of these rules in your deploy logs.

[Mixed content warnings](https://developers.google.com/web/fundamentals/security/prevent-mixed-content/what-is-mixed-content) are also important for us to report to you in a timely way. We believe very strongly in the importance of security on the web and we recently made all [new sites use HTTPS by default](https://www.netlify.com/blog/2018/07/02/all-new-sites-on-netlify-are-https-by-default/) thanks to the free and automatic provision of digital certificates. We’d rather not have the browser report to you (or your users) if you have accidentally left some resources to be served explicitly over HTTP rather than HTTPS. That is why we automatically detect this for you during site compilation, and let you know via a warning in your build logs.

## Making the information more obvious

All of this additional information is very useful. But we wanted to make it far easier for you to see.

So now, in addition to a live-streamed Deploy Log for you to watch during a build (or review any time afterwards), we have introduced a [Deploy Summary](https://docs.netlify.com/configure-builds/overview/) to your dashboard.

These summaries are available at the top of each new site deploy, whether those sites use our automated [Continuous Deployment](https://docs.netlify.com/configure-builds/overview/) service, or the drag-and-drop simplicity of [Netlify Drop](https://app.netlify.com/drop).

We think that this small change will make it easier for you to keep the web secure, one web site at a time. And to be confident that your custom HTTP headers and redirect rules are all specified as intended. We hope you like it.

### Share

-   [X (fka Twitter) ](https://twitter.com/intent/tweet?text=More confident deployments thanks to Netlify Deploy Summaries&url=https://www.netlify.com/blog/2018/09/05/more-confident-deployments-thanks-to-netlify-deploy-summaries/)
-   [LinkedIn](https://www.linkedin.com/shareArticle?mini=true&url=https%3A%2F%2Fwww.netlify.com%2Fblog%2F2018%2F09%2F05%2Fmore-confident-deployments-thanks-to-netlify-deploy-summaries%2F)
-   [Facebook](https://www.facebook.com/sharer.php?u=https://www.netlify.com/blog/2018/09/05/more-confident-deployments-thanks-to-netlify-deploy-summaries/)
-   [Bluesky](https://bsky.app/intent/compose?text=More confident deployments thanks to Netlify Deploy Summaries+https://www.netlify.com/blog/2018/09/05/more-confident-deployments-thanks-to-netlify-deploy-summaries/)

* * *

### Tags

-   [Continuous Deployment](/blog/tags/continuous-deployment/)
-   [Netlify Drop](/blog/tags/netlify-drop/)
-   [HTTPS](/blog/tags/https/)
-   [Redirect rules](/blog/tags/redirect-rules/)
-   [Custom Header rules](/blog/tags/custom-header-rules/)

## Keep reading

![](/images/blog/edge-functions-firecracker-microvms.png)

News & Announcements September 29, 2026

[

### 5x faster Edge Functions: v8 isolates to Unikraft MicroVMs

](/blog/edge-functions-firecracker-microvms/)

-   Jake Champion
    
-   ![Profile picture of Aarthy Chandrasekhar](/images/people/aarthy-chandrasekhar.jpg)
    
    Aarthy Chandrasekhar
    
-   ![Profile picture of Ivan Zarea](/_astro/451968a8e873f95cf69c7edd78eb29a9035541eb-1024x1024_2wyTXf.webp)
    
    Ivan Zarea
    

![](/_astro/293b82c564c394853a3b9f6f7c4df278dd41846d-1200x675_1XQqSx.webp)

News & Announcements August 25, 2026

[

### Compete in OpenAI’s WebMCP Challenge with Netlify

](/blog/compete-openai-webmcp-challenge/)

-   ![Profile picture of Karthik Puvvada](/_astro/e5524d3c315ad5114e1d5300d8991bfe902916fe-192x192_qfdWJ.webp)
    
    Karthik Puvvada
    

## Recent posts

News & Announcements September 29, 2026

[

### 5x faster Edge Functions: v8 isolates to Unikraft MicroVMs

](/blog/edge-functions-firecracker-microvms/)

-   Jake Champion
    
-   ![Profile picture of Aarthy Chandrasekhar](/images/people/aarthy-chandrasekhar.jpg)
    
    Aarthy Chandrasekhar
    
-   ![Profile picture of Ivan Zarea](/_astro/451968a8e873f95cf69c7edd78eb29a9035541eb-1024x1024_2wyTXf.webp)
    
    Ivan Zarea
    

Opinions & Insights September 22, 2026

[

### How we built Git storage for millions of Netlify projects

](/blog/how-we-built-git-storage-for-millions/)

-   ![Profile picture of Philippe Serhal](/_astro/795792fe4d14648b1b96285e46426ed964b802d7-512x512_Z23ebKb.webp)
    
    Philippe Serhal
    

Tools & Services September 10, 2026

[

### Cursor Origin repositories build, preview, and deploy on Netlify

](/blog/cursor-origin-repositories-on-netlify/)

-   ![Profile picture of Gehrig Kunz](/_astro/b4e9f58d914d1334ea70d53ea55a1f26b26f1445-512x512_Z202edR.webp)
    
    Gehrig Kunz
    

![](/_astro/3f255b372fa958df35802666ee33b4609b2d71bd-1200x1586_nzSVh.webp)

### How do the best dev and marketing teams work together?

[Access the report](https://www.netlify.com/reports/2024-leadership-trend-report/access/)
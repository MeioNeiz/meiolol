# CSS Styles from unrelated pages and components are merged if they're using the same shared component · vercel/next.js · Discussion #70168 · GitHub

<https://github.com/vercel/next.js/discussions/70168?sort=old>

[Skip to content](https://github.com/vercel/next.js/discussions/70168?sort=old#start-of-content)

## Navigation Menu

-   -   Platform
        
        -   [GitHubRepository hosting, code review, and collaboration](https://github.com/platform)
        -   [CopilotAI coding agent for tasks, projects and automated work](https://github.com/features/copilot)
        
    -   Build & Ship
        
        -   [ActionsCI/CD and automation](https://github.com/features/actions)
        -   [Code QualityQuality analysis, fixes, and enforcement](https://github.com/features/code-quality)
        -   [CodespacesCloud development environments](https://github.com/features/codespaces)
        
    -   Secure
        
        -   [Code SecurityVulnerability detection and remediation](https://github.com/security/advanced-security/code-security)
        -   [Secret ProtectionSecret scanning and leak prevention](https://github.com/security/advanced-security/secret-protection)
        
    
    [All Features](https://github.com/features)
    
-   -   Learn
        
        -   [Documentation](https://docs.github.com/en)
        -   [Training](https://learn.github.com/skills)
        -   [Certifications](https://learn.github.com/credentials)
        
    -   Build
        
        -   [Build with Copilot](https://github.com/features/ai)
        -   [Customize Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-copilot-overview)
        -   [Integrations](https://github.com/marketplace)
        
    -   Explore
        
        -   [Trending repos](https://github.com/trending)
        -   [GitHub Sponsors](https://github.com/open-source/sponsors)
        -   [Events](https://github.com/resources/events)
        
    -   Changelog
        
        -   [ChangelogYour source for the latest features, improvements, and fixes across GitHub products, all in one place.](https://github.blog/changelog/)
        
    
-   -   By Stage
        
        -   [Enterprises](https://github.com/enterprise)
        -   [Team](https://github.com/team)
        -   [Startups](https://github.com/enterprise/startups)
        -   [Nonprofits](https://github.com/solutions/industry/nonprofits)
        
    -   By Industry
        
        -   [Healthcare](https://github.com/solutions/industry/healthcare)
        -   [Financial services](https://github.com/solutions/industry/financial-services)
        -   [Manufacturing](https://github.com/solutions/industry/manufacturing)
        -   [Government](https://github.com/solutions/industry/government)
        -   [See all industries](https://github.com/solutions/industry)
        
    -   Evaluate GitHub
        
        -   [Why GitHub](https://github.com/why-github)
        -   [Customer Stories](https://github.com/customer-stories)
        -   [Business insights](https://github.com/solutions/executive-insights)
        -   [Trust Center](https://github.com/trust-center)
        
    -   Add-ons
        
        -   [GitHub Advanced SecurityEnterprise-grade code security](https://github.com/security/advanced-security)
        -   [Copilot for businessEnterprise-grade AI features](https://github.com/features/copilot/copilot-business)
        -   [Premium SupportEnterprise-grade 24/7 support](https://github.com/enterprise/premium-support)
        
    
-   -   Learn & Connect
        
        -   [Documentation](https://docs.github.com/en)
        -   [Resource center](https://github.com/resources)
        -   [Blog](https://github.blog/)
        -   [Events & webinars](https://github.com/resources/events)
        -   [Community Forum](https://github.com/orgs/community/discussions)
        -   [Customer Stories](https://github.com/customer-stories)
        -   [Integrations](https://github.com/marketplace)
        
    -   Support
        
        -   [Customer support](https://help.github.com/)
        -   [Training](https://learn.github.com/skills)
        -   [GitHub Status](https://www.githubstatus.com/)
        
    -   Company
        
        -   [About](https://github.com/about)
        -   [Partners](https://github.com/partners)
        -   [Changelog](https://github.blog/changelog/)
        
    -   GitHub Universe
        
        -   [GitHub UniverseThe event for developers, by developers — talks, workshops, and what’s next for GitHub.](https://githubuniverse.com/)
        
    
-   [Pricing](https://github.com/pricing)

1.  [vercel](https://github.com/vercel)
2.  [next.js](https://github.com/vercel/next.js)

## Repository navigation

-   [Code](https://github.com/vercel/next.js)
-   [Issues1.1k (1.1k)](https://github.com/vercel/next.js/issues)
-   [Pull requests2.6k (2.6k)](https://github.com/vercel/next.js/pulls)
-   [Discussions](https://github.com/vercel/next.js/discussions)
-   [Actions](https://github.com/vercel/next.js/actions)
-   [Security and quality72 (72)](https://github.com/vercel/next.js/security)
-   [Insights](https://github.com/vercel/next.js/pulse)

[CSS Styles from unrelated pages and components are merged if they're using the same shared component](https://github.com/vercel/next.js/discussions/70168?sort=old#top) #70168

 [Obvio](https://github.com/Obvio)

Sep 15, 2024 · 5 comments · 23 replies

[Answered](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10680841) by [sokra](https://github.com/sokra "sokra") [Return to top](https://github.com/vercel/next.js/discussions/70168?sort=old#top)

## 

[

Obvio

](https://github.com/Obvio)[Sep 15, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussion-7196322)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body"><h3 dir="auto">Link to the code that reproduces this issue</h3><p dir="auto"><a href="https://github.com/Obvio/next-css-modules">https://github.com/Obvio/next-css-modules</a></p><h3 dir="auto">To Reproduce</h3><p dir="auto">This issue is similar to <a class="issue-link js-issue-link" data-error-text="Failed to load title" data-id="2252620661" data-permission-text="Title is private" data-url="https://github.com/vercel/next.js/issues/64773" data-hovercard-type="issue" data-hovercard-url="/vercel/next.js/issues/64773/hovercard" href="https://github.com/vercel/next.js/issues/64773" aria-keyshortcuts="Alt+ArrowUp">#64773</a>.</p><p dir="auto">To Reproduce</p><ol dir="auto"><li>build the app and start it (not reproducible in dev mode)</li><li>go to <a href="http://localhost:3000/" rel="nofollow">http://localhost:3000/</a></li><li>you should see the both .h1 from separate pages bundled into one css file.</li></ol><p dir="auto">Visit the site in <a href="https://next-css-modules.vercel.app/" rel="nofollow">https://next-css-modules.vercel.app/</a> looking at the console we see one that one of the css files includes all the "shapes" of .h1 even-though only one of them is called/used on the page.</p><p dir="auto">I have 2 pages that share the same component, each hast its own css module and the shared component also has its own css module.</p><p dir="auto">When the app is built and deployed in vercel (doesn't happen in localhost) the bundle generates a css file which includes all the places said shared component is called from with their page css.</p><p dir="auto"><a target="_blank" rel="noopener noreferrer" href="https://private-user-images.githubusercontent.com/300232/367566992-9fd4ba16-9687-49d5-9c96-064ed2859ef4.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii8zMDAyMzIvMzY3NTY2OTkyLTlmZDRiYTE2LTk2ODctNDlkNS05Yzk2LTA2NGVkMjg1OWVmNC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYxMDI5JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MTAyOVQxMzUyMDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1lZDQxNDdiYzY5ZTUwZTM5ZDY5MzRiMmQyYjViNTNhNzkzYjcxNTI1MDI2NTFkY2Y0YzQxYzQ0YmU5YTU4ZmNmJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZwbmcifQ.EJnNYKCy4Ff7sMyyjKW3GUkmmit53S4MfYHIcg5rRK8"><img src="https://private-user-images.githubusercontent.com/300232/367566992-9fd4ba16-9687-49d5-9c96-064ed2859ef4.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii8zMDAyMzIvMzY3NTY2OTkyLTlmZDRiYTE2LTk2ODctNDlkNS05Yzk2LTA2NGVkMjg1OWVmNC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYxMDI5JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MTAyOVQxMzUyMDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1lZDQxNDdiYzY5ZTUwZTM5ZDY5MzRiMmQyYjViNTNhNzkzYjcxNTI1MDI2NTFkY2Y0YzQxYzQ0YmU5YTU4ZmNmJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZwbmcifQ.EJnNYKCy4Ff7sMyyjKW3GUkmmit53S4MfYHIcg5rRK8" alt="Screenshot 2024-09-15 at 10 49 57" style="max-width: 100%;"></a></p><p dir="auto">This seem to go against the site's performance and in bigger scale causes pagespeed and lighthouse to not like (and punish) for the increased bundle size.</p><h3 dir="auto">Current vs. Expected behavior</h3><p dir="auto">Currently the generated css files in the bundle "merge" all into one file.<br>I would expect the generated css pages in the bundle to only include the css relevant to the current page.</p><h3 dir="auto">Provide environment information</h3><div class="highlight highlight-source-shell notranslate position-relative overflow-auto" dir="auto"><pre class="notranslate">Operating System:
  Platform: darwin
  Arch: x64
  Version: Darwin Kernel Version 23.6.0: Mon Jul 29 21:13:00 PDT 2024<span class="pl-k">;</span> root:xnu-10063.141.2~1/RELEASE_X86_64
  Available memory (MB): 32768
  Available CPU cores: 12
Binaries:
  Node: 21.1.0
  npm: 10.2.0
  Yarn: 1.22.19
  pnpm: 7.26.2
Relevant Packages:
  next: 15.0.0-canary.156 // Latest available version is detected (15.0.0-canary.156).
  eslint-config-next: 15.0.0-canary.156
  react: 19.0.0-rc-206df66e-20240912
  react-dom: 19.0.0-rc-206df66e-20240912
  typescript: 5.6.2
Next.js Config:
  output: N/A</pre><div class="zeroclipboard-container position-absolute right-0 top-0"><clipboard-copy aria-label="Copy code to clipboard" class="ClipboardButton btn js-clipboard-copy m-2 p-0" data-copy-feedback="Copied!" data-tooltip-direction="w" value="Operating System:
  Platform: darwin
  Arch: x64
  Version: Darwin Kernel Version 23.6.0: Mon Jul 29 21:13:00 PDT 2024; root:xnu-10063.141.2~1/RELEASE_X86_64
  Available memory (MB): 32768
  Available CPU cores: 12
Binaries:
  Node: 21.1.0
  npm: 10.2.0
  Yarn: 1.22.19
  pnpm: 7.26.2
Relevant Packages:
  next: 15.0.0-canary.156 // Latest available version is detected (15.0.0-canary.156).
  eslint-config-next: 15.0.0-canary.156
  react: 19.0.0-rc-206df66e-20240912
  react-dom: 19.0.0-rc-206df66e-20240912
  typescript: 5.6.2
Next.js Config:
  output: N/A" tabindex="0" role="button"></clipboard-copy></div></div><h3 dir="auto">Which area(s) are affected? (Select all that apply)</h3><p dir="auto">Not sure</p><h3 dir="auto">Which stage(s) are affected? (Select all that apply)</h3><p dir="auto">next build (local)</p><h3 dir="auto">Additional context</h3><p dir="auto">14.1.4 : OK<br>14.2.5 : BROKEN<br>15-canary: BROKEN</p></td></tr></tbody></table>

Answered by [sokra](https://github.com/sokra) [Sep 18, 2024](https://github.com/vercel/next.js/discussions/70168#discussioncomment-10680841)

Even with CSS Modules order matters in same cases. E. g. when applying styles from two different CSS modules to the same element:

```js
import stylesA from "./a.module.css";
import stylesB from "./b.module.css";

<div className={stylesA + " " + stylesB}>
```

This often happens with components that allow to pass a `className` prop.

> On a personal opinion - I feel site visitors are more inclined to stay on the site (not bounce) if the first experience is super fast (the rest of the site's css can be lazyloaded).

Agree. We usually optimize with the focus on initial page load, but here we have to make trade-offs for correctness.

There is an alternative approach for CSS we experimented with for Turbopack…

[View full answer](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10680841)

## Replies: 5 comments · 23 replies

-   [Oldest](https://github.com/vercel/next.js/discussions/70168?sort=old)
-   [Newest](https://github.com/vercel/next.js/discussions/70168?sort=new)
-   [Top](https://github.com/vercel/next.js/discussions/70168?sort=top)

### 

[

samcx

](https://github.com/samcx)[Sep 16, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10664862)

Collaborator

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body"><p dir="auto"><a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/Obvio/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/Obvio" aria-keyshortcuts="Alt+ArrowUp">@Obvio</a> The behavior was changed here → <a class="issue-link js-issue-link" data-error-text="Failed to load title" data-id="2180316250" data-permission-text="Title is private" data-url="https://github.com/vercel/next.js/issues/63157" data-hovercard-type="pull_request" data-hovercard-url="/vercel/next.js/pull/63157/hovercard" href="https://github.com/vercel/next.js/pull/63157" aria-keyshortcuts="Alt+ArrowUp">#63157</a>. This is the expected behavior.</p><blockquote><p dir="auto">This seem to go against the site's performance and in bigger scale causes pagespeed and lighthouse to not like (and punish) for the increased bundle size.</p></blockquote><p dir="auto">The other side of this to consider is that more requests will also punish site performance.</p><p dir="auto"><a href="https://github.com/vercel/next.js/blob/canary/packages/next/src/build/webpack/plugins/css-chunking-plugin.ts">https://github.com/vercel/next.js/blob/canary/packages/next/src/build/webpack/plugins/css-chunking-plugin.ts</a> → I believe essentially what we do is we merge until a chunk is too large, then we split it is as needed.</p></td></tr></tbody></table>

5 replies

#### 

[Obvio](https://github.com/Obvio) [Sep 17, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10667923)

Author

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto"><a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/samcx/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/samcx" aria-keyshortcuts="Alt+ArrowUp">@samcx</a> I appreciate the time you took to review this issue, this is not taken for granted, thank you!</p><p dir="auto">I also understand what is the point that you're making, however i'd like to offer a third approach - which is in between the original behaviour and the changed behaviour - I don't want to have more requests per page, what I want is to have exactly 2 requests which only contain the CSS which is relevant to the current page: a layout.css and page.css (or an additional call in case something is laze loaded dynamically).</p><p dir="auto">My suggestion is based on what actually happens when you run <code class="notranslate">npm run dev</code>- the generated files from css modules only have the required page styles (you can run it yourself from my repo) but here are screenshots of the generated css files:</p><p dir="auto"><a target="_blank" rel="noopener noreferrer" href="https://private-user-images.githubusercontent.com/300232/368072365-cdaaf7df-8f1b-46cd-8800-3da0dbe1d9c2.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii8zMDAyMzIvMzY4MDcyMzY1LWNkYWFmN2RmLThmMWItNDZjZC04ODAwLTNkYTBkYmUxZDljMi5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYxMDI5JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MTAyOVQxMzUyMDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0xMzI1MmY4YWIzOWE3N2VjZWExZWI4MGZmNDMxNTRiODg5YjBmZGNmMDVmOTVhZGU2NWQwOTY1ZTRkZmU5NGM0JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZwbmcifQ.kCMWCeutq-nVxEHAf25_H65wLQ8-encJl1SaW3WLDEk"><img src="https://private-user-images.githubusercontent.com/300232/368072365-cdaaf7df-8f1b-46cd-8800-3da0dbe1d9c2.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii8zMDAyMzIvMzY4MDcyMzY1LWNkYWFmN2RmLThmMWItNDZjZC04ODAwLTNkYTBkYmUxZDljMi5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYxMDI5JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MTAyOVQxMzUyMDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0xMzI1MmY4YWIzOWE3N2VjZWExZWI4MGZmNDMxNTRiODg5YjBmZGNmMDVmOTVhZGU2NWQwOTY1ZTRkZmU5NGM0JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZwbmcifQ.kCMWCeutq-nVxEHAf25_H65wLQ8-encJl1SaW3WLDEk" alt="Screenshot 2024-09-17 at 11 03 43" style="max-width: 100%;"></a></p><p dir="auto"><a target="_blank" rel="noopener noreferrer" href="https://private-user-images.githubusercontent.com/300232/368072392-ec0f7885-ba95-43cd-a4ce-ec998daca99e.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii8zMDAyMzIvMzY4MDcyMzkyLWVjMGY3ODg1LWJhOTUtNDNjZC1hNGNlLWVjOTk4ZGFjYTk5ZS5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYxMDI5JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MTAyOVQxMzUyMDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0xZDQwZjIxYTMwYzdiOGU4MzVmNmZjMTllM2VlMmMzNTMzODAyYjA4Y2JkZTQ4YjVhNTBlYzQ2OGYwOGE0MmYwJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZwbmcifQ.Kfw43VYVEJVYHzCHzB02zbE-r4Z61YKt6vAAmI9ecLc"><img src="https://private-user-images.githubusercontent.com/300232/368072392-ec0f7885-ba95-43cd-a4ce-ec998daca99e.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii8zMDAyMzIvMzY4MDcyMzkyLWVjMGY3ODg1LWJhOTUtNDNjZC1hNGNlLWVjOTk4ZGFjYTk5ZS5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYxMDI5JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MTAyOVQxMzUyMDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0xZDQwZjIxYTMwYzdiOGU4MzVmNmZjMTllM2VlMmMzNTMzODAyYjA4Y2JkZTQ4YjVhNTBlYzQ2OGYwOGE0MmYwJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZwbmcifQ.Kfw43VYVEJVYHzCHzB02zbE-r4Z61YKt6vAAmI9ecLc" alt="Screenshot 2024-09-17 at 11 03 32" style="max-width: 100%;"></a></p><p dir="auto">I think this has many benefits over the current approach:</p><ol dir="auto"><li>Builds are predictable and deterministic (at least on the css level) - people can easily optimize important and specific routes.</li><li>The traffic (bandwidth) is smaller (also a Vercel benefit!) - each page receives only what they need.</li><li>Sites load faster, underpowered devices get better User experience.</li><li>SEO/pagespeed is improved.</li></ol><p dir="auto">Finally, I know we're talking about relatively small sizes (my site is super optimized) however they're still flagged by Pagespeed/Lighthouse report and I'm trying to save as much as I can on all fronts as there are features i can not remove (like monitoring etc.). Here's an example from a site I work on which led me to dig into this in the first place:</p><p dir="auto"><a target="_blank" rel="noopener noreferrer" href="https://private-user-images.githubusercontent.com/300232/368080146-709b4c75-e771-473e-a638-1560b9216854.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii8zMDAyMzIvMzY4MDgwMTQ2LTcwOWI0Yzc1LWU3NzEtNDczZS1hNjM4LTE1NjBiOTIxNjg1NC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYxMDI5JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MTAyOVQxMzUyMDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0xZDRlMjA4NjBkNmFkY2Y4MTU4YjUxMThlNTMwNTc3MmM0OThkNGFjMDFjY2I4MjhhYmU1ZmE0ZmQxZTU0OWE0JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZwbmcifQ.4LhfeO6qYC8dJN5aOs33YATud13OJrNdLpgKJ07MLtE"><img src="https://private-user-images.githubusercontent.com/300232/368080146-709b4c75-e771-473e-a638-1560b9216854.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii8zMDAyMzIvMzY4MDgwMTQ2LTcwOWI0Yzc1LWU3NzEtNDczZS1hNjM4LTE1NjBiOTIxNjg1NC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYxMDI5JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MTAyOVQxMzUyMDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0xZDRlMjA4NjBkNmFkY2Y4MTU4YjUxMThlNTMwNTc3MmM0OThkNGFjMDFjY2I4MjhhYmU1ZmE0ZmQxZTU0OWE0JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZwbmcifQ.4LhfeO6qYC8dJN5aOs33YATud13OJrNdLpgKJ07MLtE" alt="Screenshot 2024-09-17 at 11 18 37" style="max-width: 100%;"></a></p><p dir="auto">As a feature suggestion may allow for optin/optout of the current behaviour and also allow optin for preloading certain routes' css using some pragma a la "user client" like "use preload"..<br>Thank you!</p></td></tr></tbody></table>

#### 

[sokra](https://github.com/sokra) [Sep 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10678806)

Collaborator

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto">While your approach would work great for the initial visit, it does have problems with client side navigation between pages.</p><p dir="auto">In your repo this would require the inner wrapper CSS to be duplicated into page.css and other/page.css. Duplicating CSS is a red flag, because it breaks CSS order.</p><p dir="auto">In your repro page would require the page styles before the inner wrapper styles and other/page require inner wrapper styles before page styles. We must ensure that this order is correct in all scenarios.</p><p dir="auto">Assume we visit other/page first, which loads other/page.css and navigate to page via client side navigation, which loads page.css. Now other/page.css and page.css are loaded on the page. This means inner wrapper styles, other page styles, page styles and inner wrapper styles are active in that order. The second inner wrapper styles effectively override the first one so the styles are actually: other page styles, page styles, inner wrapper styles. This means the CSS order is violated for other page and navigating back to that page might show incorrect styling.</p><p dir="auto">In your repo it doesn't matter, as inner wrapper doesn't interact with the page styles but we can't assume that in general.</p></td></tr></tbody></table>

#### 

[Obvio](https://github.com/Obvio) [Sep 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10680320)

Author

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto"><a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/sokra/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/sokra" aria-keyshortcuts="Alt+ArrowUp">@sokra</a> Thank you for taking the time to answer. What I maybe I don't understand is how this scenario possible when css modules are used? I'm under the impression the generated class names are unique to the page they're called from, exactly as it is reproduced in my repo, so it's not really possible for styles/classnames to be overwritten (unless modules aren't used).</p><p dir="auto">On a personal opinion - I feel site visitors are more inclined to stay on the site (not bounce) if the first experience is super fast (the rest of the site's css can be lazyloaded).</p><p dir="auto">So, maybe as a feature suggestion if we can't bail out of this behaviour, it'd be nice to be bale to define the ax chunk size (the links above from <a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/samcx/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/samcx" aria-keyshortcuts="Alt+ArrowUp">@samcx</a> point to the change which suggest css chunks are at most 100kb)..</p><p dir="auto">Thanks again for looking into this. :)</p></td></tr></tbody></table>

#### 

[sokra](https://github.com/sokra) [Sep 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10680841)

Collaborator

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto">Even with CSS Modules order matters in same cases. E. g. when applying styles from two different CSS modules to the same element:</p><div class="highlight highlight-source-js notranslate position-relative overflow-auto" dir="auto"><pre class="notranslate"><span class="pl-k">import</span> <span class="pl-s1">stylesA</span> <span class="pl-k">from</span> <span class="pl-s">"./a.module.css"</span><span class="pl-kos">;</span>
<span class="pl-k">import</span> <span class="pl-s1">stylesB</span> <span class="pl-k">from</span> <span class="pl-s">"./b.module.css"</span><span class="pl-kos">;</span>

<span class="pl-c1">&lt;</span><span class="pl-s1">div</span> <span class="pl-c1">className</span><span class="pl-c1">=</span><span class="pl-kos">{</span><span class="pl-s1">stylesA</span> <span class="pl-c1">+</span> <span class="pl-s">" "</span> <span class="pl-c1">+</span> <span class="pl-s1">stylesB</span><span class="pl-kos">}</span><span class="pl-c1">&gt;</span></pre><div class="zeroclipboard-container position-absolute right-0 top-0"><clipboard-copy aria-label="Copy code to clipboard" class="ClipboardButton btn js-clipboard-copy m-2 p-0" data-copy-feedback="Copied!" data-tooltip-direction="w" value="import stylesA from &quot;./a.module.css&quot;;
import stylesB from &quot;./b.module.css&quot;;

&lt;div className={stylesA + &quot; &quot; + stylesB}&gt;" tabindex="0" role="button"></clipboard-copy></div></div><p dir="auto">This often happens with components that allow to pass a <code class="notranslate">className</code> prop.</p><blockquote><p dir="auto">On a personal opinion - I feel site visitors are more inclined to stay on the site (not bounce) if the first experience is super fast (the rest of the site's css can be lazyloaded).</p></blockquote><p dir="auto">Agree. We usually optimize with the focus on initial page load, but here we have to make trade-offs for correctness.</p><p dir="auto">There is an alternative approach for CSS we experimented with for Turbopack dev, which would keep the loaded modules in a runtime state and request different CSS bundles depending on what is already loaded, but it turned out that is a little bit harder due to the many ways of CSS being loaded (RSC, SSR, dynamic import) and state need to be maintained between them. Maybe that's an option for prod too, but not sure yet.</p><blockquote><p dir="auto">So, maybe as a feature suggestion if we can't bail out of this behaviour, it'd be nice to be bale to define the ax chunk size (the links above from <a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/samcx/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/samcx" aria-keyshortcuts="Alt+ArrowUp">@samcx</a> point to the change which suggest css chunks are at most 100kb)..</p></blockquote><p dir="auto">There two values here: 30kb and 100kb. Both applied on the unminimised css size.</p><p dir="auto">If a chunk would be smaller than 30kb, we merge it with another small chunk (usually from a different page) that has some overlap. The difference in size is usually not relevant for the initial page load performance (the request overhead is much bigger than the few extra bytes downloaded, compression is also more efficient on larger files), but it has a benefit if a user visits both pages (1 less request as that css is already loaded/cached). Often it even merges many small css files from a bunch of pages.</p><p dir="auto">If a chunk would be bigger than 100kb we split it into chunks that are smaller than 100kb. This allows both chunks to be cached independently, so a small change of the application won't invalidate a big 1MB chunk, but a smaller &lt;100kb chunk and the other chunks can stay cached.</p><p dir="auto">We apply similar numbers on JS chunking.</p><p dir="auto">Sounds fine to be to offer an option to change these numbers, but it's hard to measure the long term caching impact and compare that with the initial page load performance. So it's more number guessing. If you want to optimize for best initial page load you probably want to go with 0kb and ∞kb.</p></td></tr></tbody></table>

 

Answer selected by [Obvio](https://github.com/Obvio)

#### 

[Obvio](https://github.com/Obvio) [Sep 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10681218)

Author

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto">Thank you!</p></td></tr></tbody></table>

### 

[

joshwcomeau

](https://github.com/joshwcomeau)[Sep 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10682757)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body"><p dir="auto">Hey y'all!</p><p dir="auto">I recently migrated <a href="https://joshwcomeau.com/" rel="nofollow">my blog</a> to Next 15, and I believe this behaviour is causing a significant performance issue. Most pages have 20-40kb of unused CSS being loaded. My homepage, for example, loads 38kb of CSS but only uses 4kb:</p><p dir="auto"><a target="_blank" rel="noopener noreferrer" href="https://private-user-images.githubusercontent.com/6692932/368607257-37c15c09-d54a-4b2d-a522-5b31fa2de9ea.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii82NjkyOTMyLzM2ODYwNzI1Ny0zN2MxNWMwOS1kNTRhLTRiMmQtYTUyMi01YjMxZmEyZGU5ZWEucG5nP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MTAyOSUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjEwMjlUMTM1MjA1WiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9NDE3NTM4MTFjYWFhZmMzMTNhYTlkYjE0ZWEyZjYxZGJjZWU3MmVlNDkxMWM3YWEzMzJjYWRjMDZjYjZiOGQ0ZCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPWltYWdlJTJGcG5nIn0.tLsWELWomJP17bfl8UByE9DbkqsuvgsJAXSXLTsRFFM"><img src="https://private-user-images.githubusercontent.com/6692932/368607257-37c15c09-d54a-4b2d-a522-5b31fa2de9ea.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii82NjkyOTMyLzM2ODYwNzI1Ny0zN2MxNWMwOS1kNTRhLTRiMmQtYTUyMi01YjMxZmEyZGU5ZWEucG5nP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MTAyOSUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjEwMjlUMTM1MjA1WiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9NDE3NTM4MTFjYWFhZmMzMTNhYTlkYjE0ZWEyZjYxZGJjZWU3MmVlNDkxMWM3YWEzMzJjYWRjMDZjYjZiOGQ0ZCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPWltYWdlJTJGcG5nIn0.tLsWELWomJP17bfl8UByE9DbkqsuvgsJAXSXLTsRFFM" alt="Lighthouse report showing total CSS and unused CSS" style="max-width: 100%;"></a></p><p dir="auto">This is a problem since the CSS blocks rendering. It means the user spends longer staring at a blank white screen:</p><p dir="auto"><a target="_blank" rel="noopener noreferrer" href="https://private-user-images.githubusercontent.com/6692932/368606738-e66f33c2-ce2c-44d1-adf0-8d1dc5c04c3f.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii82NjkyOTMyLzM2ODYwNjczOC1lNjZmMzNjMi1jZTJjLTQ0ZDEtYWRmMC04ZDFkYzVjMDRjM2YucG5nP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MTAyOSUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjEwMjlUMTM1MjA1WiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9MDcwYWZhMGQ2NjM2ZmFmZjMxNGY3OWFkNGViODdkMTJhNzkzMmMyMzVmMmE5ZDdiYzg1OTE5YTQyNzc3YmMwNSZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPWltYWdlJTJGcG5nIn0.HnIDoIy7zLSJITVATolAj6E6eBk6VxPoSKWsTb9Zm9E"><img src="https://private-user-images.githubusercontent.com/6692932/368606738-e66f33c2-ce2c-44d1-adf0-8d1dc5c04c3f.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTMyODIyMjUsIm5iZiI6MTc5MzI4MTkyNSwicGF0aCI6Ii82NjkyOTMyLzM2ODYwNjczOC1lNjZmMzNjMi1jZTJjLTQ0ZDEtYWRmMC04ZDFkYzVjMDRjM2YucG5nP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MTAyOSUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjEwMjlUMTM1MjA1WiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9MDcwYWZhMGQ2NjM2ZmFmZjMxNGY3OWFkNGViODdkMTJhNzkzMmMyMzVmMmE5ZDdiYzg1OTE5YTQyNzc3YmMwNSZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPWltYWdlJTJGcG5nIn0.HnIDoIy7zLSJITVATolAj6E6eBk6VxPoSKWsTb9Zm9E" alt="Screenshot of a timeline showing several CSS files blocking render" style="max-width: 100%;"></a></p><p dir="auto">According to Lighthouse, the FCP has been pushed back by ~500ms on mobile, and I believe this change is responsible for the majority of that time (though I could be wrong). So it seems to me like a pretty significant regression.</p><p dir="auto">I understand <a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/sokra/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/sokra" aria-keyshortcuts="Alt+ArrowUp">@sokra</a>’s point, that out-of-order CSS is problematic and a significant challenge given the new architecture, but if I had to choose between the occasional selector issue and significantly worse initial load experience for all users, I would absolutely pick the former. I believe I <em>have</em> seen the out-of-order CSS issue in development, but it's rare, and easy enough to fix (I solve it by doubling up the selector when I see it happening and know one style should always be prioritized over the other).</p><p dir="auto">Hopefully this can be made into an config option. Otherwise, I think this fact needs to be published much more prominently, as it's important information for anyone trying to decide whether to migrate to App Router or not.</p></td></tr></tbody></table>

10 replies

#### 

[joshwcomeau](https://github.com/joshwcomeau) [Sep 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10686734)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto"><a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/samcx/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/samcx" aria-keyshortcuts="Alt+ArrowUp">@samcx</a> Ahh, I totally missed the "usually from a different page" line! That makes sense. Excited to give it a test!</p><p dir="auto">Thanks for the clarification 😄</p></td></tr></tbody></table>

 

#### 

[marko-hologram](https://github.com/marko-hologram) [Sep 25, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10749326)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><blockquote><p dir="auto">I believe I have seen the out-of-order CSS issue in development, but it's rare, and easy enough to fix (I solve it by doubling up the selector when I see it happening and know one style should always be prioritized over the other).</p></blockquote><p dir="auto">I rarely noticed this issue in development, but it would actually appear in production (although rarely as well). So development output wasn't equal to production output. This is what tripped me up few times because in development my styling would be applied a certain way and in production it would apply a different way. It doesn't happen because of CSS changes (as far as I know), it happens because of import order of components that I've used and those components imported CSS module files. So a seemingly unrelated change of importing a component somewhere or removing its import from somewhere would mess up CSS ordering and break things.</p><p dir="auto">Of course, if I perfectly encapsulated styling for a component it wouldn't happen. It would usually happen if I allowed passing className to a component and using it with existing CSS module styles the component has. Yes, doubling up the passed selector works, but it's a weird issue to debug when it happens because it's not obvious what happens, but passing className into a component is just sometimes so super convenient 😅</p><p dir="auto">I don't really have anything smart to say, but just wanted to say that this issue isn't an easy thing to debug and fix when it happens. Yeah when you know what's the issue it's super easy to address, but debugging it first time and finding a fix/workaround is a pain 😄</p></td></tr></tbody></table>

#### 

[joshwcomeau](https://github.com/joshwcomeau) [Sep 25, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10754623)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto">Yeah — I actually had my first instance yesterday of the <em>right</em> issues being applied in development, and the <em>wrong</em> ones in production. It feels like kind of a big problem to me that styles are applied in a different order between dev and prod.</p></td></tr></tbody></table>

#### 

[samcx](https://github.com/samcx) [Sep 25, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10756601)

Collaborator

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><blockquote><p dir="auto">It doesn't happen because of CSS changes (as far as I know), it happens because of import order of components that I've used and those components imported CSS module files. So a seemingly unrelated change of importing a component somewhere or removing its import from somewhere would mess up CSS ordering and break things.</p></blockquote><p dir="auto">The ordering of imports from components and stylesheets actually does matter—something I don't think is always completely clear → <a href="https://nextjs.org/docs/app/building-your-application/styling/css#ordering-and-merging" rel="nofollow">https://nextjs.org/docs/app/building-your-application/styling/css#ordering-and-merging</a>.</p><blockquote><p dir="auto">Yeah — I actually had my first instance yesterday of the right issues being applied in development, and the wrong ones in production.</p></blockquote><p dir="auto">The merging of CSS should be consistently different from development and production, but there should not be an issue with ordering, unless you are coming across this scenario (definitely looking to fix this!) → <a class="issue-link js-issue-link" data-error-text="Failed to load title" data-id="2284207696" data-permission-text="Title is private" data-url="https://github.com/vercel/next.js/issues/65480" data-hovercard-type="issue" data-hovercard-url="/vercel/next.js/issues/65480/hovercard" href="https://github.com/vercel/next.js/issues/65480" aria-keyshortcuts="Alt+ArrowUp">#65480</a>.</p></td></tr></tbody></table>

#### 

[marko-hologram](https://github.com/marko-hologram) [Sep 26, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10760035)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><blockquote><p dir="auto">The ordering of imports from components and stylesheets actually does matter</p></blockquote><p dir="auto">Yeah sorry I worded it a bit weirdly. I wanted to say, as a developer working on a project, you can change some component imports and your CSS would suddenly behave differently just because CSS was loaded in different order because of different order of imports now. So a seemingly unrelated change (you didn't touch any CSS code) impacts CSS. At least that's how it looked few times I've seen it happen.</p><p dir="auto">I understand this isn't an easy thing to solve (with everything mentioned above) and if I didn't pass in className from parent to child component (with same selector specificity level), I wouldn't have these issues. Only issue I have with this really is the different behavior between local development and production. My styles can work well in local development and things apply the way I want them to and then in production they behave differently.</p><p dir="auto">I was suspecting that locally the styles would work because fast refresh might inject them as latest styles into the DOM? So current CSS I'm working on actually gets injected last into the DOM so it applies the way I expect it to because of cascade it overrides previous CSS of same specificity, but then when built for production, it gets different ordering because it gets bundled somehow differently.</p><p dir="auto">So let's say I have this code:</p><p dir="auto">Parent.module.css</p><div class="highlight highlight-source-css notranslate position-relative overflow-auto" dir="auto"><pre class="notranslate">.<span class="pl-c1">componentParent</span> {
  <span class="pl-c1">margin-bottom</span><span class="pl-kos">:</span> <span class="pl-c1">10<span class="pl-smi">px</span></span>;
}</pre><div class="zeroclipboard-container position-absolute right-0 top-0"><clipboard-copy aria-label="Copy code to clipboard" class="ClipboardButton btn js-clipboard-copy m-2 p-0" data-copy-feedback="Copied!" data-tooltip-direction="w" value=".componentParent {
  margin-bottom: 10px;
}" tabindex="0" role="button"></clipboard-copy></div></div><p dir="auto">Child.module.css</p><div class="highlight highlight-source-css notranslate position-relative overflow-auto" dir="auto"><pre class="notranslate">.<span class="pl-c1">componentChild</span> {
  <span class="pl-c1">margin-bottom</span><span class="pl-kos">:</span> <span class="pl-c1">50<span class="pl-smi">px</span></span>;
}</pre><div class="zeroclipboard-container position-absolute right-0 top-0"><clipboard-copy aria-label="Copy code to clipboard" class="ClipboardButton btn js-clipboard-copy m-2 p-0" data-copy-feedback="Copied!" data-tooltip-direction="w" value=".componentChild {
  margin-bottom: 50px;
}" tabindex="0" role="button"></clipboard-copy></div></div><p dir="auto">Parent.tsx</p><div class="highlight highlight-source-tsx notranslate position-relative overflow-auto" dir="auto"><pre class="notranslate"><span class="pl-k">import</span> <span class="pl-v">Child</span> <span class="pl-k">from</span> <span class="pl-s">"./Child"</span><span class="pl-kos">;</span>
<span class="pl-k">import</span> <span class="pl-s1">styles</span> <span class="pl-k">from</span> <span class="pl-s">"./Parent.module.css"</span><span class="pl-kos">;</span>

<span class="pl-k">const</span> <span class="pl-v">Parent</span> <span class="pl-c1">=</span> <span class="pl-kos">(</span><span class="pl-kos">)</span> <span class="pl-c1">=&gt;</span> <span class="pl-kos">{</span>
  <span class="pl-k">return</span> <span class="pl-c1">&lt;</span><span class="pl-v">Child</span> <span class="pl-c1">className</span><span class="pl-c1">=</span><span class="pl-kos">{</span><span class="pl-s1">styles</span><span class="pl-kos">.</span><span class="pl-c1">componentParent</span><span class="pl-kos">}</span> <span class="pl-kos">/&gt;</span>
<span class="pl-kos">}</span></pre><div class="zeroclipboard-container position-absolute right-0 top-0"><clipboard-copy aria-label="Copy code to clipboard" class="ClipboardButton btn js-clipboard-copy m-2 p-0" data-copy-feedback="Copied!" data-tooltip-direction="w" value="import Child from &quot;./Child&quot;;
import styles from &quot;./Parent.module.css&quot;;

const Parent = () =&gt; {
  return &lt;Child className={styles.componentParent} /&gt;
}" tabindex="0" role="button"></clipboard-copy></div></div><p dir="auto">Child.tsx</p><div class="highlight highlight-source-tsx notranslate position-relative overflow-auto" dir="auto"><pre class="notranslate"><span class="pl-k">import</span> <span class="pl-s1">styles</span> <span class="pl-k">from</span> <span class="pl-s">"./Child.module.css"</span><span class="pl-kos">;</span>

<span class="pl-k">const</span> <span class="pl-v">Child</span> <span class="pl-c1">=</span> <span class="pl-kos">(</span><span class="pl-kos">{</span> className <span class="pl-kos">}</span><span class="pl-kos">)</span> <span class="pl-c1">=&gt;</span> <span class="pl-kos">{</span>
  <span class="pl-k">return</span> <span class="pl-c1">&lt;</span><span class="pl-s1">div</span> <span class="pl-c1">className</span><span class="pl-c1">=</span><span class="pl-kos">{</span><span class="pl-en">cx</span><span class="pl-kos">(</span><span class="pl-s1">styles</span><span class="pl-kos">.</span><span class="pl-c1">componentChild</span><span class="pl-kos">,</span> <span class="pl-s1">className</span><span class="pl-kos">)</span><span class="pl-kos">}</span><span class="pl-c1">&gt;</span>Child component<span class="pl-kos">&lt;/</span><span class="pl-s1">div</span><span class="pl-c1">&gt;</span>
<span class="pl-kos">}</span></pre><div class="zeroclipboard-container position-absolute right-0 top-0"><clipboard-copy aria-label="Copy code to clipboard" class="ClipboardButton btn js-clipboard-copy m-2 p-0" data-copy-feedback="Copied!" data-tooltip-direction="w" value="import styles from &quot;./Child.module.css&quot;;

const Child = ({ className }) =&gt; {
  return &lt;div className={cx(styles.componentChild, className)}&gt;Child component&lt;/div&gt;
}" tabindex="0" role="button"></clipboard-copy></div></div><p dir="auto">And now I edit <code class="notranslate">Parent.module.css</code> locally and everything works. During fast refresh all my changes get applied, but during production it might happen that <code class="notranslate">.componentParent</code> class gets overridden by <code class="notranslate">.componentChild</code> class, even though in local development it was the opposite.</p><p dir="auto">This is what tripped me up a few times. As I've said, I suspected that during local development last styles being saved get injected last (maybe?) and it all works, but for production it's a different thing. Of course it can be solved by using <code class="notranslate">.componentParent.componentParent {}</code> selector to make it more specific (or not pass className at all), but it's hard to know if you'll need it in advance when during development it all looks as you expect it to.</p><p dir="auto">Also, when I first ran into this issue these docs (<a href="https://nextjs.org/docs/app/building-your-application/styling/css#ordering-and-merging" rel="nofollow">https://nextjs.org/docs/app/building-your-application/styling/css#ordering-and-merging</a>) didn't exist as far as I know, so I had no documentation to reference and get an idea what's happening.</p><hr><p dir="auto">I don't really run into this issue anymore because I use Tailwind and tailwind-merge these days, but for projects that I still maintain that are using CSS Modules, this happens sometimes, but I try to avoid passing style overrides from parent in CSS Modules scenarios. Although it happens rarely, so I don't consider it that critical, it's just that it's unpredictable and hard to debug when you encounter it the for first time.</p></td></tr></tbody></table>

### 

[

samcx

](https://github.com/samcx)[Oct 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10984707)

Collaborator

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body"><p dir="auto">Related: <a class="issue-link js-issue-link" data-error-text="Failed to load title" data-id="2597355408" data-permission-text="Title is private" data-url="https://github.com/vercel/next.js/issues/71474" data-hovercard-type="issue" data-hovercard-url="/vercel/next.js/issues/71474/hovercard" href="https://github.com/vercel/next.js/issues/71474" aria-keyshortcuts="Alt+ArrowUp">#71474</a></p></td></tr></tbody></table>

5 replies

#### 

[joostmeijles](https://github.com/joostmeijles) [Oct 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10984745)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto"><a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/samcx/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/samcx" aria-keyshortcuts="Alt+ArrowUp">@samcx</a> thanks for your prompt reply!</p><p dir="auto">Is it expected behaviour (on v14) that CSS from other pages may be added in the generated &amp; loaded CSS file?</p></td></tr></tbody></table>

#### 

[samcx](https://github.com/samcx) [Oct 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10984793)

Collaborator

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto"><a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/joostmeijles/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/joostmeijles" aria-keyshortcuts="Alt+ArrowUp">@joostmeijles</a> Yes, this is expected in v14 (this <a href="https://github.com/vercel/next.js/pull/63157" data-hovercard-type="pull_request" data-hovercard-url="/vercel/next.js/pull/63157/hovercard" aria-keyshortcuts="Alt+ArrowUp">PR</a>). The reasons why are mentioned in this discussion. We're still looking at this (been somewhat busy with v15).</p><p dir="auto">Will circle back on this when we have an update!</p></td></tr></tbody></table>

#### 

[joostmeijles](https://github.com/joostmeijles) [Oct 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10984831)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto">Alright thanks!</p><p dir="auto">Please note that for our application, a large e-commerce website, many (and large) CSS files are being generated.<br>This breaks our Lighthouse performance scores, as it e.g. doubles LCP time from ~2 seconds to &gt;4 seconds on mobile.</p></td></tr></tbody></table>

#### 

[samcx](https://github.com/samcx) [Oct 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10984866)

Collaborator

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto"><a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/joostmeijles/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/joostmeijles" aria-keyshortcuts="Alt+ArrowUp">@joostmeijles</a> Are you also sharing a component(s) between the pages where the styles are being merged (the current visible page + unrelated page(s))?</p></td></tr></tbody></table>

#### 

[joostmeijles](https://github.com/joostmeijles) [Oct 18, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-10984892)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto">Yes, that's correct. We have quite some components that are shared, directly or indirectly, on various pages and layouts.</p></td></tr></tbody></table>

### 

[

samcx

](https://github.com/samcx)[Nov 28, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-11401010)

Collaborator

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body"><p dir="auto">Hey everyone!</p><p dir="auto">We recently shipped an experimental flag to disable the CSS Chunking Algorithm altogether → <a class="issue-link js-issue-link" data-error-text="Failed to load title" data-id="2699933560" data-permission-text="Title is private" data-url="https://github.com/vercel/next.js/issues/73286" data-hovercard-type="pull_request" data-hovercard-url="/vercel/next.js/pull/73286/hovercard" href="https://github.com/vercel/next.js/pull/73286" aria-keyshortcuts="Alt+ArrowUp">#73286</a>, which may help with this issue (does have tradeoffs to doing this).</p><p dir="auto">We also recently shipped an experimental flag to inline CSS → <a href="https://nextjs.org/docs/canary/app/api-reference/config/next-config-js/inlineCss" rel="nofollow">https://nextjs.org/docs/canary/app/api-reference/config/next-config-js/inlineCss</a>. More improvements to come with this flag, but this can definitely improve Lighthouse scores!</p></td></tr></tbody></table>

 

3 replies

#### 

[joshwcomeau](https://github.com/joshwcomeau) [Dec 30, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-11700157)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto">Inlining the CSS is a great idea! It was one of my favourite things about styled-components; no secondary round-trip to fetch a stylesheet, it all comes in the HTML.</p><p dir="auto">Thanks for keeping this issue in mind, and for working on solutions ❤️. Gonna test both of these options</p></td></tr></tbody></table>

#### 

[joshwcomeau](https://github.com/joshwcomeau) [Dec 31, 2024](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-11707794)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto">Just a quick note for anyone else seeing this: the linked PR adds a <code class="notranslate">"disabled"</code> option for <code class="notranslate">cssChunking</code>, but I think since then this was changed to a boolean value. Here’s the config that worked for me:</p><div class="highlight highlight-source-ts notranslate position-relative overflow-auto" dir="auto"><pre class="notranslate"><span class="pl-k">const</span> <span class="pl-s1">config</span> <span class="pl-c1">=</span> <span class="pl-kos">{</span>
  <span class="pl-c1">experimental</span>: <span class="pl-kos">{</span>
    <span class="pl-c1">cssChunking</span>: <span class="pl-c1">false</span><span class="pl-kos">,</span>
  <span class="pl-kos">}</span><span class="pl-kos">,</span>
<span class="pl-kos">}</span><span class="pl-kos">;</span></pre><div class="zeroclipboard-container position-absolute right-0 top-0"><clipboard-copy aria-label="Copy code to clipboard" class="ClipboardButton btn js-clipboard-copy m-2 p-0" data-copy-feedback="Copied!" data-tooltip-direction="w" value="const config = {
  experimental: {
    cssChunking: false,
  },
};" tabindex="0" role="button"></clipboard-copy></div></div></td></tr></tbody></table>

#### 

[samcx](https://github.com/samcx) [Jan 2, 2025](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-11720449)

Collaborator

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body tmp-px-3 pt-0 pb-2"><p dir="auto"><a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/joshwcomeau/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/joshwcomeau" aria-keyshortcuts="Alt+ArrowUp">@joshwcomeau</a> Agreed! There are still improvements/fixes to be made with CSS in App Router. Will keep ya'll updated!</p></td></tr></tbody></table>

### 

[

SurajPandey186

](https://github.com/SurajPandey186)[Nov 26, 2025](https://github.com/vercel/next.js/discussions/70168?sort=old#discussioncomment-15081274)

<table class="d-block" role="presentation" data-paste-markdown-skip=""><tbody class="d-block"><tr class="d-block"><td class="d-block color-fg-default comment-body markdown-body js-comment-body"><p dir="auto">Hi <a class="user-mention notranslate" data-hovercard-type="user" data-hovercard-url="/users/samcx/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self" href="https://github.com/samcx" aria-keyshortcuts="Alt+ArrowUp">@samcx</a> , Is there any approach to merge all the css or increase the chunks size so less file request goes,as in our case on initial load, 90 css request goes which impacts our FCP and Critical rendering path shows a delay of 2.5 ses</p><p dir="auto">Or Is there any way lik<br>Page 1<br>Import {Button} from 'moduleA'<br>Page 2<br>import {Button} from 'moduleA'</p><p dir="auto">Now to tell next each page, imports is unique<br>,hence now common component exits only respective page css loads, not the shared css</p><p dir="auto">Version of next 14.2.33</p></td></tr></tbody></table>

0 replies

[Sign up for free](https://github.com/join?source=comment-repo) **to join this conversation on GitHub**. Already have an account? [Sign in to comment](https://github.com/login?return_to=https%3A%2F%2Fgithub.com%2Fvercel%2Fnext.js%2Fdiscussions%2F70168%3Fsort%3Dold%3Fsort%3Dold)

Category

[

🎓

Help](https://github.com/vercel/next.js/discussions/categories/help)

Labels

[bug](https://github.com/vercel/next.js/discussions?discussions_q=label%3Abug)

7 participants

 

Converted from issue

This discussion was converted from issue [#70120](https://github.com/vercel/next.js/issues/70120) on September 16, 2024 23:33.

## Footer

© 2026 GitHub, Inc.

### Footer navigation

-   [Terms](https://docs.github.com/site-policy/github-terms/github-terms-of-service)
-   [Privacy](https://docs.github.com/site-policy/privacy-policies/github-privacy-statement)
-   [Security](https://github.com/security)
-   [Status](https://www.githubstatus.com/)
-   [Community](https://github.community/)
-   [Docs](https://docs.github.com/)
-   [Contact](https://support.github.com/?tags=dotcom-footer)
-   
-

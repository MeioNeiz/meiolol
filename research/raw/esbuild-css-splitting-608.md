# CSS + code splitting + multiple entry points · Issue #608 · evanw/esbuild

<https://github.com/evanw/esbuild/issues/608>

[Skip to content](https://github.com/evanw/esbuild/issues/608#start-of-content)

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

1.  [evanw](https://github.com/evanw)
2.  [esbuild](https://github.com/evanw/esbuild)

## Repository navigation

-   [Code](https://github.com/evanw/esbuild)
-   [Issues557 (557)](https://github.com/evanw/esbuild/issues)
-   [Pull requests81 (81)](https://github.com/evanw/esbuild/pulls)
-   [Actions](https://github.com/evanw/esbuild/actions)
-   [Security and quality3 (3)](https://github.com/evanw/esbuild/security)
-   [Insights](https://github.com/evanw/esbuild/pulse)

# CSS + code splitting + multiple entry points #608

[New issue](https://github.com/login?return_to=https://github.com/evanw/esbuild/issues/608)

Closed

[#1293](https://github.com/evanw/esbuild/pull/1293)

Closed

[CSS + code splitting + multiple entry points](https://github.com/evanw/esbuild/issues/608#top)#608

[#1293](https://github.com/evanw/esbuild/pull/1293)

## Description

[iamakulov](https://github.com/iamakulov)

opened [on Dec 17, 2020](https://github.com/evanw/esbuild/issues/608#issue-770441497)

### Background

Hey! Per the changelog, ESBuild doesn’t currently support code splitting with CSS:

> #### 0.7.7
> 
> Some things to keep in mind:
> 
> \[...\]
> 
> -   There is currently no support for code splitting of CSS. I haven't tested multiple entry-point scenarios yet and code splitting will require additional changes to the AST format.

Still, a) enabling `splitting: true` along with b) importing CSS files and c) having multiple entry points results in the following behavior:

-   ESBuild detects CSS code that’s used in multiple entrypoints
-   ESBuild code-splits that code into a common CSS chunk (`chunk.HASH.css`)
-   but: ESBuild doesn’t generate any code that makes the browser load these chunks

Which means that when you open the app, the common CSS code ends up simply missing.

### Question

I’m curious what’s your plan on supporting this scenario.

-   Do you plan to generate CSS `@import`s for code-split CSS chunks?
-   Do you plan to disable code-splitting for CSS at all?
-   Or do you have any other plans for this?

I’m asking this primarily because I’m helping Framer to migrate to ESBuild, and if I know the plan, it would be easier to pick the right workaround while the plan is being implemented!

Reacted by Matt Mulder

## Activity

1.  ### evanw commented on Dec 18, 2020
    
    [evanw](https://github.com/evanw)
    
    [on Dec 18, 2020](https://github.com/evanw/esbuild/issues/608#issuecomment-748078657)
    
    Owner
    
    My working plan so far is to generate CSS `@import`s for code-split CSS chunks. But I haven't researched what other tools do yet so I'm not sure what the current state of the art is. Certainly just disabling code-splitting for CSS would also work. I'd be interested to hear more information about your use case and what you're looking for if you have any thoughts.
    
    Reacted by Michael Villar
    
2.  ### techgems commented on Dec 22, 2020
    
    [techgems](https://github.com/techgems)
    
    [on Dec 22, 2020](https://github.com/evanw/esbuild/issues/608#issuecomment-749336084)
    
    Following, I would love to ditch webpack and those long long wait times per build, but we need CSS as a valid entrypoint to do that.
    
3.  ### michaelvillar commented on Jan 2, 2021
    
    [michaelvillar](https://github.com/michaelvillar)
    
    [on Jan 2, 2021](https://github.com/evanw/esbuild/issues/608#issuecomment-753425988)
    
    As a workaround for the time being, one way to use code splitting and CSS is to build twice:
    
    -   build with `splitting: true` and `loader.css: 'file'` → will output the js with chunks
    -   build with `splitting: false` → will output the css files (and extra js we can ignore)
    
    You can also output these two builds in two location and do them concurrently which is neat.
    
    Reacted by Jonas
    
    Reacted by Ivan Akulov and 吴泽康
    
4.  ### LukeSheard commented on Feb 5, 2021
    
    [LukeSheard](https://github.com/LukeSheard)
    
    [on Feb 5, 2021](https://github.com/evanw/esbuild/issues/608#issuecomment-774340059)
    
    Contributor
    
    [@evanw](https://github.com/evanw) I'd love to help out with this if possible - but a little lost as to how to get started. We're currently using the workaround [@michaelvillar](https://github.com/michaelvillar) suggested currently but isn't scaling as we build more applications at once.
    
    Reacted by Sunil Pai
    
5.  ### evanw commented on Feb 11, 2021
    
    [evanw](https://github.com/evanw)
    
    [on Feb 11, 2021](https://github.com/evanw/esbuild/issues/608#issuecomment-777388780)
    
    Owner
    
    > I'd love to help out with this if possible - but a little lost as to how to get started.
    
    The best way to help at this point would be to help me figure out the desired behavior. I'm not too familiar with the history and design space here or how other bundlers solve CSS ordering problems.
    
    CSS is order-dependent and I assume CSS order should be determined by a depth-first post-order traversal over the graph, including from JS files into the CSS files they import (ignoring top-level await). I also assume that it's not ok for the bundler to deviate from this order at all since that could result in visual changes, even if deviating from this order would make a smaller bundle.
    
    Some approaches to CSS code splitting that I can imagine:
    
    1.  Just generate a separate CSS file for each entry point without any code splitting or sharing. Common CSS would be duplicated across separate entry points. Mostly simple and straightforward.
        
        One decision point here would be what to do about dynamic JavaScript imports that reference CSS. They are sort of considered additional entry points, albeit not user-specified ones. I believe having those entry points re-specify any CSS in the importing entry point (at least by appending a `<style>` to the `<head>`) could potentially cause visual changes which is something to be avoided. So dynamic entry points can't be treated the same way as normal entry points.
        
        The simplest way to solve this is just for dynamic entry points to not have any associated CSS, and to bundle the CSS for all dynamic entry points into the CSS for the top-level entry point. Then there would only ever be a single CSS file per page which makes order easy to reason about.
        
        A less simple way to solve this would be to try to exclude any CSS in the top-level entry point from the dynamic entry point. But this seems kind of crazy because that dynamic entry point could be imported from several top-level entry points each with it's own subset of CSS, in which case you would be unable to share the dynamic entry point's CSS between top-level entry points.
        
        Perhaps there is another way this is usually solved too. Maybe the answer is for dynamic entry points to prepend their `<style>` to the `<head>` so that duplicates don't cause visual changes? I'm not sure if that could cause any issues.
        
    2.  Layout the CSS order for each entry point, then scan for common runs of CSS across these entry point layouts. Each contiguous run of CSS code that appears in more than one entry point layout would be a separate shared chunk that the root chunks reference with `@import`. This guarantees that there is no duplicate code across entry points and that the CSS order remains exactly the same. But there would potentially be a huge number of CSS chunks if there are a couple dozen entry points due to combinatorics, which I assume would be a non-starter for most people. Unfortunately CSS doesn't have any mechanism for abstraction so you can't have a "CSS library" with lazily-evaluated code that can be triggered later.
        
    3.  Do everything with JavaScript and do not generate any CSS files. CSS would be in JavaScript strings and `<style>` tags would be generated at run-time. Since JavaScript does have abstraction capabilities, CSS code could then be deferred until it can be assembled in the correct order. This has no duplication or ordering problems but I assume it would be slow because of JavaScript processing and because the browser can't download, parse, and interpret the CSS in parallel with the JavaScript.
        
    
    I'm currently considering doing option 1 (no code splitting for CSS).
    
6.  ### LukeSheard commented on Feb 17, 2021
    
    [LukeSheard](https://github.com/LukeSheard)
    
    [on Feb 17, 2021](https://github.com/evanw/esbuild/issues/608#issuecomment-780915492)
    
    Contributor
    
    I ended up landing on a workaround for the time being similar to another comment on the [MVP for CSS modules](https://github.com/evanw/esbuild/issues/20#issuecomment-779542787). I'll share the plugin I wrote shortly but it's on my work laptop and I can't extract it right now.
    
    Essentially I would go with something like (3) from above, but use the `file` loader which exists already to seperate files out into standalone chunks which can be loaded at runtime. For us this is working well as when we build ~300 files in one go the CSS files end up being shared across all the applications.
    
    The only issue that I don't have an answer for with this is preventing the everlasting issue of flashes of unstyled content, since the stylesheets are loaded asynchronously to the execution of the app. I'm not sure how other bundles are solving this at the moment though.
    
7.  ### arcanis commented on Mar 25, 2021
    
    [arcanis](https://github.com/arcanis)
    
    [on Mar 25, 2021](https://github.com/evanw/esbuild/issues/608#issuecomment-806736226)
    
    I think Webpack goes with option 1 (disregard dynamic chunks as far as css output is concerned), which seems to be the most straightforward approach (and can be incrementally improved if needed). Plus it's probably what everyone would already imagine when reading "There is currently no support for code splitting of CSS" - the current behaviour is quite confusing.
    
    Reacted by Ian Schmitz
    
8.  [evanw](https://github.com/evanw)
    
    closed this as [completed](https://github.com/evanw/esbuild/issues?q=is%3Aissue%20state%3Aclosed%20archived%3Afalse%20reason%3Acompleted)in [#1293](https://github.com/evanw/esbuild/pull/1293)[on May 17, 2021](https://github.com/evanw/esbuild/issues/608#event-4756983454)
    
9.  ### Valexr commented on May 18, 2021
    
    [Valexr](https://github.com/Valexr)
    
    [on May 18, 2021](https://github.com/evanw/esbuild/issues/608#issuecomment-842830670)
    
    🥳
    
    Reacted by bl-ue
    

[Sign up for free](https://github.com/signup?return_to=https://github.com/evanw/esbuild/issues/608) **to join this conversation on GitHub.** Already have an account? [Sign in to comment](https://github.com/login?return_to=https://github.com/evanw/esbuild/issues/608)

## Metadata

### Assignees

No one assigned

### Labels

No labels

No labels

### Projects

No projects

### Milestone

No milestone

### Relationships

None yet

### Development

-   [Breaking changes to fix CSS import issuesevanw/esbuild](https://github.com/evanw/esbuild/pull/1293)[Releasev0.12.0](https://github.com/evanw/esbuild/releases/tag/v0.12.0)

### Participants

## Issue actions

-   

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

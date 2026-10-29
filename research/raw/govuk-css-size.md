# How we reduced CSS size and improved performance across GOV.UK – Government Digital Service

<https://gds.blog.gov.uk/2023/12/15/how-we-reduced-css-size-and-improved-performance-across-gov-uk/>

# Your choice regarding cookies on this site

We use cookies to optimise site functionality and give you the best possible experience.

[Skip to main content](https://gds.blog.gov.uk/2023/12/15/how-we-reduced-css-size-and-improved-performance-across-gov-uk/#content)

[Blog](https://www.blog.gov.uk/): [Government Digital Service](https://gds.blog.gov.uk/)

Organisations:

[Government Digital Service](https://www.gov.uk/government/organisations/government-digital-service), [Department for Science, Innovation and Technology](https://www.gov.uk/government/organisations/department-for-science-innovation-and-technology)

Search blog

 

# How we reduced CSS size and improved performance across GOV.UK

Posted by: [Jon Kirwan, Front end developer, GDS](https://gds.blog.gov.uk/author/jon-kirwan-front-end-developer-gds/ "Posts by Jon Kirwan, Front end developer, GDS") and [Martin Jones, Front end developer, GDS](https://gds.blog.gov.uk/author/martin-jones-front-end-developer-gds/ "Posts by Martin Jones, Front end developer, GDS"), Posted on: 15 December 2023 - Categories: [Posts for Tech Specialists](https://gds.blog.gov.uk/category/posts-for-tech-specialists/)

We recently reduced CSS size and improved performance across GOV.UK pages by moving away from bundling all CSS into a single stylesheet served to all pages to serving smaller stylesheets containing only the necessary styles for each page. There have been reductions of up to 40% in CSS size on some pages, accompanied by incremental improvements in timing metrics across many pages. These improvements could lead to a slightly faster experience for users accessing GOV.UK through older or low end devices or for people on slower connections.

## **Previously**

GOV.UK is made up of many different applications. Previously, each application served a single stylesheet, a set of CSS rules that define the layout and appearance of a page, made up of many different types of styles bundled together. Styles can come from our [component library](https://components.publishing.service.gov.uk/component-guide) (accordion, button, notice and more) or they may apply to specific pages within the application. Styles were served to all application pages. Bundles could sometimes include as many as 30 different style imports.

In addition, a separate stylesheet which includes commonly used styles like layout or typography styles is served from an application called static.

Bundling is a common HTTP/1 performance optimization technique where resources cannot be loaded in parallel and too many sequential network requests can take a long time to download, so it makes sense to bundle styles together to reduce network requests.

## **Problems**

Concatenating multiple stylesheet assets into one bundle has its downsides.

Firstly, users might have downloaded CSS for unvisited pages. For example, the homepage previously loaded CSS for 24 components yet, aside from commonly used styles (included in the static stylesheet), only required styles for 5 components. Therefore, a homepage visit required 17 kilobytes of unused CSS to be downloaded.

Also, the application stylesheet cache was easily invalidated for small changes, which meant the browser had to download the application stylesheet again. For example, consider a small style change to the [contents list](https://components.publishing.service.gov.uk/component-guide/contents_list) component styles in our component library to change bottom margin spacing from 20px to 30px.  

This small change would require the entire application stylesheet (27.7 kB gzipped) to be redownloaded. This is an important consideration when our component library is frequently updated.

Lastly, bundling all CSS doesn’t take advantage of the multiplexing features of HTTP/2 where multiple assets can be requested at the same time making it possible to serve many smaller files. [HTTP/2 was switched on for GOV.UK in 2020](https://technology.blog.gov.uk/2020/07/02/speeding-up-gov-uk-with-http-2/).

## **How we solved these problems**

To solve these problems, we created a new asset helper in the [govuk-publishing-components gem](https://github.com/alphagov/govuk_publishing_components). The asset helper is used to create a list of stylesheets required for rendering a page, it includes helper methods to add required stylesheets to the list and the \`render\_component\_stylesheets\` method to output the list of stylesheets as [stylesheet link tags](https://api.rubyonrails.org/v7.0.6/classes/ActionView/Helpers/AssetTagHelper.html#method-i-stylesheet_link_tag) in the <head> of the document.

The asset helper ensures that all stylesheets in the list are unique. For example, if several button components are rendered on a page, only one button stylesheet is loaded.

The asset helper runs in the background for all applications that use GOV.UK Publishing Components, but implementing the individual loading of stylesheets feature is optional.

Once we had the asset helper available, the next step was to implement the individual loading of stylesheets feature in our rendering applications. We decided to do this one application at a time, starting with the \`frontend\` rendering app (which renders the home page, the register to vote and tax your vehicle services and more). This approach allowed us to monitor the impact of the change, giving us time to fix any issues before implementing in the next rendering application.

We also created detailed documentation for [setting up individual component CSS loading](https://github.com/alphagov/govuk_publishing_components/blob/main/docs/set-up-individual-component-css-loading.md) in a rendering application. This includes step-by-step guidance, links to example pull requests and known issues.

## **Performance gains**

Using [SpeedCurve](https://www.speedcurve.com/) to test various pages, across various devices and connection speeds, before and after the changes, we’ve seen a site-wide reduction in CSS size together with performance improvements when measured against key performance indicators.

CSS size has reduced by 40% (dropping from 42 kB to 25 kB) on the [GOV.UK home page](https://www.gov.uk/) along with improvements to timing metrics including [Start Render](https://support.speedcurve.com/docs/metrics-glossary#start-render-synthetic-and-rum---chrome-firefox) (the time from the start of the initial navigation until the first non-white content is painted to the browser display), Largest Contentful Paint (​​a [Core Web Vital](https://web.dev/lcp/) metric which measures loading performance) and Last Painted Hero ([a metric that shows you when the last critical content is painted](https://www.speedcurve.com/blog/last-painted-hero/)).

On an emulated Mobile 3G device:

-   Start Render - 4% improvement from 2.3s to 2.2s
-   Largest Contentful Paint - 7% improvement from 2.53s to 2.35s
-   Last Painted Hero - 7% change from 3s to 2.8s

Likewise, for [COVID-19](https://www.gov.uk/coronavirus) pages, there’s been a 27% reduction in CSS (from 44 kB to 32 kB) and similar performance improvements.

-   Start Render - 4% improvement from 2.3s to 2.2s
-   Largest Contentful Paint - 4% improvement from 2.41s to 2.32s
-   Last Painted Hero - 6% improvement from 3s to 2.81s

Such improvements will mostly be imperceptible to users on high end devices or faster connections but could make a difference for users on older or low end devices (GOV.UK analytics show a sizeable number of users using Galaxy A12, A13 and earlier models) or for people on slower connections - for some pages the improvements bring load times in under 3 seconds ([statistics indicate that 40% of visitors will leave a website if it takes longer than three seconds to load](https://www.browserstack.com/guide/how-fast-should-a-website-load)).

Whilst these size reductions are encouraging, arguably the main advantage is in caching improvements. In the earlier example, a small spacing update to one of the application component styles forced the browser to redownload the entire application stylesheet. Now the same change means the client only downloads the updated component CSS (1.1 K gzipped). All other stylesheets are loaded from cache.

## **Other improvements**

Whilst implementing the asset helper we identified other optimisation opportunities including finding and removing redundant code. We removed 32 stylesheets across 7 applications and more than 600 lines of CSS by removing unused CSS - styles that are no longer used anywhere - and also removing redundant code - custom helpers or component styles that are now available in the component library or [design system](https://design-system.service.gov.uk/).

## **Negatives**

Loading lots of individual stylesheets doesn’t always lead to performance improvements. For example, on detailed guide pages e.g. [rates and thresholds for employers 2023 to 2024](https://www.gov.uk/guidance/rates-and-thresholds-for-employers-2023-to-2024) which use lots of different components, users can download approximately 16 different stylesheets. Whilst CSS size is still lower than previously, performance indicators are adversely affected with time metrics slightly worse than previously.

Also, compressing files with small amounts of text doesn’t always produce smaller file sizes (or leads to hardly any size reduction) since there are fewer instances of repetition to be identified. It’s even possible to see larger file sizes in some cases.

However, the performance improvements across the site outweigh the downsides seen in these particular edge cases.

## **What’s next**

For some pages, where many individual stylesheets are served, performance metrics are slightly worse. We might look to group together some component styles, commonly served to the same pages, into smaller bundles to achieve better compression savings and reduce their size.

Also, we’re investigating loading JavaScript scripts individually, though this is more complex and will require changes to our component library to make use of [ES6 modules](https://github.com/alphagov/govuk-rfcs/blob/aa16e2b5c0f32784dc83117dc0c90d1d4fbe73c8/rfc-160-using-es6-modules-in-govuk_publishing_components.md).

Finally, [future enhancements](https://github.com/alphagov/govuk-rfcs/blob/779531b0f023733da76bc92c5758697560d95514/rfc-149-switch-to-per-page-asset-loading.md#future-plans) might include preloading assets based on predicted user journeys or lazy loading ‘below the fold’ component stylesheets such as footer and feedback component CSS; both positioned at the bottom of each page.

Interested in our work? [GDS is hiring](https://www.civil-service-careers.gov.uk/departments/gds-hub/).

**Tags:** [CSS](https://gds.blog.gov.uk/tag/css/), [Developer](https://gds.blog.gov.uk/tag/developer/), [development](https://gds.blog.gov.uk/tag/development/), [gov.uk](https://gds.blog.gov.uk/tag/gov-uk/), [Software Engineering](https://gds.blog.gov.uk/tag/software-engineering/)

[Get involved with the launch of early access to GOV.UK Forms](https://gds.blog.gov.uk/2023/11/27/get-involved-with-the-launch-of-early-access-to-gov-uk-forms/)

[Department for Education: Our experience of joining GOV.UK One Login](https://gds.blog.gov.uk/2023/12/20/department-for-education-our-experience-of-joining-gov-uk-one-login/)

## Sharing and comments

### Share this page

-   [X (formerly Twitter)](https://twitter.com/intent/tweet?original_referer&url=https%3A%2F%2Fgds.blog.gov.uk%2F2023%2F12%2F15%2Fhow-we-reduced-css-size-and-improved-performance-across-gov-uk%2F&text=How+we+reduced+CSS+size+and+improved+performance+across+GOV.UK)
-   [Facebook](https://www.facebook.com/sharer/sharer.php?u=https%3A%2F%2Fgds.blog.gov.uk%2F2023%2F12%2F15%2Fhow-we-reduced-css-size-and-improved-performance-across-gov-uk%2F)
-   [LinkedIn](https://www.linkedin.com/shareArticle?url=https%3A%2F%2Fgds.blog.gov.uk%2F2023%2F12%2F15%2Fhow-we-reduced-css-size-and-improved-performance-across-gov-uk%2F)
-   [Email](mailto:?subject=I%20wanted%20to%20share%20this%20post%20with%20you%20from%20Government%20Digital%20Service&body=How%20we%20reduced%20CSS%20size%20and%20improved%20performance%20across%20GOV.UK%20https%3A%2F%2Fgds.blog.gov.uk%2F2023%2F12%2F15%2Fhow-we-reduced-css-size-and-improved-performance-across-gov-uk%2F)

### 2 comments

1.  Comment by Nazmul Hasan posted on 19 December 2023
    
    What you have done is good, but you can do more with Saas and building your own framework on previous frameworks such as bootstrap or grid, this way you will have a single css but your design will be component based and your load time is optimised and better load time and synchronised design.
    
    [Link to this comment](https://gds.blog.gov.uk/2023/12/15/how-we-reduced-css-size-and-improved-performance-across-gov-uk/#comment-976944)
    
2.  Comment by Alan posted on 15 December 2023
    
    Does this have any possible impact on carbon emissions? Thanks.
    
    [Link to this comment](https://gds.blog.gov.uk/2023/12/15/how-we-reduced-css-size-and-improved-performance-across-gov-uk/#comment-976835)
    

## Related content and links

### Government Digital Service

We are the digital centre of government. We serve the public, central government departments and the wider public sector.

[Find out more](https://gds.blog.gov.uk/about/).

### Sign up and manage updates

-   [Email](https://gds.blog.gov.uk/subscribe/)
-   [Atom](https://gds.blog.gov.uk/feed/)

### Be part of the transformation

If you’re interested in joining us, check out all open opportunities on the [GDS careers](https://www.civil-service-careers.gov.uk/departments/gds-hub/) site.

### Follow us

-   [Twitter](https://twitter.com/gdsteam)
-   [Facebook](https://www.facebook.com/GovernmentDigitalService)
-   [YouTube](https://www.youtube.com/user/GovDigitalService)
-   [Instagram](http://instagram.com/gdsteam)
-   [LinkedIn](http://www.linkedin.com/company/government-digital-service)
-   [GDS Podcasts](https://governmentdigitalservice.podbean.com/)

### Government Digital and Data

### Download the GOV.UK App

The GOV.UK app went live in public beta in July 2025. Find out how to [download it for free on GOV.UK](https://www.gov.uk/guidance/download-the-govuk-app).

### Recent Posts

-   [Opening GOV.UK Wallet sandbox to digital verification services](https://gds.blog.gov.uk/2026/10/19/opening-gov-uk-wallet-sandbox-to-digital-verification-services/)  19 October 2026
-   [Building the foundations for better data sharing across the UK](https://gds.blog.gov.uk/2026/10/05/building-the-foundations-for-better-data-sharing-across-the-uk/)  5 October 2026
-   [Digital devolution: what’s been happening and what’s coming up?](https://gds.blog.gov.uk/2026/09/25/digital-devolution-whats-been-happening-and-whats-coming-up/)  25 September 2026

### Comments and moderation

[Read our guidelines](https://gds.blog.gov.uk/terms/)

### Social media house rules

[Read our guidelines](https://gds.blog.gov.uk/social-media-house-rules/)

## Useful links

-   [All GOV.UK blogs](https://www.blog.gov.uk/)
-   [All GOV.UK blog posts](https://www.blog.gov.uk/all-posts/)
-   [GOV.UK](https://www.gov.uk/)
-   [All departments](https://www.gov.uk/government/organisations)
-   [Accessibility statement](https://www.blog.gov.uk/accessibility-statement/)
-   [Cookies](https://www.blog.gov.uk/cookies/)

All content is available under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/), except where otherwise stated

[© Crown copyright](https://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/uk-government-licensing-framework/crown-copyright/)

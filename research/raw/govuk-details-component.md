# Details – GOV.UK Design System

<https://design-system.service.gov.uk/components/details/>

## Cookies on GOV.UK Design System

We’d like to use analytics cookies so we can understand how you use the Design System and make improvements.

We also use essential cookies to remember if you’ve accepted analytics cookies.

  [View cookies](https://design-system.service.gov.uk/cookies/)

[Skip to main content](https://design-system.service.gov.uk/components/details/#main-content)

[Design System](https://design-system.service.gov.uk/)

Search Design system

-   [Get started](https://design-system.service.gov.uk/get-started/)
-   [Styles](https://design-system.service.gov.uk/styles/)
-   [**Components**](https://design-system.service.gov.uk/components/)
-   [Patterns](https://design-system.service.gov.uk/patterns/)
-   [Community](https://design-system.service.gov.uk/community/)
-   [Accessibility](https://design-system.service.gov.uk/accessibility/)

## Pages in this section

-   [Accordion](https://design-system.service.gov.uk/components/accordion/)
-   [Back link](https://design-system.service.gov.uk/components/back-link/)
-   [Breadcrumbs](https://design-system.service.gov.uk/components/breadcrumbs/)
-   [Button](https://design-system.service.gov.uk/components/button/)
-   [Character count](https://design-system.service.gov.uk/components/character-count/)
-   [Checkboxes](https://design-system.service.gov.uk/components/checkboxes/)
-   [Cookie banner](https://design-system.service.gov.uk/components/cookie-banner/)
-   [Date input](https://design-system.service.gov.uk/components/date-input/)
-   [Details](https://design-system.service.gov.uk/components/details/)
    -   [History for Details](https://design-system.service.gov.uk/components/details/history/)
    -   [Use with Nunjucks for Details](https://design-system.service.gov.uk/components/details/nunjucks/)
-   [Error message](https://design-system.service.gov.uk/components/error-message/)
-   [Error summary](https://design-system.service.gov.uk/components/error-summary/)
-   [Exit this page](https://design-system.service.gov.uk/components/exit-this-page/)
-   [Feedback](https://design-system.service.gov.uk/components/feedback/)
-   [Fieldset](https://design-system.service.gov.uk/components/fieldset/)
-   [File upload](https://design-system.service.gov.uk/components/file-upload/)
-   [Generic header](https://design-system.service.gov.uk/components/generic-header/)
-   [GOV.UK footer](https://design-system.service.gov.uk/components/footer/)
-   [GOV.UK header](https://design-system.service.gov.uk/components/header/)
-   [Inset text](https://design-system.service.gov.uk/components/inset-text/)
-   [Language navigation](https://design-system.service.gov.uk/components/language-navigation/)
-   [Notification banner](https://design-system.service.gov.uk/components/notification-banner/)
-   [Pagination](https://design-system.service.gov.uk/components/pagination/)
-   [Panel](https://design-system.service.gov.uk/components/panel/)
-   [Password input](https://design-system.service.gov.uk/components/password-input/)
-   [Phase banner](https://design-system.service.gov.uk/components/phase-banner/)
-   [Radios](https://design-system.service.gov.uk/components/radios/)
-   [Select](https://design-system.service.gov.uk/components/select/)
-   [Service navigation](https://design-system.service.gov.uk/components/service-navigation/)
-   [Skip link](https://design-system.service.gov.uk/components/skip-link/)
-   [Summary list](https://design-system.service.gov.uk/components/summary-list/)
-   [Table](https://design-system.service.gov.uk/components/table/)
-   [Tabs](https://design-system.service.gov.uk/components/tabs/)
-   [Tag](https://design-system.service.gov.uk/components/tag/)
-   [Task list](https://design-system.service.gov.uk/components/task-list/)
-   [Text input](https://design-system.service.gov.uk/components/text-input/)
-   [Textarea](https://design-system.service.gov.uk/components/textarea/)
-   [Warning text](https://design-system.service.gov.uk/components/warning-text/)

1.  [Home](https://design-system.service.gov.uk/)
2.  [Components](https://design-system.service.gov.uk/components)

# Details

Make a page easier to scan by letting users reveal more detailed information only if they need it.

[Open this example in a new tab: details](https://design-system.service.gov.uk/components/details/default/)

-   [HTML](https://design-system.service.gov.uk/components/details/#details-example-html)
-   [Nunjucks](https://design-system.service.gov.uk/components/details/#details-example-nunjucks)

## When to use this component

Use the details component to make a page easier to scan when it contains information that only some users will need.

## When not to use this component

Do not use the details component to hide information that the majority of your users will need.

## Decide between using details, accordions and tabs

The Details component, [Accordion component](https://design-system.service.gov.uk/components/accordion/), and [Tabs component](https://design-system.service.gov.uk/components/tabs/) all hide sections of content which a user can choose to reveal.

Use the details component instead of tabs or an accordion if you only have 1 section of content.

The details component is less visually prominent than tabs and accordions, so tends to work better for content which is not as important to users.

## How it works

The details component is a short link that shows more detailed help text when a user clicks on it.

There are 2 ways to use the details component. You can use HTML or, if you are using [Nunjucks](https://mozilla.github.io/nunjucks/) or the [GOV.UK Prototype Kit](https://prototype-kit.service.gov.uk/), you can use the Nunjucks macro.

[Open this example in a new tab: details second](https://design-system.service.gov.uk/components/details/default/)

-   [HTML](https://design-system.service.gov.uk/components/details/#details-second-example-html)
-   [Nunjucks](https://design-system.service.gov.uk/components/details/#details-second-example-nunjucks)

### Write clear link text

Make the link text short and descriptive so users can quickly work out if they need to click on it.

## Research on this component

There is [evidence that some users avoid clicking the link to show more details](https://github.com/alphagov/govuk-design-system/discussions/6095#discussioncomment-18812380), as they think it will take them away from the page.

There are [concerns that some users of voice assist software will not be able to interact with the component](https://github.com/alphagov/govuk-design-system/discussions/6095#discussioncomment-18812377). Some software might require the user to specifically refer to the link to show more details as a button in order to interact with it.

## Recent changes

| Date | Changed | Description |
| --- | --- | --- |
| Oct 2024 | [GOV.UK Frontend v5.7.0](https://github.com/alphagov/govuk-frontend/releases/tag/v5.7.0) | 
Fixed incorrect bottom margin when component is collapsed.

Fixed expanded state not being announced on iOS.

 |
| Dec 2023 | [GOV.UK Frontend v5.0.0](https://github.com/alphagov/govuk-frontend/releases/tag/v5.0.0) | 

Removed JavaScript polyfill for older browsers.

 |
| Aug 2022 | [GOV.UK Frontend v4.3.0](https://github.com/alphagov/govuk-frontend/releases/tag/v4.3.0) | 

Added the ability to pass the `html` parameter using [Nunjucks call syntax](https://mozilla.github.io/nunjucks/templating.html#call).

Removed redundant `aria-hidden` attribute.

 |
| Sept 2021 | [GOV.UK Frontend v3.13.1](https://github.com/alphagov/govuk-frontend/releases/tag/v3.13.1) | 

Removed unnecessary right-side padding.

 |
| Feb 2021 | Guidance | 

Added research section to component guidance.

 |

[View full change history](https://design-system.service.gov.uk/components/details/history/)

## Help improve this component

To help make sure that this page is useful, relevant and up to date, you can:

-   take part in the [‘Details’ discussion on GitHub](https://github.com/alphagov/govuk-design-system/discussions/6095/) and share your research
-   [propose a change on GitHub](https://github.com/alphagov/govuk-design-system/edit/main/src/components/details/index.md) – read more about [how to propose changes in GitHub](https://design-system.service.gov.uk/community/propose-a-content-change-using-github/)

## Need help?

If you’ve got a question about the GOV.UK Design System, [contact the team](https://design-system.service.gov.uk/contact/).

[Back to top](https://design-system.service.gov.uk/components/details/#top)

## Support links

-   [Accessibility statement](https://design-system.service.gov.uk/accessibility-statement/)
-   [Sitemap](https://design-system.service.gov.uk/sitemap/)
-   [Cookies](https://design-system.service.gov.uk/cookies/)
-   [Privacy](https://design-system.service.gov.uk/privacy-policy/)
-   [Contact the team](https://design-system.service.gov.uk/contact/)

Built by the [GOV.UK Design System team](https://design-system.service.gov.uk/design-system-team/)

All content is available under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/), except where otherwise stated

[© Crown copyright](https://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/uk-government-licensing-framework/crown-copyright/)

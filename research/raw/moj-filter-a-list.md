# Filter a list - MOJ Design System

<https://design-patterns.service.justice.gov.uk/patterns/filter-a-list/>

[Skip to main content](https://design-patterns.service.justice.gov.uk/patterns/filter-a-list/#main-content)

## Cookies on MOJ Design System

We’d like to use analytics cookies so we can understand how you use the service and make improvements.

 

[Skip to main content](https://design-patterns.service.justice.gov.uk/patterns/filter-a-list/#main-content)

[Ministry of Justice Design System](https://design-patterns.service.justice.gov.uk/)

## MOJ building blocks

-   
-   -   [Add to a list](https://design-patterns.service.justice.gov.uk/patterns/add-to-a-list/)
    -   [Confirm an action](https://design-patterns.service.justice.gov.uk/patterns/confirm-an-action/)
    -   [Electronic signature](https://design-patterns.service.justice.gov.uk/patterns/electronic-signature/)
    -   [Filter a list](https://design-patterns.service.justice.gov.uk/patterns/filter-a-list/)
    -   [Get help](https://design-patterns.service.justice.gov.uk/patterns/get-help/)
    -   [Upload files](https://design-patterns.service.justice.gov.uk/patterns/upload-files/)
-   
-   

## Probation building blocks

-   
-   

## Guidance

-   [Content style guide](https://design-patterns.service.justice.gov.uk/content-standards/style-guide/)
-   
-   
-   

## About the Design System

-   [Benefits](https://design-patterns.service.justice.gov.uk/design-system-benefits/)
-   [Building block statuses](https://design-patterns.service.justice.gov.uk/design-system-statuses/)
-   [Submit a component](https://design-patterns.service.justice.gov.uk/contribute/add-new-component/start)
-   [Roadmap](https://design-patterns.service.justice.gov.uk/roadmap/)
-   [Get help](https://design-patterns.service.justice.gov.uk/help/)

Patterns

# Filter a list

**Status: To be reviewed**

Created in June 2021.

How to use ‘to be reviewed’ patterns

[Open this example (Filter a list pattern (example)) in a new window](https://design-patterns.service.justice.gov.uk/patterns/filter-a-list/examples/default)

-   [HTML (Filter a list pattern (example))](https://design-patterns.service.justice.gov.uk/patterns/filter-a-list/#html-default-examples-default)
-   [Nunjucks (Filter a list pattern (example))](https://design-patterns.service.justice.gov.uk/patterns/filter-a-list/#nunjucks-default-examples-default)
-   [JavaScript (Filter a list pattern (example))](https://design-patterns.service.justice.gov.uk/patterns/filter-a-list/#js-default-examples-default)

## When to use

Use this pattern to help users refine a set of items either in a list or a set of search results. This pattern should be used instead of advanced search.

## When not to use

Don’t use this pattern if there aren’t many items to filter.

## How to use

The list should first appear unfiltered. After selecting one or more filters, the user submits the form which filters the list.

By default filters shouldn’t persist across sessions or navigation. Where there is a clear user need, you can specify which filters should persist and for how long.

The filters can be any form control, including date inputs, checkboxes, free text and radio buttons. Use the appropriate form control for the type of attribute being filtered on.

Filters can be used in combination with the [search component](https://design-patterns.service.justice.gov.uk/components/search/). In this case, the flow should be:

1.  Type a search term and submit the search form
2.  See a search results page with filters
3.  Users can then filter the search results page further or search again starting from (1)

## Get help and contribute

### Get help

You can [contact the MOJ Design System team for help or support using this pattern](https://design-patterns.service.justice.gov.uk/help).

### Help improve this pattern

The MOJ Design System team would like to hear:

-   how you have used this pattern in your service
-   any feedback you have about its usage, for example accessibility or ideas for improvement

Add these comments to the [filter a list discussion on GitHub](https://github.com/ministryofjustice/moj-frontend/discussions/717).

## Support links

-   [Get help](https://design-patterns.service.justice.gov.uk/help)
-   [Cookies](https://design-patterns.service.justice.gov.uk/cookies)
-   [Accessibility](https://design-patterns.service.justice.gov.uk/accessibility)
-   [Privacy](https://design-patterns.service.justice.gov.uk/privacy)
-   [Sitemap](https://design-patterns.service.justice.gov.uk/sitemap)

All content is available under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/), except where otherwise stated

[© Crown copyright](https://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/uk-government-licensing-framework/crown-copyright/)

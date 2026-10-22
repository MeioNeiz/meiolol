# Filter | Avon and Somerset Police

<https://asp-design-system.policedigital.services/components/filter/>

[Skip to content](https://asp-design-system.policedigital.services/components/filter/#main)

 [ASP Digital Design System](https://asp-design-system.policedigital.services/)

-   [Get started](https://asp-design-system.policedigital.services/get-started)
-   [Styles](https://asp-design-system.policedigital.services/styles)
-   [Components](https://asp-design-system.policedigital.services/components)
-   [Patterns](https://asp-design-system.policedigital.services/patterns)
-   [Templates](https://asp-design-system.policedigital.services/templates)
-   [Content](https://asp-design-system.policedigital.services/content)
-   [Accessibility](https://asp-design-system.policedigital.services/accessibility)
-   [Resources](https://asp-design-system.policedigital.services/resources)

Search the Design System  

You are here:

1.  [Home](https://asp-design-system.policedigital.services/)
2.  [Components](https://asp-design-system.policedigital.services/components/)
3.  Filter

-   [A-Z](https://asp-design-system.policedigital.services/components/a-z/)
-   [Accordion](https://asp-design-system.policedigital.services/components/accordion/)
-   [Acronym](https://asp-design-system.policedigital.services/components/acronym/)
-   [Action](https://asp-design-system.policedigital.services/components/action/)
-   [Alert](https://asp-design-system.policedigital.services/components/alert/)
-   [Breadcrumbs](https://asp-design-system.policedigital.services/components/breadcrumbs/)
-   [Button](https://asp-design-system.policedigital.services/components/button/)
-   [Card](https://asp-design-system.policedigital.services/components/card/)
-   [Checkboxes](https://asp-design-system.policedigital.services/components/checkboxes/)
-   [Confirmation](https://asp-design-system.policedigital.services/components/confirmation/)
-   [Cookie banner](https://asp-design-system.policedigital.services/components/cookie-banner/)
-   [Copy](https://asp-design-system.policedigital.services/components/copy/)
-   [Date input](https://asp-design-system.policedigital.services/components/date-input/)
-   [Details](https://asp-design-system.policedigital.services/components/details/)
-   [Environment](https://asp-design-system.policedigital.services/components/env/)
-   [Error summary](https://asp-design-system.policedigital.services/components/error-summary/)
-   Filter
-   [Footer](https://asp-design-system.policedigital.services/components/footer/)
-   [Forms](https://asp-design-system.policedigital.services/components/forms/)
-   [Group](https://asp-design-system.policedigital.services/components/group/)
-   [Header](https://asp-design-system.policedigital.services/components/header/)
-   [Help](https://asp-design-system.policedigital.services/components/help/)
-   [Hero](https://asp-design-system.policedigital.services/components/hero/)
-   [Horizontal rule](https://asp-design-system.policedigital.services/components/hr/)
-   [Input](https://asp-design-system.policedigital.services/components/input/)
-   [Leave site](https://asp-design-system.policedigital.services/components/leave-site/)
-   [Notification](https://asp-design-system.policedigital.services/components/notification/)
-   [Pagination](https://asp-design-system.policedigital.services/components/pagination/)
-   [Panel](https://asp-design-system.policedigital.services/components/panel/)
-   [Progress](https://asp-design-system.policedigital.services/components/progress/)
-   [Radios](https://asp-design-system.policedigital.services/components/radios/)
-   [Search input](https://asp-design-system.policedigital.services/components/search-input/)
-   [Select](https://asp-design-system.policedigital.services/components/select/)
-   [Signage](https://asp-design-system.policedigital.services/components/signage/)
-   [Skip link](https://asp-design-system.policedigital.services/components/skip-link/)
-   [Status](https://asp-design-system.policedigital.services/components/status/)
-   [Steps](https://asp-design-system.policedigital.services/components/steps/)
-   [Summary list](https://asp-design-system.policedigital.services/components/summary-list/)
-   [Table](https://asp-design-system.policedigital.services/components/table/)
-   [Tabs](https://asp-design-system.policedigital.services/components/tabs/)
-   [Textarea](https://asp-design-system.policedigital.services/components/textarea/)
-   [Time input](https://asp-design-system.policedigital.services/components/time-input/)

# Filter

The form should submit with params, so the page can be reloaded/shared with the current state, also history can be preserved per pageload.

-   
-   

[Open this example in a new tab: filter](https://asp-design-system.policedigital.services/components/filter/679350efe011b/)

WIP -- After filtering the named anchor should be results table, if no results are returned there should be a message in place of the table, that reads “0 results available. Adjust or reset the filters to see available results.” Results can be substituted for a more specific term.

WIP — This toggle functionality uses JavaScript. If JavaScript is enabled, the button is hidden, on page load JavaScript checks for the corresponding content. If the corresponding content is found, the button is unhidden and the content is either shown or hidden, depending upon the aria-expanded attribute set on the button. If JavaScript is disabled, the button remains hidden and content visible. (Same as Help and Steps. Header -- not yet documented, will utilise the same JavaScript functionality with an addition data attribute to hide other content when a button is pressed. See also tabs)

## When to use this component

Use the filter component to help users filter a list of items, such as a list of cases or search results.

You should only provide users with filters they really need.

## How to use this component

You should use this component with the [filter a list](https://asp-design-system.policedigital.services/patterns/filter-a-list/) pattern to allow the component to be shown with a list.

Users can select 1 or more filters. When the user clicks ‘Apply filters’ the page refreshes to show the items that match the filters.

### Types of filters

You can use form elements such as [radios](https://asp-design-system.policedigital.services/components/radios/) and [checkboxes](https://asp-design-system.policedigital.services/components/checkboxes/) to let users filter the list.

## Status of development

The below criteria all need to be met for a component to be considered as fully developed for use within the ASP Digital Design System.

| Development criteria | Status |
| --- | --- |
| WCAG 2.2 compliant | Not started |
| WCAG 2.1 compliant | Completed |
| HTML / Nunjucks version | Completed |
| Figma version | Not started |
| M365 versions | Not started |
| Documentation | In progress |

* * *

## Make a change to the Design System

Suggest an edit to this system, or any of the components in it, by submitting a [Design System change request](https://forms.office.com/Pages/ResponsePage.aspx?id=bIFyLR9-wEGpSEeohw_zOlGCZNx8mwNDtJBjimlBuXZUODEzT0NIUlQwTUkyUzRRU0hRR1lMOUtFMSQlQCN0PWcu).

* * *

* * *

Published 24 January 2025  
Last updated 30 September 2026

-   [Accessibility statement](https://www.avonandsomerset.police.uk/help/accessibility)
-   [Sitemap](https://asp-design-system.policedigital.services/sitemap)
-   [Privacy](https://www.avonandsomerset.police.uk/help/privacy)
-   [Terms and conditions](https://www.avonandsomerset.police.uk/help/terms-and-conditions)

Copyright © 2026 Avon and Somerset Police. All Rights Reserved.

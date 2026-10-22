# Spacing – GOV.UK Design System

<https://design-system.service.gov.uk/styles/spacing/>

## Cookies on GOV.UK Design System

We’d like to use analytics cookies so we can understand how you use the Design System and make improvements.

We also use essential cookies to remember if you’ve accepted analytics cookies.

  [View cookies](https://design-system.service.gov.uk/cookies/)

[Skip to main content](https://design-system.service.gov.uk/styles/spacing/#main-content)

[Design System](https://design-system.service.gov.uk/)

Search Design system

-   [Get started](https://design-system.service.gov.uk/get-started/)
-   [**Styles**](https://design-system.service.gov.uk/styles/)
-   [Components](https://design-system.service.gov.uk/components/)
-   [Patterns](https://design-system.service.gov.uk/patterns/)
-   [Community](https://design-system.service.gov.uk/community/)
-   [Accessibility](https://design-system.service.gov.uk/accessibility/)

## Pages in this section

### Page structure

-   [Page template](https://design-system.service.gov.uk/styles/page-template/)
-   [Layout](https://design-system.service.gov.uk/styles/layout/)
-   [Spacing](https://design-system.service.gov.uk/styles/spacing/)
    -   [Responsive spacing](https://design-system.service.gov.uk/styles/spacing/#responsive-spacing)
    -   [Static spacing](https://design-system.service.gov.uk/styles/spacing/#static-spacing)
    -   [Applying spacing in your own CSS](https://design-system.service.gov.uk/styles/spacing/#applying-spacing-in-your-own-css)
    -   [Overriding spacing](https://design-system.service.gov.uk/styles/spacing/#overriding-spacing)
-   [Section break](https://design-system.service.gov.uk/styles/section-break/)

### Typography

-   [Typeface](https://design-system.service.gov.uk/styles/typeface/)
-   [Type scale](https://design-system.service.gov.uk/styles/type-scale/)
-   [Headings](https://design-system.service.gov.uk/styles/headings/)
-   [Paragraphs](https://design-system.service.gov.uk/styles/paragraphs/)
-   [Links](https://design-system.service.gov.uk/styles/links/)
-   [Lists](https://design-system.service.gov.uk/styles/lists/)
-   [Font override classes](https://design-system.service.gov.uk/styles/font-override-classes/)

### Visual elements

-   [Colour](https://design-system.service.gov.uk/styles/colour/)
-   [Images](https://design-system.service.gov.uk/styles/images/)

1.  [Home](https://design-system.service.gov.uk/)
2.  [Styles](https://design-system.service.gov.uk/styles)

# Spacing

The Design System uses two different spacing scales – responsive and static.

## Responsive spacing

The responsive spacing scale adapts based on screen size.

The spacing for ‘large screens’ is used when the screen is wider than the tablet breakpoint (640px). Spacing for the smallest units (0-3) stays the same for all screen sizes.

The responsive spacing scale
| Spacing unit | Small screens | Large screens |
| --- | --- | --- |
| 0 | 0 | 0 |
| 1 | 5px | 5px |
| 2 | 10px | 10px |
| 3 | 15px | 15px |
| 4 | 15px | 20px |
| 5 | 15px | 25px |
| 6 | 20px | 30px |
| 7 | 25px | 40px |
| 8 | 30px | 50px |
| 9 | 40px | 60px |

## Static spacing

The static spacing scale stays the same for all screen sizes, and uses the same spacing as ‘large screens’ in the responsive spacing scale.

The static spacing scale
| Spacing unit | All screens |
| --- | --- |
| 0 | 0 |
| 1 | 5px |
| 2 | 10px |
| 3 | 15px |
| 4 | 20px |
| 5 | 25px |
| 6 | 30px |
| 7 | 40px |
| 8 | 50px |
| 9 | 60px |

## Applying spacing in your own CSS

If you want to reference the spacing scale in your CSS, use the spacing helpers.

### Using the responsive spacing helper

To use the responsive spacing scale, include either:

-   the [`govuk-responsive-margin`](https://frontend.design-system.service.gov.uk/sass-api-reference/#govuk-responsive-margin) mixin
-   the [`govuk-responsive-padding`](https://frontend.design-system.service.gov.uk/sass-api-reference/#govuk-responsive-padding) mixin

For example, to apply spacing unit 6 for 30px padding on large screens and 20px on small screens, use:

```scss
@include govuk-responsive-padding(6);
```

You can also add an argument to apply margin or padding in a single direction.

For example, to apply spacing unit 6 for a 30px bottom margin on large screens and a 20px bottom margin on small screens, use:

```scss
@include govuk-responsive-margin(6, "bottom");
```

### Using the static spacing helper

For the static spacing scale, use the [`govuk-spacing` function](https://frontend.design-system.service.gov.uk/sass-api-reference/#govuk-spacing).

For example, to apply spacing unit 6 for 30px top padding on all screens, use:

```scss
padding-top: govuk-spacing(6);
```

For negative spacing, use a negative spacing unit number.

For example, to apply spacing unit -3 for a negative 15px top margin all screens, use:

```scss
margin-top: govuk-spacing(-3);
```

## Overriding spacing

Occasionally, you might need to make minor adjustments like adding or removing spacing to elements of your design. You can use the spacing override classes for this.

### Responsive spacing override classes

The responsive spacing override classes start with: `govuk-!-`, followed by either `margin-` or `padding-`, and then a spacing unit number.

To apply spacing in a single direction, include `left-`, `right-`, `top-`, or `bottom-` just before the spacing unit.

For example, use:

-   `govuk-!-margin-9` to apply a 40px margin to all sides of the element on small screens, increasing to 60px on large screens
-   `govuk-!-padding-right-5` to apply 15px of padding to the right side of the element on small screens, increasing to 25px on large screens
-   `govuk-!-margin-0` to remove all margins at all screen sizes

### Static spacing override classes

The static spacing override classes start with `govuk-!-static`. Use them the same way as the responsive spacing override classes.

For example, use:

-   `govuk-!-static-margin-9` to apply a 60px margin to all sides of the element at all screen sizes
-   `govuk-!-static-padding-right-5` to apply 25px of padding to the right side of the element at all screen sizes
-   `govuk-!-static-margin-0` to remove all margins at all screen sizes, same as `govuk-!-margin-0`

### Examples

[Open this example in a new tab: padding scale – spacing](https://design-system.service.gov.uk/styles/spacing/spacing-scale-padding/)

-   [HTML](https://design-system.service.gov.uk/styles/spacing/#padding-scale-spacing-example-html)

[Open this example in a new tab: margin scale – spacing](https://design-system.service.gov.uk/styles/spacing/spacing-scale-margin/)

-   [HTML](https://design-system.service.gov.uk/styles/spacing/#margin-scale-spacing-example-html)

## Help improve this style

To help make sure that this page is useful, relevant and up to date, you can:

-   take part in the [‘Spacing’ discussion on GitHub](https://github.com/alphagov/govuk-design-system/discussions/5947/) and share your research
-   [propose a change on GitHub](https://github.com/alphagov/govuk-design-system/edit/main/src/styles/spacing/index.md) – read more about [how to propose changes in GitHub](https://design-system.service.gov.uk/community/propose-a-content-change-using-github/)

## Need help?

If you’ve got a question about the GOV.UK Design System, [contact the team](https://design-system.service.gov.uk/contact/).

[Back to top](https://design-system.service.gov.uk/styles/spacing/#top)

## Support links

-   [Accessibility statement](https://design-system.service.gov.uk/accessibility-statement/)
-   [Sitemap](https://design-system.service.gov.uk/sitemap/)
-   [Cookies](https://design-system.service.gov.uk/cookies/)
-   [Privacy](https://design-system.service.gov.uk/privacy-policy/)
-   [Contact the team](https://design-system.service.gov.uk/contact/)

Built by the [GOV.UK Design System team](https://design-system.service.gov.uk/design-system-team/)

All content is available under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/), except where otherwise stated

[© Crown copyright](https://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/uk-government-licensing-framework/crown-copyright/)

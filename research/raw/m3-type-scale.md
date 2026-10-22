# Typography – Material Design 3

<https://m3.material.io/styles/typography/type-scale-tokens>

[Skip to main content](https://m3.material.io/styles/typography/type-scale-tokens#main_content)

[search](https://m3.material.io/search.html)[material\_design

Home

](https://m3.material.io/)[apps

Get started

](https://m3.material.io/get-started)[code

Develop

](https://m3.material.io/develop)[book

Foundations

](https://m3.material.io/foundations)[palette

Styles

](https://m3.material.io/styles)[add\_circle

Components

](https://m3.material.io/components)[pages

Blog

](https://m3.material.io/blog)

play\_arrow

pause

dark\_mode

light\_mode

# Typography

Use typography to make content readable and beautiful

[Overview](https://m3.material.io/styles/typography/overview)[Fonts](https://m3.material.io/styles/typography/fonts)[Type scale & tokens](https://m3.material.io/styles/typography/type-scale-tokens)[Applying type](https://m3.material.io/styles/typography/applying-type)[Editorial treatments](https://m3.material.io/styles/typography/editorial-treatments)

On this page

## Typography

-   Type scale
-   Type scale tokens
-   Emphasized type styles
-   Where emphasized styles can be used
-   Customize the typeface
-   Language height support
-   Customizing type styles
-   Customizing your type scale

link

Copy linkLink copied

## Type scale

link

Copy linkLink copied

A **type scale** is a selection of type styles used across a product to ensure consistency.

link

Copy linkLink copied

### M3 type scale

link

Copy linkLink copied

Material 3 has one **type scale** containing two sets of **type styles: 15 baseline** and **15 emphasized**. Both of these style sets follow the same scale from Display Large to Label Small.

The **emphasized** styles were added in the expressive update. They have a higher weight and other minor adjustments compared to the baseline styles, and are best applied to bold, selection, and other areas of emphasis. Baseline and emphasized styles are meant to be used together.

link

Copy linkLink copied

The scale is a range of contrasting styles that support the needs of various product contexts and content. No single product will use all the styles. Instead, select styles from the scale that are most appropriate.

link

Copy linkLink copied

## Type scale tokens

link

Copy linkLink copied

Each of the 30 styles has a single token that captures all the default properties. Tokens are separated into the **baseline** and **emphasized** sets. Each axis and property, such as font, line height, size, tracking, and weight, also has an individual token for greater customization. [Learn more about design tokens](https://m3.material.io/m3/pages/design-tokens/overview)

link

Copy linkLink copied

### Baseline type style tokens

link

Copy linkLink copied

link

Copy linkLink copied

## Emphasized type styles

link

Copy linkLink copied

The M3 type scale has 15 emphasized type styles. Use both baseline and emphasized type styles together to achieve expressive experiences. Material recommends using emphasized styles for selection, actions, headlines, and other [editorial treatments](https://m3.material.io/m3/pages/typography/editorial-treatments#19e5796e-9db8-4687-b20c-c6cee77e7df8).

link

Copy linkLink copied

### Emphasized type style tokens

link

Copy linkLink copied

link

Copy linkLink copied

## Where emphasized styles can be used

link

Copy linkLink copied

### Components

When used in components, emphasized type styles can communicate hierarchy or importance, such as an active or selected component, or an unread message. The emphasized styles work well with:

-   Badges
-   Buttons (for primary actions)
-   Extended FAB
-   Selected list items
-   Selected menu items

Material components don’t use emphasized type styles by default. To use an emphasized type style, swap the baseline token for the emphasized token of the same style. For example:

-   Baseline: md.sys.typescale.display-large
-   Emphasized: md.sys.typescale.**emphasized**.display-large

link

Copy linkLink copied

### Weight

Use the emphasized styles on text that already uses weight (such as medium, bold) to communicate hierarchy.

### Context

Use emphasized styles to draw attention to specifics aspects of components, such as selected states, unread messages, or key interactions.

Emphasized context and weight can be used at the same time.

1.  Weight: Apply emphasized styles to text already bolded for an expressive style
2.  Context: Apply emphasized styles to text in selective places to better communicate hierarchy or state

link

Copy linkLink copied

## Customize the typeface

link

Copy linkLink copied

The M3 type scale has the option to set different typefaces at different sizes. 

-   The **brand** typeface is used for larger type styles, like Headline and Display, to focus on expression. 
-   The **plain** typeface is used for smaller type styles, like Body and Label, to focus on readability. 
-   Roboto is the default for both typefaces.

Consider replacing Roboto with different typefaces to boost brand expression in your product. On emphasized styles, this can help important text stand out even more.

Roboto can be replaced with another font, like Roboto Flex

link

Copy linkLink copied

### Brand and plain typeface tokens

link

Copy linkLink copied

link

Copy linkLink copied

## Language height support

link

Copy linkLink copied

The type scale can adapt line height automatically based on language height category: small, medium, large, and extra large.

Development considerations:

-   It’s recommended to default to **medium language height**, as most languages fall in that category, and switch to other sizes based on detected language.
    
-   Material components that use **vertical padding** should adapt to language height automatically. Components with fixed heights are built for **small** values and may not adapt by default.
    
-   Ignoring language height can lead to overlapping text and broken UI elements, leading to major internationalization issues and failing readability standards.
    

Line heights for styles like **display large** can automatically adapt to language height category

link

Copy linkLink copied

### Language script categories

-   **Small (base)**: Cyrillic, Greek, Hebrew, Latin-based languages (except Vietnamese)
    
-   **Medium (~7% taller)**: Amharic, Arabic, Armenian, Bangla, Chinese, Gujarati, Hindi, Japanese, Kannada, Khmer, Korean, Lao, Malayalam, Odia, Punjabi, Sinhala, Tamil, Thai, Vietnamese, most other languages.
    
-   **Large (~30% taller)**: Burmese, Telugu
    
-   **Extra large (~100% taller)**: Nastaliq
    

link

Copy linkLink copied

### Language height tokens

To view the language height tokens:

-   Open the line height folder (Note: Other tokens like fonts and weights are in the same token set)
    
-   Change the language height context at the top of the token module
    

link

Copy linkLink copied

link

Copy linkLink copied

## Customizing type styles

link

Copy linkLink copied

To customize existing type styles, follow these steps:

1.  If using a different typeface, change the **brand** and **plain** typeface tokens. 
2.  Adjust properties like line height and letter spacing to refine the appearance. Avoid changing the type size; this can affect how components render and reflow.
3.  Repeat for both baseline and emphasized type styles. Try to keep emphasized styles visually consistent, like all wider than baseline.

Heavier fonts may require wider letter spacing, while fonts with long ascenders and descenders will require different line heights. Axes can be further adjusted as necessary.

**Note:** Customizing the M3 type scale or individual styles may prevent you from receiving typography token updates from Material.

Adjust variable axes, like weight and width, to customize fonts like Roboto Flex

link

Copy linkLink copied

Different typefaces can be used for baseline and emphasized type styles.

Custom typefaces can be used together, like Baskervville and Jacquard

link

Copy linkLink copied

## Customizing your type scale

link

Copy linkLink copied

When different sizes from the defaults are needed, such as for different devices, you can customize the **type scale** by adding or removing styles, and even swapping out Roboto for a font of your choice.

link

Copy linkLink copied

Material Design uses the [Major Second](https://cieden.com/book/sub-atomic/typography/different-type-scale-types#:~:text=with%2520dense%2520content.-,Major%2520Second%2520\(1.125\),-The%2520Major%2520Second) type scale with 14 as its key base size. This anchors to the most essential style used most often for typesetting body text.

The Material Design type scale uses the Major Second scale (1.125)

link

Copy linkLink copied

Sizes on the rendered type scale should aim to provide impactful contrast between sizes by avoiding small differences. 

Material’s default typescale of 15 styles allows distinction between each

link

Copy linkLink copied

Your product likely will not need all 15 default styles from the Material Design type scale. In this example, five sizes are chosen for a reduced set while the rest are removed.

If the default sizes from the Material Design type scale do not meet your needs, values can be changed instead. Here the default size of display medium is adjusted to another size from the Major Second type scale.

link

Copy linkLink copied

### Font size units

The following units are used to express font size on Android and the web.

link

Copy linkLink copied

| Platform | Android | Web |
| --- | --- | --- |
| Font size unit | sp | rem |
| Conversion ratio | 1.0 | 0.0625 |

Web browsers calculate the REM (the root em size) based on the root element size. The default for modern web browsers is 16px, so the conversion is SP\_SIZE/16 = rem.

link

Copy linkLink copied

#### Example conversions

| Android | Web |
| --- | --- |
| 10sp | 0.625rem |
| 12sp | 0.75rem |
| 24sp | 1.5rem |
| 60sp | 3.75rem |

link

Copy linkLink copied

### Letter spacing units

The following units are for spacing letters in a UI.

link

Copy linkLink copied

| Platform  
 | Android  
 | Web  
 |
| --- | --- | --- |
| Letter spacing unit  
 | em | rem |
| Conversion ratio  
 | (Tracking value in px / font size in sp) = letter spacing | (Tracking value in px / font size in sp) = letter spacing |

link

Copy linkLink copied

#### Letter spacing examples

| Android | Web |
| --- | --- |
| (.2 tracking / 16sp font size) = 0.0125 em  
 | (.2 tracking / 16px font size) = 0.0125 rem |

[

arrow\_left\_alt PreviousTypography: Fonts

](https://m3.material.io/styles/typography/fonts)[

Up next arrow\_right\_altTypography: Applying type

](https://m3.material.io/styles/typography/applying-type)

[material\_design](https://m3.material.io/)

Material Design is an adaptable system of guidelines, components, and tools that support the best practices of user interface design. Backed by open-source code, Material Design streamlines collaboration between designers and developers, and helps teams quickly build beautiful products.

-   Social
    
-   [GitHub](https://www.github.com/material-components)
-   [X](https://x.com/googledesign)
-   [YouTube](https://www.youtube.com/@googledesign)
-   [Blog RSS](https://material.io/feed.xml)

-   Libraries
    
-   [Android](https://m3.material.io/develop/android/mdc-android)
-   [Compose](https://m3.material.io/develop/android/jetpack-compose)
-   [Flutter](https://m3.material.io/develop/flutter)
-   [Web](https://m3.material.io/develop/web)

-   More Google sites
    
-   [Google Design](https://design.google/?home=)

-   Archived versions
    
-   [Material Design 1](https://m1.material.io/)
-   [Material Design 2](https://m2.material.io/)

-   [Privacy Policy](https://policies.google.com/privacy)
-   [Terms of Service](https://policies.google.com/terms)
-   [Join research studies](https://google.qualtrics.com/jfe/form/SV_3NMIMtX0F2zkakR?utm_source=Website&Q_Language=en&utm_campaign=Q2&campaignDate=June2022&referral_code=UXRgbtM2422655&productTag=b2d)
-   [Feedback](javascript:void\(0\))

This site uses cookies from Google to deliver its services and to analyze traffic. [Learn more](https://policies.google.com/technologies/cookies)

Okay, got it

Switch to list view

Small

Fonts & weights

Expand all

Type scale

Type scale - Emphasized

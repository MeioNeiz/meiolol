# Tooltips – Material Design 3

<https://m3.material.io/components/tooltips/guidelines>

[Skip to main content](https://m3.material.io/components/tooltips/guidelines#main_content)

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

# Tooltips

Tooltips display brief labels or messages

Resourcesandroid

[infoOverview](https://m3.material.io/components/tooltips/overview)[styleSpecs](https://m3.material.io/components/tooltips/specs)[design\_servicesGuidelines](https://m3.material.io/components/tooltips/guidelines)[accessibility\_newAccessibility](https://m3.material.io/components/tooltips/accessibility)

On this page

## Tooltips

-   Usage
-   Anatomy
-   Placement
-   Behavior

link

Copy linkLink copied

Plain and rich tooltips serve different purposes

link

Copy linkLink copied

## Usage

link

Copy linkLink copied

A tooltip provides additional context for a UI element. 

**Plain tooltips**  
Plain tooltips briefly describe a UI element. They're best used for labelling UI elements with no text, like icon-only buttons and fields.

**Rich tooltips**  
Rich tooltips provide additional context about a UI element. They can optionally contain a subhead, buttons, and hyperlinks.

Rich tooltips are best used for longer text like definitions or explanations.

1.  Plain tooltip
2.  Rich tooltip

link

Copy linkLink copied

check Do

Use plain tooltips to label icon-only buttons

close Don’t

Plain tooltips aren't needed when the UI element already has label text

link

Copy linkLink copied

check Do

Use rich tooltips to provide extra information and actions about a UI element or new feature

close Don’t

Don't hide critical information within tooltips as it’s easy to miss. Use an interruptive dialog instead.

link

Copy linkLink copied

## Anatomy

link

Copy linkLink copied

### Plain tooltip

link

Copy linkLink copied

1.  Container
2.  Supporting text

link

Copy linkLink copied

### Supporting text

link

Copy linkLink copied

check Do

Briefly describe a UI element

exclamation Caution

Avoid wrapping text to multiple lines or including many pieces of information

link

Copy linkLink copied

### Rich tooltip

link

Copy linkLink copied

1.  Subhead (optional)
2.  Container
3.  Supporting text
4.  Text button (optional)

link

Copy linkLink copied

### Subhead (optional)

Keep subheads brief, ideally to one line. They should summarize or describe the message of the rich tooltip.

Subheads are important to include when the rich tooltip appears automatically, like when the page loads.

check Do

Summarize the message in a few words

close Don’t

Avoid wrapping to more than one line

link

Copy linkLink copied

### Text buttons (optional)

Rich tooltips can have up to two text buttons. These should be brief and relevant to the message in the supporting text.

Keep buttons short so they can be side by side. Avoid stacking them when possible.

exclamation Caution

Avoid stacking buttons

link

Copy linkLink copied

## Placement

link

Copy linkLink copied

### Plain tooltips

By default, plain tooltips are positioned directly above the parent element. 

-   If there's a visual boundary, like a button, the distance is 4dp
-   If there's no visual boundary, like with text baselines, the distance is 8dp

If the element is in an app bar, the plain tooltip appears below the element at the same distance.

Plain tooltip with a 4dp distance between the target and tooltip

link

Copy linkLink copied

### Rich tooltips

By default, rich tooltips are positioned to the bottom right of the parent element. They adjust position to avoid going off screen.  Tooltips shouldn't cover the parent element. 

**Dynamic positioning**  
The position of the tooltip adjusts in increments of 8dp to avoid going off-screen.

**Desktop placement**  
On desktop, tooltips may appear centered below the parent element and remain visible while moving within the target region.

Four different rich tooltip locations based on dynamic positioning

link

Copy linkLink copied

## Behavior

link

Copy linkLink copied

To show a tooltip, hover on the parent element on desktop, or tap and hold the element on mobile. Persistent rich tooltips only appear when clicked or tapped.

link

Copy linkLink copied

### Transient by default

Both plain and rich tooltips disappear 1.5 seconds after navigating away from the target region.

Triggering a new tooltip immediately closes any other open tooltip.

Tooltips disappear after a 1.5 second delay when no other element is hovered

link

Copy linkLink copied

close Don’t

Only display one tooltip at a time

link

Copy linkLink copied

### Persistent rich tooltips

Persistent rich tooltips appear when either:

-   The parent element is clicked
-   The page loads and a new feature is being explained

Persistent rich tooltips remain active even when leaving the target region. They only disappear once a person interacts with another UI element. Hovering doesn't trigger the tooltip.

When appearing on page load, the tooltip can introduce and explain new features on various parent elements.

Avoid using persistent rich tooltips on icon buttons.

close Don’t

Don’t use a persistent rich tooltip on icon buttons

[

arrow\_left\_alt PreviousTooltips: Specs

](https://m3.material.io/components/tooltips/specs)[

Up next arrow\_right\_altTooltips: Accessibility

](https://m3.material.io/components/tooltips/accessibility)

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

# Understanding Success Criterion 2.5.5: Target Size (Enhanced) | WAI | W3C

<https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html>

[Skip to content](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#main)

[WCAG 2.2 Understanding Docs](https://www.w3.org/WAI/WCAG22/Understanding/)

Informative explanations, not required to meet WCAG

[About WCAG Understanding Docs](https://www.w3.org/WAI/WCAG22/Understanding/about)

-   [All Understanding Docs](https://www.w3.org/WAI/WCAG22/Understanding/)
-   [Guideline: Input Modalities](https://www.w3.org/WAI/WCAG22/Understanding/input-modalities)
-   [Previous SC: Motion Actuation](https://www.w3.org/WAI/WCAG22/Understanding/motion-actuation)
-   [Next SC: Concurrent Input Mechanisms](https://www.w3.org/WAI/WCAG22/Understanding/concurrent-input-mechanisms)

Page Contents

-   [In Brief](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#brief)
-   [Success Criterion](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#success-criterion)
-   [Intent](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#intent)
-   [Benefits](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#benefits)
-   [Examples](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#examples)
-   [Related Resources](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#resources)
-   [Techniques](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#techniques)
-   [Key Terms](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#key-terms)

# Understanding [SC 2.5.5](https://w3.org/TR/WCAG22#target-size-enhanced) Target Size (Enhanced) (Level AAA)

## In Brief

Goal

Controls can be operated more easily, especially on touchscreens.

What to do

Make custom targets at least 44 by 44 pixels.

Why it's important

Some people cannot tap small objects.

## Success Criterion (SC)

The size of the [target](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#dfn-target) for [pointer inputs](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#dfn-pointer-input) is at least 44 by 44 [CSS pixels](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#dfn-css-pixel) except when:

Equivalent

The target is available through an equivalent link or control on the same page that is at least 44 by 44 CSS pixels;

Inline

The target is in a sentence or [block of text](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#dfn-blocks-of-text);

User Agent Control

The size of the target is determined by the [user agent](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#dfn-user-agent) and is not modified by the author;

Essential

A particular [presentation](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#dfn-presentation) of the target is [essential](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#dfn-essential) to the information being conveyed.

## Intent

The intent of this success criterion is to help users who may have trouble activating a small target because of hand tremors, limited dexterity, or other reasons. If the target is too small, it may be difficult to aim at the target. Mice and similar pointing devices can be hard to use for these users, and a larger target will help them greatly in having positive outcomes on the web page.

Touch is particularly problematic as it is an input mechanism with coarse precision. Users lack the same level of fine control as on inputs such as a mouse or stylus. A finger is larger than a mouse pointer, and generally obstructs the user's view of the precise location on the screen that is being touched/activated.

The issue can be further complicated for responsive and mobile sites that need to accommodate different types of fine and coarse inputs (for example, a site that can be accessed on a traditional desktop or laptop with a mouse, as well as on a tablet or mobile phone with a touchscreen).

While this criterion defines a minimum target size, it is recommended that larger sizes are used to reduce the possibility of unintentional actions. This is particularly relevant if any of the following are true:

-   the control is used frequently;
-   the result of the interaction cannot be easily undone;
-   the control is positioned where it will be difficult to reach, or is near the edge of the screen;
-   the control is part of a sequential task.

The targets on a screen can have different purposes and uses, and this success criterion specifies how each is to be handled.

**Equivalent targets:** If there is more than one target on a screen that performs the same action, only one of the targets need to meet the target size of 44 by 44 CSS pixels.

**Inline:** The success criterion does not apply to inline targets in sentences or blocks of text. Content is often designed to reflow based on the screen width available. This is known as responsive design and makes it easier to read since you do not need to scroll both horizontally and vertically. In reflowed content, the targets can appear anywhere on a line and can change position based on the width of the available screen. Since targets can appear anywhere on the line, the size cannot be larger than the available text and spacing between the sentences or paragraphs, otherwise the targets could overlap. It is for this reason targets which are contained within one or more sentences are excluded from the target size requirements.

Note

If the target is the full sentence and the sentence is not in a block of text, then the target needs to be at least 44 by 44 CSS pixels.

Note

A footnote or an icon within or at the end of a sentence is considered to be part of a sentence and therefore are excluded from the minimum target size.

**User Agent Control:** If the size of the target is not modified by the author through CSS or other size properties, then the target does not need to meet the target size of 44 by 44 CSS pixels.

**Essential:** If the target is required to be a particular target size and cannot be provided in another way, while changing it would essentially change the information or functionality of the content, then the target does not need to meet the target size of 44 by 44 CSS pixels.

## Benefits

-   Users who use a mobile device where a touchscreen is the primary mode of interaction
-   Users with mobility impairments, such as hand tremors
-   Users who use a mobile device in environments where they are exposed to shaking such as public transportation
-   Users who find fine motor movements difficult
-   Users who access a device using one hand
-   Users with large fingers, or who are operating the device with only a part of their finger or knuckle
-   Users who have low vision may better see the target

## Examples

Example 1: Buttons

Three buttons are on-screen and the touch target area of each button is 44 by 44 CSS pixels.

Example 2: Equivalent target

Multiple targets are provided on the page that perform the same function. One of the targets is 44 by 44 CSS pixels. The other targets do not have a minimum touch target of 44 by 44 CSS pixels.

Example 3: Text Link in a paragraph

Links within a paragraph of text have varying touch target dimensions. Links within paragraphs of text do no need to meet the 44 by 44 CSS pixels requirements.

Example 4: Text Link in a sentence

A text link that is in a sentence is excluded and does not need to meet the 44 by 44 CSS pixel requirement. If the text link is the full sentence, then the text link target touch area does need to meet the 44 by 44 CSS pixels.

Example 5: Footnote

A footnote link at the end of a sentence does not need to meet the 44 by 44 CSS pixels requirements. The footnote at the end of the sentence is considered to be part of the sentence.

Example 6: Help icon

A help icon within or at the end of a sentence does not need to meet the 44 by 44 CSS pixels requirements. The icon at the end of the sentence is considered to be part of the sentence.

## Related Resources

Resources are for information purposes only, no endorsement implied.

-   [Pointing devices / Apple Developer Documentation](https://developer.apple.com/design/human-interface-guidelines/pointing-devices)
-   [Windows UWP Guidelines for touch targets](https://learn.microsoft.com/en-us/windows/apps/develop/input/guidelines-for-targeting)
-   [Google Material Design Touch targets](https://m2.material.io/design/layout/spacing-methods.html)
-   [web.dev Accessible tap targets](https://web.dev/articles/accessible-tap-targets)
-   [Human Fingertips to Investigate the Mechanics of Tactile Sense (PDF)](http://touchlab.mit.edu/publications/2003_009.pdf)
-   [One-Handed Thumb Use on Small Touchscreen Devices](https://www.cs.umd.edu/hcil/trs/2006-11/2006-11.htm)

## Techniques

Each item in this section represents a technique or combination of techniques that the Accessibility Guidelines Working Group deems sufficient for meeting this success criterion. A technique may go beyond the minimum requirement of the criterion. There may be other ways of meeting the criterion not covered by these techniques. For information on using other techniques, see [Understanding Techniques for WCAG Success Criteria](https://www.w3.org/WAI/WCAG22/Understanding/understanding-techniques), particularly the "Other Techniques" section.

### Sufficient Techniques

-   [C44: Using CSS to ensure targets are at least 44 by 44 CSS pixels](https://www.w3.org/WAI/WCAG22/Techniques/css/C44)

### Advisory Techniques

Although not required for conformance, the following additional techniques should be considered in order to make content more accessible. Not all techniques can be used or would be effective in all situations.

-   Ensuring inline links provide sufficiently large activation target

### Failures

The following are common mistakes that are considered failures of this success criterion by the Accessibility Guidelines Working Group.

-   Failure of Success Criterion 2.5.5 due to target being less than 44 by 44 CSS pixels

## Key Terms

[Back to Top](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html#top)

## Help improve this page

Please share your ideas, suggestions, or comments via email to the publicly-archived list [public-agwg-comments@w3.org](mailto:public-agwg-comments@w3.org?subject=%5BUnderstanding%20and%20Techniques%20Feedback%5D) or via GitHub

[Email](mailto:public-agwg-comments@w3.org?subject=%5BUnderstanding%20and%20Techniques%20Feedback%5D) [Fork & Edit on GitHub](https://github.com/w3c/wcag/edit/main/understanding/21/target-size-enhanced.html) [New GitHub Issue](https://github.com/w3c/wcag/issues/new)

**Date:** Updated 06 September 2026. [View this page's revision history.](https://github.com/w3c/wcag/commits/main/understanding/21/target-size-enhanced.html)

**Developed by** [Accessibility Guidelines Working Group (AG WG) Participants](https://www.w3.org/groups/wg/ag/participants) (Co-Chairs: Adam Page, Alastair Campbell, Rachael Bradley Montgomery. W3C Staff Contact: Kevin White).

The content was developed as part of the [WAI-Core projects](https://www.w3.org/WAI/about/projects/#us) funded by U.S. Federal funds. The user interface was designed by the Education and Outreach Working Group ([EOWG](https://www.w3.org/groups/wg/eowg/participants)) with contributions from Shadi Abou-Zahra, Steve Lee, and Shawn Lawton Henry as part of the [WAI-Guide](https://www.w3.org/WAI/about/projects/wai-guide/) project, co-funded by the European Commission.

[W3C Web Accessibility Initiative (WAI)](https://www.w3.org/WAI/)

Strategies, standards, resources to make the Web accessible to people with disabilities

-    [Get News in Email](https://www.w3.org/WAI/news/subscribe/)
-    [LinkedIn](https://www.linkedin.com/company/w3c-wai/)
-    [Mastodon](https://w3c.social/@wai)
-    [YouTube](https://www.youtube.com/channel/UCU6ljj3m1fglIPjSjs2DpRA/playlists/)

-   [Home](https://www.w3.org/WAI/)
-   [Contact](https://www.w3.org/WAI/about/contacting/)
-   [Site map](https://www.w3.org/WAI/sitemap/)
-   [Support WAI](https://www.w3.org/WAI/about/support/)
-   [News](https://www.w3.org/WAI/news/)
-   [Accessibility statement](https://www.w3.org/WAI/about/accessibility-statement/)
-   [All Translations](https://www.w3.org/WAI/translations/)
-   [Resources for roles](https://www.w3.org/WAI/roles/)

Copyright © 2026 [World Wide Web Consortium](https://www.w3.org/).  
W3C® [liability](https://www.w3.org/policies/#disclaimers), [trademark](https://www.w3.org/policies/#trademarks) and [permissive license](https://www.w3.org/copyright/software-license/ "W3C Software License") rules apply unless otherwise noted. See [Permission to Use WAI Material](https://www.w3.org/WAI/about/using-wai-material/).

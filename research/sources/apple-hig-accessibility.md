---
title: 'Apple Human Interface Guidelines: Accessibility'
url: https://developer.apple.com/design/human-interface-guidelines/accessibility
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (vision: text size, contrast, colour; mobility: control size)
relevance: high
grade: A/fair
description: Apple HIG accessibility page: control sizes per platform (iOS 44x44 pt default, 28x28 pt minimum), 12 or 24 pt padding, WCAG AA contrast table, more than colour alone (names red-green and blue-orange)
---
# Apple Human Interface Guidelines: Accessibility

Why: the source of the "44 pt" touch target, and Apple's colour rules.

## Assessment

- Evidence: A. Apple's platform guidelines, followed by every iOS app; living page.
- Reasoning: fair. Rules with short reasons, no studies cited.
- Interests: platform owner.
- Weigh: pt on iOS maps to CSS px at 1x on the web (both are density independent), so
  44 pt reads as about 44 CSS px for a phone browser (inferred). The page now gives 44 as
  the default and 28 as a minimum, softer than the older "44 minimum" folklore.

## Findings

- [ux/layout] Control sizes per platform: iOS and iPadOS default 44x44 pt, minimum 28x28 pt; macOS 28 and 20. Mobility ^f1
  > Strive to meet the recommended minimum control size for each platform to ensure controls and menus are comfortable for all when tapping and clicking.
  > iOS, iPadOS | 44x44 pt | 28x28 pt
- [ux/layout] Spacing counts as much as size: about 12 pt padding round bezelled elements, about 24 pt round unbezelled ones. Mobility ^f2
  > In general, it works well to add about 12 points of padding around elements that include a bezel. For elements without a bezel, about 24 points of padding works well around the element’s visible edges.
- [ux/colour] Contrast: Accessibility Inspector uses WCAG AA, 4.5:1 for text up to 17 pt, 3:1 at 18 pt and up. Vision ^f3
  > Accessibility Inspector uses the following values from WCAG Level AA as guidance in determining whether your app’s colors have an acceptable contrast.
  > Up to 17 pts | All | 4.5:1
- [ux/colour] More than colour alone; Apple names blue-orange, not only red-green, as hard for colour-blind people. Vision ^f4
  > For example, people who are color blind may have particular difficulty with pairings such as red-green and blue-orange. Offer visual indicators, like distinct shapes or icons, in addition to color to help people perceive differences in function and changes in state.
- [ux/colour] Prefer system-defined colours, which have accessible variants for increased contrast and dark mode. Vision ^f5
  > Prefer system-defined colors. These colors have their own accessible variants that automatically adapt when people adjust their color preferences
- [ux/layout] Let text enlarge by at least 200 percent. Vision ^f6
  > Ideally, give people the option to enlarge text by at least 200 percent

## Read

- Vision and Mobility sections

## Not read

- Hearing, speech, cognitive sections; VoiceOver details

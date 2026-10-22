# web-features 3.44.0 (npm, published 2026-10-22): extract of data.json

Extract of selected features from web-features data.json. One line per feature, then compat keys that are not Baseline high. Fields copied verbatim from the JSON.

## popover

name: Popover

description: The popover HTML attribute creates an overlay to display content on top of other page content. Popovers can be shown declaratively using HTML, or using the showPopover() method.

baseline: low; baseline_low_date: 2025-01-27; baseline_high_date: None

support: chrome 116, chrome_android 116, edge 116, firefox 125, firefox_android 125, safari 17, safari_ios 18.3

- compat key api.HTMLElement.popover: baseline low, low date 2025-01-27; support: chrome 114, chrome_android 114, edge 114, firefox 125, firefox_android 125, safari 17, safari_ios 18.3
- compat key api.HTMLElement.showPopover.options_source_parameter: baseline low, low date 2025-10-14; support: chrome 137, chrome_android 137, edge 137, firefox 144, firefox_android 144, safari 26, safari_ios 26
- compat key api.HTMLElement.togglePopover.options_source_parameter: baseline low, low date 2025-10-14; support: chrome 137, chrome_android 137, edge 137, firefox 144, firefox_android 144, safari 26, safari_ios 26

## popover-hint

name: popover="hint"

description: The popover="hint" global HTML attribute creates a popover that is subordinate to popovers with a popover="auto" attribute. You can use this to create tooltips that don't dismiss auto popovers.

baseline: False; baseline_low_date: None; baseline_high_date: None

support: chrome 151, chrome_android 151, edge 151, firefox 153, firefox_android 153

- compat key api.HTMLElement.popover.hint: baseline False, low date None; support: chrome 151, chrome_android 151, edge 151, firefox 153, firefox_android 153
- compat key html.global_attributes.popover.hint: baseline False, low date None; support: chrome 151, chrome_android 151, edge 151, firefox 153, firefox_android 153

## dialog

name: <dialog>

description: The <dialog> HTML element represents a modal or non-modal dialog box, such as a confirmation prompt or a subwindow used to enter data.

baseline: high; baseline_low_date: 2022-03-14; baseline_high_date: 2024-09-14

support: chrome 37, chrome_android 37, edge 79, firefox 98, firefox_android 98, safari 15.4, safari_ios 15.4

- compat key api.HTMLElement.beforetoggle_event.dialog_elements: baseline low, low date 2025-09-15; support: chrome 132, chrome_android 132, edge 132, firefox 133, firefox_android 133, safari 26, safari_ios 26
- compat key api.HTMLElement.toggle_event.dialog_elements: baseline low, low date 2025-09-15; support: chrome 132, chrome_android 132, edge 132, firefox 133, firefox_android 133, safari 26, safari_ios 26

## dialog-closedby

name: <dialog closedby>

description: The closedby HTML attribute for <dialog> sets which user actions close a dialog. For example, closedby="any" allows the dialog to be closed by clicking outside of it.

baseline: False; baseline_low_date: None; baseline_high_date: None

support: chrome 134, chrome_android 134, edge 134, firefox 141, firefox_android 141

- compat key api.HTMLDialogElement.closedBy: baseline False, low date None; support: chrome 134, chrome_android 134, edge 134, firefox 141, firefox_android 141
- compat key html.elements.dialog.closedby: baseline False, low date None; support: chrome 134, chrome_android 134, edge 134, firefox 141, firefox_android 141

## invoker-commands

name: Invoker commands

description: The command and commandfor attributes for the <button> HTML element dispatch an action to an element when the button is invoked (by click or keystroke), as a declarative alternative to addEventListener() calls or onclick attribute handlers.

baseline: low; baseline_low_date: 2025-12-12; baseline_high_date: None

support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2

- compat key api.CommandEvent: baseline low, low date 2025-12-12; support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2
- compat key api.CommandEvent.CommandEvent: baseline low, low date 2025-12-12; support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2
- compat key api.CommandEvent.command: baseline low, low date 2025-12-12; support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2
- compat key api.CommandEvent.source: baseline low, low date 2025-12-12; support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2
- compat key api.HTMLButtonElement.command: baseline low, low date 2025-12-12; support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2
- compat key api.HTMLButtonElement.commandForElement: baseline low, low date 2025-12-12; support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2
- compat key api.HTMLElement.command_event: baseline low, low date 2025-12-12; support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2
- compat key html.elements.button.command: baseline low, low date 2025-12-12; support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2
- compat key html.elements.button.commandfor: baseline low, low date 2025-12-12; support: chrome 135, chrome_android 135, edge 135, firefox 144, firefox_android 144, safari 26.2, safari_ios 26.2

## interest-invokers

name: Interest invokers

description: Interest invokers, registered by the interestfor HTML attribute, trigger events and actions on a target element when a user shows interest in the element, through behaviors such as hover, focus, or long-press. Pseudo-elements apply styles to sources and targets of interest.

baseline: False; baseline_low_date: None; baseline_high_date: None

support: chrome 142, chrome_android 142, edge 142

- compat key api.HTMLAnchorElement.interestForElement: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key api.HTMLAreaElement.interestForElement: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key api.HTMLButtonElement.interestForElement: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key api.HTMLElement.interest_event: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key api.HTMLElement.loseinterest_event: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key api.InterestEvent: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key api.InterestEvent.InterestEvent: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key api.InterestEvent.source: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key api.SVGAElement.interestForElement: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key css.selectors.interest-source: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key css.selectors.interest-target: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key html.elements.a.interestfor: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key html.elements.area.interestfor: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key html.elements.button.interestfor: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142
- compat key svg.elements.a.interestfor: baseline False, low date None; support: chrome 142, chrome_android 142, edge 142

## details-name

name: Mutually exclusive <details> elements

description: Multiple <details> elements which use the same name attribute are mutually exclusive. When one member of the group is opened, all other members are closed.

baseline: low; baseline_low_date: 2024-09-03; baseline_high_date: None

support: chrome 120, chrome_android 120, edge 120, firefox 130, firefox_android 130, safari 17.2, safari_ios 17.2

- compat key api.HTMLDetailsElement.name: baseline low, low date 2024-09-03; support: chrome 120, chrome_android 120, edge 120, firefox 130, firefox_android 130, safari 17.2, safari_ios 17.2
- compat key html.elements.details.name: baseline low, low date 2024-09-03; support: chrome 120, chrome_android 120, edge 120, firefox 130, firefox_android 130, safari 17.2, safari_ios 17.2

## details-content

name: ::details-content

description: The ::details-content pseudo-element selects the expandable content of a <details> element, excluding the <summary>.

baseline: low; baseline_low_date: 2025-09-16; baseline_high_date: None

support: chrome 131, chrome_android 131, edge 131, firefox 143, firefox_android 143, safari 18.4, safari_ios 18.4

- compat key css.selectors.details-content: baseline low, low date 2025-09-16; support: chrome 131, chrome_android 131, edge 131, firefox 143, firefox_android 143, safari 18.4, safari_ios 18.4

## customizable-select

name: Customizable <select>

description: The <select> element's appearance, including the button, selected option, picker dropdown, and options, can be customized using CSS.

baseline: False; baseline_low_date: None; baseline_high_date: None

support: chrome 135, chrome_android 135, edge 135, safari 27, safari_ios 27

- compat key css.properties.appearance.base-select: baseline False, low date None; support: chrome 135, chrome_android 135, edge 135, safari 27, safari_ios 27
- compat key css.selectors.checkmark: baseline False, low date None; support: chrome 133, chrome_android 133, edge 133, safari 27, safari_ios 27
- compat key css.selectors.picker: baseline False, low date None; support: chrome 135, chrome_android 135, edge 135, safari 27, safari_ios 27
- compat key css.selectors.picker-icon: baseline False, low date None; support: chrome 133, chrome_android 133, edge 133, safari 27, safari_ios 27
- compat key html.elements.selectedcontent: baseline False, low date None; support: chrome 135, chrome_android 135, edge 135, safari 27, safari_ios 27

## anchor-positioning

name: Anchor positioning

description: Anchor positioning places an element based on the position of another element. For example, you can place a tooltip next to the content it references.

baseline: False; baseline_low_date: None; baseline_high_date: None

support: safari 27, safari_ios 27

- compat key api.CSSPositionTryDescriptors: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.align-self: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.alignSelf: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.block-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.blockSize: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.bottom: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.height: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.inline-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.inlineSize: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.inset: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.inset-block: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.inset-block-end: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.inset-block-start: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.inset-inline: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.inset-inline-end: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.inset-inline-start: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.insetBlock: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.insetBlockEnd: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.insetBlockStart: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.insetInline: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.insetInlineEnd: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.insetInlineStart: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.justify-self: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.justifySelf: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.left: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-block: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-block-end: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-block-start: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-bottom: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-inline: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-inline-end: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-inline-start: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-left: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-right: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.margin-top: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginBlock: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginBlockEnd: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginBlockStart: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginBottom: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginInline: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginInlineEnd: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginInlineStart: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginLeft: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginRight: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.marginTop: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.max-block-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.max-height: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.max-inline-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.max-width: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.maxBlockSize: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.maxHeight: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.maxInlineSize: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.maxWidth: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.min-block-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.min-height: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.min-inline-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.min-width: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.minBlockSize: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.minHeight: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.minInlineSize: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.minWidth: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.place-self: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.placeSelf: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.position-anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.position-area: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.positionAnchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.positionArea: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.right: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.top: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryDescriptors.width: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryRule: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryRule.name: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.CSSPositionTryRule.style: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.HTMLButtonElement.commandForElement.implicit_anchor_reference: baseline low, low date 2026-01-13; support: chrome 135, chrome_android 135, edge 135, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key api.HTMLButtonElement.popoverTargetElement.implicit_anchor_reference: baseline low, low date 2026-01-13; support: chrome 133, chrome_android 133, edge 133, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.HTMLElement.showPopover.options_source_parameter.implicit_anchor_reference: baseline low, low date 2026-01-13; support: chrome 137, chrome_android 137, edge 137, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.HTMLElement.togglePopover.options_source_parameter.implicit_anchor_reference: baseline low, low date 2026-01-13; support: chrome 137, chrome_android 137, edge 137, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key api.HTMLInputElement.popoverTargetElement.implicit_anchor_reference: baseline low, low date 2026-01-13; support: chrome 133, chrome_android 133, edge 133, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.at-rules.position-try: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.align-items.anchor-center: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.align-self.anchor-center: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.anchor-name: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.anchor-name.none: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.anchor-scope: baseline low, low date 2026-01-13; support: chrome 131, chrome_android 131, edge 131, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.anchor-scope.all: baseline low, low date 2026-01-13; support: chrome 131, chrome_android 131, edge 131, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.anchor-scope.none: baseline low, low date 2026-01-13; support: chrome 131, chrome_android 131, edge 131, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.block-size.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.bottom.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.bottom.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.height.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inline-size.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-block-end.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-block-end.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-block-start.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-block-start.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-block.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-block.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-inline-end.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-inline-end.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-inline-start.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-inline-start.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-inline.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset-inline.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.inset.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.justify-items.anchor-center: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.justify-self.anchor-center: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.left.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.left.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-block-end.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-block-start.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-block.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-bottom.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-inline-end.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-inline-start.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-inline.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-left.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-right.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin-top.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.margin.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.max-block-size.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.max-height.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.max-inline-size.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.max-width.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.min-block-size.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.min-height.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.min-inline-size.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.min-width.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.place-items.anchor-center: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.place-self.anchor-center: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-anchor: baseline low, low date 2026-09-14; support: chrome 151, chrome_android 151, edge 151, firefox 151, firefox_android 151, safari 27, safari_ios 27
- compat key css.properties.position-anchor.auto: baseline low, low date 2026-09-14; support: chrome 151, chrome_android 151, edge 151, firefox 151, firefox_android 151, safari 27, safari_ios 27
- compat key css.properties.position-anchor.none: baseline low, low date 2026-09-14; support: chrome 151, chrome_android 151, edge 151, firefox 151, firefox_android 151, safari 27, safari_ios 27
- compat key css.properties.position-anchor.normal: baseline low, low date 2026-09-14; support: chrome 151, chrome_android 151, edge 151, firefox 151, firefox_android 151, safari 27, safari_ios 27
- compat key css.properties.position-area: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.block-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.block-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.bottom: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.center: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.disables_auto_margins_and_insets: baseline low, low date 2026-02-24; support: chrome 143, chrome_android 143, edge 143, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-area.end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.inline-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.inline-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.left: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.none: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.right: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.self-block-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.self-block-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.self-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.self-inline-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.self-inline-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.self-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.self-x-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-area.self-x-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-area.self-y-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-area.self-y-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-area.span-all: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.span-block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-bottom: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-left: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-right: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-self-block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-self-block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-self-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-self-inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-self-inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-self-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-self-x-end: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-area.span-self-x-start: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-area.span-self-y-end: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-area.span-self-y-start: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-area.span-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-top: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-x-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-x-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-y-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.span-y-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-area.top: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.x-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.x-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.y-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-area.y-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-try: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks: baseline low, low date 2026-01-13; support: chrome 128, chrome_android 128, edge 128, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.bottom: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.center: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.flip-block: baseline low, low date 2026-01-13; support: chrome 128, chrome_android 128, edge 128, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.flip-inline: baseline low, low date 2026-01-13; support: chrome 128, chrome_android 128, edge 128, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.flip-start: baseline low, low date 2026-01-13; support: chrome 128, chrome_android 128, edge 128, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.flip-x: baseline low, low date 2026-01-21; support: chrome 144, chrome_android 144, edge 144, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.flip-y: baseline low, low date 2026-01-21; support: chrome 144, chrome_android 144, edge 144, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.left: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.none: baseline low, low date 2026-01-13; support: chrome 128, chrome_android 128, edge 128, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.position-area: baseline low, low date 2026-01-13; support: chrome 128, chrome_android 128, edge 128, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.right: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.self-block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.self-block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.self-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.self-inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.self-inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.self-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.self-x-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.self-x-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.self-y-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.self-y-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.span-all: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-bottom: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-left: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-right: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-self-block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-self-block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-self-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-self-inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-self-inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-self-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-self-x-end: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.span-self-x-start: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.span-self-y-end: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.span-self-y-start: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try-fallbacks.span-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-top: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-x-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-x-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-y-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.span-y-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.top: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.x-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.x-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.y-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-fallbacks.y-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try-order: baseline low, low date 2026-02-24; support: chrome 125, chrome_android 125, edge 125, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-try-order.most-block-size: baseline low, low date 2026-02-24; support: chrome 125, chrome_android 125, edge 125, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-try-order.most-height: baseline low, low date 2026-02-24; support: chrome 125, chrome_android 125, edge 125, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-try-order.most-inline-size: baseline low, low date 2026-02-24; support: chrome 125, chrome_android 125, edge 125, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-try-order.most-width: baseline low, low date 2026-02-24; support: chrome 125, chrome_android 125, edge 125, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-try-order.normal: baseline low, low date 2026-02-24; support: chrome 125, chrome_android 125, edge 125, firefox 148, firefox_android 148, safari 26, safari_ios 26
- compat key css.properties.position-try.block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.bottom: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.center: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.flip-block: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.flip-inline: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.flip-start: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.flip-x: baseline low, low date 2026-01-21; support: chrome 144, chrome_android 144, edge 144, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.flip-y: baseline low, low date 2026-01-21; support: chrome 144, chrome_android 144, edge 144, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.left: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.none: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.right: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.self-block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.self-block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.self-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.self-inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.self-inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.self-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.self-x-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.self-x-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.self-y-end: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.self-y-start: baseline low, low date 2026-02-24; support: chrome 144, chrome_android 144, edge 144, firefox 148, firefox_android 148, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.span-all: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-bottom: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-left: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-right: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-self-block-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-self-block-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-self-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-self-inline-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-self-inline-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-self-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-self-x-end: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.span-self-x-start: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.span-self-y-end: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.span-self-y-start: baseline low, low date 2026-01-13; support: chrome 143, chrome_android 143, edge 143, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-try.span-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-top: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-x-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-x-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-y-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.span-y-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.top: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.x-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.x-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.y-end: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-try.y-start: baseline low, low date 2026-01-13; support: chrome 129, chrome_android 129, edge 129, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.position-visibility: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-visibility.always: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.position-visibility.anchor-valid: baseline False, low date None; support: safari 27, safari_ios 27
- compat key css.properties.position-visibility.anchor-visible: baseline False, low date None; support: safari 27, safari_ios 27
- compat key css.properties.position-visibility.no-overflow: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key css.properties.right.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.right.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.top.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.top.anchor-size: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.properties.width.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.types.anchor: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.types.anchor-size: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key css.types.anchor-size.inset_margin: baseline low, low date 2026-01-13; support: chrome 132, chrome_android 132, edge 132, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key html.elements.button.commandfor.implicit_anchor_reference: baseline low, low date 2026-01-13; support: chrome 135, chrome_android 135, edge 135, firefox 147, firefox_android 147, safari 26.2, safari_ios 26.2
- compat key html.elements.button.popovertarget.implicit_anchor_reference: baseline low, low date 2026-01-13; support: chrome 133, chrome_android 133, edge 133, firefox 147, firefox_android 147, safari 26, safari_ios 26
- compat key html.elements.input.popovertarget.implicit_anchor_reference: baseline low, low date 2026-01-13; support: chrome 133, chrome_android 133, edge 133, firefox 147, firefox_android 147, safari 26, safari_ios 26

## has

name: :has()

description: The :has() CSS functional pseudo-class matches an element if any of the selectors passed as parameters would match at least one element.

baseline: high; baseline_low_date: 2023-12-19; baseline_high_date: 2026-06-19

support: chrome 105, chrome_android 105, edge 105, firefox 121, firefox_android 121, safari 15.4, safari_ios 15.4


## view-transitions

name: View transitions

description: View transitions allow you to create animated visual transitions between different states of a document.

baseline: low; baseline_low_date: 2025-10-14; baseline_high_date: None

support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18

- compat key api.Document.startViewTransition: baseline low, low date 2025-10-14; support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key api.Document.startViewTransition.options_parameter: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 18.2, safari_ios 18.2
- compat key api.Document.startViewTransition.options_parameter.types_parameter: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 18.2, safari_ios 18.2
- compat key api.Document.startViewTransition.options_parameter.update_parameter: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 18.2, safari_ios 18.2
- compat key api.Document.startViewTransition.updateCallback_parameter: baseline low, low date 2025-10-14; support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key api.PageRevealEvent: baseline False, low date None; support: chrome 123, chrome_android 123, edge 123, safari 18.2, safari_ios 18.2
- compat key api.PageRevealEvent.PageRevealEvent: baseline False, low date None; support: chrome 128, chrome_android 128, edge 128, safari 18.2, safari_ios 18.2
- compat key api.PageRevealEvent.viewTransition: baseline False, low date None; support: chrome 126, chrome_android 126, edge 126, safari 18.2, safari_ios 18.2
- compat key api.PageSwapEvent: baseline False, low date None; support: chrome 124, chrome_android 124, edge 124, safari 18.2, safari_ios 18.2
- compat key api.PageSwapEvent.PageSwapEvent: baseline False, low date None; support: chrome 128, chrome_android 128, edge 128, safari 18.2, safari_ios 18.2
- compat key api.PageSwapEvent.activation: baseline False, low date None; support: chrome 124, chrome_android 124, edge 124, safari 18.2, safari_ios 18.2
- compat key api.PageSwapEvent.viewTransition: baseline False, low date None; support: chrome 126, chrome_android 126, edge 126, safari 18.2, safari_ios 18.2
- compat key api.ViewTransition: baseline low, low date 2025-10-14; support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key api.ViewTransition.finished: baseline low, low date 2025-10-14; support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key api.ViewTransition.ready: baseline low, low date 2025-10-14; support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key api.ViewTransition.skipTransition: baseline low, low date 2025-10-14; support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key api.ViewTransition.updateCallbackDone: baseline low, low date 2025-10-14; support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key api.Window.pagereveal_event: baseline False, low date None; support: chrome 123, chrome_android 123, edge 123, safari 18.2, safari_ios 18.2
- compat key api.Window.pageswap_event: baseline False, low date None; support: chrome 124, chrome_android 124, edge 124
- compat key css.properties.view-transition-name: baseline low, low date 2025-10-14; support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key css.properties.view-transition-name.match-element: baseline low, low date 2025-10-14; support: chrome 137, chrome_android 137, edge 137, firefox 144, firefox_android 144, safari 18.4, safari_ios 18.4
- compat key css.properties.view-transition-name.none: baseline low, low date 2025-10-14; support: chrome 111, chrome_android 111, edge 111, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key css.selectors.view-transition: baseline low, low date 2025-10-14; support: chrome 109, chrome_android 109, edge 109, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key css.selectors.view-transition-group: baseline low, low date 2025-10-14; support: chrome 109, chrome_android 109, edge 109, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key css.selectors.view-transition-image-pair: baseline low, low date 2025-10-14; support: chrome 109, chrome_android 109, edge 109, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key css.selectors.view-transition-new: baseline low, low date 2025-10-14; support: chrome 109, chrome_android 109, edge 109, firefox 144, firefox_android 144, safari 18, safari_ios 18
- compat key css.selectors.view-transition-old: baseline low, low date 2025-10-14; support: chrome 109, chrome_android 109, edge 109, firefox 144, firefox_android 144, safari 18, safari_ios 18

## cross-document-view-transitions

name: Cross-document view transitions

description: The @view-transition CSS rule sets whether a document opts-in to transitions between documents in a multi-page application. Both the old and new document must opt-in for a transition to be triggered.

baseline: False; baseline_low_date: None; baseline_high_date: None

support: chrome 126, chrome_android 126, edge 126, safari 18.2, safari_ios 18.2

- compat key api.CSSViewTransitionRule: baseline False, low date None; support: chrome 126, chrome_android 126, edge 126, safari 18.2, safari_ios 18.2
- compat key api.CSSViewTransitionRule.navigation: baseline False, low date None; support: chrome 126, chrome_android 126, edge 126, safari 18.2, safari_ios 18.2
- compat key api.CSSViewTransitionRule.types: baseline False, low date None; support: chrome 126, chrome_android 126, edge 126, safari 18.2, safari_ios 18.2
- compat key css.at-rules.view-transition: baseline False, low date None; support: chrome 126, chrome_android 126, edge 126, safari 18.2, safari_ios 18.2

## scroll-driven-animations

name: Scroll-driven animations

description: The animation-timeline, scroll-timeline, and view-timeline CSS properties advance animations based on the user's scroll position.

baseline: False; baseline_low_date: None; baseline_high_date: None

support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26

- compat key api.ScrollTimeline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key api.ScrollTimeline.ScrollTimeline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key api.ScrollTimeline.axis: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key api.ScrollTimeline.source: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key api.ViewTimeline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key api.ViewTimeline.ViewTimeline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key api.ViewTimeline.endOffset: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key api.ViewTimeline.startOffset: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key api.ViewTimeline.subject: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.animation-range: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.animation-range-end: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.animation-range-end.normal: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.animation-range-start: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.animation-range-start.normal: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.animation-timeline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.animation-timeline.scroll: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.animation-timeline.view: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.animation.animation-timeline_included: baseline False, low date None; support: 
- compat key css.properties.scroll-timeline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.scroll-timeline-axis: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.scroll-timeline-axis.block: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.scroll-timeline-axis.inline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.scroll-timeline-axis.x: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.scroll-timeline-axis.y: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.scroll-timeline-name: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.timeline-scope: baseline False, low date None; support: chrome 116, chrome_android 116, edge 116, safari 26, safari_ios 26
- compat key css.properties.timeline-scope.all: baseline False, low date None; support: safari 26, safari_ios 26
- compat key css.properties.timeline-scope.none: baseline False, low date None; support: chrome 116, chrome_android 116, edge 116, safari 26, safari_ios 26
- compat key css.properties.view-timeline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.view-timeline-axis: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.view-timeline-axis.block: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.view-timeline-axis.inline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.view-timeline-axis.x: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.view-timeline-axis.y: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.view-timeline-inset: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.view-timeline-inset.auto: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- compat key css.properties.view-timeline-name: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26

## search

name: <search>

description: The <search> HTML element is a container that represents the parts of the web page with search functionality.

baseline: high; baseline_low_date: 2023-10-13; baseline_high_date: 2026-04-13

support: chrome 118, chrome_android 118, edge 118, firefox 118, firefox_android 118, safari 17, safari_ios 17


## container-queries

name: Container queries (size)

description: Container size queries with the @container (…) at-rule apply styles to an element based on a dimension of its container, such as width or height.

baseline: high; baseline_low_date: 2023-02-14; baseline_high_date: 2025-08-14

support: chrome 105, chrome_android 105, edge 105, firefox 110, firefox_android 110, safari 16, safari_ios 16


## field-sizing

name: field-sizing

description: The field-sizing CSS property allows form controls such as <textarea> to be sized based on their content.

baseline: low; baseline_low_date: 2026-06-16; baseline_high_date: None

support: chrome 123, chrome_android 123, edge 123, firefox 152, firefox_android 152, safari 26.2, safari_ios 26.2

- compat key css.properties.field-sizing: baseline low, low date 2026-06-16; support: chrome 123, chrome_android 123, edge 123, firefox 152, firefox_android 152, safari 26.2, safari_ios 26.2
- compat key css.properties.field-sizing.content: baseline low, low date 2026-06-16; support: chrome 123, chrome_android 123, edge 123, firefox 152, firefox_android 152, safari 26.2, safari_ios 26.2
- compat key css.properties.field-sizing.fixed: baseline low, low date 2026-06-16; support: chrome 123, chrome_android 123, edge 123, firefox 152, firefox_android 152, safari 26.2, safari_ios 26.2

## user-pseudos

name: :user-valid and :user-invalid

description: The :user-valid and :user-invalid pseudo-classes match form controls that have been marked as valid or invalid based on their validation constraints.

baseline: high; baseline_low_date: 2023-11-02; baseline_high_date: 2026-05-02

support: chrome 119, chrome_android 119, edge 119, firefox 88, firefox_android 88, safari 16.5, safari_ios 16.5


## scroll-markers

name: Scroll markers

description: A scroll marker scrolls a container to a scroll target. The ::scroll-marker CSS pseudo-element selects a scroll marker in a ::scroll-marker-group pseudo-element, generated before or after the scroll container. You can use them to navigate and style tables of contents, tab panels, and carousels.

baseline: False; baseline_low_date: None; baseline_high_date: None

support: chrome 135, chrome_android 135, edge 135

- compat key css.properties.scroll-marker-group: baseline False, low date None; support: chrome 135, chrome_android 135, edge 135
- compat key css.properties.scroll-marker-group.after: baseline False, low date None; support: chrome 135, chrome_android 135, edge 135
- compat key css.properties.scroll-marker-group.before: baseline False, low date None; support: chrome 135, chrome_android 135, edge 135
- compat key css.properties.scroll-marker-group.none: baseline False, low date None; support: chrome 135, chrome_android 135, edge 135
- compat key css.selectors.scroll-marker: baseline False, low date None; support: chrome 135, chrome_android 135, edge 135
- compat key css.selectors.scroll-marker-group: baseline False, low date None; support: chrome 135, chrome_android 135, edge 135

## interpolate-size

name: interpolate-size

description: The interpolate-size CSS property sets whether animations and transitions interpolate between a numeric value and a keyword value, such as from a fixed length to auto or fit-content.

baseline: False; baseline_low_date: None; baseline_high_date: None

support: chrome 129, chrome_android 129, edge 129

- compat key css.properties.interpolate-size: baseline False, low date None; support: chrome 129, chrome_android 129, edge 129
- compat key css.properties.interpolate-size.allow-keywords: baseline False, low date None; support: chrome 129, chrome_android 129, edge 129
- compat key css.properties.interpolate-size.numeric-only: baseline False, low date None; support: chrome 129, chrome_android 129, edge 129

## starting-style

name: @starting-style

description: The @starting-style CSS at-rule sets the starting values for properties that are transitioning when the target element's style is first updated.

baseline: low; baseline_low_date: 2024-08-06; baseline_high_date: None

support: chrome 117, chrome_android 117, edge 117, firefox 129, firefox_android 129, safari 17.5, safari_ios 17.5

- compat key api.CSSStartingStyleRule: baseline low, low date 2024-08-06; support: chrome 117, chrome_android 117, edge 117, firefox 129, firefox_android 129, safari 17.5, safari_ios 17.5
- compat key css.at-rules.starting-style: baseline low, low date 2024-08-06; support: chrome 117, chrome_android 117, edge 117, firefox 129, firefox_android 129, safari 17.5, safari_ios 17.5


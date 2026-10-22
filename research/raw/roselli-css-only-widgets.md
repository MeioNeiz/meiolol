# CSS-only Widgets Are Inaccessible — Adrian Roselli

<https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html>

[Skip to content.](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Skip)

-   [Blog](https://adrianroselli.com/posts)
-   [Bio](https://adrianroselli.com/bio)
-   [Books](https://adrianroselli.com/books)
-   [Contact](https://adrianroselli.com/contact)

Search for:  

[**Adrian Roselli** Large Language Algorithm Incentive VRML](https://adrianroselli.com/)

# CSS-only Widgets Are Inaccessible

Updated April 21, 2026, originally posted March 25, 2023; [6 Comments](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Comments)

Usually.

I originally titled this _InacCSS-onlyible_. I even made this typographically, er, distinct image. Then I realized it was silly and will instead use the neologism in a talk so I can hear the groans IRL.

Interactive widgets powered with only CSS are relatively common as people are playing with all the ways CSS can respond to, or create, interactions. CodePen contests are a great venue to see these experiments (which hopefully are never moved to a live human-facing project).

The problem with many of these examples is they need to convey their state (such as expanded or not), properties (think of relationships), or values, and (sometimes) dynamic names. While CSS is ideal to show these visually, they need to be passed to accessibility APIs so they can be conveyed to users of assistive technologies.

Not everything that relies on CSS for interaction is inaccessible. There are always going to be [exceptions](https://adrianroselli.com/2021/12/under-engineered-dependency-questions.html), but those are (and should be) rare.

## Examples [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Examples)

I know folks do better with examples, so I have grabbed common ones.

### Disclosures [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Disclosures)

It is very common to see a checkbox used as a trigger to hide or show content. Its use in “hamburger” navigation is sadly common, but I often see it with arbitrary expando patterns, such as [this fork](https://codepen.io/aardrian/pen/XWPobYd) of an image gallery I made more accessible than its source:

Originally this was coded with a checkbox. A screen reader user would have no idea why there is a checkbox. Since the images are displayed even in the collapsed state (as black boxes), a sighted screen reader user could be confused why their alternative text is announced. A keyboard only user may wonder why it does not fire on Enter↵.

By changing the trigger to a `<button>` with `aria-expanded`, a screen reader user will know the trigger is for a disclosure _and_ it fires on Enter↵. By adding `aria-hidden="true"` when collapsed, those images will not be exposed to that same user. This particular design means simply toggling a `hidden` HTML attribute or the CSS-only `display: none` will not do the job.

In short, script is needed to manage the expanded or collapsed state as well as the programmatic exposure of the images when reduced to tiny icons. It is a simple [disclosure widget](https://adrianroselli.com/2020/05/disclosure-widgets.html) with an extra requirement.

Please do not use this example for a real project. It has other issues; I created it simply to demonstrate how easily a CSS-only widget can be tweaked for a baseline of WCAG conformance and a modicum of accessibility affordances.

_Update 31 March 2023:_ A popular tweet [demonstrating CSS trigonometry](https://twitter.com/Una/status/1640545307749408768) functions uses a non-ideal expando widget. I forked it and [made it into an accessible disclosure](https://codepen.io/aardrian/pen/jOvRWbP) widget (notes in the code). Scott O’Hara went further and [rebuilt it as a `popover`](https://codepen.io/scottohara/pen/ZEMPwWR) using the [Chrome-only OpenUI proposal](https://open-ui.org/components/popover.research.explainer/). A missed opportunity for OP to demonstrate a pattern which OP has championed.

### Toggles [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Toggles)

[This example](https://codepen.io/aardrian/pen/ZEMVMRM) is a control to toggle dark or light mode (from a site offering copy-pasta-ready code) that is also quite inaccessible:

This fake toggle uses a hidden checkbox, so it cannot be activated with the keyboard. This also means a sighted screen reader user cannot activate it without grabbing a mouse. Bear in mind that the code in this sample is scraped from the demo, _not_ from the downloadable package(s).

It is fine to use a [checkbox as a toggle](https://adrianroselli.com/2019/03/under-engineered-toggles.html), incidentally. Though maybe save it for when you plan to progressively enhance the control and/or flipping the toggle will only take effect when the user submits it. In other words, plan to add a submit button when using a checkbox.

The site also offers a button version of the control, but that button does not convey its state. For that to happen, it would need to use `aria-pressed` and alternate its value between `true` and `false`. Then you hang styles off it, [visually reinforcing its programmatic state](https://adrianroselli.com/2021/06/using-css-to-enforce-accessibility.html).

I tend to prefer a [button as a toggle](https://adrianroselli.com/2019/08/under-engineered-toggles-too.html) in this scenario if you can count on JavaScript being available and flipping the toggle has an immediate effect. For most theme toggles on sites, this is the preferred approach.

As an aside, as of this writing my site uses buttons for the theme toggle. If JavaScript is not available, it uses links with a query string which spares the user having to also press a submit button.

_Update 18 May 2024_: While not a toggle, using `:has()` with select menus brings the same risk as the checkbox hack. While articles like [Combining CSS :has() And HTML <select> For Greater Conditional Styling](https://www.smashingmagazine.com/2024/05/combining-css-has-html-select-conditional-styling/) are nice demonstrations of CSS, they should not be used in production without caution. [I left a comment](https://www.smashingmagazine.com/2024/05/combining-css-has-html-select-conditional-styling/#comment-1715355337669239446) saying as much.

### Sorting [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Sorting)

I have seen a few efforts using CSS to sort content. They generally follow variations on re-ordering the visual layout using the `order` property or repositioning items in a grid track.

The following video captures an [experiment from 2018](https://kizu.dev/variable-order/) that visually re-orders rows in a table. It demonstrates it as experienced in JAWS using table navigation.

Sorry, your browser doesn’t support embedded videos, but don’t worry, you can . The is also available in case your video player can import it.

Visually the table rows are sorted, but their row position announcement and navigation order never changes.

From an interface standpoint, an [accessible sortable table](https://adrianroselli.com/2021/04/sortable-table-columns.html) would use `aria-sort` on a column header to convey its current sort state. The header cell would also include a control that can be operated by keyboard (a `<button>`, for those keeping score).

Programmatically, the sorting operation would restructure the DOM so that the new first row would become the first row in the DOM, the new second row moves into the second row spot, and so on. Otherwise you have both [meaningful sequence](https://www.w3.org/WAI/WCAG21/Understanding/meaningful-sequence.html) and [focus order](https://www.w3.org/WAI/WCAG21/Understanding/focus-order.html) WCAG violations.

### Marquee [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Marquee)

_Added 2 December 2023._ It is relatively simple to use CSS to create all sorts of animations. A marquee, recreating the classic and terrible [`<marquee>`](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/marquee) element, is probably the first place most people start as they teach themselves the CSS syntax. While you can use a [`prefers-reduced-motion`](https://www.w3.org/TR/mediaqueries-5/#prefers-reduced-motion) feature query to prevent any animation for users with that system-level preference, it is useless for those who still want animations but want to [pause or stop](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html) this specific case on a page.

It is also definitely not a carousel (or slider or whatever the kids call it). And adding `aria-hidden` will not make it accessible, despite what the lead design engineer at Vercel (and Twitter blue-check) casually asserts:

> 0 javascript infinite carousel  
>   
> – the trick is to duplicate the items  
> – for a11y, add \`aria-hidden\` to all the duplicated items  
>   
> codepen 👇 [pic.twitter.com/CongykLVex](https://pic.twitter.com/CongykLVex)
> 
> Sorry, your browser doesn’t support embedded videos, but don’t worry, you can .
> 
> JohnPhamous (@JohnPhamous) [December 1, 2023](https://twitter.com/JohnPhamous/status/1730651819314139326)

Video description

He does not provide a CodePen for his example, but he did link someone else’s [2017 demo that makes no accessibility claims](https://codepen.io/studiojvla/details/qVbQqW) (and so should not be shamed). However, the video he made clearly shows structured data, no ability to pause or stop animation, and (if those avatars are or ever become links) a problematic experience for screen reader users. While my expectations for [Vercel code quality are incredibly low](https://adrianroselli.com/2023/09/the-children-are-driving-the-bus.html), I was disappointed to see CodePen boost this.

Sadly, it is not uncommon for [accessibility claims to be wrong](https://adrianroselli.com/2022/11/your-accessibility-claims-are-wrong-unless.html). I just wish they weren’t promoted when they are so easily disproven.

### Looper [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Looper)

_Added 3 May 2024._ Google Chrome has a video about radio button groups that its author is [calling The Looper Mini Web Machine](https://www.youtube.com/watch?v=vwgihljM2e4). A core feature of groups of radio buttons is that they are operable with arrow keys by default. Another core feature is that they are form controls, meant to gather information from users and then submit to a process. This video is promoting them strictly as a UI widget.

That is only one of the examples, but it demonstrates the risk of taking the video’s advice at face value. When I forked it, I removed the script that handles the view transitions since I am focusing on the CSS and HTML (the script only animates the change via view transitions).

The hit area not matching the visual box is a usability problem. The missing group label (the absent `<legend>`) is a [1.3.1 Info and Relationships](https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html) violation and the shifting position of the currently selected radio button can be argued as a [3.2.2 On Input](https://www.w3.org/WAI/WCAG22/Understanding/on-input.html) failure (depending on [broader context of use](https://www.w3.org/WAI/WCAG22/Understanding/on-input.html#dfn-changes-of-context)). That sudden shift can be a problem for magnifier users as well. Sadly, this author has a [history of WCAG-violating advice](https://issuetracker.google.com/issues/298296173) on behalf of Google, and Google continues to provide a platform, so I expect more problematic content in this “web machine” series by Google.

In short, if you want arrow key support for a widget then use script. See ARIA grids, tab lists, listboxes for scripting examples, even if the roles aren’t a fit. Taking a form control and using CSS to turn it into a contextually different widget only risks WCAG violations and confused users.

### Tabs [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Tabs)

_Added 19 June 2024._ [This example is from 2020](https://wpshout.com/snippets/accessible-pure-css-tabs/), but it came my way today when someone asked about this “accessible” pure CSS set of tabs. It uses radio buttons to hide and show content. Two immediate clues this may not satisfy its “accessible” claim:

-   This does not use any ARIA tab widget roles (`tab`, `tablist`, `tabpanel`), meaning it is not exposed as a tab widget to screen reader users. I would likely fail this under [WCAG 2.2 SC 4.1.2 Name, Role, Value (Level A)](https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html) for not conveying the tab roles and states.
-   As written, this fails [WCAG 2.2 SC 3.2.2 On Input (Level A)](https://www.w3.org/WAI/WCAG22/Understanding/on-input.html), under the content definition of “context”.

I am ignoring the unnecessary `tabindex` on the heading and paragraph [as well as its value of `1`](https://adrianroselli.com/2014/11/dont-use-tabindex-greater-than-0.html).

### Animated `<details>` [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#AniDetails)

_Added 7 March 2026._ An author has promised smoothly animated `<details>` using no JavaScript. This is a common request, and I know tiny animations can be compelling. But [until `interpolate-size` is supported by more than Chromium](https://www.oidaisdes.org/blog/lets-play-accordion/#content-styling-with-details-content), script may be the best way for all users. I argue it’s far better than making the disclosed content a _peer_ to the `<details>` instead of nested within it. Definitely better than using `aria-describedby` to associate them. And I have no idea why you’d want `term` and `definition` roles folded into the mix. But here we are, offered by someone who makes this claim: Screen readers? Fully supported. Which, sure, if by “supported” you mean the arrow glyph gets announced along with the content that’s visually hidden.

### Radio State Machine [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#State)

_Added 21 April 2026._Similar to the [Looper](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Looper) above, this is one of a series of examples that uses radio buttons as a script-free CSS-only method of managing state.

While there are many other examples from the article promoting this, this one collects all the WCAG and functional challenges in one neat package.

-   It uses _both_ `aria-label` and CSS generated content, neither of which may auto-translate and, when combined in this way, creates a 2.5.3 Label in Name violation.
-   The visible control visually looks like a button, but does not respond to Enter↵ (other patterns in this same article don’t respond to Space) with no instructions that arrow keys may be needed, so a 3.3.2 Labels or Instructions risk.
-   There is no `<fieldset>` / `<legend>`, which you may need to satisfy 1.3.1 Info and Relationships.
-   Using radio buttons as these patterns do risks a SC 3.2.2 On Input violation.
-   Activating the radio causes focus to be lost, so a user has to tab back to the (new) visible control — which may be a SC 2.4.3 Focus Order violation.
-   This particular pattern is also meant to prevent a user from looping, but a screen reader user has no issue moving between the five chunks of content.

As identified above, don’t use radio controls to track or manage state. They are form controls. Avoid using ARIA or CSS for accessible names, especially at the same time on the same control.

## Wrap-up [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Wrap)

Any person, post, article, tweet, expert, fortune cookie, company, etc., that claims its CSS-only interactive widget is accessible [is probably wrong](https://adrianroselli.com/2022/11/your-accessibility-claims-are-wrong-unless.html).

While it may not be intentional, it is incumbent on you to confirm the accessibility because the person making the claim often has not.

## Talk Reference (Added 7 July 2024) [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Update01)

This post was mentioned at CSS Day 2023.

YouTube: [That’s not how I wrote CSS 3 years ago | Manuel Matuzović | CSS Day 2023](https://youtu.be/L668dK6wFcM?start=2516).

## 2 September 2025 [#anchor](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Update02)

Chris Ferdinandi comes to a similar conclusion in [CSS-only solutions are not accessible](https://gomakethings.com/css-only-solutions-are-not-accessible/). His example is site navigation that operates on hover (I have a similar [example above with the gallery disclosure](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#Disclosures)). However, I [recommend against his approach](https://adrianroselli.com/2019/04/details-summary-are-not-insert-control-here.html#Navigation) of using `<details>` and `<summary>` since a find-in-page (Ctrl+F) will expand them with a match. Use a [link and disclosure widget pattern](https://adrianroselli.com/2019/06/link-disclosure-widget-navigation.html) instead.

## Tags

[accessibility](https://adrianroselli.com/tag/accessibility), [css](https://adrianroselli.com/tag/css), [usability](https://adrianroselli.com/tag/usability), [UX](https://adrianroselli.com/tag/ux), [WCAG](https://adrianroselli.com/tag/wcag)

## Other Posts

[Earlier post: #AudioEye Will Get You Sued](https://adrianroselli.com/2023/02/audioeye-will-get-you-sued.html)

[More recent post: Exposing Field Errors](https://adrianroselli.com/2023/04/exposing-field-errors.html)

## 6 Comments

> [Reply](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html?replytocom=253993#respond)
> 
> How accessible is this pattern of opening/closing UI components?
> 
> `main[hidden]:target{display:revert}   main:not([hidden]):has(~ main:target){display:none}`
> 
> `App   <a href="#settings" rel="nofollow ugc">Go to Settings</a>`
> 
> `Settings   <a href="#app" rel="nofollow ugc">Back to App</a>`
> 
> Rua; 27 March 2023 at 10:38 am. [Permalink](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#comment-253993)

> In response to [Rua](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#comment-253993). [Reply](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html?replytocom=253995#respond)
> 
> Rua, I am not your QA. But without a lot more context, that does not appear to be very accessible. You may want a [disclosure widget](https://adrianroselli.com/2020/05/disclosure-widgets.html) or, more likely, a [dialog](https://www.scottohara.me/blog/2023/01/26/use-the-dialog-element.html).
> 
> [Adrian Roselli](https://adrianroselli.com/); 27 March 2023 at 12:00 pm. [Permalink](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#comment-253995)

> [Reply](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html?replytocom=254011#respond)
> 
> I’m curious on what your opinion about “enhancing” the toggle hack is via messages that are pushed in and out of visibility (and thus announced) by way of live regions and display conditional upon the toggle state.
> 
> I did this a while ago and the below might have some errors as I’m going off the top of my head here. I can dig up the exact code at a later time / tomorrow if curious.
> 
> Specifically, in pseudocode, if you have
> 
> Input for toggle hack  
> Subsequent message container with live region / assertiveness  
> Message for checked state  
> Message for unchecked state  
> Indeterminate state if needed
> 
> CSS pseudocode:
> 
> input:checked ~ message container > message:not(specific index) display none  
> – display initial for message to announce
> 
> Invert the above for the non-checked state
> 
> Then add a sr-only class of course to visually hide them.
> 
> This seems to work fluidly for things like menus, dropdowns, etc.
> 
> If we had a dropdown we could do something like:
> 
> Input for hamburger menu  
> – label: toggle dropdown menu  
> Messages:  
> – dropdown menu has been opened  
> – dropdown menu has been closed  
> When checked:  
> – live region announces message #1  
> When unchecked:  
> – live region announces message #2
> 
> Which seems acceptable with proper display / CSS on the dropdown menu per state of course
> 
> The catch is the implicit role of the input itself but we can kind of hack that with role=button.
> 
> So not 100% fixed but still much better and bordering on acceptable usage at least for no JavaScript cases
> 
> Nick; 27 March 2023 at 10:44 pm. [Permalink](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#comment-254011)

> In response to [Nick](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#comment-254011). [Reply](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html?replytocom=254034#respond)
> 
> Nick, I would need to see this in action to have a sense how it works. But I can call out some specific statements you make that are indeed problems (and likely WCAG violations):
> 
> > Indeterminate state if needed
> 
> While a native checkbox can have an indeterminate state, I have no idea how you would represent that in your show/hide pattern. It might be good to disallow that.
> 
> > Messages:  
> > – dropdown menu has been opened  
> > – dropdown menu has been closed
> 
> A disclosure-based [navigation is not a menu](https://adrianroselli.com/2017/10/dont-use-aria-menu-roles-for-site-nav.html), nor does [_dropdown_ mean the same thing](https://adrianroselli.com/2020/03/stop-using-drop-down.html) to all users. So the messages themselves are mis-managing expectations, which can impact expected interaction.
> 
> > When checked:  
> > – live region announces message #1  
> > When unchecked:  
> > – live region announces message #2
> 
> Here the user only knows the state of the control when it gets activated. And the live region can interrupt their ongoing task. When [live regions are supported](https://a11ysupport.io/tech/aria/aria-live_attribute), that is, never mind [those on Braille displays](https://adrianroselli.com/2023/01/jaws-nvda-and-voiceover-braille-viewers.html#NVDA).
> 
> Regardless, there is no programmatic state (such as `aria-expanded`), which means a user may not know if the widget is open or closed as they navigate through the page.
> 
> > The catch is the implicit role of the input itself but we can kind of hack that with role=button.
> 
> That is indeed a hack since a screen reader user may wonder why it does not fire on Enter↵ (certain [roles give instructions to users](https://adrianroselli.com/2019/10/stop-giving-control-hints-to-screen-readers.html) on how to operate them).
> 
> > So not 100% fixed but still much better and bordering on acceptable usage at least for no JavaScript cases
> 
> The thing about accessibility (and especially WCAG) is that less than 100% is still a barrier (or a failure in WCAG). That is like a lovely ramp to a store with a single step at the very top. I disagree that this is bordering on acceptable usage.
> 
> [Adrian Roselli](https://adrianroselli.com/); 28 March 2023 at 9:11 am. [Permalink](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#comment-254034)

> [Reply](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html?replytocom=375572#respond)
> 
> Regarding not using details / summary for navigation “dropdowns,” Find-in-page matching the contents of details can be prevented with CSS.
> 
> `details:not([open]) > :not(summary) {   display: none;   }`
> 
> In practice, one would probably use this only for certain details, like those within a nav.
> 
> Curtis Wilcox; 2 September 2025 at 1:35 pm. [Permalink](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#comment-375572)

> In response to [Curtis Wilcox](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#comment-375572). [Reply](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html?replytocom=375618#respond)
> 
> Sure, but that falls into the CSS-only approach in my opinion (because your are using, and relying on, CSS to limit or remove a behavior of a control meant for another purpose).
> 
> [Adrian Roselli](https://adrianroselli.com/); 2 September 2025 at 6:48 pm. [Permalink](https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html#comment-375618)

### Leave a Comment or Response

Comment:

-   The form doesn’t support Markdown.
-   This form allows limited HTML.
-   Allowed HTML elements are `<a href>`, `<blockquote>`, `<code>`, `<del>`, `<em>`, `<ins>`, `<q>`, `<strong>`, and maybe some others. WordPress is fickle and randomly blocks or allows some.
-   If you want to include HTML _examples_ in your comment, then HTML encode them. E.g. `<code>&lt;div&gt;</code>` (you can copy and paste that chunk).

Name \* 

Email \* 

Website 

-   [Site Map](https://adrianroselli.com/site-map)
-   [Accessibility](https://adrianroselli.com/accessibility-statement)
-   [LLM Statement](https://adrianroselli.com/2025/12/my-use-of-ai-on-this-site.html)
-   [RSS](https://adrianroselli.com/feed)
-   [Mastodon](https://toot.cafe/@aardrian)

Theme:   

© 1999–2026 Adrian Roselli

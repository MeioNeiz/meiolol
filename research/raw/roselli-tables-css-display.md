# Tables, CSS Display Properties, and ARIA — Adrian Roselli

<https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html>

[Skip to content.](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Skip)

-   [Blog](https://adrianroselli.com/posts)
-   [Bio](https://adrianroselli.com/bio)
-   [Books](https://adrianroselli.com/books)
-   [Contact](https://adrianroselli.com/contact)

Search for:  

[**Adrian Roselli** Crypto Distrbuted Ledger Process CSS](https://adrianroselli.com/)

# Tables, CSS Display Properties, and ARIA

Updated January 29, 2024, originally posted February 20, 2018; [23 Comments](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Comments)

## Update: 7 October 2023

Tables with display properties are now functional across Chromium, Gecko, and (finally) WebKit browsers. Barring regressions (which have happened), `display: contents` is the only style that may cause issues, and that is a function of a [poor specification](https://github.com/w3c/csswg-drafts/issues/3040#issuecomment-1750967636).

My post [It’s Mid-2022 and Browsers (Mostly Safari) Still Break Accessibility via Display Properties](https://adrianroselli.com/2022/07/its-mid-2022-and-browsers-mostly-safari-still-break-accessibility-via-display-properties.html) goes into far more detail and is also far more current. The laggard, Apple, has addressed its table bugs in Safari 17. It only took 5¾ years. You can read my ongoing pestering in that post.

This post has two separate but related things going on. One is an example of one of my responsive tables with ARIA added, and the other is the Twitter conversation that started this along with some generalized responses.

-   [Responsive Table with Semantics Retained by ARIA](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#TheTable)
-   [The Tweet](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#TheTweet)
-   [What You Can Do](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#TheCall)

## Responsive Table with Semantics Retained by ARIA [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#TheTable)

This example ([viewable directly at CodePen](https://codepen.io/aardrian/pen/LQddwO/)) shows how you can use ARIA table roles to override / re-insert the table semantics you may lose by using CSS flex or grid.

First, you need to understand how to use the roles, including getting the nesting right. In general these can be simple. The [`table` role](https://www.w3.org/TR/wai-aria-1.1/#table) should be added to the `<table>` element. If you use `<thead>`, `<tbody>`, and/or `<tfoot>`, they get the [`rowgroup` role](https://www.w3.org/TR/wai-aria-1.1/#rowgroup). `<tr>` gets [`row`](https://www.w3.org/TR/wai-aria-1.1/#row) and `<td>` gets [`cell`](https://www.w3.org/TR/wai-aria-1.1/#cell). `<th scope="col">` gets [`columnheader`](https://www.w3.org/TR/wai-aria-1.1/#columnheader) while `<th scope="row">` gets [`rowheader`](https://www.w3.org/TR/wai-aria-1.1/#rowheader).

It really is that straightforward.

But here is where it gets complicated. Tables that hide content (especially headers) in a responsive or similar context, and tables that re-order content.

The re-ordering issue is easy to solve — don’t use CSS to re-order table content. Use client-side script to move the nodes around in the DOM. For example, using CSS flex or grid to sort a table may be novel, but it will not support screen reader users.

Hiding content is a bit trickier. My example above addresses that. It uses the same code as my [responsive accessible table](https://adrianroselli.com/2017/11/a-responsive-accessible-table.html), but with two differences. It now has the ARIA roles I outlined above, and it does not add the replacement text for the row headers until you click the button. The button is only there to give you a chance to experience the table without the replacement text (in a narrow view).

### Examples [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Examples)

The following videos demonstrate how the ARIA can make the table semantics, and thus table navigation, work within the browser. The first one demonstrates how the hidden column headers hurt our ability to understand the narrow table (not just visually). The second video demonstrates how the table is more understandable once the generated content appears to take the place of the hidden column headers.

Each video uses the embedded CodePen example in Firefox 58.0.2 with NVDA 2017.4 on Windows 10. I am using table navigation (Ctrl + Alt + →/←/↑/↓) to get around the content, jumping up and down rows and between cells.

### Advice [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Advice)

If you are not able to test with a screen reader, maybe don’t do this. You run the risk of making an already problematic responsive table downright unusable. Further, if you are not going to test regularly as browsers and screen readers get updated, maybe don’t do this.

## The Tweet [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#TheTweet)

I pushed out a tweet yesterday that generated a lot of interesting questions and conversations. I think it may have also led to some confusion.

I followed it up to add some detail:

### Collected Responses [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Responses)

I received some interesting questions and comments, some of them tinged with frustration. The most critical thing I learned is that developers who play around with CSS and tables on the whole do not test them in screen readers. This is my effort to break down the types of questions and comments and provide some extra information.

-   Developers have been breaking HTML table semantics via display properties since before CSS flex and grid.
-   This should not make it harder / impossible to make responsive tables. I wrote some [easy and less easy ways to make responsive tables](https://adrianroselli.com/2017/11/a-responsive-accessible-table.html).
-   CSS already has as impact on HTML semantics — `display: none` is an example of that.
-   If screen readers give priority to mark-up over styling in every instance, then `display: none` would no longer work.
-   Setting `display: table` and related does not impart HTML table semantics to (`<div>`) layouts that used it for things like vertical centering.
-   This is not a function of screen readers alone, as they get their accessibility information from the browser.
-   A screen reader needs more than the DOM to understand a page, so asking it to ignore all but the DOM is impractical.
-   Users don’t want us to be able to detect screen readers, [nor should we](https://adrianroselli.com/2014/03/on-screen-reader-detection.html) and certainly not as a workaround for responsive tables.
-   Even if you could detect screen readers, how would you know which [third of those users are not blind](https://adrianroselli.com/2017/02/not-all-screen-reader-users-are-blind.html)?
-   Even if you listen for mouse actions as a proxy for sighted screen reader users, how do you account for those with mobility impairments who do not use a mouse? Or mobile screen reader users who rely on touch gestures?
-   Disabling a site’s CSS for screen reader users is therefore impractical (and a terrible, terrible idea).
-   Using flex or grid for an HTML table already means you are running the risk of messing up [content order versus source order](https://adrianroselli.com/2015/10/html-source-order-vs-css-display-order.html) (not unique to tables).
-   Using CSS grid to lay out an HTML table may be fine, but it still won’t be a table semantically
-   A significant part of why we have this situation is because of years of relying on HTML tables for layout that had their display properties tweaked, providing a cue to screen readers that they were for layout only.
-   Screen readers already have their own heuristics for dealing with tables, primarily due to years of poor developer practices, with [current behaviors tracked by PowerMapper](https://www.powermapper.com/tests/screen-readers/tables/).
-   While [ARIA provides roles for tables](https://www.w3.org/TR/wai-aria-1.1/#table), it requires you to understand your tables well and stay on top of screen reader testing as new releases come.
-   Applying ARIA roles to retain table semantics can be problematic for responsive tables where header cells or other cells are discarded, a common pattern in responsive table examples. See the [previous section of this post](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#TheTable).
-   Generally, do not use ARIA to try to override CSS, not just because the CSS may not load, but because this is [not the purpose of ARIA](https://adrianroselli.com/2017/11/hey-its-still-ok-to-use-tables.html).

If you find the ability to so casually dismiss HTML table semantics to be frustrating, it is not the fault of screen readers. It is the fault of years of terrible coding practices predicated on visual layout over developer rigor of choosing the right element for the job.

If you find you want to use CSS flex, grid, block, inline, or other display properties on a table, then maybe consider what the heck you are doing with the table.

### Assorted CSS Specifications [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#CSSspecs)

I may have stayed up too late trying to parse all this.

CSS 2.x tries to break down the role of CSS for tables, namely leaving it up to HTML to define the semantics:

> Table layout can be used to represent tabular relationships between data. Authors specify these relationships in the [document language](https://www.w3.org/TR/CSS2/conform.html#doclanguage) and can specify their _presentation_ using CSS 2.1.
> 
> Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification, W3C Recommendation 07 June 2011, edited in place 12 April 2016: [17.1 Introduction to tables](https://www.w3.org/TR/CSS2/tables.html#tables-intro)

CSS 2.x also accounts for non-HTML pages, where it adds the semantics and generates the necessary anonymous table objects around itself:

> In other document languages (such as XML applications), there may not be pre-defined table elements. Therefore, CSS 2.2 allows authors to “map” document language elements to table elements via the [‘display’](https://www.w3.org/TR/CSS22/visuren.html#propdef-display) property. For example, the following rule makes the FOO element act like an HTML TABLE element and the BAR element act like a CAPTION element:
> 
> Cascading Style Sheets Level 2 Revision 2 (CSS 2.2) Specification, W3C First Public Working Draft 12 April 2016: [17.1 Introduction to tables](https://www.w3.org/TR/CSS22/tables.html#tables-intro)

I can find nowhere in the CSS 2.x specification (specifically in the [visual formatting model](https://www.w3.org/TR/CSS22/visuren.html)) where the `display` property should override the native semantics of the source document language (HTML).

The closest statement about interaction with tables that I can find in the Flexbox specification is a note directed at user agent makers, and says nothing about changing the semantics:

> Note: Some values of [display](https://www.w3.org/TR/css-ruby-1/#propdef-display) normally trigger the creation of anonymous boxes around the original box. If such a box is a [flex item](https://www.w3.org/TR/2017/CR-css-flexbox-1-20171019/#flex-item), it is blockified first, and so anonymous box creation will not happen. For example, two contiguous [flex items](https://www.w3.org/TR/2017/CR-css-flexbox-1-20171019/#flex-item) with [display: table-cell](https://www.w3.org/TR/css-ruby-1/#propdef-display) will become two separate [display: block](https://www.w3.org/TR/css-ruby-1/#propdef-display) [flex items](https://www.w3.org/TR/2017/CR-css-flexbox-1-20171019/#flex-item), instead of being wrapped into a single anonymous table.
> 
> CSS Flexible Box Layout Module Level 1, W3C Candidate Recommendation, 19 October 2017: [4\. Flex Items](https://www.w3.org/TR/2017/CR-css-flexbox-1-20171019/#flex-items)

CSS Grid has similar language:

> Note: Some values of [display](https://www.w3.org/TR/css-ruby-1/#propdef-display) normally trigger the creation of anonymous boxes around the original box. If such a box is a [grid item](https://www.w3.org/TR/2017/CR-css-grid-1-20171214/#grid-item), it is blockified first, and so anonymous box creation will not happen. For example, two contiguous [grid items](https://www.w3.org/TR/2017/CR-css-grid-1-20171214/#grid-item) with [display: table-cell](https://www.w3.org/TR/css-ruby-1/#propdef-display) will become two separate [display: block](https://www.w3.org/TR/css-ruby-1/#propdef-display) [grid items](https://www.w3.org/TR/2017/CR-css-grid-1-20171214/#grid-item), instead of being wrapped into a single anonymous table.
> 
> CSS Grid Layout Module Level 1, W3C Candidate Recommendation, 14 December 2017: [6.1. Grid Item Display](https://www.w3.org/TR/2017/CR-css-grid-1-20171214/#grid-item-display)

In short, I can see nowhere in the CSS, grid, nor flex specifications where a user agent should override the native semantics of the source document language (HTML). Based on that, my read is that browsers dumping table semantics is a bug.

### Example [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Videos)

I made videos with a screen reader to try to demonstrate how you can ruin the ability to navigate and parse a table just by adding flex.

The table from the example with CSS disabled as heard in NVDA. I am using table navigation controls. NVDA announces the number of rows & columns, all the headings when hopping cells, and tells you when you hit the edge of the table.

The same table with CSS flex added, as heard in NVDA. It is longer presented as a table. The tab order when tabbing through the links is confusing, headers are not announced, sorting controls do not work.

## What You Can Do [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#TheCall)

Help purge the web of layout tables. Help purge the web of CSS table display properties just for vertical centering. Code tables properly and accessibly.

In conjunction with that, file issues against web browsers. Browsers parse the page and then hand it off to a screen reader. If you can get the browsers to behave consistently, then you can get screen readers to adapt as well, as they may no longer need to rely on heuristics to protect users from bad code.

In the meantime, test your responsive tables with screen readers.

Maybe weigh in on the discussion [\[Proposal\] new attribute for specifying focus and reading order](https://web.archive.org/web/20210613060951/https://discourse.wicg.io/t/proposal-new-attribute-for-specifying-focus-and-reading-order/2601) at WICG Discourse.

## Update: March 3, 2018 [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Update1)

Roger Johansson wrote a piece in 2011 that wraps up both how browsers destroy semantics on tables and lists when CSS display properties are applied: [Screen readers and CSS](http://www.456bereastreet.com/archive/201111/screen_readers_and_css/)

## Update: March 4, 2018 [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Update2)

This quote from Steve Faulkner’s post [Short note on what CSS display properties do to table semantics](https://developer.paciellogroup.com/blog/2018/03/short-note-on-what-css-display-properties-do-to-table-semantics/) nails it (_it_ being who is to blame for this mess):

> \[I\]t’s either wittingly/unwittingly the fault of the developer or the browser. But what we can be sure of, in these cases, is that it is not the fault of the screen reader.
> 
> [Short note on what CSS display properties do to table semantics](https://developer.paciellogroup.com/blog/2018/03/short-note-on-what-css-display-properties-do-to-table-semantics/)

## Update: March 27, 2018 [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Update3)

It is worth noting that `display: contents` on a `<table>`, `<ul>`, `<ol>`, etc. also hides it from screen readers. Granted, it’s late and I only tested in Firefox and NVDA so far, but you can try it out yourself (embedded below or [visit it directly at CodePen](https://codepen.io/aardrian/pen/mxpWKX?editors=1100)):

Read Ire Aderinokun’s post, [_How display: contents; Works_](https://bitsofco.de/how-display-contents-works/) for other ways `display: contents` can affect content on a page.

## Update: February 19, 2020 [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Update4)

Big progress. Chrome 80 no longer drops semantics for HTML tables when the `display` properties `flex`, `grid`, `inline-block`, or `contents` are used. The new Edge (ChromiEdge) follows suit. Firefox still dumps table semantics for only `display: contents`. Safari dumps table semantics for everything.

## Update: September 29, 2020 [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Update05)

Léonie Watson has just posted [How screen readers navigate data tables](https://tink.uk/how-screen-readers-navigate-data-tables/) where she walks through a sample table to get some information, explaining each step, the keyboard commands, and the output. She also links to a video demonstration, which I have embedded below.

Watch [How screen readers navigate data tables](https://www.youtube.com/watch?v=X1KR4u94cho) at YouTube.

## Update: December 7, 2022 [#anchor](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#Update06)

I should have linked to my updated post sooner: [It’s Mid-2022 and Browsers (Mostly Safari) Still Break Accessibility via Display Properties](https://adrianroselli.com/2022/07/its-mid-2022-and-browsers-mostly-safari-still-break-accessibility-via-display-properties.html)

Chrome is fine now, the last Firefox bug just closed and should deploy soon, and Safari is still a hot mess after repeated assurances it was being fixed.

## Tags

[accessibility](https://adrianroselli.com/tag/accessibility), [ARIA](https://adrianroselli.com/tag/aria), [css](https://adrianroselli.com/tag/css), [html](https://adrianroselli.com/tag/html), [standards](https://adrianroselli.com/tag/standards), [tables](https://adrianroselli.com/tag/tables), [usability](https://adrianroselli.com/tag/usability), [UX](https://adrianroselli.com/tag/ux)

## Other Posts

[Earlier post: GitHub Contributions Chart](https://adrianroselli.com/2018/02/github-contributions-chart.html)

[More recent post: CSUN 2018: Everything I Know About Accessibility I Learned from Stack Overflow](https://adrianroselli.com/2018/03/csun-2018-everything-i-know-about-accessibility-i-learned-from-stack-overflow.html)

## 23 Comments

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93527#respond)
> 
> The videos would be a better demonstration if anyone not used to a screenreader would understand them. I doubt that there are many, not used to screenreaders, could understand anything in that speed. Could you provide thos videos in a slower speed? The actual speed must be 6x or 8x speed :-)
> 
> [Jens Grochtdreis](http://grochtdreis.de/); 22 February 2018 at 6:27 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93527)

> In response to [Jens Grochtdreis](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93527). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93540#respond)
> 
> Jens, I am on a deadline, so I won’t be re-making these videos in the short term. In the meantime, I suggest viewing this page in Edge or Firefox, which allows you to watch a video at half speed. I wrote some [details on this feature in a post](https://adrianroselli.com/2017/09/playback-speed-in-default-video-players.html).
> 
> [Adrian Roselli](https://adrianroselli.com/); 22 February 2018 at 11:16 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93540)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93541#respond)
> 
> Hi Adrian, thanks for the suggestion. Would have been nice, but the quality of the half-speed video is worse. I cannot understand anything. Well it was an idea. Ignore my plea from the first comment. Nevertheless an interesting finding although anyone not used to a screen reader won’t understand anything.
> 
> I keep the fingers crossed for your deadline :-)
> 
> [Jens Grochtdreis](http://grochtdreis.de/); 22 February 2018 at 11:30 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93541)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93599#respond)
> 
> > Setting display: table and related does not impart HTML table semantics to (`<div>`) layouts that used it for things like vertical centering.
> 
> > Help purge the web of CSS table display properties just for vertical centering.
> 
> Aren’t these statements kind of contradicting each other? If using table `display` on non-table elements is not meant to give them table semantics (and web devs have been taught for years that it doesn’t, and consciously use it for visual-only layout tweaks!) — why should we stop using it just because _some_ software erroneously treats such elements as real tables, contrary to the common developers expectations (according to the data collected [in the corresponding Firefox bug](https://bugzilla.mozilla.org/show_bug.cgi?id=1007975), currently fixed)? The section 4.9.1 of both HTML specs also has a note directly suggesting using CSS table model as one of the alternatives to (ab)using HTML tables for layout. Why should the browser/AT incapability to distinguish the semantically wrong HTML layout and the semantically correct DOM with some visual-only tweaks for minor layout enhancement be the problem of web devs who consciously use HTML to express semantics and CSS just to present it nicely in certain circumstances, not of the developers of these browsers/AT who should improve their heuristics to match the web devs intentions better?
> 
> > If you find you want to use CSS flex, grid, block, inline, or other display properties on a table, then maybe consider what the heck you are doing with the table.
> 
> Unfortunately, not all design requirements can be currently reasonably met with CSS table model. The simplest example from my recent experience is fitting the whole table into the container width (wrapping the sell text if necessary) while having one column shrink-wrap to its longest content. `Table-layout: fixed` can do the former, `table-layout: auto` can do the latter, but neither can do both. Grid layout (accompanied with `display: contents` for table rows) would solve it.
> 
> I agree that limiting ATs to DOM only is impractical and the problem is more complicated than one might think at first glance. But just prohibiting web devs to use certain CSS features seems not to be a long-term solution to me. I guess we should gather stats of how these features are really used and what web devs are meaning by them, collect the feedback of actual ATs users which behavior is helpful for them and which is not, and file bugs to browsers and ATs if necessary — as it seemed to work in Firefox case above…
> 
> [SelenIT](http://css-live.ru/); 23 February 2018 at 5:57 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93599)

> In response to [SelenIT](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93599). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93606#respond)
> 
> Aren’t these statements kind of contradicting each other?
> 
> No. The first statement describes where we are today. The second statement is a plea to hopefully help make it easier for heuristics to make better guesses (by not abusing the intent of the CSS `display` property).
> 
> Related, there is a [Firefox bug](https://bugzilla.mozilla.org/show_bug.cgi?id=1005271) that changing the `display` property of a `<table>` blows away its semantics. It is still open. The bug you cited (and which was resolved) was about the addition of table semantics to non-`<table>` elements just because `display: table` is added. They both need to be addressed to prevent the issues we are experiencing.
> 
> You ask why this should be the problem of web developers, and I answer that it is our job. It has always been our job. We are supposed to make things work for our users _and_ file bugs when the specs and browsers get it wrong.
> 
> Let me try a heavy-handed analogy — it should be up to municipalities to fix potholes on their roads so car makers do not have to install shocks. So let’s build cars with no shocks. That will force municipalities to fix their roads.
> 
> Unfortunately, not all design requirements can be currently reasonably met with CSS table model
> 
> I have never needed to use CSS table layout in a project, after building easily hundreds of sites and applications. As a result, I struggle to understand the limitations of CSS table layout since it was never part of my process. My suggestion above is an effort to simplify the heuristics that browsers use to decide what is and isn’t a data table.
> 
> I am also suggesting not overriding real HTML tables with CSS `display` properties, both to developers and browsers.
> 
> [Adrian Roselli](https://adrianroselli.com/); 23 February 2018 at 9:15 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93606)

> In response to [Adrian Roselli](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93606). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93619#respond)
> 
> Adrian, thanks for your reply!
> 
> But I’m still a bit confused about the first statement: doesn’t it turn out that `display:table/table-cell` _does_ affect the semantics of the `‹div›` element (at least in Chrome)? Or do you suggest that changing the semantics of the element by just changing its styling is OK? If so, than, using your cars/roads analogy, this sounds to me like “the potholes are OK, people who complain about them are only trying to save on shocks in the cars they build”. For me, it’s kind of false dichotomy: what car users really want is probably to drive in the cars with good shocks on the roads with no potholes:)
> 
> The Firefox issue about tables loosing their semantics because of the \`display\` value is filed as a bug — yet open, but still a bug, not a feature, not “resolved wontfix”. I agree that it may be hard to decouple the semantics from the visual layout (they are called “_screen_ readers”, after all!). But… being unable to use a proper markup to express the intended meaning and visually enhance it with advanced layout tools because browsers can’t treat it as intended because their heuristics are optimized for the old messy markup feels kind of unjust. It’s like people who consciously follow the HTML spec recommendation get punished for the sins of the ancient web coders who had no idea what they were doing.
> 
> I agree that _currently_ we should avoid overriding the native `display`, as it’s really problematic, and by no means call for “building cars with no shocks”:). But I don’t want this situation to last forever. I hope this second Firefox bug will be resolved at some point, as well as similar bugs for other browsers (if they are not filed yet, they should be). Screen readers shouldn’t drop the table semantics from something that is marked up properly as a data table, visually looks like a nice data table and quacks like a data table, just because it doesn’t use the “magic” CSS value for its `display`. The less such implicit “magic” would be there in the platform at all, the simpler would be the browser heuristics, and the easier it would be for web devs to create the best experience for all the users. Of course, we need some stats first, how much existing content relies on that “magic” — but I hope it’s not really that much of it.
> 
> I also couldn’t find any place in CSS specs saying anything about influence of CSS display to the meaning. The only place where CSS is mentioned as a possible indicator of table meaning seems to be the HTML spec saying that “Explicit visible borders set using CSS” mean that a table is “Probably a non-layout table”. But the introduction section [in the CSS Display spec draft](https://www.w3.org/TR/css-display/#intro) has a note mentioning that `display` can interact with the speech output, and links to the CSS Speech module (though very outdated). Maybe the CSS Display module is the best place to clarify this issue as well?
> 
> [SelenIT](http://css-live.ru/); 23 February 2018 at 2:19 pm. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93619)

> In response to [SelenIT](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93619). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93682#respond)
> 
> doesn’t it turn out that `display:table/table-cell` does affect the semantics of the `<div>` element (at least in Chrome)?
> 
> No. Check the Chrome accessibility inspector. It is just a generic container.
> 
> Or do you suggest that changing the semantics of the element by just changing its styling is OK?
> 
> No. Since much of the rest of your response is predicated on one or both of those being _yes_, I’ll just tackle specific points you make.
> 
> It’s like people who consciously follow the HTML spec recommendation get punished for the sins of the ancient web coders who had no idea what they were doing.
> 
> Much of HTML 5 was built to reflect current and historic practice. If anything, the spec is the _result_ of those earlier coders.
> 
> I hope this second Firefox bug will be resolved at some point, as well as similar bugs for other browsers (if they are not filed yet, they should be).
> 
> You can contribute by looking for open issues and posting your concerns, and when those issues do not exist, filing them.
> 
> Maybe the CSS Display module is the best place to clarify this issue as well?
> 
> I see some new bug filings in your future!
> 
> [Adrian Roselli](https://adrianroselli.com/); 24 February 2018 at 2:29 pm. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93682)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93876#respond)
> 
> Tables are probably toughest to make responsive. Most approaches we tried were based on div / span – however it has its own trade off.
> 
> I like this approach better. Though, some issues I see are minor.  
> Can we not assume role=’row’ for any tr ? I am not feeling comfortable with the redundancy of calling it tr and role both where it can be inferred.
> 
> [Dev](http://www.fromdev.com/); 28 February 2018 at 2:20 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93876)

> In response to [Dev](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93876). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93904#respond)
> 
> You can experiment with removing the `role` from `<tr>` and testing it with more screen reader / browser combinations. I agree, I do not like having to add them either.
> 
> [Adrian Roselli](https://adrianroselli.com/); 28 February 2018 at 11:48 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93904)

> In response to [Adrian Roselli](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93904). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93942#respond)
> 
> Toughest part for me right now is to debug these stylings and JS issues in iOS devices. For most part safari does help, however when it does not work – it does not work and frustrates me to hell.
> 
> May be I have not come across a better tool to debug CSS / JS in actual devices. Browser addons have kind of spoiled my creativity I guess.
> 
> I would like to know how do u debug these one of device specific issues that wont happen on a simulator.
> 
> [Dev](http://www.fromdev.com/); 1 March 2018 at 2:22 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93942)

> In response to [Dev](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93942). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=93943#respond)
> 
> Just to give more context on a sample issue I am currently struggling. It is actually JS issue but cant debug it –
> 
> I wrote this simple math practice tool for my kid to learn math tables.
> 
> obviously it had to be responsive so I picked a template that worked pretty well for styling part. But my JS seems to not work on iPad
> 
> it works on safari with ipad user agent.
> 
> [http://math.imustread.com/multiplication/practice.html](http://math.imustread.com/multiplication/practice.html)
> 
> this is open source on github here  
> [https://github.com/fromdev/math/blob/master/multiplication/practice.html](https://github.com/fromdev/math/blob/master/multiplication/practice.html)
> 
> [Dev](http://www.fromdev.com/); 1 March 2018 at 2:31 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93943)

> In response to [Dev](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-93943). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=94101#respond)
> 
> Short of getting your hands on a device and running a remote debugger, there isn’t much help I can offer on testing on your iPad. A Google search brought me to this [set of instructions for remote debugging](https://appletoolbox.com/2014/05/use-web-inspector-debug-mobile-safari/). It is from 2014 but updated a few days ago.
> 
> [Adrian Roselli](https://adrianroselli.com/); 3 March 2018 at 4:39 pm. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-94101)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=113770#respond)
> 
> Hi Adrian,
> 
> It’s Teddy again. Just noticed that Voiceover on my iPhone isn’t recognizing the ARIA table as a data table and doesn’t read the caption, but it does read the rest of the table’s contents.
> 
> Whereas it was the opposite with your previous no-ARIA semantic table, recognized the table, read the caption, but couldn’t read the rest of the table.
> 
> Teddy; 27 October 2018 at 8:39 pm. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-113770)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=128368#respond)
> 
> Update: This is marked as fixed in Firefox 62. Just checked [Steve’s test case](https://s.codepen.io/stevef/debug/xYBJNd) in the accessibility tree and in NVDA and it looks fixed indeed, for display:block.
> 
> For Flex and Grid the table is identified as such, but table nav is broken.
> 
> In Chrome + NVDA all the non-default tables are just skipped.
> 
> [Manuel](https://twitter.com/mrazzari); 14 January 2019 at 10:16 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-128368)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=155728#respond)
> 
> > Setting `display: table` and related does not impart HTML table semantics to (`<div>`) layouts that used it for things like vertical centering.
> 
> For Safari + VoiceOver on iOS specifically, this does incorrectly announce `table` semantics in the form of, _“Table start…”_ and _“Table end…”_
> 
> [Demo on CodePen](https://codepen.io/svinkle/pen/dBVzRx).
> 
> Recommended to use [Flexbox](https://css-tricks.com/snippets/css/a-guide-to-flexbox/) instead for layout.
> 
> [Scott](https://svinkle.me/); 26 June 2019 at 11:07 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-155728)

> In response to [Scott](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-155728). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=155730#respond)
> 
> Thanks, Scott. The note and demo are helpful.
> 
> [Adrian Roselli](https://adrianroselli.com/); 26 June 2019 at 12:00 pm. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-155730)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=157715#respond)
> 
> \[…\] Tables, CSS Display Properties, and ARIA | Adrian Roselli – More on responsive, accessible tables with ARIA \[…\]
> 
> [Weeknotes - w/c 1st July 2019 ~ Pete Lambert](https://www.petelambert.com/journal/weeknotes-01-jul-2019/); 8 July 2019 at 6:49 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-157715)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=225129#respond)
> 
> Thanks for the good article. Do we know if FF or Safari have stopped dumping table semantics when CSS `display` is applied?
> 
> Robert; 11 November 2021 at 1:06 pm. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-225129)

> In response to [Robert](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-225129). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=225137#respond)
> 
> Firefox 94 seems fine. My Mac is \[_waves arm_\] over there, so I cannot check it right now. However, if you take the embedded pen from above and inspect the accessibility properties you can confirm support (or lack). As for when this was fixed, you can dig into the issue history for specific release. Either way, things are much better now then they were 3½ years ago.
> 
> [Adrian Roselli](https://adrianroselli.com/); 11 November 2021 at 4:40 pm. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-225137)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=271035#respond)
> 
> Just found the article. It was very helpful. Big thank for updating it.
> 
> Anon; 20 November 2023 at 12:48 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-271035)

> [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=425341#respond)
> 
> Hi Adrian, I’ve been looking in to tables recently, and came across some strange behaviour with NVDA and JAWS not announcing content as expected.
> 
> The examples I’ve been reviewing are somewhat more niche, as they all use a nested/multi-level header and are reliant on the colspan attribute working correctly. However, from my testing, it seems like it could be `display: grid`, `display: flex`, and `display: contents`, which when applied, prevent the `colspan` attribute from being picked up as expected.
> 
> I’ve made a test case for each issue and recorded myself encountering the issue with each case using JAWS: [collection of test cases where colspan is affected by the CSS display](https://codepen.io/collection/rBpYwy/d0c6c2446d43e07d0054629ae0f090f1?grid_type=LIST)
> 
> I wondered if, on the surface of things, my theory seems plausible, or whether I’ve maybe missed something more fundamental?
> 
> Joe Lamyman; 28 July 2026 at 10:08 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-425341)

> In response to [Joe Lamyman](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-425341). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=425398#respond)
> 
> On the surface, your theory is plausible.
> 
> In what browser(s) did you experience this?
> 
> Have you seen my post [Avoid Spanning Table Headers](https://adrianroselli.com/2023/02/avoid-spanning-table-headers.html)? Wondering if your experience aligns with that.
> 
> At a conference right now and on mobile, but I may be able to check later on my copies of JAWS and NVDA.
> 
> Either way, this sounds like a fun one to unpack!
> 
> [Adrian Roselli](https://adrianroselli.com/); 28 July 2026 at 5:37 pm. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-425398)

> In response to [Adrian Roselli](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-425398). [Reply](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html?replytocom=425513#respond)
> 
> Thank you for getting back to me on this – I really appreciate the response. I’ve spent quite a while trying to diagnose the issues, so to know that I’ve hopefully not missed something important is reassuring. I’ve been experiencing these problems when using JAWS + Chrome (this combination results in the worst behaviours), as well as NVDA + Firefox.
> 
> I hadn’t seen that article, thank you for the pointer!
> 
> Reviewing the different examples, there is consistency in the JAWS behaviour I’ve encountered.
> 
> In all three examples, despite the “ISBN” and “Formats Available” columns being marked up similarly, when trying to navigate from the “Audio” or “Digital” cells, back up to “Formats Available”, JAWS announces: “Top of column”.
> 
> This is similar to the experience I’ve encountered: in my test cases JAWS doesn’t allow navigation from the header cells to the following data cells, as it announces: “bottom of column”.
> 
> Back to your examples, JAWS is fine when navigating from “10” to “ISBN”, which I find very strange. Additionally, unlike the test cases I made, in your examples, there doesn’t seem to be any changes to the default display styling (which is what I thought may be causing the issues I encountered).
> 
> I took a step back and inspected all three examples and it seems like the UIA API is picking up that the headers should span the expected number of columns, so I’m very confused as to why JAWS is behaving like this.
> 
> I’m wondering if my test cases are browser-specific issues, given that the accessibility APIs don’t seem to be getting the correct column span values, but that your examples may be AT-specific issues, given that the APIs do seem to receive the expected column spanning values. I’m very inexperienced with these types of bugs, so if that logic doesn’t hold, please feel free to call me out! Otherwise, I’ll try and file these bugs in the respective places.
> 
> Joe Lamyman; 29 July 2026 at 11:11 am. [Permalink](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html#comment-425513)

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

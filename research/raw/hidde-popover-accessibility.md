# On popover accessibility: what the browser does and doesn’t do | hidde.blog

<https://hidde.blog/popover-accessibility/>

[Blog](https://hidde.blog/blog/) [Links](https://hidde.blog/links/) [Speaking](https://hidde.blog/speaking/) [About me](https://hidde.blog/about-me/) [Contact](https://hidde.blog/contact/)

# On popover accessibility: what the browser does and doesn’t do

Published 2024-03-21 in [category: accessibility](https://hidde.blog/categories/accessibility)  
by Hidde de Vries and Scott O'Hara (last [updated](https://hidde.blog/popover-accessibility/#post-updates) on 15 March 2025)

One of the premises of the new [popover attribute](https://html.spec.whatwg.org/multipage/popover.html#the-popover-attribute) is that it comes with general accessibility considerations “built in”. What does “built in accessibility” actually mean for browsers that support popover?

_See also: [Scott's post Popping preconceived popover ponderings](https://www.scottohara.me/blog/2025/03/14/popovers.html) and [Hidde's talk on popovers](https://www.youtube.com/watch?v=uZRp7yY8SS0), and other posts about [popover semantics](https://hidde.blog/popover-semantics/), [positioning popovers](https://hidde.blog/popover-accessibility/positioning-anchored-popovers/) and the [difference with dialogs and other components](https://hidde.blog/dialog-modal-popover-differences/)._

About this post

## In this post[#heading-1](https://hidde.blog/popover-accessibility/#heading-1)

1.  [Accessibility semantics](https://hidde.blog/popover-accessibility/#heading-2)
2.  [What browsers do](https://hidde.blog/popover-accessibility/#heading-3) (aria-expanded, aria-details, group, keyboard accessibility)
3.  [What browsers don't do](https://hidde.blog/popover-accessibility/#heading-4)
5.  [Conclusion](https://hidde.blog/popover-accessibility/#heading-5)

## **Accessibility semantics**[#heading-2](https://hidde.blog/popover-accessibility/#heading-2)

The “built-in” accessibility of popover is in the addition of _guardrails_: browsers try to improve accessibility where they can. These guardrails exist mostly in the form of browsers augmenting _accessibility semantics_. Before we get into what those guardrails are, let's clarify what that term means.

Many features of HTML have some amount of [accessibility semantics](https://www.w3.org/TR/wai-aria-1.2/#at_support) associated with them - e.g., roles, states and properties. This is information that a web page exposes, which browsers then pass on to platform accessibility APIs. They do this, so that assistive technologies can build UIs around them (see: [How accessibility trees inform assistive tech](https://hidde.blog/how-accessibility-trees-inform-assistive-tech/)). These semantics are sometimes baked into native HTML elements. For instance, headings and lists have implicit roles (heading and list, respectively). Other elements, like the checkbox input type, have an implicit role as well as additional states and properties. Developers can use HTML elements with such “built-in” semantics. But they can also set, overwrite and augment accessibility semantics more directly in their HTML structure, using [WAI-ARIA](https://www.w3.org/TR/wai-aria-1.2/).

The thing with the popover attribute is that it doesn’t have a built-in role. After all, it’s not an element. Its purpose is to only add “popover behaviour”, as discussed in [Popover semantics](https://hidde.blog/popover-semantics/). In that sense, `popover` is a bit like [tabindex](https://html.spec.whatwg.org/dev/interaction.html#the-tabindex-attribute) or [contenteditable](https://html.spec.whatwg.org/dev/interaction.html#contenteditable). These attributes also add behaviour: tabability and editability behaviours, respectively.

A major reason for this choice is that there are a number of components that exhibit popover behaviours. Examples include menus, “toast” messages, sub-navigation lists of links and tooltips. You can use popover on a specific element, then it will get that element's role. Or you can use it with a generic element, and add a `role` that best matches what you are building.

So, while the default role is ‘generally’ not handled by the attribute (more on that later), there are other semantics (properties and states) that the attribute will expose. Browsers can take care of those with some degree of confidence.

## What browsers do[#heading-3](https://hidde.blog/popover-accessibility/#heading-3)

There are two semantics that the browser should take care of when you use `popover`, and its associated `popovertarget` attribute. Additionally, there is some keyboard focus behaviour that may also be handled automatically, depending on the type of popover you are using.

### The `aria-expanded` state

First, `aria-expanded`. This state is exposed on the element that invokes the popover, currently limited to buttons (for a variety of reasons that would require a whole other article to talk about - so this is all you get right now). When a popover is invoked by / associated with a button with the popovertarget attribute, the browser will automatically convey whether the popover is in the expanded (rendered) state, or if it is in the collapsed (hidden) state. This is implemented in Edge, Chrome, Firefox and Safari.

For the following example, the ‘heyo’ button will automatically convey whether its associated popover list is in the expanded or collapsed state, based on whether the popover list is invoked as a popover.

```html
<button popovertarget=p>
  Heyo
</button>

…

<ul 
  aria-label="Heyo subpages" 
  id=p 
  popover
></ul>
```

_Note: the state won’t be applied if script, rather than the declarative attribute, does the opening on click of any button (or any other element). Needless to say: it also doesn’t work if there isn’t an invoking button, for instance, and script invokes this popover (because in that case, there isn’t any expanding going on). Additionally, if you force open your popover using CSS display block, then it will not be rendered as a popover - and thus the button will still communicate that the “popover” is in the collapsed state. Also, if you’re doing that - forcing your popover open with CSS - maybe you have some things you need to reconsider with your UI._

### The `aria-details` relationship

When the popover doesn’t immediately follow its invoking button in the accessibility tree, browsers are supposed to create an [`aria-details`](https://w3c.github.io/aria/#aria-details) relationship on the popover’s invoking button with its associated popover. At the time of writing, this is implemented in Chrome, Edge and Firefox.

For instance, in the following markup snippet an implicit `aria-details` relationship will be made with the button that invokes the popover, because the button and the popover are not immediate siblings in the accessibility tree.

```html
<button popovertarget=foo>something</button>

<p>...</p>

<div role=whatever popover id=foo>...</div>
```

Similarly, an `aria-details` relationship will be made with the next markup snippet too, because even though the popover and its invoking button are siblings, the popover is a _previous_ sibling to the invoking element, and it might not be understood _which_ element is the popover, because it doesn’t immediately follow the element that invoked it.

```html
<div role=whatever popover id=foo>...</div>

<button popovertarget=foo>something</button>
```

In contrast, the next two examples have no aria-details association because that would be unnecessary. For the first, the popover is the immediate next sibling in the accessibility tree (note divs are generic and often ignored when they do not provide information important to accessibility). For the second, the button is a descendant of the popover, so browsers do not need to tell users that the button they are interacting with is about the context they are within. That’d be silly.

```html
<!--  
  example 1: 
  popover immediate sibling in acc tree 
-->
<button popovertarget=m>something</button>
<div class=presentational-styles-only>
  …
  <div role=menu popover id=m>...</div>
</div>

<!-- 
  example 2:
  button descendant of popoover
-->

<dialog popover id=d>
  <button popovertarget=d>close</button>
  …
</dialog>
```

For more information on how `aria-details` works, check out the [details in the ARIA spec](https://w3c.github.io/aria/#aria-details).

Note: `aria-details` is often confused with `aria-describedby`. That makes sense, “details” and “descriptions” are very similar. However, these two properties expose different information. `aria-describedby` takes the associated element’s content, flattens it into a single text string, and exposes that as the ‘description’ or ‘hint’ of the element which the attribute is specified. In contrast, `aria-details` only _informs_ a user that there is additional information about the current element. That might not seem useful, until you know that screen readers largely provide quick-keys to navigate to and from that associated element which provides the details.

At the time of writing, navigating into the referenced content using quick-keys is supported by JAWS and NVDA ([release notes](https://github.com/nvaccess/addonFiles/pull/392)), but not VoiceOver.

Here’s a quick demo of that with JAWS 2023 in Edge 124. JAWS lets us jump to the details content if we press `Alt + Ins + D`:

In NVDA (2023.3.4), tested with Edge 124, it works slightly differently: when you press the shortcut (`NVDA + D`), we don't jump to the details content, but it is read out after the shortcut is pressed:

(see [demo on CodePen](https://codepen.io/hidde/pen/abxZVLX/); note: announcements and shortcuts depend on the user's settings, versions, etc)

In the following demo, you can see how the `aria-details` relationship works between popovers and their invokers (in JAWS 2023 with Edge 124):

(video contains screenshot of code, see [demo on CodePen](https://codepen.io/scottohara/pen/vYQqjbZ?editors=1000))

In summary: the `aria-details` association is not announced by JAWS when we focus the invoking button for the first time. This is because the corresponding popover is hidden, so the association isn't made yet. After we open the popover, JAWS announces the button's “has details” association while it is open, to hear it we navigate away and back. This is also how it works in NVDA, which, in addition, also requires you to switch to forms mode to actually hear the relationship announced.

Warning: even if the `aria-details` association is implemented, it may not be completely ironed out in how the UX behaves for people. For instance, there isn't currently a way for users to find out about the details relationship once it is established, like when the popover opened. It requires for the user to move away from the button and return to it, at which point the relationship is announced. Maybe it would be helpful if the browser would fire some kind of event, to let AT like JAWS know that an element representing details has appeared.

We mention this not to deter you from using popover or to indicate that anyone is doing something “wrong” here. Rather, this is a relatively new feature that people still need to figure out some of the UX kinks around. Feedback is welcome, and to help ensure the best UX is provided, please reach out to the necessary browsers / AT with your thoughts.

### The `group` role

As mentioned above, popover can be used on any element, including elements that don’t have a built-in role, like `div`. But even without a role, it’s likely that the contents of a popover form some kind of meaningful whole. This is why in Chrome, Edge and Firefox, a role of `group` is automatically added to popovers if they would otherwise have no role, or a role of `generic` (for instance, divs and spans).

The `group` role is added, so that assistive technology can have the option to expose the boundaries of the popover that is being displayed. This can be important to users, because a popover is a behavior and visual treatment of its content. How is one to know where such content begins or ends if it doesn’t have boundaries to expose?

It’s important to know that an unnamed group is often ignored by screen readers. This is because otherwise the Internet would be riddled with unhelpful “group” announcements. (See also why Webkit made the decision to remove list semantics from lists that have been styled to _not look like lists_. These topics are related). Here though, it again comes down to what assistive technology wants to do. By exposing the group role for the popover, now the element can be named by authors, which will force the group role to be exposed in most cases. Then, if AT decided they want to do something special for popover groups, they now have the opportunity to do so.

### Keyboard accessibility

One more aspect of “built-in accessibility” that browsers do for your popover, is take care of some keyboard behaviors.

#### Moving focus back to invoking element

Edge/Chrome, Firefox and Safari will all return focus to the invoking element when you close the popover (only if you are inside of it). This is useful, because if focus was on an element inside the popover, the default would be to return focus to the start of the document. Various groups of users would get lost, increasingly so on pages with a lot of content. Moving focus back to the invoking element helps ensure people can quickly return to what they were doing, rather than spending time having to re-navigate to where they think they were last.

#### Popover content in tab order

Desktop browsers also do something else: they add the popover content into the tab order just after the invoking button. Even if that’s not where the popover is in the DOM.

Imagine this DOM structure:

```html
<button popovertarget=p>Open popover</button>

<p>content… content… <a href="#">link 1</a></p>

<p>content… content… <a href="#">link 2</a></p>

<div popover id="p"><a href="#">link 3</a></div>
```

When the popover opens, and you press `Tab`, you might think you’d jump to “link 1”, the next interactive element in the DOM. Except, in desktop browsers, you will jump to “link 3” instead. The browser basically moves the popover content’s position in tab order to just after its invoking button. This takes it out of its expected position in the tab order. That improves the user experience, because it is likely that upon opening the popover, users will want to interact with its contents.

Keep in mind: browsers adjust the Tab order for instances like this, but they don't adjust the placement of the content in the accessibility tree. This is why the `aria-details` association was implemented. This special Tab order behavior helps ensure logical focus order for keyboard accessibility. However, we should still strive to make sure our popovers come _after_ the invoking element in the DOM.

But since there will be times where the exact location of the popover in the DOM may be out of one’s control, this behavior is still quite welcome. For instance, if the popover happens to be far away in the DOM, having to go through the rest of the document before reaching the popover would be a nuisance. It would be highly unexpected and unwanted to have to navigate through all other focusable elements in the DOM, prior to the popover one just opened. WCAG [2.4.3 Focus Order](https://www.w3.org/TR/WCAG22/#focus-order) requires focusable elements to receive focus in an order that “preserves meaning and operability”. This special browser Tab restructuring helps ensure that requirement can be met.

## What browsers don’t do[#heading-4](https://hidde.blog/popover-accessibility/#heading-4)

We can keep this one short: the browser will not do _anything_ apart from the behaviours listed above. Browsers will not add behaviors based on which elements you use or which role you add to them. The `popover` attribute is merely a first step for us to build new components.

## Conclusion[#heading-5](https://hidde.blog/popover-accessibility/#heading-5)

The `popover` attribute provides a starting point for building popover-like interactions on the web. Browsers don't magically make your components accessible, that's not a thing. But there are some specific keyboard behaviours included with popover, as well as these semantics:

-   In specific cases, browsers set the `aria-expanded` state and/or set the `aria-details` relationship on the invoker.
-   Browsers apply the `group` role to the `popover` content if it doesn’t have a role of its own, so that assistive technologies can expose their boundaries.

_Browser support note: at the time of writing, Safari only sets `aria-expanded`, not `aria-details`. It also doesn't add a `group` role fallback._

List of updates

Hidde de Vries ([@hdv@front-end.social](https://front-end.social/@hdv)) is a web enthusiast from Rotterdam, The Netherlands. He currently works on accessibility standards for the Dutch government (views his own) and is in the [W3C's AB](https://w3.org/ab). Previously, he worked for Mozilla, W3C/WAI, national and local governments, Sanoma Learning and others as a freelancer. Hidde is a public speaker ([all 99 talks](https://talks.hiddedevries.nl/)). In his free time, he works on a coffee table book covering the video conferencing apps of our decade.

[Buy me a coffee](https://ko-fi.com/hidde) [Follow on Mastodon](https://front-end.social/@hdv) [Follow on LinkedIn](https://linkedin.com/in/hiddedevries)

## Comments, likes & shares (225)

[Michelle Barker](https://front-end.social/@hdv/112134591834927462#favorited-by-109370481765285711), [Sara Joy :happy\_pepper:](https://front-end.social/@hdv/112134591834927462#favorited-by-109295906487756020), [Sheldon Chang ????????](https://front-end.social/@hdv/112134591834927462#favorited-by-109391704861996048), [Baldur Bjarnason](https://front-end.social/@hdv/112134591834927462#favorited-by-109292253091046345), [Daniel Göransson](https://front-end.social/@hdv/112134591834927462#favorited-by-109507287965925528), [NekoOverflow](https://front-end.social/@hdv/112134591834927462#favorited-by-109300104879163466), [Florian Schroiff](https://front-end.social/@hdv/112134591834927462#favorited-by-109760296057444372), [Dr. Angus Andrea Grieve-Smith](https://front-end.social/@hdv/112134591834927462#favorited-by-109314819163626409), [Apple Annie :prami:](https://front-end.social/@hdv/112134591834927462#favorited-by-109740646094210771), [Joe Lanman](https://front-end.social/@hdv/112134591834927462#favorited-by-109772795610356960), [weilawei](https://front-end.social/@hdv/112134591834927462#favorited-by-110650026963497402), [CSS Café](https://front-end.social/@hdv/112134591834927462#favorited-by-109994375428042969), [Dave Rupert](https://front-end.social/@hdv/112134591834927462#favorited-by-109287751678680224), [Stephanie Eckles](https://front-end.social/@hdv/112134591834927462#favorited-by-109361730441865465), [Ville V. Vanninen](https://front-end.social/@hdv/112134591834927462#favorited-by-109302418304426301), [Curtis Wilcox](https://front-end.social/@hdv/112134591834927462#favorited-by-109529405942425497), [Scott Orchard](https://front-end.social/@hdv/112134591834927462#favorited-by-109389791290398031), [Brett Ritter](https://front-end.social/@hdv/112134591834927462#favorited-by-109518771755479525), [Heather Migliorisi](https://front-end.social/@hdv/112134591834927462#favorited-by-109288114698941482), [kolya](https://front-end.social/@hdv/112134591834927462#favorited-by-109299003211013072), [katherine](https://front-end.social/@hdv/112134591834927462#favorited-by-109374512363114509), [Roma Komarov](https://front-end.social/@hdv/112134591834927462#favorited-by-109298881215298619), [Sophie](https://front-end.social/@hdv/112134591834927462#favorited-by-109513729749989690), [Vincent Valentin](https://front-end.social/@hdv/112134591834927462#favorited-by-109479830339062938), [Bernhard :firefish:](https://front-end.social/@hdv/112134591834927462#favorited-by-111528558604840719), [Sarah T](https://front-end.social/@hdv/112134591834927462#favorited-by-110333468642632110), [Andrew Sutherland](https://front-end.social/@hdv/112134591834927462#favorited-by-110163935432005664), [Patrick Grey](https://front-end.social/@hdv/112134591834927462#favorited-by-109308938893617109), [bkardell](https://front-end.social/@hdv/112134591834927462#favorited-by-109288468466191466), [Luke](https://front-end.social/@hdv/112134591834927462#favorited-by-110107187161007767), [Simon St.Laurent](https://front-end.social/@hdv/112134591834927462#favorited-by-109354131204471029), [Samir Saeedi :firedoge:](https://front-end.social/@hdv/112134591834927462#favorited-by-109315155690182519), [Konnor Rogers](https://front-end.social/@hdv/112134591834927462#favorited-by-109320079549647216), [Tamas G](https://front-end.social/@hdv/112134591834927462#favorited-by-109719992436852008), [Megan Lynch (she/her)](https://front-end.social/@hdv/112134591834927462#favorited-by-109295709867242287), [Bonaventure Software](https://front-end.social/@hdv/112134591834927462#favorited-by-109524513871796894), [Jason Neel](https://front-end.social/@hdv/112134591834927462#favorited-by-109294764166058848), [{sydney:webdev}](https://front-end.social/@hdv/112134591834927462#favorited-by-109366750081121119), [mj12albert](https://front-end.social/@hdv/112134591834927462#favorited-by-109391917157842689), [Pratik Patel](https://front-end.social/@hdv/112134591834927462#favorited-by-109423683874434421), [Seth A. Roby](https://front-end.social/@hdv/112134591834927462#favorited-by-109366765753373118), [Steve Bogart ????](https://front-end.social/@hdv/112134591834927462#favorited-by-109354641185322512), [Erik Pavletic](https://front-end.social/@hdv/112134591834927462#favorited-by-109440127536443331), [Manuel Matuzović](https://front-end.social/@hdv/112134591834927462#favorited-by-109417602310639127), [Krzysztof Jeziorny](https://front-end.social/@hdv/112134591834927462#favorited-by-109371368750784158), [Sha Razeek](https://front-end.social/@hdv/112134591834927462#favorited-by-109808344158477596), [Quentin Delance](https://front-end.social/@hdv/112134591834927462#favorited-by-111538245973044880), [.js](https://front-end.social/@hdv/112134591834927462#favorited-by-109294677957284521), [Stan Chang ????](https://front-end.social/@hdv/112134591834927462#favorited-by-109298645131941539), [Taiyo Totsuka :sabakan:](https://front-end.social/@hdv/112134591834927462#favorited-by-109550082015762396), [Eric Jonathan Martin](https://front-end.social/@hdv/112134591834927462#favorited-by-109370917670978212), [mkelandis](https://front-end.social/@hdv/112134591834927462#favorited-by-109395411769739025), [Philipp Tootloff](https://front-end.social/@hdv/112134591834927462#favorited-by-109288880481403409), [Fynn Becker](https://front-end.social/@hdv/112134591834927462#favorited-by-109288696159445865), [Zach Leatherman :verify:](https://front-end.social/@hdv/112134591834927462#favorited-by-109287923857668672), [Jeff Caldwell](https://front-end.social/@hdv/112134591834927462#favorited-by-109371798347670750), [Oskar im Keller](https://front-end.social/@hdv/112134591834927462#favorited-by-109409005975021516), [cincylee@mastodon.social](https://front-end.social/@hdv/112134591834927462#favorited-by-109950558197562102), [Anton ????????????????](https://front-end.social/@hdv/112134591834927462#favorited-by-109333543286048848), [Aaron In Iowa](https://front-end.social/@hdv/112134591834927462#favorited-by-109304576545923028), [Hamish Mackenzie](https://front-end.social/@hdv/112134591834927462#favorited-by-110297581420952688), [Frank // Mottokrosh](https://front-end.social/@hdv/112134591834927462#favorited-by-112009595676132535), [Mckensie parker](https://front-end.social/@hdv/112134591834927462#favorited-by-112141932382508563), [Adam](https://front-end.social/@hdv/112134591834927462#favorited-by-109292469687193353), [roycifer](https://front-end.social/@hdv/112134591834927462#favorited-by-109306260621201355), [Timo Tijhof](https://front-end.social/@hdv/112134591834927462#favorited-by-109293603037070680), [Callie ????️‍⚧️](https://front-end.social/@hdv/112134591834927462#favorited-by-109299670780400847), [Royce Williams](https://front-end.social/@hdv/112134591834927462#favorited-by-109301116327707978), [Cathal](https://front-end.social/@hdv/112134591834927462#favorited-by-109343679781386913), [Wubbels](https://front-end.social/@hdv/112134591834927462#favorited-by-109503833781400368), [Melanie](https://front-end.social/@hdv/112333498561540277#favorited-by-109287940168299871), [Ryan Trimble](https://front-end.social/@hdv/112384366479698799#favorited-by-109292468662905667), [Ana Rodrigues](https://front-end.social/@hdv/112384366479698799#favorited-by-112003000486235188), [Daniel Göransson](https://front-end.social/@hdv/112384366479698799#favorited-by-109507287965925528), [Robb](https://front-end.social/@hdv/112384366479698799#favorited-by-109292473355859787), [Luke](https://front-end.social/@hdv/112587676667764158#favorited-by-110107187161007767), [Curtis Wilcox](https://front-end.social/@hdv/112587676667764158#favorited-by-109529405942425497), [steve.rss](https://front-end.social/@hdv/112587676667764158#favorited-by-109313902106109178), [Dennis Frank](https://front-end.social/@hdv/112587676667764158#favorited-by-109294613022126534), [John P. Green](https://front-end.social/@hdv/112587676667764158#favorited-by-109293024892840895), [Vadim Makeev](https://front-end.social/@hdv/112587676667764158#favorited-by-109288696756728038), [Bart van de Biezen](https://front-end.social/@hdv/112587676667764158#favorited-by-109294066201458356), [Daniel Göransson](https://front-end.social/@hdv/112587676667764158#favorited-by-109507287965925528), [Jon](https://front-end.social/@hdv/112587676667764158#favorited-by-109288830979951165), [W3C Developers](https://front-end.social/@hdv/113188974330280905#favorited-by-109320840872595574), [Adam Argyle](https://front-end.social/@hdv/113188974330280905#favorited-by-109665576298351061), [Matthias Ott](https://front-end.social/@hdv/113188974330280905#favorited-by-109287752283181975), [Tyler Sticka](https://front-end.social/@hdv/113189125299114576#favorited-by-110651353810564612), [Punnamaraju Vinayaka Tejas](https://front-end.social/@hdv/113188974330280905#favorited-by-109397628053458540), [⬜️????](https://front-end.social/@hdv/114201292456165192#favorited-by-109552852352010086), [Johannes Odland](https://front-end.social/@hdv/114201292456165192#favorited-by-109294229351968136), [mandynicole](https://front-end.social/@hdv/114201292456165192#favorited-by-109293837792053450), [Florian Geierstanger](https://front-end.social/@hdv/114201292456165192#favorited-by-109294894111274110), [Fynn Ellie Becker](https://front-end.social/@hdv/114201292456165192#favorited-by-109288696159445865), [Ken Franqueiro](https://front-end.social/@hdv/114201292456165192#favorited-by-109728589797885575), [Marcus Herrmann](https://front-end.social/@hdv/114201292456165192#favorited-by-110673716177803107), [Ana Rodrigues](https://front-end.social/@hdv/114201292456165192#favorited-by-112003000486235188), [Daniel Göransson](https://front-end.social/@hdv/114201292456165192#favorited-by-109507287965925528), [Ashur Cabrera](https://front-end.social/@hdv/114201292456165192#favorited-by-109292105131235315), [Olliew](https://front-end.social/@hdv/114201292456165192#favorited-by-109744313740229572), [James Basoo](https://front-end.social/@hdv/114201292456165192#favorited-by-109289235092153120), [Sofasophia](https://front-end.social/@hdv/114201292456165192#favorited-by-111005452865205479), [Vadim Makeev](https://front-end.social/@hdv/114201292456165192#favorited-by-109288696756728038), [Monoscope](https://front-end.social/@hdv/114201292456165192#favorited-by-109505077987141452), [Elly Loel](https://front-end.social/@hdv/114201292456165192#favorited-by-109426807254697808), [Michael Fürstenberg](https://front-end.social/@hdv/114201292456165192#favorited-by-109295541515167501), [Connor Bär](https://front-end.social/@hdv/114201292456165192#favorited-by-109330051415183893), [Mark Root-Wiley](https://front-end.social/@hdv/114201292456165192#favorited-by-109786164591195814), [Zacky Ma](https://front-end.social/@hdv/114201292456165192#favorited-by-109639562320344313), [Thomas Günther](https://front-end.social/@hdv/114201292456165192#favorited-by-109331245135857893), [Bart van de Biezen](https://front-end.social/@hdv/114201292456165192#favorited-by-109294066201458356), [Thomas Kräftner](https://front-end.social/@hdv/114201292456165192#favorited-by-109288830828582182), [Flo Gehring](https://front-end.social/@hdv/114201292456165192#favorited-by-109295133046487463), [Marion Dagang](https://front-end.social/@hdv/114201292456165192#favorited-by-114205187843447797) and [Roma Komarov](https://front-end.social/@hdv/114201292456165192#favorited-by-109298881215298619) liked this

[Michelle Barker](https://front-end.social/@hdv/112134591834927462#reblogged-by-109370481765285711), [Sara Joy :happy\_pepper:](https://front-end.social/@hdv/112134591834927462#reblogged-by-109295906487756020), [TheJen - Jen Wojcik](https://front-end.social/@hdv/112134591834927462#reblogged-by-111615627558719533), [Sheldon Chang ????????](https://front-end.social/@hdv/112134591834927462#reblogged-by-109391704861996048), [Baldur Bjarnason](https://front-end.social/@hdv/112134591834927462#reblogged-by-109292253091046345), [keithamus](https://front-end.social/@hdv/112134591834927462#reblogged-by-109337799880940391), [Ben Myers ????](https://front-end.social/@hdv/112134591834927462#reblogged-by-109288262457471021), [Apple Annie :prami:](https://front-end.social/@hdv/112134591834927462#reblogged-by-109740646094210771), [Joe Lanman](https://front-end.social/@hdv/112134591834927462#reblogged-by-109772795610356960), [weilawei](https://front-end.social/@hdv/112134591834927462#reblogged-by-110650026963497402), [Ayo Ayco](https://front-end.social/@hdv/112134591834927462#reblogged-by-109548151054863448), [Dave Rupert](https://front-end.social/@hdv/112134591834927462#reblogged-by-109287751678680224), [Patrick H. Lauke](https://front-end.social/@hdv/112134591834927462#reblogged-by-109288813255314170), [Laura Langdon](https://front-end.social/@hdv/112134591834927462#reblogged-by-109458503472185513), [Stephanie Eckles](https://front-end.social/@hdv/112134591834927462#reblogged-by-109361730441865465), [Curtis Wilcox](https://front-end.social/@hdv/112134591834927462#reblogged-by-109529405942425497), [hypebot](https://front-end.social/@hdv/112134591834927462#reblogged-by-110938466300805783), [Thomas Broyer](https://front-end.social/@hdv/112134591834927462#reblogged-by-109325601329552108), [Christian Puffer](https://front-end.social/@hdv/112134591834927462#reblogged-by-112040637151289756), [Jeroen Zwartepoorte](https://front-end.social/@hdv/112134591834927462#reblogged-by-109694761006835162), [Lachlan Ridley](https://front-end.social/@hdv/112134591834927462#reblogged-by-109380809383602289), [Sophie](https://front-end.social/@hdv/112134591834927462#reblogged-by-109513729749989690), [Bhupesh Singh](https://front-end.social/@hdv/112134591834927462#reblogged-by-109288673460820323), [Sarah T](https://front-end.social/@hdv/112134591834927462#reblogged-by-110333468642632110), [John Kemp-Cruz](https://front-end.social/@hdv/112134591834927462#reblogged-by-109772456952233607), [Patrick Grey](https://front-end.social/@hdv/112134591834927462#reblogged-by-109308938893617109), [Gustav Hansen](https://front-end.social/@hdv/112134591834927462#reblogged-by-109378529902162667), [bkardell](https://front-end.social/@hdv/112134591834927462#reblogged-by-109288468466191466), [Luke](https://front-end.social/@hdv/112134591834927462#reblogged-by-110107187161007767), [Konnor Rogers](https://front-end.social/@hdv/112134591834927462#reblogged-by-109320079549647216), [Drew Mochak](https://front-end.social/@hdv/112134591834927462#reblogged-by-109288983674707081), [Thomas Rigby](https://front-end.social/@hdv/112134591834927462#reblogged-by-111687319879559193), [Adrian Roselli](https://front-end.social/@hdv/112134591834927462#reblogged-by-109288223713254232), [Tamas G](https://front-end.social/@hdv/112134591834927462#reblogged-by-109719992436852008), [kazuhito](https://front-end.social/@hdv/112134591834927462#reblogged-by-109503317439994404), [Krishna Jariwala](https://front-end.social/@hdv/112134591834927462#reblogged-by-109830885740250724), [Jason Neel](https://front-end.social/@hdv/112134591834927462#reblogged-by-109294764166058848), [{sydney:webdev}](https://front-end.social/@hdv/112134591834927462#reblogged-by-109366750081121119), [Nolan](https://front-end.social/@hdv/112134591834927462#reblogged-by-109288496526079738), [Pratik Patel](https://front-end.social/@hdv/112134591834927462#reblogged-by-109423683874434421), [RT bot :verified:](https://front-end.social/@hdv/112134591834927462#reblogged-by-109578207458058996), [Sylvain G.](https://front-end.social/@hdv/112134591834927462#reblogged-by-109521816709532738), [Eyal Eshet](https://front-end.social/@hdv/112134591834927462#reblogged-by-109292923910446343), [just adrienne](https://front-end.social/@hdv/112134591834927462#reblogged-by-109311925812953501), [Seirdy](https://front-end.social/@hdv/112134591834927462#reblogged-by-109293089785718642), [Paul Kinlan](https://front-end.social/@hdv/112134591834927462#reblogged-by-109288742147979509), [Manuel Matuzović](https://front-end.social/@hdv/112134591834927462#reblogged-by-109417602310639127), [Svenja](https://front-end.social/@hdv/112134591834927462#reblogged-by-110718487395257070), [Katja ｢Amethyst｣](https://front-end.social/@hdv/112134591834927462#reblogged-by-109297373322703326), [Daniel](https://front-end.social/@hdv/112134591834927462#reblogged-by-111692642733927468), [Pierre Spring](https://front-end.social/@hdv/112134591834927462#reblogged-by-109485255051589173), [Stan Chang ????](https://front-end.social/@hdv/112134591834927462#reblogged-by-109298645131941539), [Taiyo Totsuka :sabakan:](https://front-end.social/@hdv/112134591834927462#reblogged-by-109550082015762396), [Devin Prater :blind:](https://front-end.social/@hdv/112134591834927462#reblogged-by-111674698510521562), [Fynn Becker](https://front-end.social/@hdv/112134591834927462#reblogged-by-109288696159445865), [Jeff Caldwell](https://front-end.social/@hdv/112134591834927462#reblogged-by-109371798347670750), [Zach Leatherman :verify:](https://front-end.social/@hdv/112134591834927462#reblogged-by-109287923857668672), [Ryan Mulligan](https://front-end.social/@hdv/112134591834927462#reblogged-by-109348281220737565), [Hamish Mackenzie](https://front-end.social/@hdv/112134591834927462#reblogged-by-110297581420952688), [Jake Gross](https://front-end.social/@hdv/112134591834927462#reblogged-by-109356671628769157), [Kaveinthran](https://front-end.social/@hdv/112134591834927462#reblogged-by-109496748139941900), [Åke Järvklo](https://front-end.social/@hdv/112134591834927462#reblogged-by-109881479555643882), [Rob Whittaker :thoughtbot:](https://front-end.social/@hdv/112134591834927462#reblogged-by-109304053720367412), [Timo Tijhof](https://front-end.social/@hdv/112134591834927462#reblogged-by-109293603037070680), [Ana Rodrigues](https://front-end.social/@hdv/112384366479698799#reblogged-by-112003000486235188), [Patrick Grey](https://front-end.social/@hdv/112384366479698799#reblogged-by-109308938893617109), [Apple Annie :prami:](https://front-end.social/@hdv/113188974330280905#reblogged-by-109740646094210771), [W3C Developers](https://front-end.social/@hdv/113188974330280905#reblogged-by-109320840872595574), [Matthias Ott](https://front-end.social/@hdv/113188974330280905#reblogged-by-109287752283181975), [Kaveinthran](https://front-end.social/@hdv/113188974330280905#reblogged-by-109496748139941900), [Bhupesh Singh](https://front-end.social/@hdv/113469439165922680#reblogged-by-109288673460820323), [Fynn Ellie Becker](https://front-end.social/@hdv/114201292456165192#reblogged-by-109288696159445865), [Thomas Michael Semmler](https://front-end.social/@hdv/114201292456165192#reblogged-by-109290566750849012), [Devin Prater :blind:](https://front-end.social/@hdv/114201292456165192#reblogged-by-111674698510521562) and [Sofasophia](https://front-end.social/@hdv/114201292456165192#reblogged-by-111005452865205479) reposted this

**Hidde de Vries (@hdv@front-end.social) is a web enthusiast and accessibility specialist from Rotterdam (The Netherlands). He currently works on web standards for the Dutch government and is a participant in the Open UI Community Group. Previously, he worked for W3C (WAI), Mozilla, the Dutch government and others as a freelancer. Hidde is also a public speaker, he has given 73 talks, most recently in Virtual. In his free time, he works on a coffee table book covering the video conferencing apps of our decade. Buy me a coffee Follow on Mastodon Follow on LinkedIn** wrote on [12 June 2023](https://hidde.blog/positioning-anchored-popovers/Positioning%20anchored%20popovers):

Popovers are commonly positioned relative to their invoker (if they have one). When we use [the popover attribute](https://html.spec.whatwg.org/dev/popover.html#the-popover-attribute), anchoring is tricky, as these popovers are in the top layer, away from the context of their invoker. What options do we have?

_See also: [Hidde's talk on popovers](https://www.youtube.com/watch?v=uZRp7yY8SS0), and other posts about [popover accessibility](https://hidde.blog/popover-accessibility/), [positioning popovers](https://hidde.blog/positioning-anchored-popovers/) and the [difference with dialogs and other components](https://hidde.blog/dialog-modal-popover-differences/)._

Basically, there are two ways to position popovers: one you can use today and one that will be available in the future. I'll detail them below, but first, let's look at why we can't use absolute positioning relative to a container shared by the invoker and the popover.

Not all popovers are anchored, but I expect anchored popovers to be among the most common ones. For popovers that are not anchored, such as toast-like elements, “bottom sheets” or keyboard-triggered command palettes, these positioning constraints do not apply.

_Examples of anchored popovers: map toggletip (Extinction Rebellion), date picker (European Sleeper), colour picker (Microsoft Word web app)_

See also my other posts on popovers:

-   [Dialogs and popovers seem similar. How are they different](https://hidde.blog/dialog-modal-popover-differences/)
-   [Semantics and the popover attribute: what to use when?](https://hidde.blog/popover-semantics/)
-   [On popover accessibility: what the browser does and doesn't do](https://hidde.blog/popover-accessibility/) (with Scott O'Hara)

## Top layer elements lose their positioning context

One of the unique characteristics of popovers (again, the ones made with [the popover attribute](https://html.spec.whatwg.org/dev/popover.html#the-popover-attribute), not just any popover from a design system), is that they get upgraded to the _top layer_. The top layer is a feature drafted in [CSS Positioning, Level 4](https://drafts.csswg.org/css-position-4/#top-layer). The top layer is a layer adjacent to the main document, basically like a bit like a sibling of `<html>`.

Some specifics on the top layer:

-   It's above all `z-index`es in your document, top layer elements can't use `z-index`. Instead, elements are stacked in the order they are added to the top layer.
-   As developers, we can't put elements in the top layer directly, as it is browser controlled. We can only use certain elements and APIs that then trigger the browser to move an element to the top layer: the Full Screen API, `<dialog>`s with `showModal()` and `popover`'ed elements, currently.
-   Top layer elements, quoting the specification, “don't lay out normally based on their position in the document”.

When I positioned my first popover, I tried (and failed): I put both the popover and its invoking element in one element with `position: relative`. Then I applied `position: absolute` to the popover, which I _hoped_ would let me position relative to the container. It didn't, and I think the last item above explains why.

In summary, elements lose their position context when they are upgraded to the top layer. And that's okay, we have other options.

## Option 1: position yourself (manually or with a library)

The first option is to position the popover yourself, with script. Because the fact that the top layer element doesn't know about the non-top layer element's position in CSS, doesn't mean you can't store the invoker's position and calculate a position for the popover itself.

There are some specifics to keep in mind, just like with popovers that are built without the `popover` attribute: what happens when there's no space or when the popover is near the window? Numerous libraries can help with this, such as [Floating UI](https://floating-ui.com/), an evolution of the infamous [Popper](https://popper.js.org/) library.

Let's look at a minimal example using Floating UI. It assumes you have a popover in your HTML that is connected to a button using `popovertarget`:

```
<button popovertarget="p">Toggle popover</button>
<div id="p" popover>… popover contents go here</div>
```

By default, browsers show the open popover in the center of the viewport:

_The popover is centered_

The reason that this happens is that the [UA stylesheet](https://meiert.com/en/blog/user-agent-style-sheets/) applies `margin: auto` to popovers. This will reassign any whitespace around the popover equally to all sides as margins. That checks out: if there's the same amount of whitespace left and right, it element will effectively be in the center horizontally (same for top and bottom, but vertically).

For anchored popovers, we want the popover to be near the button that invoked it, not in the center. Let's look at a minimal code example.

In your JavaScript, first import the `computePosition` function from `@floating-ui`:

```
import { computePosition } from '@floating-ui/dom';
```

Then, find the popover:

```
const popover = document.querySelector('[popover]');
```

Popovers have a [`toggle` event, just like the `<details>` element](https://html.spec.whatwg.org/multipage/indices.html#event-toggle), which we'll listen to:

```
popover.addEventListener('toggle', positionPopover); 
```

In our `positionPopover` function, we'll find the invoker, and then, if the `newState` property of the event is `open`, we'll run the `computePosition` function and set the results of its computation as inline styles.

```
function positionPopover(event) {
  const invoker = document.querySelector(`[popovertarget="${popover.getAttribute('id')}"`);

  if (event.newState === 'open') {
    computePosition(invoker, popover).then(({x, y}) => {
      Object.assign(popover.style, {
        left: `${x}px`,
        top: `${y}px`,
      });
    });
  }
}
```

To make this work, I also applied these two style declarations to the popover:

-   `margin: 0`, because the [UA's auto margin](https://html.spec.whatwg.org/multipage/rendering.html#flow-content-3)'s whitespace gets included in the calculation, with `0` we remove that whitespace
-   `position: absolute`, because popovers get `position: fixed` from the user agent stylesheet and I don't want that on popovers that are anchored to a button

It then looks something like this:

See it in action: [Codepen: Positioning a popover with Floating UI](https://codepen.io/hidde/pen/wvQaRJy/fc4f308d20a3a3118ead55e6553a7d66?editors=1011).

In the Codepen, I also use some Floating UI config to position the popover from the left. In reality, you probably want to use more of Floating UI's features, to deal with things like resizing (see [their tutorial](https://floating-ui.com/docs/tutorial)).

## Option 2: with Anchor Positioning

To make all of this a whole lot easier (and leave the maths to the browser), a new CSS specification is on the way: [Anchor Positioning, Level 1](https://drafts.csswg.org/css-anchor-position-1). It exists so that:

> a positioned element can size and position itself relative to one or more "anchor elements" elsewhere on the page

This, as they say, is _rad_, because it will let the browser do your sizing and positioning maths (even [automatically](https://drafts.csswg.org/css-anchor-position-1/#anchor-auto)\- update 4 May 2024: looks like automatic anchoring was removed). It is also exciting, because it doesn't care where your elements are. They can be anywhere in your DOM. And, important for popovers, it also works across the top layer and root element.

Though popovers would get [implicit anchoring](https://drafts.csswg.org/css-anchor-position-1/#implicit-anchor-element), you can connect a popover with its invoker via CSS. To find out how all of this works in practice, I recommend Jhey Tompkins's [great explainer on Chrome Developers](https://developer.chrome.com/blog/tether-elements-to-each-other-with-css-anchor-positioning/) (but note it's currently somewhat outdated, the editor's draft spec changed since that post, and has new editors). Roman Komarov covers his experiments and some interesting use cases in [Future CSS: Anchor Positioning](https://kizu.dev/anchor-positioning-experiments/), and also wrote [Anchor Positioning on 12 days of web](https://12daysofweb.dev/2023/anchor-positioning).

The Anchor Positioning spec was recently updated, and is currently in the process of being implemented in browsers, hence the Option 1 in this article. But, excitingly, it is in the works. Chromium has already issued an [intent to ship anchor positioning](https://groups.google.com/a/chromium.org/g/blink-dev/c/jGTYNuidPRs/m/-jB4agJ7AAAJ?pli=1), and [so did Mozilla/Gecko](https://groups.google.com/a/mozilla.org/g/dev-platform/c/4cbytMKbHtg). The recent updates are still [pending TAG review](https://github.com/w3ctag/design-reviews/issues/848#issuecomment-2053319901).

## Wrapping up

So, in summary: if your popover needs to be anchored to something, like a button or a form field, you can't “just” use absolute positioning. Instead, you can use JavaScript (today), or, excitingly, _anchor positioning_ (in the near-ish future, an Editor's Draft in CSS was published last year and a new version of that with new editors was released in April 2024.

List of updates

-   6 May 2024: Added that Gecko intents to ship anchor positioning.
-   4 May 2024: Reworded to reflect that the editor's draft of the anchor positioning spec was updated (as editor's drafts are), is now different and not yet passed TAG review.

Thanks to Jhey Tompkins, Mason Freed and Keith Cirkel for explaining and clarifying some of this to me.

[**Ben Myers ????**](https://a11y.info/@ben) wrote on [21 March 2024](https://a11y.info/@ben/112134650285791769):

[@hdv](https://front-end.social/@hdv) [@scottohara](https://a11y.info/@scottohara) Daaaaang, I had no idea about any of this. Kudos to the two of you for such an excellent, helpful post!

[**Hidde**](https://front-end.social/@hdv) wrote on [21 March 2024](https://front-end.social/@hdv/112134676105271265):

Note when the post says ‘browsers’, not all guardrails are currently implemented in [@webkit](https://front-end.social/@webkit), I hope that this may still happen in a future update (cc [@jensimmons](https://front-end.social/@jensimmons) [@annevk](https://hachyderm.io/@annevk))

[**Hidde**](https://front-end.social/@hdv) wrote on [21 March 2024](https://front-end.social/@hdv/112134809022633209):

[@scottohara](https://a11y.info/@scottohara) TLDR: browsers sometimes set\`aria-expanded\` state and/or the \`aria-details\` relationship on the invoker, sometimes add a \`group\` role to the popover, and add some keyboard behaviours.

You'll still need to take care of all other accessibility considerations for components you build with popover (eg literally anything but these specific things).

[**katherine**](https://sunny.garden/@kayserifserif) wrote on [21 March 2024](https://sunny.garden/@kayserifserif/112134944921983493):

[@hdv](https://front-end.social/@hdv) [@scottohara](https://a11y.info/@scottohara) thanks for these details! side note: the design of your blog makes it always such a nice experience for reading :)

[**Hidde**](https://front-end.social/@hdv) wrote on [21 March 2024](https://front-end.social/@hdv/112135371943533690):

[@baldur](https://toot.cafe/@baldur) thanks Baldur!

[**Curtis Wilcox**](https://c.im/@cwilcox808) wrote on [21 March 2024](https://c.im/@cwilcox808/112135458862158506):

[@hdv](https://front-end.social/@hdv) [@scottohara](https://a11y.info/@scottohara)  
\> Desktop browsers also do something else: they add the popover content into the tab order just after the invoking button.

I didn't know about this and wonder why only desktop browsers, mobile ones can have keyboards too (I confirmed it doesn't happen with mobile Safari and a Bluetooth keyboard).

[**Eyal Eshet**](https://a11y.info/@eyalito) wrote on [22 March 2024](https://a11y.info/@eyalito/112138209745911410):

[@hdv](https://front-end.social/@hdv) [@scottohara](https://a11y.info/@scottohara) much thanks!

So for example for a menu button, is the popover attribute preferred over the ARIA APG pattern? Especially given its "built in accessibility".

[**Hidde**](https://front-end.social/@hdv) wrote on [22 March 2024](https://front-end.social/@hdv/112138429443185897):

[@eyalito](https://a11y.info/@eyalito) [@scottohara](https://a11y.info/@scottohara) if you'd like the menu to be definitely above other elements (by bringing it to the top layer) and/or want it to light dismiss, popover is the way to do it! (see [https://hidde.blog/dialog-modal-popover-differences/](https://hidde.blog/dialog-modal-popover-differences/) for intro)

you can use the attribute in addition to what you're already doing

[Dialogs and popovers seem similar. How are they different?](https://hidde.blog/dialog-modal-popover-differences/)

[**Hidde**](https://front-end.social/@hdv) wrote on [22 March 2024](https://front-end.social/@hdv/112138434150777784):

If you're not sure what popover is for, I've written this post about how popover is different [https://hidde.blog/dialog-modal-popover-differences/](https://hidde.blog/dialog-modal-popover-differences/)

[Dialogs and popovers seem similar. How are they different?](https://hidde.blog/dialog-modal-popover-differences/)

[**admin**](https://technodrivenfuture.com/author/admin/) wrote on [31 March 2024](https://technodrivenfuture.com/web-application-development/net-weekly-126-stefan-judis-net-growth/):

  

## Guten Tag! Guten Tag! ????

When will `align-content` work in divs? Does the brand new `popover` attribute enhance accessibility? And why does `margin: auto` work on completely positioned components?

Activate the Net Weekly tune and discover all of the solutions beneath. Get pleasure from!

However earlier than, **the Net Weekly music queue is nearly empty. When you take pleasure in discovering and sharing new music, [send me your favorite tracks to keep the Web Weekly jukebox playing](https://www.stefanjudis.com/blog/web-weekly-126/mailto:stefan@webweekly.email).**

Ellen listens to “[Slut — If I had a heart](https://www.youtube.com/watch?v=4LoT8Pllg10)” and says:

> “If I Had a Coronary heart” creates an aura stuffed with melancholy and a novel environment, as if the music itself was my heartbeat. Wouldn’t it sing or cry?

What number of Git instructions do you utilize commonly? I am the `add -p`, `commit`, `push`‘n’`pull` kinda man. I’d even be capable to carry out a flowery rebase every now and then. However do I do know what I am doing? Not likely.

How will you stage up your Git abilities?

The next speak collection is a trick rapid-fire. The movies have bounce marks so you may decide your matters. Extremely advisable.

Moreover, [Julia Evans started digging into Git](https://jvns.ca/categories/git/). As at all times, her articles are approachable but tremendous informative.

What are your favourite Git assets?

## One thing that made me smile this week

How good are your eyes (or monitor) when differentiating colours? Discover out with `colormatch`.

[Match colors](https://colormatch.pages.dev/)

## Two methods to compose elements

How do you lengthen your Frontend elements and make them configurable? Straightforward — slap an `is-active` or `h-full` class onto it and name it a day, proper?

However the extra class modifiers you add to your elements, the trickier it will get. It is one in all these issues that turns into more durable with each change. Element and design system design is hard.

Kyle Shevlin’s put up on part compositions triggered some ideas, and I believe I modified my strategy to part creation now.

[Think about composition](https://kyleshevlin.com/two-types-of-composition/)

## TIL — auto-margin works on `absolute` positioned components

It will possibly’t simply be me who hasn’t utilized `margin: auto` to absolute positioned components earlier than, can it? I discovered this week that you may middle components (X and Y axis) with a wise mixture of `inset`, `width` and `margin`.

[Center like a pro](https://www.stefanjudis.com/today-i-learned/auto-margin-works-with-absolute-positioned-elements/)

## `disabled` vs `aria-disabled`

Quick’n’candy: Kitty Giraudel printed a simple advice on when to make use of `readonly`, `disabled` and `aria-disabeld`.

[Use the best attribute](https://kittygiraudel.com/2024/03/29/on-disabled-and-aria-disabled-attributes/)

You are midway by way of!

Wowza! Would you take pleasure in getting [Web Weekly](https://www.webweekly.email/) straight to your inbox?

## The fantastic bizarre net – `grumpy.web site`

The Grumpy web site complains about what’s fallacious with the net as we speak. We’re speaking bizarre dialogs, cluttered UIs, unlogical consumer flows, unreachable footers, \[PLACE YOUR WEB ANNOYANCE HERE\]…

Let’s get up and yell “YES! This annoys me, too!” collectively!

[Be grumpy](https://grumpy.website/)

What are your favourite web corners? [Send them my way](https://www.stefanjudis.com/blog/web-weekly-126/mailto:stefanjudis@gmail.com), and I am going to embody them in Net Weekly!

## What is the fuzz about this new React compiler?

Whereas it will not be launched anytime quickly, React will finally rework right into a compiled Framework. When you suppose this feels like a drastic change, it’s. Nadia Makarevich does a terrific job summarizing what’s on the horizon.

[What could change with the React compiler?](https://www.developerway.com/posts/react-compiler-soon)

## Issues to count on when advocating for net accessibility

Heather Buchel displays and shares classes discovered when advocating for an accessible net. It is a incredible learn!

[Understand why it’s tough to advocate for accessibility](https://heather-buchel.com/blog/2024/03/letters-to-an-accessibility-advocate/)

## Grid, subgrid and breaking consumer agent types

What occurs in case your HTML content material contains an ordered checklist with over a thousand entries? Right! The use agent types begin to break, and the checklist markers will overflow.

It is wild how rigid the default types are on this space, however Noah Liebman shared the way to resolve this challenge with a flowery subgrid!

[Avoid list overflow](https://noahliebman.net/2024/03/making-room-for-long-list-markers-with-subgrid/)

## The totally different font dimension downside

Have you ever ever found how troublesome mixing and matching totally different fonts in a paragraph is? It is shocking how difficult it’s to align totally different fonts and make them equal in dimension.

Theoretically, `font-size-adjust` solves this downside, however [browser support is still lacking](https://caniuse.com/?search=font-size-adjust). _Com’on Chromium!_

Rasmus Fløe shared how one can nonetheless align all these totally different fonts with some font evaluation.

[Align fonts](https://phloe.co/dev/font-size)

_Somebody ought to construct a fast device to align fonts robotically. [If that’s you, let me know](https://www.stefanjudis.com/blog/web-weekly-126/stefan@webweekly.email)!_

On the brilliant facet, popover cross-browser help is simply across the nook. Chromium has shipped the brand new attributes since 114, Safari has supported them since 17, and Firefox contains the brand new UI options within the nightly channel.

However what do the `popover` and `popovertarget` attributes imply for accessibility? Hidde de Vries and Scott O’Hara went deep into this matter.

tl;dr

-   `aria-expanded` state is dealt with robotically.
-   `aria-details` is _typically_ utilized.
-   `function="group"` is _typically_ utilized.
-   focus dealing with is built-in.

[Learn about popover internals](https://hidde.blog/popover-accessibility/)

From the limitless MDN data archive…

Have you ever used the `dfn` HTML component? Perhaps it’s best to give it a strive.

[Define terms](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/dfn)

## TIL recap – `Intl.Segmenter`

`Intl.Segmenter` reaches cross-browser help with Firefox 125 (transport on April 16). Then, we’ll have a local technique to cut up strings into phrases, sentences, and even graphemes.

[Split the strings](https://www.stefanjudis.com/today-i-learned/how-to-split-javascript-strings-with-intl-segmenter/)

[With Safari 17.4, **vertical form controls** are available on the web](https://webkit.org/blog/15190/implementing-vertical-form-controls/). How will you flip the controls? A `writing-mode: vertical-rl;` does the trick! Neat.

Sadly, I can not learn a top-to-bottom language, so I do not see myself utilizing vertical textareas, inputs or selects quickly. However a vertical vary slider or progress indicator — I am sport!

The help data for vertical kind components is not prepared on MDN, however I checked `<enter sort=vary>` and `<progress>` within the present Chrome, Firefox and Safari Tech Preview. The 2 labored effective.

However in different information, in the case of **centering components in block layouts** by way of `align-content`, [MDN compat has all the data](https://github.com/mdn/browser-compat-data/pull/22702/files).????

And as you see above, we’re nearly there. Centering components in a div turns into a flowery CSS one-liner quickly!

## Three invaluable initiatives to take a look at

For the TS nerds: the TS AST viewer helps you perceive how the TypeScript compiler parses your stunning code.

[Understand TS a bit better](https://ts-ast-viewer.com/)

Reminder: do not use underlines when designing paperwork, websites, slides, or something that may be consumed with a digital gadget. ????

> Underlining mainly solely exists now to confuse folks into considering one thing is a hyperlink that they will click on on.

Anil Sprint has some extra strong recommendation in [“Make better documents”](https://www.anildash.com/2024/03/10/make-better-documents/).

If you wish to help this text, advocate it to your pals, [book a sponsorship package](https://webweekly.email/sponsor) or [ensure that I’m not running low on coffee with a small donation](https://www.patreon.com/stefanjudis).

Thanks! ????

And with that, handle your self – mentally, bodily, and emotionally.

I am going to see you subsequent week! ????

[**Melanie**](https://front-end.social/@a11yMel) wrote on [25 April 2024](https://front-end.social/@a11yMel/112333639346137604):

[@hdv](https://front-end.social/@hdv) thank you for the feedback! I will add the aria-details information, I think that is useful.

[**Hidde**](https://front-end.social/@hdv) wrote on [4 May 2024](https://front-end.social/@hdv/112384575329603966):

(and just updated the positioning post with the info that for the recent major changes to anchor positioning, Chromium issued an intent to ship, TAG review and Gecko, Webkit positions still pending).

[**Luke**](https://toot.wales/@Lukew) wrote on [9 June 2024](https://toot.wales/@Lukew/112588017107372945):

[@hdv](https://front-end.social/@hdv) [@jensimmons](https://front-end.social/@jensimmons) What is WebKit missing in this case? Off the top of my head aria-details isn't done but iirc the aam says not to do anything with it for AX API?

It would be nice to get the light dismiss bug on iOS fixed though!

[**Hidde**](https://front-end.social/@hdv) wrote on [9 June 2024](https://front-end.social/@hdv/112588045524663345):

[@Lukew](https://toot.wales/@Lukew) [@jensimmons](https://front-end.social/@jensimmons) last time I checked it doesn't set aria-details (under specific conditions) and doesn't set the group role as a fallback.

the HTML AAM PR is still open ([https://github.com/w3c/html-aam/pull/481](https://github.com/w3c/html-aam/pull/481)) and no WPT exist for it yet, but Chromium and Firefox already have this behaviour

[add/revise popover related attribute mappings by scottaohara · Pull Request #481 · w3c/html-aam](https://github.com/w3c/html-aam/pull/481)

[**Luke**](https://toot.wales/@Lukew) wrote on [9 June 2024](https://toot.wales/@Lukew/112588081616291959):

[@hdv](https://front-end.social/@hdv) [@jensimmons](https://front-end.social/@jensimmons) group fallback role is possibly an issue, the aria-details is per spec.

[**Luke**](https://toot.wales/@Lukew) wrote on [9 June 2024](https://toot.wales/@Lukew/112588102226728977):

[@hdv](https://front-end.social/@hdv) [@jensimmons](https://front-end.social/@jensimmons) Fwiw I don't think WPT can even test this stuff, except the role, (yet\*). Even the latest additions only cover role and label, which is a tiny subset of the accesibility API surface area. Not to say they're not a big win but we need more. One of my colleagues presented on work they've been doing to try and get testing of the actual accesibility APIs into WPT. That way we're not reliant on the browser to tell us the truth, and we can cover all the specifics of each API mapping.

[**Hidde**](https://front-end.social/@hdv) wrote on [9 June 2024](https://front-end.social/@hdv/112588188451764779):

[@Lukew](https://toot.wales/@Lukew) [@jensimmons](https://front-end.social/@jensimmons) yep that's my understanding too, just roles at the moment! didn't know about labels (names?) that's nice

**Hidde de Vries (@hdv@front-end.social) is a web enthusiast and accessibility specialist from Rotterdam (The Netherlands). He currently works on web standards for the Dutch government and is a participant in the Open UI Community Group. Previously, he worked for W3C (WAI), Mozilla, the Dutch government and others as a freelancer. Hidde is also a public speaker, he has given 73 talks, most recently in Virtual. In his free time, he works on a coffee table book covering the video conferencing apps of our decade. Buy me a coffee Follow on Mastodon Follow on LinkedIn** wrote on [29 December 2024](https://hidde.blog/2024-review/What%20I%20got%20up%20to%20in%202024):

It's only a few days until 2025. That means one thing: it is time for my yearly tradition of reviewing… _some of my year_. I'll cover work, conferences, reading, writing and music.

This will inevitably sound cheesy, but I am once again genuinely grateful for the opportunities I got… there were fun projects at work, I got to see some of my dearest artists live and I got to share knowledge and opinions at events among some of my favourite peers. At the same time, the last few months have, honestly, been intense, and I am looking forward to take a few breaks in January.

I also can't not mention politics. I saw a number of sad elections results. I saw people chose to vote, basically, against other people. It was heartbreaking to see people vote against women, against trans people, against people who crossed borders, and also against the odds for humans to inhabit this planet… and some major tech leaders chose to embrace, encourage or cheerlead _that_. Booh.

Some say one should focus on things one can impact. I'm not always good at that, but I'll do it now, by sharing a bit more about my year in terms of projects, conferences, reading and listening.

## Projects

I spent most of my time on two projects for the Dutch government: NL Design System and the digital accessibility (standards) team at Logius.

At NL Design System, I got to organise another [Design Systems Week](https://nldesignsystem.nl/events/design-systems-week-2024), and worked on accessibility testing, guidance for [forms](https://nldesignsystem.nl/richtlijnen/formulieren) and [WCAG](https://nldesignsystem.nl/wcag/) (both in Dutch), communication strategy, events and our website. At Logius, I worked on growing our participation in international standards discussions, specifically accessibility standards like WCAG and EN 301 539, at W3C and ETSI. It's been really cool to get back into familiar groups and join new ones (like the TC and JTB; yes I learned new abbreviations why).

Next year I'm increasing my time for standards at Logius, which, sadly, also means I'm leaving the NL Design System team.

From February, I'll have some availability for new projects, too: ~2 days/week to work on accessibility, frontend and/or design systems, do get in touch if you can use help.

## Conferences

It's been a very busy and very fun year in conferences (I recommend going to conferences, for all reasons Sophie outlines in her post [You should go to conferences](https://localghost.dev/blog/you-should-go-to-conferences/)).

Some talks I liked:

-   [_The art of reflection_](https://www.youtube.com/watch?v=Lmq1MSCSA88) by Imran Afzal at All Day Hey
-   [_Feminism in programming language design_](https://youtu.be/TFw3zPqlQjA?si=KxjZeebZ7f-bCFU9&t=1250) (start at 20:50) by Felienne Hermans at Joy of Coding
-   _The many lives of a notification_ by Sarah Highley at Accessibility Toronto

I loved speaking at a number of them, too. I got to meet new people in the industry and hang out with friends. Even if it is nerve wracking at times, it gives me a lot of energy.

### Creativity, art and AI

In October, I presented a new talk called _Creativity cannot be computed_ at Beyond Tellerrand in Berlin. I talked about what's great about arts and creativity, in the context of our industry's tendency to leave stuff to computers. I love computers and art both, but we've got to prioritise. Some of this has been in my head for the last decade, and I loved to hear how it resonated with people in conversations after (maybe partially because I can't seem to shut up about it, sorry to all affected). I plan to write more about art and AI on my blog, but you can already [read along with the slides](https://talks.hiddedevries.nl/dFZf3b/slides) or [watch the video](https://www.youtube.com/watch?v=WqNgGmmwj7U).

### Acccessibility

Another new talk was _Built-in accessibility: blessing or curse_, which combined some of my earlier talks on [tooling](https://talks.hiddedevries.nl/Voo22H/will-tools-save-us), [browsers](https://talks.hiddedevries.nl/IEwNvG/could-browsers-fix-more-accessibility-problems-automatically) and [CMSes](https://talks.hiddedevries.nl/WOsDsG/your-cms-is-an-accessibility-assistant) with what I learned about design systems at NL Design System, all to uncover a general theme: that building in accessibility is not a one size fits all solution, but when done right, can be a sound part of your accessibility strategy. I gave this talk at A11y Club Amsterdam and at Accessibility Toronto.

### Popovers

Earlier in the year, I did the most northern iteration of [my popover talk (video)](https://youtu.be/uZRp7yY8SS0?si=SJpNzbYUIEwnuUZZ) at All Day Hey in Leeds. I was very happy how it turned out and it was great to visit this city and this event that I had heard so many good things about.

My shortest talks were at Joy of Coding in my home town of Rotterdam, where I spent [5 minutes rambling about software and accessibility](https://talks.hiddedevries.nl/deWifQ/more-software-should-have-accessibility-built-in), and Mozilla's performance.sync() meetup in Amsterdam, where I talked about [Open UI and reducing bundle size](https://talks.hiddedevries.nl/lRQg2b/new-web-platform-features-that-help-you-save).

In the next year, I'd like to talk about web sustainability more, and continue to cover accessibility, design systems and AI/art.

## Reading

I read [some books this year](https://log.hidde.blog/books/), two of my favourites were:

-   [Character limit: how Elon Musk destroyed Twitter](https://www.penguin.co.uk/books/457928/character-limit-by-mac-kate-conger-and-ryan/9781529914696); a lot of the shocking facts in this book were public knowledge already, but Ryan Mac and Kate Conger did a wonderful job telling how the events unfolded, the details make one fear a world in which Elon Musk has any influence.
-   [Against technoableism:](https://wwnorton.com/books/9781324036661) : seeing people with disabilities as an “inspiration” or needy of technological “fixes” is problematic, this book explains why.

These blog posts from others are among favourites this year:

-   [Coming Home](https://aworkinglibrary.com/writing/coming-home) by Mandy Brown
-   [Generative AI is for the idea guys](https://rachsmith.com/ai-is-for-the-idea-guys/) by Rach Smith
-   [The Dilemmas You'll Face When Creating a Component Library](https://github.com/andrico1234/the-dilemmas-youll-face) by Andrico Karoulla
-   [We have a content quality problem, not a content quantity problem](https://coryd.dev/posts/2024/we-have-a-content-quality-problem-not-a-content-quantity-problem.html) by Cory Dransfeldt

## Music

Three albums that came out in 2024 that I liked:

-   Odyssey by Nubya Garcia (jazz saxophone with orchestral arrangements, vocals and more).
-   Lives Outgrown by Beth Gibbons (of Portishead fame, it grew on me).
-   Drop 7 by Little Simz (hip hop, it feels more free and experimental than her previous work).
-   IJsland by Abel & Sef (Dutch punk hip hop that I loved almost instantly).

In live music, it was a [good year](https://log.hidde.blog/live-music)… I stayed on top of who's touring and ticket acquisition, and managed to see many faves. Most liked: IJSLAND, Massive Attack and Robert Glasper. I also made a point of going to see stuff when traveling, a tradition I hope to keep, though it gets expensive when traveling outside of Europe and its subsidised cultural venues.

In music making: I am picking up playing piano again and have joined a choir, which has been on of my best decisions, it is so much fun. As usual, I should have listened to a friend's advice earlier.

## Writing

With 10 posts in total, I didn't write as much on this blog in 2024. I don't know which were most read, but these got some good feedback:

-   [On popover accessibility: what the browser does and doesn't do](https://hidde.blog/popover-accessibility/) (co-written with Scott O'Hara)
-   [“AI” and accessible front-end components: is the nuance generatable?](https://hidde.blog/ai-for-accessible-components/)

## Cities

Outside The Netherlands, I spent time in Duisburg, Berlin, Taipei, Tainan, Kaohsiung, Brighton, Antwerp, Paris, Leeds, London, Bad Schandau, Brussels, Los Angeles, Toronto, Liverpool, Vienna.

## Self study

I did a bunch of self-study:

-   Josh Comeau's [The Joy of React](https://www.joyofreact.com/). It was indeed joyful, and the most down to earth overview of React I've seen so far.
-   the [IAAP certification](https://www.accessibilityassociation.org/s/certification) exams. I'm now a [CPWA](https://www.accessibilityassociation.org/s/certified-professional-web-accessibility), which is both WAS and CPACC. I have more to say about this, maybe some other time or 1:1.
-   I worked with [Melinda](https://www.seckington.com/) on specific parts of my public speaking, I would absolutely recommend her to anyone looking to learn.

## Wrapping up

I wanted to write up some resolutions for the next year, but I ran out of time. I guess I'll leave it, as a resolution itself, for the next year. If you're reading this, I wish you all the best for the new year!

[**Thomas Michael Semmler**](https://indieweb.social/@nachtfunke) wrote on [21 March 2025](https://indieweb.social/@nachtfunke/114201296913821373):

[@hdv](https://front-end.social/@hdv) yes! 1000%!

[**Johannes Odland**](https://front-end.social/@johannes) wrote on [21 March 2025](https://front-end.social/@johannes/114201339517606587):

[@hdv](https://front-end.social/@hdv) ????

[**Ana Rodrigues**](https://front-end.social/@anarodrigues) wrote on [21 March 2025](https://front-end.social/@anarodrigues/114201429849703162):

[@hdv](https://front-end.social/@hdv) yes!

[**Elly Loel**](https://front-end.social/@elly) wrote on [21 March 2025](https://front-end.social/@elly/114202562814422714):

[@hdv](https://front-end.social/@hdv) yes pleaseee ????

[**lbineau**](https://mastodon.social/@lbineau) wrote on [21 March 2025](https://mastodon.social/@lbineau/114202653741488321):

[@hdv](https://front-end.social/@hdv) yeeeees !

[**Thomas Günther**](https://mastodon.social/@medienbaecker) wrote on [22 March 2025](https://mastodon.social/@medienbaecker/114203628126599931):

[@hdv](https://front-end.social/@hdv) interest ????????‍♂️

[**Manuel Matuzović**](https://front-end.social/@matuzo) wrote on [13 May 2025](https://front-end.social/@matuzo/114498868284916167):

“On popover accessibility: what the browser does and doesn’t do” by [@hdv](https://front-end.social/@hdv) and [@scottohara](https://mastodon.social/@scottohara)

[https://hidde.blog/popover-accessibility/](https://hidde.blog/popover-accessibility/)

[On popover accessibility: what the browser does and doesn’t do](https://hidde.blog/popover-accessibility/)

[**David Roessli**](https://davidroessli.com/about/) wrote on [13 March 2026](https://davidroessli.com/logs/a-web-day-out-in-brighton/):

I'm in Brighton, and it's blowing a gale outside. The air is fresh and salty and I'm gliding back to my hotel room 50cm above ground, my mind still high on the day's vibes.

I've just left Mrs Fitzherbert's pub after a fantastic day at [Web Day Out](https://webdayout.com/ "#Web Day Out"), _”a one-day event all about what you can do in web browsers today!”_ organised by [Clearleft](https://clearleft.com/) and MC'd by [Jeremy Keith](https://adactio.com/). Just up my street.

[I love](https://davidroessli.com/lanyards/) these kind of small, one day, focus driven conferences.

Eight talks around topics around what can be done in modern browsers, from CSS to the W3C working groups, via what is the browser baseline, battle tested progressive web apps, accessibility concerns and progressive enhancement. No JavaScript (frameworks) required, just love and care for CSS and HTML.

Brighton is the perfect place to host event like this. Its vibe and size are human, rich with creativity and imagination. Open minded.

## Jemima Abu

### I can’t believe it’s not JavaScript

The day kick off in style and energy with a talk by Jemima Abu who covered some of the latest native HTML elements or CSS properties available in baseline. It was talk full of sparkles and passion. I connected immediately. It was my first opportunity to listen to Jemima present in person, and boy was I impressed.

> We have a lot of shit in our packages

I'm probably going to repeat myself in this post, but the care and passion (and love) for native HTML and CSS was palpable. Both on stage and in the audience. I use a bunch of the elements that were presented, but the [popover API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API "#Popover API") stood out. It came up in a number of talks that followed. Tooltips, modals, or styling the `select` element, the popover api is at the rescue.

## Rachel Andrew

### A pragmatic guide to browser support

Rachel Andrew (the grid lady, by her own admission) talked about [Web Platform Baseline](https://web.dev/baseline "#Web Platform Baseline"), how it worked and how to use it, relying on common sense and giving many useful tips on how to suggest new features, and how to decide to use one feature (or not) and when.

> Think about your audience  
> Think about your team  
> Understand path to baseline.

Rachel's presentations are so well structured and illustrated, it's each time a renewed pleasure to listen to her.

Rachel announced that [Subgrid](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Grid_layout/Subgrid "#Subgrid") becomes [widely available](https://web.dev/baseline#:~:text=Widely%20available:%2030%20months%20have%20passed%20since%20the%20newly%20interoperable%20date.%20The%20feature%20can%20be%20used%20by%20most%20sites%20without%20worrying%20about%20support.) next week!

Widely available: 30 months have passed since the newly interoperable date. The feature can be used by most sites without worrying about support.

## Aleth Gueguen

### Progressive web apps from the trenches

Aleth Gueguen presented real world use and tests of PWAs with loads of tips, especially for iOS - surprise surprise - that are golden for people developing real world solutions that must run in real world conditions. Precious.

> Let the user know the state of their data  
> Make it seamful  
> Provide a button to trigger a sync.

## Harry Roberts

### Build for the web, build on the web, build with the web

Harry Roberts stormed the event with a punchy presentation that resonated close to my heart, and not only because he was kind enough to [call me out](https://davidroessli.com/perch/resources/blog/harry-roberts-webdayout-callout.webp), but because of what he echoed what I'm trying to express in a professional capacity for a while now. I was fortunate to work with Harry last year for a client, and he is an amazing person, generous, committed and so talented. I always learn so much when he's around.

> The web is versionless, and versionless is a virtue  
> Stick with the web.

A opiniated talk on his love from the web. [Check-out his post](https://csswizardry.com/2025/01/build-for-the-web-build-on-the-web-build-with-the-web/ "#Build for the web, build with the web, build with the web") for a deep dive. His stories about SPA, made me laugh… (if you can name 5 pages of your website, it's not an SPA). Harry elegantly framed out loud what I've been struggling to verbalise these last years.

Harry posted his [slidedeck](https://speakerdeck.com/csswizardry/build-for-the-web-build-on-the-web-build-with-the-web) to SpeakerDeck.

## Manuel Matuzovič

### Breaking with habits

Manuel is my latest favourite speaker and person. I had the pleasure of discovering him at Smashing Conf in Freiburg and later at beyond tellerrand (or the other way around) and I finally got to meet him in person at Web Day Out (it was his birthday!) He's passionate (nerdy) and loves sharing his experience and knowledge, and is really a truly nice person.

I love the way he dives deep into a subject to explore and understand all the nook and cranies (checkout his talks on colour, or his type scale - brilliant!). I always learn so much each time our paths cross. Check out [his blog](https://matuzo.at/) and his [no-class CSS framework Oli](https://olicss.com/ "#Oli.css").

## Richard Rutter

### What’s new in web typography?

Richard made me love typography, and I try to jump on every opportunity to read or listen to him. He dived into nerdy typographic details like `font-size-adjust` (0.417!), variable font properties or fluid typography. Check out his [aspect value calculator](https://wbtyp.net/58).

His segment on lists (don't miss his [article on Piccalil.li](https://piccalil.li/blog/an-in-depth-guide-to-customising-lists-with-css/ "#An in-depth guide to customising lists with CSS")) and headings positioning and aligment (`text-box`) were stunning. So many details… I was reminded to use OpenType properties more often (eg. `font-variant-position`). Super subtle.

## Jake Archibald

### Customisable \`select\` and the friends we made along the way

A fascinating time travel in the history of the `select` element. It turns out `select` is the element the most re-created by developers, and the one that gives the most frustration (by far) - no surprise.

[OpenUI](https://open-ui.org/) W3C community group worked hard on the process that led to the popover API mentioned earlier by Jemima. Read more about the [popover accessibility](https://hidde.blog/popover-accessibility/).

> The stylable `select` has finally landed in browsers - 33 years after its initial proposal.

Many more stories about the top layer in which popover renders and how to position it (`position-area`) or style the picker (`appearance`) with any CSS properties and pseudo-selectors (`::picker-icon`). The `select` element allows any HTML element now, like `div` or `img` (or `button`!). Ever heard of [`selectedcontent`](https://davidroessli.com/perch/resources/blog/jake-archibald-select-styling-webdayout.webp)? Powerful.

## Lola Odelola

### The browser is the playground

Lola started with a project she led last year “alt-text as an Artistic Practice”. How would you describe an abstract image? Consider alt-text as the primary way to experience an image (`prefer-alt-text` - turns out, it's a bad idea).

> Robb sits in a room painted in shades of disrupted sleep and red velvet. He is amongst friends, drifting between the embers of his second coffee and the spark of a third.  
> \-- Robb

or

> Three aging emos post gradiose yet humbly against the urban backdrop of Leeds, looking either wistfully off into the distance or straight into the camera, they embody everything that can be right with the world. Hope, confidence, quietness, serenity, camaraderie. The day was good, and so are these people.  
> \-- Salma

Lola dove deep into into W3C processes (she is the co-chair of W3C Technical Architecture Group) and described and explained many things I wasn't aware of (eg. the [priority of constituencies](https://davidroessli.com/perch/resources/blog/lola-odelola-w3c-priorities-webdayout.webp) or reducing user fingerprinting). Throught her talk, she elegantly demonstrated why a 'dream feature' (like `prefer-alt-text`) can be a bad idea, and all that from the point of view of a browser engineer.

## Amazed, and proud

I'm truly amazed by the rate at which new features, elements and properties are appearing, and proud to be part of this community, that strives to to design and build on the web, for the web, with native web elements.

More links:

-   [Mastodon toots](https://mastodon.social/tags/WebDayOut)
-   [Marc Thiele's photos](https://marcthiele.com/photos/web-day-out-2026)
-   [My Flickr album](https://www.flickr.com/photos/davo39/albums/72177720332538923/)
-   [“That was Web Day Out”](https://adactio.com/journal/22465) by Jeremy
-   [“Look into the future of the web platform”](https://rachelandrew.co.uk/archives/2026/03/20/look-into-the-future-of-the-web-platform/) by Rachel

## Make friends, not followers

Michael Flarup wrote about the comeback of small conferences in his [latest newsletter](https://www.flarup.email/p/the-comeback-of-small-conferences) that echoes another reason why I like attending these kind of events so much:

> A conference is one of the few places where a scattered online community briefly becomes real.
> 
> There’s a realness that comes from meeting your peers face to face. All of the fluff that so often surrounds online discourse falls away. There is no hype, just passion. No engagement hook, just curiosity.
> 
> Instead of making followers, you make friends.

Thank you [Jeremy](https://adactio.com/) and [Clearleft](https://clearleft.com/) for hosting such events ????

[**David Roessli**](https://davidroessli.com/about/) wrote on [13 March 2026](https://davidroessli.com/logs/2026/03/a-web-day-out-in-brighton/):

I’m in Brighton, and it’s blowing a gale outside. The air is fresh and salty and I’m gliding back to my hotel room 50cm above ground, my mind still high on the day’s vibes.

I’ve just left Mrs Fitzherbert’s pub after a fantastic day at [Web Day Out](https://webdayout.com/ "#Web Day Out"), _”a one-day event all about what you can do in web browsers today!”_ organised by [Clearleft](https://clearleft.com/) and MC’d by [Jeremy Keith](https://adactio.com/). Just up my street.

[I love](https://davidroessli.com/lanyards/) these kind of small, one day, focus driven conferences.

Eight talks around topics around what can be done in modern browsers, from CSS to the W3C working groups, via what is the browser baseline, battle tested progressive web apps, accessibility concerns and progressive enhancement. No JavaScript (frameworks) required, just love and care for CSS and HTML.

Brighton is the perfect place to host event like this. Its vibe and size are human, rich with creativity and imagination. Open minded.

## Jemima Abu

### I can’t believe it’s not JavaScript

The day kick off in style and energy with a talk by Jemima Abu who covered some of the latest native HTML elements or CSS properties available in baseline. It was talk full of sparkles and passion. I connected immediately. It was my first opportunity to listen to Jemima present in person, and boy was I impressed.

> We have a lot of shit in our packages

I’m probably going to repeat myself in this post, but the care and passion (and love) for native HTML and CSS was palpable. Both on stage and in the audience. I use a bunch of the elements that were presented, but the [popover API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API "#Popover API") stood out. It came up in a number of talks that followed. Tooltips, modals, or styling the `select` element, the popover api is at the rescue.

## Rachel Andrew

### A pragmatic guide to browser support

Rachel Andrew (the grid lady, by her own admission) talked about [Web Platform Baseline](https://web.dev/baseline "#Web Platform Baseline"), how it worked and how to use it, relying on common sense and giving many useful tips on how to suggest new features, and how to decide to use one feature (or not) and when.

> Think about your audience  
> Think about your team  
> Understand path to baseline.

Rachel’s presentations are so well structured and illustrated, it’s each time a renewed pleasure to listen to her.

Rachel announced that [Subgrid](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Grid_layout/Subgrid "#Subgrid") becomes [widely available](https://web.dev/baseline#:~:text=Widely%20available:%2030%20months%20have%20passed%20since%20the%20newly%20interoperable%20date.%20The%20feature%20can%20be%20used%20by%20most%20sites%20without%20worrying%20about%20support.) next week!

Widely available: 30 months have passed since the newly interoperable date. The feature can be used by most sites without worrying about support.

## Aleth Gueguen

### Progressive web apps from the trenches

Aleth Gueguen presented real world use and tests of PWAs with loads of tips, especially for iOS - surprise surprise - that are golden for people developing real world solutions that must run in real world conditions. Precious.

> Let the user know the state of their data  
> Make it seamful  
> Provide a button to trigger a sync.

## Harry Roberts

### Build for the web, build on the web, build with the web

Harry Roberts stormed the event with a punchy presentation that resonated close to my heart, and not only because he was kind enough to [call me out](https://davidroessli.com/perch/resources/blog/harry-roberts-webdayout-callout.webp), but because of what he echoed what I’m trying to express in a professional capacity for a while now. I was fortunate to work with Harry last year for a client, and he is an amazing person, generous, committed and so talented. I always learn so much when he’s around.

> The web is versionless, and versionless is a virtue  
> Stick with the web.

A opiniated talk on his love from the web. [Check-out his post](https://csswizardry.com/2025/01/build-for-the-web-build-on-the-web-build-with-the-web/ "#Build for the web, build with the web, build with the web") for a deep dive. His stories about SPA, made me laugh… (if you can name 5 pages of your website, it’s not an SPA). Harry elegantly framed out loud what I’ve been struggling to verbalise these last years.

Harry posted his [slidedeck](https://speakerdeck.com/csswizardry/build-for-the-web-build-on-the-web-build-with-the-web) to SpeakerDeck.

## Manuel Matuzovič

### Breaking with habits

Manuel is my latest favourite speaker and person. I had the pleasure of discovering him at Smashing Conf in Freiburg and later at beyond tellerrand (or the other way around) and I finally got to meet him in person at Web Day Out (it was his birthday!) He’s passionate (nerdy) and loves sharing his experience and knowledge, and is really a truly nice person.

I love the way he dives deep into a subject to explore and understand all the nook and cranies (checkout his talks on colour, or his type scale - brilliant!). I always learn so much each time our paths cross. Check out [his blog](https://matuzo.at/) and his [no-class CSS framework Oli](https://olicss.com/ "#Oli.css").

## Richard Rutter

### What’s new in web typography?

Richard made me love typography, and I try to jump on every opportunity to read or listen to him. He dived into nerdy typographic details like `font-size-adjust` (0.417!), variable font properties or fluid typography. Check out his [aspect value calculator](https://wbtyp.net/58).

His segment on lists (don’t miss his [article on Piccalil.li](https://piccalil.li/blog/an-in-depth-guide-to-customising-lists-with-css/ "#An in-depth guide to customising lists with CSS")) and headings positioning and aligment (`text-box`) were stunning. So many details… I was reminded to use OpenType properties more often (eg. `font-variant-position`). Super subtle.

## Jake Archibald

### Customisable \`select\` and the friends we made along the way

A fascinating time travel in the history of the `select` element. It turns out `select` is the element the most re-created by developers, and the one that gives the most frustration (by far) - no surprise.

[OpenUI](https://open-ui.org/) W3C community group worked hard on the process that led to the popover API mentioned earlier by Jemima. Read more about the [popover accessibility](https://hidde.blog/popover-accessibility/).

> The stylable `select` has finally landed in browsers - 33 years after its initial proposal.

Many more stories about the top layer in which popover renders and how to position it (`position-area`) or style the picker (`appearance`) with any CSS properties and pseudo-selectors (`::picker-icon`). The `select` element allows any HTML element now, like `div` or `img` (or `button`!). Ever heard of [`selectedcontent`](https://davidroessli.com/perch/resources/blog/jake-archibald-select-styling-webdayout.webp)? Powerful.

## Lola Odelola

### The browser is the playground

Lola started with a project she led last year “alt-text as an Artistic Practice”. How would you describe an abstract image? Consider alt-text as the primary way to experience an image (`prefer-alt-text` - turns out, it’s a bad idea).

> Robb sits in a room painted in shades of disrupted sleep and red velvet. He is amongst friends, drifting between the embers of his second coffee and the spark of a third.  
> – Robb

or

> Three aging emos post gradiose yet humbly against the urban backdrop of Leeds, looking either wistfully off into the distance or straight into the camera, they embody everything that can be right with the world. Hope, confidence, quietness, serenity, camaraderie. The day was good, and so are these people.  
> – Salma

Lola dove deep into into W3C processes (she is the co-chair of W3C Technical Architecture Group) and described and explained many things I wasn’t aware of (eg. the [priority of constituencies](https://davidroessli.com/perch/resources/blog/lola-odelola-w3c-priorities-webdayout.webp) or reducing user fingerprinting). Throught her talk, she elegantly demonstrated why a ‘dream feature’ (like `prefer-alt-text`) can be a bad idea, and all that from the point of view of a browser engineer.

## Amazed, and proud

I’m truly amazed by the rate at which new features, elements and properties are appearing, and proud to be part of this community, that strives to to design and build on the web, for the web, with native web elements.

More links:

-   [Mastodon toots](https://mastodon.social/tags/WebDayOut)
-   [Marc Thiele’s photos](https://marcthiele.com/photos/web-day-out-2026)
-   [My Flickr album](https://www.flickr.com/photos/davo39/albums/72177720332538923/)
-   [“That was Web Day Out”](https://adactio.com/journal/22465) by Jeremy
-   [“Look into the future of the web platform”](https://rachelandrew.co.uk/archives/2026/03/20/look-into-the-future-of-the-web-platform/) by Rachel

## Make friends, not followers

Michael Flarup wrote about the comeback of small conferences in his [latest newsletter](https://www.flarup.email/p/the-comeback-of-small-conferences) that echoes another reason why I like attending these kind of events so much:

> A conference is one of the few places where a scattered online community briefly becomes real.
> 
> There’s a realness that comes from meeting your peers face to face. All of the fluff that so often surrounds online discourse falls away. There is no hype, just passion. No engagement hook, just curiosity.
> 
> Instead of making followers, you make friends.

Thank you [Jeremy](https://adactio.com/) and [Clearleft](https://clearleft.com/) for hosting such events ????

© 2007–2026 Hidde de Vries ([Mastodon](https://front-end.social/@hdv), [Bluesky](https://bsky.app/profile/hidde.blog), [LinkedIn](https://linkedin.com/in/hiddedevries)).

This website uses [green hosting](https://www.thegreenwebfoundation.org/green-web-check/?url=hidde.blog). All content is human-written, not generated. I don't collect your data. Don't use my content to train your language models.

[AI statement](https://hidde.blog/ai)[Accessibility statement](https://hidde.blog/accessibility)

# Cross-document view transitions for multi-page applications  |  View Transitions  |  Chrome for Developers

<https://developer.chrome.com/docs/web-platform/view-transitions/cross-document>

[Skip to main content](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#main-content)

developer.chrome.com uses cookies to deliver and enhance the quality of its services and to analyze traffic. If you agree, cookies are also used to serve advertising and to personalize the content and advertisements that you see. [Learn more](https://policies.google.com/technologies/cookies?hl=en)

[Docs](https://developer.chrome.com/docs) [Case studies](https://developer.chrome.com/case-studies) [Blog](https://developer.chrome.com/blog) [New in Chrome](https://developer.chrome.com/new)

/

-   [View Transitions](https://developer.chrome.com/docs/web-platform/view-transitions)

[Web Platform](https://developer.chrome.com/docs/web-platform) [New releases](https://developer.chrome.com/docs/web-platform/new-in-chrome) [WebGPU](https://developer.chrome.com/docs/web-platform/webgpu)

-   Chrome concepts
    
-   [Chrome release channels](https://developer.chrome.com/docs/web-platform/chrome-release-channels)
-   [Chrome flags](https://developer.chrome.com/docs/web-platform/chrome-flags)
-   [Chrome variations](https://developer.chrome.com/docs/web-platform/chrome-variations)
-   [Understand origin trials](https://developer.chrome.com/docs/web-platform/origin-trials)
-   [Third-party origin trials](https://developer.chrome.com/docs/web-platform/third-party-origin-trials)
-   [Troubleshoot origin trials](https://developer.chrome.com/docs/web-platform/origin-trial-troubleshooting)
-   [Feature deprecation and removal](https://developer.chrome.com/docs/web-platform/chrome-deprecation)
-   Browser development
    
-   [Chrome and Chromium](https://developer.chrome.com/docs/web-platform/chrome-chromium)
-   [Blink rendering engine](https://developer.chrome.com/docs/web-platform/blink)
-   [Blink Intents](https://developer.chrome.com/docs/web-platform/blink-intents)
-   Features and APIs
    
-   Shipped to the web platform
    
    -   [Back/forward cache notRestoredReasons API](https://developer.chrome.com/docs/web-platform/bfcache-notrestoredreasons)
    -   [Compute Pressure API](https://developer.chrome.com/docs/web-platform/compute-pressure)
    -   [Conditional focus API](https://developer.chrome.com/docs/web-platform/conditional-focus)
    -   [Declarative Partial Updates](https://developer.chrome.com/docs/web-platform/declarative-partial-updates)
    -   [Device Bound Session Credentials](https://developer.chrome.com/docs/web-platform/device-bound-session-credentials)
    -   [Early Hints](https://developer.chrome.com/docs/web-platform/early-hints)
    -   [Handwriting Recognition API](https://developer.chrome.com/docs/web-platform/handwriting-recognition)
    -   [Heavy Ads Intervention](https://developer.chrome.com/docs/web-platform/heavy-ads-intervention)
    -   [Launch Handler API](https://developer.chrome.com/docs/web-platform/launch-handler)
    -   [Long Animation Frames API (LoAF)](https://developer.chrome.com/docs/web-platform/long-animation-frames)
    -   [Navigation API](https://developer.chrome.com/docs/web-platform/navigation-api)
    -   [Page Lifecycle API](https://developer.chrome.com/docs/web-platform/page-lifecycle-api)
    -   [Picture-in-Picture for any Element](https://developer.chrome.com/docs/web-platform/document-picture-in-picture)
    -   [Prerender with the Speculation Rules API](https://developer.chrome.com/docs/web-platform/prerender-pages)
    -   [Privacy-preserving screen sharing controls](https://developer.chrome.com/docs/web-platform/screen-sharing-controls)
    -   [Region Capture](https://developer.chrome.com/docs/web-platform/region-capture)
    -   [Soft navigations measurement](https://developer.chrome.com/docs/web-platform/soft-navigations)
    -   [Element Capture](https://developer.chrome.com/docs/web-platform/element-capture)
    -   [Captured Surface Control](https://developer.chrome.com/docs/web-platform/captured-surface-control)
    -   [Tab sharing with Capture Handle](https://developer.chrome.com/docs/web-platform/capture-handle)
    -   [VirtualKeyboard API](https://developer.chrome.com/docs/web-platform/virtual-keyboard)
    -   View Transitions API
        
        -   [Overview](https://developer.chrome.com/docs/web-platform/view-transitions)
        -   [Same-Document View Transitions for SPA](https://developer.chrome.com/docs/web-platform/view-transitions/same-document)
        -   [Cross-Document View Transitions for MPA](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document)
        
    -   [WebGPU](https://developer.chrome.com/docs/web-platform/webgpu)
    
-   Deprecating
    
-   No longer pursuing
    
-   Best practices
    
-   Version History API
    
-   [Sign up for origin trials](https://developer.chrome.com/origintrials)
-   [Chrome Platform status](https://chromestatus.com/features)
-   [Chromium projects](https://www.chromium.org/chromium-projects/)

-   On this page
-   [Cross-document view transitions are limited to same-origin navigations](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#cross-document_view_transitions_are_limited_to_same-origin_navigations)
-   [Cross-document view transitions are opt-in](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#cross-document_view_transitions_are_opt-in)
-   [Cross-document view transitions demo](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#cross-document_view_transitions_demo)
-   [Customize cross-document view transitions](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#customization)
    -   [The pageswap and pagereveal events](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#pageswap-pagereveal)
    -   [Navigation activation information](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#navigation-activation-info)
    -   [Wait for content to load with render blocking](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#render-blocking)
-   [View transition types in cross-document view transitions](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#view-transition-types)
    -   [Demo](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#demo)
-   [Feedback](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#feedback)

-   [Home](https://developer.chrome.com/)
-   [Docs](https://developer.chrome.com/docs)
-   [Web Platform](https://developer.chrome.com/docs/web-platform)
-   [View Transitions](https://developer.chrome.com/docs/web-platform/view-transitions)

# Cross-document view transitions for multi-page applications

Bramus

When a view transition occurs between two different documents it is called a _cross-document view transition_. This is typically the case in multi-page applications (MPA). Cross-document view transitions are supported in Chrome from Chrome 126.

Browser Support

-    126
-    126
-    x
-    18.2

[Source](https://developer.mozilla.org/docs/Web/CSS/Reference/At-rules/@view-transition)

Cross-document view transitions rely on the very same building blocks and principles as [same-document view transitions](https://developer.chrome.com/docs/web-platform/view-transitions/same-document), which is very intentional:

1.  The browser takes snapshots of elements that have a unique `view-transition-name` on both the old and new page.
2.  The DOM gets updated while rendering is suppressed.
3.  And finally, the transitions are powered by CSS animations.

**Note:** To learn more about these basic building blocks, refer to the [same-document view transitions](https://developer.chrome.com/docs/web-platform/view-transitions/same-document) documentation.

What's different when compared with same-document view transitions, is that with cross-document view transitions you don't need to call `document.startViewTransition` to start a view transition. Instead, the trigger for a cross-document view transition is a same-origin navigation from one page to another, an action that is typically performed by the user of your website clicking a link.

In other words, there is no API to call in order to start a view transition between two documents. However, there are two conditions that need to be fulfilled:

-   Both documents need to exist on the same origin.
-   Both pages need to opt-in to allow the view transition.

Both these conditions are explained later in this document.

**Note:** In Chrome 126, cross-document view transitions are limited to main frame navigations only. In a future release, cross-document view transitions will also be enabled for navigations occurring in iframes.

* * *

## Cross-document view transitions are limited to same-origin navigations

Cross-document view transitions are limited to **same-origin navigations** only. A navigation is considered to be same-origin if the origin of both participating pages is the same.

The origin of a page is a combination of the used scheme, hostname, and port, as [detailed on web.dev](https://web.dev/articles/same-site-same-origin).

An example URL with the scheme, hostname, and port highlighted. Combined, they form the origin.

For example, you can have a cross-document view transition when navigating from `developer.chrome.com` to `developer.chrome.com/blog`, as those are same-origin. You can't have that transition when navigating from `developer.chrome.com` to `www.chrome.com`, as those are cross-origin and same-site.

* * *

## Cross-document view transitions are opt-in

To have a cross-document view transition between two documents, both participating pages need to opt-in to allowing this. This is done with the `@view-transition` at-rule in CSS.

In the `@view-transition` at-rule, set the `navigation` descriptor to `auto` to enable view transitions for cross-document, same-origin navigations.

```
@view-transition {
  navigation: auto;
}
```

By setting `navigation` descriptor to `auto` you are opting in to allowing view transitions to happen for the following [NavigationType](https://developer.mozilla.org/docs/Web/API/NavigateEvent/navigationType)s:

-   `traverse`
-   `push` or `replace`, if the activation was not initiated by the user through browser UI mechanisms.

Navigations excluded from `auto` are, for example, navigating using the URL address bar or clicking a bookmark, as well as any form of user or script initiated reload.

If a navigation takes too long–more than four seconds in Chrome's case–then the view transition is skipped with a `TimeoutError` `DOMException`.

**Note:** In the future, you can expect more values for more fine-grained control over the navigation conditions. For now, only `auto` is accepted.

**Note:** Back when we were still experimenting with cross-document view transitions, the opt-in was a meta tag. This was a temporary measure to allow authors to test things out while the feature was still being developed. The new way of opting-in to MPA view transitions is from within CSS using the `@view-transition` at-rule.

## Cross-document view transitions demo

Check out the following demo that uses view transitions to create [a Stack Navigator demo](https://view-transitions.chrome.dev/stack-navigator/mpa/). There are no calls to `document.startViewTransition()` here, the view transitions are triggered by navigating from one page to another.

Recording of the [Stack Navigator demo](https://view-transitions.chrome.dev/stack-navigator/mpa-prerender/). Requires Chrome 126+.

**Note:** The forwards and backwards transitions are customized with `pagereveal`, which is covered in the next section.

* * *

## Customize cross-document view transitions

To customize cross-document view transitions, there are some web platform features that you can use.

-   [The `pageswap` and `pagereveal` events](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#pageswap-pagereveal)
-   [Navigation activation information](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#navigation-activation-info)
-   [Render blocking](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#render-blocking)

These features are not part of the View Transition API specification itself, but are designed to be used in conjunction with it.

### The `pageswap` and `pagereveal` events

Browser Support

-    124
-    124
-    x
-    18.2

[Source](https://developer.mozilla.org/docs/Web/API/PageSwapEvent)

To allow you to customize cross-document view transitions, the HTML specification includes two new events that you can use: `pageswap` and `pagereveal`.

These two events get fired for every same-origin cross-document navigation regardless of whether a view transition is about to happen or not. If a view transition is about to happen between the two pages, you can access the `ViewTransition` object using the `viewTransition` property on these events.

**Note:** The same-origin navigation cannot include any intermediate cross-origin redirects.

-   The `pageswap` event fires before the last frame of a page is rendered. You can use this to do some last-minute changes on the outgoing page, right before the old snapshots get taken.
-   The `pagereveal` event fires on a page after it has been initialized or reactivated but before the first rendering opportunity. With it, you can customize the new page before the new snapshots get taken.

For example, you can use these events to quickly set or change some `view-transition-name` values or pass data from one document to another by writing and reading data from [`sessionStorage`](https://developer.mozilla.org/docs/Web/API/Window/sessionStorage) to customize the view transition _before_ it actually runs.

```
let lastClickX, lastClickY;
document.addEventListener('click', (event) => {
  if (event.target.tagName.toLowerCase() === 'a') return;
  lastClickX = event.clientX;
  lastClickY = event.clientY;
});

// Write position to storage on old page
window.addEventListener('pageswap', (event) => {
  if (event.viewTransition && lastClick) {
    sessionStorage.setItem('lastClickX', lastClickX);
    sessionStorage.setItem('lastClickY', lastClickY);
  }
});

// Read position from storage on new page
window.addEventListener('pagereveal', (event) => {
  if (event.viewTransition) {
    lastClickX = sessionStorage.getItem('lastClickX');
    lastClickY = sessionStorage.getItem('lastClickY');
  }
});
```

If you want, you can decide to skip the transition in both events.

```
window.addEventListener("pagereveal", async (e) => {
  if (e.viewTransition) {
    if (goodReasonToSkipTheViewTransition()) {
      e.viewTransition.skipTransition();
    }
  }
}
```

**Important:** The `pagereveal` event listener needs to execute before the first rendering opportunity. Therefore you must register the listener in a classic parser-blocking script in the `<head>` _(not a module, not async, not defer)_. Using an asynchronous script–be it a module or regular `<script async>`–in the `<head>` can be used but then you must manually mark it as [render-blocking](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document#render-blocking) by adding `blocking=render` to the `<script>` tag.

The `ViewTransition` object in `pageswap` and `pagereveal` are two different objects. They also handle [the various promises](https://developer.chrome.com/docs/web-platform/view-transitions#api-reference) differently:

-   `pageswap`: Once the document is hidden, the old `ViewTransition` object is skipped. When that happens, `viewTransition.ready` rejects and `viewTransition.finished` resolves.
-   `pagereveal`: The `updateCallBack` promise is already resolved at this point. You can use the `viewTransition.ready` and `viewTransition.finished` promises.

* * *

### Navigation activation information

Browser Support

-    123
-    123
-    147
-    26.2

[Source](https://developer.mozilla.org/docs/Web/API/NavigationActivation)

In both `pageswap` and `pagereveal` events, you can also take action based on the URLs of the old and new pages.

For example, in the [MPA Stack Navigator](https://view-transitions.chrome.dev/stack-navigator/mpa/) the type of animation to use depends the navigation path:

-   When navigating from the overview page to a detail page, the new content needs to slide in from the right to the left.
-   When navigating from the detail page to the overview page, the old content needs to slide out from the left to the right.

To do this you need information about the navigation that, in the case of `pageswap`, is about to happen or, in the case of `pagereveal` just happened.

For this, browsers can now expose `NavigationActivation` objects which hold info about the same-origin navigation. This object exposes the used navigation type, the current, and the final destination history entries as found in [`navigation.entries()` from the Navigation API](https://developer.chrome.com/docs/web-platform/navigation-api#access_all_entries).

On an activated page, you can access this object through `navigation.activation`. In the `pageswap` event, you can access this through `e.activation`.

Check out [this Profiles demo](https://view-transitions.chrome.dev/profiles/mpa/) that uses `NavigationActivation` info in the `pageswap` and `pagereveal` events to set the `view-transition-name` values on the elements that need to participate in the view transition.

That way, you don't have to decorate each and every item in the list with a `view-transition-name` upfront. Instead, this happens just-in-time using JavaScript, only on elements that need it.

Recording of the [Profiles demo](https://view-transitions.chrome.dev/profiles/mpa/). Requires Chrome 126+.

The code is as follows:

```
// OLD PAGE LOGIC
window.addEventListener('pageswap', async (e) => {
  if (e.viewTransition) {
    const targetUrl = new URL(e.activation.entry.url);

    // Navigating to a profile page
    if (isProfilePage(targetUrl)) {
      const profile = extractProfileNameFromUrl(targetUrl);

      // Set view-transition-name values on the clicked row
      document.querySelector(`#${profile} span`).style.viewTransitionName = 'name';
      document.querySelector(`#${profile} img`).style.viewTransitionName = 'avatar';

      // Remove view-transition-names after snapshots have been taken
      // (this to deal with BFCache)
      await e.viewTransition.finished;
      document.querySelector(`#${profile} span`).style.viewTransitionName = 'none';
      document.querySelector(`#${profile} img`).style.viewTransitionName = 'none';
    }
  }
});

// NEW PAGE LOGIC
window.addEventListener('pagereveal', async (e) => {
  if (e.viewTransition) {
    const fromURL = new URL(navigation.activation.from.url);
    const currentURL = new URL(navigation.activation.entry.url);

    // Navigating from a profile page back to the homepage
    if (isProfilePage(fromURL) && isHomePage(currentURL)) {
      const profile = extractProfileNameFromUrl(currentURL);

      // Set view-transition-name values on the elements in the list
      document.querySelector(`#${profile} span`).style.viewTransitionName = 'name';
      document.querySelector(`#${profile} img`).style.viewTransitionName = 'avatar';

      // Remove names after snapshots have been taken
      // so that we're ready for the next navigation
      await e.viewTransition.ready;
      document.querySelector(`#${profile} span`).style.viewTransitionName = 'none';
      document.querySelector(`#${profile} img`).style.viewTransitionName = 'none';
    }
  }
});
```

The code also cleans up after itself by removing the `view-transition-name` values after the view transition ran. This way the page is ready for successive navigations and can also handle traversal of the history.

To aid with this, use this utility function that temporarily sets `view-transition-name`s.

```
const setTemporaryViewTransitionNames = async (entries, vtPromise) => {
  for (const [$el, name] of entries) {
    $el.style.viewTransitionName = name;
  }

  await vtPromise;

  for (const [$el, name] of entries) {
    $el.style.viewTransitionName = '';
  }
}
```

The previous code can now be simplified as follows:

```
// OLD PAGE LOGIC
window.addEventListener('pageswap', async (e) => {
  if (e.viewTransition) {
    const targetUrl = new URL(e.activation.entry.url);

    // Navigating to a profile page
    if (isProfilePage(targetUrl)) {
      const profile = extractProfileNameFromUrl(targetUrl);

      // Set view-transition-name values on the clicked row
      // Clean up after the page got replaced
      setTemporaryViewTransitionNames([
        [document.querySelector(`#${profile} span`), 'name'],
        [document.querySelector(`#${profile} img`), 'avatar'],
      ], e.viewTransition.finished);
    }
  }
});

// NEW PAGE LOGIC
window.addEventListener('pagereveal', async (e) => {
  if (e.viewTransition) {
    const fromURL = new URL(navigation.activation.from.url);
    const currentURL = new URL(navigation.activation.entry.url);

    // Navigating from a profile page back to the homepage
    if (isProfilePage(fromURL) && isHomePage(currentURL)) {
      const profile = extractProfileNameFromUrl(currentURL);

      // Set view-transition-name values on the elements in the list
      // Clean up after the snapshots have been taken
      setTemporaryViewTransitionNames([
        [document.querySelector(`#${profile} span`), 'name'],
        [document.querySelector(`#${profile} img`), 'avatar'],
      ], e.viewTransition.ready);
    }
  }
});
```

* * *

### Wait for content to load with render blocking

Browser Support

-    124
-    124
-    x
-    x

In some cases, you may want to hold off the first render of a page until a certain element is present in the new DOM. This avoids flashing and ensure the state you're animating to is stable.

In the `<head>`, define one or more element IDs that need to be present before the page gets its first render, using the following meta tag.

```
<link rel="expect" blocking="render" href="#section1">
```

This meta tag means that the element should be present in the DOM, not that the content should be loaded. For example with images, the mere presence of the `<img>` tag with the specified `id` in the DOM tree is enough for the condition to evaluate to true. The image itself could still be loading.

Before you go all-in on render blocking be aware that incremental rendering is a fundamental aspect of the Web, so be cautious when opting to blocking rendering. The impact of blocking rendering needs to be evaluated on a case by case basis. By default, avoid using `blocking=render` unless you can actively measure and gauge the impact it has on your users, by measuring the impact to your [Core Web Vitals](https://web.dev/articles/vitals).

**Note:** For best effect of cross-page view transitions in general you need fast loading pages. For this you can consider [prerendering, using the Speculation Rules API](https://developer.chrome.com/docs/web-platform/prerender-pages).

* * *

## View transition types in cross-document view transitions

Cross-document view transitions also support [view transition types](https://developer.chrome.com/docs/web-platform/view-transitions/same-document#view-transition-types) to customize the animations and which elements get captured.

For example, when going to the next or to the previous page in a pagination, you might want to use different animations depending on whether you are going to a higher page or a lower page from the sequence.

To set these types upfront, add the types in the `@view-transition` at-rule:

```
@view-transition {
  navigation: auto;
  types: slide, forwards;
}
```

To set the types on the fly, use the `pageswap` and `pagereveal` events to manipulate the value of `e.viewTransition.types`.

```
window.addEventListener("pagereveal", async (e) => {
  if (e.viewTransition) {
    const transitionType = determineTransitionType(navigation.activation.from, navigation.activation.entry);
    e.viewTransition.types.add(transitionType);
  }
});
```

**Note:** `ViewTransition.types` is a [`Set`\-like](https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Set#set-like_browser_apis) object that holds the active view transition's types. To manipulate the entries, use [its instance methods](https://developer.mozilla.orgdocs/Web/JavaScript/Reference/Global_Objects/Set#instance_methods) `clear()`, `add()`, and `delete()`.

The types are not automatically carried over from the `ViewTransition` object on the old page to the `ViewTransition` object of the new page. You need to determine the type(s) to use on at least the new page in order for the animations to run as expected.

To respond to these types, use the `:active-view-transition-type()` pseudo-class selector [in the same way as with same-document view transitions](https://developer.chrome.com/docs/web-platform/view-transitions/same-document#view-transition-types)

```
/* Determine what gets captured when the type is forwards or backwards */
html:active-view-transition-type(forwards, backwards) {
  :root {
    view-transition-name: none;
  }
  article {
    view-transition-name: content;
  }
  .pagination {
    view-transition-name: pagination;
  }
}

/* Animation styles for forwards type only */
html:active-view-transition-type(forwards) {
  &::view-transition-old(content) {
    animation-name: slide-out-to-left;
  }
  &::view-transition-new(content) {
    animation-name: slide-in-from-right;
  }
}

/* Animation styles for backwards type only */
html:active-view-transition-type(backwards) {
  &::view-transition-old(content) {
    animation-name: slide-out-to-right;
  }
  &::view-transition-new(content) {
    animation-name: slide-in-from-left;
  }
}

/* Animation styles for reload type only */
html:active-view-transition-type(reload) {
  &::view-transition-old(root) {
    animation-name: fade-out, scale-down;
  }
  &::view-transition-new(root) {
    animation-delay: 0.25s;
    animation-name: fade-in, scale-up;
  }
}
```

Because types only apply to an active view transition, types automatically get cleaned up when a view transition finishes. Because of that, types work well with features like [BFCache](https://web.dev/articles/bfcache).

**Note:** Determining and setting the types is typically needed only on the new page, using the `pagereveal` event. An exception to this is shown in the preceding CSS snippet, when actively changing the elements to capture with `:active-view-transition-type()`.

### Demo

In the following [pagination demo](https://view-transitions.chrome.dev/pagination/mpa/), the page contents slide forwards or backwards based on the page number that you are navigating to.

Recording of the [Pagination demo (MPA)](https://view-transitions.chrome.dev/pagination/mpa/). It uses different transitions depending on which page you are going to.

The transition type to use is determined in the `pagereveal` and `pageswap` events by looking at the to and from URLs.

```
const determineTransitionType = (fromNavigationEntry, toNavigationEntry) => {
  const currentURL = new URL(fromNavigationEntry.url);
  const destinationURL = new URL(toNavigationEntry.url);

  const currentPathname = currentURL.pathname;
  const destinationPathname = destinationURL.pathname;

  if (currentPathname === destinationPathname) {
    return "reload";
  } else {
    const currentPageIndex = extractPageIndexFromPath(currentPathname);
    const destinationPageIndex = extractPageIndexFromPath(destinationPathname);

    if (currentPageIndex > destinationPageIndex) {
      return 'backwards';
    }
    if (currentPageIndex < destinationPageIndex) {
      return 'forwards';
    }

    return 'unknown';
  }
};
```

## Feedback

Developer feedback is always appreciated. To share, [file an issue with the CSS Working Group on GitHub](https://github.com/w3c/csswg-drafts) with suggestions and questions. Prefix your issue with `[css-view-transitions]`. Should you run into a bug, then [file a Chromium bug](https://crbug.com/new) instead.

Except as otherwise noted, the content of this page is licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/), and code samples are licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0). For details, see the [Google Developers Site Policies](https://developers.google.com/site-policies). Java is a registered trademark of Oracle and/or its affiliates.

Last updated 2024-04-14 UTC.

-   ### Contribute
    
    -   [File a bug](https://issuetracker.google.com/issues/new?component=1400036&template=1897236)
    -   [See open issues](https://issuetracker.google.com/issues?q=status:open%20componentid:1400036&s=created_time:desc)
-   ### Related content
    
    -   [Chromium updates](https://blog.chromium.org/)
    -   [Case studies](https://developer.chrome.com/case-studies)
    -   [Archive](https://developer.chrome.com/deprecated)
    -   [Podcasts & shows](https://web.dev/shows)
-   ### Follow
    
    -   [@ChromiumDev on X](https://twitter.com/ChromiumDev)
    -   [YouTube](https://www.youtube.com/user/ChromeDevelopers)
    -   [Chrome for Developers on LinkedIn](https://www.linkedin.com/showcase/chrome-for-developers)
    -   [RSS](https://developer.chrome.com/static/blog/feed.xml)

-   [Terms](https://policies.google.com/terms)
-   [Privacy](https://policies.google.com/privacy)
-   Manage cookies

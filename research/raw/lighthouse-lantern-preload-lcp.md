# Lighthouse Punishes Good Asset Preloading
<https://github.com/GoogleChrome/lighthouse/issues/16539>
created 2025-06-12T08:33:12Z closed 2026-10-08T21:23:27Z state CLOSED

Imagine you have a page with fast real-world FCP and LCP. A page like [this one](https://entire-darlings-348663.framer.app/page-with-instant-lcp):

![Image](https://github.com/user-attachments/assets/8f16a8f5-304f-4f66-8369-578683e879af)

It doesn’t have any render-blocking resources. Its only contentful element above the fold is a text block (which uses system fonts). Its real-world loading speed metrics (FCP and LCP) are around 1.0-1.1s.

Now, run this page [through Lighthouse](https://pagespeed.web.dev/analysis/https-entire-darlings-348663-framer-app-page-with-instant-lcp/386k6pjja5?form_factor=mobile):

![Image](https://github.com/user-attachments/assets/cc36cd13-07bb-4cd0-8694-533e752bc7f7)

Suddenly:

- the FCP of the page is yellow or red
- the LCP of the page is much higher than FCP, even though the FCP and the LCP element *is the same*

Can you guess why?

### Simulated Throttling

Lighthouse (and, therefore, PageSpeed Insights), by default, [uses simulated throttling](https://github.com/GoogleChrome/lighthouse/blob/main/docs/throttling.md). The idea behind it [is simple](https://calendar.perfplanet.com/2021/how-does-lighthouse-simulated-throttling-work/): instead of actually throttling the network while loading the page (which is slow), let’s load the page on a fast connection → look at the network graph and real FCP/LCP → *simulate* how the network graph would behave on a slow connection → derive slow FCP/LCP from that graph.

The challenge? That last step is far from perfect. For example:

- To simulate slow LCP, Lighthouse looks at all requests that happened before real LCP – and assumes that [LCP requires *all* of them](https://source.chromium.org/chromium/chromium/src/+/main:out/mac-Debug/gen/third_party/devtools-frontend/src/front_end/models/trace/lantern/metrics/LargestContentfulPaint.js;l=27-48?q=getEstimateFromSimulation&ss=chromium):
    
    ![Image](https://github.com/user-attachments/assets/1b34a4fe-15e5-4104-bb67-eab4e9884ecb)

    This causes a bunch of issues.
    
    - Preloaded a font? Well, now simulated LCP will be delayed by that font load time, even if the LCP element is actually an image.
    - Fetched a tiny, non-blocking script that just so happened to load before real LCP? Too bad, now that script will delay simulated LCP as well.
- To simulate slow FCP, Lighthouse [does the same thing](https://source.chromium.org/chromium/chromium/src/+/main:out/mac-Debug/gen/third_party/devtools-frontend/src/front_end/models/trace/lantern/metrics/FirstContentfulPaint.js;l=95-109). (The code path is literally the same!) The only difference is that for FCP, nodes with a low fetch priority are ignored. This means offscreen images and non-blocking scripts won’t delay FCP (yay!), but `@font-face` requests (meh) or `modulepreload`s (eh?) still will.

### This Punishes (Good) Preloading

_(and, in general, any kind of good early-loaded assets)_

Framer is a no-code website platform that deeply cares about performance. At Framer sites, we try to help the browser load critical resources ASAP. To do this, we:

- emit `<link rel="modulepreload">`s for all JS modules that the current page needs
- inline the page CSS, including `@font-face`s, straight into the HTML

These optimizations directly improve real-world performance, making the site visible and interactive sooner. These optimizations also dramatically worsen the Lighthouse score.

<details>

<summary>Demo</summary>
    
Above, you saw a loading trace of a demo page ([URL](https://entire-darlings-348663.framer.app/page-with-instant-lcp)). For this trace, `lighthouse -A` computes the following FCP and LCP:

![Image](https://github.com/user-attachments/assets/8d12db53-b232-464e-9920-f446e5465ed0)


Now, here’s the same page, modified to not have any `<link rel="modulepreload">` elements ([URL](https://framer-cloudflare-proxy.iamakulov.workers.dev/page-with-instant-lcp?host=entire-darlings-348663.framer.app&remove-elements=%5Brel%3Dmodulepreload%5D)):

![Image](https://github.com/user-attachments/assets/6a8fecbb-5b11-4c7d-847f-fba9542bdfeb)


We removed `<link rel="modulepreload">`s, so:

- the real-world LCP is still ~same (200-300 ms) because `<link rel="modulepreload">`s don’t affect it
- website hydrates much later (at ~2000 ms instead of ~500 ms), making the real user experience worse

However, `lighthouse -A` now simulates a much better LCP:

![Image](https://github.com/user-attachments/assets/41fc0ffb-4953-4f0d-8031-cab7316623b6)

</details>  

### This is Bad

This is bad because it creates bad incentives:

- Developers are forced to pick between doing deep research (and convincing stakeholders that Lighthouse isn’t accurate) – or making the site *slower for real users* just to get the score higher
- Companies (web platforms like Framer, agencies, etc.) are forced to pick between shipping fast sites – or retaining the business of customers who look at PageSpeed Insights scores

### This is Serious

In Nov 2024, Google Amsterdam hosted [WebPerfDays Unconference](https://x.com/HenriHelvetica/status/1854279159247524204), an informal discussion event for Googlers, GDEs, and web perf specialists. At the event, the mismatch between Lighthouse and Core Web Vitals was (to my memory) one of the most-discussed points.

See also other people being struck by this issue: WebPerf Slack [one](https://webperformance.slack.com/archives/C04BK7K1X/p1742922067789419), [two](https://webperformance.slack.com/archives/C04BK7K1X/p1676553293876909), https://github.com/GoogleChrome/lighthouse/issues/11460

### Solutions

There are easy solutions, and there are hard ones.

- *Easy solution 1:* Fine-tune the simulation algo.
    - Ignore `modulepreload`s when computing FCP and LCP
    - Ignore fonts when computing FCP and LCP if 1) the FCP/LCP element is not text, or 2) the FCP/LCP element is text that uses a system font, or 3) `@font-face` uses `font-display: swap` [or similar]
    
    At least some of those changes would have to be upstreamed to `@paulirish/trace_engine` which is not on GitHub.
    
    *This will reduce the punishment that Lighthouse gives to early requests.*
    
- *Easy solution 2:* For simulated FCP and LCP, pick `min(simulated FCP value, simulated LCP value)` when 1) their real-world values are the same, and 2) they were triggered by the same element.
    
    *This will avoid an artificial mismatch between FCP and LCP when they are actually the same in the real world.*
    

I would be happy to contribute these changes if you’re open to accepting them.

The harder solution would be to get smarter about figuring out what assets are *actually* render-blocking. We might have to look at 1) where a script is positioned in the document, 2) whether a script applies an anti-flicker effect, etc. This is harder and much less defined, but perhaps this issue could be a start of a discussion.



## sod 2025-06-24T12:53:47Z

Edit: Seems like lighthouse 12.7 fixed the issue 👀 

---

Yes! We use angular with SSR (server side rendering) with incremental hydration and event replay. This means the customers see static DOM after 400ish milliseconds which is 100% visually complete and 90% functional (as most interactive elements are real hyperlinks that work without angular), and thanks to incremental hydration and event replay, angular will pick up the entire DOM and replay any event that happened beforehand for the 10% remainder. E.g. if the customer clicked the burger menu and angular bootstraps 1 second after, the burger menu will open right that second.

But due to the behavior you described, lighthouse treats our static html from SSR as it wasn't there and treats our page as if it was a blank page until all scripts finished loading.

Maybe it was just an oversight, as when you run lighthouse cli you see these two errors specifically about FCP and LCP
```
  LH:lh:computed:TimingSummary:error Error: FCP All Frames not implemented in lantern
  LH:lh:computed:TimingSummary:error     at FirstContentfulPaintAllFrames.computeSimulatedMetric (file:///opt/homebrew/lib/node_modules/lighthouse/core/computed/metrics/first-contentful-paint-all-frames.js:16:11)
  LH:lh:computed:TimingSummary:error     at FirstContentfulPaintAllFrames.compute_ (file:///opt/homebrew/lib/node_modules/lighthouse/core/computed/metrics/metric.js:90:21) +1ms
  LH:lh:computed:TimingSummary:error Error: LCP All Frames not implemented in lantern
  LH:lh:computed:TimingSummary:error     at LargestContentfulPaintAllFrames.computeSimulatedMetric (file:///opt/homebrew/lib/node_modules/lighthouse/core/computed/metrics/largest-contentful-paint-all-frames.js:21:11)
  LH:lh:computed:TimingSummary:error     at LargestContentfulPaintAllFrames.compute_ (file:///opt/homebrew/lib/node_modules/lighthouse/core/computed/metrics/metric.js:90:21) +0ms
```

from https://github.com/GoogleChrome/lighthouse/blob/main/core/computed/metrics/first-contentful-paint-all-frames.js#L14-L17 and https://github.com/GoogleChrome/lighthouse/blob/main/core/computed/metrics/largest-contentful-paint-all-frames.js#L20-L22

## iamakulov 2025-07-11T10:44:29Z

> Edit: Seems like lighthouse 12.7 fixed the issue 👀

Glad it did it for your issue! But I’m guessing that means it had a different root cause. What I described above still stands, and none of the [algos responsible](https://github.com/ChromeDevTools/devtools-frontend/blob/f9daaf82ddcf36cd9af189b692fd062fbadb59f7/front_end/models/trace/lantern/metrics/FirstContentfulPaint.ts#L132-L165) for [simulating FCP/LCP](https://github.com/ChromeDevTools/devtools-frontend/blob/f9daaf82ddcf36cd9af189b692fd062fbadb59f7/front_end/models/trace/lantern/metrics/LargestContentfulPaint.ts#L41-L67) have changed.

---

In the meantime, I talked to @tunetheweb (ty!!) and learned a bit more about contributing to the Lighthouse repo.

I want to reiterate: I’m happy to work on the proposed ideas (see “Solutions” ↑) myself, and I’m happy to dedicate a significant chunk of my work time (20%?) to this. This issue has been a huge pet peeve of mine, and I’d love to see Lighthouse thrive while also giving more accurate test scores 🖤

But with changes that big, the Lighthouse team will likely need to trial them for a while before rolling them out to everyone. So before I embark on this quest, I’d love to hear whether you folks are interested in experimenting with changes to the core FCP/LCP algos. (Because if you don’t have capacity to support that right now – which is valid! – then my efforts will be in vain!) 

cc maybe @jackfranklin because we talked about this very issue on WebPerfDays Unconference in Amsterdam last year 🤞

## paulirish 2025-07-11T20:28:36Z

Hi Ivan! Really appreciate the deep investigation and thorough report!  We're lucky to have such an invested community member and contributor.

You're right.  And I really like your solutions. 

I'd be happy to move ahead with your suggestions for **tweaking the LCP simulation algo**. Those adjustments are entirely reasonable.  👍 

I also like your **LCP clamp when the observed values are the same** proposal. The same DOM node condition is a good, safe call. (Nice). Yeah we can definitely do that. 👍 


We would definitely love that and appreciate your time. We can trial things out to make sure they don't raise any red flags, but.. as of right now, I feel pretty optimistic. 

_Below, some added background, context, and guidance…_

### Simulation and graphs tldr

For LCP (and our other metrics) we need two graphs. They graphs are built of nodes which represent either CPU tasks or Network requests, though.. it's mostly network.  Why two? One is is a best-case scenario, the other in a worst-case. We then `simulate()` each graph and get an estimate (in ms) from that.  We "blend" those two estimates, though in this case it ends up just [being an average](https://source.chromium.org/chromium/chromium/src/+/main:third_party/devtools-frontend/src/front_end/models/trace/lantern/metrics/LargestContentfulPaint.ts;l=20-24;drc=d5da73f2369dbd6c6628e81fb8a373917e8520ad) of the two. FWIW, I'm open to tweaking that blend if your future self is interested. 

Related, there's https://github.com/GoogleChrome/lighthouse/issues/15737 which explored similar things and called out that our optimistic graph is including more network requests than it should.  (Basically same as what you were saying.)

### Code locations

FYI A year ago we moved lantern (the simulation engine) from the LH into the DevTools repo. 

It sounds like you've already peeked at the code but.. yeah the relevant files are

* [LargestContentfulPaint.ts](https://source.chromium.org/chromium/chromium/src/+/main:third_party/devtools-frontend/src/front_end/models/trace/lantern/metrics/LargestContentfulPaint.ts) where the LCP simulation is defined
* [FirstContentfulPaint.ts](https://source.chromium.org/chromium/chromium/src/+/main:third_party/devtools-frontend/src/front_end/models/trace/lantern/metrics/FirstContentfulPaint.ts;l=132-165;drc=6f18728664c962ba99e4d3adda42a883dfb331ee)  the helper methods that end up doing the work
* [Metric.ts](https://source.chromium.org/chromium/chromium/src/+/main:third_party/devtools-frontend/src/front_end/models/trace/lantern/metrics/Metric.ts;l=87-122) where we simulate the two graphs and blend the result.

@paulirish/trace_engine is built from the DevTools repo. 

### Quick hack-mode

There's a bit of complexity ahead so..   the **easiest** way to develop would probably be to check out the LH repo, get it build/running, and then just make edits to the files within node_modules/@paulirish/trace_engine .. and I can help land them.  

Or.. below the full flow with DevTools changes -> trace_engine -> LH.

### DevTools contribution.

https://source.chromium.org/chromium/chromium/src/+/main:third_party/devtools-frontend/src/docs/contributing/README.md and https://source.chromium.org/chromium/chromium/src/+/main:third_party/devtools-frontend/src/docs/get_the_code.md cover how to check out that repo. As its chromium, the contribution process doesn't use github, but gerrit and depot_tools and stuff.  It's not terrible but.. it's definitely friction. :/

The `trace_engine` is built from a living branch of devtools, [which lives here](https://github.com/paulirish/devtools-frontend/tree/trace-engine-lib). Every few weeks we merge devtools' origin/main into it. (It's not ideal that it's a branch, but.. anyway).  Per [this](https://github.com/paulirish/devtools-frontend/blob/trace-engine-lib/front_end/models/trace/README.md#maintainer-cheatsheet) you can run `scripts/trace/prep-trace-engine-package.sh` and it'll build the files for the NPM package. Then, you could `npm link` that new folder so that a local LH build can use it.

So in this world, you have a devtools branch like `trace-engine-lib-plus-lcptweaks`, make your edits, run the .sh, and then your local LH will use your updated changes.  Once done, your CL to devtools would be from a `only-lcptweaks` kind of branch. Apologies for the verbosity and/or annoyingness here. :)  

----------------

Also just sent you a message so we have you can easily msg me if/when the above throws you any curveballs.

Hope this helps, and thanks again!



## iamakulov 2025-07-11T20:54:38Z

This is incredibly helpful, tysm @paulirish! Great to hear you’re interested in exploring those. I’ll start with this:

> I also like your LCP clamp when the observed values are the same proposal. The same DOM node condition is a good, safe call. (Nice). Yeah we can definitely do that. 👍

as it seems to be simplest optimization. I’ll try to follow the full DevTools flow to reduce the friction for you folks, but I’ll reach out if it’s too complicated, and I need your help landing this.

Full disclosure: I’m on a holiday for the next two weeks, but it is my plan to pick this up as soon as I’m back.

## jackfranklin 2025-07-23T07:12:37Z

Hey @iamakulov thanks so much for your suggestions and pushing on this; feel free to ping me if you have any issues with the DevTools repository and working on it. Happy to have a quick meeting or video call to talk you through anything. The docs are pretty thorough so should help you out and none of it is Googler specific.

## iamakulov 2025-08-04T09:08:45Z

Quick status update: I’m back from the holiday, and I’m (still) working on this:

> I also like your LCP clamp when the observed values are the same proposal. The same DOM node condition is a good, safe call. (Nice). Yeah we can definitely do that. 👍

The [actual code change](https://github.com/GoogleChrome/lighthouse/compare/main...iamakulov:lighthouse:lantern-lcp-fcp-same-frame?expand=1) is small, but I’m taking extra time to make sure it looks correct (by running it against ~200 sites and checking if score changes make sense). Sadly, I ran out of time this week, so I’m going to continue next week.

---

**Important implementation note:** We talked about using “same DOM node” as a condition for clamping. However, that ended up being a) pretty hard to implement, b) rather unnecessary (?). So, instead, I’ll be PRing a change where the algo is simply checking whether FCP and LCP happen within the same paint.

Why both hard to implement and unnecessary? If you look at how [Chromium FCP/LCP detection works](https://source.chromium.org/chromium/chromium/src/+/main:third_party/blink/renderer/core/paint/timing/paint_timing.cc;l=303;drc=d32f634388f26f8c7bbb98c82fa9718d30636b1e), you’ll see that:
- for every paint, Chrome detects whether the paint is FCP and may have been an LCP
- if the paint is FCP, Chrome adds the `firstContentfulPaint` trace mark
- if the paint is an LCP candidate, Chrome [determines what images or text rendered within this paint](https://source.chromium.org/chromium/chromium/src/+/main:third_party/blink/renderer/core/paint/timing/paint_timing_detector.cc;l=425;drc=877c4eff05eee91a64ab498b2f02928fe718278b;bpv=1;bpt=1) – and adds the `largestContentfulPaint::Candidate` trace mark

This algo has two consequences:
1. _FCP doesn’t have a clear DOM node associated with it._ There’s no `nodeId` in the FCP trace, unlike with LCP, so we can’t clearly compare whether FCP and LCP got triggered by the same DOM node.

   <details>

   <summary>Screenshots</summary>

   <img width="754" height="702" alt="Image" src="https://github.com/user-attachments/assets/d181575b-c731-4522-a2c0-97f3eada95b9" />

   <img width="1038" height="1166" alt="Image" src="https://github.com/user-attachments/assets/9ecacd84-3e43-4973-8518-8921d8ebf3d4" />

   </details>

   This makes clamping hard to implement. And we can ofc do the work to add `nodeId` for the FCP trace (I was ready to clone Chromium!), but this brings me to the second consequence:

2. _If we associate a `nodeId` with FCP, it would always be the same node as LCP._ Look at the algo again: first, Chromium looks at each paint and determines whether it’s FCP/LCP. Then, it uses `ImagePaintTimingDetector` and `TextPaintTimingDetector` to determine what image or text rendered within that paint. And then, it associates that image or text with LCP.

   If we were to implement node detection for FCP, we’d use the same `ImagePaintTimingDetector` and `TextPaintTimingDetector`. And for the same paint, they would always return the same `nodeId`s.

   This makes comparing DOM nodes at the Lighthouse level unnecessary. If, within the same paint, the attributed `nodeId` is always the same, then we don’t need to compare paint IDs _and_ node IDs. We can simply compare paint IDs only.

## paulirish 2025-08-28T17:22:49Z

>  So, instead, I’ll be PRing a change where the algo is simply checking whether FCP and LCP happen within the same paint.

Ah! good call. Yup everything that you said is accurate and we should be fine.

Though we don't have a 'paint id' and finding the parent paint event probably is not worth it.

The exact timestamp (`ts`) is passed around so if FCP & LCP are the same, luckily the ts is exactly the same. So we can use that. We could even say if they're within 5ms of eachother, we call it the same. (I don't see why they would be but.. easy enough)

## iamakulov 2025-09-12T22:10:35Z

Quick update here: I’ve been trying to get back to this, but the 20% thing is clearly not working out for me (I’ve been getting pulled aside by internal priorities). So I’m going to dedicate a couple of proper weeks to this, ~starting next week or the week after~ UPDATE Oct 2: still wrapping up the work project that’s preceding this one, ETA soon. Thank you for your patience :)

## iamakulov 2025-11-08T00:22:26Z

Alright, after wrapping up [the project that took three months](https://x.com/iamakulov/status/1981666558205431910) (= three months longer than expected :D), I’m finally free. So here comes the first PR! https://github.com/GoogleChrome/lighthouse/pull/16782

Would appreciate your review! I’ll kick off the second PR (“Ignore `modulepreloads` when computing FCP and LCP”), in the meantime :)

## brendankenny 2025-11-11T00:04:03Z

> 2\. _If we associate a `nodeId` with FCP, it would always be the same node as LCP._ Look at the algo again: first, Chromium looks at each paint and determines whether it’s FCP/LCP. Then, it uses `ImagePaintTimingDetector` and `TextPaintTimingDetector` to determine what image or text rendered within that paint. And then, it associates that image or text with LCP.
>     If we were to implement node detection for FCP, we’d use the same `ImagePaintTimingDetector` and `TextPaintTimingDetector`. And for the same paint, they would always return the same `nodeId`s.

I feel like I'm getting tripped up on this point. Having the same timestamp seems necessary but not sufficient, because many nodes can have very different critical paths but still be presented at the same time (since all the paint timing trace events set their `ts` to the paint time).

For example, a page with text included inline in the html document as the typical FCP but an LCP image requiring a fetch. Depending on the machine, the connection, and the rest of the page (e.g. render-blocking resources, if the LCP image is identifiable by the preload scanner, etc), the LCP image might be ready to paint in the same frame as the text. On a slower device and connection, though, the LCP image might not be ready by the time the browser can make that first contentful paint.

Am I missing something, though?

I do agree it will be difficult to impossible to annotate the FCP trace event with the node that was painted since flagging contentful paints is done in so many places, and they all only record the timestamp for use in `PaintTiming::MarkPaintTimingInternal` because that's all that's ever been needed. There are some other layout and painting trace events with somewhat extensive node info recorded, but it would likely be a lot of work and still not enough to establish equivalence. The effort to only evaluate nodes for timing/tracing on frames means this aliasing might be a fundamental problem for simulated throttling regardless, and that improvements will have to come entirely from the simulation side.

## iamakulov 2025-11-12T09:58:00Z

@brendankenny I responded in https://github.com/GoogleChrome/lighthouse/pull/16782#issuecomment-3521028754! (Moved it there because I’ll be posting other qs unrelated to that PR here now.)

## iamakulov 2025-11-12T10:53:17Z

> I’ll be posting other qs unrelated to that PR here now

speaking of which! :D

I’m currently investigating the next algo change: ignoring `modulepreload`s when computing FCP and LCP. `modulepreload`s are nasty because they have the fetch priority of `High` and `resourceType` of `Script`; this makes FCP [treat them as render-blocking](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/metrics/FirstContentfulPaint.ts#L174).

I noticed we already have [some logic for regular `preload`s](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/insights/NetworkDependencyTree.ts#L192) lying around, but it wasn’t extended when `modulepreload`s were added. Unfortunately, this flag is set [inside Chromium internals](https://source.chromium.org/chromium/chromium/src/+/main:third_party/blink/renderer/core/html/parser/preload_request.cc;l=171;drc=dce6bb944aa5c46b37a8cc4a314e2357cbfeab6d;bpv=0;bpt=1), so I’ll need to drill `modulepreload`s all the way back from there, too.

Thus, could you sanity-check if this plan makes sense? 🙏

- **Drilling:**
  - Add a new `isLinkModulePreload` field alongside `isLinkPreload` [in the traces](https://source.chromium.org/chromium/chromium/src/+/main:third_party/blink/renderer/core/inspector/inspector_trace_events.cc;l=789?q=isLinkPreload&ss=chromium/chromium/src), and drill its value [from `preload_request.cc`](https://source.chromium.org/chromium/chromium/src/+/main:third_party/blink/renderer/core/html/parser/preload_request.cc;l=171;drc=dce6bb944aa5c46b37a8cc4a314e2357cbfeab6d;bpv=0;bpt=1)
  - Consume this value in `devtools_frontend`, and drill it around everywhere `isLinkPreload` is available
- **Actual algo changes:**
  - [In `hasRenderBlockingPriority()`,](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/graph/NetworkNode.ts#L85-L92) return `false` for `preload`s/`modulepreload`s
    - This feels safe-ish: those requests are definitely not render-blocking, although there’s probably _some_ reason why they weren’t included into this check before? 
  - In [the optimistic LCP algo](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/metrics/LargestContentfulPaint.ts#L50), exclude (module)preloads, or perhaps even all scripts _if_ the image was discovered by the parser and not JS-inserted
    - This is a BIG change, so I’d love to make sure it passes the smell test. On the surface, it feels reasonable: on most sites, images that are parser-discovered should be visible without JS; and on the rare occasion that the image is delayed by a white curtain (A/B test or whatevs), the (unchanged) pessimistic graph should account for it

## brendankenny 2025-11-20T17:34:16Z

I haven't been able to take a look in depth here, sorry, but I'm wondering how much work can be reduced by using the built-in renderBlocking information provided by Chrome now (#2065). @tunetheweb has been looking at Chrome's render blocking signal and preloads, so may have ideas on how suitable it is?

@connorjclark @paulirish looks like `renderBlocking` hasn't been plumbed through to `NetworkRequest` (and that might be difficult if it's only coming through in traces events, not the protocol), but it is in the lantern graph at `networkNode.rawRequest.args.data.renderBlocking`, so is presumably ok to use in the lantern metrics?

## tunetheweb 2025-11-20T18:15:55Z

> @tunetheweb has been looking at Chrome's render blocking signal and preloads, so may have ideas on how suitable it is?

I just [fixed a bug](https://chromium-review.googlesource.com/c/chromium/src/+/7112285) where something like this:

```html
<link rel=preload href=styles.css as=style>
<link rel=stylesheet href=styles.css>
```

Would not upgrade the `styles.css` to render blocking (as the initial request as a preload is not render-blocking). As of Chrome 144 this will correctly be marked as render-blocking.

@jackfranklin made [a similar fix to the trace engine](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/7112841).

We should be careful not to introduce the same bug here, which it sounds like you might be with this change:

> [In `hasRenderBlockingPriority()`,](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/graph/NetworkNode.ts#L85-L92) return `false` for `preload`s/`modulepreload`s

## brendankenny 2025-11-20T18:35:57Z

> [@jackfranklin](https://github.com/jackfranklin) made [a similar fix to the trace engine](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/7112841).

ah nice, then `networkNode.rawRequest` will get that fix, since it's the `SyntheticNetworkRequest` trace event

## iamakulov 2025-11-28T01:43:54Z

> how much work can be reduced by using the built-in renderBlocking information provided by Chrome now

Oh this is great, thank you! <3 Yea let’s use that.

I’m out this week, so I’ll send the PR hopefully next week. Here’s the updated plan (could you sanity-check the second point when you have a moment? 🙏):

> * [In `hasRenderBlockingPriority()`,](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/graph/NetworkNode.ts#L85-L92) return `false` ~for `preload`s/`modulepreload`s~ for all requests with `renderBlocking: false`
>   
>   * This feels safe-ish: those requests are definitely not render-blocking, although there’s probably _some_ reason why they weren’t included into this check before?
> * In [the optimistic LCP algo](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/metrics/LargestContentfulPaint.ts#L50), exclude ~(module)preloads, or perhaps even all scripts~ all requests with `renderBlocking: false` _if_ the image was discovered by the parser and not JS-inserted
>   
>   * This is a BIG change, so I’d love to make sure it passes the smell test. On the surface, it feels reasonable: on most sites, images that are parser-discovered should be visible without JS; and on the rare occasion that the image is delayed by a white curtain (A/B test or whatevs), the (unchanged) pessimistic graph should account for it



## iamakulov 2025-12-15T11:47:02Z

> ah nice, then `networkNode.rawRequest` will get that fix, since it's the `SyntheticNetworkRequest` trace event

Qq: how good/how close to production-ready is `INTERNAL_LANTERN_USE_TRACE` (https://github.com/GoogleChrome/lighthouse/pull/16026)?

I’m noticing that unlike some other audits, FCP/LCP audits build their network graphs from the Chrome DevTools Protocol log, not from the trace. Unlike the trace, the CDP log does not include the `renderBlocking` attribute. We can ofc drill it in the protocol, but the trace already exposes it, and we’ll need to re-implement the same fixes [Lighthouse did earlier](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/7112841), so I’m not sure this is wise. 

Flipping the flag to `true` will allow us to use `renderBlocking` with much less effort.





## connorjclark 2025-12-15T22:16:45Z

> [In hasRenderBlockingPriority(),](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/graph/NetworkNode.ts#L85-L92) return false for preloads/modulepreloads for all requests with renderBlocking: false

SGTM

As you saw with `INTERNAL_LANTERN_USE_TRACE`, this won't yet impact the metric graphs created by Lighthouse – mostly just improved results in the Performance panel insights. I filed #16805 to track the work to make the switch to the trace in Lighthouse's Lantern usages. It's an unknown amount of work - last time I tried to chip away at it, it was pretty slow progress. I think it's close to being an accurate replacement, but the number of differences in tests (even if minor) makes it a hard call to make.

> In [the optimistic LCP algo](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/metrics/LargestContentfulPaint.ts#L50), exclude (module)preloads, or perhaps even all scripts all requests with renderBlocking: false if the image was discovered by the parser and not JS-inserted

One thing I haven't seen mentioned during this discussion is the issue of bandwidth. One reason that the LCP graph included so much was to account for that. For an extreme example, if dozens of non-critical requests are preloaded, that would saturate the network and prevent the actual LCP image request from being delivered as quickly as when there were no preloaded requests. By removing those requests from the LCP graph, we lose that signal and begin to _under_ report the value for a given throttling setting. I suspect this would be closer to the real value than what we're doing today, but it's something we should consider.

____

An extreme alternative solution would be to drop simulated throttling, and use applied throttling. We've long opted not to do that for the reason that developers want / deserve fast results. But it's always been at the cost of accuracy and trust in the results. I wonder if, given the age of AI we find ourselves in (which has proven developers don't mind waiting longer / spending more compute for accurate results), perhaps we should drop simulated throttling. Or at least, change the defaults to use applied/devtools throttling.

Do you have an opinion on that approach?

Although, that might be totally untenable for PSI (wrt cost). cc @paulirish 

## iamakulov 2025-12-15T23:14:37Z

> For an extreme example, if dozens of non-critical requests are preloaded, that would saturate the network and prevent the actual LCP image request from being delivered as quickly as when there were no preloaded requests.

Good one. I guess this is especially the case with PSI which probably has really high bandwidth.

I wonder if maybe _maybe_ maybe this is exactly what [optimistic and pessimistic graphs](https://github.com/ChromeDevTools/devtools-frontend/blob/48e7b166faabd303966361c452f589474fddaeca/front_end/models/trace/lantern/metrics/Metric.ts#L91-L92) are made for? My thinking is: with an optimistic graph, we can assume we’re on a “happy” path: the site is like 80% of other sites and doesn’t do any weird tricks. In the pessimistic graph, we can account for the remaining 20% of cases: sites with white curtains, sites that preload too much and saturate the bandwidth, etc.

Today, the optimistic graph for LCP is [a slightly less pessimistic version](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/metrics/LargestContentfulPaint.ts#L50) of [the pessimistic graph](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/metrics/LargestContentfulPaint.ts#L63-L65). If we make the optimistic graph assume the site is the typical “80%” site – one where only render-blocking nodes block rendering – we’ll make the score closer to reality while still accounting for weirdness via the other graph.

(Happy to do some work to gather some data here if you think we need it, lmk.)

---

> Do you have an opinion on that approach?

Interesting! I don’t think I can make a call on removing simulated throttling. (Although ofc I’m always down for better accuracy.)

My first thought is: could this be a UX problem rather than a technical one? We have a less-precise-but-fast algorithm, and a more-precise-but-slow one. We chose to optimize for speed of getting results, but most people aren’t even aware of the tradeoff.

I could imagine some alternate UXes that are more explicit about this tradeoff:
- **Show the “fast” score, then replace with the “slow” score.** For example, in PSI, we could do [something like this](https://www.tldraw.com/f/6-4aD_OcVaLs4vo5nDyQy?d=v-2099.-1697.6059.3890.page). In DevTools, instead of showing a loader until the test is complete, we can show the simulated results first – and then run an applied throttling test right after.
- **In DevTools, put a “☑︎ Faster but less accurate test” checkbox.** (And uncheck it by default?) Pretty much nobody outside of the web perf community knows what this ↓ select means, and the checkbox will make the tradeoff much more explicit.

  <img width="521" height="139" alt="Image" src="https://github.com/user-attachments/assets/42ea5036-4aec-4244-876b-227278889b0b" />

   

## iamakulov 2025-12-16T00:32:22Z

> [In hasRenderBlockingPriority(),](https://github.com/ChromeDevTools/devtools-frontend/blob/3dafd1404ce2d50cd13f569ee4afa47c65955b8d/front_end/models/trace/lantern/graph/NetworkNode.ts#L85-L92) return false for all requests with `renderBlocking: false`

In the meantime, I prepared a Chromium change for this one: https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/7262577

I’ll take a look at https://github.com/GoogleChrome/lighthouse/issues/16805 tomorrow (🤞), to see if I can resolve it in a day. Waiting for your feedback to proceed further with https://github.com/GoogleChrome/lighthouse/pull/16782 or the optimistic graph change we discussed above.

## iamakulov 2026-01-29T23:00:20Z

Happy new year! I submitted two more changes:

- https://github.com/GoogleChrome/lighthouse/pull/16869 – a sibling PR for the Chromium change above that enables proper render blocking detection in FCP and LCP (without switching to `INTERNAL_LANTERN_USE_TRACE`)
- https://github.com/GoogleChrome/lighthouse/pull/16870 – a surface-level hit for tests broken with `INTERNAL_LANTERN_USE_TRACE`. I didn’t dig into more because pt. 1 ultimately makes it unnecessary

Kind bump re: your opinion on the bigger changes (being more lax with preloads for the optimistic lcp graph) :)

## iamakulov 2026-07-30T19:21:47Z

> An extreme alternative solution would be to drop simulated throttling, and use applied throttling. We've long opted not to do that for the reason that developers want / deserve fast results. But it's always been at the cost of accuracy and trust in the results.

@connorjclark Can I do a 180° [at my earlier response](https://github.com/GoogleChrome/lighthouse/issues/16539#issuecomment-3657992549), actually?

I’ve just been helping someone with performance. They’ve been running the `lighthouse` npm package on their servers, measuring performance of each of their releases. They’ve been seeing a ton of test variance and and generally very poor numbers – and were very confused as to why it doesn’t match what they see in RUM. Could you guess the cause? (It was the simulated throttling mode, which they were using because it’s the default.)

I now think that, yes, removing simulated throttling (or at least making it non-default) would really help other dev teams. As it stands today, I have to tell someone “Don’t use Lighthouse because it reports bad numbers, use WebPageTest” at least once a month, and I really don’t want to do that :(

## EricBCoding 2026-08-23T20:41:10Z

I can reproduce this cleanly on a public, mostly text-first page:

https://sparknight.io/dev-latch/test-post-again

Using Lighthouse 13.4.1 on the same machine, repeated mobile runs produced:

| Throttling | Observed FCP/LCP | Simulated FCP | Simulated LCP | Score |
| --- | --- | --- | --- | --- |
| `simulate` | 426–449 ms, equal in each run | 1.78–1.94 s | 3.10–3.15 s | 92–93 |
| `devtools` | — | — | — | 98–99 |

For comparison, six recent PageSpeed Insights mobile runs against the same URL scored 84–89.

The LCP is text present in the initial HTML. It uses Roboto Flex with `display=swap`; the Google Fonts stylesheets are loaded non-blockingly. Page scripts are deferred, and the only content image is below the fold.

The browser therefore paints FCP and LCP together in under 450 ms, but Lantern turns them into separate events about 1.2–1.4 seconds apart. Merely changing from simulated to applied throttling raises the score by 6–7 points.

This appears to match the narrower case discussed in #16782: a text LCP in the initial HTML, using `font-display: swap`, with observed FCP and LCP in the same frame. It remains reproducible in Lighthouse 13.4.1.


## TiagoGranelli 2026-09-28T22:09:28Z

One more data point for this, from a CI runner rather than a real device: the same build can score 100 or 99 depending on how busy the host CPU is, because of how Lantern ties preloaded scripts to the navigation commit task.

Chrome requests the stylesheet and every `modulepreload` inside the navigation commit task (`DocumentLoader::CommitNavigation` → `HTMLDocumentParser::MaybeFetchQueuedPreloads`), since the whole HTML is already buffered when the renderer commits. Most of that task is creating the page's JS contexts; our 13 KB of HTML takes about 3 ms of it. Lantern drops tasks under 10 ms (`SIGNIFICANT_DUR_THRESHOLD_MS`), but once the task is kept, every script requested inside it waits for it, times the CPU slowdown. The stylesheet isn't linked to it.

On my laptop the task takes 5–10 ms, so it costs nothing and mobile FCP is 1.50 s (score 100). On a GitHub Actions runner (2 vCPUs, also running the app server, Caddy and Postgres) it took 26–68 ms, every preloaded script started 105–270 ms later, and FCP = LCP came out at 1.62–1.79 s (99 on 19 of 20 mobile runs). Same build, byte for byte. Stretching only that task in a saved laptop trace and replaying Lantern gives 1.504 s at 9.9 ms, 1.544 s at 10.1 ms and 1.636 s at 33 ms.

The task length follows how contended the CPU is, which `benchmarkIndex` doesn't measure. With the whole run pinned by `taskset`: 2 fast cores (benchmarkIndex ~4600) gave a 12–22 ms task and 99, 2 slow cores (~2500, the runner's range) 16–31 ms and 99, 4 slow cores 12–19 ms and 99, 8 slow cores 9–10 ms and 100.

So besides the render-blocking question, the preloads make the simulated FCP sensitive to host load in a way the rest of the graph isn't. The planned follow-up to ignore modulepreloads for FCP/LCP would remove this too. The traces and the replay script are available if they're useful.


## iamakulov 2026-10-15T11:27:53Z

Thank you so much @connorjclark!!! Super super hyped for Lighthouse to get much more accurate here.

I’ll see how it affects Framer customers’ feedback once it’s shipped to PSI and report if I still see complaints that are driven by inaccuracies :)


# Closing PR #17307 (merged 2026-10-08), released in v13.6.0 2026-10-27

Roll `@paulirish/trace_engine` from `0.0.65` to `0.0.66` (`845cad7f273...c0884b8bff9`).

https://chromium.googlesource.com/devtools/devtools-frontend.git/+log/845cad7f273..c0884b8bff9

Fixes #17163
Ref #16539
Ref #16805

### Highlights for Lighthouse

- **Legacy JavaScript `0.0.3` — 11–31x Speedup & Updated Polyfill Data** ([CL 8526861](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8526861)):
  - Rolls in the `legacy-javascript` changes from #17299, #17300, #17301, and #17304 (and bundles `third_party/legacy-javascript` directly in `@paulirish/trace_engine`, removing the separate npm dependency).
  - **11–31x faster `detectLegacyJavaScript`** (#17301): Pattern matching and source map lookup optimizations reduce execution time across 465 test bundles (25.7 MB) from 4,370 ms to 172 ms (**25.4x** without source maps) and from 5,375 ms to 259 ms (**20.8x** with source maps), and from 1,375 ms to 44 ms (**31.2x**) on an 8.9 MB `typescript.js` bundle.
  - **Updated `core-js` & Baseline polyfill detection** (#17299, #17304): Regenerated `core-js` signatures and added detection for newly-Baseline polyfills (`Object.hasOwn`, `Array.prototype.at`, `Error.cause`, `structuredClone`, etc.).
  - **Line/column tracking fixes** (#17300): Fixed CRLF and multi-line match line/column tracking.
- **Lantern Accuracy & Trace Parity Improvements**:
  - **Render-blocking priority** ([CL 8508087](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8508087), fixes #16539, #17163; builds on #16869, #17263): `NetworkNode.hasRenderBlockingPriority` now uses the explicit `renderBlocking` status from CDP/trace events (`non_blocking`, `blocking`, `potentially_blocking`, etc.) in addition to priority heuristics, so High-priority `<script type="module">` / `<link rel="modulepreload">` requests are no longer treated as render-blocking. In `sample_v2.json`, this also prevents non-blocking High-priority scripts from remaining in the optimistic FCP graph and masking `render-blocking-insight` FCP metric savings.
  - **Connectionless requests (`data:`, `blob:`, disk cache)** ([CL 8510073](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8510073), #15841): Omitted from active request counts in `Simulator`, preventing them from blocking concurrent network requests or reducing per-connection throughput. Because Chrome does not emit `ResourceSendRequest` trace events for `data:` URLs, this also resolves the `TODO(15841)` `devtoolsLog` vs. `trace` discrepancies in `largest-contentful-paint-test.js` and `lcp-breakdown-test.js`.
  - **HTTP/3 multiplexing** ([CL 8509828](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8509828)): `ConnectionPool` now treats `h3` connections (`h3`, `h3-29`, `h3-Q050`, etc.) as multiplexed alongside `h2`.
  - **ES Module CPU nodes** ([CL 8502697](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8502697)): `PageDependencyGraph` and `CPUNode` now link `v8.compileModule`, `v8.evaluateModule`, and `ModuleEvaluated` trace events to their network requests so module script execution across separate tasks is not dropped from Lantern's dependency graph.
  - **Dependency graph & TBT fixes** ([CL 8512473](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8512473), [CL 8511807](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8511807), [CL 8509826](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8509826)): Fixed an early `return` bug in `PageDependencyGraph.addDependencyOnUrl` (now `continue`), prevented negative `CPUNode` durations when tasks share timestamps, and guarded `interactiveResult` in `TotalBlockingTime.compute`.
- **Soft Navigations Disabled by Default in Lighthouse** ([CL 8023822](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8023822), [CL 7895124](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/7895124)):
  - DevTools added `SoftNavigationsHandler` and `enableSoftNavigation` (default `true` in DevTools) to break down soft navigations into separate insight sets. Lighthouse sets `config.enableSoftNavigation = false` in `trace-engine-result.js` for now.
- **UI Strings & Localization Sweeps** ([CL 8086673](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8086673), [CL 8180384](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8180384), [CL 8364194](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8364194), [CL 8495913](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8495913), [CL 8525488](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8525488)):
  - DevTools performed UX writing sweeps across `models/trace/insights/` and `BackForwardCacheStrings.ts` (curly apostrophes, contractions like `aren’t`/`can’t`/`shouldn’t`, sentence case, and removing trailing periods), plus new `Deprecation.ts` strings.
- **Network Requests Sanitization & Handler Cleanup** ([CL 7942589](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/7942589), [CL 7959034](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/7959034)):
  - `NetworkRequestsHandler` now validates `finalSendRequest` URLs and sanitizes stack trace and redirect URLs against an allowed protocol list (`http:`, `https:`, `blob:`, `file:`, `filesystem:`).
  - Removed `AuctionWorkletsHandler` (Protected Audience removal from DevTools).



# Related issue #11460 (duplicated into #16539)

# font-display:swap fonts shouldn't affect lantern lcp
<https://github.com/GoogleChrome/lighthouse/issues/11460>
created 2020-09-18T20:46:05Z closed 2026-10-08T21:49:47Z

I'm a bit confused about the recommendation `uses-rel-preload` and the resulting `LCP` score. Without font preloading the `LCP` score looks ok and results in a 100 % rating in the performance category:

![grafik](https://user-images.githubusercontent.com/3391958/93643439-50c12280-fa00-11ea-9980-3583a81a7a99.png)

After adding the suggested preloading lines for my fonts the `LCP` increased a lot and the performance rating goes down to 80 %:

![grafik](https://user-images.githubusercontent.com/3391958/93643534-7bab7680-fa00-11ea-9a2c-0742b06ee6e0.png)

The preloading lines I use looks like this:

```
<link rel="preload" as="font" href="/fonts/Metropolis.woff2" type="font/woff2" crossorigin="anonymous">
<link rel="preload" as="font" href="/fonts/LiberationSans.woff2" type="font/woff2" crossorigin="anonymous">
<link rel="preload" as="font" href="/fonts/LiberationSans-Bold.woff2" type="font/woff2" crossorigin="anonymous">
<link rel="preload" as="font" href="/fonts/LiberationSans-BoldItalic.woff2" type="font/woff2" crossorigin="anonymous">
<link rel="preload" as="font" href="/fonts/LiberationSans-Italic.woff2" type="font/woff2" crossorigin="anonymous">
<link rel="preload" as="font" href="/fonts/LiberationMono.woff2" type="font/woff2" crossorigin="anonymous">
<link rel="preload" as="font" href="/fonts/DroidSans.woff2" type="font/woff2" crossorigin="anonymous">
```
What am I doing wrong? Any way to get preloading and the `LCP` together? Thanks a lot for your help. 

 

## patrickhulce 2020-09-18T21:30:53Z

Thanks for filing @xoxys! Is this page deployed on the internet anywhere for us to take a look? I have a hunch about what's going on, but we need a page to be able to look into it :)

## xoxys 2020-09-18T21:34:03Z

Not right  now :) would you need it with the preloads enabled?

## patrickhulce 2020-09-18T21:41:22Z

> would you need it with the preloads enabled?

Ideally we could have both versions available at the same time to directly compare, but the one with the preloads enabled is the more important of the two to hunt down the (likely) bug.

## xoxys 2020-09-18T21:57:38Z

Ok, here you go:
https://preload-on.geekdocs.de/
https://preload-off.geekdocs.de/

Let me know when you need something else

## patrickhulce 2020-09-18T22:30:16Z

Thanks very much for those @xoxys! I'm having trouble reproducing the low performance on the preload one though :/

![image](https://user-images.githubusercontent.com/2301202/93650582-7e907200-f9d4-11ea-9cc8-233438bcf1d3.png)

Any extra settings, environment information, etc that might help?

## xoxys 2020-09-19T10:04:21Z

Ok now it is getting more complicated :) So I see this behavior while testing on localhost and I'm using the following config:

```
---
ci:
  collect:
    numberOfRuns: 3
    staticDistDir: exampleSite/public
    url:
      - http://localhost/
      - http://localhost/404.html
      - http://localhost/posts/
    settings:
      chromeFlags: "--no-sandbox"
  assert:
    preset: "lighthouse:no-pwa"
    assertions:
      uses-long-cache-ttl: off
      tap-targets: warn
      unsized-images: warn
      categories:performance:
        - error
        - minScore: 0.95
      categories:accessibility:
        - error
        - minScore: 1
      categories:seo:
        - error
        - minScore: 0.95
  upload:
    target: filesystem
    outputDir: lhci_reports
```

If you want to test it locally as well you could download the whole source code (pre-build and working) from the S3 backend which is serving the demo site. https://sp.rknet.org/minio/geekdocs/ (there should be a download button behind the preload-on and preload-off folder). I could also provide a tarball here if that works better for you :)


## xoxys 2020-09-19T10:16:31Z

Oh maybe I should have mentioned that I use `lhci`. Now I am not sure if I opened the issue in the right repo... But I thought this was more of a core problem.

## patrickhulce 2020-09-19T13:06:48Z

You're all good you actually filed in LHCI @xoxys but I moved the issue to the core repo because any issue computing the performance metrics won't be LHCI specific :)

I can repro locally now thanks for the download link 👍 

This is a bug in simulated throttling. Basically the preloaded fonts now load before LCP and Lighthouse includes them in our pessimistic estimate of LCP. It only happens on localhost because they load *so* fast that Chrome doesn't even have a chance to get a paint out. When the page is hosted somewhere remotely we see the expected behavior. 

As a temporary workaround you can use
```yaml
ci:
  collect:
    settings:
      throttlingMethod: devtools
```

but either way it's not a real problem with the performance of the page.

To the Lighthouse team, I think it's time to finally include more than just trace/devtools information in our lantern graph creation. These fonts are all display `swap` and we shouldn't be including them in the LCP calculation.

## xoxys 2020-09-19T13:28:47Z

Wow, many thanks for your help! To be honest the workaround does not really work for me. With `devtools` enabled the results changed to 
![grafik](https://user-images.githubusercontent.com/3391958/93668562-51ec6100-fa8d-11ea-9743-178ca2a8c66d.png)
instead of 
![grafik](https://user-images.githubusercontent.com/3391958/93668487-d2f72880-fa8c-11ea-9544-41d71967510f.png)

This does not really make it better and is not comparable to the results without font preloading :)

## xoxys 2021-02-07T13:01:34Z

Is there any update so far?

## patrickhulce 2021-02-07T15:11:58Z

No, changes to lantern like this requires are large investments and are only shipped with major versions. There is no immediate plan to tackle this.

## paulirish 2021-12-14T21:12:27Z

We've since "disabled" the preload audit for other, but related reasons. I'll leave this issue open to track patrick's suggestion:

> To the Lighthouse team, I think it's time to finally include more than just trace/devtools information in our lantern graph creation. These fonts are all `font-display: swap` and we shouldn't be including them in the LCP calculation.

## paulirish 2022-01-10T22:22:19Z

We believe this may only affect localhost.. generally a swap font will have deferred network requests.. but in localhost.. all requests are so fast it happens prior to LCP.
Assuming that is the case, this is lower priority. Localhost will always have very optimistic and unrealistic perf. It's something we can try to account for, but we're limited..

## siakaramalegos 2025-03-25T18:37:10Z

FYI I think I'm having this issue on my website in production, not in dev. Right now, I've commented out my preloads. Site is https://sia.codes/

With any preload - score is 80. With no preloads - score is 100. LCP is paragraph text and extremely fast in real life. Throttling device and network yields 1.0-1.4s LCP. Lighthouse for some reason waits several seconds to render.

## connorjclark 2026-10-08T21:49:48Z

duping into #16539 (and related issue #15737)

Gemini:

#16539 covers this exact behavior in detail: when `font-display: swap` fonts or other non-blocking preloaded assets finish before observed LCP in the unthrottled pass, Lantern includes them in the LCP dependency graph and shares simulated bandwidth across them, inflating simulated LCP. Follow #16539 for progress on the fix.


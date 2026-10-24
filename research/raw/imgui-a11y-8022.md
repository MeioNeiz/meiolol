# Feature request: Implement accessibility features?
author: juanreina921 2024-09-27T16:47:07Z OPEN

### Version/Branch of Dear ImGui:

not applicable to current situation

### Back-ends:

not applicable to current situation

### Compiler, OS:

not applicable to current situation

### Full config/build information:

not applicable to current situation

### Details:

**My Issue/Question:**
ImGui has no current implementation of accessibility for Asistive software, but there is a way for an implementation to have such support. 
XXX _(please provide as much context as possible)_

hello there!

This issue, as the title states, is about the lack of accessibility support in imgui, especially since this will become increasingly important soon enough. This will also present a convenient solution to making imgui have accessibility support, for windows, linux and mac OS, all at once, with minimal effort on your part. But before we get to that, some background and terminology explanation is required, because last time this was discussed, #4122, people were confused, rightly, by most of what was talked about in there, so it's my turn to attempt to make it right

## background

For a very long time now, I have been passionate about the chiptune scene. However, the only thing I could do is archive people's chiptune, but that I did a lot of, and I like to think that I did it well too. The problem is that I wanted to do more at some point, to give back to the community in the only way I know how, by making something. However, in this scene, a lot of UI is written with imgui, because imediate mode ui is generally better than regular retained mode UI, such as gtk for example. So then, I was trying to talk to people about making that software accessible to us too, and corroborating multiple such instances together, this is how such a conversation typically sounds like:

- me: hello there, I'm a blind person who uses a screenreader, *insert details about how screenreaders work here*. Could you perhaps help me make this accessible, for me and my people? currently, nothing at all reads, it looks like a blank window, a black canvass
- person at the other end: ahem, what's that more exactly/sure, let's see what's possible. A long discussion usually follows, about how accessibility is typically implemented, more on that below
- person goes and actually tryes to implement some accessibility in the app, in whatever way they think it should work. It generally doesn't work at all, or is just exploratory and it's abandoned, because
- person: there are no accessibility API's here, I can't subclass or annotate anything like in qt or gtk, and not even native controls are accessible. Nothing of what you told me applies, and not even self-voicing it with tts would work that well, because events are slightly unpredictable with keyboard navigation
- me, inwardly prepairing for an unfavourable answer and kinda knowing what's coming: what ui is this written in?
- person: imgui
- me: a long, long pause, followed by lots of disappointment

This has happened a couple times already, and not only with trackers either. An mml editor is written in imgui, so are some other products, such as some hex editors, which could be useful in some scenarios, music players, you name it, it's probably there.

What I'm trying to get at here is that more and more people are adopting imgui, because as I said above, imediate mode ui does allow one to make applications much quicker, however this does leave a lot of people behind. And not before long, there will be stronger accessibility related laws in the EU and beyond, at which point concerned people might open more issues about this, and there's very little you could actually have done in the past to fix this problem.

That's why I'm opening this now, I want what's best for everyone involved, our community and a lot of people using accessibility tools in general, the consumers of your library because they don't want to have such a risk of legal issues in the future, if they don't already, you because you won't have to deal with absolutely no accessibility on your against imgui list, and such a label would be damaging in the near future, if it's not already. 

We don't know how many people didn't use imgui, even if it would have made their lives easier, just because it doesn't have accessibility. It's not just about having the issue yourself either, it's about human decency and empathy, and for example, there's a lot of that in the fediverse, a lot of people from there won't touch a product or library, on the basis of pure principle alone, if it has known hard showstoppers when it comes to accessibility, the same way a lot of people from there don't boost images if they don't have alt text, from principle.

alright, you heard the term screenreader a lot up to now, I'll try to properly explain that, as well as how it actually works. Hint, not like someone thought in that issue:

## what's a screenreader anyway?

In the simplest terms, a screenreader is a piece of software which uses diverse output and input methods to convey to a visually impaired person what's happening on their computer. Output methods could be speakers, headphones, braille displays, vibration engines inside controllers perhaps, while inputs could be the keyboard, the touchscreen, etc, which then pass through the screenreader and get slightly modified, for example we have screenreader specific shortcuts which give us even more information about where we are on the desktop, or the touchscreen gestures, such as flicking a finger to the right to go to the next item, or double tapping anywhere on the screen to click a focused object

Did you notice that in that entire definition, I didn't mention the screen or reading it at all? well, that's because a screenreader...doesn't actually read the screen! What it reads, we call this semantic information, enough of that combined and you got what we call an accessibility tree.

An accessibility tree is essentially a hierarchy of components, which logically represents your application. For example, at the root, you may have your window, which has afew properties, such as it's role of window, its bounding box, the location of the top-left corner of the bounding box, the title if any, etc. Underneath that, you have your regular buttons, checkboxes, etc, those also have the same properties as a window, but their role is button or checkbox, they have a state, aka clicked or focused, they have a text or label associated to them, etc. Those we call the leaf nodes, because there's nothing under them, but for example, you could group some of those under a pannel, which then would be a node with however many children, etc. See? this isn't very hard, and it's also how web browsers work, your browser's DOM does that kind of transformation, because javascript has to act on the information you see on your screen in some way, and that kind of design does help with that. Firefox's or chrome's accessibility inspectors could help a lot in understanding this

Now that you know all that information, you may be asking, what would a screenreader see if imgui doesn't support sending those virtual node objects to a virtual channel? Well, nothing, and by that, I mean absolutely nothing, a blank spot on the desktop.

Alright, so how would this be fixed, how was it fixed in the past, surely other people faced this? The way it was done before was horrible and inefficient, and now there's a new way which is a lot better, both of those will be discussed in the following

## OS native accessibility, the past and the future

Before recently, the only possible options for making stuff accessible were:

- write it in a toolkit which supports accessibility, gtk, qt, electron, etc are all good options
- implement the accessibility logic yourself, which is undesirable because it's platform-specific and tedious besides
- use text to speech solutions to essentially self-voice every control in your toolkit, making more or less a screenreader inside every app using it. That's also not recommended, because that requires a high level of maintenance, especially when it comes to lots of different ways to access information that the screenreader natively provides, which you would have to duplicate, and at some point, it becomes more complicated than an actual screenreader

So then, a new option appeared relatively recently, it's called accesskit, which I believe would be awesome for integrating with imgui, and since it was specifically made for imediate mode UI, it would be perfect for that. Here's what I know about access kit, all good reasons for which adding it should be considered

- it's cross-platform, working with all platforms it supports behind the adaptor abstraction. This only works with windows, mac OS and linux, but that's very important as well, even ifimgui supports android and such too, plus you'll get accessibility support for those the moment access kit adds them, with minimal disturbance to your existing code
- its architecture is based on imediate UI paradigms, which means you provide it with tree diffs of what changed between the current frame and the previous one, not unlike what you already do with rendering, and it figures out the rest in such a way that it just works with all supported screenreaders and operating systems. This is huge, this means that accessibility is coupled with the visual part of the screen more than ever before, which can fix so many of the existing weird little timing bugs and so on which were present in other UI libraries, because the coupling is much better now. Furthermore, you don't need to keep ui state, no more than what you already tell the user to write, aka in relation to what control is that one, you provide it also when a node should have focus, according to whatever heuristics you have, in that tree diff, same for other actions the screenreader asks to do, and then you react to those as if they were done by the mouse. That's that, for most of your native controls, you only have to stick an extra field in there with the accesskit node that represents, then manipulate your internal state according to what action the screenreader asks. I know it's not that simple, but it's definitely much better than even a year ago, when you had to do stuff like the above, definitely not fun
- it's written in rust, so less memory management issues over all, plus a relatively simpler dependency chain if you just take it vendored like that, though you can also actually integrate it with sources and all. Most important though, it has C bindings, which means it would integrate nicely with imgui. I know, you probably have to wrap it for better c++ usage, but in general it's pretty straight-forward for what it does
- because the screenreader sees that as native ui, the user can read it in the way they configured their screenreader for the rest of the system, which is incredibly useful for people with braille displays or other esoteric forms of output and input
- since the accessibility is OS native, other tools which make use of that would be able to support the user more, for example zoom which uses focus and such, input methods for languages like japanese and chinese, possibly right to left languages as well if there are input methods for that, etc
- some projects which embedded accesskit, as you'll find on its website are: egui, which is a rust alternative to imgui, slint which is another imediate mode UI for rust, as well as possibly others I forgot. So yes, there's prior art, and although the implementation is a bit wonky at the moment, it's better than nothing by miles
- because it manages only the accessibility layer, focus and such stuff is still on you, so you can still use the existing infrastructure to make it work. Furthermore, our screenreaders have something called object navigation, where we can inspect the accessibility tree without moving focus, so we could go, if absolutely needed, in places which aren't reachable by the keyboard. So, as I said, win win for everyone

Finally, the relevant links:

- accesskit website: https://accesskit.dev/
- C bindings, including an example accessible application, which uses sdl to manage focus and such, for a dummy application which is invisible to everything but the accessibility infrastructure: https://github.com/AccessKit/accesskit-c
- python bindings: https://pypi.org/project/accesskit/

So, what do y'all think? could this be revisited again, now that there's a universal framework to make this kind of UI accessible? I really hope so, and would be glad to do the testing to make sure it works, at least on windows, and I know people who can test on linux too.

### Screenshots/Video:

Video of a demo using Furnace; a tracker software using ImGUI for it's UI. 
https://drive.google.com/file/d/18PyGNQp0SeoIT5y96Xipm_9uX-IOhLOV/view?usp=sharing

### Minimal, Complete and Verifiable Example code:

_No response_

## comment by still-standing88 2025-01-02T10:38:36Z (NONE)

Were any attempts made towards implementing this? Or is it just sitting idle.

## comment by ocornut 2025-01-02T11:08:07Z (OWNER)

Happy new year everyone :) I am sorry I haven’t yet been able to reply to @juanreina921 thoughtful message about this. As you noticed it is sitting idle much like many other requests for dear imgui. There’s just presently so much to handle and do. I am presently working on an unrelated big feature and I intend to try to tackle many big features this year, but I am yet unsure if this in particular will be something I can even consider tackling short or mid term. I’m doing my best but I am unfortunately not in a position to promise anything. 

## comment by DataTriny 2025-01-11T13:31:27Z (NONE)

Hi @ocornut,

FYI there is an older and similar issue for this #5833. Its description is not as detailed as this one though, so maybe you should only keep this one open?


## comment by learn-more 2025-04-16T22:19:11Z (CONTRIBUTOR)

The [Xbox GDK Samples](https://github.com/microsoft/Xbox-GDK-Samples) repository contains a sample application that uses Dear ImGui to demonstrate accessibility features:
https://github.com/microsoft/Xbox-GDK-Samples/tree/main/Samples/System/AccessibilitySample

It might be a useful reference for some concepts?

![Image](https://github.com/user-attachments/assets/b8bdbd5f-d8d2-423e-b3b3-bb704e7d01cd)



## comment by mwestphal 2025-06-29T11:56:20Z (NONE)

I want to mention that the F3D maintainers would love this to be supported and be happy to test any prototype of this.

## comment by ocornut 2026-04-28T13:49:17Z (OWNER)

Some thoughts:

> The [Xbox GDK Samples](https://github.com/microsoft/Xbox-GDK-Samples) repository contains a sample application that uses Dear ImGui to demonstrate accessibility features:
https://github.com/microsoft/Xbox-GDK-Samples/tree/main/Samples/System/AccessibilitySample
It might be a useful reference for some concepts?

Yes. Skimming at the code and notably at:
https://github.com/microsoft/Xbox-GDK-Samples/blob/main/Samples/System/AccessibilitySample/ImGuiAcc.cpp

This seems like a proof of concept but gives a basic outine of the needed things:
- Narrate focus change with the Item label.
- Narrate activation / changes with the Item label.
- Wrap InputText() via XGameUiTextEntryGetState() and narrate changes.
- Narrate window focus changes.

Other than that:
- They tend to use high contrast colors + increase/adjust spacing etc. but that can be done app side without modifying the library.

Adding basic __narration__ support is technically possible in Dear ImGui (there's no hard problem to solve, and it's all behaving on triggers so wouldn't hinder performance). My concern and main question:
- I feel it would be decently easy to get 80% narration working, but extremely difficult if not impossible to get it 90-100%. There are all kinds of edge cases and tricks used by advanced applications. The simplest being to display labels separately from actual interactive widget, where from Dear ImGui POV they are two unrelated things and would essentially break narration.
- So the TL;DR; is that it would work for applications intently designed to careful about narration, but probably not for others.
- I'm very concerned about providing a 80% solution while knowing that getting to 99% is going to be extremely unlikely if not possible. It seems misleading to me. 

Generally speaking, the data and improvements required for narration would align well with code for:
- Supporting text selection anywhere.
- Improving the LogXXX api. The LogXXX API is mostly unchanged since 1.0 (!) and suffer from a few flaws, but it's still very useful. Note how you can set e.g. `io.ConfigWindowsCopyContentsWithCtrlC = true` to automatically have CTRL+C put textual window of the window into the clipboard.

<img width="575" height="400" alt="Image" src="https://github.com/user-attachments/assets/d16f2287-7198-4364-97e3-27941b1f97b1" />

Press Ctrl+C and get in clipboard:
```
Hello, world!
This is some useful text.
[x] Demo Window
[ ] Another Window
{ 0.000 } float
{ 115 } { 140 } { 153 } clear color
[ Button ] counter = 0
Application average 16.669 ms/frame (60.0 FPS)
```
While I don't claim this is a replacement for narration, you can easily tell that it relies on similar concepts and data.
One of the flaw of the LogXXX api is that it processes data in submission order rather than spatial order, so some UI might break. Finding a solution to the general "be able to select any text" will likely also solve that problem, and we can imagine the 3 issues could simultaneously benefit.

I believe the accessibility sample would be better reworked by:
- Moving all the spacing/padding stuff to style.
- Removing all the ImGuiAcc:: trampoline Widgets, and hacking narration directly as a fork of Dear ImGui. If well designed, the fork would mostly consist of small additions to core and widgets, and therefore be easy to maintain/update.
- The `IMGUI_TEST_ENGINE_ITEM_INFO()` macro used by Test Engine is designed to access similar data and there's probably a path to do the same for narration.



## comment by albertotirla 2026-05-11T19:57:55Z (NONE)

hello there!

I was sent this issue because I have some accessibility experience, and as such, I want to clarify some things. I will quote parts from @ocornut's last comment whenever appropriate.

From reading the original poster's comment, I'm seeing that this path of conversation was anticipated, and a bunch of good arguments were given against narration as a means to making apps accessible. But essentially, the issue is that you would end up implementing your own screenreader on top of imgui, which is going to make your work that much harder. Yes, this is enough for the xbox people, because game UI isn't necessarily that complicated, the console screenreader is likewise relatively simple, you don't have the advanced screenreader features you have, and need, on desktops. Even for desktop games, this might, possibly, be enough depending on the game, because games don't have complex enough UI, but for regular applications, this model falls hard. To see how difficult a basic implementation of this that's also usable could be, look at the kodi screenreader addon, you'd have to do something similar.

> I feel it would be decently easy to get 80% narration working, but extremely difficult if not impossible to get it 90-100%. There are all kinds of edge cases and tricks used by advanced applications. The simplest being to display labels separately from actual interactive widget, where from Dear ImGui POV they are two unrelated things and would essentially break narration.

This is only one of the issues, but a significant one. The user may use their own tts inside their screenreader, configured with their preferred speech rate, pitch, volume and voice variant. If you implement narration without the screenreader's help, you'll stand out from the rest of the user's system, like the user's theme being set to dark but then your app appeared on screen, blazingly white, shining bright. If you do it by using the screenreader as a tts system, that may work, but that's a lot of platform-specific things you have to do for one, and for another, you'd still have to implement all the semantic stuff from basic principles, string interpolation, and make it sound like the actual screenreader as much as possible. Furthermore, XGameUiTextEntryGetState is probably not available on anything but the xbox, so outside that, text entry in an accessible way will not work, meanwhile with accesskit you get the support cross-platform, at least across windows, linux and macos, dk if accesskit supports android, my information might be out of date there. So yeah, I feel that the easy part you're referring to is more like 60 to 70%, not 80%, because implementing those interfaces in such a way that it'll feel like I'm using an actual screenreader while I use the app is very hard, and small differences can add up to such a degree that one would have to learn to deal with the quirks apart from anything else one uses, for example gtk or qt applications. And also, it would be copying engineering effort which already exists in accesskit, having to go through all the mistakes accesskit did, but not in a reusable way because your effort would be targeting a different medium, pure tts narration instead of exposing a semantics tree other accessibility tools can use.

The labeling of fields problem can be solved by semantic notation, where you're using accesskit to annotate not only controls, but relationships between them, for example an edit box can be annotated with the labeled_by relationship, using the label object as a target, and the screenreader would know what that means. Furthermore, accesskit has been made with immediate mode UI in mind, which will make implementation significantly easier

> So the TL;DR; is that it would work for applications intently designed to careful about narration, but probably not for others.

Yes, in part that, and in part applications which are simple enough to use narration instead of requiring a screenreader's more advanced features. As I said above, a game's UI will probably benefit from narration because there you don't need selection, object navigation, keyboard shortcuts specifically for screenreader navigation and stuff like that, but more serious applications do. 

> Supporting text selection anywhere.

Well, I dk if the adapters for accesskit expose events you can hook into to see when the assistive tool expects text selection, but if it does, selecting text in an edit box, for example, may be doable. Otherwise, the tree and semantics structure you build for accessibility with accesskit will definitely help trying to serialize the contents of the tree to any form, the clipboard in this case, because you have more granular, retained mode like, access to a tree structure from your immediate mode UI library.

## comment by DataTriny 2026-05-11T20:38:35Z (NONE)

FWIW AccessKit supports Android and I just published the first version of our iOS backend.

We also recently added the concept of subtrees in our data schema. It is designed to let independant accessibility producers like ImGUI provide a part of the accessibility tree that can be merged into the greater tree of the host application. This is especially useful in games that might display an ImGUI UI ontop of the game scene.

## comment by ethindp 2026-05-13T01:45:22Z (NONE)

I am quite curious as to whether this is feasible. My current understanding is that it is not as AccessKit requires maintaining state somewhere and ImGui is inherently stateless. That said, my information could be significantly out of date.

The thing we should strive for -- if we do take this route -- is to ensure that accessibility is an automatic thing; a consumer of the library should not need to opt-in to the functionality because people will then forget to do it and it only shifts the burden instead of resolving it outright. I am personally against allowing opt-out, for a similar reason: people will do it in the name of "binary size" and similar and thereby exclude a significant amount of users for no reason.

I'd definitely be happy to help wherever possible. I'm not the developer of any accessibility framework but am instead the dev of [Prism](https://github.com/ethindp/prism) so I hope I can provide valuable feedback as both a developer and blind computer user.

## comment by jacobfriedman 2026-09-24T12:00:17Z (NONE)

+1 for making accessibility mandatory. @ocornut this lift is worthwhile


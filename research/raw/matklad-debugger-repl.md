# A Debugger is a REPL is a Debugger

<https://matklad.github.io/2025/03/25/debugger-is-repl-is-debugger.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# A Debugger is a REPL is a Debugger

Mar 25, 2025

I _love_ debuggers! The last time I used a debugger seriously was in 2017 or so, when I was still coding in Kotlin. I’ve since switched to working with native code, and, sadly gdb and lldb are of almost no help for me. This is because they are mere “debuggers”, but what I need is a REPL, and a debugger, all in one. In this article I show a more productive way to use debuggers as REPLS.

The trick boils down to two IntelliJ IDEA features, **Run to Cursor** and **Quick Evaluate Expression**.

The first feature, run to cursor, resumes the program until it reaches the line where the cursor is at. It is a declarative alternative to the primitive debugger features for stepping into, over, and out — rather telling the debugger how to do every single step, you just directly tell it where do you want to be:

The second feature, quick evaluate expression, evaluates selected test in the context of the current stack frame. Crucially, this needn’t be some pre-existing expression, you can type new stuff and evaluate it!

Run to cursor sets up the interesting context, and quick evaluate allows you to poke around. This two features completely change how I used debuggers — instead of stepping through my program and observing it, I zap between interesting points of its execution and run experiments.

Authors of debuggers & REPLs, take note of these features of the workflow:

There’s no prompt anywhere. The medium of interaction is the 2D program text, not 1D command _line_. Its a vi interface, not ed interface.

From the debugger side, we support seamless evaluation of _new_ program text in context. When entering new text, you get full code completion experience. I haven’t used this a tonne, but it should also be possible to _reload_ code with your changes.

From the REPL side, you need breakpoints. Top-level context is rarely interesting! You need to be able to place yourself “in the middle” of your application, where you have access to all the locals. Debuggers do this via setting breakpoints, but the click-on-the-fringe (or, worse, enter `file:line:column` textually) UI is atrocious. There’s a perfectly fine pointing device in any editor — the cursor. Just get the program execution to that point!

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2025-03-25-debugger-is-repl-is-debugger.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)

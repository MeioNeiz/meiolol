# Embracing the parallel coding agent lifestyle

<https://simonwillison.net/2025/Oct/5/parallel-coding-agents/>

# [Simon Willison’s Weblog](https://simonwillison.net/)

[Newsletter](https://simonwillison.net/newsletters/)

**Sponsored by:** Greptile — Your code reviewer uses Computer Use to catch bugs by opening your app and clicking through it. Now you can configure its test environment and define the key user journeys it tests. [Try it for free](https://10xn.link/sw-greptile)

## Embracing the parallel coding agent lifestyle

For a while now I’ve been hearing from engineers who run multiple coding agents at once—firing up several Claude Code or Codex CLI instances at the same time, sometimes in the same repo, sometimes against multiple checkouts or [git worktrees](https://docs.claude.com/en/docs/claude-code/common-workflows#run-parallel-claude-code-sessions-with-git-worktrees).

I was pretty skeptical about this at first. AI-generated code needs to be reviewed, which means the natural bottleneck on all of this is how fast I can review the results. It’s tough keeping up with just a single LLM given how fast they can churn things out, where’s the benefit from running more than one at a time if it just leaves me further behind?

Despite my misgivings, over the past few weeks I’ve noticed myself quietly starting to embrace the parallel coding agent lifestyle.

I can only focus on reviewing and landing one significant change at a time, but I’m finding an increasing number of tasks that can still be fired off in parallel without adding too much cognitive overhead to my primary work.

Here are some patterns I’ve found for applying parallel agents effectively.

#### Research for proof of concepts [#](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/#research-poc)

The first category of tasks I’ve been applying this pattern to is **research**.

Research tasks answer questions or provide recommendations without making modifications to a project that you plan to keep.

A lot of software projects start with a proof of concept. Can [Yjs](https://yjs.dev/) be used to implement a simple collaborative note writing tool with a Python backend? The [libraries exist](https://github.com/y-crdt/pycrdt), but do they work when you wire them together?

Today’s coding agents can build a proof of concept with new libraries and resolve those kinds of basic questions. Libraries too new to be in the training data? Doesn’t matter: tell them to checkout the repos for those new dependencies and read the code to figure out how to use them.

#### How does that work again? [#](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/#how-does-that-work-again)

If you need a reminder about how a portion of your existing system works, modern “reasoning” LLMs can provide a detailed, actionable answer in just a minute or two.

It doesn’t matter how large your codebase is: coding agents are extremely effective with tools like grep and can follow codepaths through dozens of different files if they need to.

Ask them to make notes on where your signed cookies are set and read, or how your application uses subprocesses and threads, or which aspects of your JSON API aren’t yet covered by your documentation.

These LLM-generated explanations are worth stashing away somewhere, because they can make excellent context to paste into further prompts in the future.

#### Small maintenance tasks [#](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/#small-maintenance-tasks)

Now we’re moving on to code edits that we intend to keep, albeit with _very_ low-stakes. It turns out there are a lot of problems that really just require a little bit of extra cognitive overhead which can be outsourced to a bot.

Warnings are a great example. Is your test suite spitting out a warning that something you are using is deprecated? Chuck that at a bot—tell it to run the test suite and figure out how to fix the warning. No need to take a break from what you’re doing to resolve minor irritations like that.

There is a definite knack to spotting opportunities like this. As always, the best way to develop that instinct is to try things—any small maintenance task is something that’s worth trying with a coding agent. You can learn from both their successes _and_ their failures.

#### Carefully specified and directed actual work [#](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/#carefully-specified-and-directed-actual-work)

Reviewing code that lands on your desk out of nowhere is a _lot_ of work. First you have to derive the goals of the new implementation: what’s it trying to achieve? Is this something the project needs? Is the approach taken the best for this current project, given other future planned changes? A lot of big questions before you can even start digging into the details of the code.

Code that started from your own specification is a lot less effort to review. If you already decided what to solve, picked the approach and worked out a detailed specification for the work itself, confirming it was built to your needs can take a lot less time.

I described my [more authoritarian approach](https://simonwillison.net/2025/Mar/11/using-llms-for-code/#tell-them-exactly-what-to-do) to prompting models for code back in March. If I tell them _exactly_ how to build something the work needed to review the resulting changes is a whole lot less taxing.

#### How I’m using these tools today [#](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/#how-i-m-using-these-tools-today)

My daily drivers are currently [Claude Code](https://www.claude.com/product/claude-code) (on Sonnet 4.5), [Codex CLI](https://github.com/openai/codex) (on GPT-5-Codex), and [Codex Cloud](https://chatgpt.com/codex) (for asynchronous tasks, frequently launched from my phone.)

I’m also dabbling with [GitHub Copilot Coding Agent](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent) (the agent baked into the [GitHub.com](https://github.com/) web interface in various places) and [Google Jules](https://jules.google/), Google’s currently-free alternative to Codex Cloud.

I’m still settling into patterns that work for me. I imagine I’ll be iterating on my processes for a long time to come, especially as the landscape of coding agents continues to evolve.

I frequently have multiple terminal windows open running different coding agents in different directories. These are currently a mixture of Claude Code and Codex CLI, running in [YOLO mode](https://simonwillison.net/2025/Sep/30/designing-agentic-loops/#the-joy-of-yolo-mode) (no approvals) for tasks where I’m confident malicious instructions can’t sneak into the context.

(I need to start habitually running my local agents in Docker containers to further limit the blast radius if something goes wrong.)

I haven’t adopted git worktrees yet: if I want to run two agents in isolation against the same repo I do a fresh checkout, often into `/tmp`.

For riskier tasks I’m currently using asynchronous coding agents—usually Codex Cloud—so if anything goes wrong the worst that can happen is my source code getting leaked (since [I allow it to have network access](https://simonwillison.net/2025/Jun/3/codex-agent-internet-access/) while running). Most of what I work on is open source anyway so that’s not a big concern for me.

I occasionally use [GitHub Codespaces](https://github.com/features/codespaces) to run VS Code’s agent mode, which is surprisingly effective and runs directly in my browser. This is particularly great for workshops and demos since it works for anyone with GitHub account, no extra API key necessary.

#### Please share your patterns that work [#](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/#please-share-your-patterns-that-work)

This category of coding agent software is still really new, and the models have only really got good enough to drive them effectively in the past few months—Claude 4 and GPT-5 in particular.

I plan to write more as I figure out the ways of using them that are most effective. I encourage other practitioners to do the same!

#### Recommended reading [#](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/#recommended-reading)

Jesse Vincent wrote [How I’m using coding agents in September, 2025](https://blog.fsck.com/2025/10/05/how-im-using-coding-agents-in-september-2025/) which describes his workflow for parallel agents in detail, including having an architect agent iterate on a plan which is then reviewed and implemented by fresh instances of Claude Code.

In [The 7 Prompting Habits of Highly Effective Engineers](https://sketch.dev/blog/seven-prompting-habits) Josh Bleecher Snyder describes several patterns for this kind of work. I particularly like this one:

> **Send out a scout**. Hand the AI agent a task just to find out where the sticky bits are, so you don’t have to make those mistakes.

I’ve tried this a few times with good results: give the agent a genuinely difficult task against a large codebase, with no intention of actually landing its code, just to get ideas from which files it modifies and how it approaches the problem.

Peter Steinberger’s [Just Talk To It—the no-bs Way of Agentic Engineering](https://steipete.me/posts/just-talk-to-it) provides a very detailed description of his current process built around Codex CLI.

Posted [5th October 2025](https://simonwillison.net/2025/Oct/5/) at 12:06 pm · Follow me on [Mastodon](https://fedi.simonwillison.net/@simon), [Bluesky](https://bsky.app/profile/simonwillison.net), [Twitter](https://twitter.com/simonw) or [subscribe to my newsletter](https://simonwillison.net/about/#subscribe)

## More recent articles

-   [Qwen 3.8 27B on my laptop can interpret model weights, too](https://simonwillison.net/2026/Nov/3/qwen-can-interpret-model-weights/) - 3rd November 2026
-   [The U.S. Census Bureau and “Super Intelligence”](https://simonwillison.net/2026/Nov/2/census-bureau-super-intelligence/) - 2nd November 2026
-   [The October inflection point for vibe game development](https://simonwillison.net/2026/Oct/28/vibe-game-development/) - 28th October 2026
-   [Battle Drones - a vibe coded RTS with audio-based multiplayer](https://simonwillison.net/2026/Oct/20/battledrones/) - 20th October 2026

This is **Embracing the parallel coding agent lifestyle** by Simon Willison, posted on [5th October 2025](https://simonwillison.net/2025/Oct/5/).

Part of series **[How I use LLMs and ChatGPT](https://simonwillison.net/series/using-llms/)**

28.  [I really don't like ChatGPT's new memory dossier](https://simonwillison.net/2025/May/21/chatgpt-new-memory/) - May 21, 2025, 2:38 p.m.
29.  [Tips on prompting ChatGPT for UK technology secretary Peter Kyle](https://simonwillison.net/2025/Jun/3/tips-for-peter-kyle/) - June 3, 2025, 7:08 p.m.
30.  [Designing agentic loops](https://simonwillison.net/2025/Sep/30/designing-agentic-loops/) - Sept. 30, 2025, 3:20 p.m.
31.  **Embracing the parallel coding agent lifestyle** - Oct. 5, 2025, 12:06 p.m.
32.  [Vibe engineering](https://simonwillison.net/2025/Oct/7/vibe-engineering/) - Oct. 7, 2025, 2:32 p.m.
33.  [Claude can write complete Datasette plugins now](https://simonwillison.net/2025/Oct/8/claude-datasette-plugins/) - Oct. 8, 2025, 11:43 p.m.
34.  [Getting DeepSeek-OCR working on an NVIDIA Spark via brute force using Claude Code](https://simonwillison.net/2025/Oct/20/deepseek-ocr-claude-code/) - Oct. 20, 2025, 5:21 p.m.
35.  [… more](https://simonwillison.net/series/using-llms/)

[ai 2,308](https://simonwillison.net/tags/ai/) [generative-ai 2,048](https://simonwillison.net/tags/generative-ai/) [llms 2,013](https://simonwillison.net/tags/llms/) [ai-assisted-programming 407](https://simonwillison.net/tags/ai-assisted-programming/) [ai-agents 111](https://simonwillison.net/tags/ai-agents/) [coding-agents 264](https://simonwillison.net/tags/coding-agents/) [claude-code 134](https://simonwillison.net/tags/claude-code/) [async-coding-agents 17](https://simonwillison.net/tags/async-coding-agents/) [jules 6](https://simonwillison.net/tags/jules/) [codex 61](https://simonwillison.net/tags/codex/) [parallel-agents 16](https://simonwillison.net/tags/parallel-agents/) [jesse-vincent 6](https://simonwillison.net/tags/jesse-vincent/) [peter-steinberger 4](https://simonwillison.net/tags/peter-steinberger/) [agentic-engineering 70](https://simonwillison.net/tags/agentic-engineering/)

**Next:** [OpenAI DevDay 2025 live blog](https://simonwillison.net/2025/Oct/6/openai-devday-live-blog/)

**Previous:** [Designing agentic loops](https://simonwillison.net/2025/Sep/30/designing-agentic-loops/)

### Monthly briefing

Sponsor me for **$10/month** and get a curated email digest of the month's most important LLM developments.

Pay me to send you less!

[Sponsor & subscribe](https://github.com/sponsors/simonw/)

-   [Disclosures](https://simonwillison.net/about/#disclosures)
-   [Colophon](https://simonwillison.net/about/#about-site)
-   ©
-   [2002](https://simonwillison.net/2002/)
-   [2003](https://simonwillison.net/2003/)
-   [2004](https://simonwillison.net/2004/)
-   [2005](https://simonwillison.net/2005/)
-   [2006](https://simonwillison.net/2006/)
-   [2007](https://simonwillison.net/2007/)
-   [2008](https://simonwillison.net/2008/)
-   [2009](https://simonwillison.net/2009/)
-   [2010](https://simonwillison.net/2010/)
-   [2011](https://simonwillison.net/2011/)
-   [2012](https://simonwillison.net/2012/)
-   [2013](https://simonwillison.net/2013/)
-   [2014](https://simonwillison.net/2014/)
-   [2015](https://simonwillison.net/2015/)
-   [2016](https://simonwillison.net/2016/)
-   [2017](https://simonwillison.net/2017/)
-   [2018](https://simonwillison.net/2018/)
-   [2019](https://simonwillison.net/2019/)
-   [2020](https://simonwillison.net/2020/)
-   [2021](https://simonwillison.net/2021/)
-   [2022](https://simonwillison.net/2022/)
-   [2023](https://simonwillison.net/2023/)
-   [2024](https://simonwillison.net/2024/)
-   [2025](https://simonwillison.net/2025/)
-   [2026](https://simonwillison.net/2026/)

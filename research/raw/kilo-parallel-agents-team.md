# How 7 Kilo Code Engineers Run Up to 20 Parallel Agents and Still Ship Clean Code

_Darko_

<https://web.archive.org/web/20260615171307/https://blog.kilo.ai/p/how-7-kilo-code-engineers-run-up>

Are parallel coding agents actually useful, or just Twitter theater?

Two camps have emerged when it comes to this topic. The first camp consists of people like Steve Yegge, who claims [you can](https://steve-yegge.medium.com/welcome-to-gas-town-4f25ee16dd04) train yourself to run and hand-manage 10+ agents at once:

> _Stage 7: 10+ agents, hand-managed. You are starting to push the limits of hand-management._

Others such as Armin Ronacher, the creator of Flask, think we’re in [an agent psychosis](https://lucumr.pocoo.org/2026/1/18/agent-psychosis/):

> _“When I watch someone at 3am, running their tenth parallel agent session, telling me they’ve never been more productive — in that moment I don’t see productivity. I see someone who might need to step away from the machine for a bit. And I wonder how often that someone is me.”_

To find a more nuanced answer to the question of whether and how you can run parallel AI agents productively, we asked 7 of our senior software engineers how they’re doing this and reaching [Kilo Speed](https://kilo.ai/manifesto) every single day.

These were engineers who didn’t just use coding agents, _but actively built them_. **Mark** has been working on the VS Code extension for over a year and has [replatformed](https://blog.kilo.ai/p/inside-kilo-speed-how-one-engineer-52c) the whole engine behind it. **Evgeny** [shipped](https://blog.kilo.ai/p/inside-kilo-speed-how-one-engineer-971) a deploy agent in a week. **John** is [building](https://blog.kilo.ai/p/gas-town-ga) a hosted version of Steve Yegge’s Gas Town, an orchestrator designed to run twenty-plus agents at once. And then you have **Igor**, **Florian**, **Kirill**, and **Imanol**, who ship incredibly fast and used to work at companies like Netflix, Netlify, JetBrains, and Rackspace.

We couldn’t ask for a better squad. Here are the lessons we learned from thirty minutes of focused discussion, backed by hundreds of hours of firsthand experience:

The entire discussion started with **Evgeny** being puzzled by posts on social platforms like X/LinkedIn from people who claimed to be running anywhere between 50 and 100 coding agents at once productively.

**The attention bottleneck:** At an engineering meeting a few days ago, Evgeny asked the team on the call if they thought these were real scenarios or just hype. Maybe those people who run 100 parallel agents have superhuman attention spans, where they can context-switch between 50+ different sessions at the same time.

**John** agreed with the sentiment. It’s simply next to impossible to have 20 agents working in the background and pay attention to them equally at the same time, let alone 100.

That led to a discussion about how many agents everyone was running in parallel and what’s the “sweet spot” number.

**Most of our engineers have 2-4 foreground agents running at a time** and they are not alone. Simon Willison, the co-creator of the Django Web Framework, [said](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/) that he can “focus on reviewing and landing one significant change at a time.” Mitchell Hashimoto, the legendary co-founder of HashiCorp, [calls](https://www.teamday.ai/ai/hashimoto-new-way-of-writing-code) himself “the mayor” managing at most two agents at a time.

**Wait, only 2–4 agents?**

Notice how I said _foreground_ agents. Foreground are the agents you **actively** manage: the ones whose work you’re watching, reviewing, steering, and interrupting when they start drifting off-track.

**Igor**, a software engineer at Kilo who works on high-level architecture problems, says he’s firmly in the “two-to-three agents max” club. In his experience, even with SOTA models, output quality on complex tasks drops quickly unless you stay close to the work. The higher the stakes, the less you can afford to treat the agent as a black box.

**The lesson:** Your engineers are (smart) humans, not superhumans. And that’s okay.

When someone tells you they’re “running” 100 agents, it’s worth asking what “running” means. In practice, _we found that “running” can mean two very different things:_ actively managing a few foreground agents, or letting many background agents work with minimal intervention. The latter is where things get more interesting.

**Mark** is one person on the team known for running over 20 parallel agents at once.

**Here’s the catch** you won’t hear from most social media “gurus” who claim they’re running 100+ agents at once: **most of those are background agents.** As the rest of the team, Mark usually runs 1-3 parallel agents in the foreground, while the rest are background jobs that don’t demand a lot of attention.

For example, Mark could spin up a cloud agent to fix specific change markers in a file while he continues working on a larger upstream merge with a foreground agent.

**Mark’s background agents “fire-and-forget”** **type of agents.** Each agent ships a pull request, which passes or fails in tests, and Mark looks at the final result later. The agent doesn’t demand attention while it runs. It only demands attention once it finishes, when Mark decides whether to merge or reject the PR.

**The lesson here is:** these small, background parallel tasks are easy to evaluate. An agent does something, creates a PR, you take a quick look, and then move on to the next thing.

**This is becoming industry practice:** Mark is not alone with this setup. Addy Osmani, an engineer at Google, has a [setup](https://addyosmani.com/blog/coding-agents-manager/) that “runs four to five background agents handling low-to-medium complexity work”.

Simon Willison has embraced the [parallel](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/) coding agent lifecycle by using a lot of agents for small maintenance tasks: “It turns out there are a lot of problems that really just require a little bit of extra cognitive overhead which can be outsourced to a bot.”.

**Software as gardening;** In one of Kilo’s blogs, Mark [describes](https://blog.kilo.ai/p/inside-kilo-speed-how-one-engineer-52c) that he likes “to think of software engineering as gardening instead of building” Instead of doing the grunt work (boilerplate, scaffolds), you apply your judgment. “You can just say: take care of that, remove that weed. That’s much closer to how it feels to interact with an agent.”

This metaphor fits how I think about background agents. You give them a small piece of work, let them progress on their own, and come back later to prune. The agents do the building. You do the gardening.

At its core, an agent session is you giving the agent a task, and the agent completing that task.

The task can be as simple as “capitalize these 3 strings” or as broad as “build me a Kilo Code clone.”

**Which begs the question:** what’s the right task size for an agent? If it’s too small, your prompting might be slower than just writing the code. If it’s too large, the agent could run out of context and start getting confident in making the wrong calls.

What’s the Goldilocks zone when prompting agents? That’s the question our CEO, Scott, asked engineers. The answers were revealing.

**Managing the context window:** Igor, our senior software engineer who works on a lot of architecture tasks, said that figuring out the Goldilocks zone for him depends on the context window. Quality usually drops around 60% context fill, well before the 95% mark where compaction actually kicks in for many coding agents. By then, hallucinations have already started.

**Igor’s** workaround is to split coding tasks into smaller sub-agents, so each one finishes before its context fills up. He’s trying to optimize the scope of each task so the work completes before auto-compression kicks in.

There’s a name for what Igor is referring to in the agentic engineering community:: [context rot](https://redis.io/blog/context-rot/).

The more the context window fills up, the more hallucination, inaccurate output, and unpredictable results you get. An Anthropic employee [wrote](https://x.com/trq212/status/2044548257058328723) an entire piece on this problem, pointing out the risks of “bad compacting” when a context window grows too large.

**The advertised context window is not the usable window:** Figuring out the Goldilocks zone for your use case is easier said than done. However, there are some tips to get you started:

-   **Size the task by reviewability**
    

A good agent task should produce an output a human can review in one sitting. If the diff is too large to inspect carefully, the task was probably too large.

-   **Use OpenAI’s [GCCD](https://developers.openai.com/codex/learn/best-practices) framework when structuring your prompts:**
    

-   **Avoid mixing too many task types in one run**
    

“Refactor this service, improve performance, add analytics, and clean up tests” is four agent tasks, not one.

Some of our engineers were happy to let the agent run the whole task they wanted to do, as long as the plan is right.

**Florian**, for example, had an interesting approach that involved careful planning and fast execution. Florian’s research agents (which can be spun up using Kilo Code’s Plan mode or KiloClaw) prepare plans for the tasks he wants to do. By the time the planning finishes, he has a queue of pre-investigated problems ready for execution agents to work on.

**Imanol** was experimenting between two SOTA models to get this approach right. One of them was GPT-5.5 with “Fast mode” on. He found the model incredibly quick, but error-prone. He eventually defaulted to a similar approach to Florian’s: use a slow, thinking model for planning, and let GPT-5.5 Fast implement that work quickly. The result was “so much better,” according to Imanol.

**Kirill** combined GPT-5.5 (with Thinking enabled) for planning, then switched to Sonnet for fast execution.

**Florian, Imanol and Kiril are not alone in using this approach**. Boris Cherny, the creator of Claude Code, [uses](https://newsletter.pragmaticengineer.com/p/building-claude-code-with-boris-cherny) a similar setup where he starts Claude in plan mode, iterates on the plan, then lets it one-shot the implementation. According to Boris, _“once there is a good plan, it will one-shot the implementation almost every time.”_

Let’s say you went with this approach. A planning model hands off to a fast executor. The output looks good. But “looks good” is not the same as “is good,” and that gap is what Step 3 closes.

This can be one of the most important steps when it comes to managing your attention budget.

**Let’s take Florian’s PR-review-feedback agent as one example.** When a reviewer leaves comments on a PR Florian pushed, an OpenClaw agent hosted on KiloClaw reads the feedback, makes the code changes, and sends a message back to Florian with the new changes. Repeat this across hundreds of PRs and the saved time compounds.

This is just one example of plugging an agent in a feedback loop. Boris Cherny from Anthropic [said](https://paddo.dev/blog/how-boris-uses-claude-code/) that giving an agent the ability to verify its work results in a final result where the quality is 2-3x better.

A separate agent reviews better than the original because [“the person who wrote the code is the worst person to review it”](https://readysolutions.ai/blog/2026-04-08-agentic-development-starter-guide/). A fresh session has no attachment to what it’s looking at. That’s part of the reason why Kilo ships separate agents for [code review](https://kilo.ai/code-reviewer), [security](https://kilo.ai/security-agent), and [hosted workflows](https://kilo.ai/kiloclaw), making workflows like Florian’s easier to create.

So no, we’re not living in the age of agent psychosis. We’re living in the age where the bottleneck is shifting from writing code to verifying it. The 100-agent tweet may get attention, but the practical workflow is much less dramatic: 2–4 agents in the foreground, a handful in the background, and a strong verification loop on top. That’s the unlock. Everything else is theater.

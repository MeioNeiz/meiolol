# My Thoughts on the Bun Rust Rewrite - Andrew Kelley

<https://andrewkelley.me/post/my-thoughts-bun-rust-rewrite.html>

[Andrew Kelley](https://andrewkelley.me/) - My Thoughts on the Bun Rust Rewrite (2026 Jul 09)

* * *

# My Thoughts on the Bun Rust Rewrite

Context: [Rewriting Bun in Rust](https://bun.com/blog/bun-in-rust)

## History

When Jarred joined the Zig community about 5 years ago, I described him as someone who had strong "beginner energy". That is, he moved fast and tried a lot of different stuff, jumping head first into problems that he was not yet equipped to solve, leading to mediocre outcomes in terms of engineering, but learning a whole heck of a lot in the process. I see it as quite a healthy attitude, particularly for young people and students. This is the best way to level up and learn new things.

As he focused his efforts on Bun he began to attract attention. JavaScript being the most popular programming language in the world, there are a lot of potential eyeballs on a promising new toolchain.

This attention could have been harnessed in a few different ways. For example, he could have easily achieved a solid living via crowdfunding, even for San Francisco standards. But having graduated from the Thiel Fellowship school of thought rather than university, he was essentially groomed from a young age into uncritically embracing the Silicon Valley mindset, and he took venture capital.

From the beginning, Jarred was appreciative towards the Zig project. He credited Zig on the Bun website for the project's performance achievements. He set up a monthly donation to [Zig Software Foundation](https://ziglang.org/zsf/) that amounted to $60,000 per year. He didn't have to do either of those things, but he did, and it was pretty cool of him. Even in [his blog post that I'm referencing](https://bun.com/blog/bun-in-rust), he expresses what I perceive as sincere grattitude towards the Zig project.

However, once Bun became a VC-backed startup, he started racing towards the finish line. Now, instead of working on a free and open source project, learning and growing with the community, Jarred was running a business. It was at this point - when he suddenly became a manager - that this "beginner energy" started to hit differently for me. It's one thing to [choose a poor work-life balance for oneself](https://nitter.net/jarredsumner/status/1544821137128927232); a different thing entirely to [demand it of others](https://web.archive.org/web/20220824093845/https://twitter.com/oven_sh/status/1562248121656102914):

> "Oven is going to be a grind, especially the first nine months or so. If work-life balance to you means a lot of time spent not working, it’s probably not a good fit right now."

Fun fact: people talk to each other.

I talked to those who interviewed for a job at Oven. I talked to people who worked there. Those people talked to each other. Everybody talked to everybody. The grapevine was large and healthy and full of juicy grapes, and all those grapes contained the juice of the same message: Jarred was a stinky manager. Poor communication, unrealistic expectations, low empathy, no experience. Just a total shit show, from an employment perspective.

Consequently, although Zig community members were eager to find work coding in Zig on the clock, most of the talent pool steered clear of Oven and Bun.

At the same time, a rift between Zig and Jarred started widening. His singular focus on productivity and his startup's exit strategy was increasingly at odds with my longer term vision for the Zig project. I remember he kept nagging me to drop all my other priorities and work on a Language Server Protocol implementation and VSCode integration, while I had bigger plans.

The main problem, however, was code quality.

The Zig team regularly checks in on our users' projects. We read source code to find out how the language is affecting users, we test changes to see how problematic breakage might be, and we check for performance regressions.

We became increasingly horrified at the programming practices we saw in Bun's codebase. Hacks on top of hacks. [Abuse of assertions.](https://kristoff.it/blog/fix-your-asserts/) Most of all, recklessly speeding past feature after feature with very little time taken for reflection and elimination of bugs and technical debt. Jarred was already writing slop well before he had access to LLMs. Now, it's not our business to police what our users do, but you may have noticed people screaming in our faces about memory safety constantly. You can imagine how we might want to put some social distance between ourselves and a project whose irresponsible software engineering practices invite the exact kind of criticism that people are eager to level.

We made futile attempts to guide them towards better programming practices. There were a few exceptional heroes who did their very best in a dysfunctional company. You know who you are. But you can't stop a rising tide.

By this time, we all felt at ZSF that Bun was a net liability, and this was _before_ RoboBun became the #1 contributor. Along with the discomfort of the publicly presumed poster child for Zig programming language actually being the prime example of How Not To Write Zig Code, at some point they would sell out (let's be honest, their vague "sell some cloud something" business plan was a farce from the get-go), we would receive some negative publicity by proxy, and we'd stop getting that regular donation.

So, when the Anthropic aquisition finally happened, we at ZSF breathed a sigh of relief. When the donation silently stopped, our bank account was ready for it. When they neither canceled their monthly meeting with us, nor showed up, we were not surprised. The relationship was over.

The (re)writing was on the wall. Even within a couple days, we already suspected a Rust rewrite was coming. And we were rooting for it! The acquisition by a large AI company was a burden, because even the indirect connection of Claude being written in Bun being written in Zig caused not only a surge of [drive by slop contributions](https://kristoff.it/blog/contributor-poker-and-ai/), but also an influx of tasteless AI enthusists into Zig communities who had to be informed that it's antisocial to paste LLM output into forum posts. For a moment, I feared Zig's identity would become known colloquially as a programming language associated with AI.

When Jarred announced the Rust rewrite, we were ecstatic. It seemed too good to be true. I have to admit, I didn't think the technology was there, to pull off this stunt. But he did it, and now I'm metaphorically sipping delicious tea from a mug that says "It Tastes Like It's Not My Problem Anymore".

## Addressing the Blog Post

The blog post is expertly written. It's _almost_ like the marketing department of a trillion dollar company has a lot of money riding on this article.

I do have some bones to pick however.

There's a dichotomy being presented here where you have to either choose a "style guide" or a programming language feature in order to avoid bugs. The sleight of hand misdirects the reader away from the main way bugs are eliminated: by dedicating engineering resources to it. You're not giving TigerBeetle nearly enough credit. Quite simply they put in the time to find and eliminate the bugs, they make an effort to maintain a healthy relationship with ZSF, and Bun did neither of those things.

The argument for shipping all the million lines of unreviewed code is that the test suite is good enough to catch everything. Then why are you saying you have so many annoying bugs in the Zig code? What happened to the test suite being sufficient to catch everything? It's not sufficient to catch bugs in Zig code but it is sufficient to catch bugs in 1 million lines of unreviewed slop?

Performance increase is attributed to LTO, which Zig has supported for all of Bun's existence. It used to be enabled by default until we ran into too many LLVM bugs, all of which also affect Rust. We probably tried to tell you to try enabling it and you didn't listen. We have good advice, damn it!

The post implies you were diligently fuzzing your Zig code, while during our calls the Bun team told us that they were not fuzzing anything.

The blog post outlines a bunch of engineering work done to reduce binary size, to better make the case that "Bun is better in Rust". But all that engineering work had nothing to do with the rewrite. I think this (specifically the "binary size" section of the blog post) is precisely why it took so long for the blog post to come out, you were doing the engineering work that you should have done in the Zig codebase since the beginning. We've been trying to warn you about your `comptime` abuse for years. We even made [this time report thing](https://ziglang.org/download/0.15.1/release-notes.html#Web-Interface-and-Time-Report) specifically for projects that need to audit their use of `comptime`/`inline` usage and compile times.

I noticed that you neglected to mention compilation speed. Zig compiler project is about 600,000 lines of code - roughly the same size as Bun before the rewrite, and I'm clocking 16s to build from scratch with a clean cache, followed by 90ms for each subsequent edit with incremental compilation enabled. What are the corresponding measurements of Bun post-rewrite?

## Moving On

Zooming out a bit, I want to make one thing clear.

The main issue here had nothing to do with the language features of Zig vs Rust, and everything to do with the diverging value systems of the two projects and the relationship breakdown that followed.

I have rewritten this section twice - once upon reflection, and now again after several people have confided in me additional information. The original version focused on a sort of "radical acceptance" that I try to subscribe to, seeing things from Jarred's perspective. However, it did not include any admission of feelings of resentment, causing many readers to perceive this post as duplicitous. So the first update included a bit of self reflection. However, with the new information I am privy to, I have a completely different feeling about Jarred, and with that in mind, here is the final update. Feel free to go read the older versions in the public source repository for this website.

It's not a good look for the leader of a project to say negative things about a user on the way out the door, however, this is an exceptional situation. I have firsthand information from two young, naive programmers fresh out of college and seeking employment. Jarred wasn't only a shitty manager. He regularly engaged in cruel, illegal practices, including withholding wages, and bait and switch operations that he only got away with due to financial desperation. There is more, however, in order to protect the identity of those victims I will not share more details.

I find these things inexcusable.

At this point, my only regret is not asking more questions earlier, discovering this information earlier, and then loudly ending the relationship immediately to protect more Zig community members from becoming victims.

Lesson learned.

* * *

Thanks for reading my blog post.

[Home Page](https://andrewkelley.me/) | [RSS feed](https://andrewkelley.me/rss.xml) | [Sponsor the Zig Software Foundation](https://ziglang.org/zsf)

# Automation That Screams Joy

<https://tigerbeetle.com/blog/2026-04-14-automation-screams-joy/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# Automation That Screams Joy

Apr 14, 2026

-   [
    
    matklad
    
    ](https://matklad.github.io/)

I hate shell scripting with a passion. Whenever I join a project, I go on a crusade to rewrite all bash scripts into the project’s main language. I have [Java For Everything](https://www.teamten.com/lawrence/writings/java-for-everything.html) tattooed on my arm (no). The code I’ve written at TigerBeetle that I am most proud of is this:

```
while true
do
    rm -rf ./tigerbeetle
    (
        git clone https://github.com/tigerbeetle/tigerbeetle tigerbeetle
        cd tigerbeetle
        ./zig/download.sh
        unshare --user -f --pid \
            ./zig/zig build -Drelease scripts -- cfo --timeout=30m
    ) || sleep 10
done
```

This snippet encapsulates the pattern ([Erlang Universal Server](https://joearms.github.io/published/2013-11-21-My-favorite-erlang-program.html)) which works really well for writing custom automations for software projects.

## [Problem Statement](https://tigerbeetle.com/blog/2026-04-14-automation-screams-joy/#problem-statement)

When working on larger software projects, one often needs to run a custom piece of automation software somewhere. The most common case is running the set of CI checks. If the problem is roughly CI-shaped, you largely are covered by GitHub actions or your platform’s alternative.

This post discusses what to do (and what to avoid) when implementing custom automation that doesn’t fit CI. In the case of TigerBeetle, we need to manage a fleet of machines continuously running our deterministic simulation testing harness (the [VOPR](https://github.com/tigerbeetle/tigerbeetle/blob/0.16.78/docs/internals/vopr.md)). I gave a talk about that particular use case on [HYTRADBOI 2025](https://www.hytradboi.com/2025/c222d11a-6f4d-4211-a243-f5b7fafc8d79-rocket-science-of-simulation-testing) and I want to expand it into a series of articles extracting re-usable lessons.

## [Naive Solution](https://tigerbeetle.com/blog/2026-04-14-automation-screams-joy/#naive-solution)

How would you implement an in-house fuzzing service for a database? Our V1 solution felt like a “standard” small scale approach to this sort of thing: a Go service in a separate repository, running under systemd on a couple of manually provisioned machines. A lot of custom automation I’ve seen worked along those lines, and shared the following set of problems:

If you are a developer, it’s hard to know what automation even exists, because it is hidden in separate repositories. Once you find it, it is hard to modify, because it is using a different language and a different set of technologies (e.g., there are database developers, who don’t know how to write a systemd unit file (👋). Finally, even if you fix it, there are extra steps to make the fix go live — you need to find the devops person who has the permission to deploy the automation, and ask them kindly to redeploy. Friction, friction everywhere, and not a change to make!

## [Universal Server](https://tigerbeetle.com/blog/2026-04-14-automation-screams-joy/#universal-server)

The common thread here is that automation directly affects developers’ lives, but they don’t have the agency to go and make it better. Let’s fix that.

_First_, we make sure that automation lives in the same repository as the main project. `./src/scripts` is a good place.

_Second_, we make sure that automation is implemented in the same language as the project itself. Yes, bash is significantly more compact that `std::process::Command`. But adding one library (or even just one helper function) closes most of the gap. In return for a slight increase in verbosity you remove the need to context switch, stop worrying about semantic differences between BSD and GNU sed, and remove the need to set up ShellCheck on top of your usual linting setup.

_Third_, the secret sauce, you implement auto-deploy. The invariant you maintain is that the version of automation deployed matches the current tip of the main branch. That is, whoever can push to main is automatically able to deploy changes to automation. And the way you achieve that is via a self-bootstrapping pattern. What you actually deploy is a script that clones your repository, runs automation off the main branch, and then loops. [Here’s ours](https://github.com/tigerbeetle/tigerbeetle/blob/0.16.78/src/scripts/cfo_supervisor.sh):

```
set -eu
git --version

while true
do
    rm -rf ./tigerbeetle
    (
        git clone https://github.com/tigerbeetle/tigerbeetle tigerbeetle
        cd tigerbeetle
        ./zig/download.sh
        unshare --user -f --pid \
            ./zig/zig build -Drelease scripts -- cfo --timeout=30m
    ) || sleep 10
done
```

-   We start with removing the old version of the repository, to clean the slate.
-   We then clone the repo and bootstrap the dev environment for our main language. Zig makes this particularly easy, but this should work for any language.
-   We then compile and run the automation for some time (e.g., 30 minutes). Ideally, the timeout is enforced externally, but, given the cooperative nature of the thing, we’ve found the internal timeout to work fine as well.
-   Similarly, it’s pretty hard to robustly _not_ leak any leftover processes on UNIX, so some lightweight sandboxing is in order ([`unshare`](https://man7.org/linux/man-pages/man1/unshare.1.html) works for us).

You might be wondering who deploys the deployer script? We have a bunch of persistent [tmux](https://github.com/tmux/tmux) sessions which run the above script in foreground, works like a charm at our scale!

And that’s it — developers are now empowered to change the automation to their liking, because the only thing they need to do to effect change is [a pull request](https://github.com/tigerbeetle/tigerbeetle/pull/3209)!

MORE POSTS

[

## A Trillion Transactions

Joran Dirk Greef · Mar 19, 2026

](https://tigerbeetle.com/blog/2026-03-19-a-trillion-transactions)

-   [View All Posts](https://tigerbeetle.com/blog)
-   [**RSS**](https://tigerbeetle.com/blog/atom.xml)

 

### Product

[

Cloud

](https://tigerbeetle.com/cloud)[

Pricing

](https://tigerbeetle.com/cloud#pricing)[

Stories

](https://tigerbeetle.com/stories)

### Developers

[

Docs

](https://docs.tigerbeetle.com/)[

GitHub

](https://github.com/tigerbeetle/tigerbeetle)[

Tutorials

](https://github.com/tigerbeetle/tigerlings)[

Releases

](https://github.com/tigerbeetle/tigerbeetle/releases)[

Jepsen

](https://jepsen.io/analyses/tigerbeetle-0.16.11)[

Blog

](https://tigerbeetle.com/blog)

### Connect

[

X

](https://x.com/TigerBeetleDB)[

LinkedIn

](https://www.linkedin.com/company/tigerbeetle/)[

YouTube

](https://www.youtube.com/@tigerbeetledb)[

Email

](mailto:hello@tigerbeetle.com)

### Company

[

About

](https://tigerbeetle.com/company)[

Privacy

](https://tigerbeetle.com/privacy)

### Newsletter

Get monthly highlights and carefully crafted updates.

[Subscribe](https://tigerbeetle.com/newsletter)[

Past Newsletters →

](https://tigerbeetle.com/newsletters)

Correct and Fast

Copyright © 2026 TigerBeetle, Inc. All Rights Reserved.

# graydon2 | technicalities: "not rocket science" (the story of monotone and bors)

<https://web.archive.org/web/20240101105019/https://graydon2.dreamwidth.org/1597.html>

Account name:  Password  

[(OpenID?)](https://www.dreamwidth.org/openid/) [(Forgot it?)](https://www.dreamwidth.org/lostinfo)  Remember Me

You're viewing [**graydon2**](https://graydon2.dreamwidth.org/)'s journal  
[Create a Dreamwidth Account](https://www.dreamwidth.org/create)  [Learn More](https://www.dreamwidth.org/)

 

Reload page in style:  [site](https://graydon2.dreamwidth.org/1597.html?style=site)   [light](https://graydon2.dreamwidth.org/1597.html?style=light)

-   [Recent Entries](https://graydon2.dreamwidth.org/)
-   [Archive](https://graydon2.dreamwidth.org/archive)
-   [Reading](https://graydon2.dreamwidth.org/read)
-   [Network](https://graydon2.dreamwidth.org/network)
-   [Tags](https://graydon2.dreamwidth.org/tag/)
-   [Memories](https://www.dreamwidth.org/tools/memories?user=graydon2)
-   [Profile](https://graydon2.dreamwidth.org/profile)

# [frog hop](https://graydon2.dreamwidth.org/)

## technicalities: "not rocket science" (the story of monotone and bors)

### [technicalities: "not rocket science" (the story of monotone and bors)](https://graydon2.dreamwidth.org/1597.html "technicalities: ")

[Feb](https://graydon2.dreamwidth.org/2014/02/). [2nd](https://graydon2.dreamwidth.org/2014/02/02/), [2014](https://graydon2.dreamwidth.org/2014/) 10:25 pm

[**graydon2**](https://graydon2.dreamwidth.org/)

A technical note about a program I wrote last year called [bors](https://github.com/graydon/bors) and some of its ancestry. This is _excruciatingly boring_ unless you happen to build software for a living, in which case I recommend taking a minute to read it.  
  
  
Thirteen years ago I worked at Cygnus/RedHat on a project with a delightful no-nonsense Australian hacker named Ben Elliston. We were faced with a somewhat nightmarish multi-timezone integration-testing scenario that carried a strong penalty for admitting transient bugs to the revision control repository (then CVS). To try to keep the project under control, Ben, Frank, and possibly a few other folks on the team cooked up a system of cron jobs, rsync, multiple CVS repositories and a small postgres database tracking test results.  
  
The system had a simple job: _automatically maintain a repository of code that always passes all the tests_. It gave us peace of mind (customers only pulled from that repository, so never saw breakage) and had the important secondary benefit that engineers could do their day's work from known-good revisions, without hunting someone else's bug that accidentally slipped in. Because the system was automated, we knew there was no chance anyone would rush to commit something sloppy. You could commit all the sloppy stuff you wanted to the _non-automated_ repository; it would just be declined by the automated process if it broke any tests. Unforgiving, but fair. At the time I felt I'd learned an important engineering lesson that any reasonable shop I went to in the future would probably also adopt. It turns out that if you set out to engineer a system with this as an explicit goal, it's not actually that hard to do. Ben described the idea as "not rocket science". Little did I know how elusive it would be! For reference sake, let me re-state the principle here:  
  

>   
> **The Not Rocket Science Rule Of Software Engineering:**  
>   
> automatically maintain a repository of code that always passes all the tests  

  
  
Time passed, that system aged and (as far as I know) went out of service. I became interested in revision control, especially systems that enforced this Not Rocket Science Rule. Surprisingly, only one seemed to do so automatically ([Aegis](http://aegis.sourceforge.net/), written by Peter Miller, another charming no-nonsense Australian who is now, sadly, approaching death). At the time Aegis was not a distributed system, and while I was using Aegis on my own time I knew there were interesting possibilities if one went into the area of _distributed_ revision control, as I saw my friends using bitkeeper. I wanted to blend the two ideas, so I got to work on a system of my own called [monotone](https://github.com/graydon/monotone).  
  
Monotone was named as it was because I wanted to really pursue this concept of "monotonically increasing test coverage". Revision branch-inclusion was based on certificates that could easily be published out-of-order by testing robots. Etc. Etc. I figured this was the future. Of course, numerous adventures followed eventually resulting in mercurial and git, monotone was swept aside, the world of revision control changed, and so forth. Hurrah.  
  
Along the way something weird happened. "Continuous integration" became a standard practice, and eventually "continuous deployment", but _very few sites seemed to be following the Not Rocket Science Rule_ in their own codebase. That is, everywhere I saw "continuous integration" in practice, it was being done in the wrong order: code being accepted _before_ testing (leaving a potentially broken tree), or tested in isolation and then integrated on the basis of that test (with no guarantee that the integrated combination works). Continuous integration seemed everywhere to be used only to learn (rapidly) when the tree was broken, not prevent it breaking in the first place. I was dumbfounded, annoyed, saddened.  
  
So when it came time, a few years later, to scale up contribution beyond a few of us on Rust, I decided I needed to enforce the Not Rocket Science Rule in order to keep the code under control. I repeatedly explained it but nobody else was biting at the idea, so as "technical lead" I wound up implementing it myself. The result was a small script called [bors](https://github.com/graydon/bors).  
  
Bors implements the Not Rocket Science Rule against a combination of a buildbot test farm and a github repository: it monitors pull requests, waits for reviewers to approve them, then for each approved revision, makes a _temporary integration revision_ which extends your integration branch by the proposed changes. It tests that temporary revision and advances your integration branch to point to the integration revision if and only if the tests pass. If the tests fail, the integration revision is discarded and a comment in the pull request is left showing the failures.  
  
You can see the Rust instance of its work queue [here](http://buildbot.rust-lang.org/bors/bors.html) and the Servo instance [here](http://servo-buildbot.pub.build.mozilla.org/bors/bors.html). An example successful integration is [here](https://github.com/mozilla/rust/pull/12003) and an example rejected integration (at least at the time of writing) is [here](https://github.com/mozilla/rust/pull/11951). This rule is, I reiterate, not rocket science. I'm banging on about this because it's _so amazing_ to me how little tool support seems to exist for it. I had to write it myself! Its effect on a fast-moving, delicate project is extremely beneficial. Trunk is never broken. It does mean that your integration cycle time is bounded by your test cycle time, and it means that some changes take a number of attempts to integrate (bors supports priority markers to help you manually tune the integration order).  
  
On some projects, test time is too long for this strategy to work on each revision, at least without defining an integration-test subset. This is certainly everyone's chief initial concern, and it's legitimate, but in my experience it's a bit like people objecting to testing (or typechecking) in the first place because writing the tests and types will take too long: you'll spend much more time fighting the bugs if you wait and discover them later. I _strongly_ recommend anyone who works in software _try this arrangement_ to see what a difference it makes.

-   Crossposts: [http://graydon.livejournal.com/186550.html](http://graydon.livejournal.com/186550.html)

Tags:

-   [tech](https://graydon2.dreamwidth.org/tag/tech)

-   [Previous](https://www.dreamwidth.org/go?dir=prev&itemid=1597&journal=graydon2)
-   [Memory](https://www.dreamwidth.org/tools/memadd?journal=graydon2&itemid=1597)
-   [Share](https://www.dreamwidth.org/tools/tellafriend?journal=graydon2&itemid=1597)
-   [Next](https://www.dreamwidth.org/go?dir=next&itemid=1597&journal=graydon2)

-   [8 comments](https://graydon2.dreamwidth.org/1597.html#comments)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?mode=reply)

[Flat](https://graydon2.dreamwidth.org/1597.html?view=flat#comments) | [Top-Level Comments Only](https://graydon2.dreamwidth.org/1597.html?view=top-only#comments)

#### [Not rocket science](https://graydon2.dreamwidth.org/1597.html?thread=613181#cmt613181 "Not rocket science")

Date: 2014-02-03 10:10 am (UTC)

From: [**ewen**](https://ewen.dreamwidth.org/)

Thanks for sharing the history, and the example of how the tools work -- I particularly hadn't realised that was the origin of monotone. As you say "don't break the build" is such a simple concept (and one I try hard to maintain manually in any project I work on), but it's often left to social enforcement at best. It's odd that in a 100%-test-coverage and continuous-integration world that the tooling isn't also prioritising an "any trunk revision is a viable release candidate" test-first-then-merge-to-trunk.  
  
Ewen

-   [Link](https://graydon2.dreamwidth.org/1597.html?thread=613181#cmt613181)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?replyto=613181)

#### [no subject](https://graydon2.dreamwidth.org/1597.html?thread=613437#cmt613437 "no subject")

Date: 2014-02-04 02:07 am (UTC)

From: [**robbat2.livejournal.com**](http://robbat2.livejournal.com/)

It's a shame that Not Rocket Science Rule didn't get a better early start, I sadly still see many cases where it would have save much time later on (possibly with the mandatory writing of non-trivial test cases before new code).  
  
But also fun to run into somebody with time in Redhat's boom era, hats off to you for that - I have a signed copy of Bob Young's autobiography from November 1999, from my early start in open source.

-   [Link](https://graydon2.dreamwidth.org/1597.html?thread=613437#cmt613437)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?replyto=613437)
-   [Thread](https://graydon2.dreamwidth.org/1597.html?thread=613437#cmt613437)
-   [Hide 1 comment](https://graydon2.dreamwidth.org/1597.html#cmt613437)

#### [no subject](https://graydon2.dreamwidth.org/1597.html?thread=617533#cmt617533 "no subject")

Date: 2014-02-25 02:11 am (UTC)

From: [**graydon.livejournal.com**](http://graydon.livejournal.com/)

Aegis has a delightful wrinkle on this: each changeset has to not just pass all existing tests, but also come with a new test, independently tracked and associated with the change, that must fail before the change, and pass after it.  
  
I found working within this structure -- enforced and automated -- extremely pleasant, the few times I worked on aegis-managed projects. Wish it had spread more.

-   [Link](https://graydon2.dreamwidth.org/1597.html?thread=617533#cmt617533)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?replyto=617533)
-   [Thread from start](https://www.dreamwidth.org/go?redir_type=threadroot&journal=graydon2&talkid=617533)
-   [Parent](https://graydon2.dreamwidth.org/1597.html?thread=613437#cmt613437)

#### [no subject](https://graydon2.dreamwidth.org/1597.html?thread=613693#cmt613693 "no subject")

Date: 2014-02-04 04:39 am (UTC)

From: [**lindseykuper**](https://lindseykuper.dreamwidth.org/)

Good stuff, Graydon. Thanks for writing this down.

-   [Link](https://graydon2.dreamwidth.org/1597.html?thread=613693#cmt613693)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?replyto=613693)

#### [no subject](https://graydon2.dreamwidth.org/1597.html?thread=613949#cmt613949 "no subject")

Date: 2014-02-04 03:18 pm (UTC)

From: [**elsmi.livejournal.com**](http://elsmi.livejournal.com/)

And the pull-request support in Travis-CI is so close, and yet so far... it tells you whether the PR passed when merged into master, at the time when the test was run. But if other PRs have been merged since then, then the result may be stale. One could trivially detect this, but who cares, right?

-   [Link](https://graydon2.dreamwidth.org/1597.html?thread=613949#cmt613949)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?replyto=613949)
-   [Thread](https://graydon2.dreamwidth.org/1597.html?thread=613949#cmt613949)
-   [Hide 3 comments](https://graydon2.dreamwidth.org/1597.html#cmt613949)

#### [no subject](https://graydon2.dreamwidth.org/1597.html?thread=614205#cmt614205 "no subject")

Date: 2014-02-04 05:28 pm (UTC)

From: [**graydon.livejournal.com**](http://graydon.livejournal.com/)

Yeah, Bors actually uses the status hooks they put in place for Travis. I was seriously surprised how close, yet how far.

-   [Link](https://graydon2.dreamwidth.org/1597.html?thread=614205#cmt614205)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?replyto=614205)
-   [Thread from start](https://www.dreamwidth.org/go?redir_type=threadroot&journal=graydon2&talkid=614205)
-   [Parent](https://graydon2.dreamwidth.org/1597.html?thread=613949#cmt613949)
-   [Thread](https://graydon2.dreamwidth.org/1597.html?thread=614205#cmt614205)
-   [Hide 2 comments](https://graydon2.dreamwidth.org/1597.html#cmt614205)

#### [no subject](https://graydon2.dreamwidth.org/1597.html?thread=614461#cmt614461 "no subject")

Date: 2014-02-04 06:31 pm (UTC)

From: [**elsmi.livejournal.com**](http://elsmi.livejournal.com/)

Though, looking at the bors-reviewed commits you linked, I will say that it is kind of nice that Travis goes ahead and tests everything immediately, so when reviewing you can refer to the test results (or skip reviewing things that are actually still broken). Best of both worlds would be to test immediately when the PR is submitted, and then when it passes review, check whether those test results are still valid and re-use them if so; or, if master has moved on, re-run.  
  
(I guess this is probably more interesting for "slowish project that gets lots of PRs from random outsiders" than "fast-moving project under active development by small team".)

-   [Link](https://graydon2.dreamwidth.org/1597.html?thread=614461#cmt614461)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?replyto=614461)
-   [Thread from start](https://www.dreamwidth.org/go?redir_type=threadroot&journal=graydon2&talkid=614461)
-   [Parent](https://graydon2.dreamwidth.org/1597.html?thread=614205#cmt614205)
-   [Thread](https://graydon2.dreamwidth.org/1597.html?thread=614461#cmt614461)
-   [Hide 1 comment](https://graydon2.dreamwidth.org/1597.html#cmt614461)

#### [no subject](https://graydon2.dreamwidth.org/1597.html?thread=614717#cmt614717 "no subject")

Date: 2014-02-04 06:40 pm (UTC)

From: [**graydon.livejournal.com**](http://graydon.livejournal.com/)

No, it's more that we weren't (and still aren't, on that test farm) fully isolating test environments, so "run random code someone opened a PR containing without any review" would be a nice way for a stranger to take over one of the buildslaves.  
  
In 2014 I'd probably start with docker and do container-per-PR on a public cloud, which I think is now all the new CI stuff works.

-   [Link](https://graydon2.dreamwidth.org/1597.html?thread=614717#cmt614717)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?replyto=614717)
-   [Thread from start](https://www.dreamwidth.org/go?redir_type=threadroot&journal=graydon2&talkid=614717)
-   [Parent](https://graydon2.dreamwidth.org/1597.html?thread=614461#cmt614461)

-   [Previous](https://www.dreamwidth.org/go?dir=prev&itemid=1597&journal=graydon2)
-   [Memory](https://www.dreamwidth.org/tools/memadd?journal=graydon2&itemid=1597)
-   [Share](https://www.dreamwidth.org/tools/tellafriend?journal=graydon2&itemid=1597)
-   [Next](https://www.dreamwidth.org/go?dir=next&itemid=1597&journal=graydon2)

-   [8 comments](https://graydon2.dreamwidth.org/1597.html#comments)
-   [Reply](https://graydon2.dreamwidth.org/1597.html?mode=reply)

[Flat](https://graydon2.dreamwidth.org/1597.html?view=flat#comments) | [Top-Level Comments Only](https://graydon2.dreamwidth.org/1597.html?view=top-only#comments)

## [Profile](https://graydon2.dreamwidth.org/profile)

graydon2

[My Website](http://www.pobox.com/~graydon)

## [June](https://graydon2.dreamwidth.org/2023/06/) [2023](https://graydon2.dreamwidth.org/2023/)

| S | M | T | W | T | F | S |
| --- | --- | --- | --- | --- | --- | --- |
|   |   |   |   | 1 | 2 | 3 |
| [4](https://graydon2.dreamwidth.org/2023/06/04/ "1 entry") | 5 | 6 | 7 | 8 | 9 | 10 |
| 11 | 12 | 13 | 14 | 15 | 16 | 17 |
| 18 | 19 | 20 | 21 | 22 | 23 | 24 |
| 25 | 26 | 27 | 28 | 29 | 30 |   |

## [Most Popular Tags](https://graydon2.dreamwidth.org/tag/)

-   [capitalism](https://graydon2.dreamwidth.org/tag/capitalism) - 1 use
-   [gender](https://graydon2.dreamwidth.org/tag/gender) - 1 use
-   [history](https://graydon2.dreamwidth.org/tag/history) - 1 use
-   [infrastructure](https://graydon2.dreamwidth.org/tag/infrastructure) - 1 use
-   [justice](https://graydon2.dreamwidth.org/tag/justice) - 1 use
-   [management](https://graydon2.dreamwidth.org/tag/management) - 1 use
-   [novelty](https://graydon2.dreamwidth.org/tag/novelty) - 1 use
-   [politics](https://graydon2.dreamwidth.org/tag/politics) - 1 use
-   [rust](https://graydon2.dreamwidth.org/tag/rust) - 1 use
-   [software](https://graydon2.dreamwidth.org/tag/software) - 1 use
-   [tech](https://graydon2.dreamwidth.org/tag/tech) - 12 uses
-   [writing](https://graydon2.dreamwidth.org/tag/writing) - 1 use

## Page Summary

-   [**ewen**](https://ewen.dreamwidth.org/) - [Not rocket science](https://graydon2.dreamwidth.org/1597.html#cmt613181 "0 responses")
-   [**robbat2.livejournal.com**](http://robbat2.livejournal.com/) - [_(no subject)_](https://graydon2.dreamwidth.org/1597.html#cmt613437 "1 response")
-   [**lindseykuper**](https://lindseykuper.dreamwidth.org/) - [_(no subject)_](https://graydon2.dreamwidth.org/1597.html#cmt613693 "0 responses")
-   [**elsmi.livejournal.com**](http://elsmi.livejournal.com/) - [_(no subject)_](https://graydon2.dreamwidth.org/1597.html#cmt613949 "3 responses")

## Active Entries

-   1: [amateur (ham) radio and adjacent stuff](https://graydon2.dreamwidth.org/305034.html)
-   2: [computer history](https://graydon2.dreamwidth.org/304682.html)

## Style Credit

-   Base style: [Crossroads](https://www.dreamwidth.org/customize/?layoutid=82592) by [**branchandroot**](https://branchandroot.dreamwidth.org/)
-   Theme: Green Light by [**krja**](https://krja.dreamwidth.org/)

## Expand Cut Tags

No cut tags

Page generated Jan. 1st, 2024 10:50 am

Powered by [Dreamwidth Studios](https://www.dreamwidth.org/)

[Top of page](https://graydon2.dreamwidth.org/1597.html#)

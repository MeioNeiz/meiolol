# IMP Is Back. After a rough patch, Individual Match… | by STRATZ | STRATZ | Medium

<https://medium.com/stratz/imp-is-back-9a4280f34d62>

[

Write

](https://medium.com/m/signin?operation=register&redirect=https%3A%2F%2Fmedium.com%2Fnew-story&source=---top_nav_layout_nav-----------------------new_post_topnav--------------------)

[Sign in](https://medium.com/m/signin?operation=login&redirect=https%3A%2F%2Fmedium.com%2Fstratz%2Fimp-is-back-9a4280f34d62&source=post_page---top_nav_layout_nav-----------------------global_nav--------------------)

[

## 

STRATZ

](https://medium.com/stratz?source=post_page---publication_nav-825912da3fbc-9a4280f34d62-----------------------------------------)

STRATZ provides free player data and statistics for Dota 2.

# IMP Is Back

## After a rough patch, Individual Match Performance is better than ever!

[STRATZ](https://medium.com/@stratz?source=post_page---byline--9a4280f34d62-----------------------------------------)

6 min read

·

Jun 12, 2021

Press enter or click to view image in full size

For 4 years, IMP has been the most comprehensive metric to describe Individual Match Performance in Dota. Over a year ago, we upgraded from an algorithmic approach to a [neural network generated value](https://medium.com/stratz/stratz-ai-the-imp-ire-strikes-back-a7a3ca2b9eba), tying together innumerable combinations of metrics, and training computers to understand what a winning Dota performance is composed of. Things largely went along smoothly, though following the Dawnbreaker release, it became apparent that something wasn’t right.

Today, following a few detailed investigations into the issue, we’ve got everything smoothed out, and IMP is back as the reliable metric that it has earned its place as being over the years. Still, we take this downtime seriously, and wanted to do more than just set things straight, by adding a little joy into IMP’s return to excellence.

The first update is to the range of values that the purple IMP meters, found across [STRATZ.com](https://stratz.com/), are designed to display. Alongside the release of IMP 2.0, we updated the IMP meters to display a range from -100 through +100. This is because, technically speaking, if you begin a match with an estimated 0.01% chance to win, and then perform so highly as an individual that your performance alone predicts a 99.99% win probability, then you could achieve an approximately +100 IMP value. In reality, this is borderline impossible. The highest IMP values have historically varied by training cycle, but generally ranged between 70 and 80.

> [Have you seen our suite of Animajor pages yet?](https://stratz.com/leagues/12964)

IMP 2.1 produces the most consistent ranges we’ve ever produced, with values in excess of +50 and less than -50 being very rare. Because of this, the new IMP meters visualize a spread of IMP from -50 through +50. This creates a much more visually diverse and satisfying spread of values across your heroes and/or matches. For those players who manage to exceed the bounds set by this range, we added two new match awards to highlight their achievements.

Press enter or click to view image in full size

Introducing the new Very Special MVP (VSMVP) and Least Value Player (LVP) awards! The VSMVP award is earned by reaching +50 or greater IMP in a match, while LVP \[anti-\]awards are distributed to only the absolute worst performances. The VSMVP threshold is the same as what’s required to earn a spot on the [Global Highlights page](https://stratz.com/heartbeat). You can [learn more about match awards here](https://stratz.com/knowledge-base/General/What%20are%20Match%20Awards%3F).

> Very Special MVP awards are earned in about 1 out of 50 matches; LVP awards are \[earned\] in about 1 out of 60 matches.

Not all heroes are built alike, and IMP can provide some interesting insights regarding this truth. While the average IMP across across all matches is very close to 0, different heroes vary in their average IMP scores. While this might sound bad, it’s a feature rather than a bug, highlighting the amount to which different hero performances tend to influence the outcome of a match during any given meta. Here’s a range of all heroes’ average IMPs as of 7.29d, using a sample size of 250,000 matches.

Average IMP (rounded to nearest whole number)

Medusa and Templar Assassin stand out as super high achievers, signifying the impact these heroes have on the outcomes of their matches, when they perform well. The lowest two avearge earners are Earth Spirit and Ogre Magi, both of whom have the lowest correlation between in-game performance and match outcome, on average.

We’ve gone back and forth debating whether or not to normalize the IMP value by hero, allowing for equal odds for high and low achievement regardless of hero choice. From a UX standpoint, this feels like the right thing to do. However, our position currently is that we’d rather evolve our IMP visualizations and exposure across the site and elsewhere, because \[we believe\] the truth revealed by a more honest and hero-dependent IMP is a more actionable and interesting stat regarding how impactful each hero is in their respective matches, specifically in relation to their contribution to their teams’ win rate contributions. We’re very happy to be in a strong and unique position to provide this data.

## Get STRATZ’s stories in your inbox

Join Medium for free to get updates from this writer.

Remember me for faster sign in

It’s important to note that heroes that average lower IMP aren’t necessarily heroes that can’t contribute as meaningfully to their team as higher average IMP heroes. There are tons of high IMP Earth Spirits and Ogre Magis, and low IMP Templar Assassins and Medusas. Players’ unique approaches to playing heroes can trump gameplay standards, which is one of the many beautiful things about Dota.

Press enter or click to view image in full size

Also new this week, we have a couple new pages for you to enjoy. The first of these is our [Special Events page](https://stratz.com/special-events), which highlights our past and active coverage of Valve’s seasonal events, and provides links to archived content when available. This is a simple page, but will continue to grow more compelling as new events are released — and there are at least two coming up very soon! As usual, we expect to provide unique access and insights into these historic game modes.

Press enter or click to view image in full size

My Grandma…what a huge spread of analytics you provide!

Navigation gets trickier the more you grow. Seeing as STRATZ has grown tremendously over the last few years, and continues to do so at a record pace, we think it’s important to have a place to allow instant access to anywhere you want to go, and to show anywhere you _can_ go. For that, we now have a new [Site Map page](https://stratz.com/sitemap)! Maybe site maps aren’t especially compelling to the average user, but we think it’s pretty cool, and hopefully you’ll enjoy watching it expand as much as we do.

Next up, one of STRATZ’s craftsmen behind the scenes who’s influenced and built a lot of what you rely on day in and day out for your Dota insights, Carceri, went through the entire STRATZ website and double-triple checked that \[just about\] every string on the site is available for our group of community volunteer translators to finally catch up to a true 100% localized experience. Unfortunately, Gitlocalize is experiencing a rather frustrating bug that our German translator Ingi discovered last week. Blukai has provided a very detailed bug report to their team, and we hope a resolution is pushed soon. Once that takes place, we’ll finally be in a position to fully welcome readers of Russian, German, Chinese, Portuguese, and Thai to STRATZ.

> Want to help translate STRATZ into a new language? We have a strong team of translators, many who have already begun to provide even more users access to their native language on STRATZ. [Let us know on Discord!](https://discordapp.com/invite/5WWngXa)

Finally, we’ve made some additional improvements to [the new Leagues experience](https://stratz.com/leagues). We now show the teams and players that are participating in each league on their respective [Overview pages](https://stratz.com/leagues/12964), among over improvements. The Leagues area of the site is an ongoing process, and has a few pieces still awaiting implementation, though much of our attention will be focused on our new releases from this point forward. Stay tuned!

_Think you’ve got what it takes to join the STRATZ team?_ [_We’re looking for a new Machine Learning Developer!_](https://discord.gg/QKEq8fY)

Enjoy keeping up with what’s happening at [STRATZ](https://stratz.com/)? Follow us on Medium, Twitter, or Facebook to get a new Supdate most Fridays! If you want to get more involved, join us on Discord!

**Did you miss our last Supdate?** [_Take a look at the massive new Leagues experience on STRATZ!_](https://medium.com/stratz/dota-2-leagues-cbb8e316ac4)

See you soon!

[Eric Phy](https://discord.gg/zMY9X7g)

[

## Written by STRATZ

](https://medium.com/@stratz?source=post_page---post_author_info--9a4280f34d62-----------------------------------------)

[229 followers](https://medium.com/@stratz/followers?source=post_page---post_author_info--9a4280f34d62-----------------------------------------)

·[4 following](https://medium.com/@stratz/following?source=post_page---post_author_info--9a4280f34d62-----------------------------------------)

Advanced Esports Analytics

[

## Published in STRATZ

](https://medium.com/stratz?source=post_page---post_publication_info--9a4280f34d62-----------------------------------------)

[68 followers](https://medium.com/stratz/followers?source=post_page---post_publication_info--9a4280f34d62-----------------------------------------)

·[Last published Oct 27, 2023](https://medium.com/stratz/top-8-teams-meta-at-ti12-lb-7a1494ec7843?source=post_page---post_publication_info--9a4280f34d62-----------------------------------------)

STRATZ provides free player data and statistics for Dota 2.

## No responses yet

Write a response

[

What are your thoughts?

](https://medium.com/m/signin?operation=register&redirect=https%3A%2F%2Fmedium.com%2Fstratz%2Fimp-is-back-9a4280f34d62&source=---post_responses--9a4280f34d62---------------------respond_sidebar--------------------)

## More from STRATZ and STRATZ

[

See all from STRATZ

](https://medium.com/@stratz?source=post_page---author_recirc--9a4280f34d62-----------------------------------------)

[

See all from STRATZ

](https://medium.com/stratz?source=post_page---author_recirc--9a4280f34d62-----------------------------------------)

## Recommended from Medium

[

See more recommendations

](https://medium.com/?source=post_page---read_next_recirc--9a4280f34d62-----------------------------------------)

[

Help

](https://help.medium.com/hc/en-us?source=post_page-----9a4280f34d62-----------------------------------------)

[

Status

](https://status.medium.com/?source=post_page-----9a4280f34d62-----------------------------------------)

[

About

](https://medium.com/about?autoplay=1&source=post_page-----9a4280f34d62-----------------------------------------)

[

Careers

](https://medium.com/jobs-at-medium/work-at-medium-959d1a85284e?source=post_page-----9a4280f34d62-----------------------------------------)

[

Press

](mailto:pressinquiries@medium.com)

[

Blog

](https://blog.medium.com/?source=post_page-----9a4280f34d62-----------------------------------------)

[

Store

](https://medium.com/store)

[

Privacy

](https://policy.medium.com/medium-privacy-policy-f03bf92035c9?source=post_page-----9a4280f34d62-----------------------------------------)

[

Rules

](https://policy.medium.com/medium-rules-30e5502c4eb4?source=post_page-----9a4280f34d62-----------------------------------------)

[

Terms

](https://policy.medium.com/medium-terms-of-service-9db0094a1e0f?source=post_page-----9a4280f34d62-----------------------------------------)

[

Text to speech

](https://speechify.com/medium?source=post_page-----9a4280f34d62-----------------------------------------)

## Be the first to hear about new stories from STRATZ

#### Join Medium for free to get updates from STRATZ sent right to your inbox.

Your email

Remember me for faster sign in

Already have an account? 

By clicking "Create Account", you accept Medium's [Terms of Service](https://policy.medium.com/medium-terms-of-service-9db0094a1e0f?source=register-----9a4280f34d62-----------------7cae98607604----subscribe_to_author--------------------) and [Privacy Policy](https://policy.medium.com/medium-privacy-policy-f03bf92035c9?source=register-----9a4280f34d62-----------------7cae98607604----subscribe_to_author--------------------).

This site uses reCaptcha and the Google [Privacy Policy](https://policies.google.com/privacy?source=register-----9a4280f34d62-----------------7cae98607604----subscribe_to_author--------------------) and [Terms of Service](https://policies.google.com/terms?source=register-----9a4280f34d62-----------------7cae98607604----subscribe_to_author--------------------) apply.

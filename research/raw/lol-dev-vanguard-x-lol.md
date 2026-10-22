# /dev: Vanguard x LoL

<https://www.leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol/>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://www.leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol/#c0596b52-d1a0-463e-b84f-5bf8487aaea9)

-   Targeted Advertising
-   Personalisation
-   Analytics

  

Storage Preferences

[

Game Overview

](https://na.leagueoflegends.com/en-us/how-to-play/)

[

League of Legends Classic

](https://www.leagueoflegends.com/en-us/classic/)

Champions

[

Patch Notes

](https://na.leagueoflegends.com/en-us/news/tags/patch-notes)

[

Support

](https://support.riotgames.com/riot/)

[

PBE

](https://www.leagueoflegends.com/en-us/pbe/)

More

[Game Overview](https://na.leagueoflegends.com/en-us/how-to-play/)[League of Legends Classic](https://www.leagueoflegends.com/en-us/classic/)[Champions

](https://www.leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol/#)[Patch Notes](https://na.leagueoflegends.com/en-us/news/tags/patch-notes)[Support

](https://support.riotgames.com/riot/)[News

](https://www.leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol/#)[DISCOVER

](https://www.leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol/#)[PBE](https://www.leagueoflegends.com/en-us/pbe/)

PLAY NOW

PLAY NOW

# /dev: Vanguard x LoL

Riot’s Vanguard comes to League.

[Dev](https://www.leagueoflegends.com/en-us/news/dev/)

mirageofpenguins

4/11/2024

## The "How" and "Why" of Anti-Cheat

It's getting to be about that time, and I must once again extend to you our quadrennial anti-cheat greetings. I'm "mirageofpenguins," an anti-cheat artisan with lifetime 85 million bans served, and I'm manifesting today to talk to y'all about Vanguard.

You actually may've already suffered through our LoL anti-cheat literature in the past, and here is some of [the recommended prerequisite reading](https://www.leagueoflegends.com/en-us/news/dev/dev-anti-cheat-in-lol-more/). Feel free to skim through it, but this material is now known to the state of California to cause bone lengthening and will not be on this semester's midterm.

The news of [Vanguard in LoL](https://www.youtube.com/watch?v=9U_jEzKf0_0&t=733s) was certainly divisive—after all, the majority of players aren't cheating, and no one is exactly thrilled at the notion of installing more stuff solely because cheaters can't figure out how to fight fair. Anti-cheat is a shadowy game, and the darkness we usually operate in has the unfortunate side-effect of generating a lot of confusion, concern, and frankly, misinformation.

So strap in, and we'll try to shine the brightest light possible on just how Vanguard gets the job done. This one's a little long, but I promise I put a few pictures in it.

### Cheating in League 101

League of Legends is a _fairly_ secure video game. The server simulates the entirety of the game state, and the client is really only responsible for making "requests" to it. Often referred to as an authoritative model, it essentially means that our server is the final arbiter of truth, and things like "sending spells on cooldown" _should_ fail once we've added enough server validation. This is why we don't see as many [exploits](https://www.youtube.com/watch?v=MXKhutUIwkA) anymore, and instead, most cheaters resort to input automation, or more colloquially, "scripting."

Scripting developers create platforms that are essentially wrappers for the LoL client. They rebroadcast the game as an event stream and allow the end-user to create (or more likely, copy and paste) a selection of "scripts" that automate certain behaviors in response to these events. The end result is usually a frame-perfect Zeri kiting on what appears to be a near-lethal dose of caffeine or a god-touched Cassiopeia that, through the power of prayer, has been rendered untouchable by any skillshot. It's not fun to play against cheaters, and worse, once you know scripts are out there, it's hard not to suspect other players of using them.

### Scripter Persistence

Our first problem is that cheating is addictive, and scripters are _persistent_. LoL is a free-to-play game, and one ban is never enough. Regular suspensions have stood up a saturated secondary account market, and the barrier to reentry is only the cost of a fresh level 30, which at the time of this article is about $1.99 with a side of large fries. This type of quantity-over-quality pricing strategy is made possible, because—you guessed it—the accounts themselves are leveled by scripting applications, resulting in a loop that allows cheaters to iterate against us indefinitely.

An examination into the average scripter's total lack of desire to get good is best visualized in an antiquated medium known by today's historians as "The Line Graph," and the one pictured above is a percentage of LoL games played with at least one cheater or botter in them. As always, I've graphed the number of accounts banned on the second y-axis, so that you may see the volume and taste their pain.

Throughout 2023, the lovable rascals on our anti-cheat team have been sneaking detections into the LoL client that offer glimpses into the size of the scripting epidemic. These cheeky security maneuvers, also called "honeypots" or "spicy values," only work once, as any bans issued on them will be met with excess scrutiny, followed by their immediate discovery in cheat communities. We only have so many tricks up our sleeves, so this pattern is about as sustainable as bunker fuel. However, we now have access to mankind's greatest weapon: Statistics.

In recent months, as many as **1 in 15 games globally has had a scripter or botter in it**, but in some regions, this number is as high as 1 in 5. Cheating isn't really region-specific, cheaters just go wherever cheating is easiest. In eastern countries, we see higher rates of scripting, because they're getting spillover from cheaters in China and Korea, both of which have region-exclusive anti-cheats and more importantly, identity requirements for gaming from their regional governments.

It's only worth making cheats if there's glory worth stealing, so _attempts_ at cheating are actually the sign of a successful competitive environment. However, this is far too many for a game with Olympic-level ambitions, and if we want the win to mean something, we must protect its integrity.

### Scripter Effectiveness

The second problem is that scripting is rather effective, and to their credit (if you can call it that), scripters have gotten quite good at playing without the use of their hands. When piloted optimally, scripter win rates hover around 80% in Ranked games, continually propelling their unyielding supply of accounts through the ladder.

As scripting volume increases, we're starting to see stratification of their distribution amongst the tiers again, with bias towards higher ranks. It's also important to me that you know I personally digested and averaged the ranked regalia icons for the hex colors that rendered this masterpiece. It took me over an hour, and my eyes won't stop watering.

The polyphonic rainbow you're now bearing witness to is the percentage of Ranked games completed with a cheater, bucketed by what tier the scripter was in at the end of the game. You are reading that correctly, **more than 10% of Master+ games had a cheater in them**. Even Challenger, which we manually audit on a regular cadence, has suffered from a significant number of cheaters. Statistically, this is what analysts might refer to as a "Bad Line," and we're seriously not jazzed about the trend.

Worse still, we can't see how that trend continues, because **the current anti-cheat is beaten**.

### Packman (Not a Typo)

For all the reasons we're about to get into, we didn't want to push the Vanguard button until we absolutely had to, so up until now, League has been surviving (for nearly six years) on an anti-tamper called "Packman." However, due to an unrelenting volley of cheats and bans, the anti-cheat technological space moves at recursive lightspeed. After factoring in for hyperbaric time-dilation, the resulting bistromath makes Packman roughly 250 million "cheat-years" old, pushing the pre-mesozoic boundary.

Packman's primary objective is to make analysis of the game binary more difficult, and this includes "hiding" the anti-cheat detections that it appends to a game client. The problem is that dumping the deobfuscated game binary and bypassing the anti-cheat checks are now something closer to a training exercise, and it's one that's only been made potentially easier by the [breach earlier last year](https://twitter.com/riotgames/status/1617900234734198787). Packman was never meant to last this long, and iterating on it has become prohibitively expensive.

According to the publishing department, use of a log y-axis is apparently a crime of the same magnitude as witchcraft, so to assist in the comparison, I've removed "honeypot" type detections from the graph above. Remaining are only bans issued or reviewed in the old packman system.

This chart attempts to visualize our emotional turmoil, though its true intensity could never be captured in two-dimensional form. Pictured are weekly LoL scripting bans, bucketed based on those issued for a detection within Packman (blue), versus those that were banned "manually" (reviewed by an anti-cheat agent). As Packman's effectiveness wanes, we are unable to keep up with the scripting "demand," and an infinite number of hands reviewing an infinite number of scripters is not a strategically viable option. **If we want a fair video game, we must upgrade.**

## Enter Vanguard

Like most anti-cheats, Vanguard is made up of preventative and detective layers. We endeavor to outright block as many cheating methods as possible, but in gap areas where "preventing" a cheat locally (and obviously) would too easily allow our vector to be audited, we instead passively "detect" the intrusion and take action on a delay. Putting our darkest detection magic behind the scrutiny of our server gives us the opportunity to hide our methods by occluding signals to the developer through seemingly arbitrary bans. This mouthful is often called "the cat and mouse game," and it's an absurd waltz that every anti-cheat developer worldwide steps to on the daily.

### Best Anti-Cheat is Fastest Anti-Cheat

By uncoupling ourselves from the game client and moving more of Vanguard to the server, we can deliver different "checks" to riskier players, making our intrusion detection far more targeted and _much faster_.

"Time-to-action" is the number of games a cheater is able to complete before their account slips into the dimension between worlds. It's not perfect for a variety of reasons, but I count myself among the lucky few with an opportunity to A/B test user-mode and kernel-mode anti-cheats.

To demonstrate, here is a graph of "Time to Action" on both games, though it's not a totally fair comparison. Cheating is far, far more sophisticated in first person shooters, so even though LoL games are shorter in duration, League was already heavily favored to win this race. However, because of Vanguard's aerodynamic design (and the speed at which it can be adapted), it has become so large a chore to stay undetected that most cheaters _don't even bother_. Instead they rage for a few games and get banned, just as nature intended.

### Environment Security

Where Vanguard starts to further distinguish itself from other anti-cheats is in its enforcement of security standards even further to the left of the game client—on the operating system itself. Several of these requirements aren't totally frictionless, but they inflict many hurdles onto those that want to distribute cheats successfully. For this reason, we're constantly having to make tradeoffs for the security of the game versus the ease with which players can access it.

### TPM 2.0

LoL x Vanguard comes with a TPM 2.0 requirement, and while Microsoft originally intended to require one for all new Windows 11 installations, their actual implementation of this enforcement was relatively weak and easily bypassable. We took them up on their original offer and instead elected to enforce it ourselves. So, a select few Windows 11 users may find their ability to play League is impacted, especially if you modified registry keys to bypass this requirement.

TPM stands for "Trusted Platform Module," and we require it for two reasons. The first is because it adds security to cert signing validation (something we rely on to know if other software can be trusted), but the second (and more important), is because **it acts as an extremely non-fungible form of hardware ID**. If it's on and working, we can pretty much assume you don't intend to cheat, because if you did, we could easily banish the chip from this realm forever. 

For more details on how to enable TPM, please see [this helpful support article](https://support-leagueoflegends.riotgames.com/hc/articles/24170417829651).

### The Driver

Anti-cheat drivers are not new, and we didn't invent them. The purpose of [our driver component](https://www.leagueoflegends.com/en-us/news/dev/dev-null-anti-cheat-kernel-driver/) is not to collect more information—we can already see everything we need to from user-mode. Instead, **Vanguard's primary goal is to confirm the game is currently running in an environment we can trust**. This reduces the number of detections we have to create, the amount of data we have to collect, and most importantly, the ease with which any prospective cheater can access the game.

We want to move as much of our anti-cheat into a "preventative" pattern as is feasible (and safe). Windows is easily corruptible, and the current threat landscape necessitates that we validate its defenses ourselves. We need to be able to trust what the operating system is telling us about the VALORANT process, otherwise cheaters could compromise it, middleman our checks, eat hot chip, and "lie" that everything is good to go.

"Hardware" indicates that the account was detected immediately as a re-offender, "Manual" references an account that had to be reviewed by an agent before it was suspended, and "Detection" is exactly what it sounds like—a ban that occurred with an explicitly detected cheat asset. They're colored by "speed," and manual is still our least favorite.

Our final timeline of the evening is a look at VALORANT's percent of Ranked games with a cheater, beautifully contrasted to dishes served by the Vanguard kitchen. Even when the going gets rough, Vanguard's hardware identifiers and system requirements help us hold down the fort, but what this really highlights is everything we're missing today in League of Legends. LoL's existing anti-cheat has no attestation or environment components—it's all "detection" or "manual."

Through the friction of its checks to host security, Vanguard drives up the cost of repeatedly cheating. Sure, a cheater can still put their harddrives through the dishwasher's sanitize cycle or manually map their own code into kernel memory (I dare you to try either), but the point is that these things cost cheaters money and _time_.

### Why is it _always_ on?

**Vanguard is not really "running all the time."** The driver loads at boot, but nothing is making calls to it, and there's no network connectivity until you run one of Riot's games. It's literally just sitting there (menacingly), so that it can attest to the fact that nothing's happened between Windows loading and the game starting that would break the operating system.

When you launch League, the Vanguard client contacts the driver to confirm that it thinks everything is 100%, and if so, you receive a valid anti-cheat session and may connect to the game server. Instructions from the client then start enabling features within the driver to watch for things that might tamper with the signed League process and prevent them. You can always disable the driver whenever you'd like-you'll just need a fresh reboot to "recertify" the integrity of the trust chain before you jump into game.

## LoL x Vanguard

As Vanguard rolls out to League, we'll see a dramatic decrease in the number of cheaters, but the fun doesn't have to stop there.

With heightened VM prevention, we'll drive up the cost of botting and inflict significant friction onto re-offenders. Bot supply for boosting accounts will dry up, and bypassing bans will no-longer be "buy another level 30." With its device fingerprinting, Vanguard also gives us a renewed opportunity to sink teeth into boosting, smurfing, and account compromise. We'll be able to revoke rewards boosters didn't deserve, get smurfs to their proper rating faster, and maybe even invalidate "unfair" premades.

Increased client security and less scripting means that the League team will be able to leverage more mechanically rewarding designs, like combos, timing windows, and executes. Ranked statistics won't be as poisoned by scripters, facilitating easier balancing of high risk-and-reward champions, and games ruined by cheaters can eventually be "undone," returning LP to those affected.

_I know_ it's hard to be delighted about new anti-cheat, but this is the hardest part. It's only up and to the right from here.

## Until Next Time

The Vanguard team is now almost thirty people, up nearly 1000% from the tight three it was when we got started in 2014. We've in-housed everything from our data pipeline to our cheat reconnaissance, and members of this team pour everything they have into creating the most fair gaming experiences physically possible. Some of our successes have come from technical innovation, but a much larger percentage of it has just been raw, unrelenting effort. Cheaters are **always** working against us, and our diligence is only possible with the player's support.

Thanks for reading, thanks for playing, and thanks for helping a few silly ex-cheaters find a greater purpose.

## F.A.Q.

Welcome back. These next few questions didn't really belong anywhere else, but they've been included below for avid readers—primarily so that they may consume all of the knowledge we have to spare. I'll warn you that my _marvelous_ editor explicitly ignored this part with a "it's your funeral," so if your eyes continue past this line, you're signing up for unfiltered madness. This was your only warning.

### Q. Isn't Vanguard Spyware?

No, but I'm sure those words in that exact order are mathematically the fastest way to farm retweets. Content algorithms everywhere are programmatically addicted to the clicks the words "spyware" or "rootkit" can generate, and mathematically hunting for their next fix has steered them away from informative journalism and into a sort of faux-pandemonium that's only remarkable in its unhelpfulness.

Each region must adhere to its own specific policy and regulatory requirements. Tencent, for example, has their own anti-cheat for games operated in their region, including Riot's titles, for which they are the CN publisher. While we do share the cheats we find so that our respective teams can make detections for them, we have no need to share anything else. We've met with Tencent's anti-cheat team maybe three times in a decade, and the only things we exchanged were high-fives and ban counts (they won both contests). We don't share Vanguard or its code, and anti-cheat data has never left Riot's warehouse.

### Q. Why do we need anti-cheat?

I do hope that this article made at least a small dent in the polycarbonate wall that is this question. But to further wax philosophical: improving in League is like learning an instrument, and you get better at it through cold, hard practice. Now, I personally haven't had this experience (15 years and never even put a toe past platinum), but the whole point is that **_you could_**. The only things you should need to be competitive are your brain, an ethernet cable, and a backlit input peripheral.

Practice is time-consuming and shortcuts aren't. What if instead of getting good, you could pay someone to press the buttons for you? And what if instead of pressing the buttons, you could program your toaster to play the game? What if instead of playing the game, you just bought a trophy that said "The Greatest" on it? These things break the meritocracy, reduce satisfaction, and eliminate any competitor's incentive to truly compete. We want the win to be earned, and we want it to mean something to you when it is.

### Q: What about Linux?

We've never officially supported Linux, and it's true that the current Lutris-based implementation for League (that uses wine) will not be able to satisfy the Vanguard driver requirements. Linux does not currently afford us sufficient ability to attest boot state or kernel modules, and the difficulty in securing it is only compounded by all the frustrating differences between distributions. Even allowing emulation is an exceptionally dangerous game, as many cheats could then just run on the host, manipulating or analyzing the VM in a way that would be invisible to Vanguard within it.

Half of anti-cheat is making sure the environment hasn't been tampered with, and this is extremely hard on Linux by design. Any backdoors we leave open for it are ones developers will immediately leverage for cheats, and yesterday, there were just over 800 Linux users on League. We have evaluated this risk to not be worth the payoff.

### Q: Have you tried just asking cheaters nicely to stop?

We once let cheaters submit [hand-written apologies](https://twitter.com/deteccphilippe/status/1185351542766915586) for unbans. Some promised to stop, many stiffed kids on Fiverr to write their apology for them, and 91% of the unbanned accounts were banned again for scripting within the next 6 months. This enemy cannot be reasoned with, and our best defense is preventing their attempts until they've had sufficient time to develop empathy.

### Q: I've heard that Vanguard bricks keyboards?

At launch (in 2020), we made the decision to have Vanguard utilize its on-boot positioning to prevent known signed-but-vulnerable drivers from loading in their entirety. This was only so cheaters couldn't load (or leverage cracked services to load) their own drivers, and in turn, subvert Vanguard. However, what we hadn't discovered in the compatibility lab (or even in the alpha test) were extraordinarily specific hardware configurations utilizing bespoke, broken kernel drivers to communicate instructions to relatively obscure devices.

In one infamous case, this included a driver that was responsible for keyboard lighting. Cheaters unfortunately were able to use this otherwise properly signed driver to load their own malware, allowing them to "look" like a clean windows installation (with cert verification still enabled), yet still be running kernel-level cheats. Because this driver was only for keyboard lighting and macros, we kept the driver denylisted until the developers released a new one, and in the process, got ourselves a reputation for hating keyboard backlights—which admittedly is true (we prefer darkness).

### Q: What about false positives?

Players claiming a "false ban" are in one of seven categories, ordered here by likelihood:

1.  They are presenting a fictional narrative.
2.  They tested a cheat on a smurf, poisoning their main through hardware linking (known internally as "whoopsie daisies").
3.  They shared their account with someone who cheated, usually a paid boosting service or a relative.
4.  They repeatedly queued with a booster that used cheats and ate a 180 day ban for their trouble.
5.  Their account was stolen by a serial rage hacker, who used it to torture other players for exactly 6 games.
6.  They used cheating software for another game, and Vanguard unfortunately picked it up.
7.  They have malware installed that performs the same operations as a cheat.

In the account compromise cases, we try to place protective suspensions on the accounts, though we are not always fast enough. Sometimes the damage is too great a percentage of the account's playtime, and it becomes too difficult to identify any sort of "true" owner. With hardware-level cheating, we can't always tell which game you intended to cheat on, so it's our firm recommendation that you just not cheat on any game. For genuine false positives (usually caused by malware), we completely "revert" the rule that caused them after analysis, undoing all bans that originated from a bad asset. This does _infrequently_ happen, but it's exceedingly rare that such suspensions last longer than a few days.

To request an audit of a suspension, please [submit a ticket](https://support-leagueoflegends.riotgames.com/hc/en-us/requests/new), and if you don't get the answer you were looking for, it indicates only that the account was ruled to be one of the first 6 cases.

### Q: Why not just sue the cheat developers?

Oh for sure we [do that when we need to](https://www.gamedeveloper.com/business/riot-awarded-10-million-following-lawsuit-against-leaguesharp), and our legal team couldn't be more hype to defend Riot's experiences. But with Vanguard, few developers have had the persistence necessary to ever warrant it. Most don't attempt bypasses, and those that do usually give up after sheepishly returning one or two basic anti-cheat volleys. The unrelenting exit scams also kinda do the hard work for us by sowing distrust in the cheating community and reducing the likelihood that larger resellers ever really become a problem. With the right anti-cheat posture, it's rare that sufficient business forms around any one provider to justify a lawsuit. Right now, the majority of our legal efforts are directed towards advertisements for malware masquerading as an aimbot.

### Q: Why not create a game mode for cheaters?

"Cheater's Island" sounds very amusing, but we have chosen instead to spend all our engineering time on just preventing the cheats in the first place. We don't have infinite money, and using resources for in-game features that exist solely to torture the cheaters we've already caught would kinda take the "anti-" out of "anti-cheat." However, should my budget quintuple, you will again find me advocating for cheaters to be grounded. I will call your parents for a gamer-developer conference. Forget about hardware bans, guess who's not going to senior prom? Please contact your local member of congress.

### Q: What about OSX?

There isn't yet as much tooling on OSX for script development, although the "need" is growing. For now, Mac won't have Vanguard, but we've still got a few bullets in the chamber for when cheaters inevitably try to exploit this. It has since been pointed out to me that each chamber can hold only one bullet. I reject this hypothesis on the basis of improved throughput. Why shouldn't we fire two bullets at once? 2x the damage with the same amount of reloads. Wake up gunsmiths.

### Q: Does Vanguard break 3rd party tools?

Developers [not using the official APIs](https://www.riotgames.com/en/DevRel/vanguard-faq) will find it difficult to continue exfiltrating information directly from client memory, primarily because that's exactly what cheats do. One of the key concerns with allow-listing specific tools is that we are then responsible for their security when cheats seek to leverage them, so it is our vast preference that everyone just use the API. If tools choose to read client memory anyway, we make no guarantees that it won't break. In fact, we promise to deliberately break it as often as possible.

### Q: Why not AI Anti-Cheat?

We do use machine models to predict the likelihood that a player is cheating, but using only data the game server receives does not currently afford us the granularity necessary to detect "informational" cheats that do not modify player input—ESPs, FoW leaks, and radar hacks are almost totally undetectable. VALORANT and LoL both rely heavily upon the art of gathering or obscuring information, so cheats like these are very damaging, ultimately necessitating traditional anti-cheat anyway.

And even solely for aimbots, recall just isn't that great. The best models can only identify around 30-50% of cheats on server-sided player input alone, and this is not sufficient for a free competitive game with literally no barriers to reentry. Worse, aimbot developers have already started offering "humanization" features to prevent player reports, and while they're still mostly goofy pseudo-random noise generators, at some point, a particularly enterprising young cheater will spend the weekend training a model to "move the mouse like it's a real boy." Honestly, I wouldn't be surprised to see this exact white paper in the next six months, probably titled "Operation Geppetto."

### Q: Why not open source the driver?

Anti-cheat is an iterative, indefinite battle. Many of the preventative checks that Vanguard makes to ensure system integrity are deliberately stealthy, bleeding-edge, and in some cases, built on total pillars of sand. We benefit extensively from the confusion that the system inflicts on cheaters, and letting them simply browse the detection methods would exhaust our supply faster than we could invent new ones. An [open source anti-cheat application](https://github.com/RiotVanguard/Vanguard) would be totally useless (April Fools 2021).

### Q: What if I'm having technical issues with Vanguard?

These days, Vanguard suffers from a lot of attribution bias, and the majority of bugs we see actually come from external sources that are difficult to lock down. One of the largest perpetrators recently has been the distribution of pirated software that toggles a registry option ("DevOverrideEnable") and allows "different" versions of key Windows files to be loaded into all running processes. Now, we can't say exactly what your intentions would be for doing something like this (wink), but what we can say is that Vanguard doesn't like when corrupted windows files are loaded into VALORANT—we use a great many of them to do tampering checks ourselves. We'd also recommend that you be careful what you turn off windows defender for, because it's doing what it says on the tin (_defending_ windows).

Anyways, issues can arise, but please [submit a ticket](https://support-leagueoflegends.riotgames.com/hc/en-us/requests/new). We'll get you sorted.

### Q: If Vanguard is so good, why do I still see cheats on VALORANT?

For starters, we do not action every cheat or account instantly. Every ban is like broadcasting a signal to the developer that their cheat has been detected and that they need to "update" it. In order to slow the progression of our "cheat arms race," we delay bans based on the sophistication and visibility of the cheat and cheater, respectively.

But also, cheaters gonna cheat. We've really driven our preventative layer as far as we can feasibly go without colliding with existing setups and hurting legitimate players. We'll detect them soon enough, but not before they snap a video and repeatedly drop it on TikTok for the highest ad-to-malware clickthrough rate ever before realized. And just because it says "live," does not mean you're watching a live stream. Don't download garbage.

### Q: Does Vanguard do anything to help with DDoS?

There are (generally) three types of drophacks: (1) DDoS replay attacks targeted at the server, (2) DDoS UDP flooding targeted at other users, and (3) malformed server packets. None of these are clever, and there's no need to be impressed. Vanguard is client-sided anti-cheat, so it gives us detection on the tooling required to exfiltrate traffic for the former, and prevention to the hooks on our packet handler usually used for the latter. For DDoS attacks that target users at home, Vanguard doesn't have much to offer—local software cannot prevent network elements from being overwhelmed.

### Q. Why can't we just put Vanguard in Vietnam only?

That would just make all of those scripters move to the Philippines.

### Q. Why can't we just put Vanguard in Vietnam and the Philippines only?

Then they'd move to Singapore.

### Q. Why can't we put Vanguard in Vietnam, the Philippines, and Singapore only?

Cheating is not a regionally-specific problem. Most of our servers are not geofenced, and even if they were, tunneling is a google search away. Cheaters cheat without borders, and this thought exercise was brought to you by Anti-Cheat Airways.  

### Q: What if I am personally incompatible with Vanguard?

We get it, and we 100% respect your decision. Hopefully one day soon, the platforms our games run on will offer developers the security features required to prevent cheating without necessitating extracurricular software. However, if your beef is only about data privacy at Riot, running the game client or running Vanguard makes not one bit of difference. Data can still be retrieved from user-mode, and we're all engineers for the same studio with the same goals, none of which are collecting your personal information. If Riot hasn't earned your trust, do not run our software.

### Q. What personal information does Vanguard collect?

Riot only collects what we need to run and secure our games. More data is just more risk for us, and we don't want anything except the bare minimum required to get the job done. Locally, Vanguard has system hooks to run its protections, but we're not shipping back your files or documents. Like most anti-malware and anti-cheat systems, we leverage a technique called "Signature Scanning," to determine if a series of bytes in memory matches a known cheating application. The results of these are only true or false (it was present or it wasn't), and we try to use this pattern for other checks too. Things like, "are you currently using a DMA device" or "did an application just try to submit input to the game" send mostly binary responses (though the latter includes the name of the process that did it).

For other detections, we need snapshots to scrutinize in post, and there are chances that these can contain PII. For example, we log the file path of every library loaded into League, and this could contain a user name (if it's in a user folder). We do things like this so that, after a cheat is discovered, we stand a chance to detect cheaters who have already used it (instead of only those moving forward). This type of data is only in "warm" storage for 14 days, and we will never use it for anything that is not cheat detection. I can't tell you every single thing Vanguard looks at, as cheaters would then know what areas to scrub the hardest. We need some obscurity to succeed, but I hope this makes our intentions with the data we do collect more clear.

### Q: What is the phrase that sends you back to the pain dimension?

Nice try, Asmodeus.

* * *

## Related Articles

1.  [
    
    Dev
    
    10/20/2026
    
    /dev: Mel Midscope
    
    We’re updating Mel, and here’s the how and why.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/dev-mel-midscope)
2.  [
    
    Dev
    
    10/14/2026
    
    /dev: League Classic
    
    What’s changing with League Classic.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/dev-league-classic)
3.  [
    
    Dev
    
    9/8/2026
    
    Dev Update: Team Voice, Classic & More
    
    Pabro, Meddler, FeralPony, and Phreak talk about Team Voice, Classic, Mayhem, Ranked 5s, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=9vrcrlJqqvY)
4.  [
    
    Dev
    
    9/8/2026
    
    TL;DW: Team Voice, Classic & More Dev Update
    
    A short rundown of changes from today’s Dev Update.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/tldw-team-voice-classic-more-dev-update)
5.  [
    
    Dev
    
    7/14/2026
    
    TL;DW: Classic, Mayhem & More Dev Update
    
    A short rundown of changes from today’s Dev Update.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/tldw-classic-mayhem-more-dev-update)
6.  [
    
    Dev
    
    7/14/2026
    
    /dev: League of Legends Classic
    
    Welcome back, Summoners.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-us/news/dev/dev-league-of-legends-classic)
7.  [
    
    Dev
    
    7/14/2026
    
    Dev Update: Classic, Mayhem & More
    
    Pabro, Meddler, FeralPony, and Phreak talk about Classic, Mayhem, Hall of Legends, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=KV1ArTWlEFU)
8.  [
    
    Dev
    
    6/26/2026
    
    200 YEARS OF EXPERIENCE
    
    Pabro has a breakthrough, he just needs Meddler on board.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=fTH-CylOvcc)
9.  [
    
    Dev
    
    5/27/2026
    
    Dev Update: Mayhem, Ranked 5s & More
    
    Pabro, Meddler, Phlox, and Cadmus talk about ARAM: Mayhem, Ranked 5s, skins, MSI, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.youtube.com/watch?v=3_0h_vuIKv4)

-   [ABOUT LEAGUE OF LEGENDS](https://na.leagueoflegends.com/en/game-info/get-started/what-is-lol/)
-   [Server Status](https://status.riotgames.com/?locale=en_US&region=na)
-   [Support](https://support.riotgames.com/riot/)
-   [Esports Pro Site](https://www.lolesports.com/en-US/)
-   [Download Riot Mobile Companion App](https://www.riotgames.com/en/riot-mobile-download)

-   [Youtube](https://www.youtube.com/user/riotgamesinc)
-   [Twitter](https://twitter.com/leagueoflegends)
-   [Facebook](https://www.facebook.com/leagueoflegends)
-   [Instagram](https://www.instagram.com/leagueoflegends/)
-   [Reddit](https://www.reddit.com/r/leagueoflegends/)

™ & © 2026 Riot Games, Inc. League of Legends and all related logos, characters, names and distinctive likenesses thereof are exclusive property of Riot Games, Inc. All Rights Reserved.

-   [Privacy Notice](https://www.riotgames.com/en/privacy-notice)
-   [Terms of Service](https://www.riotgames.com/en/terms-of-service)
-   [Cookie Preferences](javascript:void\(0\);)

Blood  
Fantasy Violence  
Mild Suggestive Themes  
Use of Alcohol and Tobacco  
Online Interactions Not Rated by the ESRB

# Ask Riot: Is ARAM Really Random?

<https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-is-aram-really-random/>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-is-aram-really-random/#2cc5c466-98f9-468b-af48-35416ce38bcc)

-   Targeted Advertising
-   Personalisation
-   Analytics

  

Storage Preferences

[

Game Overview

](https://www.leagueoflegends.com/en-gb/how-to-play/)

[

League of Legends Classic

](https://www.leagueoflegends.com/en-gb/classic/)

Champions

[

Patch Notes

](https://www.leagueoflegends.com/en-gb/news/tags/patch-notes)

[

Support

](https://support.riotgames.com/riot/)

More

[Game Overview](https://www.leagueoflegends.com/en-gb/how-to-play/)[League of Legends Classic](https://www.leagueoflegends.com/en-gb/classic/)[Champions

](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-is-aram-really-random/#)[Patch Notes](https://www.leagueoflegends.com/en-gb/news/tags/patch-notes)[Support

](https://support.riotgames.com/riot/)[News

](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-is-aram-really-random/#)[DISCOVER

](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-is-aram-really-random/#)

PLAY NOW

PLAY NOW

# Ask Riot: Is ARAM Really Random?

How Your Shop works, Bilgewater botany, and how we make sure you don’t get two Lux’s in one ARAM.

[Dev](https://www.leagueoflegends.com/en-gb/news/dev/)

Riot Scathlocke, Riot Mojibake, Riot Aryeila

25/03/2021

## Welcome to Ask Riot

This week, it’s flowers, Your Shop, and ARAM.

Also, **please** [**send us all your questions**](https://www.surveygizmo.com/s3/5477715/Ask-Riot)**!** Each question helps [feed a hungry poro](https://www.youtube.com/watch?v=5dvYxkyQFZU&t=33s).

* * *

## Does "Your Shop" randomize what skin you get when you press the button, or is it predetermined?

The skins in Your Shop are specially picked for you long before you hit that button! We actually dive into the details behind how your offers are selected and personalized in the Tech Blog article [Stocking Your Shop with Data Science](https://technology.riotgames.com/news/stocking-your-shop-data-science)—check it out if you’d like to know more.

**Riot Aryeila, Senior Editor**

* * *

## What are the flowers like in Bilgewater? If any grow there.

Bilgewater itself is just one (large and grimy!) city, nestled away in the Serpent Isles. Since the population of _paylangi_ outsiders is crammed in pretty tightly in their wooden shanties, there’s not much room for plants and wildlife—but wild tropical blooms definitely sprout up wherever they can, especially among the ruins of the older Buhru architecture. I imagine you might see particularly colorful lily or lotus flowers, as well as far less pleasant specimens like flytraps, or worse...

But Bilgewater is a thriving port, and you can usually buy pretty much anything you want, if you have enough coin. I’m not going to actually use the words “black market florist,” but I bet you could find someone in Bilgewater who could hook you up with whatever you’re looking for, even if it takes weeks or months to arrive. Roses from Noxus? Dried spirit blossoms from Ionia? Hop vines from Demacia? All this and more can be yours, for the right price.

But such things are generally considered pretty frivolous to the average citizen, and it’s probably only the wealthiest ship captains who could ever hope to maintain anything as ostentatious as a _garden_, in their private residences high, high up above the quays, wharves, and carving bays.

**Riot Scathlocke, Narrative Editorial Director**

* * *

## Hello Riot, I have a question regarding the ARAM. Is Champ Select totally random? How do you make sure both teams don't get the same champion, even as people reroll?

The logic for ARAM’s Champ Select is in a service we call TeamBuilder. The TeamBuilder server knows what champ every player has rolled, what’s on the bench, etc., for both teams. TeamBuilder prevents any player from rolling a champion that someone else has rolled.

The League client’s Champ Select UI obediently gives you the champion that TeamBuilder tells it to give you. And when you click “Reroll,” the client tells TeamBuilder that you requested a reroll. TeamBuilder determines what champ you rolled, and tells the client, which displays it to you.

In other words, the whole Champ Select process is _server-authoritative_. TeamBuilder is in charge. And every roll, reroll, trade, bench swap, and lock-in is _transactional_. **That means it is impossible for two players to, say, reroll the same champion at the same time; TeamBuilder will carefully process one reroll, then the other**.

As for whether it is “totally random,” that depends on what you mean. Everytime you roll or reroll, the champion you get is randomly drawn from the set of available champions that you _could_ roll at that moment, but that set is not random. In [set-math terminology](https://en.wikipedia.org/wiki/Set_\(mathematics\)), it is:

((_A_ ∪ _C_ ∪ _O_) \\ _R_) \\ _D_

Where _A_ is the set of [65 always-free-to-play ARAM champs](https://euw.leagueoflegends.com/en-gb/news/game-updates/patch-10-7-notes/#patch-aram-free-to-play-rotation-and-balance-changes), _C_ is the current free-to-play rotation of champs, _O_ is the set of champs you own, _R_ is the set of champs that have been rolled by players on both teams so far, and _D_ is the (hopefully empty) set of disabled champs. In simpler terms… **You will always receive a random champion that isn’t already on a team or bench**.

The initial 10 rolls follow this process too; at the start of Champ Select, TeamBuilder simply does this once for each player, to determine everyone’s initial champion.

**Notably, champs that appeared in previous games, or even queue-dodged champ selects, have no effect on any of this whatsoever**. That means it is entirely possible to get a streak of the same champ in different games, or a streak of champs you really like, or a streak of champs you really don’t like. When that happens, [it can _feel_ like it is not random, even though it is](https://core.ac.uk/download/pdf/82644986.pdf).

So, when your mouse hovers hesitantly above the reroll button, all I can say is, “Good luck!”

**Riot Mojibake, Senior Software Engineer**

* * *

### Have a question? [Head here](https://www.surveygizmo.com/s3/5477715/Ask-Riot), drop your question in the box, and ask away.

* * *

## Related Articles

1.  [
    
    Dev
    
    29/07/2021
    
    Ask Riot: Vex’s Release Date?
    
    When’s Vex coming out? Are Prestige skins canon? And how do you say Akshan?
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-vex-s-release-date/)
2.  [
    
    Dev
    
    02/07/2021
    
    Ask Riot: Manaless Champions
    
    When are champs manaless? When are they micropatched? And can there be one place for League news?
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-manaless-champions/)
3.  [
    
    Dev
    
    17/06/2021
    
    Ask Riot: Most Pentas?
    
    Plus… Can we add Wild Rift animations to League PC? And how do we make champion theme songs?
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-most-pentas/)
4.  [
    
    Dev
    
    03/06/2021
    
    Ask Riot: More New Items When?
    
    What new items are in the works? Human skins for non-humans? Plus canon LGBTQ+ representation in LoL.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-more-new-items-when/)
5.  [
    
    Dev
    
    06/05/2021
    
    Ask Riot: Unbench the Kench
    
    The latest on Tahm Kench’s mini-update and the revival of server transfers.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-unbench-the-kench/)
6.  [
    
    Dev
    
    09/04/2021
    
    Ask Riot: Let’s Talk Clarity
    
    Hiding skins in game, Lancer Blitzcrank’s walk animation, Storm Dragon Lee Sin, and more.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-let-s-talk-clarity/)
7.  [
    
    Dev
    
    11/03/2021
    
    Ask Riot: Legendary Skins
    
    How we choose champs for Legendaries, League Displays, and fighting toxicity.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-legendary-skins/)
8.  [
    
    Dev
    
    25/02/2021
    
    Ask Riot: I Want More Bans
    
    Bot lane diversity, bans in Champion Select, and the delicious flavor of health pots.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-i-want-more-bans/)
9.  [
    
    Dev
    
    11/02/2021
    
    Ask Riot: Where’s Rod of Ages?
    
    Why we removed some items in preseason, role strength throughout the game, and MMR.
    
    
    
    
    
    
    
    
    
    
    
    ](https://www.leagueoflegends.com/en-gb/news/dev/ask-riot-where-s-rod-of-ages/)

-   [ABOUT LEAGUE OF LEGENDS](https://euw.leagueoflegends.com/en/game-info/get-started/what-is-lol/)
-   [Server Status](https://status.riotgames.com/?locale=en_GB&region=euw)
-   [Support](https://support.riotgames.com/riot/)
-   [Esports Pro Site](https://www.lolesports.com/)
-   [Download Riot Mobile Companion App](https://www.riotgames.com/en/riot-mobile-download)

-   [Youtube](https://www.youtube.com/c/UKLeagueofLegends)
-   [Twitter](https://twitter.com/LoLUKN)
-   [Facebook](https://www.facebook.com/ukleagueoflegends/)
-   [Instagram](https://www.instagram.com/ukleagueoflegends/)
-   [Reddit](https://www.reddit.com/r/leagueoflegends/)

™ & © 2026 Riot Games, Inc. League of Legends and all related logos, characters, names and distinctive likenesses thereof are exclusive property of Riot Games, Inc. All Rights Reserved.

-   [Privacy Notice](https://www.riotgames.com/en/privacy-notice)
-   [Terms of Service](https://www.riotgames.com/en/terms-of-service)
-   [Cookie Policy](http://www.riotgames.com/en/cookie-policy)
-   [Company Information](https://euw.leagueoflegends.com/en-gb/news/riot-games/riot-games-europe-company-information)
-   [Cookie Preferences](javascript:void\(0\);)

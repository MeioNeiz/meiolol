# Jacob's page by page review, 24 Oct 2026

Jacob's words below, unedited, except Riot IDs in the pasted Players block (left out:
public repo). Pasted page text is quoted as he pasted it. Plans and work from it:
docs/plan/ui-rebuild.md (once written); foundation context docs/frontend-rework.md.

## Themes across pages (index, not his words)

- Words: far too many everywhere; captions, method text, scope sentences, explanations.
  The UI should explain itself; never a long "how to read this"
- Generic UI: plain tables and lists where the data wants a purpose-built component
  (lane comparison, game stats, every pick rated, patch changes, builds, runes, pool)
- Space: first screens wasted (home, game detail, champion page beside the histogram)
- Real tables: sorting, proper table semantics, scaling
- Interaction: graph range selection and click-through moments, select an option to see
  why, role picker at the top, pool selection, tooltips where something isn't clear
- Consistency: elements reused across pages (game stats, champion and matchup pages
  complementing each other, search, dropdowns), graph markers that fit the graph style
- Colour: no colour keys ever; the numbers are the key. More colour on changes
- References: lolalytics for champion pages, runes and builds; survey other LoL sites'
  game stats and pick one to learn from
- Investment: frontend framework and components now, long term, designed from the
  ground up across pages, not page by page fixes. A plan per page first

## Review

Page by page review

your games, too many words on main page, the + and - on the graph doesnt fit the style of the rest, a way to filter moment perhaps, but yeah before you use it, there is just way too many words. Need to turn this into a more complete ui,

First page is almost too much selling, looks like an ad i just think it could use space more efficiently, be more clear and way less words.

your games detail screen, bad use of space on first screen, i quite like the your games bit but perhaps could show a little more info about the game like

```
Aurelion Sol
vs
Aurora
14/8/14
Draft
mid
41:38
23 Oct patch 16.21
```

this is too wordy, needs to be more ui based

The game turned at 35:00: your team's win chance went from 52% to 90%, with 5 kills and 2 deaths for your team, you took part in 5 kills and your team took Cloud dragon. WAAAAY too wordy, again needs to be ui elements, good use of space, clear

on the game graph the things showing the moments aren't clear, dont fit style of graph, i want to be able to highlght a range and see the moments in that range, more indepth of that part of game, and click though momenets by click on there

```
+1,402 gold your best minute, 35-36 min: 5 kills with you and Cloud dragon
+38% biggest rise, 35-36 min
98% highest, at 41:00
20% lowest, at 17:00
17 of 41 minutes ahead
```

too many words, i like the cells of like first tower but could be better too

You minus your lane opponent. Typical: Aurelion Sol vs Aurora, All games (too few games at your rank), EUW, patch 16.21, 11 solo/duo games. More data needed. too many words

this whole thing

```
Lane, first 25 min
Gold
XP
CS
+1500
0
-2500
5 min
10 min
15 min
20 min
25 min
You ahead
Opponent ahead
You minus your lane opponent. Typical: Aurelion Sol vs Aurora, All games (too few games at your rank), EUW, patch 16.21, 11 solo/duo games. More data needed.
You    Opponent    Typical    vs typical
Gold lead at 14    −768        −63    −705
below half the games
Level 6    6:31    5:15    5:39    +52s
First legendary item    11:54    10:16    11:21    +33s
CS at 10    64        ·
Deaths before 14    2        ·
Kills you took part in    2        ·
Biggest gain against the typical game, 8-11 min: 0 deaths, 0 kills you took part in
+281
Biggest drop against the typical game, 5-8 min: 1 death, 0 kills you took part in
```

Is just not interesting/enganging/thoughtful enough

```
Fight in bot: 3 for 2
You took down Karma, +381 kill gold.
+5%
medium
15:12
✕
Fight in mid: 1 for 2
You took down Karma, died to Jarvan IV, −478 kill gold, the enemy took Top inner tower.
−19%
big
19:03
⚔
Took down Karma, mid
+240 kill gold, the enemy took Bot outer tower.
+21%
huge
20:22
⚔
Took down Smolder and Karma, mid
+482 kill gold, your team took Mid outer tower.
+12%
big
22:49
⚔
Fight in enemy jungle: 2 for 3
You took down Aurora (lane), −327 kill gold, the enemy took Cloud dragon.
```

the words here arent so bad but again i think could be more clear without words, more thought put into some ui work

```
Players
Riot IDs as at the game; pick one to see their games
Your team, won    K/D/A
 Master Yi    18/16/8
 Cho'Gath    11/7/9
 Aurelion Sol    14/8/14
 Draven    8/10/11
 Shaco    2/5/24
Enemy team, lost    K/D/A
 Illaoi    8/8/6
 Jarvan IV    17/7/9
 Aurora    11/11/14
 Smolder    5/13/13
 Karma    3/14/16
```

(each row also had the player's Riot ID under the champion)

Checkout how other lol sites show game stats we could learn a lot pick the one we like best and what we like and dont like about others and make our own that matches much more similar and probably re use a lot of these elements

The highlights are good, almost still too wordy or atleast a bit hard to read rn

Friends is great, we just need to expand on this overtime, again make it less wordy, develop more advanced ui for it

the overtime bit is just a bit shit rn, not actually interesting, doesnt scale well, needs a lot of work and not even a real table so it sucks

Too many words in the your data bit too

daily draft, only do games where we have all ranks, ban icons too hard to read, too grey. Again I think this UI is lazy, bad use of space like with the 9 champions and the missing one

the sub header text is too long, it kinda explains itself, prob just not needed.

cus we cant know what was the last pick we need to give more info perhaps idk, is there another game mode where we actually can know the pick order from the api? and always have them picking last pick. Too many sentences explaining itself, in 99% of cases the ui shoud be intuive enough without an explanation beside it

The game stats should be reusing elements from the other game stat stuff

I really like on on paper stuff but still could be more thoughtfull it its design, use space better. Needs much more explanation of why different things could have been picked, like maybe each champ suggested can be selected to see details of why it thinks it was pickable

the every pick rated is awesome but again, the ui is too simple, almost limiting, too generic.

as i said game stats so unimaginitve, too generic, basic table

love the lane comparison but agian this ui just doesnt match the data its trying to show.

the how these facts are read is ridiculous, no one is reading all that, ever, never have something that long

This page review has really shown me how much work we need to put into the frontend framework/components like we have to invest a lot of time into this now

learn:
the sentences are sometimes way too confusing, like so hard to understand what its asking, but it is cool

the basics is waaaaaay to basic, cant just give every answer and expect that to be fun or interesting, maybe give other examples no the exact answer but still have the answers be reasonably easy if that makes sense, like quite obvious counters, synergies, roles

champions screen, the number showing from patch to patch, i think is a great one, but also just doesnt make sense where it is, this whole table is too generic as well, could be much more specialised and show the information way clearer.

builds last 30 days screen is just a mess as well, again needs specific design thought

and then i cant go back 403,364 Platinum+ ranked solo/duo games in EUW, last 30 days, patches 16.19 to 16.21. Builds, last 30 days.

i also dont like the text and hyperlink text like that, minimums doesnt need to be hidden behind a dropdown

on champions page, needs to be more like the basic lolalytics page, the players win rate thing is too generic, not precise, or clear enough to what it menas, WAAAAAY too many words, awful use of space, like having nothing beside the player winrates histogram thing, the builds is quite cool, but runes, i need to be able to easily see the lolaytics like version where i can actually see all the pick rates, games and win rates of choices, oh just way too many words, some cells are showing information and look just like the other buttons, the most played, highest wr i dont want a toggle i want to show that all at once somehow. I need a way at the top to select between different roles, again more similar to lolalytics and slecting vs different roles is cool but I think we can make this ui element much easier, intutive, clear with a more specfic design. We never need a key of colours for the fucking numbers it shows, its a key in of itself, never do that on any page. I love the patch by patch and game time graphs, but again we can do this way better and clearer still, they dont really fit the style and look messy and TOO MANY WORDS

how hard champ is to pickup, why does it take up so much space WHY ARE THERE SO MANY WORDS

also if i pick on champion with its role on the champions list page, i want that role not some other,
So many things on this page just dont have the ui componenets to do it well

matchups list, just showing a list of all matchups is just ridiulous, theres just no reason for it, its so over the top, unclear, unhelpful, overwhleming, unsuable to actually find a matchup too

the specific matchup page actually is way better than the champion specific page, much better use of space and can share alot with the champion specifc page, these pages should compliment each other, im way happier with it and its much more in the direction i wanna go but could still do with a lot of work, too many words, sometimes too cramped but in general we wanna keep going this direction but still a lot of what i said on the champion specifc page applys,

patch changes is alright, not enough colour on the change, if i hover over the uncertainty i probably want a tool tip explaining it a little, this probably applys to over parts of ui that arent clear too, too many words, awful use of space on this page too with the very generic table, and its not a real table too, like no sorting?, also we can prob show more info on this page too like they should be able to use the same page to see more changes, idk though actaully if they want specific patch to patch, maybe they see that more on champion detail + matchup page idk good overview. Also showing context to this page, like the model should be able to have some idea of what has changed that affected this, like even better if it could actually show patch notes too and then even matchup changes in wr to the change itself, or what is impacting it, in general i like this page but again too generic, could be so much better

champion pool i really like my fav thing here is the gap of how hard a champ is to learn, but this page doesnt really have a good identity rn, WAYYY TO MANY WORDS again, if we know what person they analysed recently it could show the pool for that player but also great if they have a way of selecting a specific pool. The search here is way worse than other pages for champs and the drop downs look shit, not like they are meant to be there. In general the page has no flow, shows too much info, just not actually very helpful or useful and the ui sucks. The really long tables are just too much as well, too much to scroll though, we need to find a better way of showing all this.

in draft tester there is so much work to do as I think doing work here to make this more intersting and easy to use will help us implement this stuff on other pages. Its still too wordy, shipped model vs lab experiment is still not very clear about what models we are actually showing, i think name the model and then tag it with where its shipped/used and where its from like lab or whatever

i kinda need you to save this review, then spawn agents to start working on it all, I think a big part of it will be developing our frontend "tools" libraries and such so we can actually make good ui with what we have. I want you to work on this thinking extremely long term like spend time developing good solutions that can be applied on different pages, thinking of making the ui from the groundup not just solving each problem in isolation. first each page should probably have a plan so we can start developing with this context aware idea, and solve problems properly If that makes sense. Might be worth doing some research on the side for things, seeing how other lol sites do front end components for stuff, seeing what works what doesnt, taking insipration. Do you have any questions?

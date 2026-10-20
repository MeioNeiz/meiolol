: ''{{Hatnote|For information on account experience, see [[Experience (summoner)]]. For other uses, see [[Experience]].}}''
{{TOCright}}
{{as|{{sti|'''Experience points'''}}|xp}} ('''EXP''' or '''XP''') are a {{tt|quantity|abstract & dimensionless}} that allows champions to '''level up''' after reaching certain thresholds. Leveling up automatically and naturally awards various [[Champion statistic|stats]] as well as a skill point that can be spent on learning [[Champion ability|champion abilities]] or ranking up learned abilities. Some [[champion ability|champion abilities]], [[item effect|item abilities]], [[rune]]s and [[buff]]s, may also scale with champion level. Experience is earned from various sources by participating in the game.

All champions start each match at the same level, varying based on the [[map]] or game mode, usually either level 1 with zero XP or level 3 with zero XP. The amount of XP required to level up generally increases with each level.

== Gaining experience ==
There are four ways to gain experience. The majority of experience can be earned by standing near certain dying enemies that dispense an experience '''bounty''', or otherwise [[kill]]ing them to earn it.

When multiple champions are valid for earning an experience bounty, the amount is split and shared equally among them.

=== Champion kill bounties ===
Dying [[champion]]s dispense experience to enemy champions within 1600 units of their death location, when they are slain by an enemy champion ([[Kill#Champion kill credit|credited]]) or [[Kill#Execution|executed]] by an enemy [[minion]] or [[turret]]. Scoring a kill or [[assist]] on the champion guarantees earning the experience share regardless of range or death status. Lastly, enemy champions who have died within the last 10 seconds and did not participate in the kill can continue earning their experience share from dying champions within range, as if they were alive.

When only a single ally is eligible for the champion's experience bounty (solo experience), they earn {{pp|type=slain champion level|label=experience|42; 114; 144; 174; 204; 234; 308; 392; 486; 590; then + 50*x|formula=Explicit values (though technically an increasing % of each levelup requirement until level 10).}} experience.<ref name="patch1304">[https://www.leagueoflegends.com/en-us/news/game-updates/patch-13-4-notes/ Official Patch 13.4 Notes]</ref>
* Examples: The ally has been credited a solo kill and/or is the only one nearby when the champion is executed by a minion or turret.

When more than one ally is eligible for the champion's bounty, they share a total of {{pp|type=slain champion level|label=experience|42*0.666; 114*0.666; 144*0.666; 174*0.666; 204*0.666; 234*0.666; 308*0.82; 392*0.82; 486*0.9; 590*0.9; then + 50*0.9*x|formula=66.6% of the solo bounty until level 6, then 82% of the solo bounty at levels 7 and 8, then 90% of the solo bounty at levels 9+}} experience.
* Examples: The kill has been assisted; there are multiple allies within range when the champion is executed; the kill was assisted and one or more allies were also within range but did not participate/were not credited a kill or assist.

{{sbc|Comeback Bonus/Penalty:}} Benefitting champions who are at least 1 full decimal level higher or lower than the slain champion individually receive{{ft|<!--
-->20% less or more, respectively, experience per full decimal level of difference beyond the first.<ref name="patch1304"/> This starts from 0% at {{fd|1.0}} level of difference.<!--
-->|{{pp|0 to 80;…|1 to 5 by 0.25;5+|key=%|type=level difference|label=Experience modifier|formula=Linear interpolation by 20% per decimal level after 1 decimal level of difference. This has a lower bound at -60% for the penalty.}} less or more experience, respectively.}}<!--
-->The penalty when earning experience from a lower-level champion is capped at 60% less experience (= minimum 40% of the base experience bounty).

=== Minion kill bounties ===
Dying [[minion]]s dispense experience to champions within 1500 units<ref>[https://www.leagueoflegends.com/en-us/news/game-updates/patch-25-s1-1-notes/ Official Patch 25.S1.1 Notes]</ref> of their death location, whether they have been slain by an enemy champion or another enemy unit. Killing the minion guarantees earning the experience share regardless of range or death status.

The amount of experience that minions dispense is based on their type.

Minion bounties are affected by two ratios called '''[[#Yield modifiers|yield modifiers]]''' (detailed in the next section). As a general rule, one champion earns the whole minion's experience bounty<ref name=":0" />, and multiple champions earn slightly more—these modifiers exist for game-balance reasons.

{{sbc|Comeback Bonus:}} Benefitting champions who are more than 1 integer level lower than the slain minion individually receive{{ft|<!--
-->20% more experience. Then, over the second level of disadvantage, the value increases linearly by an additional 20%. Upon reaching 2 levels of disadvantage, it immediately increases by an additional 40%. Over the third level of disadvantage and for every level thereafter, the value increases linearly by an additional 40% per level of difference, up to a '''maximum''' bonus of {{ap|(<!-- second level down -->0.2+0.2<!-- third level down -->+0.4+0.4<!-- fourth -->+0.4<!-- fifth -->+0.4<!-- sixth -->+0.4)*100}}% when 6 levels below the slain minion.<!--
-->|{{pp|20;25;30;35;39.75;80;90;100;110;120;160;200;240|key=%|1.01;1.25;1.5;1.75;1.99;2;2.25;2.5;2.75;3;4;5;6|label1=Levels of difference|label=Comeback Bonus|type=level difference|formula=Linear interpolation from 0% at no difference, with a +20% discontinuity upon entering the second level of difference and a +40% discontinuity upon entering the third level of difference. The modifier starts applying upon entering the second level of difference, increases by 20% per level until a level difference of 2, then 40% per level until a level difference of 6 where the modifier is capped.}} more experience.}}
* This rule activates only after the enemy minions have reached level 6.

=== Monster kill bounties ===
All large-, medium- and lesser-tier [[monster]]s dispense their full experience bounty to their killer exclusively, regardless of range or death status. Epic monsters dispense experience to nearby champions of the slaying team (locally) who are alive. In the case of Baron specifically, he will dispense an experience bounty to all members of the slaying team, regardless of their range or death status.<ref name=":0">[[V26.01]]</ref>

The amount of experience that monsters dispense is based on their type and tier.

[[:Category:Jungle items|Jungle item]] users undergo additional rules:
* They always earn experience bonuses from slaying large monsters.
* {{sbc|Comeback Bonus:}} If they are more than {{fd|1.1}} levels behind the game's average champion level upon killing a large monster, they gain an additional 50 '''bonus''' experience for every integer level of disadvantage, rounded to the nearest integer.
* {{sbc|Minion Farming Penalty:}} They receive {{pp|70 to 0 for 11|0 to 20|key=%|type=minutes}} less experience from minion kills. This penalty is temporarily paused while the user is more than {{fd|1.5}} levels behind the average game level, and permanently removed at 20 minutes.
* {{sbc|Monster Hunter Penalty:}} They receive a further 50% less experience from minion kills if their total [[gold]] earned from minion kills exceeds 40% of their earned gold from monster kills. This penalty is permanently removed at 14 minutes.

=== Neutral buffs ===
Neutral [[buff]]s such as the global {{tip|Howling Abyss Aura}} in [[ARAM]] may grant experience passively.

== {{Anchor|Sharing experience}}Yield modifiers ==
Certain units may dispense varying amounts of their experience bounty based on whether one champion (solo experience) or multiple champions (shared experience) benefit from it. This is called a yield modifier. When more than 1 champion receives it, ''approximately 30% more'' experience compared to the base bounty is generated, before the total amount is split equally among all sharing champions.

'''These yield modifiers currently only apply to {{tip|minions}} and the {{ui|Rift Herald|Mercenary|link=Rift Herald#Summoned form}}.'''

In total:
* One champion receives 100% of the base experience bounty (''solo experience'').
* Two champions each receive 65% of the base experience bounty (130%{{divided by}}2).
* Three champions each receive {{fd|43.3}}% of the base experience bounty ({{fd|129.9}}%{{divided by}}3).
* Four champions each receive {{fd|32.5}}% of the base experience bounty (130%{{divided by}}4).
* Five champions each receive {{fd|26}}% of the base experience bounty (130%{{divided by}}5).
* Six champions each receive {{fd|21.7}}% of the base experience bounty ({{fd|130.2}}%{{divided by}}6).

== Level cap ==
By default, and in most gamemodes, the maximum level is '''18'''.
* Completing the Top Lane [[Role Quest]] increases the maximum level to '''20'''.
* In {{tip|Ultra Rapid Fire}}, the maximum level is '''30'''.
* In {{tip|Arena}}, the maximum level is '''41'''.

When reaching the maximum level, the in-game tooltip for experience will show '''0/0 Experience'''. Champions will still be able to gain experience, but it has no effect on their level whatsoever.

Champions' [[Champion statistic#Increasing Statistics|statistics grow]] with all levels they gain. Non-stat effects, such as [[champion ability|abilities]] or [[rune]]s, may or may not scale at levels above 18 and/or cap at a different level, depending on the effect.

== Experience needed ==
<tabber>
Summoner's Rift=
{{Clr}}
The following table lists the amount of experience required to go from level 1 to level 18 on {{tip|Summoner's Rift}}. 

Minion wave calculations assume experience earned from minions within a single lane of Summoner's Rift, no increased experience sources, and no experience from neutral monsters.

Solo experience assumes 1 champion within valid experience range. Shared experience assumes 2 champions within valid experience range simultaneously and at all times.

{| class="article-table"
|-
! To reach level
! XP
! Cumulative XP
! Solo Waves
! Shared Waves
|-
| 1 || 0 || {{#vardefineecho:cumulative|0}} || 0 || 0
|-
| 2 || 280 || {{Cumulative experience|280}} || 2 || 2
|-
| 3 || 380 || {{Cumulative experience|380}} || 3 || 4
|-
| 4 || 480 || {{Cumulative experience|480}} || 4 || 6
|-
| 5 || 580 || {{Cumulative experience|580}} || 6 || 9
|-
| 6 || 680 || {{Cumulative experience|680}} || 9 || 13
|-
| 7 || 780 || {{Cumulative experience|780}} || 11 || 16
|-
| 8 || 880 || {{Cumulative experience|880}} || 14 || 21
|-
| 9 || 980 || {{Cumulative experience|980}} || 18 || 26
|-
| 10 || 1080 || {{Cumulative experience|1080}} || 21 || 31
|-
| 11 || 1180 || {{Cumulative experience|1180}} || 25 || 37
|-
| 12 || 1280 || {{Cumulative experience|1280}} || 30 || 43
|-
| 13 || 1380 || {{Cumulative experience|1380}} || 34 || 49
|-
| 14 || 1480 || {{Cumulative experience|1480}} || 39 || 55
|-
| 15 || 1580 || {{Cumulative experience|1580}} || 45 || 62
|-
| 16 || 1680 || {{Cumulative experience|1680}} || 49 || 69
|-
| 17 || 1780 || {{Cumulative experience|1780}} || 54 || 76
|-
| 18 || 1880 || {{Cumulative experience|1880}} || 60 || 84
|-
| 19 || 1980 || {{Cumulative experience|1980}} || — || —
|-
| 20 || 2080 || {{Cumulative experience|2080}} || — || —
|}
|-|Howling Abyss=
The following table lists the amount of experience required to go from level 3 to level 18 on {{tip|Howling Abyss}}.
{| class="article-table"
|-
! To reach level
! XP
! Cumulative XP
|-
| 3 || 0 || {{#vardefineecho:cumulative|0}}
|-
| 4 || 478 || {{Cumulative experience|478}}
|-
| 5 || 510 || {{Cumulative experience|510}}
|-
| 6 || 750 || {{Cumulative experience|750}}
|-
| 7 || 780 || {{Cumulative experience|780}}
|-
| 8 || 880 || {{Cumulative experience|880}}
|-
| 9 || 980 || {{Cumulative experience|980}}
|-
| 10 || 1080 || {{Cumulative experience|1080}}
|-
| 11 || 1180 || {{Cumulative experience|1180}}
|-
| 12 || 1280 || {{Cumulative experience|1280}}
|-
| 13 || 1380 || {{Cumulative experience|1380}}
|-
| 14 || 1480 || {{Cumulative experience|1480}}
|-
| 15 || 1580 || {{Cumulative experience|1580}}
|-
| 16 || 1680 || {{Cumulative experience|1680}}
|-
| 17 || 1780 || {{Cumulative experience|1780}}
|-
| 18 || 1880 || {{Cumulative experience|1880}}
|}
</tabber>

== Increasing experience gain ==
Note that regular experience gain modifiers [[Stacking#Stacks additively|stack additively]] with each other. Modifiers originating from the game mode's global rules [[Stacking#Stacks multiplicatively|stack multiplicatively]] with regular sources, however.

=== Champion abilities ===
* {{cai|Joy Unending|Nilah}}
* {{cai|Time in a Bottle|Zilean}}

=== Items ===
{{Column|2|
* {{ii|Gustwalker Hatchling}}
* {{ii|Mosstomper Seedling}}
* {{ii|Rod of Ages}}
* {{ii|Scorchclaw Pup}}
}}

=== Neutral buffs ===
* {{tip|Howling Abyss Aura}} passively grants experience.

=== Other ===
* {{tip|Jungle Quest}}
* {{tip|Toplane Quest}}

== Level requirement ==
=== Champion abilities ===
The following passive abilities require the user to have reached a certain level in order to access new effects.
* {{cais|Demon Shade|Evelynn}} {{tip|camouflage}}
* {{cais|A Harmless Scarecrow|Fiddlesticks}} {{tip|Sweeper Drone}}
* {{cais|Divine Ascent|Kayle}} ascensions
* {{cais|Master Craftsman|Ornn}} {{sbc|Masterwork}} upgrades

=== Items ===
The following items require the user to have reached a certain level in order to equip them.
* {{ii|Cappa Juice}}
* {{ii|Elixir of Iron}}
* {{ii|Elixir of Sorcery}}
* {{ii|Elixir of Wrath}}
* {{ii|Farsight Alteration}}

=== Runes ===
The following runes require the user to have reach a certain level in order to access new effects.

* {{ri|Deep Ward}}
* {{ri|Transcendence}}
* {{ri|Triple Tonic}}

== Trivia ==
* {{ci|Nidalee}}, prior to her rework, had a non-displayed passive that granted 5 experience points every 5 seconds to nearby allied champions that had a lower level than her.
* Comeback experience may also be called "catch-up" experience by Riot designers or the community.

== Patch History ==
{{Scroll box|content=
;[[V26.01]]
* Solo minion experience increased to 100% from 95%.
* Shared minion experience increased to 130% from 124%.
* ''Experience gain changed to {{ap|100|65|43.3|32.5|26|21.7}}% (based on sharing champions) from {{ap|95|62|41.3|31|24.8|20.7}}% (based on sharing champions).''

;[[V25.S1.1]]
* Minion experience range increased to 1500 from 1400.

;[[V14.19]]
* {{sbc|Removed:}} Killing a {{tip|Stealth Ward}} or {{tip|Totem Ward}} no longer grants 40 '''base''' experience.
* {{sbc|Removed:}} Killing a {{tip|Farsight Ward}} no longer grants 20 '''base''' experience.

;[[V14.10]]
* Shared minion experience increased to 124% from 116%.
** ''Solo minion experience unchanged at 95%.''
* Shared champion kill experience modifier reduced to {{pp|66.6;82;90|key=%|1;7;9|type=your level}} of the solo kill experience from {{pp|66.6;82;100|key=%|1;7;9|type=your level}}.
* {{sbc|Bug Fix:}} Fixed an inconsistency for experience sharing with five teammates which resulted from an out-of-bounds value in the formula.
* {{sbc|New:}} The game now has a value for splitting experience to 6 players.

;[[V13.20]]
* Jungle item generic minion experience reduction is no longer removed upon the {{ii|Gustwalker Hatchling|icononly=true}}{{ii|Mosstomper Seedling|icononly=true}}{{ii|Scorchclaw Pup|icononly=true}} ''Jungle companion's'' first evolution.
* Jungle item generic minion experience reduction changed to {{pp|70 to 0 for 11|0 to 20|key=%|type=minutes}} from {{pp|60 to 25 for 15|0 to 14|key=%|type=minutes}}.
* Jungle item comeback experience threshold reduced to {{fd|1.1}} levels from {{fd|1.5}}.

;[[V13.17]]
* Jungle item comeback experience now rounds to the nearest integer level difference instead of always rounding up.

;[[V13.5]]
* Jungle item generic minion experience reduction increased to {{pp|60 to 25 for 15|0 to 14|key=%|type=minutes}} from 25% at all times.

;[[V13.4]]
* Champion kill experience reduced to {{pp|type=enemy champion level|label=experience|42; 114; 144; 174; 204; 234; 308; 392; 486; 590; then + 50*x}} from {{pp|type=enemy champion level|label=experience|42; 114; 186; 258; 330; 402; 434.5; 500.5; 515; 590; then + 50*x}}. ''Reduced at levels 3–9''.
* Champion kill experience modifier per level of difference changed to 20% from 16%.
** ''Experience penalty (earned experience from a lower level target) still has a minimum of 40% total experience.''
* Champion kill experience modifier now starts applying from 0% at the first full decimal level of difference instead of 16% immediately.

;[[V12.22]]
* Minion solo XP increased to 95% from 93%.
** Minion shared XP unchanged.
* Jungle item comeback experience threshold reduced to {{fd|1.5}} levels from 2.
* Jungle item Monster Hunter rule is now removed at 14 minutes from 20.
* Jungle item users now receive 25% reduced experience from minions before their {{ii|Gustwalker Hatchling|icononly=true}}{{ii|Mosstomper Seedling|icononly=true}}{{ii|Scorchclaw Pup|icononly=true}} ''Jungle companion'' has reached its first evolution.

;[[V11.10]]
* {{sbc|Jungle Comeback Experience:}} If a Jungle item user is at least 2 full decimal levels below the average level of all champions, they now receive 50 bonus experience upon killing a large monster for each level of disadvantage. This is rounded up (e.g. {{fd|2.1}} levels is rounded to 3).

;[[V10.8]]
* Solo champion kill experience increased to {{pp|type=enemy champion level|label=experience|42; 114; 186; 258; 330; 402; 434.5; 500.5; 515; 590; then + 50*x}} from {{pp|type=enemy champion level|label=experience|35; 95; 155; 215; 275; 335; 395; 455; 515; 590; then + 50*x}}. ''Increased by 20% at levels 1–6 and increased by 10% at levels 7–8.''
* {{sbc|New Effect:}} Shared champion kill experience is now {{pp|66.6;82;100|key=%|1;7;9|type=your level}} of the solo kill experience instead of 100% always.
* Jungle item users' threshold for Monster Hunter penalty reduced to 40% of monster gold from 50%.
* Jungle item users' Monster Hunter rule is now removed at 20 minutes from 14.

;[[V10.6]]
* {{sbc|Monster Hunter Penalty:}} Jungle item users now receive 50% experience from minion kills if their total gold earned from minion kills is greater than 50% of earned gold from monster kills. This penalty is removed at 14 minutes.

;[[V9.23]]
* Minion solo XP increased to 93% from 92%.
* Minion shared XP reduced to 116% from 120%.
* {{sbc|Removed:}} Jungle items no longer award 50 bonus experience upon killing a large monster for each level higher the monster is than the user.

;[[V7.22]]
* {{sbc|Removed:}} Kills and assists no longer award bonus experience if you are more than 1 decimal level lower than your team's average decimal level, increasing logarithmically up to a bonus of 60% at 4 full levels of difference.
* Jungle item bonus experience per level of difference with the slain monster increased to 50 from 30.
* {{sbc|Removed:}} Jungle item bonus experience per level of difference with the slain monster is no longer granted from slaying lesser and medium monsters.

;[[V7.4]]
* Champion kill experience modifier per level of difference increased to 16% from 15%.
* {{sbc|New Effect:}} Scoring a kill or assist while more than 1 decimal level lower than your team's average decimal level now grants bonus experience.
** The modifier increases logarithmically the larger the disadvantage is, up to 60% more experience at 4 full levels below the team's average.

;[[V7.3]]
* Champion kill experience modifier per level of difference increased to 15% from 14%.

;[[V6.13]]
* {{sbc|New Effect:}} Champion kill experience modifier now scales linearly with decimal level of difference rather than at breakpoints with each integer level of difference.
* Champion kill experience modifier per level of difference increased to 14% from 12%.
* Champion kill experience modifier per level of difference now starts at 1 full decimal level of difference from 2.
* {{sbc|New Effect:}} Champions can now also earn experience from nearby champion deaths up to 10 seconds after the benefitting player dies.

;[[V6.12]]
* Champion kill experience changed to {{pp|type=enemy champion level|label=experience|35;then + 60*x for 8; then + 75; then + 50*x}} from 50% of the target's level up experience.
* Champion kill experience modifier per level of difference increased to 12% from 7%.
* Minimum champion kill experience increased to 40% from 20%.

;[[V6.9]]
* {{sbc|Removed:}} While at least one level lower/higher than the slain monster, no longer awards an increased/reduced, respectively, amount of experience from killing it by a constant percentage, up to 50%.
* {{sbc|New:}} While a Jungle item is equipped, killing any monster that is higher level awards 30 bonus experience for each level of difference with the monster.

;[[V5.23]]
* Champion kill experience reduced to 50% of the target's level up experience from 60%.

;[[V5.22]]
* Champion kill experience increased to 60% of the target's level up experience from 50%.
* Champion kill experience modifier per level of difference reduced to 7% from 8%.
* Minimum champion kill experience increased to 20% from 15%.

;[[V4.21]]
* Champion kill experience reduced to 50% of the target's level up experience from 55%.

;[[V4.20]]
* {{sbc|Jungle Experience Penalty:}} Champions now gain 10% less experience for each level they are above the camp they are killing, capping at 50%.

;[[V4.11]]
* Lane minion experience range increased to 1400 from 1250.

;[[V3.14]]
* Minions are no longer worth more experience based on game time. To account for this, level up thresholds are reduced. ''Summoner's Rift values are listed below''.
** 1→2: No change (280)
** 2→3: 380 (660 total) from 390 (670 total)
** 3→4: 480 (1140 total) from 500 (1170 total)
** 4→5: 580 (1720 total) from 610 (1780 total)
** 5→6: 680 (2400 total) from 720 (2500 total)
** 6→7: 780 (3180 total) from 830 (3330 total)
** 7→8: 880 (4060 total) from 940 (4270 total)
** 8→9: 980 (5040 total) from 1050 (5320 total)
** 9→10: 1080 (6120 total) from 1160 (6480 total)
** 10→11: 1180 (7300 total) from 1270 (7750 total)
** 11→12: 1280 (8580 total) from 1380 (9130 total)
** 12→13: 1380 (9960 total) from 1490 (10620 total)
** 13→14: 1480 (11440 total) from 1600 (12220 total)
** 14→15: 1580 (13020 total) from 1710 (13930 total)
** 15→16: 1680 (14700 total) from 1820 (15750 total)
** 16→17: 1780 (16480 total) from 1930 (17680 total)
** 17→18: 1880 (18360 total) from 2040 (19720 total)
* {{sbc|New:}} Jungle monsters now utilize a level system based on champion levels.
** A monster's level is calculated when the monster spawns and is based on the average level of all champions (AFK players are excluded).
** A monster's level determines its health, damage and bounty.
** {{sbc|Jungle Comeback Experience:}} Killing jungle monsters that have a higher level now grant ''up to'' an additional 50% of their experience bounty, based on how large the level difference is.

;[[V1.0.0.138]]
* {{sbc|New Effect:}} At 2 levels of difference or higher between the killer and the slain champion, champion kill experience is now modified by 8% per level of difference.
** Being higher level than the slain champion awards less experience, being lower level than the slain champion awards more experience.
** The penalty for being higher level than the slain champion cannot grant less than 15% of the base experience gained from a champion kill.
* Minion shared experience increased to 120% from 116%.

;[[V1.0.0.130]]
* {{sbc|Undocumented:}} Minion shared experience increased to 116% from 110%.

;[[V1.0.0.120]]
* Experience granted for kills is now determined by the dying champion's level instead of the killer's level. This means:
** Killing champions higher level than you will now grant more experience.
** Killing champions lower level than you will now grant less experience.
** Killing equal level champions is unaffected.

;[[V1.0.0.113]]
* {{sbc|New effect:}} Shared minion kill experience now grants 110% experience, shared equally between nearby allied champions.

;[[V1.0.0.104]]
* {{sbc|Undocumented:}} Solo minion kill experience reduced to 92% of the '''base''' value ''(shared experience unchanged)''.

;[[V1.0.0.98]]
* Fixed a bug where kills or assists were not granting experience if the Champion was too far away from the target.

;[[V1.0.0.96]]
* Base champion kill experience reduced to 55% from 60% of level up experience.

;[[V1.0.0.94]]
* Base champion kill experience increased to 60% from 50% of level up experience.

;[[V1.0.0.79]]
* Base champion kill experience increased 50% from 40% of level up experience.

;[[V1.0.0.75]]
* Champion kill experience system reworked.
** Experience rewards are now calculated on a per-champion basis, with the rewards scaling based on the delta of champion levels. The scaling is based on an S curve so that killing champions three levels and below provide negligible rewards, and kills three levels and above provide almost twice the experience of even level kills.

;[[May 1, 2009 Patch]]
* Destroying an inhibitor no longer causes the enemy team to gain less experience from minion kills.
}}

== See also ==
* [[Kill]]
* [[Champion gold bounties]]
{{Gameplay elements}}

== References ==
{{Reflist}}[[de:Erfahrung (Champion)]]
[[es:Experiencia (campeón)]]
[[ru:Опыт]]
[[zh:Experience (champion)]]
[[Category:Gameplay elements]]
[[Category:Champions]]
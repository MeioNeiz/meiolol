# Legends of Runeterra Developer Challenge Announcement | Riot Games

<https://www.riotgames.com/en/DevRel/legends-of-runeterra-developer-challenge-announcement>

This website utilises technologies such as cookies to enable essential site functionality, as well as for analytics, personalisation, and targeted advertising. You may change your settings at any time or accept the default settings. You may close this banner to continue with only essential cookies. [Privacy Notice](https://www.riotgames.com/en/privacy-notice)

[Storage Preferences](https://www.riotgames.com/en/DevRel/legends-of-runeterra-developer-challenge-announcement#e0fe6401-008d-494c-ba48-a48acb93b735)

-   Targeted Advertising
-   Personalisation
-   Analytics

  

Storage Preferences

[Jump to Main Content](https://www.riotgames.com/en/DevRel/legends-of-runeterra-developer-challenge-announcement#content)[Jump to Primary Navigation](https://www.riotgames.com/en/DevRel/legends-of-runeterra-developer-challenge-announcement#riotbar-bar)

[

Who We Are

](https://www.riotgames.com/en/who-we-are)

[

Work with us

](https://www.riotgames.com/en/work-with-us)

[

News

](https://www.riotgames.com/en/news)

[Who We Are](https://www.riotgames.com/en/who-we-are)[Work with us](https://www.riotgames.com/en/work-with-us)[News](https://www.riotgames.com/en/news)

SIGN IN

SIGN IN

News

# Legends of Runeterra Developer Challenge Announcement

-   By [**Paul Sullivan**](https://www.riotgames.com/en/DevRel/legends-of-runeterra-developer-challenge-announcement#author)
-   **Nov 4, 2019**

-   [Share this on Reddit](https://reddit.com/submit?url=https%3A%2F%2Fwww.riotgames.com%2Fen%2FDevRel%2Flegends-of-runeterra-developer-challenge-announcement)
-   [Share this on Twitter](https://twitter.com/share?url=https%3A%2F%2Fwww.riotgames.com%2Fen%2FDevRel%2Flegends-of-runeterra-developer-challenge-announcement&text=Legends%20of%20Runeterra%20Developer%20Challenge%20Announcement)
-   [Share this on Facebook](https://www.facebook.com/sharer/sharer.php?&u=https%3A%2F%2Fwww.riotgames.com%2Fen%2FDevRel%2Flegends-of-runeterra-developer-challenge-announcement)
-   

 Good News, Everyone!

We’re excited to announce a developer challenge based around our newly announced game, Legends of Runeterra. You may have noticed the [shiny new toys](https://developer.riotgames.com/docs/lor) we released during the first preview of Legends of Runeterra. For the next preview on November 14th - 19th, we’ve added even more functionality to the [Game Client API](https://developer.riotgames.com/docs/lor#game-client-api), and we’re going to sweeten the pot for those of you who want to test things out.

First, we’re accepting [submissions](https://developer.riotgames.com/app-type) for the first Legends of Runeterra Developer Challenge, right now, on the Riot Developer Portal. We’re asking for you to pitch us something you want to make that hasn’t been made yet, so Definitely Not Mobalytics’ [card gallery](https://lor.mobalytics.gg/cards), [deck builder](https://lor.mobalytics.gg/decks),  or [Twitch extension](https://lor.mobalytics.gg/twitch-extension). We worked with them over the past several months to make those tools, and we’re specifically looking for something new, something that scratches a different itch. Before submitting your pitch, make sure that you read all of the [rules](https://static.developer.riotgames.com/assets/challenge-rules-2019.pdf) for this Challenge.

We’re going to vet all applicants for well conceived submissions only, so please give as detailed an explanation as you can of what you, and your potential teammates (up to 5 TOTAL), intend to make and how the developer tools for Legends of Runeterra will enable your features. After the application deadline November 8th at 10 AM PST, the submissions which we find intriguing will be granted access to the second preview of Legends of Runeterra starting November 14th. 

The official runtime of the challenge will be from November 11th at 10 AM PST until November 22nd at 10 AM PST. At that time, we’ll sort through all submissions, which should include any relevant links to video demos, GitHub repos, websites, or mobile apps. 

Once we’ve vetted all submissions, we’ll actively involve the Legends of Runeterra dev team to take a look at the finalists. Their judgment will weigh heavily on our choice of winner, but we’ll be holding our own evaluations to the following standards:

1.  **Value(s)**: This is two concepts rolled into one; how valuable the app would be to Legends of Runeterra players to use daily and how it shares our values as Rioters (i.e. don’t exploit players, don’t give players unfair advantages, don’t break the game).
    
2.  **Novelty**: We want you to surprise and delight us, be creative, and think outside the box.
    
3.  **Polish**: We know these challenges and their shorter cousin, the hackathon, impose a ton of constraints on quality development, but we do want to give props to developers who are able to beat the odds and have something that feels shippable by the deadline.
    

We will be judging applications with the help of the Legends of Runeterra team until December 6th. From the end of the challenge until we select the winner, we may call on you to give a demo of your application or clarify aspects of your submission. We will be choosing a single winning team, who will receive an iPhone 11 and a Samsung Galaxy Tab S6 (per member).

We can’t wait to be surprised and delighted by what you ship next. Good luck!

## **PATCH NOTES FOR LoR GAME CLIENT**

**Client Endpoints**

The **positional-rectangles** endpoint now returns Card Rect data for cards in the collection view, deck view, deckbuilder, and Expeditions selection screens. The per-card rect objects now contain an additional **bool LocalPlayer**, which is true if that particular card belongs to the player and false if it belongs to the opponent.

A brand new **expeditions-state** endpoint has been added. The endpoint returns a response object with the following fields:

**bool IsActive**  
     Does the player have an active Expeditions run?

**string State**

    “Inactive”: Player doesn’t have any active Expeditions run

    “Offscreen”: Player has an active Expeditions run, but they’re elsewhere in client

    “Picking”: Player is currently being presented with potential Picks

    “Swapping”: Player is currently being presented with potential Swaps

    “Other”: Player is on one of the interstitial screens within Expeditions

**List<string> Record**

    Each string is either “win” or “loss”, representing this run’s historical results

**List<string> Deck**

    List of each card currently in the Expeditions deck, represented as CardCodes

**int Games**

    Number of games played so far in this run

**int Wins**

    Number of games won so far this run

**int Losses**

    Number of games lost so far this run

**Data Dragon**

In addition to **description** and **descriptionRaw**, all cards have a **levelupDescription** and a **levelupDescriptionRaw**. If the card is a Level 1 Champion, these fields contains the card’s levelup condition text as displayed on the card in-game. Non-Champion cards have empty levelupDescriptions.

Many card data content changes and global data content changes were made, but no fields were added or removed beyond the above.

Author

### Paul Sullivan

Director of Developer Relations, Riot Games, Inc.

[Read More](https://developer.riotgames.com/)

[Riot Games](https://www.riotgames.com/)

-   [Press](https://www.riotgames.com/en/press)
-   [Security](https://www.riotgames.com/en/security)
-   [Legal](https://www.riotgames.com/en/legal)
-   [Leadership](https://www.riotgames.com/en/leadership)
-   [Candidate Privacy](https://www.riotgames.com/en/candidate-privacy)
-   [Terms of Service](https://www.riotgames.com/en/terms-of-service)
-   [Privacy Notice](https://www.riotgames.com/en/privacy-notice)
-   [Player Support](https://support.riotgames.com/hc/en-us)
-   [E-Verify](https://www.riotgames.com/en/e-verify-right-to-work)
-   [Accessibility](https://www.riotgames.com/en/accessibility)
-   [Annual Reports](https://www.riotgames.com/en/annual-reports)
-   [Peering Information](https://www.riotgames.com/en/peering-information)
-   [Community Pact](https://www.riotgames.com/en/community-pact)

[Follow us on Twitter](https://twitter.com/riotgames)[Follow us on Instagram](https://www.instagram.com/riotgames/)[Follow us on Tiktok](https://www.tiktok.com/@riotgames)[Share this on LinkedIn](https://www.linkedin.com/company/riot-games)[Follow us on Facebook](https://www.facebook.com/RiotGames/)[Watch on YouTube](https://www.youtube.com/riotgames)

© 2026 Riot Games, Inc. All Rights Reserved.

[To the Surface](https://www.riotgames.com/en/DevRel/legends-of-runeterra-developer-challenge-announcement#top)

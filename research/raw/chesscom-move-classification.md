# How are moves classified? What is a 'blunder' or 'brilliant,' etc.? | Chess.com Help Center

<https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-etc>

[Skip to main content](https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-etc#main-content)

[Claim your free trial 💎](https://www.chess.com/membership?c=faq)[Contact us](https://www.chess.com/support)

Search for articles...

1.  How are moves classified? What is a 'blunder' or 'brilliant,' etc.?

# How are moves classified? What is a 'blunder' or 'brilliant,' etc.?

Learn how Chess.com classifies moves using the new Expected Points Model and how Brilliant and Great Moves are defined.

February 9, 2026

## Move classification on Chess.com

Classifying moves in chess involves both art and science. How do we distinguish between a good move and an inaccurate one? How do we define a blunder for a chess master versus a new player? Is it more significant to go from +2 to +1 or from +0.7 to +0? What engine evaluation makes a position winning?

With **Classification V2**, Chess.com has adopted an [Expected Points Model](https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-etc#h_1844e8c057) to answer these questions.

## Expected Points Model

Expected Points uses data science to **determine a player’s winning chances based on their rating and the engine evaluation**, where 1.00 is always winning, 0.00 is always losing, and 0.50 is even.

**At 1.00, you have a 100% chance of winning, and at 0.00, you have a 0% chance of winning.** After you make a move, we evaluate how your expected points—likely game outcome—have changed and classify the move accordingly.

The table below shows the expected points cutoffs for various move classifications. If the expected points lost by a move is between a set of upper and lower limits, then the corresponding classification is used:

<table style="min-width:395px"><tbody><tr><td data-colwidth="195" style="background-color:#e8e8e880;width:195px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><b>Classification</b></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div></td><td style="background-color:#e8e8e880"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><b>Lower Limit</b></p></div></td><td style="background-color:#e8e8e880"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><b>Upper Limit</b></p></div></td></tr><tr><td data-colwidth="195" style="width:195px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><img src="https://downloads.intercomcdn.com/i/o/qzot1t7g/1637071903/77cb6ca45247128f333a61de8152/best.png?expires=1792584000&amp;signature=3ace3af04f6b46ad1265d86fbbb6e6d75f6755d0005deea17b5d261ab2a5c060&amp;req=dSYkEcl5nIhfWvMW3Hu4gbwI76T5BpYp6TurYv1UUtbVXSZMYZn2SNkE3k5g%0AQA%3D%3D%0A" width="18" alt=""> <b>Best</b></p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.00</p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.00</p></div></td></tr><tr><td data-colwidth="195" style="width:195px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><img src="https://downloads.intercomcdn.com/i/o/qzot1t7g/1637072060/10cfcdb2e85b519f37bbcc003b84/excellent.png?expires=1792584000&amp;signature=dcba9ade2f437685fa64f041f6b2cc9237fce1b822107b0a2316d0a27025fd2a&amp;req=dSYkEcl5n4FZWfMW3Hu4gQb%2F6BsxnYyK24oFqFUPOtAYyRYgJmapqxiASNgu%0Awg%3D%3D%0A" width="18" alt=""> <b>Excellent</b></p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.00</p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.02</p></div></td></tr><tr><td data-colwidth="195" style="width:195px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><img src="https://downloads.intercomcdn.com/i/o/qzot1t7g/1637072339/7b1fa05df4ee3103e3d0be935d01/good.png?expires=1792584000&amp;signature=de75eada39b58fbad4a092a749bda24cd9723760bafe1c7a706002cb80334bfd&amp;req=dSYkEcl5n4JcUPMW3Hu4gXM0r9ARON3BtEkQRXg3TPxcX5Pf6z9KmnhiS4ak%0ACw%3D%3D%0A" width="18" alt=""> <b>Good</b></p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.02</p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.05</p></div></td></tr><tr><td data-colwidth="195" style="width:195px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><img src="https://downloads.intercomcdn.com/i/o/qzot1t7g/1773434770/7d812b468182341864b3c910ae26/innacuracy.png?expires=1792584000&amp;signature=3d31133dd9f528ef6eb3fec2cbe663a5155d54daddd1b180ab3e47c9f6915b0c&amp;req=dScgFc19mYZYWfMW3Hu4gTn57RFcGoEgQSMnlw0eW1rzy0T7%2Fe6fj5vwwwsI%0Avw%3D%3D%0A" width="18" alt=""> <b>Inaccuracy</b></p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.05</p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.10</p></div></td></tr><tr><td data-colwidth="195" style="width:195px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><img src="https://downloads.intercomcdn.com/i/o/qzot1t7g/1637072680/ad1b658b25545d0ef8071c8fe9c0/mistake.png?expires=1792584000&amp;signature=03e18c446535f7be6aa57de95a44430fe6213b1cef1fbfce1950ffec79fc1b94&amp;req=dSYkEcl5n4dXWfMW3Hu4gZ%2Bhlszf3fweuTvJWSZbEB4SjUZmyivZn3xc9REg%0AMA%3D%3D%0A" width="18" alt=""> <b>Mistake</b></p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.10</p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.20</p></div></td></tr><tr><td data-colwidth="195" style="width:195px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><img src="https://downloads.intercomcdn.com/i/o/qzot1t7g/1637072797/c2fc996629dbf3592a8c34b5eae7/blunder.png?expires=1792584000&amp;signature=f6861acc4d1fb31c4ae383f198450c159208b783f6205a36621db2174c4d07d3&amp;req=dSYkEcl5n4ZWXvMW3Hu4gcGWNDGvyUVu1yf8%2FQClz8hm6G1%2ByhmFVECH0aPt%0AGw%3D%3D%0A" width="18" alt=""> <b>Blunder</b></p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>0.20</p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p>1.00</p></div></td></tr></tbody></table>

## Move classifications beyond expected points

Special move classifications that use rules beyond expected points have also undergone improvements:

<table style="min-width:256px"><tbody><tr><td data-colwidth="156" style="background-color:#e8e8e880;width:156px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><b>Classification</b></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div></td><td style="background-color:#e8e8e880"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><b>When is it used?</b></p></div></td></tr><tr><td data-colwidth="156" style="width:156px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><img src="https://downloads.intercomcdn.com/i/o/qzot1t7g/1637071269/d5bb6eafbbba30d9a60e85936c57/great.png?expires=1792584000&amp;signature=21819cb9b985af6649dccb99b18b96f12b76b9312e18a8483448ce03f5f6da87&amp;req=dSYkEcl5nINZUPMW3Hu4gRvp26FyuorhRaDPHY6UOOlQqQ9mwybSZO%2FXOX6G%0AZw%3D%3D%0A" width="18" alt=""> <b>Great</b> <b>Move</b></p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p><b>These are moves that were critical to the outcome of the game</b>, such as turning a losing position into an equal one, an equal position into a winning one, or finding the only good move in a position.</p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-justify"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p>Similar to Brilliant Moves, we are more generous in what we call a Great Move for new players compared to higher-rated players.</p></div></td></tr><tr><td data-colwidth="156" style="width:156px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><img src="https://downloads.intercomcdn.com/i/o/qzot1t7g/1637071528/66bb10f27947d975d32aa4b7a4aa/brilliant.png?expires=1792584000&amp;signature=6486a65f5feb8335ab074ed81874e47867392544e2d4c86f32d249f7a8a825a6&amp;req=dSYkEcl5nIRdUfMW3Hu4gbqERDNAhBynGE5yCTxkT9Uh6MiW%2B9u4vBZBEz%2Bj%0AVg%3D%3D%0A" width="18" alt=""> <b>Brilliant</b></p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p>Brilliant Moves are always the best or nearly best move in the position, but they are also special in some way.</p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p>We replaced the old Brilliant algorithm with a simpler definition:<b> a Brilliant move is when you find a good piece sacrifice.</b></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p>There are additional conditions:</p></div><div class="intercom-interblocks-unordered-nested-list"><ul><li><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p>You should not be in a bad position after a Brilliant move</p></div></li><li><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p>You should not be completely winning even if you hadn't found the move.</p></div></li></ul></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p>We are also more generous in defining a piece sacrifice for newer players compared to those who are higher-rated.</p></div></td></tr><tr><td data-colwidth="156" style="width:156px"><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-center"><p><img src="https://downloads.intercomcdn.com/i/o/qzot1t7g/1637071723/58ad222d8004bdf9504524175c5e/miss.png?expires=1792584000&amp;signature=91cb178e1e0909c22a0bdb771f797306ed9dd2cf66f6cbeeb097a032c65c4165&amp;req=dSYkEcl5nIZdWvMW3Hu4gZF%2FoINJhGHKLyA3r2ScpU0xABgSzuoDijA6dr4%2F%0Awg%3D%3D%0A" width="18" alt=""> <b>Miss</b></p></div></td><td><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p>A <b>Miss</b> <b>is when you fail to capitalize on your opponent's mistake </b>and miss the opportunity to gain a winning position, often resulting in an equal or worse outcome.</p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p></p></div><div class="intercom-interblocks-paragraph no-margin intercom-interblocks-align-left"><p>The engine evaluation required to determine a winning, equal, or losing position varies according to the player's rating, similar to expected points.</p></div></td></tr></tbody></table>

 Check out this article to learn more about Game Review: [How does Game Review work?](https://support.chess.com/article/653-computer-analysis-how-do-i-get-my-games-analyzed)

* * *

Related Articles

-   [
    
    How do I change what kinds of moves are highlighted in Analysis?
    
    ](https://support.chess.com/en/articles/8648715-how-do-i-change-what-kinds-of-moves-are-highlighted-in-analysis)
-   [
    
    How do I use Game Review on the app?
    
    ](https://support.chess.com/en/articles/10328363-how-do-i-use-game-review-on-the-app)
-   [
    
    How do I use Advanced Stats?
    
    ](https://support.chess.com/en/articles/15451190-how-do-i-use-advanced-stats)

Did this answer your question?

[Move classification on Chess.com](https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-etc#h_9cdfc0c1c3)

[Expected Points Model](https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-etc#h_1844e8c057)

[Move classifications beyond expected points](https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-etc#h_03c0f89a32)

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

-   [Privacy Policy](https://www.chess.com/legal/privacy)
-   [Fair Play Policy](https://www.chess.com/legal/fair-play)
-   [User Agreement](https://www.chess.com/legal/user-agreement)
-   [Community Policy](https://www.chess.com/legal/community)

-   
-   
-   
-

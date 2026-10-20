//! "Your games": a skeleton that static/your.js fills from the service (`meiolol api`,
//! src/api) at /api/ on the same host, or from data/your-example.json (`meiolol
//! your-example`) for the example: a game review per game (static/review.js), modelled
//! on a chess game review. Facts about the player's own games, never advice
//! (docs/concept.md).

const std = @import("std");
const Writer = std.Io.Writer;
const prose = @import("prose.zig");

pub fn page(w: *Writer, info: prose.Info) Writer.Error!void {
    _ = info;
    try w.writeAll(
        \\<section id="start" class="your-start">
        \\<h1>Review your games</h1>
        \\<p class="lead">Every recent game, reviewed like a chess game: your team's win
        \\chance minute by minute, the moments that moved it, what each death cost, and your
        \\lane against the typical game in the same matchup at your rank. Solo/duo, flex,
        \\draft and Swiftplay.</p>
        \\<form id="lookup" class="search" role="search">
        \\<input id="riot-id" name="id" placeholder="Riot ID, like Name#EUW" aria-label="Riot ID, as Name#TAG" autocomplete="off" spellcheck="false" required>
        \\<button type="submit">Review my games</button>
        \\</form>
        \\<p id="example-offer" class="sub-links" hidden><a href="your.html#example" id="example-link">See an example review →</a></p>
        \\</section>
        \\<p id="status" class="note" hidden></p>
        \\<div id="player" hidden>
        \\<section class="banner">
        \\<div class="who"><span id="player-rank"></span><h1 id="player-name"></h1>
        \\<button type="button" id="check" class="link" hidden>Check for new games</button>
        \\<button type="button" id="not-you" class="link" title="Back to an empty lookup; this browser stops opening this player here" hidden>Not you?</button></div>
        \\<div id="record" class="record"></div>
        \\</section>
        \\<div class="sec-h"><h2>Your games</h2><span id="games-note"></span></div>
        \\<div id="film" class="film" role="list"></div>
        \\<div id="review"></div>
        \\<section id="highlights" hidden>
        \\<div class="sec-h"><h2>Highlights</h2><span id="highlights-note"></span></div>
        \\<div id="highlight-tiles" class="hls"></div>
        \\</section>
        \\<div class="sec-h"><h2>Over time</h2></div>
        \\<div class="panel">
        \\<nav class="tabs" id="time-tabs" aria-label="Over time">
        \\<a href="#by-matchup" aria-current="page" data-tab="by-matchup">By matchup</a>
        \\<a href="#by-week" data-tab="by-week">By week</a>
        \\</nav>
        \\<div id="by-matchup" class="table-scroll"><table>
        \\<thead><tr><th>You</th><th>Against</th><th class="num">Games</th><th class="num">Wins</th><th>Gold diff at 10 min, oldest to newest</th></tr></thead>
        \\<tbody id="matchups"></tbody></table></div>
        \\<div id="by-week" class="table-scroll" hidden><table>
        \\<thead><tr><th>Week of</th><th class="num">Games</th><th class="num">Wins</th><th class="num">Gold diff at 14 min</th><th class="num">Against typical at 14 min</th></tr></thead>
        \\<tbody id="weeks"></tbody></table></div>
        \\</div>
        \\</div>
        \\<section class="your-data">
        \\<h2>Your data</h2>
        \\<p class="muted">Looking up a Riot ID fetches its recent games from the Riot
        \\Games API and keeps them, so the page loads fast and your history builds up. Each
        \\game lists its ten players with their Riot IDs as at that game, as other League
        \\statistics sites do. Details in the <a href="privacy.html">privacy policy</a>.</p>
        \\<p class="muted">Don't want your games here? Remove them and stop us collecting
        \\them again. To prove the account is yours, you set a given profile icon for a
        \\moment.</p>
        \\<p><button type="button" id="forget">Remove a Riot ID</button></p>
        \\<div id="forget-box" class="card" hidden>
        \\<p id="forget-text"></p>
        \\<p><img id="forget-icon" alt="" width="64" height="64" hidden></p>
        \\<p><button type="button" id="forget-check" hidden>I've set it: check</button></p>
        \\</div>
        \\</section>
        \\<script src="review.js" defer></script>
        \\<script src="your.js" defer></script>
        \\
    );
}

//! "Your games": a skeleton that static/your.js fills from the service (`meiolol api`,
//! src/api) at /api/ on the same host, or from data/your-example.json (`meiolol
//! your-example`) for the example. Facts about the player's own lanes against the
//! typical curve, never advice (docs/concept.md).

const std = @import("std");
const Writer = std.Io.Writer;
const prose = @import("prose.zig");

pub fn page(w: *Writer, info: prose.Info) Writer.Error!void {
    _ = info;
    try w.writeAll(
        \\<h1>Your games</h1>
        \\<p class="lead">Your lane in each recent ranked solo game, minute by minute, laid
        \\over how that matchup typically goes at your rank. Your highlights and streaks,
        \\then your weeks and your matchups over time.</p>
        \\<form id="lookup" class="lookup">
        \\<input id="riot-id" name="id" placeholder="Name#TAG" autocomplete="off" spellcheck="false" required>
        \\<button type="submit">Show my games</button>
        \\</form>
        \\<p id="example-offer" class="muted" hidden>No Riot ID to hand? <a href="your.html?example" id="example-link">See an example</a>:
        \\real ranked games of one player from our data, without their name.</p>
        \\<p id="status" class="note" hidden></p>
        \\<div id="player" hidden>
        \\<h2 id="player-name"></h2>
        \\<p id="player-rank" class="muted"></p>
        \\<section id="highlights" hidden>
        \\<h2>Highlights</h2>
        \\<div id="highlight-tiles" class="tiles"></div>
        \\<p id="highlights-note" class="muted"></p>
        \\</section>
        \\<h2>By week</h2>
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>Week of</th><th class="num">Games</th><th class="num">Wins</th><th class="num">Gold diff at 14 min</th><th class="num">Against typical at 14 min</th></tr></thead>
        \\<tbody id="weeks"></tbody></table></div>
        \\<h2>By matchup</h2>
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>You</th><th>Against</th><th class="num">Games</th><th class="num">Wins</th><th>Gold diff at 10 min, oldest to newest</th></tr></thead>
        \\<tbody id="matchups"></tbody></table></div>
        \\<h2>Games</h2>
        \\<p class="muted">Lines show you minus your lane opponent. The band is the middle
        \\half of games in the same matchup at your rank and patch, the line through it the
        \\typical (median) game. Under 200 games the typical curve is grey: more data
        \\needed.</p>
        \\<div class="tabs" id="stat-tabs">
        \\<button type="button" data-stat="gold" aria-pressed="true">Gold</button>
        \\<button type="button" data-stat="xp" aria-pressed="false">XP</button>
        \\<button type="button" data-stat="cs" aria-pressed="false">CS</button>
        \\</div>
        \\<div id="games" class="your-games"></div>
        \\</div>
        \\<h2>Your data</h2>
        \\<p class="muted">Looking up a Riot ID fetches its recent ranked games from the Riot
        \\Games API and keeps them, so the page loads fast and your history builds up. Only
        \\your own lane is shown: champions, never other players' names. Details in the
        \\<a href="privacy.html">privacy policy</a>.</p>
        \\<p class="muted">Don't want your games here? Remove them and stop us collecting
        \\them again. To prove the account is yours, you set a given profile icon for a
        \\moment.</p>
        \\<p><button type="button" id="forget">Remove a Riot ID</button></p>
        \\<div id="forget-box" class="card" hidden>
        \\<p id="forget-text"></p>
        \\<p><img id="forget-icon" alt="" width="64" height="64" hidden></p>
        \\<p><button type="button" id="forget-check" hidden>I've set it: check</button></p>
        \\</div>
        \\<script src="your.js" defer></script>
        \\
    );
}

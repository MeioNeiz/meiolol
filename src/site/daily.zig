//! The Daily Draft page: a skeleton that static/daily.js fills from daily/<n>.json
//! (made by src/daily.zig). Results, days in a row and archive stay in the browser.

const std = @import("std");
const Writer = std.Io.Writer;
const prose = @import("prose.zig");
const tpl = @import("html.zig").tpl;

pub fn page(w: *Writer, info: prose.Info) Writer.Error!void {
    try tpl.render(w,
        \\<h1>Daily Draft <span id="number" class="muted"></span></h1>
        \\<p class="lead">One real ranked game a day from recent games, the same for everyone.
        \\Guess the last pick, then the winner.</p>
        \\<p id="status" class="note">Loading…</p>
        \\<div id="daily" class="dd" hidden>
        \\<p id="about" class="muted"></p>
        \\<div class="board">
        \\<div class="card side-0"><h3>Blue side</h3><ol id="team-0" class="team"></ol><p class="bans" id="bans-0"></p></div>
        \\<div class="card side-1"><h3>Red side</h3><ol id="team-1" class="team"></ol><p class="bans" id="bans-1"></p></div>
        \\</div>
        \\<section id="q-pick" class="card question">
        \\<h2 id="q-pick-title">Last pick: who did they lock in?</h2>
        \\<p class="muted dd-q-note">Treat it as the last pick: the other nine are locked in
        \\and the bans are done. (Match data has no pick order, so it may not have been.)</p>
        \\<div id="options" class="dd-options"></div>
        \\</section>
        \\<section id="q-side" class="card question" hidden>
        \\<h2>Which side won?</h2>
        \\<div class="dd-sides"><button type="button" data-side="0">Blue side</button><button type="button" data-side="1">Red side</button></div>
        \\<p id="crowd" class="muted dd-crowd-note" hidden></p>
        \\</section>
        \\<section id="reveal" hidden>
        \\<div id="score" class="dd-score"></div>
        \\<div id="happened" class="tiles dd-tiles"></div>
        \\<p id="estimate" class="dd-paper"></p>
        \\<div id="scoreboard" class="dd-sbs" hidden></div>
        \\<h3 class="dd-h">Lanes at 14 minutes</h3>
        \\<ul id="lanes" class="dd-lanes"></ul>
        \\<p id="share-row"><button type="button" id="share">Share result</button> <span id="share-note" class="muted"></span></p>
        \\<details class="dd-how"><summary>How these facts are read</summary>
        \\<p class="muted">From patch {patch}'s ranked solo games, whichever patch the game was
        \\played on. The hidden slot is the pick the rest of the draft explains best, by its
        \\matchups and teammates more than its strength on the patch. A draft leans to a side only when our model is 95% sure it is not even;
        \\otherwise it reads "close". A lane or option's usual gold at 14 minutes is always
        \\shown, coloured only when it is 200 or more and clear of even by
        \\two standard errors on 200+ games, mostly the matchup's own; in this game, under 200
        \\gold is uncoloured. A reason ("good into", "better with") needs 400+ games and a
        \\difference larger than chance, and comes only from lane matchups and the few other
        \\pairings the data shows matter. How drafts like this tend to go, not a verdict on
        \\anyone's pick. <a href="method.html">Method</a>.</p></details>
        \\</section>
        \\<h2>Archive</h2>
        \\<ul id="archive" class="archive"></ul>
        \\</div>
        \\<script src="reasons.js" defer></script>
        \\<script src="daily.js" defer></script>
        \\
    , .{ .patch = info.patch });
}

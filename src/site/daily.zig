//! The Daily Draft page: a skeleton that static/daily.js fills from daily/<n>.json
//! (made by src/daily.zig). Results, days in a row and archive stay in the browser.

const std = @import("std");
const Writer = std.Io.Writer;
const prose = @import("prose.zig");

pub fn page(w: *Writer, info: prose.Info) Writer.Error!void {
    _ = info;
    try w.writeAll(
        \\<h1>Daily Draft <span id="number" class="muted"></span></h1>
        \\<p class="lead">A real ranked solo game, anonymised and at least a week old: the
        \\same one for everyone today. One champion is hidden. Guess which of four was played,
        \\then which side won. The reveal shows what happened and what this patch's games say
        \\about the draft.</p>
        \\<p id="status" class="note">Loading…</p>
        \\<div id="daily" hidden>
        \\<p id="about" class="muted"></p>
        \\<div class="board">
        \\<div class="card side-0"><h3>Blue side</h3><ol id="team-0" class="team"></ol><p class="bans" id="bans-0"></p></div>
        \\<div class="card side-1"><h3>Red side</h3><ol id="team-1" class="team"></ol><p class="bans" id="bans-1"></p></div>
        \\</div>
        \\<section id="q-pick" class="card question">
        \\<h2 id="q-pick-title">Which champion was played in the hidden slot?</h2>
        \\<p id="q-pick-hint" class="muted" hidden>Hidden: the pick our numbers say the rest
        \\of the draft explains best, by its matchups and teammates more than its strength
        \\this patch.</p>
        \\<div id="options" class="choices"></div>
        \\</section>
        \\<section id="q-side" class="card question" hidden>
        \\<h2>Which side won?</h2>
        \\<div class="choices"><button type="button" data-side="0">Blue side</button><button type="button" data-side="1">Red side</button></div>
        \\</section>
        \\<section id="reveal" hidden>
        \\<h2>What happened</h2>
        \\<p id="happened"></p>
        \\<p id="share-row"><button type="button" id="share">Share result</button> <span id="share-note" class="muted"></span></p>
        \\<p id="record" class="muted"></p>
        \\<h2>On paper</h2>
        \\<p id="estimate"></p>
        \\<div class="table-scroll"><table class="lanes">
        \\<thead><tr><th>Lane</th><th>Blue</th><th>Red</th><th class="num">Edge</th><th class="num">Games</th></tr></thead>
        \\<tbody id="lanes"></tbody></table></div>
        \\<h3>The four options in this draft</h3>
        \\<ul id="option-notes" class="card notes"></ul>
        \\<p class="muted">From this patch's games. A draft leans to a side only when our
        \\model is 95% sure it is not even, given how many games stand behind each lane, duo
        \\and matchup in it; otherwise it reads "close". A lane shows the side ahead, and a
        \\reason is listed, only with 400+ games and when the difference is larger than chance
        \\alone would give; other lanes say "few games" (under 400) or "no clear edge". Reasons
        \\come only from lane matchups and the few other pairings the data shows matter. This
        \\describes how drafts like this tend to go, not a verdict on anyone's pick.
        \\<a href="method.html">Method</a>.</p>
        \\</section>
        \\<h2>Archive</h2>
        \\<ul id="archive" class="archive"></ul>
        \\</div>
        \\<script src="reasons.js" defer></script>
        \\<script src="daily.js" defer></script>
        \\
    );
}

//! The Daily Draft page: a skeleton that static/daily.js fills from daily/<n>.json
//! (made by src/daily.zig). Results, streak and archive stay in the browser.

const std = @import("std");
const Writer = std.Io.Writer;
const prose = @import("prose.zig");

pub fn page(w: *Writer, info: prose.Info) Writer.Error!void {
    _ = info;
    try w.writeAll(
        \\<h1>Daily Draft <span id="number" class="muted"></span></h1>
        \\<p class="lead">A real ranked solo game, anonymised: the same one for everyone
        \\today. One champion is hidden. Guess which of four was played, then which side won.
        \\The reveal shows what happened and what this patch's numbers say about the draft.</p>
        \\<p id="status" class="note">Loading…</p>
        \\<div id="daily" hidden>
        \\<p id="about" class="muted"></p>
        \\<div class="board">
        \\<div class="card side-0"><h3>Blue side</h3><ol id="team-0" class="team"></ol><p class="bans" id="bans-0"></p></div>
        \\<div class="card side-1"><h3>Red side</h3><ol id="team-1" class="team"></ol><p class="bans" id="bans-1"></p></div>
        \\</div>
        \\<section id="q-pick" class="card question">
        \\<h2 id="q-pick-title">Which champion was played in the hidden slot?</h2>
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
        \\<h2>What the numbers say</h2>
        \\<p id="estimate"></p>
        \\<div class="table-scroll"><table class="lanes">
        \\<thead><tr><th>Lane</th><th>Blue</th><th>Red</th><th class="num">Edge</th><th class="num">Games</th></tr></thead>
        \\<tbody id="lanes"></tbody></table></div>
        \\<h3>The four options in this draft</h3>
        \\<ul id="option-notes" class="card notes"></ul>
        \\<p class="muted">Points are percentage points of win chance, estimated from this
        \\patch's games. Pairs with few games stay near zero, and lanes under 200 games are
        \\greyed out. The numbers describe how drafts like this tend to go; they are not a
        \\verdict on anyone's pick. <a href="method.html">Method</a>.</p>
        \\</section>
        \\<h2>Archive</h2>
        \\<ul id="archive" class="archive"></ul>
        \\</div>
        \\<script src="daily.js" defer></script>
        \\
    );
}

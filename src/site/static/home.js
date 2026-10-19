// Home page: the example player's most-swung game as a game review that steps through
// its biggest moments, previews of what every review has, and their highlights. All
// from data/your-example.json, one player per role with a switch; without it the page
// keeps its static parts only, previews hidden.
"use strict";

(async () => {
  const root = document.currentScript?.dataset.root ?? "";
  const { el, clock, signed, pct, icon } = Review;

  // Riot IDs Your games remembered on this device (your.js), to reopen in one click
  const form = document.querySelector("form.search");
  const recent = (() => {
    try {
      const list = JSON.parse(localStorage.getItem("your-recent") ?? "[]");
      return Array.isArray(list) ? list.filter((r) => typeof r?.id === "string") : [];
    } catch {
      return [];
    }
  })();
  if (form && recent.length) {
    const box = el("p", "recent");
    box.append(el("span", "", "On this device:"));
    for (const r of recent) {
      const a = el("a", "", r.id);
      a.href = `${root}your.html#id=${encodeURIComponent(r.id)}`;
      box.append(a);
    }
    const forget = el("button", "link", "Forget on this device");
    forget.type = "button";
    forget.addEventListener("click", () => {
      try {
        localStorage.removeItem("your-recent");
        localStorage.removeItem("your-last");
        sessionStorage.removeItem("your-hash");
      } catch {}
      box.remove();
    });
    box.append(forget);
    form.after(box);
  }

  let all;
  try {
    [, all] = await Promise.all([Review.init(root), fetch(`${root}data/your-example.json`).then((r) => r.json())]);
  } catch {
    return;
  }
  // An example per role (src/api/example.zig); an older file is one example of no role
  const byRole = !all.state;
  const demo = document.getElementById("demo");
  const links = [...document.querySelectorAll('a[href$="your.html#example"]')];
  let box, timer = 0;
  const tabs = el("nav", "tabs");
  tabs.setAttribute("aria-label", "Example role");
  for (const [role, label] of [["top", "Top"], ["jungle", "Jungle"], ["mid", "Mid"], ["bot", "Bot"], ["support", "Support"]]) {
    if (!byRole || !all[role]) continue;
    const a = el("a", "", label);
    a.href = `${root}your.html#example=${role}`;
    a.dataset.role = role;
    a.addEventListener("click", (e) => {
      e.preventDefault();
      show(role);
    });
    tabs.append(a);
  }
  if (tabs.children.length > 1) demo.querySelector(".panel-h").after(tabs);
  show(byRole ? all.default : "");

  function show(role) {
    const body = byRole ? all[role] : all;
    clearInterval(timer);
    box?.remove();
    for (const id of ["v-turn", "v-death", "v-lane", "home-hls"]) {
      const x = document.getElementById(id)?.closest(".viz, section");
      if (x) x.hidden = true;
    }
    for (const a of tabs.children) {
      if (a.dataset.role === role) a.setAttribute("aria-current", "page");
      else a.removeAttribute("aria-current");
    }
    for (const a of links) a.href = `${root}your.html#example${role ? `=${role}` : ""}`;
    const games = (body.report?.games ?? []).filter((g) => !g.remake && g.win_chance?.length > 1 && g.duration_s >= 300);
    if (!games.length) return;
    const swing = (g) => (g.turning ? Math.abs(g.turning.to - g.turning.from) : 0);
    const g = games.reduce((a, b) => (swing(b) > swing(a) ? b : a));
    const date = (x) => new Date(x.start_ms).toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: "UTC" });

    // The four moments that moved win chance most, played through in time order
    const M = Review.moments(g);
    const keep = M.map((m, i) => [Math.abs(m.d) * (m.kind === "death" ? 0.3 : 1), i]).sort((a, b) => b[0] - a[0]).slice(0, 4).map((x) => x[1]).sort((a, b) => a - b);
    box = el("div");
    demo.append(box);
    const review = Review.render(box, g, { date, lane: false, keep });
    demo.hidden = false;
    if (review && keep.length) {
      const n = g.win_chance.length - 1;
      let k = Math.max(0, keep.indexOf(M.findIndex((m) => m.kind === "turn")));
      const step = () => review.set(Math.min(n, Math.ceil(M[keep[k]].minute)), keep[k]);
      step();
      const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
      timer = still ? 0 : setInterval(() => {
        k = (k + 1) % keep.length;
        step();
      }, 2800);
      // Any pick stops the tour where the visitor is looking
      box.addEventListener("click", () => clearInterval(timer), { capture: true });
      box.addEventListener("keydown", () => clearInterval(timer), { capture: true });
      box.addEventListener("focusin", () => clearInterval(timer));
    }

    // Previews: the turning minute, three deaths that cost most, the lane against typical
    const t = g.turning;
    const turn = document.getElementById("v-turn");
    if (t && turn) {
      const s = Review.spark(g);
      s.style.cssText = "width:100%;height:54px;display:block";
      const p = el("p", "small");
      p.style.margin = "8px 0 0";
      p.append(el("b", "t-turn", `${t.minute - 1}-${t.minute} min `), `${t.from}% → ${t.to}%: ${t.kills} kills for your team${t.taken?.length ? `, took ${Review.list(t.taken)}` : ""}`);
      turn.replaceChildren(s, p);
      turn.hidden = false;
    }
    const deaths = document.getElementById("v-death");
    const worst = (g.death_costs ?? []).filter((d) => d.after < d.before).sort((a, b) => (a.after - a.before) - (b.after - b.before)).slice(0, 3).sort((a, b) => a.t_s - b.t_s);
    if (deaths && worst.length) {
      deaths.replaceChildren(...worst.map((d) => {
        const li = el("li");
        const what = el("span");
        if (d.killer !== undefined) what.append(icon(d.killer));
        what.append(`${clock(d.t_s)} · ${d.gold} gold${d.lost?.length ? `, then ${d.lost[0]}` : ""}`);
        li.append(what, el("b", "num t-cost", pct(d.after - d.before)));
        return li;
      }));
      deaths.closest(".viz").hidden = false;
    }
    const lane = document.getElementById("v-lane");
    const hasCurve = (x) => x.lane?.curve && x.lane.gold.length >= Review.LANE_END && x.lane.curve.n[Review.LANE_END - 1] >= Review.MIN_N;
    // The featured game's lane; another game's only when it has none, and then named
    const lg = hasCurve(g) ? g : games.find(hasCurve);
    if (lane && lg) {
      const l = lg.lane, c = l.curve, i = Review.LANE_END - 1;
      const row = (label, value, diff, good, text) => {
        const li = el("li");
        const b = el("b", "num", `${value} `);
        b.append(el("span", `pill ${diff === 0 ? "n" : good ? "g" : "r"}`, text));
        li.append(el("span", "", label), b);
        return li;
      };
      const sec = (s) => `${s > 0 ? "+" : s < 0 ? "−" : ""}${Math.abs(s)}s`;
      const rows = [row(`Gold lead at ${Review.LANE_END}`, signed(l.gold[i]), l.gold[i] - c.gold[i][1], l.gold[i] >= c.gold[i][1], signed(l.gold[i] - c.gold[i][1]))];
      if (l.level6?.[0] != null && c.level6?.[0] != null) rows.push(row("Level 6", clock(l.level6[0]), l.level6[0] - c.level6[0], l.level6[0] <= c.level6[0], sec(l.level6[0] - c.level6[0])));
      if (l.first_item?.[0] != null && c.first_item?.[0] != null) rows.push(row("First item", clock(l.first_item[0]), l.first_item[0] - c.first_item[0], l.first_item[0] <= c.first_item[0], sec(l.first_item[0] - c.first_item[0])));
      lane.replaceChildren(...rows);
      if (lg !== g) {
        const vs = lg.opponent !== undefined ? ` vs ${Review.champName(lg.opponent)}` : "";
        const note = el("li", "small muted", `From another game: ${Review.champName(lg.champion)}${vs}, ${date(lg)}`);
        lane.append(note);
      }
      lane.closest(".viz").hidden = false;
    }

    const hl = Review.highlights(body.report.games, date);
    const pick = ["record", "comeback", "costliest", "swing"].map((k) => hl.find((h) => h.key === k)).filter(Boolean);
    const cards = document.getElementById("home-hls");
    if (cards && pick.length >= 2) {
      cards.replaceChildren(...pick.map(Review.highlightCard));
      cards.closest("section").hidden = false;
    }
  }
})();

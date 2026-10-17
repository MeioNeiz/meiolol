// Game review, shared by Your games (your.js) and the home page's demo (home.js): one
// game's win chance by minute with its bar, the key moments that moved it, what each
// death cost and the lane against the typical game. Facts about the player's own game,
// never advice. Strings from the service go in with textContent, never as HTML.
"use strict";

const Review = (() => {
  const LANE_END = 14;
  const MIN_N = 10;
  const THIN = 200;
  const SOLO = 420;
  // Minutes that moved win chance at least this much are key moments
  const SWING = 10;
  // Deaths costing at least this much win chance, or followed by an objective while the
  // team's chance did not rise, are costly
  const COSTLY = 5;

  let champs = new Map();
  let ddragon = "";
  let chartWasm = null;

  const el = (tag, cls, text) => {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  };
  const SVG_NS = "http://www.w3.org/2000/svg";
  const svgEl = (tag, attrs) => {
    const e = document.createElementNS(SVG_NS, tag);
    for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
    return e;
  };
  const clock = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;
  const plural = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`;
  const signed = (x) => (x > 0 ? `+${x.toLocaleString("en-GB")}` : x < 0 ? `−${(-x).toLocaleString("en-GB")}` : "0");
  const pct = (x) => `${x > 0 ? "+" : x < 0 ? "−" : ""}${Math.abs(x)}%`;
  const list = (xs) => (xs.length > 1 ? `${xs.slice(0, -1).join(", ")} and ${xs[xs.length - 1]}` : xs[0] ?? "");

  // `root`: from the page to the site root, where data/ and chart.wasm are
  async function init(root = "", { lane = false } = {}) {
    const jobs = [
      fetch(`${root}data/champions.json`).then((r) => r.json()).then((j) => {
        ddragon = j.ddragon;
        champs = new Map(j.champions.map((c) => [c.id, c]));
      }).catch(() => {}),
    ];
    if (lane) {
      jobs.push(WebAssembly.instantiateStreaming(fetch(`${root}chart.wasm`)).then(({ instance }) => {
        chartWasm = instance.exports;
      }).catch(() => {}));
    }
    await Promise.all(jobs);
  }

  const champName = (id) => champs.get(id)?.name ?? "?";
  const iconUrl = (id) => {
    const c = champs.get(id);
    return c && ddragon ? `https://ddragon.leagueoflegends.com/cdn/${ddragon}/img/champion/${c.key}.png` : "";
  };
  function icon(id, cls) {
    const img = el("img", cls);
    const src = iconUrl(id);
    if (src) img.src = src;
    img.alt = "";
    img.width = img.height = 24;
    img.loading = "lazy";
    return img;
  }

  // The minutes and deaths that moved the team's win chance, in time order
  function moments(g) {
    const out = [];
    const wc = g.win_chance ?? [];
    const t = g.turning;
    if (t) {
      const what = [`${plural(t.kills, "kill")} and ${plural(t.deaths, "death")} for your team`];
      if (t.your_deaths) what.push(t.your_deaths > 1 ? `you died ${t.your_deaths} times` : "you died");
      else if (t.your_kills) what.push(`you took part in ${plural(t.your_kills, "kill")}`);
      if (t.taken?.length) what.push(`your team took ${list(t.taken)}`);
      if (t.lost?.length) what.push(`the enemy took ${list(t.lost)}`);
      out.push({ kind: "turn", minute: t.minute, t_s: (t.minute - 1) * 60, title: "Turning minute", text: `${list(what)}.`, d: t.to - t.from });
    }
    for (let m = 1; m < wc.length; m++) {
      const d = wc[m] - wc[m - 1];
      if (Math.abs(d) < SWING || (t && m === t.minute)) continue;
      out.push({
        kind: d > 0 ? "gain" : "drop",
        minute: m,
        t_s: (m - 1) * 60,
        title: d > 0 ? "Big minute" : "Swing against you",
        text: `Your team's win chance ${wc[m - 1]}% to ${wc[m]}%.`,
        d,
      });
    }
    for (const x of g.death_costs ?? []) {
      const d = x.before !== undefined && x.after !== undefined ? x.after - x.before : 0;
      const costly = d <= -COSTLY || (x.lost?.length > 0 && d <= 0);
      let text = `${x.killer !== undefined ? champName(x.killer) : "Executed"}${x.assists ? ` and ${plural(x.assists, "other")}` : ""}: ${x.gold} kill gold`;
      if (x.lost?.length) text += `, then the enemy took ${list(x.lost)}`;
      out.push({ kind: costly ? "cost" : "death", minute: x.t_s / 60, t_s: x.t_s, title: costly ? "Costly death" : "Death", text: `${text}.`, d, killer: x.killer });
    }
    return out.sort((a, b) => a.t_s - b.t_s);
  }

  const KINDS = {
    turn: { icon: "★", colour: "var(--turn)" },
    gain: { icon: "↑", colour: "var(--gain)" },
    drop: { icon: "↓", colour: "var(--drop)" },
    cost: { icon: "✕", colour: "var(--cost)" },
    death: { icon: "✕", colour: "var(--death)" },
  };
  const badge = (kind) => el("span", `badge c-${kind}`, KINDS[kind].icon);

  // Win chance at a fractional minute, on the line between whole minutes
  function at(wc, m) {
    const last = wc.length - 1;
    const lo = Math.min(Math.floor(m), last), hi = Math.min(lo + 1, last);
    return wc[lo] + (wc[hi] - wc[lo]) * (m - lo);
  }

  // Drawn at the holder's width in pixels, so labels keep their size on any screen
  function winChart(g, M, minute, pick, width) {
    const wc = g.win_chance;
    const n = wc.length - 1;
    const W = Math.max(300, Math.round(width || 600)), H = W > 640 ? 250 : 200;
    const L = 30, R = 8, T = 26, B = 20;
    const x = (m) => L + ((W - L - R) * m) / Math.max(n, 1);
    const y = (p) => T + ((H - T - B) * (100 - p)) / 100;
    const svg = svgEl("svg", { class: "wc", viewBox: `0 0 ${W} ${H}`, role: "img", "aria-label": "Your team's win chance by minute" });
    const id = `wc${Math.random().toString(36).slice(2, 8)}`;
    svg.innerHTML = `<defs><linearGradient id="${id}u" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e9ecf1" stop-opacity=".22"/><stop offset="1" stop-color="#e9ecf1" stop-opacity=".02"/></linearGradient>
      <linearGradient id="${id}d" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f0596b" stop-opacity=".02"/><stop offset="1" stop-color="#f0596b" stop-opacity=".3"/></linearGradient>
      <clipPath id="${id}cu"><rect x="0" y="0" width="${W}" height="${y(50)}"/></clipPath><clipPath id="${id}cd"><rect x="0" y="${y(50)}" width="${W}" height="${H}"/></clipPath></defs>`;
    for (const p of [100, 75, 25, 0]) svg.append(svgEl("line", { class: "gl", x1: L, x2: W - R, y1: y(p), y2: y(p) }));
    for (const p of [100, 50, 0]) {
      const t = svgEl("text", { x: 0, y: y(p) + 3.5 });
      t.textContent = `${p}%`;
      svg.append(t);
    }
    const step = n > 40 ? 10 : 5;
    for (let m = step; m < n; m += step) {
      const t = svgEl("text", { x: x(m), y: H - 4, "text-anchor": "middle" });
      t.textContent = `${m}:00`;
      svg.append(t);
    }
    svg.append(svgEl("line", { class: "mid", x1: L, x2: W - R, y1: y(50), y2: y(50) }));
    const pts = wc.map((p, m) => `${x(m).toFixed(1)},${y(p).toFixed(1)}`);
    const area = `M${x(0)},${y(50)} L${pts.join(" L")} L${x(n)},${y(50)} Z`;
    svg.append(svgEl("path", { d: area, fill: `url(#${id}u)`, "clip-path": `url(#${id}cu)` }));
    svg.append(svgEl("path", { d: area, fill: `url(#${id}d)`, "clip-path": `url(#${id}cd)` }));
    const t = g.turning;
    if (t) {
      const mx = x(t.minute - 0.5);
      svg.append(svgEl("rect", { class: "turn", x: x(t.minute - 1), y: T, width: x(t.minute) - x(t.minute - 1), height: H - T - B }));
      const label = svgEl("text", { class: "note", x: Math.min(W - R, Math.max(L, mx)), y: 12, "text-anchor": mx < L + 90 ? "start" : mx > W - 90 ? "end" : "middle" });
      label.textContent = `★ Turning minute ${t.from}% → ${t.to}%`;
      svg.append(label, svgEl("line", { class: "note-line", x1: mx, x2: mx, y1: 16, y2: T }));
    }
    svg.append(svgEl("path", { class: "ln", d: `M${pts.join(" L")}` }));
    // Pick a minute anywhere on the chart; moments on top take their own clicks
    if (pick) {
      const hit = svgEl("rect", { class: "hit", x: L, y: T, width: W - L - R, height: H - T - B });
      hit.addEventListener("click", (e) => {
        const r = svg.getBoundingClientRect();
        const m = Math.round((((e.clientX - r.left) / r.width) * W - L) / ((W - L - R) / n));
        pick(Math.max(0, Math.min(n, m)), -1);
      });
      svg.append(hit);
    }
    M.forEach((mo, i) => {
      const m = Math.min(mo.minute, n);
      const p = mo.kind === "death" || mo.kind === "cost" ? at(wc, m) : wc[m];
      const c = svgEl("circle", { class: "mo", cx: x(m), cy: y(p), r: mo.kind === "death" ? 3.5 : 5, fill: KINDS[mo.kind].colour });
      const tip = svgEl("title", {});
      tip.textContent = `${clock(mo.t_s)} ${mo.title}`;
      c.append(tip);
      if (pick) {
        const go = () => pick(Math.min(n, Math.ceil(mo.minute)), i);
        c.setAttribute("role", "button");
        c.setAttribute("tabindex", "0");
        c.setAttribute("aria-label", tip.textContent);
        c.addEventListener("click", go);
        c.addEventListener("keydown", (e) => {
          if (e.key !== "Enter" && e.key !== " ") return;
          e.preventDefault();
          go();
        });
      }
      svg.append(c);
    });
    svg.append(svgEl("line", { class: "cursor", x1: x(minute), x2: x(minute), y1: T, y2: H - B }));
    svg.append(svgEl("circle", { class: "cursor-dot", cx: x(minute), cy: y(wc[minute]), r: 4 }));
    return svg;
  }

  // A game's win chance in 100x26, for the strip of games
  function spark(g) {
    const svg = svgEl("svg", { viewBox: "0 0 100 26", preserveAspectRatio: "none", "aria-hidden": "true" });
    const wc = g.win_chance;
    if (!wc || wc.length < 2) return svg;
    const n = wc.length - 1;
    const x = (m) => (m / n) * 100, y = (p) => 2 + (1 - p / 100) * 22;
    svg.append(svgEl("line", { x1: 0, x2: 100, y1: y(50), y2: y(50), stroke: "rgba(255,255,255,.12)", "stroke-dasharray": "2 2", "vector-effect": "non-scaling-stroke" }));
    if (g.turning) svg.append(svgEl("rect", { x: x(g.turning.minute - 1), y: 0, width: x(1), height: 26, fill: "#f5c451", opacity: 0.45 }));
    svg.append(svgEl("polyline", { points: wc.map((p, m) => `${x(m)},${y(p)}`).join(" "), fill: "none", stroke: g.win ? "#3ccf91" : "#f0596b", "stroke-width": 1.5, "vector-effect": "non-scaling-stroke" }));
    return svg;
  }

  const QUEUES = { 420: "Solo/duo", 440: "Flex", 400: "Draft", 480: "Swiftplay" };

  function strip(g, opts) {
    const s = el("div", "rv-strip");
    s.append(el("span", `res ${g.remake ? "remake" : g.win ? "win" : "loss"}`, g.remake ? "REMAKE" : g.win ? "WIN" : "LOSS"));
    const mu = el("span", "rv-matchup");
    mu.append(icon(g.champion), champName(g.champion));
    if (g.opponent !== undefined) mu.append(el("span", "vs", "vs"), icon(g.opponent, "opp"), champName(g.opponent));
    s.append(mu);
    const facts = el("span", "facts-inline");
    const fact = (b, rest) => {
      const f = el("span");
      f.append(el("b", "num", b));
      if (rest) f.append(` ${rest}`);
      facts.append(f);
    };
    fact(`${g.kills}/${g.deaths}/${g.assists}`);
    if (g.queue !== undefined) fact(QUEUES[g.queue] ?? `queue ${g.queue}`);
    fact(g.role ?? "no lane");
    fact(clock(g.duration_s));
    fact(opts.date ? opts.date(g) : "", `patch ${g.patch}`);
    s.append(facts);
    if (opts.pager) {
      const { index, count, go } = opts.pager;
      const p = el("span", "pager");
      const prev = el("button", "", "‹");
      prev.type = "button";
      prev.setAttribute("aria-label", "Newer game");
      prev.disabled = index === 0;
      prev.addEventListener("click", () => go(index - 1));
      const next = el("button", "", "›");
      next.type = "button";
      next.setAttribute("aria-label", "Older game");
      next.disabled = index === count - 1;
      next.addEventListener("click", () => go(index + 1));
      p.append(prev, `Game ${index + 1} of ${count}`, next);
      s.append(p);
    }
    return s;
  }

  // A death's change is the team's whole minute, which can rise while you die: only a
  // costly death gets a colour
  const tone = (m) => (m.kind === "cost" ? "t-cost" : m.kind === "death" ? "" : m.d > 0 ? "t-gain" : "t-cost");

  function momentList(M, onPick, keep) {
    const ul = el("ul", "moments");
    M.forEach((m, i) => {
      if (keep && !keep.includes(i)) return;
      const li = el("li");
      li.dataset.i = i;
      li.tabIndex = 0;
      const what = el("span", "what");
      what.append(el("b", "", m.title));
      const sub = el("div");
      if (m.killer !== undefined) sub.append(icon(m.killer));
      sub.append(m.text);
      what.append(sub);
      li.append(el("span", "t num", clock(m.t_s)), badge(m.kind), what, el("span", `d num ${tone(m)}`, pct(m.d)));
      const go = () => onPick(i);
      li.addEventListener("click", go);
      li.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          go();
        }
      });
      ul.append(li);
    });
    if (!ul.children.length) {
      const li = el("li", "empty", "No minute moved your team's win chance by 10 points or more, and no deaths.");
      ul.append(li);
    }
    return ul;
  }

  function counts(M) {
    const box = el("div", "counts");
    const n = (k) => M.filter((m) => m.kind === k).length;
    for (const [k, label] of [["turn", "Turning minute"], ["gain", "Big minutes"], ["drop", "Swings against you"], ["cost", "Costly deaths"]]) {
      const d = el("div");
      const b = el("b");
      b.append(badge(k), String(n(k)));
      d.append(b, el("span", "", label));
      box.append(d);
    }
    return box;
  }

  // The lane chart (src/site/lanechart.zig) through chart_wasm.zig, whose header has the
  // input layout. Names come back escaped by the Zig templates, so the SVG may go in as
  // markup
  function laneSvg(aria, a, b, band, line, you) {
    const w = chartWasm;
    if (!w) return null;
    const enc = new TextEncoder();
    const texts = [aria, a, b].map((t) => enc.encode(t));
    const ints = [...texts.map((t) => t.length), band.length, line.length, you.length, ...band.flat(), ...line, ...you];
    const len = 4 * ints.length + texts.reduce((n, t) => n + t.length, 0);
    const view = new DataView(w.memory.buffer, w.input(), len);
    ints.forEach((v, i) => view.setInt32(4 * i, v, true));
    let pos = 4 * ints.length;
    for (const t of texts) {
      new Uint8Array(w.memory.buffer, w.input() + pos, t.length).set(t);
      pos += t.length;
    }
    const n = w.render(len);
    return n ? new TextDecoder().decode(new Uint8Array(w.memory.buffer, w.output(), n)) : null;
  }

  function laneChart(g, stat) {
    const l = g.lane, c = l.curve;
    const thin = !c || c.games < THIN;
    const fig = el("figure", `chart${thin ? " thin" : ""}`);
    // Typical minutes while enough games are still going (a prefix: games only end)
    const band = c ? c[stat] : null;
    const shown = band ? band.slice(0, l[stat].length).filter((_, i) => c.n[i] >= MIN_N) : [];
    const svg = laneSvg(`${stat} difference by minute, you minus your lane opponent`, "You", "Opponent", shown.map((q) => [q[0], q[2]]), shown.map((q) => q[1]), l[stat]);
    if (svg) fig.insertAdjacentHTML("afterbegin", svg);
    fig.append(el("figcaption", "", c
      ? `You minus your lane opponent. Typical: ${champName(g.champion)} vs ${champName(g.opponent)}, ${c.bracket}${c.pooled ? " (too few games at your rank)" : ""}, patch ${c.patch}, ${plural(c.games, `${g.queue === undefined || g.queue === SOLO ? "" : "solo/duo "}game`)}${thin ? ". More data needed" : ""}.`
      : `No typical game yet for ${champName(g.champion)} vs ${champName(g.opponent)} in this role: only your game is shown.`));
    return fig;
  }

  function laneTable(g) {
    const l = g.lane, c = l.curve;
    const i = LANE_END - 1;
    const solid = (k) => c && c.n[k] >= MIN_N;
    const t = el("table", "lane");
    const head = el("tr");
    for (const h of ["", "You", "Opponent", "Typical", "vs typical"]) head.append(el("th", "", h));
    t.append(head);
    const pill = (v, good, text) => {
      const s = el("span", `pill ${v === 0 ? "n" : good ? "g" : "r"}`, text);
      return s;
    };
    const row = (label, you, opp, typ, diff) => {
      const tr = el("tr");
      tr.append(el("td", "", label), el("td", "you", you), el("td", "", opp ?? ""), el("td", "", typ ?? "·"));
      const d = el("td");
      if (diff) d.append(diff);
      tr.append(d);
      t.append(tr);
    };
    if (l.gold.length > i) {
      const typ = solid(i) ? c.gold[i][1] : null;
      row(`Gold lead at ${LANE_END}`, signed(l.gold[i]), null, typ === null ? null : signed(typ), typ === null ? null : pill(l.gold[i] - typ, l.gold[i] >= typ, signed(l.gold[i] - typ)));
    }
    const timing = (label, mine, typical) => {
      if (!mine || mine[0] == null) return;
      const typ = typical?.[0];
      const diff = typ == null ? null : mine[0] - typ;
      row(label, clock(mine[0]), mine[1] != null ? clock(mine[1]) : null, typ == null ? null : clock(typ), diff === null ? null : pill(diff, diff <= 0, `${diff > 0 ? "+" : diff < 0 ? "−" : ""}${Math.abs(diff)}s`));
    };
    timing("Level 6", l.level6, c?.level6);
    timing("First legendary item", l.first_item, c?.first_item);
    if (l.cs10 !== undefined) row("CS at 10", String(l.cs10));
    row(`Deaths before ${LANE_END}`, String(l.lane_deaths));
    row("Kills you took part in", String(l.lane_kills));
    return t;
  }

  function laneSwings(l) {
    const ul = el("ul", "mini-list");
    const ref = (s) => (s.against === "typical" ? "the typical game" : "an even lane");
    for (const [s, label] of [[l.rise, "Biggest gain"], [l.fall, "Biggest drop"]]) {
      if (!s) continue;
      const li = el("li");
      li.append(el("span", "", `${label} against ${ref(s)}, ${s.from}-${s.to} min: ${plural(s.deaths, "death")}, ${plural(s.kills, "kill")} you took part in`));
      li.append(el("b", `num ${s.change >= 0 ? "t-gain" : "t-cost"}`, signed(s.change)));
      ul.append(li);
    }
    if (ul.children.length) ul.style.padding = "4px 14px 10px";
    return ul;
  }

  function lanePanel(g) {
    const p = el("div", "panel rv-lane");
    const h = el("div", "panel-h");
    h.append(el("b", "", `Lane, first ${LANE_END} min`));
    const box = el("div");
    if (chartWasm) {
      const seg = el("span", "rv-seg");
      const draw = (stat) => {
        box.replaceChildren(laneChart(g, stat));
        for (const b of seg.children) b.setAttribute("aria-pressed", String(b.dataset.stat === stat));
      };
      for (const [stat, label] of [["gold", "Gold"], ["xp", "XP"], ["cs", "CS"]]) {
        const b = el("button", "", label);
        b.type = "button";
        b.dataset.stat = stat;
        b.addEventListener("click", () => draw(stat));
        seg.append(b);
      }
      h.append(seg);
      draw("gold");
    }
    p.append(h, box, laneTable(g), laneSwings(g.lane));
    return p;
  }

  // Fun facts from recent games (newest first), each only when there is something to
  // say, so a short history shows fewer rather than empty ones. key names each for the
  // home page; champ: a champion to show beside it; tone: gain, cost or turn colour
  function highlights(all, date) {
    // Under 5 minutes: an early surrender after a leaver. A real result (record and
    // streaks count it), but never a record for length, KDA or lane
    const played = all.filter((g) => !g.remake);
    const games = played.filter((g) => g.duration_s >= 300);
    const out = [];
    if (!played.length) return out;
    const add = (key, value, label, sub, champ, tone) => out.push({ key, value, label, sub, champ, tone });
    const on = (g) => `${champName(g.champion)}${g.opponent !== undefined ? ` vs ${champName(g.opponent)}` : ""}, ${g.win ? "win" : "loss"}, ${date(g)}`;
    const best = (xs, key) => xs.reduce((a, b) => (key(b) > key(a) ? b : a), xs[0]);

    const wins = played.filter((g) => g.win).length;
    add("record", `${wins}–${played.length - wins}`, "Record", `${Math.round((100 * wins) / played.length)}% wins in ${plural(played.length, "game")}`);
    let streak = 1;
    while (streak < played.length && played[streak].win === played[0].win) streak++;
    let longest = 0;
    for (let i = 0, run = 0; i < played.length; i++) {
      run = played[i].win ? run + 1 : 0;
      longest = Math.max(longest, run);
    }
    if (streak >= 2) add("streak", `${streak} ${played[0].win ? "wins" : "losses"}`, "Current streak", null, null, played[0].win ? "gain" : "cost");
    if (longest >= 2 && !(played[0].win && streak === longest)) add("longest-streak", plural(longest, "win"), "Longest win streak");
    if (!games.length) return out;

    const won = games.filter((g) => g.win);
    const at = LANE_END - 1;
    const lanes = games.filter((g) => g.lane && g.lane.gold.length > at);
    if (lanes.length) {
      const gold14 = (g) => g.lane.gold[at];
      const comeback = won.filter((g) => lanes.includes(g) && gold14(g) < 0);
      if (comeback.length) {
        const c = best(comeback, (g) => -gold14(g));
        add("comeback", signed(gold14(c)), "Won from furthest behind", `lane gold at ${LANE_END} min: ${on(c)}`, c.champion, "gain");
      }
      const lead = best(lanes, gold14);
      // A lost lead shows below as the furthest-ahead loss
      if (gold14(lead) > 0 && lead.win) add("lead", signed(gold14(lead)), `Biggest lane lead at ${LANE_END} min`, on(lead), lead.champion);
      const thrown = lanes.filter((g) => !g.win && gold14(g) > 0);
      if (thrown.length) {
        const t = best(thrown, gold14);
        add("thrown", signed(gold14(t)), "Lost from furthest ahead", `lane gold at ${LANE_END} min: ${on(t)}`, t.champion, "cost");
      }
      const typical = (g) => (g.lane.curve && g.lane.curve.n[at] >= MIN_N ? gold14(g) - g.lane.curve.gold[at][1] : null);
      const vs = lanes.filter((g) => typical(g) !== null);
      if (vs.length) {
        const v = best(vs, typical);
        if (typical(v) > 0) add("above", signed(typical(v)), `Furthest above the typical game at ${LANE_END} min`, on(v), v.champion);
      }
    }
    const costs = games.filter((g) => g.death_costs);
    const deaths = costs.flatMap((g) => g.death_costs.map((d) => ({ g, d })));
    if (deaths.length) {
      // Ranked by what followed first, so that is the headline; gold only when nothing did
      const worst = best(deaths, (x) => x.d.gold + 1000 * (x.d.lost?.length ?? 0));
      const lost = worst.d.lost ?? [];
      if (lost.length) {
        const took = lost.length > 2 ? `${lost.length} objectives` : list(lost);
        add("costliest", took, "Costliest death: what the enemy took next", `${clock(worst.d.t_s)}, ${worst.d.gold} gold, then ${list(lost)}: ${on(worst.g)}`, worst.d.killer, "cost");
      } else {
        add("costliest", `${worst.d.gold} gold`, "Costliest death: kill gold given", `${clock(worst.d.t_s)}: ${on(worst.g)}`, worst.d.killer, "cost");
      }
    }
    const turns = games.filter((g) => g.turning);
    if (turns.length) {
      const swing = (g) => Math.abs(g.turning.to - g.turning.from);
      const b = best(turns, swing);
      add("swing", `${b.turning.from}% → ${b.turning.to}%`, "Biggest one-minute swing", `${b.turning.minute - 1}-${b.turning.minute} min: ${on(b)}`, b.champion, "turn");
    }
    if (costs.length) {
      const gold = deaths.reduce((a, x) => a + x.d.gold, 0);
      add("gift", Math.round(gold / costs.length).toLocaleString("en-GB"), "Kill gold given away per game", `${plural(deaths.length, "death")} in ${plural(costs.length, "game")}`);
    }
    if (deaths.length) {
      const followed = deaths.filter((x) => x.d.lost?.length).length;
      add("followed", `${followed} of ${deaths.length}`, "Deaths the enemy took an objective after", "within a minute");
    }
    if (lanes.length) {
      const clean = lanes.filter((g) => g.lane.lane_deaths === 0).length;
      add("clean", `${clean} of ${lanes.length}`, `Lanes without a death before ${LANE_END} min`);
    }
    const long = best(games, (g) => g.duration_s);
    add("long", clock(long.duration_s), "Longest game", on(long), long.champion);
    if (won.length) {
      const fast = best(won, (g) => -g.duration_s);
      add("fast", clock(fast.duration_s), "Fastest win", on(fast), fast.champion);
    }
    const kda = (g) => (g.kills + g.assists) / Math.max(1, g.deaths);
    const top = best(games, kda);
    add("kda", kda(top).toFixed(1), "Best KDA", `${top.kills}/${top.deaths}/${top.assists}, ${on(top)}`, top.champion);
    const counts = new Map();
    for (const g of games) {
      const c = counts.get(g.champion) ?? { games: 0, wins: 0 };
      c.games++;
      c.wins += g.win ? 1 : 0;
      counts.set(g.champion, c);
    }
    const [main, m] = [...counts].reduce((a, b) => (b[1].games > a[1].games ? b : a));
    if (m.games >= 2) add("main", champName(main), "Most played", `${plural(m.games, "game")}, ${plural(m.wins, "win")}`, main);
    return out;
  }

  function highlightCard(h) {
    const c = el("div", "panel hlc");
    const b = el("b", h.tone ? `t-${h.tone}` : "", h.value);
    c.append(b, el("span", "", h.label));
    if (h.sub) {
      const s = el("small");
      if (h.champ !== undefined && h.champ !== null) s.append(icon(h.champ));
      s.append(h.sub);
      c.append(s);
    }
    return c;
  }

  // The whole review into `box`. opts: pager {index, count, go}, date(g) for the strip,
  // lane: false for no lane panel, keep: moment indexes to list (default all)
  function render(box, g, opts = {}) {
    box.replaceChildren(strip(g, opts));
    if (g.remake) {
      box.append(el("p", "panel rv-empty", "A remake: nobody's game counts, so there is nothing to review."));
      return null;
    }
    const wc = g.win_chance;
    const M = moments(g);
    const panel = el("div", "panel");
    const h = el("div", "panel-h");
    h.append(el("b", "", "Win chance"), el("span", "", "your team, minute by minute, from gold, XP and objectives as in Platinum+ games"));
    panel.append(h);
    let set = () => {};
    if (wc?.length > 1) {
      const wrap = el("div", "wc-wrap");
      const bar = el("div", "evalbar");
      const fill = el("i"), val = el("span");
      bar.append(fill, val);
      const holder = el("div");
      wrap.append(bar, holder);
      panel.append(wrap, counts(M));
      const ml = momentList(M, (i) => set(Math.min(wc.length - 1, Math.ceil(M[i].minute)), i), opts.keep);
      set = (minute, i) => {
        // The chart is redrawn: a keyboard user keeps their place on the same dot
        const dot = [...holder.querySelectorAll(".mo")].indexOf(document.activeElement);
        holder.replaceChildren(winChart(g, M, minute, set, holder.clientWidth));
        if (dot >= 0) holder.querySelectorAll(".mo")[dot]?.focus();
        fill.style.height = `${wc[minute]}%`;
        val.textContent = wc[minute];
        bar.setAttribute("aria-label", `Win chance at ${minute}:00: ${wc[minute]}%`);
        for (const li of ml.children) li.classList.toggle("on", Number(li.dataset.i) === i);
      };
      if (opts.lane === false) {
        panel.append(ml);
        box.append(panel);
      } else {
        box.append(panel);
        const cols = el("div", "rv-cols");
        const mp = el("div", "panel");
        const mh = el("div", "panel-h");
        mh.append(el("b", "", "Key moments"), el("span", "", "pick one to see it on the chart"));
        mp.append(mh, ml);
        cols.append(mp);
        if (g.lane) cols.append(lanePanel(g));
        box.append(cols);
      }
      const turn = M.findIndex((m) => m.kind === "turn");
      set(turn >= 0 ? M[turn].minute : wc.length - 1, turn);
    } else {
      panel.append(el("p", "rv-empty", "No timeline for this game yet, so no win chance by minute."));
      box.append(panel);
      if (g.lane && opts.lane !== false) {
        const cols = el("div", "rv-cols");
        cols.append(lanePanel(g));
        box.append(cols);
      }
    }
    return { moments: M, set };
  }

  return { init, render, moments, spark, highlights, highlightCard, icon, iconUrl, champName, clock, plural, signed, pct, list, el, LANE_END, MIN_N };
})();

// meiolol admin page (src/admin.zig writes the data): stat tiles, charts with a hover
// crosshair, bar lists and tables, all drawn here from the JSON in #data.
"use strict";

const D = JSON.parse(document.getElementById("data").textContent);
const NS = "http://www.w3.org/2000/svg";
// Fixed per entity, never by rank (validated on the dark panel, adjacent pairs)
const PALETTE = ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#9085e9"];
const REGION_ORDER = ["europe", "americas", "asia", "sea"];
const REGION_COLOR = { europe: PALETTE[0], americas: PALETTE[1], asia: PALETTE[2], sea: PALETTE[3] };
const KIND_LABEL = {
  rate_limit: "Rate limited (429)", riot_server: "Riot 5xx", db_busy: "DB busy/locked",
  network: "Network", other: "Other",
};
const TIERS = ["CHALLENGER", "GRANDMASTER", "MASTER", "DIAMOND", "EMERALD", "PLATINUM", "GOLD",
  "SILVER", "BRONZE", "IRON"];

// ---------- formatting ----------

function num(v) {
  if (v == null || !isFinite(v)) return "–";
  const a = Math.abs(v);
  if (a >= 1e9) return (v / 1e9).toFixed(a >= 1e10 ? 0 : 1) + "B";
  if (a >= 1e6) return (v / 1e6).toFixed(a >= 1e7 ? 0 : 1) + "M";
  if (a >= 1e4) return (v / 1e3).toFixed(0) + "k";
  if (a >= 1e3) return (v / 1e3).toFixed(1) + "k";
  if (a >= 10 || Number.isInteger(v)) return Math.round(v).toString();
  return v.toFixed(1);
}
function bytes(v) {
  if (v == null) return "–";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let i = 0;
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return (v >= 100 || i === 0 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i];
}
function pct(v) { return v == null ? "–" : (100 * v).toFixed(1) + "%"; }
function ago(t) {
  if (t == null) return "never";
  const s = D.now - t;
  if (s < 90) return s + " s ago";
  if (s < 5400) return Math.round(s / 60) + " min ago";
  if (s < 172800) return Math.round(s / 3600) + " h ago";
  return Math.round(s / 86400) + " days ago";
}
const pad = n => String(n).padStart(2, "0");
// UK time: BST in summer, GMT in winter
const TZ = "Europe/London";
const ukFmt = new Intl.DateTimeFormat("en-GB", {
  timeZone: TZ, hourCycle: "h23", year: "numeric", month: "numeric", day: "numeric",
  hour: "numeric", minute: "numeric", second: "numeric", timeZoneName: "short",
});
function ukParts(t) {
  const p = {};
  for (const { type, value } of ukFmt.formatToParts(new Date(t * 1000))) p[type] = value;
  return p;
}
// Seconds UK time is ahead of UTC at t
function ukOffset(t) {
  const p = ukParts(t);
  return Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second) / 1000 - t;
}
const zoneName = t => ukParts(t).timeZoneName;
function uk(t) {
  const p = ukParts(t);
  const day = new Date(t * 1000).toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short", timeZone: TZ });
  return `${day} ${pad(p.hour)}:${pad(p.minute)}`;
}
function dayLabel(day) {
  return new Date(day * 86400000).toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: "UTC" });
}
function esc(s) {
  return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

// ---------- DOM ----------

function el(tag, attrs = {}, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") e.className = v;
    else if (k === "html") e.innerHTML = v;
    else e.setAttribute(k, v);
  }
  for (const k of kids) if (k != null) e.append(k);
  return e;
}
function svg(tag, attrs = {}) {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  return e;
}
function section(title, sub) {
  const s = el("section", {}, el("h2", {}, title));
  if (sub) s.append(el("p", { class: "sub" }, sub));
  app.append(s);
  return s;
}

// ---------- charts ----------

// Gridline step: a round number, `parts` of them covering v
function niceStep(v, parts) {
  if (!(v > 0)) return 1 / parts;
  const raw = v / parts, p = Math.pow(10, Math.floor(Math.log10(raw)));
  for (const m of [1, 2, 2.5, 5, 10]) if (m * p >= raw) return m * p;
  return 10 * p;
}

// A chart over a numeric x (unix seconds unless xFmt says otherwise). series: [{name,
// color, values}] with null for gaps; type "area" (stacked), "line" or "bars" (stacked)
function chart(parent, o) {
  const fig = el("figure", { class: "chart" + (o.small ? " small" : "") });
  const head = el("div", { class: "chart-head" }, el("h3", {}, o.title));
  if (o.series.length > 1) {
    const legend = el("div", { class: "legend" });
    for (const s of o.series) {
      const last = lastValue(s.values);
      legend.append(el("span", {}, el("i", { style: "background:" + s.color }), s.name,
        last == null ? null : el("b", {}, (o.fmt || num)(last))));
    }
    head.append(legend);
  } else if (o.series.length === 1) {
    const last = lastValue(o.series[0].values);
    if (last != null) head.append(el("span", { class: "now" }, (o.fmt || num)(last)));
  }
  fig.append(head);
  const box = el("div", { class: "plot" });
  const tip = el("div", { class: "tip", hidden: "" });
  box.append(tip);
  fig.append(box);
  if (o.caption) fig.append(el("figcaption", {}, o.caption));
  parent.append(fig);
  const draw = () => drawChart(box, tip, o);
  new ResizeObserver(draw).observe(box);
  return fig;
}

function lastValue(vs) {
  for (let i = vs.length - 1; i >= 0; i--) if (vs[i] != null) return vs[i];
  return null;
}

function drawChart(box, tip, o) {
  const old = box.querySelector("svg");
  if (old) old.remove();
  const W = Math.max(box.clientWidth, 200), H = o.small ? 120 : 200;
  const L = 48, R = 12, T = 10, B = 24;
  const xs = o.x, n = xs.length;
  if (!n) { box.append(el("p", { class: "muted" }, "No data yet.")); return; }
  const stacked = o.type !== "line";
  const tops = xs.map((_, i) => {
    let sum = 0, any = false, max = 0;
    for (const s of o.series) {
      const v = s.values[i];
      if (v == null) continue;
      any = true; sum += v; max = Math.max(max, v);
    }
    return any ? (stacked ? sum : max) : null;
  });
  // fit: around the data instead of from zero (model scores move in the third decimal)
  const known = o.series.flatMap(s => s.values).filter(v => v != null);
  let ymin = 0, ymax = Math.max(0, ...tops.filter(v => v != null), o.ref ? o.ref.value : 0);
  if (o.fit && known.length) {
    const lo = Math.min(...known), hi = Math.max(...known), st = niceStep(Math.max(hi - lo, Math.abs(hi) * 0.01), 4);
    ymin = Math.floor(lo / st) * st;
    ymax = ymin + 4 * st;
    if (ymax < hi) ymax += st;
  } else ymax = 4 * niceStep(ymax, 4);
  const x0 = o.xMin ?? xs[0], x1 = o.xMax ?? xs[n - 1] + (o.step || 0);
  const span = Math.max(x1 - x0, 1);
  const px = x => L + (x - x0) / span * (W - L - R);
  const py = v => T + (1 - (v - ymin) / (ymax - ymin)) * (H - T - B);
  const s = svg("svg", { viewBox: `0 0 ${W} ${H}`, width: W, height: H, role: "img", "aria-label": o.title });

  for (let k = 0; k <= 4; k++) {
    const v = ymin + (ymax - ymin) * k / 4, y = py(v);
    s.append(svg("line", { class: k ? "grid" : "base", x1: L, x2: W - R, y1: y, y2: y }));
    const t = svg("text", { x: L - 6, y: y + 4, "text-anchor": "end" });
    t.textContent = (o.fmt || num)(v);
    s.append(t);
  }
  for (const [x, label] of (o.xTicks || timeTicks)(x0, x1, W)) {
    const t = svg("text", { x: px(x), y: H - 6, "text-anchor": "middle" });
    t.textContent = label;
    s.append(t);
    s.append(svg("line", { class: "tick", x1: px(x), x2: px(x), y1: H - B, y2: H - B + 4 }));
  }
  for (const m of o.markers || []) {
    if (m < x0 || m > x1) continue;
    const l = svg("line", { class: "marker", x1: px(m), x2: px(m), y1: T, y2: H - B });
    const title = svg("title");
    title.textContent = "crawler started " + uk(m);
    l.append(title);
    s.append(l);
  }

  const step = o.step || 0;
  const bw = step ? Math.max(1, px(x0 + step) - px(x0) - (px(x0 + step) - px(x0) > 4 ? 1.5 : 0)) : 0;
  const base = new Array(n).fill(0);
  for (const ser of o.series) {
    const vs = ser.values;
    if (o.type === "bars") {
      for (let i = 0; i < n; i++) {
        const v = vs[i];
        if (!v) continue;
        const y0 = py(base[i]), y1 = py(base[i] + v);
        s.append(svg("rect", { x: px(xs[i]), y: y1, width: bw, height: Math.max(0, y0 - y1 - (y0 - y1 > 3 ? 1 : 0)), fill: ser.color }));
        base[i] += v;
      }
      continue;
    }
    // Runs of values without gaps
    let run = [];
    const flush = () => {
      if (!run.length) return;
      const mid = i => px(xs[i]) + (step ? (px(x0 + step) - px(x0)) / 2 : 0);
      const pts = run.map(i => [mid(i), py((stacked ? base[i] : 0) + vs[i])]);
      if (run.length === 1) pts.push([pts[0][0] + 2, pts[0][1]]);
      if (stacked) {
        const bottom = run.map(i => [mid(i), py(base[i])]).reverse();
        if (run.length === 1) bottom.unshift([bottom[0][0] + 2, bottom[0][1]]);
        s.append(svg("polygon", { class: "area", fill: ser.color, points: pts.concat(bottom).map(p => p.join(",")).join(" ") }));
      }
      s.append(svg("polyline", { class: stacked ? "edge" : "line", stroke: ser.color, points: pts.map(p => p.join(",")).join(" ") }));
      run = [];
    };
    for (let i = 0; i < n; i++) {
      if (vs[i] == null) flush(); else run.push(i);
    }
    flush();
    if (stacked) for (let i = 0; i < n; i++) if (vs[i] != null) base[i] += vs[i];
  }
  if (o.ref) {
    const y = py(o.ref.value);
    s.append(svg("line", { class: "ref", x1: L, x2: W - R, y1: y, y2: y }));
    const t = svg("text", { x: W - R, y: y - 4, "text-anchor": "end", class: "ref-label" });
    t.textContent = o.ref.label;
    s.append(t);
  }

  // Hover: nearest x, every series' value there
  const cross = svg("line", { class: "cross", y1: T, y2: H - B, visibility: "hidden" });
  s.append(cross);
  const hit = svg("rect", { x: L, y: 0, width: W - L - R, height: H, fill: "transparent" });
  s.append(hit);
  const move = ev => {
    const r = s.getBoundingClientRect();
    const x = x0 + (ev.clientX - r.left - L) / (W - L - R) * span;
    let i = 0, best = Infinity;
    for (let j = 0; j < n; j++) {
      const d = Math.abs(xs[j] + step / 2 - x);
      if (d < best) { best = d; i = j; }
    }
    const cx = px(xs[i]) + (step ? (px(x0 + step) - px(x0)) / 2 : 0);
    cross.setAttribute("x1", cx); cross.setAttribute("x2", cx);
    cross.setAttribute("visibility", "visible");
    const f = o.fmt || num;
    let rows = "";
    for (const ser of o.series.slice().reverse()) {
      rows += `<div><i style="background:${ser.color}"></i>${esc(ser.name)}<b>${f(ser.values[i])}</b></div>`;
    }
    if (stacked && o.series.length > 1) rows += `<div class="total">Total<b>${f(tops[i])}</b></div>`;
    tip.innerHTML = `<div class="when">${esc((o.xFmt || uk)(xs[i]))}</div>` + rows;
    tip.hidden = false;
    const left = cx + 14 + tip.offsetWidth > W ? cx - 14 - tip.offsetWidth : cx + 14;
    tip.style.left = Math.max(0, left) + "px";
    tip.style.top = "4px";
  };
  hit.addEventListener("pointermove", move);
  hit.addEventListener("pointerdown", move);
  hit.addEventListener("pointerleave", () => { tip.hidden = true; cross.setAttribute("visibility", "hidden"); });
  box.append(s);
}

function timeTicks(x0, x1, width) {
  const span = x1 - x0, out = [];
  const maxTicks = Math.max(2, Math.floor(width / 70));
  const steps = [3600, 3 * 3600, 6 * 3600, 12 * 3600, 86400, 2 * 86400, 7 * 86400];
  const st = steps.find(v => span / v <= maxTicks) || 7 * 86400;
  // On UK hours and midnights (one offset for the range: a clock change moves ticks an hour)
  const off = ukOffset(x0);
  for (let t = Math.ceil((x0 + off) / st) * st - off; t <= x1; t += st) {
    const h = +ukParts(t).hour;
    const label = st >= 86400 || h === 0
      ? new Date(t * 1000).toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: TZ })
      : pad(h) + ":00";
    out.push([t, label]);
  }
  return out;
}

// Horizontal bars: rows [{label, value, color?}]
function bars(parent, title, rows, opts = {}) {
  const card = el("div", { class: "card" }, el("h3", {}, title));
  const total = rows.reduce((a, r) => a + r.value, 0);
  const max = Math.max(1, ...rows.map(r => r.value));
  const list = el("div", { class: "bars" });
  for (const r of rows) {
    const share = total ? r.value / total : 0;
    list.append(el("div", { class: "bar", title: `${r.label}: ${r.value.toLocaleString("en-GB")} (${pct(share)})` },
      el("span", { class: "label" }, r.label),
      el("span", { class: "track" }, el("span", { class: "fill", style: `width:${100 * r.value / max}%;background:${r.color || PALETTE[0]}` })),
      el("span", { class: "value" }, (opts.fmt || num)(r.value), el("small", {}, pct(share)))));
  }
  card.append(list);
  if (opts.caption) card.append(el("p", { class: "sub" }, opts.caption));
  parent.append(card);
  return card;
}

function tile(parent, label, value, sub, state) {
  parent.append(el("div", { class: "tile" + (state ? " " + state : "") },
    el("span", { class: "label" }, label), el("b", {}, value), sub ? el("span", { class: "sub" }, sub) : null));
}

function tsv(text) {
  const lines = (text || "").trim().split("\n").filter(Boolean);
  if (lines.length < 2) return [];
  const head = lines[0].split("\t");
  return lines.slice(1).map(l => {
    const cells = l.split("\t"), row = {};
    head.forEach((h, i) => { const c = cells[i]; row[h] = c === undefined || c === "" ? null : isNaN(+c) ? c : +c; });
    return row;
  });
}

// ---------- data ----------

const C = D.crawl;
const regionIdx = Object.fromEntries(C.regions.map((r, i) => [r, i]));
const regionsShown = REGION_ORDER.filter(r => r in regionIdx);
const bucketT = C.buckets.map((_, i) => C.start + i * C.step);
// Per-hour rate of a bucket counter, by coverage (null while the crawler was down)
function rate(get, per = 3600) {
  return C.buckets.map(b => b.covered ? get(b) * per / b.covered : null);
}
function lastHour(get) {
  let v = 0, cov = 0;
  for (let i = C.buckets.length - 1; i >= 0 && C.start + i * C.step >= D.now - 3600; i--) {
    v += get(C.buckets[i]); cov += C.buckets[i].covered;
  }
  return cov ? v * 3600 / cov : null;
}
const sumR = arr => arr.reduce((a, b) => a + b, 0);
const history = tsv(D.history);
const count = name => (D.counts.find(c => c.name === name) || {}).rows;

let range = "24h";
try { range = localStorage.getItem("admin-range") || range; } catch (e) { /* storage blocked */ }

// ---------- page ----------

const app = document.getElementById("app");
app.innerHTML = "";

function render() {
  app.innerHTML = "";
  const top = el("header", { class: "top" },
    el("h1", {}, "meiolol ", el("span", {}, "admin")),
    el("p", { class: "sub" }, `Built ${uk(D.now)} ${zoneName(D.now)} (${ago(D.now)}). Times in UK time (${zoneName(D.now)}); log excerpts in UTC.`));
  const toggle = el("nav", { class: "switch", "aria-label": "Range" });
  for (const [k, label] of [["24h", "24 hours"], ["7d", `${D.days} days`]]) {
    const a = el("button", { type: "button" }, label);
    if (k === range) a.setAttribute("aria-current", "true");
    a.onclick = () => { range = k; try { localStorage.setItem("admin-range", k); } catch (e) { /* ok */ } render(); };
    toggle.append(a);
  }
  top.append(toggle);
  app.append(top);

  // Health
  const problems = (D.health || "").trim().split("\n").filter(Boolean);
  if (D.health != null) {
    app.append(el("div", { class: "health " + (problems.length ? "bad" : "good") },
      el("b", {}, problems.length ? `⚠ ${problems.length} problem${problems.length > 1 ? "s" : ""}` : "✓ All checks pass"),
      problems.length ? el("ul", {}, ...problems.map(p => el("li", {}, p))) : el("span", {}, " crawler, site loop, upload age, disk, backups")));
  }

  // Tiles
  const tiles = el("div", { class: "tiles" });
  const mDay = lastHour(b => sumR(b.m)), tDay = lastHour(b => sumR(b.t));
  const silent = C.last_report == null || D.now - C.last_report > 900;
  tile(tiles, "Matches / day", mDay == null ? "–" : num(mDay * 24), "rate over the last hour", silent ? "bad" : null);
  tile(tiles, "Timelines / day", tDay == null ? "–" : num(tDay * 24), "rate over the last hour");
  const req = lastHour(b => sumR(b.req) + b.platform_req);
  tile(tiles, "Riot requests / min", req == null ? "–" : num(req / 60), "all routes");
  tile(tiles, "Last crawl report", ago(C.last_report), C.restarts.length ? `last start ${ago(C.restarts[C.restarts.length - 1])}` : "no restart in window", silent ? "bad" : null);
  tile(tiles, "Matches stored", num(count("matches")), `${num(count("timeline.timelines"))} timelines`);
  tile(tiles, "Draft rows", num(count("drafts")), `${num(count("draft_backfill"))} to backfill`);
  tile(tiles, "Players", num(count("players")), `${num(count("ranks"))} ranks known`);
  const dbBytes = sumR(D.files.map(f => f.bytes));
  tile(tiles, "Databases", bytes(dbBytes), D.files.map(f => `${f.name.replace(".db", "")} ${bytes(f.bytes)}`).join(" · "));
  if (D.disk) {
    const used = D.disk[1] / D.disk[0];
    tile(tiles, "Disk", pct(used) + " used", `${bytes(D.disk[2])} free of ${bytes(D.disk[0])}`, used > 0.8 ? "bad" : used > 0.65 ? "warn" : null);
  }
  const lastUp = D.uploads.length ? D.uploads[D.uploads.length - 1] : null;
  tile(tiles, "Site upload", ago(lastUp), `${D.uploads.filter(t => t >= D.now - 86400).length} in the last 24 h`, lastUp == null || D.now - lastUp > 26 * 3600 ? "bad" : null);
  app.append(tiles);

  // Crawl
  const from = range === "24h" ? D.now - 86400 : C.start;
  const first = Math.max(0, Math.floor((from - C.start) / C.step));
  const xs = bucketT.slice(first);
  const cut = vs => vs.slice(first);
  const byRegion = get => regionsShown.map(r => ({
    name: r, color: REGION_COLOR[r], values: cut(rate(b => get(b)[regionIdx[r]])),
  }));
  const common = { x: xs, step: C.step, markers: C.restarts, xMin: from, xMax: D.now };
  const crawl = section("Crawler", "From the crawler's minute report lines; gaps = crawler not running, dashed = crawler start.");
  const grid = el("div", { class: "charts" });
  crawl.append(grid);
  chart(grid, { ...common, title: "Matches stored per hour", type: "area", series: byRegion(b => b.m) });
  chart(grid, { ...common, title: "Timelines stored per hour", type: "area", series: byRegion(b => b.t) });
  chart(grid, {
    ...common, title: "Regional requests per minute", type: "line",
    series: regionsShown.map(r => ({ name: r, color: REGION_COLOR[r], values: cut(rate(b => b.req[regionIdx[r]], 60)) })),
    ref: { value: 50, label: "personal key: 100 / 2 min" },
  });
  chart(grid, {
    ...common, title: "Ladder, mastery and match list calls per hour", type: "line",
    series: [
      { name: "ladder pages", color: PALETTE[0], values: cut(rate(b => b.ladder)) },
      { name: "mastery", color: PALETTE[1], values: cut(rate(b => b.mastery)) },
      { name: "match id lists", color: PALETTE[2], values: cut(rate(b => sumR(b.ids))) },
    ],
  });
  chart(grid, {
    ...common, title: "Writer commits per minute", type: "line",
    series: [{ name: "commits", color: PALETTE[0], values: cut(rate(b => b.commits, 60)) }],
    caption: "Each commit is a batch of queued jobs (one per match or timeline).",
  });
  chart(grid, {
    ...common, title: "Writer queue, highest per 10 min", type: "line",
    series: [{ name: "jobs waiting", color: PALETTE[1], values: cut(C.buckets.map(b => b.covered ? b.queued_max : null)) }],
    ref: { value: 128, label: "full: workers block" },
  });
  chart(grid, {
    ...common, title: "Database pages per minute (writer connection)", type: "line",
    series: [
      { name: "written", color: PALETTE[0], values: cut(rate(b => b.pages_written, 60)) },
      { name: "read", color: PALETTE[1], values: cut(rate(b => b.pages_read, 60)) },
    ],
  });
  chart(grid, {
    ...common, title: "Warnings per 10 min", type: "bars",
    series: C.kinds.map((k, i) => ({ name: KIND_LABEL[k] || k, color: PALETTE[i], values: cut(C.buckets.map(b => b.warnings[i])) })),
  });
  if (C.messages.length) {
    const t = el("table", {}, el("thead", {}, el("tr", {}, el("th", {}, "Last 24 h"), el("th", { class: "num" }, "Count"), el("th", {}, "Last"))));
    const body = el("tbody");
    for (const m of C.messages) {
      body.append(el("tr", {}, el("td", { class: "msg" }, el("i", { class: "dot", style: "background:" + PALETTE[C.kinds.indexOf(m.kind)] }), m.text),
        el("td", { class: "num" }, m.count.toLocaleString("en-GB")), el("td", { class: "muted" }, ago(m.last))));
    }
    t.append(body);
    crawl.append(el("details", {}, el("summary", {}, `Top warning messages (${C.messages.length})`), el("div", { class: "table-scroll" }, t)));
  }

  // Storage
  const store = section("Storage", "One snapshot per page build (data/admin-history.tsv).");
  const sg = el("div", { class: "charts" });
  store.append(sg);
  const hx = history.map(r => r.time);
  const files = [["meiolol.db", "meiolol_db"], ["timeline.db", "timeline_db"], ["raw.db", "raw_db"]];
  chart(sg, {
    x: hx, title: "Database files on disk", type: "area", fmt: bytes,
    series: files.map(([name, col], i) => ({ name, color: PALETTE[i], values: history.map(r => r[col]) })),
  });
  chart(sg, {
    x: hx, title: "Queue backlog", type: "line",
    series: [
      { name: "match queue", color: PALETTE[0], values: history.map(r => r.match_queue) },
      { name: "timeline queue", color: PALETTE[1], values: history.map(r => r.timeline_queue) },
    ],
  });
  const minis = el("div", { class: "charts minis" });
  store.append(minis);
  for (const [col, title] of [["matches", "Matches"], ["timelines", "Timelines"], ["drafts", "Draft rows"],
    ["players", "Players (scan pool)"], ["ranks", "Ladder ranks"], ["mastery", "Mastery rows"]]) {
    chart(minis, { x: hx, title, type: "line", small: true, series: [{ name: title, color: PALETTE[0], values: history.map(r => r[col]) }] });
  }
  const dayAgo = history.find(r => r.time >= D.now - 86400);
  const histCol = { "timeline.timelines": "timelines" };
  const ct = el("table", {}, el("thead", {}, el("tr", {}, el("th", {}, "Table"), el("th", { class: "num" }, "Rows"), el("th", { class: "num" }, "24 h change"))));
  const cb = el("tbody");
  for (const c of D.counts) {
    const col = histCol[c.name] || c.name;
    const before = dayAgo && dayAgo[col] != null ? dayAgo[col] : null;
    const delta = before == null ? "" : (c.rows >= before ? "+" : "") + (c.rows - before).toLocaleString("en-GB");
    cb.append(el("tr", {}, el("td", {}, c.name), el("td", { class: "num" }, c.rows.toLocaleString("en-GB")), el("td", { class: "num muted" }, delta)));
  }
  ct.append(cb);
  store.append(el("details", {}, el("summary", {}, "Row counts"), el("div", { class: "table-scroll" }, ct)));

  // Ingest mix
  const M = D.drafts;
  const mix = section("What we ingest", `Complete ranked games (draft rows): the newest ${num(M.rows)} stored.`);
  const mg = el("div", { class: "charts" });
  mix.append(mg);
  const days = M.days;
  chart(mg, {
    x: days.map(d => d.day * 86400), step: 86400, title: "Games by game day", type: "bars",
    xFmt: t => dayLabel(t / 86400), xMin: days.length ? days[0].day * 86400 : 0,
    xMax: days.length ? (days[days.length - 1].day + 1) * 86400 : 1,
    series: regionsShown.map(r => ({ name: r, color: REGION_COLOR[r], values: days.map(d => d.region[regionIdx[r]]) })),
  });
  chart(mg, {
    x: M.minutes.map((_, i) => i * 5), step: 5, title: "Game length", type: "bars",
    xFmt: m => m >= 60 ? "60+ min" : `${m}–${m + 5} min`, xMin: 0, xMax: 65,
    xTicks: () => [0, 15, 30, 45, 60].map(m => [m, m + " min"]),
    series: [{ name: "games", color: PALETTE[0], values: M.minutes }],
  });
  const cards = el("div", { class: "cards" });
  mix.append(cards);
  const blue = M.rows ? M.blue_wins / M.rows : null;
  const ranked = M.rows ? 1 - M.tiers[M.tiers.length - 1] / M.rows : null;
  const facts = el("div", { class: "card" }, el("h3", {}, "Sanity"));
  facts.append(el("dl", {},
    el("dt", {}, "Blue side wins"), el("dd", {}, pct(blue)),
    el("dt", {}, "With a median rank"), el("dd", {}, pct(ranked)),
    el("dt", {}, "Platforms"), el("dd", {}, String(M.platforms.length)),
    el("dt", {}, "Patches"), el("dd", {}, M.patches.map(p => p.key).join(", ") || "–")));
  cards.append(facts);
  const platformRegion = id => (D.platforms.find(p => p.id === id) || {}).region;
  bars(cards, "Games by platform", M.platforms.map(p => ({ label: p.key, value: p.n, color: REGION_COLOR[platformRegion(p.key)] })));
  bars(cards, "Games by median rank", TIERS.map((t, i) => ({ label: t[0] + t.slice(1).toLowerCase(), value: M.tiers[i] }))
    .concat([{ label: "Unknown", value: M.tiers[TIERS.length], color: "#5b6478" }]).filter(r => r.value));
  bars(cards, "Ladder players by tier", D.ladder.map(g => ({ label: g.key[0] + g.key.slice(1).toLowerCase(), value: g.n, color: PALETTE[2] })),
    { caption: "Every player a ladder page showed (ranks table)." });
  bars(cards, "Scan pool by region", D.players.map(g => ({ label: g.key, value: g.n, color: REGION_COLOR[g.key] })));
  bars(cards, "Matches by patch", D.by_patch.map(g => ({ label: g.key, value: g.n, color: PALETTE[5] })));

  // Queues
  const qs = section("Queues");
  const qc = el("div", { class: "cards" });
  qs.append(qc);
  bars(qc, "Match queue", D.queues.match.map(g => ({ label: g.key, value: g.n, color: g.key === "failed" ? "#e66767" : PALETTE[0] })));
  bars(qc, "Timeline queue", D.queues.timeline.map(g => {
    const [r, st] = g.key.split(" ");
    return { label: g.key, value: g.n, color: st === "failed" ? "#e66767" : REGION_COLOR[r] };
  }));

  // Model
  const ev = tsv(D.eval);
  if (ev.length) {
    const ms = section("Draft model", "meiolol eval, daily: held-out EUW games (docs/model.md). Higher AUC is better; 0.5 is a coin.");
    const eg = el("div", { class: "charts" });
    ms.append(eg);
    const ex = ev.map((_, i) => i);
    const evFmt = i => ev[i] ? `${ev[i].date}, ${num(ev[i].games)} games` : "";
    const evTicks = (a, b, w) => {
      const every = Math.max(1, Math.ceil(ev.length / Math.max(2, Math.floor(w / 90))));
      return ev.map((r, i) => [i, num(r.games)]).filter((_, i) => i % every === 0);
    };
    const models = [["base", "base"], ["current", "current"], ["eb", "shrunk"], ["joint", "joint"]];
    chart(eg, {
      x: ex, title: "AUC by games used", type: "line", fit: true, xFmt: evFmt, xTicks: evTicks, fmt: v => v == null ? "–" : v.toFixed(3),
      series: models.map(([k, name], i) => ({ name, color: PALETTE[i], values: ev.map(r => r["auc_" + k]) })),
    });
    chart(eg, {
      x: ex, title: "Log loss by games used", type: "line", fit: true, xFmt: evFmt, xTicks: evTicks, fmt: v => v == null ? "–" : v.toFixed(4),
      series: models.map(([k, name], i) => ({ name, color: PALETTE[i], values: ev.map(r => r["ll_" + k]) })),
      caption: "Coin flip is 0.6931; lower is better.",
    });
  }

  // Ops
  const ops = section("Site and box");
  const og = el("div", { class: "charts" });
  ops.append(og);
  const upFrom = range === "24h" ? D.now - 86400 : D.now - D.days * 86400;
  const ups = D.uploads.filter(t => t >= upFrom);
  const strip = el("figure", { class: "chart" }, el("div", { class: "chart-head" }, el("h3", {}, `Site uploads (${ups.length})`)));
  const sbox = el("div", { class: "plot strip" });
  strip.append(sbox);
  og.append(strip);
  new ResizeObserver(() => {
    sbox.innerHTML = "";
    const W = Math.max(sbox.clientWidth, 200), H = 44, L = 8, R = 8;
    const s = svg("svg", { viewBox: `0 0 ${W} ${H}`, width: W, height: H });
    const px = t => L + (t - upFrom) / (D.now - upFrom) * (W - L - R);
    s.append(svg("line", { class: "base", x1: L, x2: W - R, y1: 18, y2: 18 }));
    for (const t of ups) {
      const c = svg("circle", { cx: px(t), cy: 18, r: 4, fill: PALETTE[2] });
      const title = svg("title");
      title.textContent = "uploaded " + uk(t);
      c.append(title);
      s.append(c);
    }
    for (const [t, label] of timeTicks(upFrom, D.now, W)) {
      const tx = svg("text", { x: px(t), y: H - 4, "text-anchor": "middle" });
      tx.textContent = label;
      s.append(tx);
    }
    sbox.append(s);
  }).observe(sbox);
  const deploys = (D.deploys || "").trim().split("\n").filter(Boolean).reverse();
  if (deploys.length) {
    const dl = el("ul", { class: "deploys" });
    for (const d of deploys) {
      const [commit, at] = d.split(" ");
      dl.append(el("li", {}, el("code", {}, commit.slice(0, 8)), el("span", { class: "muted" }, at ? ago(Date.parse(at) / 1000) : "")));
    }
    og.append(el("div", { class: "card" }, el("h3", {}, "Deploys"), dl));
  }
  for (const [name, text] of Object.entries(D.logs)) {
    if (!text.trim()) continue;
    ops.append(el("details", {}, el("summary", {}, `${name}.log`), el("pre", {}, text.trim())));
  }
}

render();

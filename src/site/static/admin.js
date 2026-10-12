// meiolol admin dashboard (src/admin.zig writes the snapshot): tabs over the crawler, Riot
// limits, storage, ingest, the draft model, Mac training runs, site traffic and box
// controls. Data, freshest first: api/live.json (box, every minute: crawler tail, queues,
// services, health, actions), data.json (the 15 min snapshot, also embedded in #data),
// ops/traffic.json (web server, every 5 min), training/ (the Mac's runs). Each part
// degrades on its own: a missing source hides its pieces, the snapshot always renders.
"use strict";

let D = JSON.parse(document.getElementById("data").textContent);
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
const BAD = "#e66767";
const TABS = [
  ["overview", "Overview"], ["crawler", "Crawler"], ["riot", "Riot API"], ["storage", "Storage"],
  ["ingest", "Ingest"], ["models", "Models"], ["traffic", "Traffic"],
  ["ops", "Controls"],
];
// Tabs whose charts follow the time range switch
const TIMED = new Set(["overview", "crawler", "riot"]);
const LIVE_MS = 60_000, SNAPSHOT_MS = 5 * 60_000, TRAFFIC_MS = 5 * 60_000, TRAINING_MS = 30_000;
// Personal key app limit, per routing value: 100 per 2 min sustains 50 a minute
const KEY_PER_MIN = 50;

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
  if (v == null || !isFinite(v)) return "–";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let i = 0, neg = v < 0;
  v = Math.abs(v);
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return (neg ? "-" : "") + (v >= 100 || i === 0 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i];
}
function pct(v) { return v == null || !isFinite(v) ? "–" : (100 * v).toFixed(1) + "%"; }
const nowS = () => Date.now() / 1000;
function ago(t) {
  if (t == null) return "never";
  const s = Math.max(0, Math.round(nowS() - t));
  if (s < 90) return s + " s ago";
  if (s < 5400) return Math.round(s / 60) + " min ago";
  if (s < 172800) return Math.round(s / 3600) + " h ago";
  return Math.round(s / 86400) + " days ago";
}
function span(s) {
  if (s == null || !isFinite(s)) return "–";
  if (s < 90) return Math.round(s) + " s";
  if (s < 5400) return Math.round(s / 60) + " min";
  if (s < 172800) return (s / 3600).toFixed(1) + " h";
  return Math.round(s / 86400) + " days";
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
const cap = s => s ? s[0] + s.slice(1).toLowerCase() : s;
const sumR = arr => arr.reduce((a, b) => a + (b || 0), 0);

// ---------- storage of UI state ----------

function stored(key, fallback) {
  try { const v = localStorage.getItem("admin-" + key); return v == null ? fallback : JSON.parse(v); } catch (e) { return fallback; }
}
function store(key, value) {
  try { localStorage.setItem("admin-" + key, JSON.stringify(value)); } catch (e) { /* storage blocked */ }
}

// Old tab names (#model, #training) open the Models tab
const hashTab = () => {
  const [t, sub] = location.hash.slice(1).split("/");
  return t === "model" ? ["models", "win"] : t === "training" ? ["models", "all"] : [t || "overview", sub];
};
const CATS_KEYS = ["all", "win", "draft", "early", "items", "objectives", "playstyle", "player", "data", "lab"];
const ui = {
  tab: hashTab()[0],
  cat: hashTab()[0] === "models" && hashTab()[1] ? hashTab()[1] : stored("cat", "all"),
  outcome: stored("outcome", null),
  range: stored("range2", "24h"),
  regions: new Set(stored("regions", REGION_ORDER)),
  hidden: new Set(stored("hidden", [])),
  zoom: null,
  sort: stored("sort", {}),
  trafficRange: stored("traffic-range", "7d"),
  pagesWindow: "24h",
  run: null,
  log: { file: "crawl", lines: 300, filter: "", follow: false },
};
if (!TABS.some(([k]) => k === ui.tab)) ui.tab = "overview";
if (!CATS_KEYS.includes(ui.cat)) ui.cat = "all";

// ---------- DOM ----------

function el(tag, attrs = {}, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v == null || v === false) continue;
    if (k === "class") e.className = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else e.setAttribute(k, v === true ? "" : v);
  }
  for (const k of kids.flat()) if (k != null && k !== false) e.append(k);
  return e;
}
function svg(tag, attrs = {}) {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  return e;
}
function section(parent, title, sub, ...extra) {
  const head = el("div", { class: "section-head" }, el("h2", {}, title), ...extra);
  const s = el("section", {}, head);
  if (sub) s.append(el("p", { class: "sub" }, sub));
  parent.append(s);
  return s;
}
function grid(parent, cls = "charts") {
  const g = el("div", { class: cls });
  parent.append(g);
  return g;
}
function switcher(options, current, onPick, label) {
  const nav = el("nav", { class: "switch", "aria-label": label });
  for (const [k, text] of options) {
    nav.append(el("button", { type: "button", "aria-pressed": String(k === current), onclick: () => onPick(k) }, text));
  }
  return nav;
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
// color, values}] with null for gaps; type "area" (stacked), "line" or "bars" (stacked).
// Legend entries hide and show their series; time charts (o.time) zoom by dragging
function chart(parent, o) {
  const id = o.id || o.title;
  const fig = el("figure", { class: "chart" + (o.small ? " small" : "") });
  const head = el("div", { class: "chart-head" }, el("h3", {}, o.title));
  const fmt = o.fmt || num;
  const draw = () => drawChart(box, tip, o, id);
  if (o.series.length > 1) {
    const legend = el("div", { class: "legend" });
    for (const s of o.series) {
      const key = id + "|" + s.name;
      const last = lastValue(s.values);
      const b = el("button", {
        type: "button", "aria-pressed": String(!ui.hidden.has(key)), title: "Show or hide " + s.name,
        onclick: () => {
          if (ui.hidden.has(key)) ui.hidden.delete(key); else ui.hidden.add(key);
          b.setAttribute("aria-pressed", String(!ui.hidden.has(key)));
          store("hidden", [...ui.hidden]);
          draw();
        },
      }, el("i", { style: "background:" + s.color }), s.name, last == null ? null : el("b", {}, fmt(last)));
      legend.append(b);
    }
    head.append(legend);
  } else if (o.series.length === 1) {
    const last = lastValue(o.series[0].values);
    if (last != null) head.append(el("span", { class: "now" }, fmt(last)));
  }
  fig.append(head);
  const box = el("div", { class: "plot" });
  const tip = el("div", { class: "tip", hidden: true });
  box.append(tip);
  fig.append(box);
  if (o.caption) fig.append(el("figcaption", {}, o.caption));
  parent.append(fig);
  let w = 0;
  new ResizeObserver(() => { if (box.clientWidth !== w) { w = box.clientWidth; draw(); } }).observe(box);
  return fig;
}

function lastValue(vs) {
  for (let i = vs.length - 1; i >= 0; i--) if (vs[i] != null) return vs[i];
  return null;
}

function drawChart(box, tip, o, id) {
  const old = box.querySelector("svg, p.muted");
  if (old) old.remove();
  const W = Math.max(box.clientWidth, 200), H = o.small ? 120 : 200;
  const L = 52, R = 12, T = 10, B = 24;
  const step = o.step || 0;
  let x0 = o.xMin ?? o.x[0], x1 = o.xMax ?? (o.x[o.x.length - 1] + step);
  if (o.time && ui.zoom) { x0 = Math.max(x0, ui.zoom[0]); x1 = Math.min(x1, ui.zoom[1]); }
  // Points inside the window only
  const idx = [];
  o.x.forEach((x, i) => { if (x + step >= x0 && x <= x1) idx.push(i); });
  const xs = idx.map(i => o.x[i]);
  const series = o.series.filter(s => !ui.hidden.has(id + "|" + s.name)).map(s => ({ ...s, values: idx.map(i => s.values[i]) }));
  const n = xs.length;
  if (!n || x1 <= x0) { box.append(el("p", { class: "muted" }, "No data in this range.")); return; }
  const stacked = o.type !== "line";
  const tops = xs.map((_, i) => {
    let sum = 0, any = false, max = -Infinity;
    for (const s of series) {
      const v = s.values[i];
      if (v == null) continue;
      any = true; sum += v; max = Math.max(max, v);
    }
    return any ? (stacked ? sum : max) : null;
  });
  // fit: around the data instead of from zero (model scores move in the third decimal)
  const refs = [].concat(o.ref || []);
  const known = series.flatMap(s => s.values).concat(refs.map(r => r.value)).filter(v => v != null);
  let ymin = 0, ymax = Math.max(0, ...tops.filter(v => v != null), ...refs.map(r => r.value));
  if (o.fit && known.length) {
    const lo = Math.min(...known), hi = Math.max(...known), st = niceStep(Math.max(hi - lo, Math.abs(hi) * 0.01), 4);
    ymin = Math.floor(lo / st) * st;
    ymax = ymin + 4 * st;
    if (ymax < hi) ymax += st;
  } else ymax = 4 * niceStep(ymax, 4);
  const xspan = Math.max(x1 - x0, 1e-9);
  const px = x => L + (x - x0) / xspan * (W - L - R);
  const py = v => T + (1 - (v - ymin) / (ymax - ymin)) * (H - T - B);
  const fmt = o.fmt || num;
  const s = svg("svg", { viewBox: `0 0 ${W} ${H}`, width: W, height: H, role: "img", "aria-label": o.title });

  for (let k = 0; k <= 4; k++) {
    const v = ymin + (ymax - ymin) * k / 4, y = py(v);
    s.append(svg("line", { class: k ? "grid" : "base", x1: L, x2: W - R, y1: y, y2: y }));
    const t = svg("text", { x: L - 6, y: y + 4, "text-anchor": "end" });
    t.textContent = fmt(v);
    s.append(t);
  }
  for (const [x, label] of (o.xTicks || timeTicks)(x0, x1, W)) {
    if (x < x0 || x > x1) continue;
    const t = svg("text", { x: px(x), y: H - 6, "text-anchor": "middle" });
    t.textContent = label;
    s.append(t);
    s.append(svg("line", { class: "tick", x1: px(x), x2: px(x), y1: H - B, y2: H - B + 4 }));
  }
  for (const m of o.markers || []) {
    if (m < x0 || m > x1) continue;
    const l = svg("line", { class: "marker", x1: px(m), x2: px(m), y1: T, y2: H - B });
    const title = svg("title");
    title.textContent = (o.markerLabel || "crawler started") + " " + uk(m);
    l.append(title);
    s.append(l);
  }

  const bw = step ? Math.max(1, px(x0 + step) - px(x0) - (px(x0 + step) - px(x0) > 4 ? 1.5 : 0)) : 0;
  const mid = i => Math.min(Math.max(px(xs[i]) + (step ? (px(x0 + step) - px(x0)) / 2 : 0), L), W - R);
  const base = new Array(n).fill(0);
  for (const ser of series) {
    const vs = ser.values;
    if (o.type === "bars") {
      for (let i = 0; i < n; i++) {
        const v = vs[i];
        if (!v) continue;
        const y0 = py(base[i]), y1 = py(base[i] + v);
        const bx = Math.max(px(xs[i]), L), bwi = Math.min(bw, W - R - bx);
        if (bwi > 0) s.append(svg("rect", { x: bx, y: y1, width: bwi, height: Math.max(0, y0 - y1 - (y0 - y1 > 3 ? 1 : 0)), fill: ser.color }));
        base[i] += v;
      }
      continue;
    }
    // Runs of values without gaps
    let run = [];
    const flush = () => {
      if (!run.length) return;
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
  for (const ref of refs) {
    const y = py(ref.value);
    s.append(svg("line", { class: "ref", x1: L, x2: W - R, y1: y, y2: y }));
    const t = svg("text", { x: W - R, y: y - 4, "text-anchor": "end", class: "ref-label" });
    t.textContent = ref.label;
    s.append(t);
  }

  // Hover: nearest x, every series' value there. Drag (mouse) on a time chart: zoom
  const cross = svg("line", { class: "cross", y1: T, y2: H - B, visibility: "hidden" });
  const brush = svg("rect", { class: "brush", y: T, height: H - T - B, visibility: "hidden" });
  s.append(cross, brush);
  const hit = svg("rect", { x: L, y: 0, width: W - L - R, height: H, fill: "transparent" });
  s.append(hit);
  const toX = ev => {
    const r = s.getBoundingClientRect();
    return x0 + ((ev.clientX - r.left) * (W / r.width) - L) / (W - L - R) * xspan;
  };
  let drag = null;
  const move = ev => {
    const x = toX(ev);
    if (drag) {
      const a = px(Math.max(x0, Math.min(drag, x))), b = px(Math.min(x1, Math.max(drag, x)));
      brush.setAttribute("x", a);
      brush.setAttribute("width", Math.max(0, b - a));
      brush.setAttribute("visibility", "visible");
    }
    let i = 0, best = Infinity;
    for (let j = 0; j < n; j++) {
      const d = Math.abs(xs[j] + step / 2 - x);
      if (d < best) { best = d; i = j; }
    }
    const cx = mid(i);
    cross.setAttribute("x1", cx); cross.setAttribute("x2", cx);
    cross.setAttribute("visibility", "visible");
    tip.replaceChildren(el("div", { class: "when" }, (o.xFmt || uk)(xs[i])));
    for (const ser of series.slice().reverse()) {
      tip.append(el("div", {}, el("i", { style: "background:" + ser.color }), ser.name, el("b", {}, fmt(ser.values[i]))));
    }
    if (stacked && series.length > 1) tip.append(el("div", { class: "total" }, "Total", el("b", {}, fmt(tops[i]))));
    tip.hidden = false;
    const r = s.getBoundingClientRect(), scale = r.width / W;
    const left = (cx * scale) + 14 + tip.offsetWidth > r.width ? cx * scale - 14 - tip.offsetWidth : cx * scale + 14;
    tip.style.left = Math.max(0, left) + "px";
    tip.style.top = "4px";
  };
  hit.addEventListener("pointermove", move);
  hit.addEventListener("pointerdown", ev => {
    if (o.time && ev.pointerType === "mouse" && ev.button === 0) {
      drag = toX(ev);
      hit.setPointerCapture(ev.pointerId);
    }
    move(ev);
  });
  hit.addEventListener("pointerup", ev => {
    if (drag == null) return;
    const a = Math.max(x0, Math.min(drag, toX(ev))), b = Math.min(x1, Math.max(drag, toX(ev)));
    drag = null;
    brush.setAttribute("visibility", "hidden");
    // Wider than a few pixels and at least two buckets: a click is not a zoom
    if (px(b) - px(a) > 6 && b - a >= 2 * Math.max(step, 60)) setZoom([a, b]);
  });
  hit.addEventListener("pointerleave", () => { if (drag == null) { tip.hidden = true; cross.setAttribute("visibility", "hidden"); } });
  if (o.time) hit.addEventListener("dblclick", () => setZoom(null));
  box.append(s);
}

function timeTicks(x0, x1, width) {
  const span = x1 - x0, out = [];
  const maxTicks = Math.max(2, Math.floor(width / 70));
  const steps = [600, 1800, 3600, 3 * 3600, 6 * 3600, 12 * 3600, 86400, 2 * 86400, 7 * 86400];
  const st = steps.find(v => span / v <= maxTicks) || 7 * 86400;
  // On UK hours and midnights (one offset for the range: a clock change moves ticks an hour)
  const off = ukOffset(x0);
  for (let t = Math.ceil((x0 + off) / st) * st - off; t <= x1; t += st) {
    const p = ukParts(t), h = +p.hour;
    const label = st >= 86400 || (h === 0 && +p.minute === 0)
      ? new Date(t * 1000).toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: TZ })
      : pad(h) + ":" + pad(p.minute);
    out.push([t, label]);
  }
  return out;
}

function numTicks(fmt = num) {
  return (x0, x1, width) => {
    const st = niceStep(x1 - x0, Math.max(2, Math.floor(width / 90)));
    const out = [];
    for (let v = Math.ceil(x0 / st) * st; v <= x1 + st * 1e-9; v += st) out.push([v, fmt(+v.toPrecision(12))]);
    return out;
  };
}

// Horizontal bars: rows [{label, value, color?}]
function bars(parent, title, rows, opts = {}) {
  const card = el("div", { class: "card" }, el("h3", {}, title));
  const total = opts.total ?? rows.reduce((a, r) => a + r.value, 0);
  const max = Math.max(1, ...rows.map(r => r.value));
  const list = el("div", { class: "bars" });
  for (const r of rows) {
    const share = total ? r.value / total : 0;
    list.append(el("div", { class: "bar", title: `${r.label}: ${r.value.toLocaleString("en-GB")} (${pct(share)})` },
      el("span", { class: "label" }, r.label),
      el("span", { class: "track" }, el("span", { class: "fill", style: `width:${100 * r.value / max}%;background:${r.color || PALETTE[0]}` })),
      el("span", { class: "value" }, (opts.fmt || num)(r.value), el("small", {}, pct(share)))));
  }
  if (!rows.length) list.append(el("p", { class: "muted" }, "Nothing yet."));
  card.append(list);
  if (opts.caption) card.append(el("p", { class: "sub" }, opts.caption));
  parent.append(card);
  return card;
}

function tile(parent, label, value, sub, state, onclick) {
  const t = el(onclick ? "button" : "div", { class: "tile" + (state ? " " + state : ""), type: onclick ? "button" : null, onclick },
    el("span", { class: "label" }, label), el("b", {}, value), sub ? el("span", { class: "sub" }, sub) : null);
  parent.append(t);
  return t;
}

// Sortable table. cols: [{key, label, num?, fmt?(v, row), cls?}]; rows: objects
function table(parent, id, cols, rows, opts = {}) {
  const wrap = el("div", { class: "table-scroll" });
  const sort = ui.sort[id] || opts.sort || null;
  const sorted = rows.slice();
  if (sort) {
    const col = cols.find(c => c.key === sort.key);
    if (col) {
      const val = r => r[col.key];
      sorted.sort((a, b) => {
        const x = val(a), y = val(b);
        const c = x == null ? 1 : y == null ? -1 : typeof x === "number" && typeof y === "number" ? x - y : String(x).localeCompare(String(y));
        return sort.dir === "desc" ? -c : c;
      });
    }
  }
  const t = el("table");
  const tr = el("tr");
  for (const c of cols) {
    const active = sort && sort.key === c.key;
    tr.append(el("th", { class: c.num ? "num" : null, "aria-sort": active ? (sort.dir === "desc" ? "descending" : "ascending") : null },
      el("button", {
        type: "button", onclick: () => {
          const dir = active && sort.dir === (c.num ? "desc" : "asc") ? (c.num ? "asc" : "desc") : (c.num ? "desc" : "asc");
          ui.sort[id] = { key: c.key, dir };
          store("sort", ui.sort);
          wrap.replaceWith(table(el("div"), id, cols, rows, opts));
        },
      }, c.label, active ? (sort.dir === "desc" ? " ↓" : " ↑") : "")));
  }
  t.append(el("thead", {}, tr));
  const body = el("tbody");
  for (const r of sorted.slice(0, opts.limit || Infinity)) {
    body.append(el("tr", {}, ...cols.map(c => {
      const v = r[c.key];
      const shown = c.fmt ? c.fmt(v, r) : v == null ? "–" : typeof v === "number" ? v.toLocaleString("en-GB") : String(v);
      return el("td", { class: [c.num ? "num" : "", c.cls || ""].join(" ").trim() || null }, shown);
    })));
  }
  t.append(body);
  wrap.append(t);
  if (!rows.length) wrap.append(el("p", { class: "muted" }, "Nothing yet."));
  parent.append(wrap);
  return wrap;
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

const mdCells = l => l.trim().replace(/^\||\|$/g, "").split("|").map(c => c.trim());
const isTableAt = (lines, i) => lines[i].trim().startsWith("|") && i + 1 < lines.length && /^\s*\|?\s*:?-{3,}/.test(lines[i + 1]);

// The pipe tables of a report by ## section: [{intro, head, rows: [{column: text}]}],
// intro the paragraph line just above the table
function reportTables(md) {
  const out = {}, lines = (md || "").replace(/\r/g, "").split("\n");
  let sec = "", intro = "";
  for (let i = 0; i < lines.length; i++) {
    const h = lines[i].match(/^#{2,4}\s+(.*)/);
    if (h) { sec = h[1].trim(); intro = ""; continue; }
    if (isTableAt(lines, i)) {
      const head = mdCells(lines[i]), rows = [];
      for (i += 2; i < lines.length && lines[i].trim().startsWith("|"); i++) {
        const c = mdCells(lines[i]);
        rows.push(Object.fromEntries(head.map((k, j) => [k, c[j]])));
      }
      i--;
      (out[sec] = out[sec] || []).push({ intro, head, rows });
    } else if (lines[i].trim()) intro = lines[i].trim();
  }
  return out;
}
const numIn = s => { const m = String(s ?? "").match(/[-+]?\d*\.?\d+/); return m ? +m[0] : null; };
// "-0.0014 ± 0.0010": an estimate and its 95% half-width
const pmIn = s => { const m = String(s ?? "").match(/([-+]?\d*\.?\d+)\s*±\s*(\d*\.?\d+)/); return m ? { mean: +m[1], ci: +m[2] } : null; };
const signed = (v, d = 4) => (v >= 0 ? "+" : "−") + Math.abs(v).toFixed(d);
const pmText = p => `${signed(p.mean)} ± ${p.ci.toFixed(4)}`;

// Markdown as meiolol eval writes it: headings, pipe tables, lists, code, paragraphs
function markdown(text) {
  const out = el("div", { class: "md" });
  const lines = text.replace(/\r/g, "").split("\n");
  const inline = s => {
    const frag = document.createDocumentFragment();
    const re = /(`[^`]+`|\*\*[^*]+\*\*|~~.+?~~)/g;
    let at = 0, m;
    while ((m = re.exec(s))) {
      if (m.index > at) frag.append(s.slice(at, m.index));
      const t = m[0];
      frag.append(t[0] === "`" ? el("code", {}, t.slice(1, -1)) : t[0] === "~" ? el("del", {}, t.slice(2, -2)) : el("strong", {}, t.slice(2, -2)));
      at = m.index + m[0].length;
    }
    frag.append(s.slice(at));
    return frag;
  };
  const cells = mdCells;
  for (let i = 0; i < lines.length;) {
    const l = lines[i];
    if (!l.trim()) { i++; continue; }
    const h = l.match(/^(#{1,4})\s+(.*)/);
    if (h) { out.append(el("h" + Math.min(6, h[1].length + 2), {}, inline(h[2]))); i++; continue; }
    if (l.startsWith("```")) {
      const body = [];
      for (i++; i < lines.length && !lines[i].startsWith("```"); i++) body.push(lines[i]);
      i++;
      out.append(el("pre", {}, body.join("\n")));
      continue;
    }
    if (isTableAt(lines, i)) {
      const head = cells(l);
      const rows = [];
      for (i += 2; i < lines.length && lines[i].trim().startsWith("|"); i++) rows.push(cells(lines[i]));
      const numeric = head.map((_, c) => rows.length > 0 && rows.every(r => /^[-+±0-9.,% ]*$/.test(r[c] || "")));
      out.append(el("div", { class: "table-scroll" }, el("table", {},
        el("thead", {}, el("tr", {}, ...head.map((c, k) => el("th", { class: numeric[k] ? "num" : null }, inline(c))))),
        el("tbody", {}, ...rows.map(r => el("tr", {}, ...r.map((c, k) => el("td", { class: numeric[k] ? "num" : null }, inline(c)))))))));
      continue;
    }
    if (/^\s*[-*]\s+/.test(l)) {
      const ul = el("ul");
      while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) {
        let item = lines[i].replace(/^\s*[-*]\s+/, "");
        for (i++; i < lines.length && /^\s{2,}\S/.test(lines[i]) && !/^\s*[-*]\s+/.test(lines[i]); i++) item += " " + lines[i].trim();
        ul.append(el("li", {}, inline(item)));
      }
      out.append(ul);
      continue;
    }
    const para = [];
    while (i < lines.length && lines[i].trim() && !/^(#{1,4}\s|```|\s*[-*]\s|\s*\|)/.test(lines[i])) para.push(lines[i++].trim());
    if (para.length) out.append(el("p", {}, inline(para.join(" "))));
    else i++;
  }
  return out;
}

// ---------- data sources ----------

let L = null, liveErr = null, liveAt = 0;
let TRAFFIC = null, trafficErr = null;
let TRAIN = null, trainErr = null;
const runCache = new Map();

async function getJson(path) {
  const r = await fetch(path, { cache: "no-store", credentials: "same-origin" });
  if (!r.ok) throw new Error(r.status + " " + r.statusText);
  return r.json();
}
async function getText(path) {
  const r = await fetch(path, { cache: "no-store", credentials: "same-origin" });
  if (!r.ok) throw new Error(r.status + " " + r.statusText);
  return r.text();
}

async function pollLive() {
  try { L = await getJson("api/live.json"); liveErr = null; liveAt = nowS(); } catch (e) { liveErr = e.message; }
  refreshView("live");
}
async function pollSnapshot() {
  try { const d = await getJson("data.json"); if (d.now > D.now) { D = d; refreshView("snapshot"); } } catch (e) { /* the embedded copy stays */ }
}
async function pollTraffic() {
  try { TRAFFIC = await getJson("ops/traffic.json"); trafficErr = null; } catch (e) { trafficErr = e.message; }
  refreshView("traffic");
}
async function pollTraining() {
  try {
    const opt = p => getText("training/" + p).catch(() => null);
    const [runs, pushed, hosts, learned, modelMd, camps] = await Promise.all([getText("training/runs.tsv"),
      opt("pushed.txt"), opt("hosts.tsv"), opt("learned.md"), opt("model.md"), opt("campaigns.txt")]);
    TRAIN = {
      runs: tsvRaw(runs).reverse(), pushed: +(pushed || "").trim() || null,
      hosts: Object.fromEntries(tsvRaw(hosts || "").map(h => [h.host, +h.seen || null])),
    };
    MODELS.learned = learnedByCat(learned);
    await loadFindings(TRAIN.runs.filter(r => r.findings));
    MODELS.modelMd = modelMd;
    MODELS.campaigns = await Promise.all((camps || "").split("\n").filter(Boolean).map(async name => {
      const [digest, hyp] = await Promise.all([opt(`campaigns/${name}/digest.md`), opt(`campaigns/${name}/hypotheses.tsv`)]);
      return { name, digest, hyp: tsvRaw(hyp || "") };
    }));
    trainErr = null;
  } catch (e) { trainErr = e.message; }
  refreshView("training");
}
// TSV kept as strings (run names and args are not numbers)
function tsvRaw(text) {
  const lines = (text || "").split("\n").filter(Boolean);
  if (!lines.length) return [];
  const head = lines[0].split("\t");
  return lines.slice(1).map(l => Object.fromEntries(head.map((h, i) => [h, l.split("\t")[i] || ""])));
}

// Live crawler data when the box answers; the snapshot's otherwise
const crawlLive = () => L && L.crawl && L.crawl.buckets && L.crawl.buckets.length ? L.crawl : null;
const health = () => L && L.health != null ? L.health : D.health;
const queues = () => (L && L.queues) || D.queues;
const disk = () => (L && L.disk) || D.disk;
const freshest = () => Math.max(D.now, L ? L.now : 0);

// ---------- crawl helpers ----------

function crawlFor(range) {
  const live = crawlLive();
  if (range === "3h" && live) return { C: live, from: live.start, to: L.now };
  if (range === "3h") return { C: D.crawl, from: D.now - 3 * 3600, to: D.now };
  return { C: D.crawl, from: range === "24h" ? D.now - 86400 : D.crawl.start, to: D.now };
}
function crawlSeries(C, from) {
  const regionIdx = Object.fromEntries(C.regions.map((r, i) => [r, i]));
  const regions = REGION_ORDER.filter(r => r in regionIdx && ui.regions.has(r));
  const first = Math.max(0, Math.floor((from - C.start) / C.step));
  const bs = C.buckets.slice(first);
  const xs = bs.map((_, i) => C.start + (first + i) * C.step);
  const rate = (get, per = 3600) => bs.map(b => b.covered ? get(b) * per / b.covered : null);
  const byRegion = (get, per = 3600) => regions.map(r => ({ name: r, color: REGION_COLOR[r], values: rate(b => get(b)[regionIdx[r]], per) }));
  const regionSum = (get, b) => sumR(regions.map(r => get(b)[regionIdx[r]]));
  return { xs, bs, rate, byRegion, regions, regionIdx, regionSum };
}
// Rate per hour of a counter over the last hour of C
function lastHour(C, get, now) {
  let v = 0, cov = 0;
  for (let i = C.buckets.length - 1; i >= 0 && C.start + i * C.step >= now - 3600; i--) {
    v += get(C.buckets[i]); cov += C.buckets[i].covered;
  }
  return cov ? v * 3600 / cov : null;
}
function newestCrawl() {
  const live = crawlLive();
  return live ? { C: live, now: L.now } : { C: D.crawl, now: D.now };
}
// null while the snapshot has no crawl.args
function reserveShare() {
  if (!D.riot || D.riot.crawl_args == null) return null;
  const m = D.riot.crawl_args.match(/--reserve\s+(\d+)/);
  return m ? +m[1] / 100 : 0;
}

// ---------- shell ----------

const app = document.getElementById("app");
let lastRender = 0;

function setTab(tab) {
  ui.tab = tab;
  ui.zoom = null;
  history.replaceState(null, "", "#" + tab + (tab === "models" ? "/" + ui.cat : ""));
  render();
  window.scrollTo(0, 0);
}
function setRange(r) {
  ui.range = r;
  ui.zoom = null;
  store("range2", r);
  render();
}
function setZoom(z) {
  ui.zoom = z;
  render(true);
}

// Re-render the open tab when its data changed, keeping scroll and open details
function refreshView(source) {
  const uses = {
    live: ["overview", "crawler", "riot", "storage", "models", "ops"],
    snapshot: TABS.map(t => t[0]).filter(t => t !== "traffic"),
    traffic: ["overview", "traffic"],
    training: ["overview", "models"],
  }[source];
  renderStatus();
  if (!uses || !uses.includes(ui.tab)) return;
  // Not while a field has focus (log filter) or a drag is under way
  const a = document.activeElement;
  if (a && (a.tagName === "INPUT" || a.tagName === "SELECT" || a.tagName === "TEXTAREA")) return;
  render(true);
}

function render(keep) {
  const y = window.scrollY;
  const open = new Set([...app.querySelectorAll("details[open] > summary")].map(s => s.textContent));
  app.replaceChildren();
  const top = el("header", { class: "top" },
    el("h1", {}, "meiolol ", el("span", {}, "admin")),
    el("span", { id: "status", class: "status" }));
  const controls = el("div", { class: "controls" });
  if (TIMED.has(ui.tab)) {
    controls.append(switcher([["3h", "3 hours"], ["24h", "24 hours"], ["7d", `${D.days} days`]], ui.range, setRange, "Range"));
  }
  if (["overview", "crawler", "riot", "ingest"].includes(ui.tab)) {
    const chips = el("div", { class: "chips", role: "group", "aria-label": "Regions" });
    for (const r of REGION_ORDER) {
      chips.append(el("button", {
        type: "button", "aria-pressed": String(ui.regions.has(r)),
        onclick: () => {
          if (ui.regions.has(r) && ui.regions.size > 1) ui.regions.delete(r); else ui.regions.add(r);
          store("regions", [...ui.regions]);
          render(true);
        },
      }, el("i", { style: "background:" + REGION_COLOR[r] }), r));
    }
    controls.append(chips);
  }
  if (ui.zoom) {
    controls.append(el("button", { type: "button", class: "zoom", onclick: () => setZoom(null) },
      `${uk(ui.zoom[0])} to ${uk(ui.zoom[1])}`, el("span", { "aria-hidden": "true" }, " ×")));
  }
  controls.append(el("button", { type: "button", class: "ghost", title: "Fetch everything now", onclick: () => refreshAll() }, "Refresh"));
  top.append(controls);
  const nav = el("nav", { class: "tabs", "aria-label": "Sections" });
  TABS.forEach(([k, label], i) => nav.append(el("a", { href: "#" + k, "aria-current": k === ui.tab ? "page" : null, title: `${label} (${i + 1})`, onclick: ev => { ev.preventDefault(); setTab(k); } }, label)));
  app.append(top, nav);
  const body = el("div", { class: "tab" });
  app.append(body);
  try {
    VIEWS[ui.tab](body);
  } catch (e) {
    body.append(el("div", { class: "health bad" }, el("b", {}, "This tab failed to draw: "), String(e && e.message || e)));
    console.error(e);
  }
  for (const d of app.querySelectorAll("details")) {
    const s = d.querySelector(":scope > summary");
    if (s && open.has(s.textContent)) d.open = true;
  }
  renderStatus();
  lastRender = Date.now();
  if (keep) window.scrollTo(0, y);
}

function renderStatus() {
  const s = document.getElementById("status");
  if (!s) return;
  if (L && !liveErr) {
    s.className = "status live";
    s.textContent = `Live, updated ${ago(liveAt)}`;
    s.title = `Snapshot ${uk(D.now)} ${zoneName(D.now)}. Times in UK time.`;
  } else {
    s.className = "status stale";
    s.textContent = `Snapshot from ${ago(D.now)}` + (liveErr ? " (live API unavailable)" : "");
    s.title = liveErr ? "api/live.json: " + liveErr : "";
  }
}

async function refreshAll() {
  await Promise.all([pollLive(), pollSnapshot(), pollTraffic(), pollTraining()]);
}

// ---------- views ----------

const VIEWS = {};

VIEWS.overview = body => {
  healthBanner(body);
  const { C, now } = newestCrawl();
  const crawlUp = L && L.services ? L.services["meiolol-crawl"] === "active" : null;
  const tiles = grid(body, "tiles");
  const silent = C.last_report == null || now - C.last_report > 900;
  const mHour = lastHour(C, b => sumR(b.m), now), tHour = lastHour(C, b => sumR(b.t), now);
  tile(tiles, "Crawler", crawlUp == null ? (silent ? "silent" : "reporting") : crawlUp ? "running" : L.services["meiolol-crawl"],
    `last report ${ago(C.last_report)}`, silent || crawlUp === false ? "bad" : "good", () => setTab("crawler"));
  tile(tiles, "Matches / day", mHour == null ? "–" : num(mHour * 24), "rate over the last hour", silent ? "bad" : null, () => setTab("crawler"));
  tile(tiles, "Timelines / day", tHour == null ? "–" : num(tHour * 24), "rate over the last hour", null, () => setTab("crawler"));
  const req = lastHour(C, b => sumR(b.req), now);
  const nReg = C.regions.length || 1;
  tile(tiles, "Riot key use", req == null ? "–" : pct(req / 60 / (KEY_PER_MIN * nReg)), `${num(req == null ? null : req / 60)} requests / min, all routes`, null, () => setTab("riot"));
  const q = queues();
  const pending = rows => sumR(rows.filter(g => / ?pending$/.test(g.key) || g.key === "pending").map(g => g.n));
  tile(tiles, "Queues", num(pending(q.match) + pending(q.timeline)), `${num(pending(q.match))} matches, ${num(pending(q.timeline))} timelines pending`, null, () => setTab("crawler"));
  const dk = disk();
  if (dk) {
    const used = dk[1] / dk[0];
    tile(tiles, "Disk", pct(used) + " used", `${bytes(dk[2])} free` + daysLeftText(), used > 0.8 ? "bad" : used > 0.65 ? "warn" : null, () => setTab("storage"));
  }
  const lastUp = D.uploads.length ? D.uploads[D.uploads.length - 1] : null;
  tile(tiles, "Site upload", ago(lastUp), `${D.uploads.filter(t => t >= D.now - 86400).length} in the last 24 h`, lastUp == null || D.now - lastUp > 26 * 3600 ? "bad" : null, () => setTab("ops"));
  if (TRAFFIC) {
    const h = TRAFFIC.hours.filter(r => r[0] >= TRAFFIC.generated - 86400);
    tile(tiles, "Site views, 24 h", num(sumR(h.map(r => r[1]))), `${num(sumR(h.map(r => r[2])))} by bots`, null, () => setTab("traffic"));
  }
  const ev = tsv(D.eval);
  if (ev.length) {
    const e = ev[ev.length - 1];
    const best = ["base", "current", "eb", "joint"].reduce((a, k) => (e["auc_" + k] ?? 0) > (e["auc_" + a] ?? 0) ? k : a, "base");
    tile(tiles, "Model AUC", (e["auc_" + best] ?? 0).toFixed(3), `best: ${best === "eb" ? "shrunk" : best}, ${num(e.games)} games`, null, () => { ui.cat = "win"; setTab("models"); });
  }
  if (TRAIN && TRAIN.runs.length) {
    const live = TRAIN.runs.filter(r => r.state === "running" || r.state === "paused");
    const r = live[0] || TRAIN.runs[0];
    tile(tiles, "Training", live.length ? `${live.length} running` : "idle", `${shortRun(r.run)}: ${runState(r.state)}`, null, () => { ui.cat = "all"; setTab("models"); });
  }

  const { from, to } = crawlFor(ui.range);
  const cv = crawlFor(ui.range);
  const S = crawlSeries(cv.C, from);
  const common = { x: S.xs, step: cv.C.step, markers: cv.C.restarts, xMin: from, xMax: to, time: true };
  const g = grid(body);
  chart(g, { ...common, id: "ov-matches", title: "Matches stored per hour", type: "area", series: S.byRegion(b => b.m) });
  chart(g, {
    ...common, id: "ov-req", title: "Riot requests per minute, by region", type: "line",
    series: S.byRegion(b => b.req, 60), ref: { value: KEY_PER_MIN, label: "key limit" },
  });
  if (TRAFFIC) {
    const hrs = TRAFFIC.hours.filter(r => r[0] >= TRAFFIC.generated - 2 * 86400);
    chart(g, {
      id: "ov-traffic", title: "Site page views per hour", type: "bars", step: 3600, time: true,
      x: hrs.map(r => r[0]), xMin: TRAFFIC.generated - 2 * 86400, xMax: TRAFFIC.generated,
      series: [{ name: "people", color: PALETTE[0], values: hrs.map(r => r[1]) }, { name: "bots", color: PALETTE[5], values: hrs.map(r => r[2]) }],
    });
  }
  if (L && L.actions && L.actions.length) {
    const s = section(body, "Recent actions", null);
    actionList(s, L.actions.slice(-5));
  }
};

function daysLeftText() {
  const g = growthPerDay("disk_used");
  const dk = disk();
  if (!dk || !(g > 0)) return "";
  return `, full in ~${Math.round(dk[2] / g)} days`;
}

function healthBanner(parent) {
  const h = health();
  if (h == null) return;
  const problems = h.trim().split("\n").filter(Boolean);
  parent.append(el("div", { class: "health " + (problems.length ? "bad" : "good") },
    el("b", {}, problems.length ? `⚠ ${problems.length} problem${problems.length > 1 ? "s" : ""}` : "✓ All checks pass"),
    problems.length ? el("ul", {}, ...problems.map(p => el("li", {}, p))) : el("span", {}, " crawler, site loop, upload age, disk, backups")));
}

// What the crawl's counters say: rates now against the week, queue direction, retention
function crawlReadings(body) {
  const h = tsv(D.history);
  if (h.length < 2) return;
  const sec = section(body, "Readings", "From the 15-minute snapshots (data/admin-history.tsv): least-squares rates, so one odd snapshot doesn't swing them.");
  const tiles = grid(sec, "tiles");
  const rate = (col, days) => growthPerDay(col, days);
  const trend = (col, label) => {
    const r6 = rate(col, 0.25), r24 = rate(col, 1), wk = rate(col, 7);
    const shift = r6 != null && r24 ? r6 / r24 - 1 : null;
    tile(tiles, label + " / day", num(r24), `last 6 h ${num(r6)}, week ${num(wk)}` + (shift != null && Math.abs(shift) > 0.25 ? ` · ${shift > 0 ? "up" : "down"} ${Math.round(Math.abs(shift) * 100)}% lately` : ""),
      shift != null && shift < -0.5 ? "warn" : null);
  };
  trend("matches", "Matches");
  trend("timelines", "Timelines");
  const m24 = rate("matches", 1), t24 = rate("timelines", 1);
  if (m24 > 0 && t24 != null) {
    const args = (D.riot && D.riot.crawl_args) || "";
    const want = (args.match(/--timelines\s+(\d+)/) || [])[1];
    tile(tiles, "Timelines per new match", pct(t24 / m24), want ? `crawler asks for ${want}%` : "share of matches that get a timeline");
  }
  const last = h[h.length - 1];
  for (const [col, label] of [["match_queue", "Match queue"], ["timeline_queue", "Timeline queue"]]) {
    const r = rate(col, 1), n = last[col];
    if (n == null || r == null) continue;
    const text = Math.abs(r) < n * 0.02 ? "steady over the last day" : r < 0 ? `shrinking ${num(-r)} / day: empty in ~${span(n / -r * 86400)}` : `growing ${num(r)} / day: the crawler falls behind`;
    tile(tiles, label, num(n), text, r > 0 && Math.abs(r) >= n * 0.02 ? "warn" : null);
  }
  const ms = rate("mastery", 1);
  if (ms != null) tile(tiles, "Mastery rows / day", num(ms), ms > 0 ? "collecting" : "not collecting (off in crawl.args?)");
  const args = (D.riot && D.riot.crawl_args) || "";
  const flag = (k, d) => { const m = args.match(new RegExp("--" + k + "\\s+(\\S+)")); return m ? m[1] : d; };
  if (args) {
    const keep = v => v === "0" ? "forever" : `${v} days`;
    const lines = [
      `Raw match summaries on the box: kept ${keep(flag("raw-match-days", "?"))}. Raw timelines: ${keep(flag("raw-timeline-days", "?"))} (the gpu-box archive takes them hourly). Compact rows: ${keep(flag("keep-days", "?"))}.`,
      `Ladder floor ${cap(flag("min-tier", "?"))}; ${flag("ladder-per-hour", "?")} ladder pages an hour, refreshed every ${flag("ladder-refresh-hours", "?")} h; ${flag("reserve", "0")}% of the key held back for the site.`,
    ];
    sec.append(el("ul", { class: "readings" }, ...lines.map(t => el("li", {}, t))));
  }
}

VIEWS.crawler = body => {
  const cv = crawlFor(ui.range);
  const C = cv.C;
  const S = crawlSeries(C, cv.from);
  const common = { x: S.xs, step: C.step, markers: C.restarts, xMin: cv.from, xMax: cv.to, time: true };
  const per = C.step >= 600 ? "per 10 min" : "per minute";
  crawlReadings(body);
  const sec = section(body, "Crawler", `From the crawler's minute report lines${C === D.crawl ? "" : " (live, last 3 hours)"}; gaps = crawler not running, dashed = crawler start. Drag across a chart to zoom, double-click to reset.`);
  const g = grid(sec);
  chart(g, { ...common, title: "Matches stored per hour", type: "area", series: S.byRegion(b => b.m) });
  chart(g, { ...common, title: "Timelines stored per hour", type: "area", series: S.byRegion(b => b.t) });
  chart(g, {
    ...common, title: "Ladder, mastery and match list calls per hour", type: "line",
    series: [
      { name: "ladder pages", color: PALETTE[0], values: S.rate(b => b.ladder) },
      { name: "mastery", color: PALETTE[1], values: S.rate(b => b.mastery) },
      { name: "match id lists", color: PALETTE[2], values: S.rate(b => S.regionSum(x => x.ids, b)) },
    ],
  });
  chart(g, {
    ...common, title: "Writer commits per minute", type: "line",
    series: [{ name: "commits", color: PALETTE[0], values: S.rate(b => b.commits, 60) }],
    caption: "Each commit is a batch of queued jobs (one per match or timeline).",
  });
  chart(g, {
    ...common, title: `Writer queue, highest ${per}`, type: "line",
    series: [{ name: "jobs waiting", color: PALETTE[1], values: S.bs.map(b => b.covered ? b.queued_max : null) }],
    ref: { value: 128, label: "full: workers block" },
  });
  chart(g, {
    ...common, title: "Database pages per minute (writer connection)", type: "line",
    series: [
      { name: "written", color: PALETTE[0], values: S.rate(b => b.pages_written, 60) },
      { name: "read", color: PALETTE[1], values: S.rate(b => b.pages_read, 60) },
    ],
  });
  chart(g, {
    ...common, title: `Warnings ${per}`, type: "bars",
    series: C.kinds.map((k, i) => ({ name: KIND_LABEL[k] || k, color: PALETTE[i], values: S.bs.map(b => b.warnings[i]) })),
  });
  if (C.messages && C.messages.length) {
    const d = el("details", { open: true }, el("summary", {}, `Warning messages (${C.messages.length})`));
    sec.append(d);
    table(d, "messages", [
      { key: "kind", label: "Kind", fmt: k => el("span", { class: "kind" }, el("i", { class: "dot", style: "background:" + PALETTE[C.kinds.indexOf(k)] }), KIND_LABEL[k] || k) },
      { key: "text", label: "Message (last 24 h)", cls: "msg" },
      { key: "count", label: "Count", num: true },
      { key: "last", label: "Last", num: true, fmt: v => ago(v) },
    ], C.messages, { sort: { key: "count", dir: "desc" } });
  }
  const qs = section(body, "Queues", L && L.queues ? "Live." : "From the snapshot.");
  const qc = grid(qs, "cards");
  const q = queues();
  bars(qc, "Match queue", q.match.map(g => ({ label: g.key, value: g.n, color: g.key === "failed" ? BAD : PALETTE[0] })));
  bars(qc, "Timeline queue", q.timeline.filter(g => ui.regions.has(g.key.split(" ")[0])).map(g => {
    const [r, st] = g.key.split(" ");
    return { label: g.key, value: g.n, color: st === "failed" ? BAD : REGION_COLOR[r] };
  }));
  const history = tsv(D.history);
  const qg = grid(qs);
  chart(qg, {
    x: history.map(r => r.time), title: "Queue backlog (snapshots)", type: "line", time: true,
    series: [
      { name: "match queue", color: PALETTE[0], values: history.map(r => r.match_queue) },
      { name: "timeline queue", color: PALETTE[1], values: history.map(r => r.timeline_queue) },
    ],
  });
};

VIEWS.riot = body => {
  const cv = crawlFor(ui.range);
  const C = cv.C;
  const S = crawlSeries(C, cv.from);
  const common = { x: S.xs, step: C.step, markers: C.restarts, xMin: cv.from, xMax: cv.to, time: true };
  const { C: NC, now } = newestCrawl();
  const reserve = reserveShare();
  // Before the box sends its limits: the personal key's documented app limit
  const R = D.riot || { app_limit: "20:1,100:120" };
  const sec = section(body, "Riot API key", "Personal key: limits per routing value (region). Usage from the crawler's report lines.");
  const tiles = grid(sec, "tiles");
  const idx = Object.fromEntries(NC.regions.map((r, i) => [r, i]));
  for (const r of REGION_ORDER.filter(r => r in idx)) {
    const perMin = lastHour(NC, b => b.req[idx[r]], now);
    const use = perMin == null ? null : perMin / 60 / KEY_PER_MIN;
    tile(tiles, r, perMin == null ? "–" : pct(use), `${num(perMin == null ? null : perMin / 60)} / min of ${KEY_PER_MIN}`, use > 0.98 ? "warn" : null);
  }
  const rlIdx = NC.kinds.indexOf("rate_limit"), srvIdx = NC.kinds.indexOf("riot_server");
  const day = D.crawl.buckets.filter((_, i) => D.crawl.start + i * D.crawl.step >= D.now - 86400);
  tile(tiles, "429s, 24 h", num(sumR(day.map(b => b.warnings[rlIdx]))), "rate limited answers", sumR(day.map(b => b.warnings[rlIdx])) > 50 ? "warn" : null);
  tile(tiles, "Riot 5xx, 24 h", num(sumR(day.map(b => b.warnings[srvIdx]))), "server errors");
  const kp = R.key_problems || [];
  tile(tiles, "Key problems", kp.length ? num(kp.length) : "none", kp.length ? `last ${ago(kp[kp.length - 1][0])}` : "no 401/403 in the window", kp.length ? "bad" : "good");
  tile(tiles, "Reserve", reserve == null ? "–" : pct(reserve), "left for the Your games service");

  const g = grid(sec);
  const refs = [{ value: KEY_PER_MIN, label: "key limit (100 / 2 min)" }];
  if (reserve) refs.push({ value: KEY_PER_MIN * (1 - reserve), label: `crawler target (${pct(reserve)} reserve)` });
  chart(g, { ...common, title: "Requests per minute, by region", type: "line", series: S.byRegion(b => b.req, 60), ref: refs });
  chart(g, {
    ...common, title: "Platform route requests per minute", type: "line",
    series: [{ name: "platform routes", color: PALETTE[4], values: S.rate(b => b.platform_req, 60) }],
    caption: "Ladder and mastery calls go to platform hosts (own limits per platform).",
  });
  chart(g, {
    ...common, title: "Rate limited and server errors", type: "bars",
    series: [
      { name: "429", color: PALETTE[3], values: S.bs.map(b => b.warnings[C.kinds.indexOf("rate_limit")]) },
      { name: "Riot 5xx", color: PALETTE[1], values: S.bs.map(b => b.warnings[C.kinds.indexOf("riot_server")]) },
    ],
  });
  const cards = grid(sec, "cards");
  const lim = el("div", { class: "card" }, el("h3", {}, "Limits"));
  const specRows = [];
  const spec = (name, s) => (s || "").split(",").filter(Boolean).forEach(p => {
    const [n, secs] = p.split(":").map(Number);
    specRows.push({ name, limit: n, window: secs, per_min: n * 60 / secs });
  });
  spec("app (per region)", R.app_limit);
  for (const [k, v] of Object.entries(R.method_limits || {})) spec(k, v);
  table(lim, "limits", [
    { key: "name", label: "Bucket" }, { key: "limit", label: "Requests", num: true },
    { key: "window", label: "Window", num: true, fmt: v => span(v) },
    { key: "per_min", label: "Per minute", num: true, fmt: v => num(v) },
  ], specRows);
  if (R.crawl_args) lim.append(el("p", { class: "sub" }, "Crawler arguments: ", el("code", {}, R.crawl_args.trim())));
  cards.append(lim);
  const kc = el("div", { class: "card" }, el("h3", {}, "Key problems"));
  if (kp.length) table(kc, "key-problems", [{ key: "t", label: "When", fmt: v => uk(v) }, { key: "msg", label: "Message", cls: "msg" }], kp.map(([t, msg]) => ({ t, msg })).reverse());
  else kc.append(el("p", { class: "muted" }, "No rejected-key answers in the crawl log window."));
  cards.append(kc);
};

// Growth per day of a history column, over the newest week (or all history when shorter)
function historyDays() {
  const h = tsv(D.history);
  return h.length > 1 ? Math.min(7, (h[h.length - 1].time - h[0].time) / 86400) : 0;
}
// Sizes that include a WAL: growth is read without it (history from 13 Oct has the WAL
// columns), and on the lower envelope (points no later point undercuts) for older rows,
// where a WAL swing would read as growth and then shrinkage
const WAL_OF = {
  meiolol_db: ["meiolol_wal"], timeline_db: ["timeline_wal"], raw_db: ["raw_wal"],
  disk_used: ["meiolol_wal", "timeline_wal", "raw_wal"],
};
// Per day over the newest `days`, least squares (null under ~5 h of history)
function growthPerDay(col, days = 7) {
  const h = tsv(D.history).filter(r => r[col] != null);
  if (h.length < 2) return null;
  const end = h[h.length - 1].time;
  let pts = h.filter(r => r.time >= end - days * 86400).map(r => [r.time, r[col] - sumR((WAL_OF[col] || []).map(c => r[c]))]);
  if (WAL_OF[col]) {
    let min = Infinity;
    pts = pts.reverse().filter(([, v]) => v <= min ? (min = v, true) : false).reverse();
  }
  if (pts.length < 2 || pts[pts.length - 1][0] - pts[0][0] < 0.2 * 86400) return null;
  return slope(pts) * 86400;
}
function slope(pts) {
  const n = pts.length, mx = sumR(pts.map(p => p[0])) / n, my = sumR(pts.map(p => p[1])) / n;
  let sxy = 0, sxx = 0;
  for (const [x, y] of pts) { sxy += (x - mx) * (y - my); sxx += (x - mx) ** 2; }
  return sxx ? sxy / sxx : 0;
}
const dayDate = t => new Date(t * 1000).toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: TZ });

VIEWS.storage = body => {
  const history = tsv(D.history);
  const hx = history.map(r => r.time);
  const files = D.files;
  const dk = disk();
  const sec = section(body, "Space", "Snapshots every 15 min (data/admin-history.tsv); growth over the newest week.");
  const tiles = grid(sec, "tiles");
  if (dk) {
    const used = dk[1] / dk[0];
    tile(tiles, "Disk used", pct(used), `${bytes(dk[1])} of ${bytes(dk[0])}`, used > 0.8 ? "bad" : used > 0.65 ? "warn" : null);
    const g = growthPerDay("disk_used"), g1 = growthPerDay("disk_used", 1);
    tile(tiles, "Disk growth", g == null ? "–" : bytes(g) + " / day", `over the last ${span(historyDays() * 86400)}, WAL excluded` + (g1 == null ? "" : `; last 24 h ${bytes(g1)} / day`));
    if (g > 0) {
      const left = dk[2] / g, faster = g1 > g ? dk[2] / g1 : null;
      tile(tiles, "Disk full around", dayDate(D.now + left * 86400), `in ~${Math.round(left)} days at the week's rate` + (faster ? `, ~${Math.round(faster)} at the last 24 h's` : ""), left < 14 ? "bad" : left < 30 ? "warn" : null);
    }
  }
  const dbTotal = sumR(files.map(f => f.bytes));
  tile(tiles, "Databases", bytes(dbTotal), files.map(f => `${f.name.replace(".db", "")} ${bytes(f.bytes)}`).join(" · "));
  const matches = (D.counts.find(c => c.name === "matches") || {}).rows;
  if (matches) tile(tiles, "Per stored match", bytes(dbTotal / matches), "all databases, WAL included");
  const dbCols = [["meiolol", "meiolol_db"], ["timeline", "timeline_db"], ["raw", "raw_db"]];
  const dbg = sumR(dbCols.map(([, c]) => growthPerDay(c) || 0));
  tile(tiles, "Database growth", dbg ? bytes(dbg) + " / day" : "–", dbCols.map(([n, c]) => `${n} ${bytes(growthPerDay(c))}`).join(" · ") + ", newest week, WAL excluded");
  if (D.backups) tile(tiles, "Backups", bytes(D.backups.bytes), `${D.backups.files} files, newest ${ago(D.backups.newest)}`, D.backups.newest && D.now - D.backups.newest > 2 * 86400 ? "warn" : null);
  const g = grid(sec);
  chart(g, {
    x: hx, title: "Database files on disk", type: "area", fmt: bytes, time: true,
    caption: "WAL files included: a sharp drop is a checkpoint folding the WAL back into its database.",
    series: [["meiolol.db", "meiolol_db"], ["timeline.db", "timeline_db"], ["raw.db", "raw_db"]].map(([name, col], i) => ({ name, color: PALETTE[i], values: history.map(r => r[col]) })),
  });
  if (dk) {
    chart(g, {
      x: hx, title: "Disk used", type: "line", fmt: bytes, time: true,
      series: [{ name: "used", color: PALETTE[1], values: history.map(r => r.disk_used) }],
      ref: { value: dk[0], label: "disk size" },
    });
  }

  // Per table and index, from the daily dbstat scan
  const st = D.storage;
  const bd = section(body, "What takes the space", st ? `Daily dbstat scan, ${ago(st.generated)}. Sizes are pages in the file, so free pages and the WAL are not counted.` : "No dbstat scan yet (daily on the box, data/storage.tsv).");
  if (st && st.rows.length) {
    const rows = st.rows.map(([db, name, kind, b, cells]) => ({ db, name, kind, bytes: b, cells, per_cell: cells ? b / cells : null }));
    const byDb = {};
    for (const r of rows) (byDb[r.db] = byDb[r.db] || []).push(r);
    const cards = grid(bd, "cards");
    Object.entries(byDb).forEach(([db, rs]) => {
      rs.sort((a, b) => b.bytes - a.bytes);
      const total = sumR(rs.map(r => r.bytes));
      const top = rs.slice(0, 8);
      const rest = sumR(rs.slice(8).map(r => r.bytes));
      const list = top.map(r => ({ label: r.name, value: r.bytes, color: r.kind === "index" ? PALETTE[5] : PALETTE[0] }));
      if (rest) list.push({ label: `${rs.length - 8} more`, value: rest, color: "#5b6478" });
      const idx = sumR(rs.filter(r => r.kind === "index").map(r => r.bytes));
      bars(cards, `${db}.db: ${bytes(total)}`, list, { fmt: bytes, total, caption: `Indexes ${pct(idx / total)} (purple), tables blue.` });
    });
    const totals = Object.fromEntries(Object.entries(byDb).map(([db, rs]) => [db, sumR(rs.map(r => r.bytes))]));
    const d = el("details", {}, el("summary", {}, `Every table and index (${rows.length})`));
    bd.append(d);
    table(d, "dbstat", [
      { key: "db", label: "DB" }, { key: "name", label: "Name" }, { key: "kind", label: "Kind" },
      { key: "bytes", label: "Size", num: true, fmt: v => bytes(v) },
      { key: "share", label: "Share of DB", num: true, fmt: v => pct(v) },
      { key: "cells", label: "Cells", num: true, fmt: v => num(v) },
      { key: "per_cell", label: "Bytes / cell", num: true, fmt: v => v == null ? "–" : num(v) },
    ], rows.map(r => ({ ...r, share: r.bytes / totals[r.db] })), { sort: { key: "bytes", dir: "desc" } });
  }

  // Rows and their growth
  const rs = section(body, "Rows", "Row counts per snapshot; growth over the newest week.");
  const minis = grid(rs, "charts minis");
  const histCol = { "timeline.timelines": "timelines" };
  for (const [col, title] of [["matches", "Matches"], ["timelines", "Timelines"], ["drafts", "Draft rows"],
    ["players", "Players (scan pool)"], ["ranks", "Ladder ranks"], ["mastery", "Mastery rows"]]) {
    chart(minis, { x: hx, title, type: "line", small: true, time: true, series: [{ name: title, color: PALETTE[0], values: history.map(r => r[col]) }] });
  }
  const dayAgo = history.find(r => r.time >= D.now - 86400);
  table(rs, "counts", [
    { key: "name", label: "Table" },
    { key: "rows", label: "Rows", num: true },
    { key: "day", label: "24 h change", num: true, fmt: v => v == null ? "" : (v >= 0 ? "+" : "") + v.toLocaleString("en-GB") },
    { key: "week", label: "Per day (week)", num: true, fmt: v => v == null ? "" : num(v) },
  ], D.counts.map(c => {
    const col = histCol[c.name] || c.name;
    const before = dayAgo && dayAgo[col] != null ? dayAgo[col] : null;
    return { name: c.name, rows: c.rows, day: before == null ? null : c.rows - before, week: history.length && history[0][col] !== undefined ? growthPerDay(col) : null };
  }));
};

VIEWS.ingest = body => {
  const M = D.drafts;
  const regionIdx = Object.fromEntries(D.crawl.regions.map((r, i) => [r, i]));
  const regions = REGION_ORDER.filter(r => r in regionIdx && ui.regions.has(r));
  const sec = section(body, "What we ingest", `Complete ranked games (draft rows): the newest ${num(M.rows)} stored.`);
  const g = grid(sec);
  const days = M.days;
  chart(g, {
    x: days.map(d => d.day * 86400), step: 86400, title: "Games by game day", type: "bars",
    xFmt: t => dayLabel(t / 86400), xMin: days.length ? days[0].day * 86400 : 0,
    xMax: days.length ? (days[days.length - 1].day + 1) * 86400 : 1,
    series: regions.map(r => ({ name: r, color: REGION_COLOR[r], values: days.map(d => d.region[regionIdx[r]]) })),
  });
  chart(g, {
    x: M.minutes.map((_, i) => i * 5), step: 5, title: "Game length", type: "bars",
    xFmt: m => m >= 60 ? "60+ min" : `${m}–${m + 5} min`, xMin: 0, xMax: 65,
    xTicks: () => [0, 15, 30, 45, 60].map(m => [m, m + " min"]),
    series: [{ name: "games", color: PALETTE[0], values: M.minutes }],
  });
  const cards = grid(sec, "cards");
  const blue = M.rows ? M.blue_wins / M.rows : null;
  const ranked = M.rows ? 1 - M.tiers[M.tiers.length - 1] / M.rows : null;
  cards.append(el("div", { class: "card" }, el("h3", {}, "Sanity"), el("dl", {},
    el("dt", {}, "Blue side wins"), el("dd", {}, pct(blue)),
    el("dt", {}, "With a median rank"), el("dd", {}, pct(ranked)),
    el("dt", {}, "Platforms"), el("dd", {}, String(M.platforms.length)),
    el("dt", {}, "Patches"), el("dd", {}, M.patches.map(p => p.key).join(", ") || "–"))));
  const platformRegion = id => (D.platforms.find(p => p.id === id) || {}).region;
  bars(cards, "Games by platform", M.platforms.filter(p => ui.regions.has(platformRegion(p.key))).map(p => ({ label: p.key, value: p.n, color: REGION_COLOR[platformRegion(p.key)] })));
  bars(cards, "Games by median rank", TIERS.map((t, i) => ({ label: cap(t), value: M.tiers[i] }))
    .concat([{ label: "Unknown", value: M.tiers[TIERS.length], color: "#5b6478" }]).filter(r => r.value));
  bars(cards, "Ladder players by tier", D.ladder.map(g => ({ label: cap(g.key), value: g.n, color: PALETTE[2] })),
    { caption: "Every player a ladder page showed (ranks table)." });
  bars(cards, "Scan pool by region", D.players.filter(g => ui.regions.has(g.key) || !REGION_ORDER.includes(g.key)).map(g => ({ label: g.key, value: g.n, color: REGION_COLOR[g.key] })));
  bars(cards, "Matches by patch", D.by_patch.map(g => ({ label: g.key, value: g.n, color: PALETTE[5] })));
};

// ---------- models ----------
//
// One tab over every model: categories (docs/learned.md's ## headings), each with what we
// learnt in plain sentences, the best result against its baseline, its runs, then run
// health (curves, logs) last. Sources: the eval report and history (box snapshot), the
// training view the Mac uploads (deploy/lab-push.sh: runs of the Mac and the gpu-box,
// learned.md, model.md, lab campaigns, run findings)

const CATS = [
  ["all", "All"], ["win", "Win (draft)"], ["draft", "Draft tester"], ["early", "Early game"], ["items", "Items"],
  ["objectives", "Objectives"], ["playstyle", "Playstyle"], ["player", "Player"],
  ["data", "Data quality"], ["lab", "Lab campaigns"],
];
const CAT_OF_HEADING = {
  "win": "win", "early game": "early", "items": "items", "objectives": "objectives",
  "playstyle": "playstyle", "player": "player", "data quality": "data",
};
// Lab targets: label, unit of the outcome
const OUTCOMES = {
  win: ["Win", ""], gold14: ["Gold at 14 min", "gold"], lanediff14: ["Lane gold lead at 14 min", "gold"],
  cs10: ["CS at 10 min", "CS"], deaths15: ["Deaths before 15 min", "deaths"], first_item: ["First finished item", "minutes"],
};
const CAT_OF_TARGET = { win: "win", gold14: "early", lanediff14: "early", cs10: "early", deaths15: "early", first_item: "early" };
// Published draft-only models (docs/model.md "Method"): ~55-57% accuracy, log loss ~0.687
const LL_COIN = 0.6931, LL_PUBLISHED = 0.687;

// meiolol-lab's RESULT line (lab-push.sh puts it in `last` when a run has no metrics)
function labResult(last) {
  if (!last) return null;
  const kind = (last.match(/^(\w+)[ =]/) || [])[1];
  if (!kind) return null;
  const f = { kind: kind === "run" ? "run" : kind };
  for (const m of last.matchAll(/(\w+)=(\S+)/g)) f[m[1]] = m[2];
  const verdict = last.match(/\(([^)]*)\)/);
  f.verdict = verdict ? verdict[1] : null;
  f.dev = pmIn(f.dev);
  f.gain = pmIn(f.gain);
  f.bias = pmIn(f.bias);
  return f;
}

function runInfo(r) {
  const a = (r.args || "").split(/\s+/);
  const lab = a[0] === "exp" ? { cmd: a[1], campaign: a[3], target: a[4] } : null;
  const res = labResult(r.last);
  const target = (res && res.target) || (lab && lab.target) || Object.keys(OUTCOMES).find(k => a.includes(k)) || null;
  const synthetic = a[0] === "train-demo";
  let cat = target && CAT_OF_TARGET[target];
  if (!cat && /^(enemy|outcomes|fm|pairs|team)/.test(a[0] || "")) cat = "early";
  if (!cat && /item/.test(r.args)) cat = "items";
  if (!cat && /objective/.test(r.args)) cat = "objectives";
  if (!cat && /playstyle/.test(r.args)) cat = "playstyle";
  const result = MODELS.findings.get(r.run)?.result;
  if (result && result.category && result.category !== "-") cat = result.category;
  return { ...r, host: r.host || "mac", lab, res, result, target: target || (result && result.target), synthetic, cat: cat || null, campaign: (lab && lab.campaign) || (result && result.campaign) };
}

// What a run found, in a sentence a non-statistician can read
function runSentence(i) {
  const res = i.res || {}, out = OUTCOMES[i.target];
  const what = out ? out[0].toLowerCase() : i.target || "the outcome";
  if (i.synthetic) return "Synthetic: random curves from a test script, not a model.";
  if (!res && !(i.result && i.result.removed_pct)) return i.last ? i.last : "";
  const rt = i.result, rp = rt && +rt.removed_pct, rh = rt && +rt.removed_half;
  if (rt && isFinite(rp) && isFinite(rh) && rt.removed_pct !== "") {
    const unit = rt.unit && rt.unit !== "-" ? " " + rt.unit : "";
    const miss = isFinite(+rt.err_base) && isFinite(+rt.err_cand) && unit ? ` Typical miss ${num(+rt.err_base)} → ${num(+rt.err_cand)}${unit}.` : "";
    let s = rp - rh > 0 ? `Predicts ${what} better than champion averages: ${rp.toFixed(1)}% (± ${rh.toFixed(1)}) of the error removed on practice games.${miss}`
      : rp + rh < 0 ? `Predicts ${what} worse than champion averages (${rp.toFixed(1)}% ± ${rh.toFixed(1)}).`
        : `No measurable difference from champion averages for ${what}.`;
    if (rt.select === "new-best") s += " Confirmed on the held-back selection games: the new best.";
    else if (rt.select === "no-change") s += " Not better on the held-back selection games.";
    return s;
  }
  if (res.kind === "run" && res.dev && !res.dev.ci) return `Reference run for ${what}: the baseline scored against itself.`;
  if (res.kind === "run" && res.dev) {
    const better = res.dev.mean + res.dev.ci < 0, worse = res.dev.mean - res.dev.ci > 0;
    // Scores are squared error in the role's standard deviation, so dev x 100 is about
    // the % of the outcome's spread
    const size = `${(Math.abs(res.dev.mean) * 100).toFixed(1)}% (± ${(res.dev.ci * 100).toFixed(1)})`;
    let s = better ? `Predicts ${what} better than champion averages: error down ${size} on practice games.`
      : worse ? `Predicts ${what} worse than champion averages: error up ${size}.`
        : `No measurable difference from champion averages for ${what}.`;
    if (res.select === "new-best") s += " Confirmed on the held-back selection games: the new best.";
    else if (res.select === "no-change") s += " Not better on the held-back selection games.";
    return s;
  }
  if (res.kind === "diagnose" && res.bias) return `Check of where the model is off for ${what}: overall bias ${signed(res.bias.mean, 3)} standard deviations.`;
  if (res.kind === "screen") return `Screened ${res.features} candidate inputs for ${what}: ${res.clear} clear of noise.`;
  if (res.kind === "preds") return `Wrote ${num(+res.rows)} predictions for comparison.`;
  return i.last;
}

// docs/learned.md by category: markdown list items, newest first as written
function learnedByCat(md) {
  const out = {};
  let cat = null, item = null;
  const flush = () => { if (item && cat) (out[cat] = out[cat] || []).push(item); item = null; };
  for (const l of (md || "").replace(/\r/g, "").split("\n")) {
    const h = l.match(/^##\s+(.*)/);
    if (h) { flush(); cat = CAT_OF_HEADING[h[1].trim().toLowerCase()] || null; continue; }
    if (/^\s*-\s+/.test(l)) { flush(); item = l.replace(/^\s*-\s+/, ""); continue; }
    if (item && /^\s{2,}\S/.test(l)) item += " " + l.trim();
    else flush();
  }
  flush();
  return out;
}

// short: the finding's first sentence only (no evidence or use), for the All view
function learnedList(parent, items, limit, short) {
  let shown = (items || []).filter(t => !(short && /^~~/.test(t))).slice(0, limit || Infinity);
  if (short) shown = shown.map(t => t.split(/\. (?=Evidence|Sure|Site|Use|Models)/)[0].replace(/\.$/, "") + ".");
  if (!shown.length) { parent.append(el("p", { class: "muted" }, "Nothing final yet.")); return; }
  const md = markdown(shown.map(t => "- " + t).join("\n"));
  md.classList.add("learned");
  parent.append(md);
}

// Estimates with 95% intervals: a dot and whiskers per row, a line at zero.
// rows: [{label, value, ci, color?}]; o.fmt for values, o.left / o.right label the ends
function intervalChart(parent, o) {
  const fig = el("figure", { class: "chart ichart" }, el("div", { class: "chart-head" }, el("h3", {}, o.title)));
  const box = el("div", { class: "plot" });
  fig.append(box);
  if (o.caption) fig.append(el("figcaption", {}, o.caption));
  parent.append(fig);
  const fmt = o.fmt || (v => (+v.toPrecision(3)).toString());
  const draw = () => {
    box.replaceChildren();
    const W = Math.max(box.clientWidth, 240), rowH = 22, T = o.left || o.right ? 18 : 4, B = 22;
    const labelW = Math.min(W * 0.4, 230), L = labelW + 8, R = 64;
    const H = T + B + rowH * o.rows.length;
    const ends = o.rows.filter(r => !r.gap).flatMap(r => [r.value - (r.ci || 0), r.value + (r.ci || 0)]);
    let lo = Math.min(0, ...ends), hi = Math.max(0, ...ends);
    const st = niceStep(hi - lo || 1, Math.max(2, Math.floor((W - L - R) / 70)));
    lo = Math.floor(lo / st) * st; hi = Math.ceil(hi / st) * st;
    if (hi === lo) hi = lo + st;
    const px = v => L + (v - lo) / (hi - lo) * (W - L - R);
    const s = svg("svg", { viewBox: `0 0 ${W} ${H}`, width: W, height: H, role: "img", "aria-label": o.title });
    for (let v = lo; v <= hi + st * 1e-9; v += st) {
      s.append(svg("line", { class: Math.abs(v) < st * 1e-9 ? "base" : "grid", x1: px(v), x2: px(v), y1: T, y2: H - B }));
      const t = svg("text", { x: px(v), y: H - 6, "text-anchor": "middle" });
      t.textContent = fmt(+v.toPrecision(12));
      s.append(t);
    }
    const end = (text, x, anchor) => {
      const t = svg("text", { x, y: 12, "text-anchor": anchor, class: "end" });
      t.textContent = text;
      s.append(t);
    };
    if (o.left) end("← " + o.left, L, "start");
    if (o.right) end(o.right + " →", W - R, "end");
    const chars = Math.max(8, Math.floor(labelW / 6.4));
    o.rows.forEach((r, i) => {
      const y = T + rowH * i + rowH / 2;
      const label = svg("text", { x: 0, y: y + 4, class: "label" });
      label.textContent = r.label.length > chars ? r.label.slice(0, chars - 1) + "…" : r.label;
      const full = svg("title");
      full.textContent = `${r.label}: ${fmt(r.value)}${r.ci ? " ± " + fmt(r.ci) : ""}${r.n ? `, ${num(r.n)} rows` : ""}`;
      label.append(full);
      s.append(label);
      if (r.gap) return;
      const color = r.color || (r.ci && (r.value - r.ci > 0 || r.value + r.ci < 0) ? PALETTE[0] : "#5b6478");
      if (r.ci) s.append(svg("line", { class: "whisker", x1: px(r.value - r.ci), x2: px(r.value + r.ci), y1: y, y2: y, stroke: color }));
      s.append(svg("circle", { cx: px(r.value), cy: y, r: 4, fill: color }));
      const v = svg("text", { x: W, y: y + 4, "text-anchor": "end" });
      v.textContent = fmt(r.value);
      s.append(v);
    });
    box.append(s);
  };
  let w = 0;
  new ResizeObserver(() => { if (box.clientWidth !== w) { w = box.clientWidth; draw(); } }).observe(box);
  return fig;
}

// ---------- models: win (draft) ----------

// The eval report's tables, read into plain findings
function winReadings() {
  const R = reportTables(D.eval_report);
  const full = (R["Full draft, held-out games"] || [])[0];
  if (!full) return null;
  const name = full.head[0], vs = full.head[full.head.length - 1];
  const rows = full.rows.map(r => ({
    label: r[name], ll: numIn(r["log loss"]), acc: numIn(r.accuracy) / 100, auc: numIn(r.AUC), d: pmIn(r[vs]),
  }));
  const games = numIn(name.match(/\(([\d,]+) games\)/)?.[1]?.replace(/,/g, ""));
  const find = re => rows.find(r => re.test(r.label));
  const base = find(/base only/), current = find(/^current/);
  const real = rows.filter(r => !/coin|blue side/.test(r.label));
  const best = real.reduce((a, r) => r.ll < a.ll ? r : a, real[0]);
  const out = { rows, games, base, current, best, lines: [] };
  const L = out.lines;
  if (best) {
    const share = Math.max(0, (LL_COIN - best.ll) / (LL_COIN - LL_PUBLISHED));
    L.push(`From the draft alone the best model calls the winner of ${num(games)} new EUW games right ${pct(best.acc)} of the time (a coin flip: 50%). Published draft models trained on millions of games reach about 55 to 57%; by log loss we are ${Math.round(100 * share)}% of the way there.`);
  }
  if (base && current && base.d) {
    const b = base.d;
    L.push(Math.abs(b.mean) <= b.ci
      ? `The model the site and app use is no better than each champion's own win rate (difference ${pmText(b)}, inside noise): its matchup and duo terms add nothing measurable yet.`
      : b.mean < 0 ? `Champion win rates alone beat the model the site uses (${pmText(b)}): its pair terms add noise.`
        : `The model the site uses beats champion win rates alone (${pmText({ mean: -b.mean, ci: b.ci })}).`);
  }
  const winners = rows.filter(r => r.d && r.d.mean + r.d.ci < 0 && !/coin|blue side|base only/.test(r.label));
  if (winners.length) {
    const tuning = (D.eval_report || "").match(/Term weights[^:]*:\s*([^\n]+)/);
    const w = tuning ? Object.fromEntries([...tuning[1].matchAll(/(\w+) (-?[\d.]+)/g)].map(m => [m[1], +m[2]])) : {};
    let why = "";
    if (w.lane > 1.3) why += ` The tuning weighs lane matchups ${w.lane.toFixed(1)} times the default: lane matchups carry signal the shipped model shrinks away.`;
    if (w.duo != null && w.duo < 0.85) why += ` Duo terms are shrunk to ${w.duo.toFixed(2)}: mostly noise.`;
    L.push(`Beats the shipped model beyond noise: ${winners.map(r => `${r.label} (${pmText(r.d)})`).join(", ")}. The eval runs several times a day, so check it holds run after run (chart below).${why}`);
  }
  const pick = ((R["Pick metric"] || [])[0] || { rows: [] }).rows.find(r => /^current/.test(r.model));
  if (pick) {
    const col = Object.keys(pick).find(k => /top 10%/.test(k));
    const m = String(pick[col] || "").match(/([\d.]+)% of (\d+)/);
    if (m) {
      const p = +m[1] / 100, n = +m[2], z = (p - 0.5) / Math.sqrt(0.25 / n);
      L.push(z >= 3
        ? `Picks the shipped model ranks in its top 10% for their slot won ${pct(p)} of ${num(n)} games: a small but real edge of ${((p - 0.5) * 100).toFixed(1)} points (about ${z.toFixed(0)} standard errors; fewer in truth, as picks in one team share a result).`
        : `Picks the shipped model ranks in its top 10% won ${pct(p)} of ${num(n)} games: not yet distinguishable from 50%.`);
    }
  }
  const cal = (R["Full draft, held-out games"] || []).find(t => t.head[0] === "decile");
  if (cal) {
    const c = cal.rows.map(r => ({ p: numIn(r["mean predicted"]), y: numIn(r["blue won"]), n: numIn(r.games) }));
    const miss = Math.max(...c.map(r => Math.abs(r.p - r.y)));
    const se = 100 * Math.sqrt(0.25 / (c[0].n || 1));
    L.push(`Its percentages can be read at face value: predictions run from ${c[0].p}% to ${c[c.length - 1].p}% and each tenth of games landed within ${miss.toFixed(1)} points of its prediction (noise alone is about ±${(2 * se).toFixed(1)}).`);
  }
  const lc = learningCurve(R);
  if (lc && lc.perDoubling > 0) {
    const need = (lc.last - LL_PUBLISHED) / lc.perDoubling;
    const target = lc.n * Math.pow(2, need);
    const perDay = growthPerDay("matches");
    L.push(`More games help slowly: each doubling of games improves champion win rates by ${lc.perDoubling.toFixed(4)} log loss. At that pace reaching published accuracy takes about ${need.toFixed(0)} more doublings, ~${num(target)} games` + (perDay > 0 ? ` (~${num((target - lc.n) / perDay)} days of crawling at today's rate, while patches change every two weeks)` : "") + ". Gains have to come from better inputs too, not volume alone.");
  }
  const exp = ((R["Player experience"] || [])[0] || { rows: [] }).rows.find(r => r.source === "history" && /user/.test(r.players));
  if (exp) {
    const d = pmIn(exp.difference), bins = String(exp["effect per bin (pp)"] || "").split(/\s+/).map(Number).filter(isFinite);
    if (d && Math.abs(d.mean) <= d.ci) {
      L.push(`Knowing how many games the player has on the champion doesn't improve the prediction yet (${pmText(d)}).` +
        (bins.length && bins.every(b => b > 0) ? " Every experience band shows a positive effect against unknown players, which fits selection (crawled players come from the current ladder, where winners sit) better than skill." : ""));
    }
  }
  const gold = ((R["Lane gold at 14 minutes"] || [])[0] || { rows: [] }).rows;
  const g = gold.find(r => /lane gold \(stacked\)/.test(r[Object.keys(r)[0]])), eb = gold.find(r => /empirical/.test(r[Object.keys(r)[0]]));
  if (g && eb) L.push(`Adding typical lane gold at 14 min (from timelines) to the draft: accuracy ${g.accuracy} vs ${eb.accuracy}, log loss ${g["log loss"]} vs ${eb["log loss"]}.`);
  return out;
}

// Learning curve on fixed test games: log loss by train size, slope per doubling over
// the largest four sizes
function learningCurve(R) {
  const t = (R["Learning curve"] || [])[0];
  if (!t || t.rows.length < 3) return null;
  const rows = t.rows.map(r => ({ n: numIn(r["train games"]), r }));
  const pts = rows.slice(-4).map(x => [Math.log2(x.n), numIn(x.r["base only"])]);
  return { t, rows, perDoubling: -slope(pts), last: pts[pts.length - 1][1], n: rows[rows.length - 1].n };
}

function winView(body) {
  const ev = tsv(D.eval);
  const W = winReadings();
  const running = L && L.running && L.running.eval;
  const head = actionButton("eval-run", running ? `Eval running (${span(nowS() - running)})` : "Run eval now", { disabled: !!running || !L, confirm: "Run meiolol eval now? About 10 minutes at low priority on the box." });
  const learnt = section(body, "What we learnt", "Final findings for predicting the winner (docs/learned.md).");
  learnedList(learnt, MODELS.learned.win);
  runFindings(learnt, "win");
  const sec = section(body, "Best model against the baseline", ev.length ? `Daily eval (docs/model.md), newest ${ev[ev.length - 1].date}: models built from older games, scored on the newest EUW games they never saw.` : "Daily eval (docs/model.md).", head);
  if (!W) { sec.append(el("p", { class: "muted" }, "No eval report yet.")); return; }
  sec.append(el("ul", { class: "readings" }, ...W.lines.map(t => el("li", {}, t))));
  const g = grid(sec);
  const cmp = W.rows.filter(r => r.d && r !== W.current);
  if (cmp.length) {
    intervalChart(g, {
      title: "Each model against the one the site uses", left: "better", right: "worse",
      fmt: v => (v > 0 ? "+" : "") + (+v.toFixed(4)).toString(),
      rows: cmp.map(r => ({ label: r.label, value: r.d.mean, ci: r.d.ci, color: r.d.mean + r.d.ci < 0 ? PALETTE[2] : r.d.mean - r.d.ci > 0 ? PALETTE[1] : null })),
      caption: `Log loss per game against the shipped model on the same ${num(W.games)} games, with 95% intervals. Green: better beyond noise.`,
    });
  }
  const lc = learningCurve(reportTables(D.eval_report));
  if (lc) {
    const cols = lc.t.head.filter(h => !/train games|AUC/.test(h));
    chart(g, {
      id: "learning-curve", title: "Does more data help? Same test games, more training games", type: "line", fit: true,
      x: lc.rows.map(x => Math.log2(x.n)), xFmt: v => num(Math.pow(2, v)) + " games",
      xTicks: (a, b, w) => lc.rows.filter((_, i) => i % Math.max(1, Math.ceil(lc.rows.length / Math.max(2, Math.floor(w / 70)))) === 0).map(x => [Math.log2(x.n), num(x.n)]),
      fmt: v => v == null ? "–" : v.toFixed(4),
      series: cols.map((c, i) => ({ name: c, color: PALETTE[i % PALETTE.length], values: lc.rows.map(x => numIn(x.r[c])) })),
      ref: { value: LL_COIN, label: "coin flip" },
      caption: "Log loss, lower is better. Each point doubles the training games; the test games stay the same, so this is the honest accuracy-by-data curve.",
    });
  }
  if (ev.length > 1) {
    const ex = ev.map((_, i) => i);
    const evFmt = i => ev[i] ? `${ev[i].date}, ${num(ev[i].games)} games` : "";
    const evTicks = (a, b, w) => {
      const every = Math.max(1, Math.ceil(ev.length / Math.max(2, Math.floor(w / 90))));
      return ev.map((r, i) => [i, num(r.games)]).filter((_, i) => i % every === 0);
    };
    const rel = k => ev.map(r => r["ll_" + k] == null || r.ll_base == null ? null : r["ll_" + k] - r.ll_base);
    chart(g, {
      x: ex, id: "eval-vs-base", title: "Run by run: each model against champion win rates", type: "line", fit: true, xFmt: evFmt, xTicks: evTicks,
      fmt: v => v == null ? "–" : (v > 0 ? "+" : "") + v.toFixed(4),
      series: [["current", "site's model"], ["eb", "shrunk priors"], ["joint", "joint ratings"], ["tunedw", "tuned + weights"]]
        .map(([k, name], i) => ({ name, color: PALETTE[i], values: rel(k) })).filter(s => s.values.some(v => v != null)),
      ref: { value: 0, label: "champion win rates" },
      caption: "Below the line beats champion win rates. Each run holds out a different, growing set of games, so raw scores across runs don't compare; differences on the same games do.",
    });
    const picks = ev.map(r => r.pick_top10_win ?? null);
    if (picks.some(v => v != null)) {
      chart(g, {
        x: ex, id: "eval-picks", title: "Win rate of the site model's top-10% picks", type: "line", fit: true, xFmt: evFmt, xTicks: evTicks,
        fmt: v => v == null ? "–" : pct(v), series: [{ name: "top-10% picks", color: PALETTE[2], values: picks }],
        ref: { value: 0.5, label: "50%" },
      });
    }
  }
  const d = el("details", {}, el("summary", {}, "Full eval report (for model work)"));
  if (D.eval_report) d.append(el("div", { class: "report" }, markdown(D.eval_report)));
  sec.append(d);
  const r = el("details", {}, el("summary", {}, `Every eval run (${ev.length})`));
  table(r, "eval-runs", [
    { key: "date", label: "Date" }, { key: "games", label: "Games", num: true }, { key: "test", label: "Held out", num: true },
    { key: "ll_base", label: "Win rates", num: true, fmt: v => v == null ? "–" : v.toFixed(4) },
    { key: "ll_current", label: "Site model", num: true, fmt: v => v == null ? "–" : v.toFixed(4) },
    { key: "ll_eb", label: "Shrunk", num: true, fmt: v => v == null ? "–" : v.toFixed(4) },
  ], ev.map((x, i) => ({ ...x, i })), { sort: { key: "i", dir: "desc" } });
  sec.append(r);
}

// ---------- models: early game ----------

// docs/model.md "Team effects on early outcomes": % of the outcome's variation each part
// of the draft explains beyond the parts above it
function teamEffects() {
  const R = reportTables(MODELS.modelMd);
  const key = Object.keys(R).find(k => /^Team effects on early outcomes/.test(k));
  const t = key && R[key].find(x => x.head[0] === "step");
  return t ? { title: key, t } : null;
}

function earlyView(body) {
  const learnt = section(body, "What we learnt", "Final findings on the first 15 minutes: gold, CS, deaths, first item (docs/learned.md).");
  learnedList(learnt, MODELS.learned.early);
  runFindings(learnt, "early");
  const sec = section(body, "Best model against the baseline", "How much of each early-game number the draft explains beyond champion averages.");
  const te = teamEffects();
  if (te) {
    const outs = te.t.head.slice(1);
    if (!outs.includes(ui.outcome)) ui.outcome = outs.includes("lanediff14") ? "lanediff14" : outs[0];
    const pick = el("nav", { class: "cats", "aria-label": "Outcome" });
    for (const o of outs) pick.append(el("button", { type: "button", "aria-pressed": String(o === ui.outcome), onclick: () => { ui.outcome = o; store("outcome", o); render(true); } }, (OUTCOMES[o] || [o])[0]));
    sec.append(pick);
    const rows = te.t.rows.filter(r => !/^total/.test(r.step)).map(r => ({ label: r.step.replace(/^\+ /, ""), ...(pmIn(r[ui.outcome]) || { mean: 0, ci: 0 }) }));
    const total = te.t.rows.find(r => /^total/.test(r.step));
    const tot = total && pmIn(total[ui.outcome]);
    const top = rows.slice().sort((a, b) => b.mean - a.mean)[0];
    const name = (OUTCOMES[ui.outcome] || [ui.outcome])[0].toLowerCase();
    const lines = [];
    if (tot) lines.push(`Who is in the game explains ${tot.mean.toFixed(1)}% (± ${tot.ci.toFixed(1)}) of the differences in ${name} beyond each champion's average. The rest is the game itself: players, decisions, luck.`);
    if (top) lines.push(`The biggest single part: ${top.label} (${top.mean.toFixed(1)}%).`);
    const nothing = rows.filter(r => Math.abs(r.mean) <= r.ci).map(r => r.label);
    if (nothing.length) lines.push(`Adds nothing measurable: ${nothing.join("; ")}.`);
    sec.append(el("ul", { class: "readings" }, ...lines.map(t => el("li", {}, t))));
    const g = grid(sec);
    intervalChart(g, {
      title: `What each part of the draft adds to ${name}`, right: "explains more", fmt: v => (+v.toFixed(2)).toString() + "%",
      rows: rows.map(r => ({ label: r.label, value: r.mean, ci: r.ci })),
      caption: `% of the variation in ${name} explained, each part on top of the ones above it, 95% intervals (docs/model.md, "${te.title}"). Blue: clear of zero.`,
    });
    labBest(g, Object.keys(OUTCOMES).filter(k => CAT_OF_TARGET[k] === "early"));
  } else {
    sec.append(el("p", { class: "muted" }, MODELS.modelMd == null ? "Loading docs/model.md…" : "No team effects table in docs/model.md yet."));
    labBest(grid(sec), Object.keys(OUTCOMES).filter(k => CAT_OF_TARGET[k] === "early"));
  }
  runsBlock(body, MODELS.runs.filter(r => r.cat === "early"));
}

// The best lab run per target (practice games, `exp run`), as a dot chart
function labBest(parent, targets) {
  const best = {};
  for (const r of MODELS.runs) {
    // ci 0: a reference run scoring the baseline against itself
    if (!r.res || r.res.kind !== "run" || !r.res.dev || !r.res.dev.ci || !targets.includes(r.target)) continue;
    const b = best[r.target];
    if (!b || r.res.dev.mean < b.res.dev.mean) best[r.target] = r;
  }
  const rows = targets.filter(t => best[t]).map(t => {
    const b = best[t], rt = b.result;
    const own = rt && rt.removed_pct !== "" && isFinite(+rt.removed_pct);
    return { label: `${OUTCOMES[t][0]}: ${b.campaign || shortRun(b.run)}`, value: own ? +rt.removed_pct : -b.res.dev.mean * 100, ci: own ? +rt.removed_half : b.res.dev.ci * 100 };
  });
  if (!rows.length) return;
  intervalChart(parent, {
    title: "Best lab model so far, per outcome", right: "less error", fmt: v => (+v.toFixed(1)).toString() + "%",
    rows, caption: "Error removed against champion averages on the lab's practice games (not the final test), 95% intervals. Lab runs are listed below.",
  });
}

// ---------- models: lab campaigns ----------

function labView(body) {
  const sec = section(body, "Lab campaigns", "Each campaign is an agent improving one model inside the lab's rules (docs/lab-agent.md): ideas it tried, what held up.");
  if (!MODELS.campaigns.length) sec.append(el("p", { class: "muted" }, "No campaigns yet."));
  for (const c of MODELS.campaigns) {
    const card = el("div", { class: "card campaign" }, el("h3", {}, c.name));
    sec.append(card);
    const runs = MODELS.runs.filter(r => r.campaign === c.name);
    const newBest = runs.filter(r => r.res && r.res.select === "new-best");
    card.append(el("p", { class: "sub" }, `${runs.length} runs, ${newBest.length} confirmed improvement${newBest.length === 1 ? "" : "s"} on held-back games.`));
    if (c.hyp && c.hyp.length) {
      const ul = el("ul", { class: "hyps" });
      for (const h of c.hyp) {
        const st = (h.status || "").toLowerCase();
        ul.append(el("li", {}, el("span", { class: "pill " + (st === "confirmed" ? "good" : st === "rejected" || st === "parked" ? "warn" : "") }, h.status || "?"), " ", h.hypothesis || ""));
      }
      card.append(ul);
    }
    if (c.digest && c.digest.split("\n").filter(l => l.trim() && !/^#|^What worked/.test(l)).length) {
      const d = el("details", {}, el("summary", {}, "Digest"), markdown(c.digest));
      card.append(d);
    }
  }
  runsBlock(body, MODELS.runs.filter(r => r.lab));
}

// ---------- models: run findings ----------

// meiolol-lab's plain results per run: result.tsv (one row: category, removed_pct ±
// removed_half = % of the baseline's error removed, err_base and err_cand = typical miss in
// `unit`, effects = comma list of effect files), findings.tsv (campaign, finding,
// effect_file; may come after the run) and effect files: "# title | unit | what higher
// means", then label, effect, ci (95% half-width), n
async function loadFindings(runs) {
  for (const r of runs) {
    const key = r.run + "|" + r.state + "|" + r.ended + "|" + r.last;
    if (MODELS.findings.get(r.run)?.key === key) continue;
    const base = "training/runs/" + encodeURIComponent(r.run) + "/";
    // runs.tsv's findings column lists the files present; older pushes wrote just "1"
    const has = f => r.findings === "1" || r.findings.split(",").includes(f);
    const get = f => has(f) ? getText(base + f).catch(() => "") : "";
    const [res, fin] = await Promise.all([get("result.tsv"), get("findings.tsv")]);
    const result = tsvRaw(res)[0] || null;
    const findings = tsvRaw(fin).filter(f => f.finding);
    const names = new Set([...findings.map(f => f.effect_file), ...(result && result.effects ? result.effects.split(",") : [])]
      .map(x => (x || "").trim().split("/").pop()).filter(x => x && x !== "-"));
    const effects = {};
    for (const name of names) {
      const text = await getText(base + encodeURIComponent(name)).catch(() => null);
      if (!text) continue;
      const lines = text.split("\n");
      const meta = lines[0].startsWith("#") ? lines.shift().slice(1).split("|").map(x => x.trim()) : [];
      effects[name] = { title: meta[0] || name, unit: meta[1] || "", higher: meta[2] || "", rows: tsvRaw(lines.join("\n")).map(x => ({ label: x.label, value: +x.effect, ci: +x.ci || 0, n: +x.n || null })).filter(x => isFinite(x.value)) };
    }
    MODELS.findings.set(r.run, { key, result, findings, effects });
  }
}

function effectChart(parent, e) {
  if (!e || !e.rows.length) return;
  let rows = e.rows.slice().sort((a, b) => b.value - a.value);
  // Long lists: the ten largest and ten smallest
  if (rows.length > 20) rows = [...rows.slice(0, 10), { label: "…", value: 0, gap: true }, ...rows.slice(-10)];
  intervalChart(parent, {
    title: e.title, right: e.higher || null, fmt: v => (+v.toPrecision(3)).toString() + (e.unit && e.unit !== "-" ? " " + e.unit : ""), rows,
    caption: `95% intervals${e.rows.length > 20 ? `; the top and bottom 10 of ${e.rows.length}` : ""}. Blue: clear of zero.`,
  });
}

// Findings from runs in a category, newest first, each with its effect charts
function runFindings(parent, cat) {
  const out = MODELS.runs.filter(r => r.cat === cat && MODELS.findings.get(r.run)?.findings.length);
  if (!out.length) return;
  parent.append(el("h3", { class: "subhead" }, "From recent runs"));
  const ul = el("ul", { class: "readings" });
  parent.append(ul);
  const g = grid(parent);
  const shown = new Set();
  for (const r of out) {
    const f = MODELS.findings.get(r.run);
    for (const x of f.findings) {
      ul.append(el("li", {}, x.finding, el("span", { class: "sub" }, ` (${x.campaign || r.campaign || shortRun(r.run)}, ${uk(Date.parse(r.started) / 1000)})`)));
      const name = (x.effect_file || "").split("/").pop();
      if (name && name !== "-" && !shown.has(r.run + name)) { shown.add(r.run + name); effectChart(g, f.effects[name]); }
    }
  }
}

// ---------- models: draft tester ----------
//
// Admin only: a draft board of two teams, the model's win chance for the whole draft, and
// a picker per slot showing what each champion would change. The model comes from
// meiolol-lab's `draft --export` (meiolol-88), sent by deploy/lab-push.sh as
// training/draft-model.json with reference pairs in draft-ref.json, checked at load. Nothing
// here reaches the public site, which must not claim "this draft wins X%"

const DRAFT_ROLES = [["top", "Top"], ["jungle", "Jungle"], ["mid", "Mid"], ["bot", "Bot"], ["support", "Support"]];
const SIDES = [["blue", "Blue"], ["red", "Red"]];
const DRAFT = { model: undefined, ref: null, err: null, check: null, m: null };

function draftState() {
  const d = stored("draft2", null) || {};
  return { blue: d.blue || {}, red: d.red || {}, locks: d.locks || {}, fb: d.fb || {}, bans: d.bans || [], open: d.open || null, sort: d.sort || "played", rank: d.rank || "low" };
}
function saveDraft(d) { store("draft2", d); render(true); }

async function loadDraftModel() {
  try {
    DRAFT.model = await getJson("training/draft-model.json");
    DRAFT.m = draftModel(DRAFT.model);
    if (!DRAFT.m) throw new Error(`draft-model.json is format "${DRAFT.model.format}" version ${DRAFT.model.version}; this page reads meiolol-draft-model version 1`);
    DRAFT.ref = await getJson("training/draft-ref.json").catch(() => null);
    DRAFT.err = null;
    DRAFT.check = DRAFT.m && DRAFT.ref ? draftCheck(DRAFT.m, DRAFT.ref) : null;
  } catch (e) { DRAFT.model = null; DRAFT.m = null; DRAFT.err = e.message; }
  // The lane model is optional: without it the suggester shows only "Best for this draft"
  DRAFT.lane = null; DRAFT.laneErr = null; DRAFT.laneCheck = null;
  try {
    const L = await getJson("training/lane-model.json");
    DRAFT.lane = laneModel(L);
    if (!DRAFT.lane) throw new Error(`lane-model.json is format "${L.format}" version ${L.version}; this page reads meiolol-lane-model version 1`);
    const ref = await getJson("training/lane-ref.json").catch(() => null);
    DRAFT.laneCheck = ref ? laneCheck(DRAFT.lane, ref) : null;
  } catch (e) { if (!/^404/.test(e.message)) DRAFT.laneErr = e.message; }
  if (ui.tab === "models" && ui.cat === "draft") render(true);
}

// The exported model (docs/model.md "Draft model file"; Scorer in src/lab/draft.zig is the
// reference): champions, play share per role on the newest patch, blue's win chance with a
// 95% interval for a draft, and the candidates for a slot. A draft here is
// {blue: {role: id}, red: {role: id}}; an empty slot, or a champion with no term in the
// role, is average[role] with sd 0
function draftModel(M) {
  if (!M || M.format !== "meiolol-draft-model" || M.version !== 1) return null;
  const terms = new Map(M.model.terms.map(t => [t.champion + ":" + t.role, t]));
  const cells = new Map(M.cells.map(c => [c.champion + ":" + c.role, c]));
  const avg = M.average.map(a => ({ ...a, sd: 0 }));
  const { intercept, w, z } = M.model;
  const dot = (a, b) => { let x = 0; for (let i = 0; i < a.length; i++) x += a[i] * b[i]; return x; };
  const sig = x => 1 / (1 + Math.exp(-x));
  // teams[side][role]: champion id, 0 empty
  const score = teams => {
    const [B, R] = teams.map(t => t.map((id, r) => (id && terms.get(id + ":" + r)) || avg[r]));
    let logit = intercept, v = 0;
    for (let r = 0; r < 5; r++) {
      logit += B[r].b - R[r].b;
      v += B[r].sd ** 2 + R[r].sd ** 2;
    }
    if (M.has_pairs) {
      for (let i = 0; i < 5; i++) for (let j = 0; j < 5; j++) logit += w[i * 5 + j] * (dot(B[i].u, R[j].v) - dot(R[i].u, B[j].v));
      for (let a = 0; a < 5; a++) for (let b = a + 1; b < 5; b++) logit += z[a * 5 + b] * (dot(B[a].s, B[b].s) - dot(R[a].s, R[b].s));
    }
    const h = 1.96 * Math.sqrt(v);
    return { p: sig(logit), lo: sig(logit - h), hi: sig(logit + h) };
  };
  const teamsOf = d => SIDES.map(([side]) => DRAFT_ROLES.map(([role]) => +d[side][role] || 0));
  const roleIdx = Object.fromEntries(DRAFT_ROLES.map(([r], i) => [r, i]));
  const m = {
    M, score, teamsOf,
    champs: M.champions.slice().sort((a, b) => a.name.localeCompare(b.name)),
    rate: (id, role) => (cells.get(id + ":" + roleIdx[role]) || {}).patch_share || 0,
    games: (id, role) => (cells.get(id + ":" + roleIdx[role]) || {}).games || 0,
    win: d => score(teamsOf(d)),
    // Each slot's part of blue's logit, for tracing a number
    explain(teams) {
      const rows = [];
      teams.forEach((t, side) => t.forEach((id, r) => {
        const term = id && terms.get(id + ":" + r);
        const x = term || avg[r];
        rows.push({ side, role: r, champion: id || 0, average: !term, b: x.b, sd: x.sd, part: side === 0 ? x.b : -x.b });
      }));
      const lin = intercept + sumR(rows.map(x => x.part));
      const p = score(teams);
      return { intercept, rows, pairs: Math.log(p.p / (1 - p.p)) - lin, logit: Math.log(p.p / (1 - p.p)), p };
    },
    // A slot's candidates: games in the role >= min_games, not picked, not banned; win and
    // change for the side filling it, sorted by win then champion id (as draft-ref.json)
    slot(teams, bans, side, r, min = M.min_games) {
      const mine = x => side === 0 ? x : { p: 1 - x.p, lo: 1 - x.hi, hi: 1 - x.lo };
      const t = teams.map(x => x.slice());
      t[side][r] = 0;
      const empty = mine(score(t)).p;
      const out = new Set([...t.flat(), ...bans].filter(Boolean));
      const options = [];
      for (const c of M.cells) {
        if (c.role !== r || c.games < min || out.has(c.champion)) continue;
        t[side][r] = c.champion;
        const x = mine(score(t));
        options.push({ champion: c.champion, games: c.games, share: c.patch_share, win: x.p, lo: x.lo, hi: x.hi, change: x.p - empty });
      }
      options.sort((a, b) => b.win - a.win || a.champion - b.champion);
      const g = sumR(options.map(o => o.games));
      return { empty, average: g ? sumR(options.map(o => o.win * o.games)) / g : null, options };
    },
  };
  return m;
}

// The page's numbers against meiolol-lab's reference (draft-ref.json): whole drafts, and
// slot queries with their candidate lists
function draftCheck(m, ref) {
  const tol = ref.tolerance || 1e-9;
  let worst = 0, n = 0, bad = null;
  const cmp = (a, b, what) => { n++; const e = Math.abs(a - b); if (e > worst) { worst = e; if (e > tol) bad = what; } };
  for (const x of ref.drafts || []) {
    const s = m.score(x.teams);
    for (const k of ["p", "lo", "hi"]) cmp(s[k], x.blue[k], `${x.label}: ${k}`);
  }
  for (const q of ref.slots || []) {
    const s = m.slot(q.teams, q.bans || [], q.side, q.role, q.min_games);
    cmp(s.empty, q.empty, `${q.label}: empty`);
    cmp(s.average, q.average, `${q.label}: average`);
    if (s.options.length !== q.options.length) { bad = `${q.label}: ${s.options.length} candidates, meiolol-lab has ${q.options.length}`; worst = Infinity; continue; }
    q.options.forEach((o, i) => {
      const mine = s.options[i];
      if (mine.champion !== o.champion) { bad = `${q.label}: order differs at ${i + 1}`; worst = Infinity; return; }
      for (const k of ["win", "lo", "hi", "change"]) cmp(mine[k], o[k], `${q.label}: ${k}`);
    });
  }
  if (!n) return null;
  return bad ? { ok: false, text: `Differs from meiolol-lab's reference (${bad}; largest gap ${isFinite(worst) ? worst.toExponential(1) : "order"}): don't trust these numbers.` }
    : { ok: true, text: `Matches meiolol-lab on ${(ref.drafts || []).length} reference drafts and ${(ref.slots || []).length} slot lists (largest gap ${worst.toExponential(1)}).` };
}

// The early-game lane model (docs/model.md "Lane model file"; Scorer in src/lab/lane.zig is
// the reference): expected gold14, lanediff14, cs10 and deaths15 for champion x in role r
// into lane opponent y, each with a 95% range for the average, and the champion's and the
// matchup's games. Every outcome array follows L.outcomes
function laneModel(L) {
  if (!L || L.format !== "meiolol-lane-model" || L.version !== 1) return null;
  const champ = new Map(L.champ.map(t => [t.champion + ":" + t.role, t]));
  const enemy = new Map(L.enemy.map(t => [t.champion + ":" + t.role, t]));
  const col = Object.fromEntries(L.pair_columns.map((c, i) => [c, i]));
  const pairs = new Map(L.pairs.map(p => [p[0] + ":" + p[1] + ":" + p[2], p]));
  const outs = L.outcomes.map((o, i) => i);
  // vc: the champion term's variance, shared by all its matchups; vr: the rest's
  const value = (x, y, r) => {
    const c = champ.get(x + ":" + r), e = enemy.get(y + ":" + r), p = pairs.get(x + ":" + y + ":" + r);
    const pt = p && { b: L.outcomes.map(o => p[col["b_" + o]]), sd: L.outcomes.map(o => p[col["sd_" + o]]) };
    const v = outs.map(o => L.intercept[o][r] + L.others[o][r] + (c ? c.b[o] : 0) + (e ? e.b[o] : 0) + (pt ? pt.b[o] : 0));
    const vc = outs.map(o => c ? c.sd[o] ** 2 : 0);
    const vr = outs.map(o => (e ? e.sd[o] ** 2 : 0) + (pt ? pt.sd[o] ** 2 : 0));
    const h = outs.map(o => 1.96 * Math.sqrt(vc[o] + vr[o]));
    return { value: v, lo: v.map((x, o) => x - h[o]), hi: v.map((x, o) => x + h[o]), vc, vr, champ_games: c ? c.n : 0, pair_games: p ? p[col.n] : 0 };
  };
  // Into a field of opponents [{id, w}] (w summing to 1): the weighted average, its range
  // (opponent and pair terms average down, the champion's own term doesn't) and each matchup
  const blind = (x, r, field) => {
    const each = field.map(f => ({ ...f, ...value(x, f.id, r) }));
    const v = outs.map(o => sumR(each.map(f => f.w * f.value[o])));
    const h = outs.map(o => 1.96 * Math.sqrt((each[0] ? each[0].vc[o] : 0) + sumR(each.map(f => f.w * f.w * f.vr[o]))));
    return { value: v, lo: v.map((x, o) => x - h[o]), hi: v.map((x, o) => x + h[o]), each, champ_games: (champ.get(x + ":" + r) || {}).n || 0 };
  };
  return { L, value, blind, at: Object.fromEntries(L.outcomes.map((o, i) => [o, i])) };
}

function laneCheck(lm, ref) {
  let worst = 0, n = 0, bad = null;
  for (const x of ref.refs || []) {
    const s = lm.value(x.champion, x.enemy, x.role);
    for (const k of ["value", "lo", "hi"]) x[k].forEach((v, o) => { n++; const e = Math.abs(s[k][o] - v); if (e > worst) worst = e; if (e > 0.01) bad = `${x.label}, role ${x.role}: ${k} ${lm.L.outcomes[o]}`; });
    if (s.champ_games !== x.champ_games || s.pair_games !== x.pair_games) bad = `${x.label}, role ${x.role}: games`;
  }
  if (!n) return null;
  return bad ? { ok: false, text: `Lane model differs from meiolol-lab's reference (${bad}; largest gap ${worst.toFixed(3)}): don't trust the lane suggestions.` }
    : { ok: true, text: `Lane model matches meiolol-lab on ${ref.refs.length} reference matchups (largest gap ${worst.toExponential(1)}).` };
}

// Search key: letters and digits only, so "kaisa" finds Kai'Sa and "nunu" Nunu & Willump
const champKey = s => (s || "").toLowerCase().normalize("NFD").replace(/[^a-z0-9]/g, "");
const takenIn = d => new Set([...Object.values(d.blue), ...Object.values(d.red), ...d.bans].map(String));

// Fill unlocked slots (only empty ones unless `all`) by play rate in the role
function randomFill(m, d, all) {
  const taken = takenIn(d);
  for (const [side] of SIDES) for (const [role] of DRAFT_ROLES) {
    const key = side + "." + role;
    if (d.locks[key] || (!all && d[side][role] != null)) continue;
    if (d[side][role] != null) taken.delete(String(d[side][role]));
    const pool = m.champs.filter(c => !taken.has(String(c.id)) && m.rate(c.id, role) > 0 && m.games(c.id, role) >= m.M.min_games);
    let x = Math.random() * sumR(pool.map(c => m.rate(c.id, role)));
    const pick = pool.find(c => (x -= m.rate(c.id, role)) <= 0) || pool[pool.length - 1];
    if (!pick) continue;
    d[side][role] = pick.id;
    taken.add(String(pick.id));
  }
}

function draftView(body) {
  if (DRAFT.model === undefined) { loadDraftModel(); body.append(el("p", { class: "muted" }, "Loading the draft model…")); return; }
  const m = DRAFT.m, M = DRAFT.model || {}, meta = M.meta || {};
  const sec = section(body, "Draft tester", "Build two teams, swap champions in, see what the model thinks. Admin only: the public site never shows a draft's win chance.",
    el("button", { type: "button", class: "ghost", onclick: () => { DRAFT.model = undefined; render(true); } }, "Reload model"));
  if (!m) {
    if (DRAFT.err && !/^404/.test(DRAFT.err)) sec.append(el("div", { class: "health bad" }, el("b", {}, "The draft model didn't load: "), DRAFT.err));
    else sec.append(el("p", { class: "muted" }, "No draft model yet: meiolol-lab's `draft --export` writes it and deploy/lab-push.sh sends it."));
    return;
  }
  if (DRAFT.tags === undefined) loadTags();
  const d = draftState();
  const name = id => (m.champs.find(c => String(c.id) === String(id)) || { name: "#" + id }).name;
  const dev = meta.dev || {};
  sec.append(el("p", { class: "sub", title: dev.what || "" }, [meta.name, meta.training_games != null ? `${num(meta.training_games)} training games to ${meta.newest_game}` : null, meta.patch ? `play rates from patch ${meta.patch}` : null, dev.accuracy != null ? `right ${pct(dev.accuracy)} of ${num(dev.games)} practice games (coin flip 50%)` : null].filter(Boolean).join(" · ")));
  if (DRAFT.check) sec.append(el("div", { class: "health " + (DRAFT.check.ok ? "good" : "bad") }, el("b", {}, DRAFT.check.ok ? "✓ " : "⚠ "), DRAFT.check.text));
  if (DRAFT.laneErr) sec.append(el("div", { class: "health bad" }, el("b", {}, "The lane model didn't load: "), DRAFT.laneErr));
  if (DRAFT.laneCheck) sec.append(el("div", { class: "health " + (DRAFT.laneCheck.ok ? "good" : "bad") }, el("b", {}, DRAFT.laneCheck.ok ? "✓ " : "⚠ "), DRAFT.laneCheck.text));
  if (DRAFT.lane) {
    const lm = DRAFT.lane.L.meta, dev = (lm.dev || []).find(x => x.outcome === "lanediff14");
    sec.append(el("p", { class: "sub" }, `Lane suggestions: early-game model ${lm.name !== "candidate" ? lm.name + " " : ""}on ${num(lm.training_games)} games to ${lm.newest_game}.` +
      (dev ? ` It predicts the gold lead at 14 ${dev.removed_pct.toFixed(0)}% better than champion averages alone, so matchups nudge the numbers rather than decide them.` : "")));
  }
  if (!M.has_pairs) sec.append(el("div", { class: "health warn" }, el("b", {}, "Caveat: "), "the model has no counter or synergy terms yet. It ranks by champion strength in the role; other picks shift the numbers, not the order."));

  const w = m.win(d);
  sec.append(el("div", { class: "winbar", role: "img", "aria-label": `Blue ${pct(w.p)}, range ${pct(w.lo)} to ${pct(w.hi)}` },
    el("div", { class: "labels" }, el("b", { class: "blue" }, `Blue ${pct(w.p)}`), el("span", { class: "sub" }, `range ${pct(w.lo)} to ${pct(w.hi)}`), el("b", { class: "red" }, `Red ${pct(1 - w.p)}`)),
    el("div", { class: "track" }, el("span", { class: "range", style: `left:${100 * w.lo}%;width:${100 * (w.hi - w.lo)}%` }), el("span", { class: "mark", style: `left:${100 * w.p}%` }), el("span", { class: "half" }))));

  sec.append(fillMenu(m, d));
  const board = el("div", { class: "draft" });
  sec.append(board);
  for (const [side, title] of SIDES) {
    const col = el("div", { class: "card team " + side }, el("h3", {}, title));
    for (const [role, label] of DRAFT_ROLES) {
      const key = side + "." + role, id = d[side][role], open = d.open === key, locked = !!d.locks[key];
      col.append(el("div", { class: "slotrow" + (open ? " open" : "") },
        el("span", { class: "role" }, label),
        el("button", { type: "button", class: "slot", "aria-expanded": String(open), title: d.fb[key] ? `Fallback: ${d.fb[key]}` : null, onclick: () => { d.open = open ? null : key; saveDraft(d); } },
          id != null ? name(id) : el("span", { class: "muted" }, "empty"), d.fb[key] && id != null ? el("span", { class: "fb" }, ` (${d.fb[key]})`) : null),
        el("button", { type: "button", class: "ghost icon", "aria-pressed": String(locked), title: locked ? "Unlock" : "Lock (random keeps it)", onclick: () => { d.locks[key] = !locked; saveDraft(d); } }, locked ? "locked" : "lock"),
        id != null ? el("button", { type: "button", class: "ghost icon", title: "Clear", "aria-label": "Clear " + name(id), onclick: () => { delete d[side][role]; delete d.fb[key]; saveDraft(d); } }, "×") : null));
      if (open) col.append(slotPicker(m, d, side, role));
    }
    board.append(col);
  }
  const bans = el("div", { class: "card bans" }, el("h3", {}, `Bans (${d.bans.length}), left out of random games and pickers`));
  const chips = el("div", { class: "chips" });
  for (const b of d.bans) chips.append(el("button", { type: "button", title: "Remove ban", onclick: () => { d.bans = d.bans.filter(x => x !== b); saveDraft(d); } }, name(b), " ×"));
  bans.append(chips);
  if (d.bans.length < 10) {
    const input = el("input", { type: "search", class: "bansearch", placeholder: "Ban a champion: type, Enter", "aria-label": "Ban a champion", autocomplete: "off", spellcheck: "false" });
    input.addEventListener("keydown", ev => {
      if (ev.key !== "Enter") return;
      const q = champKey(input.value), taken = takenIn(d);
      const c = m.champs.find(c => !taken.has(String(c.id)) && champKey(c.name).startsWith(q)) || m.champs.find(c => !taken.has(String(c.id)) && champKey(c.name).includes(q));
      if (q && c) { d.bans.push(c.id); saveDraft(d); }
    });
    bans.append(input);
  }
  sec.append(bans);
  sec.append(draftDebug(m, d, name));
}

// Data Dragon's tags (Tank, Assassin, ...) and attack/magic ratings per champion id, cached
// per version; null when it can't be reached (the fills that need them are hidden)
async function loadTags() {
  DRAFT.tags = "loading";
  try {
    const [v] = await (await fetch("https://ddragon.leagueoflegends.com/api/versions.json")).json();
    let data = null;
    try { const c = JSON.parse(localStorage.getItem("admin-ddragon") || "null"); if (c && c.v === v) data = c.data; } catch (e) { /* storage blocked */ }
    if (!data) {
      const j = await (await fetch(`https://ddragon.leagueoflegends.com/cdn/${v}/data/en_US/champion.json`)).json();
      data = Object.values(j.data).map(c => [+c.key, c.tags, c.info.attack, c.info.magic]);
      try { localStorage.setItem("admin-ddragon", JSON.stringify({ v, data })); } catch (e) { /* storage blocked */ }
    }
    DRAFT.tags = new Map(data.map(([id, tags, attack, magic]) => [id, { tags, attack, magic }]));
  } catch (e) { DRAFT.tags = null; }
  if (ui.tab === "models" && ui.cat === "draft") render(true);
}

// Fill unlocked slots of `sides` with pick(role, taken) -> id, or {id, fb} when the pick
// fell back from what the fill asked for (shown on the slot)
function fillSlots(d, sides, pick) {
  const taken = takenIn(d);
  for (const side of sides) for (const [role] of DRAFT_ROLES) {
    const key = side + "." + role;
    if (d.locks[key]) continue;
    if (d[side][role] != null) taken.delete(String(d[side][role]));
    delete d.fb[key];
    const x = pick(role, taken);
    const id = x != null && typeof x === "object" ? x.id : x;
    if (id == null) { delete d[side][role]; continue; }
    d[side][role] = id;
    taken.add(String(id));
    if (x.fb) d.fb[key] = x.fb;
  }
}

function fillMenu(m, d) {
  const legal = role => m.champs.filter(c => m.games(c.id, role) >= m.M.min_games && m.rate(c.id, role) > 0);
  const weighted = (list, role, taken) => {
    const pool = list.filter(c => !taken.has(String(c.id)));
    let x = Math.random() * sumR(pool.map(c => m.rate(c.id, role)));
    return (pool.find(c => (x -= m.rate(c.id, role)) <= 0) || pool[pool.length - 1] || {}).id;
  };
  const top = (role, n) => legal(role).sort((a, b) => m.rate(b.id, role) - m.rate(a.id, role)).slice(0, n);
  // Tag fills try each [test, note] in turn, so a role whose pool runs out takes the closest
  // class, then any role-legal champion, marked with the note
  const tagged = (...steps) => (role, taken) => {
    for (const [f, fb] of [...steps, [null, "any champion"]]) {
      const pool = f ? legal(role).filter(c => DRAFT.tags.has(c.id) && f(DRAFT.tags.get(c.id))) : legal(role);
      const id = weighted(pool, role, taken);
      if (id != null) return fb ? { id, fb } : id;
    }
  };
  const has = tag => t => t.tags.includes(tag);
  const fighter = [has("Fighter"), "fighter"];
  const go = f => () => { f(); d.open = null; saveDraft(d); };
  const both = ["blue", "red"];
  const btn = (label, f, title) => el("button", { type: "button", class: "action", title, onclick: go(f) }, label);
  const groups = [
    ["Realistic", [
      btn("Random realistic", () => fillSlots(d, both, (r, t) => weighted(legal(r), r, t)), "Each slot drawn by its play share in the role on the newest patch"),
      btn("Random generic", () => fillSlots(d, both, (r, t) => weighted(top(r, 15), r, t)), "Each slot from the role's 15 most played"),
      btn("Swap sides", () => {
        [d.blue, d.red] = [d.red, d.blue];
        const flip = o => Object.fromEntries(Object.entries(o).map(([k, v]) => [k.replace(/^(blue|red)/, x => x === "blue" ? "red" : "blue"), v]));
        d.locks = flip(d.locks);
        d.fb = flip(d.fb);
      }, "Same champions, sides swapped: a symmetry check"),
    ]],
  ];
  const tags = DRAFT.tags instanceof Map;
  if (tags) {
    const ad = tagged([t => t.attack > t.magic], [t => t.attack === t.magic, "mixed damage"]);
    const ap = tagged([t => t.magic > t.attack], [t => t.attack === t.magic, "mixed damage"]);
    groups.push(["Team styles", [
      btn("Blue full AD", () => fillSlots(d, ["blue"], ad)), btn("Red full AD", () => fillSlots(d, ["red"], ad)),
      btn("Blue full AP", () => fillSlots(d, ["blue"], ap)), btn("Red full AP", () => fillSlots(d, ["red"], ap)),
    ]]);
  }
  const debug = [];
  if (tags) {
    debug.push(btn("All tanks", () => fillSlots(d, both, tagged([has("Tank")], fighter))),
      btn("All assassins", () => fillSlots(d, both, tagged([has("Assassin")], fighter))));
  }
  debug.push(
    btn("Mirror", () => fillSlots(d, both, r => (top(r, 1)[0] || {}).id), "The most played champion in every role on both sides: only the intercept (blue side) should remain, about 50%"),
    btn("Empty board", () => { d.blue = {}; d.red = {}; d.locks = {}; d.fb = {}; }, "Every slot the role average"));
  groups.push(["Debug", debug]);
  const menu = el("details", { class: "fillmenu" }, el("summary", {}, "Fill…"));
  for (const [title, buttons] of groups) menu.append(el("div", { class: "fillgroup" }, el("span", { class: "sub" }, title), el("div", { class: "actions" }, ...buttons)));
  if (!tags) menu.append(el("p", { class: "sub" }, DRAFT.tags === null ? "AD, AP, tank and assassin fills need Data Dragon, which didn't answer." : "Loading Data Dragon tags…"));
  return el("div", { class: "fillbar" },
    el("button", { type: "button", class: "action", onclick: go(() => fillSlots(d, both, (r, t) => weighted(legal(r), r, t))) }, "Random game"),
    el("button", { type: "button", class: "action", onclick: go(() => { const taken = takenIn(d); for (const side of both) for (const [r] of DRAFT_ROLES) if (d[side][r] == null && !d.locks[side + "." + r]) { const id = weighted(legal(r), r, taken); if (id != null) { d[side][r] = id; delete d.fb[side + "." + r]; taken.add(String(id)); } } }) }, "Fill empty"),
    menu);
}

// Blue's logit, slot by slot, so a number can be traced
function draftDebug(m, d, name) {
  const x = m.explain(m.teamsOf(d));
  const box = el("details", { class: "debug" }, el("summary", {}, "Debug: how the win chance is built"));
  const roles = DRAFT_ROLES.map(r => r[1]);
  table(box, "draft-debug", [
    { key: "side", label: "Side" }, { key: "role", label: "Role" }, { key: "champ", label: "Champion" },
    { key: "b", label: "Rating", num: true, fmt: v => v.toFixed(4) }, { key: "sd", label: "± sd", num: true, fmt: v => v.toFixed(4) },
    { key: "part", label: "Part of blue's logit", num: true, fmt: v => (v >= 0 ? "+" : "") + v.toFixed(4) },
  ], x.rows.map(r => ({ side: r.side ? "Red" : "Blue", role: roles[r.role], champ: r.champion ? name(r.champion) + (r.average ? " (no term: role average)" : "") : "empty (role average)", b: r.b, sd: r.sd, part: r.part })));
  const swapped = m.score(m.teamsOf(d).slice().reverse()).p;
  box.append(el("ul", { class: "readings" },
    el("li", {}, `Intercept (blue side, ${m.M.meta.platform || "EUW1"}): ${x.intercept >= 0 ? "+" : ""}${x.intercept.toFixed(4)}.`),
    el("li", {}, `Pair terms: ${m.M.has_pairs ? (x.pairs >= 0 ? "+" : "") + x.pairs.toFixed(4) : "none in this model"}.`),
    el("li", {}, `Logit ${x.logit.toFixed(4)}, so blue ${pct(x.p.p)} (range ${pct(x.p.lo)} to ${pct(x.p.hi)}).`),
    el("li", {}, `Sides swapped: blue would have ${pct(swapped)}; the two add up to ${pct(x.p.p + swapped)} (exactly 100% only without a side term).`)));
  return box;
}

// Candidates for one slot: search, play rate in the role, and the change to this team's win
// chance if picked; sorted by play rate or by that change
function slotPicker(m, d, side, role) {
  const box = el("div", { class: "slotpicker" });
  const cur = d[side][role];
  const ri = DRAFT_ROLES.findIndex(([r]) => r === role), si = side === "blue" ? 0 : 1;
  const q = m.slot(m.teamsOf(d), d.bans.map(Number), si, ri);
  const byId = new Map(m.champs.map(c => [c.id, c]));
  const all = q.options.map(o => ({ c: byId.get(o.champion) || { id: o.champion, name: "#" + o.champion }, rate: o.share, p: o.win, change: o.change }));
  const now = cur != null ? (all.find(x => String(x.c.id) === String(cur)) || {}).change ?? null : null;
  const input = el("input", { type: "search", placeholder: `Search ${all.length} champions played ${role}`, "aria-label": "Search champions", autocomplete: "off", spellcheck: "false" });
  const sortBtn = el("nav", { class: "switch", "aria-label": "Sort" });
  for (const [k, label] of [["played", "Most played"], ["best", "Best for this team"]]) {
    sortBtn.append(el("button", { type: "button", "aria-pressed": String(d.sort === k), onclick: () => { d.sort = k; saveDraft(d); } }, label));
  }
  const list = el("div", { class: "cands", role: "listbox" });
  const pick = id => { d[side][role] = id; delete d.fb[side + "." + role]; d.open = null; saveDraft(d); };
  const fill = () => {
    const q = champKey(input.value);
    const hits = all.filter(x => !q || champKey(x.c.name).includes(q) || champKey(x.c.alias).includes(q))
      .sort(d.sort === "best" ? (a, b) => b.p - a.p : (a, b) => b.rate - a.rate);
    list.replaceChildren(...hits.slice(0, 40).map(x => {
      const delta = x.change - (now ?? 0);
      return el("button", { type: "button", role: "option", class: String(x.c.id) === String(cur) ? "cur" : null, onclick: () => pick(x.c.id) },
        el("span", { class: "nm" }, x.c.name), el("span", { class: "rate" }, pct(x.rate)),
        el("b", { class: delta > 0.0005 ? "up" : delta < -0.0005 ? "down" : "" }, (Math.abs(delta) < 0.0005 ? "±" : delta > 0 ? "+" : "−") + Math.abs(delta * 100).toFixed(1) + "%"));
    }));
    if (hits.length > 40) list.append(el("p", { class: "sub" }, `${hits.length - 40} more: type to narrow.`));
  };
  input.addEventListener("input", fill);
  input.addEventListener("keydown", ev => {
    if (ev.key === "Enter") { const b = list.querySelector("button"); if (b) b.click(); }
    if (ev.key === "Escape") { d.open = null; saveDraft(d); }
  });
  box.append(suggest(m, d, all, q.options, cur, now, side, role, pick));
  box.append(el("div", { class: "pickhead" }, input, sortBtn), el("p", { class: "sub" }, `Share of the role's games on the newest patch, then the change to ${side}'s win chance ${now != null ? "against the current pick" : "against an empty slot"}. An average pick here: ${pct(q.average)}.`), list);
  fill();
  setTimeout(() => input.focus({ preventScroll: true }), 0);
  return box;
}

const LANE_MIN_SHARE = 0.01;

// Suggestions for the open slot, each with its reason as a plain sentence. Ranked by the
// range's low end by default, so a champion on few games can't top a list (as the site's
// lane opponents). The lane lists need the lane model (DRAFT.lane)
function suggest(m, d, all, options, cur, now, side, role, pick) {
  const byId = new Map(options.map(o => [o.champion, o]));
  const low = d.rank !== "guess";
  const ri = DRAFT_ROLES.findIndex(([r]) => r === role), roleName = DRAFT_ROLES[ri][1].toLowerCase();
  const nameOf = id => (m.champs.find(c => c.id === +id) || { name: "#" + id }).name;
  const cands = all.filter(x => String(x.c.id) !== String(cur));
  const rank = el("nav", { class: "switch", "aria-label": "Rank by" });
  for (const [k, label] of [["low", "Likely (low end)"], ["guess", "Best guess"]]) {
    rank.append(el("button", { type: "button", "aria-pressed": String(d.rank === k), onclick: () => { d.rank = k; saveDraft(d); } }, label));
  }
  const box = el("div", { class: "suggest" }, el("div", { class: "suggesthead" }, el("h4", {}, "Suggestions"), el("span", { class: "sub" }, "Rank by"), rank));
  const list = (title, rows, empty) => {
    box.append(el("h5", {}, title));
    if (!rows.length) { box.append(el("p", { class: "muted" }, empty)); return; }
    box.append(el("ol", {}, ...rows.map(([id, text]) => el("li", {}, el("button", { type: "button", class: "link", onclick: () => pick(id) }, nameOf(id)), ": ", text))));
  };
  const pts = x => `${x >= 0 ? "+" : "−"}${Math.abs(x * 100).toFixed(1)} points`;
  const gold = x => `${x >= 0 ? "+" : "−"}${Math.abs(Math.round(x)).toLocaleString("en-GB")}`;

  const best = cands.slice().sort((a, b) => low ? byId.get(b.c.id).lo - byId.get(a.c.id).lo : b.p - a.p).slice(0, 5);
  list("Best for this draft", best.map(x => {
    const o = byId.get(x.c.id);
    return [x.c.id, `${side} would win ${pct(x.p)} of games (likely ${pct(o.lo)} to ${pct(o.hi)}), ${pts(x.change - (now ?? 0))} against ${now != null ? "the current pick" : "an empty slot"}, from ${num(o.games)} games in the role.`];
  }), "No candidates left for this slot.");

  const lm = DRAFT.lane;
  if (!lm) { box.append(el("p", { class: "sub" }, "Best into your lane opponent and safest blind pick need the lane model (meiolol-lab lane --export).")); return box; }
  const { lanediff14: G, cs10: C, deaths15: D } = lm.at;
  const by = r => low ? r.lo[G] : r.value[G];
  // Off-role picks (carries in support, say) farm more than the role's regulars, so on a few
  // hundred games they top every gold list; the lane lists keep the role's regular picks
  const regular = cands.filter(x => x.rate >= LANE_MIN_SHARE);
  box.append(el("p", { class: "sub" }, `Lane lists: champions with at least ${pct(LANE_MIN_SHARE)} of the ${roleName} role's games this patch.` +
    (ri === 1 || ri === 4 ? ` For ${roleName === "jungle" ? "junglers" : "supports"}, gold at 14 says more about how much a champion farms than about who wins the lane.` : "")));
  const other = side === "blue" ? "red" : "blue", opp = d[other][role];
  if (opp != null) {
    const rows = regular.map(x => [x.c.id, lm.value(x.c.id, +opp, ri)]).sort((a, b) => by(b[1]) - by(a[1])).slice(0, 5);
    list(`Best into ${nameOf(opp)}`, rows.map(([id, r]) => [id,
      `${gold(r.value[G])} gold over ${nameOf(opp)} at 14 (likely ${gold(r.lo[G])} to ${gold(r.hi[G])}), ${r.value[C].toFixed(0)} CS at 10 and ${r.value[D].toFixed(1)} deaths before 15, ` +
      (r.pair_games ? `from ${num(r.pair_games)} games of this matchup and ${num(r.champ_games)} on ${nameOf(id)} in the ${roleName} role.` : `from ${num(r.champ_games)} games on ${nameOf(id)} in the ${roleName} role; no games of this matchup yet, so averages only.`)]), "No candidates left for this slot.");
  } else {
    box.append(el("h5", {}, "Best into your lane opponent"), el("p", { class: "muted" }, `Pick ${other}'s ${roleName} first: that's the lane opponent.`));
  }
  // Likely opponents: the role's champions by play share on the newest patch, without
  // picks and bans; the "worst common matchup" is among the 10 most played
  const taken = takenIn(d);
  const field = m.champs.filter(c => !taken.has(String(c.id)) && m.rate(c.id, role) > 0).map(c => ({ id: c.id, w: m.rate(c.id, role) }));
  const blind = regular.map(x => {
    const f = field.filter(o => o.id !== x.c.id), t = sumR(f.map(o => o.w));
    return [x.c.id, lm.blind(x.c.id, ri, f.map(o => ({ id: o.id, w: o.w / t })))];
  }).sort((a, b) => by(b[1]) - by(a[1])).slice(0, 5);
  list("Safest blind pick", blind.map(([id, r]) => {
    const worst = r.each.slice().sort((a, b) => b.w - a.w).slice(0, 10).sort((a, b) => a.value[G] - b.value[G])[0];
    return [id, `${gold(r.value[G])} gold over the lane opponent at 14 on average across likely opponents (likely ${gold(r.lo[G])} to ${gold(r.hi[G])})` +
      (worst ? `; worst common matchup ${nameOf(worst.id)}, ${gold(worst.value[G])} gold` : "") + `; from ${num(r.champ_games)} games on ${nameOf(id)} in the ${roleName} role.`];
  }), "No candidates left for this slot.");
  return box;
}

// ---------- models: shell ----------

const MODELS = { learned: {}, modelMd: null, campaigns: [], runs: [], findings: new Map() };

function modelsData() {
  MODELS.runs = TRAIN ? TRAIN.runs.map(runInfo) : [];
  return MODELS;
}

// Model runs as cards; the lab's checks (diagnose, screen, preds) folded under them
function runsBlock(body, all) {
  const isCheck = r => r.res && r.res.kind !== "run";
  const runs = all.filter(r => !isCheck(r)), checks = all.filter(isCheck);
  const sec = section(body, "Runs", runs.length ? "Newest first. Pick one to see its health below." : null);
  if (checks.length) {
    const d = el("details", {}, el("summary", {}, `Checks and screens (${checks.length}): where models are off, which inputs look useful`));
    d.append(el("ul", { class: "readings checks" }, ...checks.slice(0, 40).map(r => el("li", {}, el("b", {}, shortRun(r.run)), ` (${r.host === "gpu-box" ? "gpu-box" : "Mac"}, ${uk(Date.parse(r.started) / 1000)}): `, runSentence(r)))));
    sec.append(d);
  }
  if (!runs.length) { sec.append(el("p", { class: "muted" }, "No model runs in this category yet.")); return; }
  const gpu = TRAIN && TRAIN.hosts && TRAIN.hosts["gpu-box"];
  if (gpu && nowS() - gpu > 1800 && runs.some(r => r.host === "gpu-box")) {
    sec.append(el("div", { class: "health bad" }, el("b", {}, `gpu-box last reached ${ago(gpu)}: `), "its runs below may be out of date (the Mac reaches it on the home network only)."));
  }
  if (!ui.run || !runs.some(r => r.run === ui.run)) ui.run = runs[0].run;
  const list = el("div", { class: "runcards" });
  for (const r of runs.slice(0, 24)) {
    const started = Date.parse(r.started) / 1000;
    const state = r.synthetic ? "synthetic" : runState(r.state);
    list.append(el("button", { type: "button", class: "run", "aria-current": r.run === ui.run ? "true" : null, onclick: () => { ui.run = r.run; render(true); } },
      el("span", { class: "top" }, el("b", {}, shortRun(r.run)), el("span", { class: "pill " + (r.synthetic ? "warn" : runClass(r.state)) }, state)),
      el("span", { class: "sub" }, [r.host === "gpu-box" ? "gpu-box" : "Mac", r.target && OUTCOMES[r.target] ? OUTCOMES[r.target][0] : null, isFinite(started) ? uk(started) : null].filter(Boolean).join(" · ")),
      el("span", { class: "finding" }, runSentence(r))));
  }
  sec.append(list);
  if (runs.length > 24) sec.append(el("p", { class: "sub" }, `${runs.length - 24} older runs not shown.`));
  const health = el("details", { class: "health-block" }, el("summary", {}, `Run health: ${shortRun(ui.run)} (curves, log)`));
  sec.append(health);
  const detail = el("div", { class: "detail" });
  const fx = MODELS.findings.get(ui.run);
  if (fx && Object.keys(fx.effects).length) {
    const fd = el("details", { open: true }, el("summary", {}, `Effects measured by ${shortRun(ui.run)} (${Object.keys(fx.effects).length})`));
    const g = grid(fd);
    for (const e of Object.values(fx.effects)) effectChart(g, e);
    sec.insertBefore(fd, health);
  }
  health.append(detail);
  runDetail(detail, runs.find(r => r.run === ui.run));
}

function categoryView(body, cat) {
  const learnt = section(body, "What we learnt", "Final findings (docs/learned.md).");
  learnedList(learnt, MODELS.learned[cat]);
  runFindings(learnt, cat);
  const runs = MODELS.runs.filter(r => r.cat === cat);
  const targets = Object.keys(OUTCOMES).filter(k => CAT_OF_TARGET[k] === cat);
  if (targets.length) labBest(grid(section(body, "Best model against the baseline", null)), targets);
  runsBlock(body, runs);
}

function allView(body) {
  const sec = section(body, "What we learnt", "The newest findings per category (docs/learned.md); open a category for its evidence, best model and runs.");
  const cards = grid(sec, "cards");
  const W = winReadings();
  const te = teamEffects();
  for (const [cat, label] of CATS.slice(1).filter(([k]) => k !== "draft")) {
    const items = MODELS.learned[cat] || [];
    const runs = MODELS.runs.filter(r => (cat === "lab" ? r.lab : r.cat === cat));
    const live = runs.filter(r => r.state === "running" || r.state === "paused").length;
    const card = el("button", { type: "button", class: "card catcard", onclick: () => setCat(cat) }, el("h3", {}, label));
    if (cat === "win" && W && W.best) card.append(el("p", { class: "headline" }, `Best model right ${pct(W.best.acc)} of the time (coin flip 50%).`));
    if (cat === "early" && te) {
      const tot = te.t.rows.find(r => /^total/.test(r.step));
      const v = tot && pmIn(tot.lanediff14);
      if (v) card.append(el("p", { class: "headline" }, `The draft explains ${v.mean.toFixed(1)}% of lane gold leads at 14 min beyond champion averages.`));
    }
    if (cat === "lab") card.append(el("p", { class: "headline" }, `${MODELS.campaigns.length} campaign${MODELS.campaigns.length === 1 ? "" : "s"}.`));
    if (items.length) learnedList(card, items, 2, true);
    else if (cat !== "lab") card.append(el("p", { class: "muted" }, "Nothing final yet."));
    card.append(el("p", { class: "sub" }, `${runs.length} run${runs.length === 1 ? "" : "s"}` + (live ? `, ${live} running` : "") + (items.length > 2 ? ` · ${items.length} findings` : "")));
    cards.append(card);
  }
  const live = MODELS.runs.filter(r => r.state === "running" || r.state === "paused");
  if (live.length) runsBlock(body, live);
}

function setCat(cat) {
  ui.cat = cat;
  store("cat", cat);
  history.replaceState(null, "", "#models/" + cat);
  render();
  window.scrollTo(0, 0);
}

VIEWS.models = body => {
  modelsData();
  const nav = el("nav", { class: "cats", "aria-label": "Model categories" });
  for (const [k, label] of CATS) {
    nav.append(el("button", { type: "button", "aria-pressed": String(k === ui.cat), onclick: () => setCat(k) }, label));
  }
  body.append(nav);
  if (!TRAIN && !trainErr && ui.cat !== "draft") body.append(el("p", { class: "muted" }, "Loading runs and findings…"));
  if (trainErr) body.append(el("div", { class: "health bad" }, el("b", {}, "Could not load the training view: "), trainErr));
  ({ all: allView, win: winView, draft: draftView, early: earlyView, lab: labView }[ui.cat] || (b => categoryView(b, ui.cat)))(body);
};

const shortRun = run => (run || "").replace(/^\d{8}T\d{4}Z-/, "");
const runState = s => s === "exit 0" ? "finished" : /^exit/.test(s) ? `failed (${s})` : s;
const runClass = s => s === "exit 0" ? "good" : /^exit|died/.test(s) ? "bad" : s === "paused" ? "warn" : s === "running" ? "live" : "";

async function runDetail(box, r) {
  const started = Date.parse(r.started) / 1000;
  box.append(el("div", { class: "section-head" }, el("h3", {}, shortRun(r.run)), el("span", { class: "pill " + runClass(r.state) }, runState(r.state))));
  box.append(el("p", { class: "sub" }, `Started ${isFinite(started) ? uk(started) : "–"}`, r.head ? `, at ${r.head}${r.dirty && r.dirty !== "0 files" ? " + " + r.dirty + " changed" : ""}` : "", r.args ? el("code", {}, " " + r.args) : null));
  const holder = el("div");
  box.append(holder);
  const key = r.run + "|" + r.state + "|" + r.last + "|" + r.ended;
  let data = runCache.get(r.run);
  if (!data || data.key !== key) {
    holder.append(el("p", { class: "muted" }, "Loading…"));
    const base = "training/runs/" + encodeURIComponent(r.run) + "/";
    const [metrics, log] = await Promise.all([getText(base + "metrics.tsv").catch(() => ""), getText(base + "log.txt").catch(() => "")]);
    data = { key, metrics, log };
    runCache.set(r.run, data);
    holder.replaceChildren();
  }
  const lines = data.metrics.split("\n").filter(Boolean);
  const cols = lines.length ? lines[0].split("\t") : [];
  const rows = lines.slice(1).map(l => l.split("\t").map(Number)).filter(x => isFinite(x[0]));
  if (rows.length && cols.length > 1) {
    // Columns sharing the part after the last _ share a chart; a prefix keeps its colour
    const groups = new Map(), prefixes = [];
    for (const c of cols.slice(1)) {
      const i = c.lastIndexOf("_");
      const g = i > 0 ? c.slice(i + 1) : c, p = i > 0 ? c.slice(0, i) : c;
      if (!groups.has(g)) groups.set(g, []);
      groups.get(g).push(c);
      if (!prefixes.includes(p)) prefixes.push(p);
    }
    const colour = c => { const i = c.lastIndexOf("_"); return PALETTE[Math.min(prefixes.indexOf(i > 0 ? c.slice(0, i) : c), PALETTE.length - 1)]; };
    const g = grid(holder);
    const xs = rows.map(x => x[0]);
    for (const [name, cs] of groups) {
      chart(g, {
        id: "run-" + name, title: cs.length === 1 ? cs[0] : name, type: "line", fit: true, x: xs,
        xFmt: v => `${cols[0]} ${num(v)}`, xTicks: numTicks(), fmt: v => v == null ? "–" : Math.abs(v) >= 100 ? num(v) : (+v.toPrecision(4)).toString(),
        series: cs.map(c => ({ name: c, color: colour(c), values: rows.map(x => x[cols.indexOf(c)]) })),
      });
    }
    const d = el("details", {}, el("summary", {}, `Metrics table (${rows.length} rows)`));
    holder.append(d);
    table(d, "run-metrics", cols.map((c, i) => ({ key: c, label: c, num: true, fmt: v => v == null ? "–" : (+v.toPrecision(5)).toString(), i })),
      rows.map(x => Object.fromEntries(cols.map((c, i) => [c, x[i]]))), { sort: { key: cols[0], dir: "desc" }, limit: 200 });
  } else holder.append(el("p", { class: "muted" }, "No metrics yet: the run reports by appending rows to metrics.tsv in its directory."));
  const pre = el("pre", { class: "log" }, data.log || "(empty log)");
  const d = el("details", { open: !rows.length }, el("summary", {}, "Log (last 300 lines)"), pre);
  holder.append(d);
  d.addEventListener("toggle", () => { pre.scrollTop = pre.scrollHeight; });
}

// ---------- traffic ----------

VIEWS.traffic = body => {
  const sec = section(body, "Site traffic", TRAFFIC ? `nginx log on the web server, no IP addresses; updated ${ago(TRAFFIC.generated)}. People and bots told apart by user agent.` : "",
    switcher([["24h", "24 hours"], ["7d", "7 days"], ["30d", "30 days"]], ui.trafficRange, r => { ui.trafficRange = r; store("traffic-range", r); render(true); }, "Traffic range"));
  if (!TRAFFIC) { sec.append(el("p", { class: "muted" }, trafficErr ? `Could not load ops/traffic.json: ${trafficErr}` : "Loading…")); return; }
  const T = TRAFFIC;
  const spanS = { "24h": 86400, "7d": 7 * 86400, "30d": 30 * 86400 }[ui.trafficRange];
  const hrs = T.hours.filter(r => r[0] >= T.generated - spanS);
  const tiles = grid(sec, "tiles");
  const day = T.hours.filter(r => r[0] >= T.generated - 86400);
  tile(tiles, "Views, 24 h", num(sumR(day.map(r => r[1]))), "pages by people");
  tile(tiles, `Views, ${ui.trafficRange}`, num(sumR(hrs.map(r => r[1]))), `${num(sumR(hrs.map(r => r[2])))} by bots`);
  tile(tiles, "Server errors, 24 h", num(sumR(day.map(r => r[4]))), "5xx answers", sumR(day.map(r => r[4])) > 0 ? "warn" : null);
  const lat = (T.latency_ms || {})["24h"];
  const ms = v => v == null ? "–" : num(v) + " ms";
  if (lat) tile(tiles, "Page time, p95", ms(lat.p95), `p50 ${ms(lat.p50)}, p99 ${ms(lat.p99)} (bucket bounds)`);
  tile(tiles, "Sent, 24 h", bytes(sumR(day.map(r => r[5]))), `${num(sumR(day.map(r => r[3])))} asset requests`);
  const daily = spanS > 2 * 86400;
  let xs = hrs.map(r => r[0]), people = hrs.map(r => r[1]), bots = hrs.map(r => r[2]), errs = hrs.map(r => r[4]);
  if (daily) {
    const by = new Map();
    for (const r of hrs) {
      const d = Math.floor((r[0] + ukOffset(r[0])) / 86400) * 86400 - ukOffset(r[0]);
      const a = by.get(d) || [0, 0, 0];
      a[0] += r[1]; a[1] += r[2]; a[2] += r[4];
      by.set(d, a);
    }
    xs = [...by.keys()].sort((a, b) => a - b);
    people = xs.map(d => by.get(d)[0]); bots = xs.map(d => by.get(d)[1]); errs = xs.map(d => by.get(d)[2]);
  }
  const step = daily ? 86400 : 3600;
  const g = grid(sec);
  chart(g, {
    id: "traffic-views", title: `Page views per ${daily ? "day" : "hour"}`, type: "bars", step, time: true, x: xs,
    xMin: T.generated - spanS, xMax: T.generated, xFmt: daily ? t => uk(t).replace(/ \d\d:\d\d$/, "") : uk,
    series: [{ name: "people", color: PALETTE[0], values: people }, { name: "bots", color: PALETTE[5], values: bots }],
  });
  chart(g, {
    id: "traffic-errors", title: `Server errors per ${daily ? "day" : "hour"}`, type: "bars", step, time: true, x: xs,
    xMin: T.generated - spanS, xMax: T.generated, series: [{ name: "5xx", color: BAD, values: errs }],
  });
  const cards = grid(sec, "cards");
  const pages = (T.top_pages || {})[ui.pagesWindow] || [];
  const pc = el("div", { class: "card" }, el("div", { class: "section-head" }, el("h3", {}, "Top pages"),
    switcher([["24h", "24 h"], ["7d", "7 days"]], ui.pagesWindow, w => { ui.pagesWindow = w; render(true); }, "Pages window")));
  table(pc, "top-pages", [{ key: "uri", label: "Page", cls: "msg" }, { key: "views", label: "Views", num: true }], pages.map(([uri, views]) => ({ uri, views })), { sort: { key: "views", dir: "desc" } });
  cards.append(pc);
  bars(cards, "Referrers, 7 days", ((T.referrers || {})["7d"] || []).map(([d, n]) => ({ label: d, value: n, color: PALETTE[2] })));
  bars(cards, "Browsers and bots, 7 days", ((T.agents || {})["7d"] || []).map(([a, n]) => ({ label: a, value: n, color: /bot|crawl|spider|other/i.test(a) ? PALETTE[5] : PALETTE[0] })));
  bars(cards, "Status codes, 24 h", ((T.status || {})["24h"] || []).map(([c, n]) => ({ label: String(c), value: n, color: +c >= 500 ? BAD : +c >= 400 ? PALETTE[3] : PALETTE[2] })));
  bars(cards, "Render cache, 24 h", ((T.render_cache || {})["24h"] || []).map(([c, n]) => ({ label: c || "static", value: n, color: PALETTE[4] })),
    { caption: "Pages the static build leaves out come from the box (MISS) or nginx's cache (HIT, STALE)." });
  const nf = el("div", { class: "card" }, el("h3", {}, "Not found, 24 h"));
  table(nf, "not-found", [{ key: "uri", label: "Path", cls: "msg" }, { key: "n", label: "Hits", num: true }], ((T.not_found || {})["24h"] || []).map(([uri, n]) => ({ uri, n })), { sort: { key: "n", dir: "desc" } });
  cards.append(nf);
};

// ---------- controls ----------

const ACTIONS = {
  "crawl-start": "Start crawler", "crawl-stop": "Stop crawler", "crawl-restart": "Restart crawler",
  "site-build": "Build and upload site", "eval-run": "Run eval", "health-check": "Run health check",
};
let actionBusy = null, actionResult = null;

function actionButton(name, label, opts = {}) {
  return el("button", {
    type: "button", class: "action" + (opts.danger ? " danger" : ""), disabled: opts.disabled || !!actionBusy || !L,
    title: L ? null : "The live API is unavailable", onclick: () => runAction(name, opts.confirm),
  }, actionBusy === name ? "Working…" : label || ACTIONS[name]);
}

async function runAction(name, confirmText) {
  if (confirmText && !window.confirm(confirmText)) return;
  actionBusy = name;
  actionResult = null;
  render(true);
  try {
    const r = await fetch("api/action/" + name, { method: "POST", headers: { "X-Meiolol-Action": "1" }, credentials: "same-origin", cache: "no-store" });
    const j = await r.json().catch(() => ({ ok: false, output: `${r.status} ${r.statusText}` }));
    actionResult = { name, ok: !!j.ok, output: j.output || "", at: nowS() };
  } catch (e) {
    actionResult = { name, ok: false, output: String(e.message || e), at: nowS() };
  }
  actionBusy = null;
  await pollLive();
  render(true);
}

function actionList(parent, actions) {
  table(parent, "actions-" + actions.length, [
    { key: "t", label: "When", fmt: v => typeof v === "number" ? `${uk(v)} (${ago(v)})` : v },
    { key: "name", label: "Action", fmt: v => ACTIONS[v] || v },
    { key: "result", label: "Result", fmt: v => el("span", { class: "pill " + (v === "ok" ? "good" : v === "refused" ? "warn" : "bad") }, v) },
    { key: "out", label: "Output", cls: "msg" },
  ], actions.slice().reverse().map(([t, name, result, out]) => ({ t, name, result, out })));
}

const SERVICES = [
  ["meiolol-crawl", "Crawler", "Riot API to the databases (deploy/box.sh start|stop)"],
  ["meiolol-web", "Web loop", "site build and upload every 15 min, daily eval and builds"],
  ["meiolol-render@a", "Renderer a", "pages on request for nginx"],
  ["meiolol-render@b", "Renderer b", "takes over on deploys"],
  ["meiolol-backup", "Backups", "daily (docs/data-safety.md)"],
  ["meiolol-health", "Health", "checks with ntfy pushes"],
];

VIEWS.ops = body => {
  healthBanner(body);
  const sec = section(body, "Box", L ? `Live from the box, ${ago(L.now)}. Every action is logged on the box (data/admin-actions.log).` : `The live API is unavailable${liveErr ? " (" + liveErr + ")" : ""}: controls are off.`);
  const cards = grid(sec, "cards");
  const svc = el("div", { class: "card" }, el("h3", {}, "Services"));
  const ul = el("ul", { class: "services" });
  for (const [unit, label, what] of SERVICES) {
    const state = L && L.services ? L.services[unit] : null;
    ul.append(el("li", {}, el("span", { class: "pill " + (state === "active" ? "good" : state == null ? "" : state === "inactive" && unit.startsWith("meiolol-render") ? "" : "bad") }, state || "unknown"),
      el("span", {}, el("b", {}, label), el("span", { class: "sub" }, " " + what))));
  }
  svc.append(ul);
  cards.append(svc);
  const act = el("div", { class: "card" }, el("h3", {}, "Actions"));
  const crawlUp = L && L.services && L.services["meiolol-crawl"] === "active";
  const running = L && L.running;
  act.append(el("div", { class: "actions" },
    crawlUp
      ? actionButton("crawl-restart", null, { confirm: "Restart the crawler? It resumes from its queues." })
      : actionButton("crawl-start", null, { confirm: "Start (and enable) the crawler?" }),
    crawlUp ? actionButton("crawl-stop", null, { danger: true, confirm: "Stop and disable the crawler? No new games until it is started again." }) : null,
    actionButton("site-build", null, { confirm: "Build and upload the site now?" }),
    actionButton("eval-run", running && running.eval ? "Eval running" : null, { disabled: !!(running && running.eval), confirm: "Run meiolol eval now? About 10 minutes at low priority." }),
    actionButton("health-check")));
  if (running && running.action) act.append(el("p", { class: "sub" }, `Busy: ${ACTIONS[running.action.name] || running.action.name} since ${ago(running.action.since)}.`));
  if (actionResult) {
    act.append(el("div", { class: "result " + (actionResult.ok ? "good" : "bad") },
      el("b", {}, `${ACTIONS[actionResult.name] || actionResult.name}: ${actionResult.ok ? "done" : "failed"}`),
      actionResult.output ? el("pre", {}, actionResult.output) : null));
  }
  cards.append(act);
  if (L && L.actions && L.actions.length) {
    const h = el("details", { open: true }, el("summary", {}, `Action history (${L.actions.length})`));
    sec.append(h);
    actionList(h, L.actions);
  }

  logViewer(section(body, "Logs", "Box logs with player names, ids and match ids removed. Filter is case-insensitive."));

  const site = section(body, "Site and deploys");
  const og = grid(site);
  const upFrom = D.now - D.days * 86400;
  chart(og, {
    id: "uploads", title: `Site uploads (${D.uploads.length} in ${D.days} days)`, type: "bars", step: 3600, time: true,
    x: hourBins(D.uploads, upFrom), xMin: upFrom, xMax: D.now,
    series: [{ name: "uploads", color: PALETTE[2], values: hourBins(D.uploads, upFrom, true) }],
  });
  const deploys = (D.deploys || "").trim().split("\n").filter(Boolean).reverse();
  if (deploys.length) {
    const c = el("div", { class: "card" }, el("h3", {}, "Deploys"));
    table(c, "deploys", [{ key: "commit", label: "Commit", fmt: v => el("code", {}, v.slice(0, 10)) }, { key: "at", label: "When", num: true, fmt: v => v ? `${uk(v)} (${ago(v)})` : "" }],
      deploys.map(d => { const [commit, at] = d.split(" "); return { commit, at: at ? Date.parse(at) / 1000 : null }; }));
    og.append(c);
  }
};

// Upload times binned per hour: the hours, or the counts
function hourBins(times, from, counts) {
  const by = new Map();
  for (const t of times) if (t >= from) { const h = Math.floor(t / 3600) * 3600; by.set(h, (by.get(h) || 0) + 1); }
  const hs = [...by.keys()].sort((a, b) => a - b);
  return counts ? hs.map(h => by.get(h)) : hs;
}

let logTimer = null;
function logViewer(parent) {
  const files = ["crawl", "web", "eval", "render", "health", "backup", "builds"];
  const out = el("pre", { class: "log big" }, L ? "Loading…" : "The live API is unavailable.");
  const info = el("span", { class: "sub" });
  const filter = el("input", { type: "search", placeholder: "Filter lines", value: ui.log.filter, "aria-label": "Filter log lines" });
  const file = el("select", { "aria-label": "Log file" }, ...files.map(f => el("option", { value: f, selected: f === ui.log.file }, f + ".log")));
  const lines = el("select", { "aria-label": "Lines" }, ...[100, 300, 1000, 2000].map(n => el("option", { value: n, selected: n === ui.log.lines }, n + " lines")));
  const follow = el("input", { type: "checkbox", checked: ui.log.follow });
  let text = "";
  const show = () => {
    const f = ui.log.filter.toLowerCase();
    const all = text.split("\n");
    const shown = f ? all.filter(l => l.toLowerCase().includes(f)) : all;
    out.replaceChildren();
    for (const l of shown) {
      if (!f) { out.append(l + "\n"); continue; }
      const i = l.toLowerCase().indexOf(f);
      out.append(l.slice(0, i), el("mark", {}, l.slice(i, i + f.length)), l.slice(i + f.length) + "\n");
    }
    info.textContent = f ? `${shown.length} of ${all.length} lines` : `${all.length} lines`;
    out.scrollTop = out.scrollHeight;
  };
  const load = async () => {
    if (!L) return;
    try {
      text = (await getText(`api/log?file=${encodeURIComponent(ui.log.file)}&lines=${ui.log.lines}`)).replace(/\n$/, "");
    } catch (e) { text = "Could not load: " + e.message; }
    show();
  };
  filter.addEventListener("input", () => { ui.log.filter = filter.value; show(); });
  file.addEventListener("change", () => { ui.log.file = file.value; load(); file.blur(); });
  lines.addEventListener("change", () => { ui.log.lines = +lines.value; load(); lines.blur(); });
  const arm = () => {
    clearInterval(logTimer);
    logTimer = ui.log.follow ? setInterval(() => { if (document.body.contains(out)) load(); else clearInterval(logTimer); }, 10_000) : null;
  };
  follow.addEventListener("change", () => { ui.log.follow = follow.checked; arm(); follow.blur(); });
  parent.append(el("div", { class: "log-bar" }, file, lines, filter, el("label", {}, follow, " follow"),
    el("button", { type: "button", class: "ghost", onclick: load }, "Reload"), info), out);
  load();
  arm();
}

// ---------- start ----------

window.addEventListener("hashchange", () => {
  const [t, sub] = hashTab();
  if (t === "models" && sub && sub !== ui.cat) { ui.cat = sub; if (t === ui.tab) render(); }
  if (TABS.some(([k]) => k === t) && t !== ui.tab) setTab(t);
});
window.addEventListener("keydown", ev => {
  if (ev.target.closest && ev.target.closest("input, select, textarea") || ev.metaKey || ev.ctrlKey || ev.altKey) return;
  const n = +ev.key;
  if (n >= 1 && n <= TABS.length) setTab(TABS[n - 1][0]);
  if (ev.key === "Escape" && ui.zoom) setZoom(null);
});
document.addEventListener("visibilitychange", () => { if (!document.hidden) refreshAll(); });

// The site's menu shows Jacob a link here (src/site/html.zig admin_link)
store("link", { href: location.pathname + "#models/draft", label: "Draft tester (admin)" });
render();
pollLive();
pollTraffic();
pollTraining();
setInterval(() => { if (!document.hidden) pollLive(); }, LIVE_MS);
setInterval(() => { if (!document.hidden) pollSnapshot(); }, SNAPSHOT_MS);
setInterval(() => { if (!document.hidden) pollTraffic(); }, TRAFFIC_MS);
setInterval(() => { if (!document.hidden && (ui.tab === "models" || ui.tab === "overview")) pollTraining(); }, TRAINING_MS);
setInterval(renderStatus, 5000);

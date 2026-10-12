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
  ["ingest", "Ingest"], ["model", "Model"], ["training", "Training"], ["traffic", "Traffic"],
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

const ui = {
  tab: (location.hash.slice(1).split("/")[0]) || "overview",
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
    const h = lines[i].match(/^##\s+(.*)/);
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
    const re = /(`[^`]+`|\*\*[^*]+\*\*|~~[^~]+~~)/g;
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
    const [runs, pushed] = await Promise.all([getText("training/runs.tsv"), getText("training/pushed.txt").catch(() => "")]);
    TRAIN = { runs: tsvRaw(runs).reverse(), pushed: +pushed.trim() || null };
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
  history.replaceState(null, "", "#" + tab);
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
    live: ["overview", "crawler", "riot", "storage", "model", "ops"],
    snapshot: TABS.map(t => t[0]).filter(t => t !== "traffic" && t !== "training"),
    traffic: ["overview", "traffic"],
    training: ["overview", "training"],
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
    tile(tiles, "Model AUC", (e["auc_" + best] ?? 0).toFixed(3), `best: ${best === "eb" ? "shrunk" : best}, ${num(e.games)} games`, null, () => setTab("model"));
  }
  if (TRAIN && TRAIN.runs.length) {
    const live = TRAIN.runs.filter(r => r.state === "running" || r.state === "paused");
    const r = live[0] || TRAIN.runs[0];
    tile(tiles, "Training", live.length ? `${live.length} running` : "idle", `${shortRun(r.run)}: ${runState(r.state)}`, null, () => setTab("training"));
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

VIEWS.crawler = body => {
  const cv = crawlFor(ui.range);
  const C = cv.C;
  const S = crawlSeries(C, cv.from);
  const common = { x: S.xs, step: C.step, markers: C.restarts, xMin: cv.from, xMax: cv.to, time: true };
  const per = C.step >= 600 ? "per 10 min" : "per minute";
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

VIEWS.model = body => {
  const ev = tsv(D.eval);
  const running = L && L.running && L.running.eval;
  const head = [];
  head.push(actionButton("eval-run", running ? `Eval running (${span(nowS() - running)})` : "Run eval now", { disabled: !!running || !L, confirm: "Run meiolol eval now? About 10 minutes at low priority on the box." }));
  const sec = section(body, "Draft model", "meiolol eval, daily: held-out EUW games (docs/model.md). Higher AUC is better; 0.5 is a coin.", ...head);
  if (ev.length) {
    const e = ev[ev.length - 1];
    const tiles = grid(sec, "tiles");
    const names = { base: "base", current: "current", eb: "shrunk", joint: "joint" };
    for (const k of Object.keys(names)) {
      const prev = ev.length > 1 ? ev[ev.length - 2]["auc_" + k] : null;
      const d = prev == null || e["auc_" + k] == null ? "" : `, AUC ${e["auc_" + k] >= prev ? "+" : ""}${(e["auc_" + k] - prev).toFixed(4)} vs previous run`;
      tile(tiles, "AUC, " + names[k], e["auc_" + k] == null ? "–" : e["auc_" + k].toFixed(4), `log loss ${e["ll_" + k] == null ? "–" : e["ll_" + k].toFixed(4)}${d}`);
    }
    tile(tiles, "Latest run", e.date, `${num(e.games)} games, ${num(e.test)} held out`);
    const g = grid(sec);
    const ex = ev.map((_, i) => i);
    const evFmt = i => ev[i] ? `${ev[i].date}, ${num(ev[i].games)} games` : "";
    const evTicks = (a, b, w) => {
      const every = Math.max(1, Math.ceil(ev.length / Math.max(2, Math.floor(w / 90))));
      return ev.map((r, i) => [i, num(r.games)]).filter((_, i) => i % every === 0);
    };
    const models = [["base", "base"], ["current", "current"], ["eb", "shrunk"], ["joint", "joint"]];
    chart(g, {
      x: ex, title: "AUC by games used", type: "line", fit: true, xFmt: evFmt, xTicks: evTicks, fmt: v => v == null ? "–" : v.toFixed(3),
      series: models.map(([k, name], i) => ({ name, color: PALETTE[i], values: ev.map(r => r["auc_" + k]) })),
    });
    chart(g, {
      x: ex, title: "Log loss by games used", type: "line", fit: true, xFmt: evFmt, xTicks: evTicks, fmt: v => v == null ? "–" : v.toFixed(4),
      series: models.map(([k, name], i) => ({ name, color: PALETTE[i], values: ev.map(r => r["ll_" + k]) })),
      caption: "Coin flip is 0.6931; lower is better.",
    });
    const d = el("details", {}, el("summary", {}, `Every run (${ev.length})`));
    sec.append(d);
    table(d, "eval-runs", [
      { key: "date", label: "Date" }, { key: "games", label: "Games", num: true }, { key: "test", label: "Test", num: true },
      ...models.map(([k, name]) => ({ key: "auc_" + k, label: "AUC " + name, num: true, fmt: v => v == null ? "–" : v.toFixed(4) })),
      { key: "ll_coin", label: "Coin log loss", num: true, fmt: v => v == null ? "–" : v.toFixed(4) },
    ], ev.map((r, i) => ({ ...r, i })), { sort: { key: "i", dir: "desc" } });
  } else sec.append(el("p", { class: "muted" }, "No eval runs yet."));
  if (D.eval_report) {
    const r = section(body, "Latest eval report", "data/eval-latest.md from the newest run.");
    r.append(el("div", { class: "card report" }, markdown(D.eval_report)));
  }
};

// ---------- training ----------

const shortRun = run => (run || "").replace(/^\d{8}T\d{4}Z-/, "");
const runState = s => s === "exit 0" ? "finished" : /^exit/.test(s) ? `failed (${s})` : s;
const runClass = s => s === "exit 0" ? "good" : /^exit|died/.test(s) ? "bad" : s === "paused" ? "warn" : s === "running" ? "live" : "";

VIEWS.training = body => {
  const sec = section(body, "Training runs", TRAIN && TRAIN.pushed ? `The Mac's lab runs (deploy/lab-push.sh), sent ${ago(TRAIN.pushed)}.` : "The Mac's lab runs (deploy/lab-push.sh).");
  if (!TRAIN) { sec.append(el("p", { class: "muted" }, trainErr ? `Could not load training/: ${trainErr}` : "Loading…")); return; }
  if (!TRAIN.runs.length) { sec.append(el("p", { class: "muted" }, "No runs yet. Start one with deploy/lab-run.sh start mac NAME -- ARGS.")); return; }
  const live = TRAIN.runs.some(r => r.state === "running" || r.state === "paused");
  if (live && TRAIN.pushed && nowS() - TRAIN.pushed > 600) sec.append(el("div", { class: "health bad" }, el("b", {}, "No upload for " + span(nowS() - TRAIN.pushed) + ": "), "the Mac may be asleep or offline."));
  if (!ui.run || !TRAIN.runs.some(r => r.run === ui.run)) ui.run = TRAIN.runs[0].run;
  const layout = el("div", { class: "split" });
  sec.append(layout);
  const list = el("div", { class: "runs" });
  for (const r of TRAIN.runs) {
    const started = Date.parse(r.started) / 1000;
    const ended = r.ended ? Date.parse(r.ended) / 1000 : null;
    list.append(el("button", { type: "button", class: "run", "aria-current": r.run === ui.run ? "true" : null, onclick: () => { ui.run = r.run; render(true); } },
      el("span", { class: "top" }, el("b", {}, shortRun(r.run)), el("span", { class: "pill " + runClass(r.state) }, runState(r.state))),
      el("span", { class: "sub" }, `${isFinite(started) ? uk(started) : "–"}, ${span((ended || nowS()) - started)}`),
      r.last ? el("span", { class: "sub last" }, r.last) : null));
  }
  const detail = el("div", { class: "card detail" });
  layout.append(list, detail);
  runDetail(detail, TRAIN.runs.find(r => r.run === ui.run));
};

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
  const t = location.hash.slice(1).split("/")[0];
  if (TABS.some(([k]) => k === t) && t !== ui.tab) setTab(t);
});
window.addEventListener("keydown", ev => {
  if (ev.target.closest && ev.target.closest("input, select, textarea") || ev.metaKey || ev.ctrlKey || ev.altKey) return;
  const n = +ev.key;
  if (n >= 1 && n <= TABS.length) setTab(TABS[n - 1][0]);
  if (ev.key === "Escape" && ui.zoom) setZoom(null);
});
document.addEventListener("visibilitychange", () => { if (!document.hidden) refreshAll(); });

render();
pollLive();
pollTraffic();
pollTraining();
setInterval(() => { if (!document.hidden) pollLive(); }, LIVE_MS);
setInterval(() => { if (!document.hidden) pollSnapshot(); }, SNAPSHOT_MS);
setInterval(() => { if (!document.hidden) pollTraffic(); }, TRAFFIC_MS);
setInterval(() => { if (!document.hidden && (ui.tab === "training" || ui.tab === "overview")) pollTraining(); }, TRAINING_MS);
setInterval(renderStatus, 5000);

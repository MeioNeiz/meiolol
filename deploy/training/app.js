"use strict";
// Training view: deploy/lab-push.sh uploads this page with runs.tsv (the Mac's lab runs)
// and runs/RUN/{metrics.tsv,log.txt}. Polls; no build step

const POLL_MS = 15000;
// lab-push.sh re-uploads at least every 5 min while a run is live
const STALE_S = 600;
const SERIES = ["--s1", "--s2", "--s3", "--s4", "--s5", "--s6", "--s7", "--s8"];
const SVG_NS = "http://www.w3.org/2000/svg";

let runs = [];
let selected = decodeURIComponent((location.hash.match(/run=([^&]+)/) || [])[1] || "");
let pushedAt = 0;
let shownKey = "";

function el(tag, attrs = {}, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  for (const k of kids) e.append(k);
  return e;
}

function svg(tag, attrs = {}) {
  const e = document.createElementNS(SVG_NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  return e;
}

function parseTsv(text) {
  const lines = text.split("\n").filter(l => l.length);
  if (!lines.length) return { cols: [], rows: [] };
  return { cols: lines[0].split("\t"), rows: lines.slice(1).map(l => l.split("\t")) };
}

async function get(path) {
  const r = await fetch(path, { cache: "no-store" });
  if (!r.ok) throw new Error(`${path}: ${r.status}`);
  return r.text();
}

function ago(s) {
  if (s < 90) return `${Math.max(0, Math.round(s))} s`;
  if (s < 5400) return `${Math.round(s / 60)} min`;
  if (s < 172800) return `${(s / 3600).toFixed(1)} h`;
  return `${Math.round(s / 86400)} days`;
}

function fmt(v) {
  if (!Number.isFinite(v)) return "-";
  if (Math.abs(v) >= 1000) return Math.round(v).toLocaleString("en-GB");
  return String(+v.toPrecision(4));
}

function stateClass(state) {
  if (state === "exit 0") return "done";
  if (state.startsWith("exit")) return "failed";
  return state;
}

function stateLabel(state) {
  if (state === "exit 0") return "finished";
  if (state.startsWith("exit")) return `failed (${state})`;
  return state;
}

// Run directories are named START-NAME (deploy/lab-run.sh)
function shortName(run) {
  return run.replace(/^\d{8}T\d{4}(\d{2})?Z-/, "");
}

function duration(r) {
  const start = Date.parse(r.started);
  if (!start) return "";
  const end = r.ended ? Date.parse(r.ended) : r.live ? Date.now() : NaN;
  return Number.isFinite(end) ? ago((end - start) / 1000) : "";
}

function when(iso) {
  const t = Date.parse(iso);
  if (!t) return "-";
  return new Date(t).toLocaleString("en-GB", { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
}

async function refresh() {
  try {
    const [tsv, pushed] = await Promise.all([get("runs.tsv"), get("pushed.txt")]);
    pushedAt = Number(pushed.trim()) || 0;
    const t = parseTsv(tsv);
    runs = t.rows.map(row => Object.fromEntries(t.cols.map((c, i) => [c, row[i] || ""]))).reverse();
    for (const r of runs) r.live = r.state === "running" || r.state === "paused";
    if (!runs.some(r => r.run === selected)) selected = runs.length ? runs[0].run : "";
    renderList();
    await renderDetail(false);
  } catch (e) {
    document.getElementById("age").textContent = `could not load: ${e.message}`;
  }
  renderAge();
}

function renderAge() {
  const age = document.getElementById("age");
  if (!pushedAt) return;
  const s = Date.now() / 1000 - pushedAt;
  age.textContent = `Mac sent ${ago(s)} ago`;
  // Live runs mean regular uploads: none for a while means the Mac slept or lost network
  const stale = runs.some(r => r.live) && s > STALE_S;
  age.className = stale ? "stale" : "muted";
  if (stale) age.textContent += ", nothing since: Mac asleep or offline?";
}

function renderList() {
  const nav = document.getElementById("runs");
  nav.replaceChildren();
  if (!runs.length) {
    nav.append(el("p", { class: "empty" }, "No runs yet. Start one with deploy/lab-run.sh start mac NAME -- ARGS."));
    return;
  }
  for (const r of runs) {
    const b = el("button", { class: "run", type: "button" });
    if (r.run === selected) b.setAttribute("aria-current", "true");
    const pill = el("span", { class: `pill ${stateClass(r.state)}` }, stateLabel(r.state));
    b.append(el("div", { class: "top" }, el("span", { class: "name" }, shortName(r.run)), pill));
    b.append(el("div", { class: "muted" }, `${when(r.started)}${duration(r) ? ", " + duration(r) : ""}`));
    if (r.last) b.append(el("div", { class: "last" }, r.last));
    b.addEventListener("click", () => {
      selected = r.run;
      history.replaceState(null, "", `#run=${encodeURIComponent(r.run)}`);
      renderList();
      renderDetail(true);
    });
    nav.append(b);
  }
}

// Columns sharing the part after the last _ share a chart: train_loss and test_loss
function groups(cols) {
  const out = new Map();
  for (const c of cols.slice(1)) {
    const i = c.lastIndexOf("_");
    const key = i > 0 ? c.slice(i + 1) : c;
    if (!out.has(key)) out.set(key, []);
    out.get(key).push(c);
  }
  return out;
}

// Colour follows the series name (train, test, ...) across every chart of a run
function seriesColours(cols) {
  const names = [];
  for (const c of cols.slice(1)) {
    const i = c.lastIndexOf("_");
    const n = i > 0 ? c.slice(0, i) : c;
    if (!names.includes(n)) names.push(n);
  }
  const css = getComputedStyle(document.documentElement);
  return c => {
    const i = c.lastIndexOf("_");
    const idx = names.indexOf(i > 0 ? c.slice(0, i) : c);
    return css.getPropertyValue(SERIES[Math.min(idx, SERIES.length - 1)]).trim();
  };
}

async function renderDetail(force) {
  const box = document.getElementById("detail");
  const r = runs.find(x => x.run === selected);
  if (!r) {
    box.replaceChildren(el("p", { class: "empty" }, "Nothing selected."));
    shownKey = "";
    return;
  }
  const [metrics, log] = await Promise.all([
    get(`runs/${encodeURIComponent(r.run)}/metrics.tsv`).catch(() => ""),
    get(`runs/${encodeURIComponent(r.run)}/log.txt`).catch(() => ""),
  ]);
  const key = [r.run, r.state, r.ended, metrics, log].join("\u0000");
  if (!force && key === shownKey) return;
  shownKey = key;
  const openLog = box.querySelector("details.log")?.open ?? false;
  const openTable = box.querySelector("details.table")?.open ?? false;

  box.replaceChildren();
  box.append(el("div", { class: "top" }, el("h2", {}, shortName(r.run))));
  const facts = el("div", { class: "facts" },
    el("span", { class: `pill ${stateClass(r.state)}` }, stateLabel(r.state)),
    el("span", {}, `started ${when(r.started)}`),
  );
  if (duration(r)) facts.append(el("span", {}, `${r.live ? "running for" : "took"} ${duration(r)}`));
  if (r.head) facts.append(el("span", {}, `at ${r.head}${r.dirty && r.dirty !== "0 files" ? ` + ${r.dirty} changed` : ""}`));
  if (r.args) facts.append(el("code", {}, r.args));
  box.append(facts);

  const t = parseTsv(metrics);
  const rows = t.rows.map(row => row.map(Number)).filter(row => Number.isFinite(row[0]));
  if (rows.length && t.cols.length > 1) {
    const charts = el("div", { class: "charts" });
    box.append(charts);
    const colour = seriesColours(t.cols);
    for (const [name, cols] of groups(t.cols)) {
      const series = cols.map(c => ({ name: c, colour: colour(c), values: rows.map(row => row[t.cols.indexOf(c)]) }));
      chart(charts, name, t.cols[0], rows.map(row => row[0]), series);
    }
    const table = el("table", {}, el("tr", {}, ...t.cols.map(c => el("th", {}, c))));
    for (const row of rows.slice(-30).reverse()) table.append(el("tr", {}, ...row.map(v => el("td", {}, fmt(v)))));
    const det = el("details", { class: "table" }, el("summary", {}, `Table (last ${Math.min(30, rows.length)} of ${rows.length} rows)`), el("div", { class: "table-wrap" }, table));
    det.open = openTable;
    box.append(det);
  } else {
    box.append(el("p", { class: "muted" }, "No metrics yet: the run reports by appending rows to metrics.tsv in its directory."));
  }

  const pre = el("pre", {}, log || "(empty log)");
  const det = el("details", { class: "log" }, el("summary", {}, "Log (last 300 lines)"), pre);
  det.open = openLog || !rows.length;
  box.append(det);
  pre.scrollTop = pre.scrollHeight;
  det.addEventListener("toggle", () => { pre.scrollTop = pre.scrollHeight; });
}

function niceTicks(lo, hi, n) {
  const span = hi - lo || Math.abs(hi) || 1;
  const raw = span / n;
  const mag = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 2.5, 5, 10].map(m => m * mag).find(s => s >= raw);
  const out = [];
  for (let v = Math.ceil(lo / step) * step; v <= hi + step * 1e-9; v += step) out.push(+v.toPrecision(12));
  return out;
}

function chart(parent, title, xName, xs, series) {
  const fig = el("figure");
  fig.append(el("h3", {}, series.length === 1 ? series[0].name : title));
  if (series.length > 1) {
    const legend = el("ul", { class: "legend" });
    for (const s of series) {
      const key = el("span", { class: "key" });
      key.style.background = s.colour;
      legend.append(el("li", {}, key, s.name));
    }
    fig.append(legend);
  }
  const plot = el("div");
  const tip = el("div", { class: "tip", hidden: "" });
  fig.append(plot, tip);
  parent.append(fig);

  const all = series.flatMap(s => s.values).filter(Number.isFinite);
  let lo = Math.min(...all), hi = Math.max(...all);
  const pad = (hi - lo) * 0.08 || Math.abs(hi) * 0.01 || 1;
  lo -= pad;
  hi += pad;
  const yTicks = niceTicks(lo, hi, 4);
  const x0 = xs[0], x1 = xs[xs.length - 1];

  const draw = () => {
    const W = Math.max(plot.clientWidth, 240), H = 180;
    const L = 8 + 7 * Math.max(...yTicks.map(v => fmt(v).length)), R = 10, T = 8, B = 22;
    const px = x => L + (x1 === x0 ? 0.5 : (x - x0) / (x1 - x0)) * (W - L - R);
    const py = y => T + (1 - (y - lo) / (hi - lo)) * (H - T - B);
    const s = svg("svg", { viewBox: `0 0 ${W} ${H}`, height: H, role: "img", "aria-label": `${title} by ${xName}` });
    for (const v of yTicks) {
      s.append(svg("line", { class: "grid", x1: L, x2: W - R, y1: py(v), y2: py(v) }));
      const t = svg("text", { x: L - 6, y: py(v) + 4, "text-anchor": "end" });
      t.textContent = fmt(v);
      s.append(t);
    }
    s.append(svg("line", { class: "base", x1: L, x2: W - R, y1: H - B, y2: H - B }));
    for (const v of niceTicks(x0, x1, Math.max(3, Math.floor(W / 110)))) {
      if (v < x0 || v > x1) continue;
      const t = svg("text", { x: px(v), y: H - 6, "text-anchor": "middle" });
      t.textContent = fmt(v);
      s.append(t);
    }
    const xl = svg("text", { x: W - R, y: H - B - 6, "text-anchor": "end" });
    xl.textContent = xName;
    s.append(xl);
    for (const ser of series) {
      const pts = ser.values.map((v, i) => Number.isFinite(v) ? `${px(xs[i]).toFixed(1)},${py(v).toFixed(1)}` : null).filter(Boolean);
      if (pts.length === 1) s.append(svg("circle", { cx: pts[0].split(",")[0], cy: pts[0].split(",")[1], r: 4, fill: ser.colour }));
      else s.append(svg("polyline", { class: "line", points: pts.join(" "), stroke: ser.colour }));
    }
    const cross = svg("line", { class: "cross", y1: T, y2: H - B, visibility: "hidden" });
    const dots = series.map(ser => svg("circle", { class: "dot", r: 5, fill: ser.colour, visibility: "hidden" }));
    s.append(cross, ...dots);
    const hit = svg("rect", { x: L, y: 0, width: W - L - R, height: H, fill: "transparent" });
    s.append(hit);

    const show = ev => {
      const box = s.getBoundingClientRect();
      const mx = (ev.clientX - box.left) * (W / box.width);
      let best = 0;
      for (let i = 1; i < xs.length; i++) if (Math.abs(px(xs[i]) - mx) < Math.abs(px(xs[best]) - mx)) best = i;
      const cx = px(xs[best]);
      cross.setAttribute("x1", cx);
      cross.setAttribute("x2", cx);
      cross.setAttribute("visibility", "visible");
      tip.replaceChildren(el("div", { class: "x" }, `${xName} ${fmt(xs[best])}`));
      series.forEach((ser, i) => {
        const v = ser.values[best];
        const ok = Number.isFinite(v);
        dots[i].setAttribute("visibility", ok ? "visible" : "hidden");
        if (ok) {
          dots[i].setAttribute("cx", cx);
          dots[i].setAttribute("cy", py(v));
        }
        const key = el("span", { class: "key" });
        key.style.background = ser.colour;
        tip.append(el("div", {}, key, el("b", {}, fmt(v)), el("span", {}, ser.name)));
      });
      tip.hidden = false;
      const left = (cx / W) * box.width;
      const tw = tip.offsetWidth;
      tip.style.left = `${Math.min(Math.max(0, left + 12 + tw > box.width ? left - tw - 12 : left + 12), Math.max(0, box.width - tw))}px`;
      tip.style.top = `${plot.offsetTop + 8}px`;
    };
    const hide = () => {
      cross.setAttribute("visibility", "hidden");
      dots.forEach(d => d.setAttribute("visibility", "hidden"));
      tip.hidden = true;
    };
    hit.addEventListener("pointermove", show);
    hit.addEventListener("pointerdown", show);
    hit.addEventListener("pointerleave", hide);
    plot.replaceChildren(s);
  };
  let lastW = 0;
  new ResizeObserver(() => {
    if (plot.clientWidth !== lastW) {
      lastW = plot.clientWidth;
      draw();
    }
  }).observe(plot);
}

refresh();
setInterval(refresh, POLL_MS);
setInterval(renderAge, 5000);
document.addEventListener("visibilitychange", () => { if (!document.hidden) refresh(); });
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => renderDetail(true));

// Champion page filters (root.zig filterBar, filters.zig). The champion's filter data has
// one row per region, rank, patch, 30-day flag, role and lane opponent with games, wins
// and gold at 14; this sums the rows the bar picks and redraws each role's win rate and
// games tiles and its opponent table. The page as written is the bar's defaults, put
// back as it was on Reset. Picks live in the URL so a view can be shared.
"use strict";

(async () => {
  const bar = document.querySelector(".filter-bar[data-src]");
  if (!bar) return;
  let data, champs;
  try {
    const get = (url) => fetch(url).then((r) => (r.ok ? r.json() : Promise.reject(r.status)));
    [data, champs] = await Promise.all([get(bar.dataset.src), get(bar.dataset.champions)]);
  } catch {
    return;
  }
  const byId = new Map(champs.champions.map((c) => [c.id, c]));
  const field = (f) => bar.querySelector(`[data-f="${f}"]`);
  const add = (select, value, text) => select.append(new Option(text, value));
  const titleCase = (s) => s.charAt(0) + s.slice(1).toLowerCase();

  const region = field("region");
  add(region, "all", "All regions");
  for (const p of data.platforms) add(region, p, platformName(p));
  const rank = field("rank");
  add(rank, "", "All ranks");
  data.tiers.forEach((t, i) => add(rank, String(i), `${titleCase(t)}+`));
  const period = field("period");
  add(period, "days30", "Last 30 days");
  for (const i of data.order) {
    const p = data.patches[i];
    add(period, `patch:${p}`, data.current.includes(p) ? `Patch ${p}` : `Patch ${p} (last 30 days)`);
  }
  const min = field("min");
  for (const [v, t] of [
    ["0", "All"], ["5", "5+ games"], ["10", "10+ games"], ["20", "20+ games"], ["50", "50+ games"],
    ["100", "100+ games"], ["p1", "Seen in 1%+ of games"], ["p2", "Seen in 2%+ of games"],
  ]) add(min, v, t);

  const defaults = {
    region: bar.dataset.region,
    rank: "",
    period: bar.dataset.period === "patch" ? `patch:${data.current[0]}` : "days30",
    min: "0",
  };
  const selects = { region, rank, period, min };
  const params = new URLSearchParams(location.search);
  for (const [k, s] of Object.entries(selects)) {
    const want = params.get(k) ?? defaults[k];
    s.value = [...s.options].some((o) => o.value === want) ? want : defaults[k];
  }

  const scope = document.querySelector("[data-scope]");
  const sections = [...document.querySelectorAll("main section[id]")]
    .map((el) => ({ el, role: data.roles.indexOf(el.id) }))
    .filter((s) => s.role >= 0)
    .map((s) => {
      const body = s.el.querySelector("table.tl tbody");
      const originalRows = new Map();
      for (const tr of body?.rows ?? []) originalRows.set(Number(tr.dataset.id), tr);
      return {
        ...s,
        body,
        originalRows,
        original: {
          tiles: s.el.querySelector(".tiles")?.innerHTML,
          body: body?.innerHTML,
          count: s.el.querySelector(".opp-h .muted")?.textContent,
          more: s.el.querySelector(".tl-more")?.textContent,
        },
      };
    });
  const originalScope = scope?.textContent;

  const picks = () => Object.fromEntries(Object.entries(selects).map(([k, s]) => [k, s.value]));
  const isDefault = (f) => Object.keys(defaults).every((k) => f[k] === defaults[k]);

  function sum(f) {
    const platform = f.region === "all" ? -1 : data.platforms.indexOf(f.region);
    const minTier = f.rank === "" ? -1 : Number(f.rank);
    const patch = f.period.startsWith("patch:") ? data.patches.indexOf(f.period.slice(6)) : -1;
    const roles = data.roles.map(() => ({ games: 0, wins: 0, opps: new Map() }));
    for (const [pl, ti, pa, recent, role, opp, g, w, gn, gs, gq] of data.rows) {
      if (platform >= 0 && pl !== platform) continue;
      if (minTier >= 0 && (ti < minTier || ti >= data.tiers.length)) continue;
      if (patch >= 0 ? pa !== patch : !recent) continue;
      const r = roles[role];
      r.games += g;
      r.wins += w;
      let o = r.opps.get(opp);
      if (!o) r.opps.set(opp, (o = { id: opp, games: 0, wins: 0, gn: 0, gs: 0, gq: 0 }));
      o.games += g;
      o.wins += w;
      o.gn += gn;
      o.gs += gs;
      o.gq += gq;
    }
    return roles;
  }

  function scopeText(f) {
    const where = f.region === "all" ? "across all regions" : `in ${platformName(f.region)}`;
    const when = f.period === "days30" ? "last 30 days" : `patch ${f.period.slice(6)}`;
    const ranks = f.rank === "" ? "all ranks" : `${titleCase(data.tiers[Number(f.rank)])} and above`;
    return `${where}, ${when}, ${ranks}`;
  }

  function apply() {
    const f = picks();
    const fresh = isDefault(f);
    bar.querySelector("[data-reset]").hidden = fresh;
    const q = new URLSearchParams();
    for (const k of Object.keys(defaults)) if (f[k] !== defaults[k]) q.set(k, f[k]);
    history.replaceState(null, "", q.size ? `?${q}${location.hash}` : location.pathname + location.hash);
    if (scope) scope.textContent = fresh ? originalScope : scopeText(f);
    const sums = fresh ? null : sum(f);
    for (const s of sections) {
      if (fresh) restore(s);
      else draw(s, sums[s.role], f);
      // Re-run the table's name search over the new rows
      s.el.querySelector("input[data-filter]")?.dispatchEvent(new Event("input"));
    }
  }

  function restore(s) {
    const tiles = s.el.querySelector(".tiles");
    if (tiles) tiles.innerHTML = s.original.tiles;
    if (s.body) s.body.innerHTML = s.original.body;
    const count = s.el.querySelector(".opp-h .muted");
    if (count) count.textContent = s.original.count;
    const more = s.el.querySelector(".tl-more");
    if (more) {
      more.textContent = s.original.more;
      more.hidden = false;
    }
  }

  function draw(s, r, f) {
    const tiles = s.el.querySelector(".tiles");
    if (tiles) {
      tiles.innerHTML = s.original.tiles;
      const iv = wilson(r.wins, r.games);
      const wr = tiles.querySelector('[data-tile="wr"]');
      wr.querySelector("b").className = side(iv);
      wr.querySelector("b").textContent = pct(r.wins, r.games);
      wr.querySelector("small").textContent = `${(100 * iv[0]).toFixed(1)}% to ${(100 * iv[1]).toFixed(1)}%`;
      tiles.querySelector('[data-tile="games"] b').textContent = r.games;
      for (const t of tiles.querySelectorAll('[data-tile="view"]')) {
        t.classList.add("stale");
        t.title = "For the page's own region and period, not the filters";
      }
    }
    if (!s.body) return;
    const floor = f.min.startsWith("p") ? (Number(f.min.slice(1)) / 100) * r.games : Number(f.min);
    const thin = 10;
    const opps = [...r.opps.values()].filter((o) => o.games >= Math.max(1, floor));
    opps.sort((x, y) => {
      const xt = x.games < thin, yt = y.games < thin;
      if (xt !== yt) return xt ? 1 : -1;
      if (xt) return y.games - x.games;
      return x.wins / x.games - y.wins / y.games;
    });
    s.body.replaceChildren(...opps.map((o) => row(s, o, o.games < thin)));
    const count = s.el.querySelector(".opp-h .muted");
    if (count) count.textContent = `${opps.length}, hardest first`;
    const few = opps.filter((o) => o.games < thin).length;
    const more = s.el.querySelector(".tl-more");
    if (more) {
      more.hidden = few === 0;
      more.textContent = `Faded: the last ${few} opponents, under ${thin} games each, too few to read much into.`;
    }
  }

  function row(s, o, thin) {
    const tr = document.createElement("tr");
    const ch = byId.get(o.id);
    tr.dataset.id = o.id;
    tr.dataset.name = ch?.name ?? String(o.id);
    if (thin) tr.className = "thin";
    const before = s.originalRows.get(o.id);
    const name = before ? before.cells[0].cloneNode(true) : nameCell(ch);
    const goldLink = before?.cells[2]?.querySelector("a")?.getAttribute("href");
    tr.append(name, winRateCell(o.wins, o.games, 0.25), goldCell(o, goldLink), gamesCell(o.games));
    return tr;
  }

  function nameCell(ch) {
    const td = document.createElement("td");
    td.className = "l";
    if (!ch) return td;
    const a = document.createElement("a");
    a.className = "champ";
    a.href = `../champion/${ch.slug}.html`;
    const img = document.createElement("img");
    img.src = `https://ddragon.leagueoflegends.com/cdn/${bar.dataset.ddragon}/img/champion/${ch.key}.png`;
    img.alt = "";
    img.loading = "lazy";
    img.width = img.height = 32;
    a.append(img, ch.name);
    td.append(a);
    return td;
  }

  // As root.zig winRateCell: the interval as a bar on 50% ± span, the rate as a dot
  function winRateCell(wins, games, span) {
    const iv = wilson(wins, games);
    const p = games ? wins / games : 0;
    const at = (x) => (100 * (Math.min(Math.max(x, 0.5 - span), 0.5 + span) - (0.5 - span))) / (2 * span);
    const td = document.createElement("td");
    td.dataset.v = p.toFixed(4);
    td.innerHTML =
      `<span class="wr" style="--c:oklch(0.76 0.15 ${hue(p, span).toFixed(0)})">` +
      `<span class="ci" title="95%: ${(100 * iv[0]).toFixed(1)}% to ${(100 * iv[1]).toFixed(1)}%, ${games} games">` +
      `<i class="r" style="left:${at(iv[0]).toFixed(1)}%;width:${(at(iv[1]) - at(iv[0])).toFixed(1)}%"></i>` +
      `<i class="d" style="left:${at(p).toFixed(1)}%"></i></span>` +
      `<b>${(100 * p).toFixed(1)}%</b><small>±${(50 * (iv[1] - iv[0])).toFixed(1)}</small></span>`;
    return td;
  }

  // Raw mean of the gold difference at 14 with ± two standard errors; filtered games
  // have no lane curve fit, so this is the plain average, not the curve's estimate
  function goldCell(o, href) {
    const td = document.createElement("td");
    if (o.gn < 2) {
      td.className = "dim";
      td.dataset.v = "";
      return td;
    }
    const mean = o.gs / o.gn;
    const variance = Math.max(0, (o.gq - o.gn * mean * mean) / (o.gn - 1));
    const margin = 2 * Math.sqrt(variance / o.gn);
    const cls = mean > margin ? "up" : mean < -margin ? "down" : "even";
    const m = Math.round(mean);
    td.dataset.v = m;
    const value = document.createElement(href ? "a" : "span");
    value.className = `gold ${cls}`;
    if (href) {
      value.href = href;
      value.title = "Lane curves";
    }
    value.textContent = `${m > 0 ? "+" : ""}${m}`;
    const small = document.createElement("small");
    small.textContent = `±${Math.round(margin)}`;
    td.append(value, small);
    return td;
  }

  function gamesCell(games) {
    const td = document.createElement("td");
    td.className = "dim";
    td.dataset.v = games;
    td.textContent = games;
    return td;
  }

  for (const s of Object.values(selects)) s.addEventListener("change", apply);
  bar.querySelector("[data-reset]").addEventListener("click", () => {
    for (const [k, s] of Object.entries(selects)) s.value = defaults[k];
    apply();
  });
  bar.hidden = false;
  if (!isDefault(picks())) apply();
})();

// As root.zig wilson: 95% interval of a win rate
function wilson(wins, games) {
  if (!games) return [0, 1];
  const z = 1.96, n = games, p = wins / n;
  const d = 1 + (z * z) / n;
  const c = (p + (z * z) / (2 * n)) / d;
  const h = (z * Math.sqrt((p * (1 - p)) / n + (z * z) / (4 * n * n))) / d;
  return [c - h, c + h];
}

function side(iv) {
  return iv[0] > 0.5 ? "up" : iv[1] < 0.5 ? "down" : "even";
}

// As root.zig wrHue: red through amber to green, full at 50% ± 40% of the span
function hue(p, span) {
  const t = Math.min(Math.max((p - 0.5) / (0.4 * span), -1), 1);
  return 25 + ((150 - 25) * (t + 1)) / 2;
}

function pct(part, whole) {
  return whole ? `${((100 * part) / whole).toFixed(1)}%` : "-";
}

function platformName(p) {
  const names = { EUN1: "EUNE", LA1: "LAN", LA2: "LAS", OC1: "OCE" };
  return names[p] ?? p.replace(/\d+$/, "");
}

// Champion page filters (root.zig filterBar, filters.zig). The champion's filter data has
// one row per region, patch, 30-day flag, rank, role and lane opponent with games, wins
// and gold at 14, plus bans by the game's rank; data/filters.json has players per role
// and games by rank for pick and ban rates. This sums the rows the bar picks and
// redraws each role's tiles and opponent table, the early-data note and the header
// switches. The page as written is the bar's defaults (the root view), put back as it
// was on Reset. Picks live in the URL so a view can be shared; the views' own links use
// the same keys (html.View.query).
"use strict";

// As root.zig opponentTable: by the bar's top end, so few games can't top the list
const HARDEST = "hardest first, by the top of each bar";

(async () => {
  const bar = document.querySelector(".filter-bar[data-src]");
  if (!bar) return;
  let data, meta, champs;
  try {
    const get = (url) => fetch(url).then((r) => (r.ok ? r.json() : Promise.reject(r.status)));
    [data, meta, champs] = await Promise.all(
      [bar.dataset.src, bar.dataset.meta, bar.dataset.champions].map(get),
    );
  } catch {
    return;
  }
  const byId = new Map(champs.champions.map((c) => [c.id, c]));
  const self = byId.get(Number(bar.dataset.id));
  const field = (f) => bar.querySelector(`[data-f="${f}"]`);
  const titleCase = (s) => s.charAt(0) + s.slice(1).toLowerCase();
  const current = meta.current.length === 1 ? meta.current[0] : null;
  const home = bar.dataset.region;

  const defaults = { region: home, rank: "", period: "days30", min: "0" };
  const selects = { region: field("region"), rank: field("rank"), period: field("period"), min: field("min") };
  // "period=patch" from the views' links: the current patch, whichever it is now
  const fromUrl = (k, v) => (k === "period" && v === "patch" && current ? `patch:${current}` : v);
  const toUrl = (k, v) => (k === "period" && current && v === `patch:${current}` ? "patch" : v);
  const params = new URLSearchParams(location.search);
  for (const [k, s] of Object.entries(selects)) {
    const want = fromUrl(k, params.get(k) ?? defaults[k]);
    s.value = [...s.options].some((o) => o.value === want) ? want : defaults[k];
    s.disabled = false;
  }

  const scope = document.querySelector("[data-scope]");
  const early = document.querySelector("[data-early]");
  const sections = [...document.querySelectorAll("main section[id]")]
    .map((el) => ({ el, role: meta.roles.indexOf(el.id) }))
    .filter((s) => s.role >= 0)
    .map((s) => {
      const body = s.el.querySelector("table.tl tbody");
      const links = new Map();
      for (const tr of body?.rows ?? []) {
        const a = tr.cells[2]?.querySelector("a");
        if (a) links.set(Number(tr.dataset.id), a.getAttribute("href"));
      }
      return {
        ...s,
        body,
        links,
        original: {
          tiles: s.el.querySelector(".tiles")?.innerHTML,
          body: body?.innerHTML,
          count: s.el.querySelector(".opp-h .muted")?.textContent,
          more: s.el.querySelector(".tl-more")?.textContent,
        },
      };
    });
  const original = { scope: scope?.textContent, early: early?.innerHTML, earlyHidden: early?.hidden };

  const picks = () => Object.fromEntries(Object.entries(selects).map(([k, s]) => [k, s.value]));
  const isDefault = (f) => Object.keys(defaults).every((k) => f[k] === defaults[k]);
  const query = (f) => {
    const q = new URLSearchParams();
    for (const k of Object.keys(defaults)) if (f[k] !== defaults[k]) q.set(k, toUrl(k, f[k]));
    return q.size ? `?${q}` : "";
  };

  // The view (html.View) the region and period pick, if any: its directory and its key
  // in the curves' gold
  function viewOf(f) {
    const region = f.region === home ? "" : f.region === "all" ? "all/" : null;
    const period = f.period === "days30" ? "" : current && f.period === `patch:${current}` ? "patch/" : null;
    if (region === null || period === null) return null;
    return { dir: region + period, key: `${f.region}|${f.period}` };
  }

  // Curve gold at 14 by "region|period|rank", then role and opponent
  const gold = new Map();
  function curveGold(key) {
    if (!gold.has(key)) {
      const m = new Map();
      for (const [role, opp, mean, se, p10, p90] of data.gold[key] ?? []) m.set(role * 65536 + opp, { mean, se, p10, p90 });
      gold.set(key, m);
    }
    return gold.get(key);
  }

  function sum(f) {
    const platform = f.region === "all" ? -1 : data.platforms.indexOf(f.region);
    const minTier = f.rank === "" ? -1 : Number(f.rank);
    const patch = f.period.startsWith("patch:") ? data.patches.indexOf(f.period.slice(6)) : -1;
    const slice = (pl, pa, recent) =>
      (platform < 0 || pl === platform) && (patch >= 0 ? pa === patch : recent === 1);
    const ranked = (ti) => minTier < 0 || (ti >= minTier && ti < meta.tiers.length);
    const out = {
      roles: meta.roles.map(() => ({ games: 0, wins: 0, slots: 0, opps: new Map() })),
      players: 0,
      games: 0,
      bans: 0,
    };
    for (const [pl, pa, recent, ti, role, opp, g, w, gn, gs, gq] of data.rows) {
      if (!slice(pl, pa, recent) || !ranked(ti)) continue;
      const r = out.roles[role];
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
    for (const [pl, pa, recent, ti, role, n] of meta.slots) {
      if (!slice(pl, pa, recent) || !ranked(ti)) continue;
      out.players += n;
      out.roles[role].slots += n;
    }
    // Bans and games by the game's rank (filters.zig gameTier)
    for (const [pl, pa, recent, ti, n] of data.bans) if (slice(pl, pa, recent) && ranked(ti)) out.bans += n;
    for (const [pl, pa, recent, ti, n] of meta.games) if (slice(pl, pa, recent) && ranked(ti)) out.games += n;
    return out;
  }

  const when = (f) => (f.period === "days30" ? "last 30 days" : `patch ${f.period.slice(6)}`);

  function scopeText(f) {
    const where = f.region === "all" ? "across all regions" : `in ${platformName(f.region)}`;
    const ranks = f.rank === "" ? "all ranks" : `${titleCase(meta.tiers[Number(f.rank)])} and above`;
    return `${where}, ${when(f)}, ${ranks}`;
  }

  // Region and period switches in the header: the one the filters are on is current;
  // a click sets the bar instead of loading the page again
  // Relative, so the site also works from disk; "?" alone still drops the picks
  const file = location.pathname.split("/").pop();
  const switches = [...document.querySelectorAll(".subbar .filters a[data-region], .subbar .filters a[data-period]")];
  const switchPick = (a) =>
    a.dataset.region
      ? ["region", a.dataset.region === "all" ? "all" : home]
      : ["period", a.dataset.period === "patch" && current ? `patch:${current}` : "days30"];
  function drawSwitches(f) {
    for (const a of switches) {
      const [k, v] = switchPick(a);
      if (f[k] === v) {
        a.setAttribute("aria-current", "page");
        a.removeAttribute("href");
      } else {
        a.removeAttribute("aria-current");
        a.href = file + (query({ ...f, [k]: v }) || "?");
      }
    }
  }
  for (const a of switches) {
    a.addEventListener("click", (e) => {
      const [k, v] = switchPick(a);
      if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || ![...selects[k].options].some((o) => o.value === v)) return;
      e.preventDefault();
      selects[k].value = v;
      apply();
    });
  }

  function apply() {
    const f = picks();
    const fresh = isDefault(f);
    bar.querySelector("[data-reset]").hidden = fresh;
    history.replaceState(null, "", location.pathname + query(f) + location.hash);
    drawSwitches(f);
    const view = viewOf(f);
    // Nav links (Champions, Matchups, Pool) into the view the filters are on
    if (view && typeof meioView === "function") meioView(view.dir);
    if (scope) scope.textContent = fresh ? original.scope : scopeText(f);
    const sums = fresh ? null : sum(f);
    if (early) {
      if (fresh) {
        early.innerHTML = original.early;
        early.hidden = original.earlyHidden;
      } else {
        const games = Math.round(sums.players / 10);
        early.hidden = games >= Number(early.dataset.early);
        early.querySelector("[data-early-games]").textContent = `${games} games so far (${when(f)})`;
      }
    }
    for (const s of sections) {
      if (fresh) restore(s);
      else draw(s, sums, f, view);
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

  function draw(s, sums, f, view) {
    const r = sums.roles[s.role];
    const tiles = s.el.querySelector(".tiles");
    if (tiles) {
      tiles.innerHTML = s.original.tiles;
      const iv = wilson(r.wins, r.games);
      const wr = tiles.querySelector('[data-tile="wr"]');
      wr.querySelector("b").className = side(iv);
      wr.querySelector("b").textContent = pct(r.wins, r.games);
      wr.querySelector("small").textContent = `${(100 * iv[0]).toFixed(1)}% to ${(100 * iv[1]).toFixed(1)}%`;
      // Two players per role and game
      tiles.querySelector('[data-tile="pick"] b').textContent = pct(2 * r.games, r.slots);
      const ban = tiles.querySelector('[data-tile="ban"]');
      ban.querySelector("b").textContent = pct(sums.bans, sums.games);
      if (f.rank !== "") ban.title = "Of games whose players' middle rank is in the filter";
      tiles.querySelector('[data-tile="games"] b').textContent = r.games;
    }
    if (!s.body) return;
    const floor = f.min.startsWith("p") ? (Number(f.min.slice(1)) / 100) * r.games : Number(f.min);
    const thin = 10;
    const opps = [...r.opps.values()].filter((o) => o.games >= Math.max(1, floor));
    opps.sort((x, y) => {
      const xt = x.games < thin, yt = y.games < thin;
      if (xt !== yt) return xt ? 1 : -1;
      if (xt) return y.games - x.games;
      return wilson(x.wins, x.games)[1] - wilson(y.wins, y.games)[1];
    });
    const curve = view ? curveGold(`${view.key}|${f.rank}`) : null;
    const pages = view ? curveGold(`${view.key}|`) : null;
    const q = query(f);
    s.body.replaceChildren(
      ...opps.map((o) => {
        const k = s.role * 65536 + o.id;
        const href = !view
          ? s.links.get(o.id)
          : pages.has(k)
            ? matchupHref(view.dir, meta.roles[s.role], o.id)
            : null;
        return row(o, o.games < thin, curve?.get(k), href, q);
      }),
    );
    const count = s.el.querySelector(".opp-h .muted");
    if (count) count.textContent = `${opps.length}, ${HARDEST}`;
    const few = opps.filter((o) => o.games < thin).length;
    const more = s.el.querySelector(".tl-more");
    if (more) {
      more.hidden = few === 0;
      more.textContent = `Faded: the last ${few} opponents, under ${thin} games each, too few to read much into.`;
    }
  }

  // As matchup.zig path: from the lower champion id's side
  function matchupHref(dir, role, opp) {
    const other = byId.get(opp);
    if (!self || !other) return null;
    const [x, y] = self.id < other.id ? [self, other] : [other, self];
    return `../${dir}matchup/${role}/${x.slug}-vs-${y.slug}.html`;
  }

  function row(o, thin, curve, href, q) {
    const tr = document.createElement("tr");
    const ch = byId.get(o.id);
    tr.dataset.id = o.id;
    tr.dataset.name = ch?.name ?? String(o.id);
    if (thin) tr.className = "thin";
    tr.append(nameCell(ch, q), winRateCell(o.wins, o.games, 0.25), goldCell(o, curve, href), gamesCell(o.games));
    return tr;
  }

  // To the opponent's own page with the same filters
  function nameCell(ch, q) {
    const td = document.createElement("td");
    td.className = "l";
    if (!ch) return td;
    const a = document.createElement("a");
    a.className = "champ";
    a.href = `${ch.slug}.html${q}`;
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
      `<span class="wr" style="--c:${wrColour(p, span)}">` +
      `<span class="ci" title="95%: ${(100 * iv[0]).toFixed(1)}% to ${(100 * iv[1]).toFixed(1)}%, ${games} games">` +
      `<i class="r" style="left:${at(iv[0]).toFixed(1)}%;width:${(at(iv[1]) - at(iv[0])).toFixed(1)}%"></i>` +
      `<i class="d" style="left:${at(p).toFixed(1)}%"></i></span>` +
      `<b>${(100 * p).toFixed(1)}%</b><small>±${(50 * (iv[1] - iv[0])).toFixed(1)}</small></span>`;
    return td;
  }

  // Gold difference at 14, coloured when clear of even by two standard errors, then
  // where 8 games in 10 end: the lane curve's estimate where the filters are a view with
  // a curve for the matchup (as root.zig goldCell), else the plain average of the games
  // picked, its 10th to 90th percentile from the sd as if normal (only sums are sent)
  function goldCell(o, curve, href) {
    const td = document.createElement("td");
    let mean, margin, p10, p90;
    if (curve) {
      ({ mean, p10, p90 } = curve);
      margin = 2 * curve.se;
    } else if (o.gn >= 2) {
      mean = o.gs / o.gn;
      const sd = Math.sqrt(Math.max(0, (o.gq - o.gn * mean * mean) / (o.gn - 1)));
      margin = (2 * sd) / Math.sqrt(o.gn);
      p10 = mean - 1.2816 * sd;
      p90 = mean + 1.2816 * sd;
    } else {
      td.className = "dim";
      td.dataset.v = "";
      return td;
    }
    const cls = mean > margin ? "up" : mean < -margin ? "down" : "even";
    const m = Math.round(mean);
    td.dataset.v = m;
    const value = document.createElement(href ? "a" : "span");
    value.className = `gold ${cls}`;
    if (href) {
      value.href = href;
      value.title = "Lane curves";
    }
    if (!curve) value.title = (href ? "Lane curves. " : "") + "Plain average of the games picked";
    value.textContent = `${m > 0 ? "+" : ""}${m}`;
    const small = document.createElement("small");
    const sign = (x) => `${x > 0 ? "+" : ""}${Math.round(x)}`;
    small.textContent = `${sign(p10)} to ${sign(p90)}`;
    small.title = "8 games in 10";
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
  apply();
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

// As root.zig wrColour: orange below 50%, blue above, grey at 50%
function wrColour(p, span) {
  const t = Math.min(Math.max((p - 0.5) / (0.4 * span), -1), 1);
  return `oklch(0.76 ${(0.15 * Math.abs(t)).toFixed(3)} ${t < 0 ? 50 : 225})`;
}

function pct(part, whole) {
  return whole ? `${((100 * part) / whole).toFixed(1)}%` : "-";
}

function platformName(p) {
  const names = { EUN1: "EUNE", LA1: "LAN", LA2: "LAS", OC1: "OCE" };
  return names[p] ?? p.replace(/\d+$/, "");
}

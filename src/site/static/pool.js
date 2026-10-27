// Champion pool: pick your main(s), read data/pool.json (src/pool.zig).
// Main: {id, players, one_tricks, role?, also?: [[id, together, lift, base share]],
//   hard?: [[id, pp, games]], cover?: [{id, lift, lanes}], fallback?: [{id, together,
//   lift, lanes}]}; lanes are [[enemy id, pp, games]]. Lists only from min_players.
"use strict";

const ROLE_NAMES = {
  top: "top",
  jungle: "jungle",
  middle: "mid",
  bottom: "bot",
  utility: "support",
};

const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
const pts = (pp) => `${pp >= 0 ? "+" : ""}${pp.toFixed(1)}`;
const share = (x) => `${Math.round(100 * x)}%`;

function el(tag, attrs = {}, ...children) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") e.className = v;
    else e.setAttribute(k, v);
  }
  e.append(...children.filter((c) => c !== null && c !== undefined));
  return e;
}

async function start() {
  const status = document.getElementById("status");
  try {
    const [pool, meta, learning] = await Promise.all([
      fetch("data/pool.json").then((r) => r.json()),
      fetch("data/champions.json").then((r) => r.json()),
      // How hard to pick up is extra: the page works without it
      fetch("data/learning.json")
        .then((r) => r.json())
        .catch(() => null),
    ]);
    status.hidden = true;
    setup(pool, meta, learning);
  } catch (e) {
    status.textContent = "Could not load the pool data: " + e.message;
  }
}

// learning.json (src/learning.zig): {games, mean_pp, champions: [{id, kind: "harder" |
// "usual" | "easier", new: [win rate, games], practised: [win rate, games]}]}
const KIND_TEXT = {
  harder: "harder to pick up than most",
  usual: "usual to pick up",
  easier: "easier to pick up than most",
};

function learningLine(learning, id) {
  const c = learning?.champions.find((x) => x.id === id);
  if (!c) return "how hard to pick up: more data needed";
  const pct = (x) => `${(100 * x).toFixed(1)}%`;
  return `${KIND_TEXT[c.kind]}: new players win ${pct(c.new[0])}, practised ${pct(c.practised[0])}`;
}

function kindOf(learning, id) {
  return learning?.champions.find((x) => x.id === id)?.kind;
}

function setup(pool, meta, learning) {
  const byId = new Map(meta.champions.map((c) => [c.id, c]));
  const byName = new Map(meta.champions.map((c) => [norm(c.name), c]));
  const bySlug = new Map(meta.champions.map((c) => [c.slug, c]));
  const mains = new Map(pool.mains.map((m) => [m.id, m]));
  const list = document.getElementById("champions");
  for (const c of meta.champions) list.append(el("option", { value: c.name }));
  const inputs = [...document.querySelectorAll("[data-main]")];
  const out = document.getElementById("results");

  const icon = (c) =>
    `/icon/${meta.ddragon}/${c.key}.jpg`;
  const link = (id) => {
    const c = byId.get(id);
    if (!c) return el("span", {}, "?");
    return el(
      "a",
      { class: "champ box", href: `${out.dataset.toSite}champion/${c.slug}.html${out.dataset.query}` },
      el("img", { src: icon(c), alt: "", width: "32", height: "32", loading: "lazy" }),
      c.name,
    );
  };
  const nameOf = (id) => byId.get(id)?.name ?? "?";
  const card = (title, sub, ...body) =>
    el(
      "div",
      { class: "card" },
      el("h3", {}, title, sub ? el("span", { class: "muted" }, " " + sub) : null),
      ...body,
    );
  const empty = (text) => el("li", { class: "muted" }, text);

  // "59% of them (28% of others)", and how hard it is to pick up when it stands out
  const alsoItem = (id, k, base, players, main) => {
    const kind = kindOf(learning, id);
    return el(
      "li",
      { class: "bx" },
      el("span", {}, link(id)),
      el(
        "span",
        { class: "num", title: `${k} of ${players} ${nameOf(main)} players; ${share(base)} of other players` },
        `${share(k / players)} `,
        el("span", { class: "muted" }, `(${share(base)})`),
        kind && kind !== "usual" ? el("span", { class: "role" }, ` ${kind} to pick up`) : null,
      ),
    );
  };

  const alsoList = (m) => {
    const ul = el("ul", { class: "also" });
    if (!m.also?.length) ul.append(empty("No champion stands out yet"));
    for (const [id, k, , base] of m.also ?? []) ul.append(alsoItem(id, k, base, m.players, m.id));
    return ul;
  };

  const hardList = (m) => {
    const ul = el("ul");
    if (!m.hard?.length) ul.append(empty("None stands out: no lane is a point or more below even"));
    for (const [id, pp, games] of m.hard ?? []) {
      ul.append(
        el(
          "li",
          { class: "bx" },
          el("span", {}, link(id)),
          el("span", { class: "num bad", title: `${games} games` }, pts(pp)),
        ),
      );
    }
    return ul;
  };

  // Each option with its reasons, as in the draft helper
  const options = (items, why) => {
    const ul = el("ul", { class: "card suggestions" });
    for (const o of items) {
      const li = el("li", { class: "bx" }, el("div", {}, link(o.id)));
      for (const line of why(o)) li.append(el("div", { class: "why" }, line));
      ul.append(li);
    }
    return ul;
  };

  const renderMain = (id) => {
    const c = byId.get(id);
    const m = mains.get(id) ?? { id, players: 0, one_tricks: 0 };
    const box = el("section", { class: "pool-main" });
    box.append(el("h2", {}, link(id)));
    if (m.players < pool.min_players) {
      box.append(
        el(
          "p",
          { class: "note" },
          `Not enough players yet: ${m.players} with ${c.name} as their most played champion so far; lists start at ${pool.min_players}.`,
        ),
      );
      return box;
    }
    const role = m.role ? ROLE_NAMES[m.role] : null;
    box.append(
      el(
        "p",
        { class: "muted" },
        `${m.players} players main ${c.name}; for ${m.one_tricks} of them it is over half their ${pool.source === "mastery" ? "mastery points" : "games"}.`,
      ),
    );
    const hardPp = new Map((m.hard ?? []).map(([e, pp]) => [e, pp]));
    const grid = el("div", { class: "grid" });
    grid.append(card(`${c.name} players also play`, "share of them (of other players)", alsoList(m)));
    grid.append(card("Hard lanes", role ? `in ${role}` : null, hardList(m)));
    box.append(grid);

    box.append(el("h3", { class: "pool-h" }, `Options into ${c.name}'s hard lanes`));
    if (!m.cover?.length) {
      box.append(
        el(
          "p",
          { class: "muted" },
          m.hard?.length
            ? "None of the champions its players also play does a point or more better into those lanes."
            : "No hard lanes to cover.",
        ),
      );
    } else {
      box.append(
        options(m.cover, (o) => [
          ...o.lanes.map(
            ([e, pp, games]) =>
              `${pts(pp)} vs ${nameOf(e)} (${games} games; ${c.name} there: ${pts(hardPp.get(e) ?? 0)})`,
          ),
          `${share(m.also.find((a) => a[0] === o.id)?.[1] / m.players || 0)} of ${c.name} players play it`,
          learningLine(learning, o.id),
        ]),
      );
    }

    box.append(el("h3", { class: "pool-h" }, `When ${c.name} is banned`));
    if (!m.fallback?.length) {
      box.append(
        el(
          "p",
          { class: "muted" },
          "No champion its players also play does a point or more better into the same lanes.",
        ),
      );
    } else {
      box.append(
        options(m.fallback, (o) => [
          `${share(o.together / m.players)} of ${c.name} players play it`,
          "also good into " +
            o.lanes.map(([e, pp]) => `${nameOf(e)} (${pts(pp)})`).join(", "),
          learningLine(learning, o.id),
        ]),
      );
    }
    return box;
  };

  // With several mains: everything their players also play, in one list
  const renderCombined = (ids) => {
    const listed = ids
      .map((id) => mains.get(id))
      .filter((m) => m && m.players >= pool.min_players);
    if (listed.length < 2) return null;
    const best = new Map();
    for (const m of listed) {
      const id = m.id;
      for (const [other, k, lift, base] of m.also ?? []) {
        if (ids.includes(other)) continue;
        if (!best.has(other) || best.get(other).lift < lift)
          best.set(other, { main: id, k, lift, base, n: m.players });
      }
    }
    if (best.size === 0) return null;
    const ul = el("ul", { class: "also" });
    for (const [other, b] of [...best]
      .sort((x, y) => y[1].lift - x[1].lift)
      .slice(0, 12)) {
      const li = alsoItem(other, b.k, b.base, b.n, b.main);
      li.lastChild.append(el("span", { class: "role" }, ` with ${nameOf(b.main)}`));
      ul.append(li);
    }
    return el(
      "section",
      { class: "pool-main" },
      el("h2", {}, "Across your mains"),
      el("div", { class: "card" }, ul),
    );
  };

  const chosen = () => {
    const ids = [];
    for (const i of inputs) {
      const c = byName.get(norm(i.value));
      if (c && !ids.includes(c.id)) ids.push(c.id);
    }
    return ids;
  };

  const render = () => {
    const ids = chosen();
    out.replaceChildren();
    if (ids.length > 1) out.append(renderCombined(ids) ?? "");
    for (const id of ids) out.append(renderMain(id));
    const hash = ids.map((id) => byId.get(id).slug).join(",");
    history.replaceState(null, "", hash ? "#" + hash : location.pathname);
  };

  // pool.html#garen,darius from champion pages and shared links
  decodeURIComponent(location.hash.slice(1))
    .split(",")
    .map((s) => bySlug.get(s))
    .filter(Boolean)
    .slice(0, inputs.length)
    .forEach((c, i) => (inputs[i].value = c.name));
  document.getElementById("pool").addEventListener("input", render);
  render();
}

start();

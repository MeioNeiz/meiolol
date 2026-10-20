// Champion pool: pick your main(s), read data/pool.json (src/pool.zig).
// Main: {id, players, one_tricks, role?, also?: [[id, together, lift]],
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
const times = (lift) => `×${lift.toFixed(1)}`;

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
      // Learning curves are extra: the page works without them
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

// learning.json (src/learning.zig): {players, thin_games, bins: [first game of each],
// champions: [{id, usual, reach: bin index | null, bins: [[games, wins, gold games,
// mean gold]]}]}
function learningLine(learning, id) {
  const c = learning?.champions.find((x) => x.id === id);
  if (!c || c.bins[0][0] < learning.thin_games) return "learning curve: more data needed";
  const [games, wins] = c.bins[0];
  const first = `${learning.bins[1] - 1}`;
  const usual = (100 * c.usual).toFixed(1);
  let text = `first ${first} games on it: ${((100 * wins) / games).toFixed(1)}% (usual ${usual}%)`;
  if (c.reach === 0) text += ", about as well from the start";
  else if (c.reach !== null) {
    const lo = learning.bins[c.reach];
    const hi = learning.bins[c.reach + 1];
    text += `, usual by games ${hi ? `${lo}-${hi - 1}` : `${lo}+`}`;
  }
  return text;
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
    `https://ddragon.leagueoflegends.com/cdn/${meta.ddragon}/img/champion/${c.key}.png`;
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

  const alsoList = (m) => {
    const ul = el("ul", { class: "also" });
    if (!m.also?.length) ul.append(empty("No champion stands out yet"));
    for (const [id, k, lift] of m.also ?? []) {
      ul.append(
        el(
          "li",
          { class: "bx" },
          el("span", {}, link(id)),
          el(
            "span",
            { class: "num", title: `${k} of ${m.players} players` },
            times(lift),
          ),
        ),
      );
    }
    return ul;
  };

  const hardList = (m) => {
    const ul = el("ul");
    if (!m.hard?.length) ul.append(empty("Not enough lane games yet"));
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
    grid.append(card(`${c.name} players also play`, null, alsoList(m)));
    grid.append(card("Hard lanes", role ? `in ${role}` : null, hardList(m)));
    box.append(grid);

    box.append(el("h3", { class: "pool-h" }, `Options into ${c.name}'s hard lanes`));
    if (!m.cover?.length) {
      box.append(
        el(
          "p",
          { class: "muted" },
          "None of the champions its players also play does well into those lanes yet.",
        ),
      );
    } else {
      box.append(
        options(m.cover, (o) => [
          ...o.lanes.map(
            ([e, pp, games]) =>
              `${pts(pp)} vs ${nameOf(e)} (${games} games; ${c.name} there: ${pts(hardPp.get(e) ?? 0)})`,
          ),
          `played ${times(o.lift)} as often by ${c.name} players`,
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
          "No champion its players also play is good into the same lanes yet.",
        ),
      );
    } else {
      box.append(
        options(m.fallback, (o) => [
          `played by ${o.together} of ${m.players} ${c.name} players (${times(o.lift)} the usual rate)`,
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
      for (const [other, k, lift] of m.also ?? []) {
        if (ids.includes(other)) continue;
        if (!best.has(other) || best.get(other).lift < lift)
          best.set(other, { main: id, k, lift, n: m.players });
      }
    }
    if (best.size === 0) return null;
    const ul = el("ul", { class: "also" });
    for (const [other, b] of [...best]
      .sort((x, y) => y[1].lift - x[1].lift)
      .slice(0, 12)) {
      ul.append(
        el(
          "li",
          { class: "bx" },
          el("span", {}, link(other)),
          el(
            "span",
            { class: "num", title: `${b.k} of ${b.n} ${nameOf(b.main)} players` },
            `${times(b.lift)} `,
            el("span", { class: "role" }, `with ${nameOf(b.main)}`),
          ),
        ),
      );
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

// Draft helper: the app's recommender (src/wasm.zig) on the site's model file.
// Request: {role, allies: [{id, role}], enemies: [{id}], bans: [id], top, min_games}
// Reply: [{id, win, pp, games, reasons: [{kind, id, role, guessed, hover, pp, games}]}]
"use strict";

const ROLES = [
  ["top", "Top"],
  ["jungle", "Jungle"],
  ["middle", "Mid"],
  ["bottom", "Bot"],
  ["utility", "Support"],
];
const roleName = Object.fromEntries(ROLES);

const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, "");

async function start() {
  const status = document.getElementById("status");
  try {
    const [wasmBytes, model, meta] = await Promise.all([
      fetch("meiolol.wasm").then((r) => r.arrayBuffer()),
      fetch("data/stats.bin").then((r) => r.arrayBuffer()),
      fetch("data/champions.json").then((r) => r.json()),
    ]);
    const { instance } = await WebAssembly.instantiate(wasmBytes, {});
    const x = instance.exports;
    const put = (bytes) => {
      const ptr = x.alloc(bytes.length);
      new Uint8Array(x.memory.buffer, ptr, bytes.length).set(bytes);
      return ptr;
    };
    const modelBytes = new Uint8Array(model);
    if (x.load(put(modelBytes), modelBytes.length) !== 0) throw new Error("bad model file");
    status.hidden = true;
    setup(meta, (req) => {
      const bytes = new TextEncoder().encode(JSON.stringify(req));
      const ptr = put(bytes);
      const out = x.suggest(ptr, bytes.length);
      x.free(ptr, bytes.length);
      if (!out) return [];
      const text = new TextDecoder().decode(new Uint8Array(x.memory.buffer, out, x.result_len()));
      return JSON.parse(text);
    });
  } catch (e) {
    status.textContent = "Could not load the draft helper: " + e.message;
  }
}

function setup(meta, suggest) {
  const byId = new Map(meta.champions.map((c) => [c.id, c]));
  const byName = new Map(meta.champions.map((c) => [norm(c.name), c]));
  const list = document.getElementById("champions");
  for (const c of meta.champions) {
    const o = document.createElement("option");
    o.value = c.name;
    list.append(o);
  }
  const icon = (c) =>
    `https://ddragon.leagueoflegends.com/cdn/${meta.ddragon}/img/champion/${c.key}.png`;
  const find = (s) => byName.get(norm(s)) || null;

  const form = document.getElementById("draft");
  const myRole = form.elements.role;
  const allyInputs = [...form.querySelectorAll("[data-ally]")];
  const enemyInputs = [...form.querySelectorAll("[data-enemy]")];
  const banInput = form.elements.bans;
  const out = document.getElementById("suggestions");

  // Ally slots are the four roles other than mine
  const labelAllies = () => {
    const others = ROLES.filter(([r]) => r !== myRole.value);
    allyInputs.forEach((input, i) => {
      input.dataset.role = others[i][0];
      input.previousElementSibling.textContent = others[i][1];
    });
  };

  const render = () => {
    const allies = allyInputs
      .map((i) => ({ c: find(i.value), role: i.dataset.role }))
      .filter((p) => p.c)
      .map((p) => ({ id: p.c.id, role: p.role }));
    const enemies = enemyInputs.map((i) => find(i.value)).filter(Boolean).map((c) => ({ id: c.id }));
    const bans = banInput.value.split(",").map(find).filter(Boolean).map((c) => c.id);
    const minGames = Math.min(200, Math.max(5, Math.round(meta.games * 0.003)));
    const list = suggest({ role: myRole.value, allies, enemies, bans, top: 5, min_games: minGames });

    out.replaceChildren();
    if (list.length === 0) {
      out.innerHTML = '<li class="muted">No options with enough games in this role yet.</li>';
      return;
    }
    for (const s of list) {
      const c = byId.get(s.id);
      if (!c) continue;
      const li = document.createElement("li");
      const head = document.createElement("div");
      head.innerHTML =
        `<a class="champ" href="champion/${c.slug}.html"><img src="${icon(c)}" alt="" width="32" height="32"></a>`;
      head.querySelector("a").append(c.name);
      const games = document.createElement("span");
      games.className = "muted";
      games.textContent = ` ${s.games} games in ${roleName[myRole.value].toLowerCase()}`;
      head.append(games);
      li.append(head);
      for (const r of s.reasons) {
        const why = document.createElement("div");
        why.className = "why";
        why.textContent = describe(r, byId);
        li.append(why);
      }
      out.append(li);
    }
  };

  myRole.addEventListener("change", () => {
    labelAllies();
    render();
  });
  form.addEventListener("input", render);
  labelAllies();
  render();
}

function describe(r, byId) {
  const sign = r.pp >= 0 ? "+" : "";
  const pts = `${sign}${r.pp.toFixed(1)}`;
  const role = roleName[r.role].toLowerCase();
  if (r.kind === "base") {
    return `${pts} ${r.pp >= 0 ? "strong" : "weak"} in ${role} this patch`;
  }
  const other = byId.get(r.id);
  const name = other ? other.name : "?";
  const guess = r.guessed ? "?" : "";
  return `${pts} ${r.kind === "ally" ? "with" : "vs"} ${name} (${role}${guess})`;
}

start();

// Header search (html.zig head): a champion, a matchup ("Ahri vs Zed", "ahri zed",
// "ahri v zed") or a Riot ID (Name#TAG), with suggestions under the box; "/" focuses it.
// Names match ignoring case and punctuation: whole name, alias (mf, tf, j4), a prefix of
// the name or one of its words, part of it, then a typo (one, two from 7 letters). The
// index, data/search.json (search.zig), loads on first focus from the page's view; pages
// in no view (champion and shared pages) use the last one visited, as meioView does.
"use strict";

// The subbar's region picker (html.zig switches) closes on a click elsewhere or Escape
document.addEventListener("click", (e) => {
  for (const d of document.querySelectorAll("details.regions[open]")) if (!d.contains(e.target)) d.open = false;
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") for (const d of document.querySelectorAll("details.regions[open]")) d.open = false;
});

(() => {
  const script = document.currentScript;
  const form = document.querySelector("header form.look");
  if (!form) return;
  const input = form.elements.namedItem("id");
  const site = script.dataset.site ?? "";
  const views = ["", "patch/", "all/", "all/patch/"];
  const queries = ["", "?period=patch", "?region=all", "?region=all&period=patch"];
  const roleNames = { top: "Top", jungle: "Jungle", mid: "Mid", bot: "Bot", support: "Support" };
  const aliases = {
    "Miss Fortune": ["mf"], "Twisted Fate": ["tf"], "Jarvan IV": ["j4"], "Aurelion Sol": ["asol"],
    "LeBlanc": ["lb"], "Warwick": ["ww"], "Tahm Kench": ["tk"], "Gangplank": ["gp"],
    "Wukong": ["monkeyking"], "Nunu & Willump": ["nunu"], "Kog'Maw": ["kog"],
  };
  const norm = (s) => s.toLowerCase().normalize("NFD").replace(/[^a-z0-9]/g, "");
  // This tab has been on the site: filters.js fills picks a link leaves out
  addEventListener("pagehide", () => {
    try {
      sessionStorage.setItem("meio-in", "1");
    } catch {}
  });
  // [data-keep=KEY]: the radio picked inside (matchup curve tabs) kept in this browser
  for (const box of document.querySelectorAll("[data-keep]")) {
    const key = `keep:${box.dataset.keep}`;
    try {
      const saved = box.querySelector(`input[type=radio][id="${CSS.escape(localStorage.getItem(key) ?? "")}"]`);
      if (saved) saved.checked = true;
    } catch {}
    box.addEventListener("change", (e) => {
      try {
        if (e.target.checked) localStorage.setItem(key, e.target.id);
      } catch {}
    });
  }
  const viewDir = () => {
    if (script.hasAttribute("data-view")) return script.dataset.view;
    try {
      const v = localStorage.getItem("view");
      if (views.includes(v)) return v;
    } catch {}
    return "";
  };

  let index = null;
  let loading = null;
  let loadedView = null;
  const load = () => {
    const v = viewDir();
    if (loading && loadedView === v) return loading;
    loadedView = v;
    loading = fetch(`${site}${v}data/search.json`)
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(r.status))))
      .then((j) => {
        const n = j.champs.length;
        index = {
          ...j,
          n,
          champs: j.champs.map(([name, slug, key], i) => ({
            name, slug, key, i, n: norm(name),
            words: name.split(/[\s.'&]+/).map(norm).filter((x) => x),
            aliases: aliases[name] ?? [],
          })),
        };
        if (document.activeElement === input) update();
      })
      .catch(() => {
        loading = null;
      });
    return loading;
  };

  // Optimal string alignment distance, stopping early above `max`
  const distance = (a, b, max) => {
    if (Math.abs(a.length - b.length) > max) return max + 1;
    let prev2 = [];
    let prev = [...Array(b.length + 1).keys()];
    for (let i = 1; i <= a.length; i++) {
      const row = [i];
      let low = i;
      for (let j = 1; j <= b.length; j++) {
        const cost = a[i - 1] === b[j - 1] ? 0 : 1;
        let d = Math.min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + cost);
        if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) d = Math.min(d, prev2[j - 2] + 1);
        row.push(d);
        low = Math.min(low, d);
      }
      if (low > max) return max + 1;
      prev2 = prev;
      prev = row;
    }
    return prev[b.length];
  };

  const score = (q, c) => {
    if (!q) return 0;
    if (c.n === q || c.aliases.includes(q)) return 100;
    if (c.n.startsWith(q)) return 80;
    if (c.words.some((w) => w.startsWith(q))) return 70;
    if (q.length >= 2 && c.aliases.some((a) => a.startsWith(q))) return 65;
    if (q.length >= 3 && c.n.includes(q)) return 50;
    if (q.length < 4) return 0;
    const max = q.length >= 7 ? 2 : 1;
    const d = Math.min(
      distance(q, c.n, max),
      distance(q, c.n.slice(0, q.length), max),
      distance(q, c.n.slice(0, q.length + 1), max),
      ...c.words.filter((w) => w.length >= 4).map((w) => distance(q, w, max)),
    );
    return d <= max ? 40 - 10 * d : 0;
  };

  // Champions for `q`, best first
  const champs = (q, limit) => {
    const out = [];
    for (const c of index.champs) {
      const s = score(q, c);
      if (s > 0) out.push({ c, s });
    }
    out.sort((x, y) => y.s - x.s || x.c.name.length - y.c.name.length || x.c.name.localeCompare(y.c.name));
    return out.slice(0, limit);
  };

  const role = (a, b) => {
    if (a.i === b.i) return null;
    const i = Math.min(a.i, b.i);
    const j = Math.max(a.i, b.i);
    const ch = index.pairs[(i * (2 * index.n - i - 1)) / 2 + j - i - 1];
    return ch === "." || ch === undefined ? null : index.roles[Number(ch)];
  };

  const champHref = (c) => `${site}champion/${c.slug}.html${queries[views.indexOf(viewDir())]}`;
  const pairHref = (a, b, r) => `${site}${viewDir()}matchup/${r}/${a.slug}-vs-${b.slug}.html`;
  const idHref = (id) => `${site}your.html#id=${encodeURIComponent(id)}`;

  const recent = () => {
    try {
      const list = JSON.parse(localStorage.getItem("your-recent") ?? "[]");
      return Array.isArray(list) ? list.map((r) => r?.id).filter((id) => typeof id === "string") : [];
    } catch {
      return [];
    }
  };

  // Pairs from left and right texts: the left side's best few against the right's
  const pairs = (left, right, out) => {
    const ls = champs(left, 3);
    const rs = right ? champs(right, 8) : null;
    for (const { c: a, s: sa } of ls) {
      if (rs) {
        for (const { c: b, s: sb } of rs) {
          const r = role(a, b);
          if (r) out.push({ s: Math.min(sa, sb) + (sa + sb) / 1000, a, b, r });
        }
      } else if (sa >= 70) {
        // "ahri vs": every opponent with a page, by name
        for (const b of index.champs) {
          const r = role(a, b);
          if (r) out.push({ s: sa - 1, a, b, r });
        }
      }
    }
  };

  // Options for the text: {label, tag, href, icon}
  const options = (raw) => {
    const text = raw.trim();
    const ids = recent();
    if (!text) return ids.slice(0, 5).map((id) => ({ label: id, tag: "Your games", href: idHref(id) }));
    const lower = text.toLowerCase();
    const known = ids.filter((id) => id.toLowerCase().startsWith(lower));
    if (text.includes("#")) {
      const out = known.map((id) => ({ label: id, tag: "Your games", href: idHref(id) }));
      if (/^[^#]+#[^#]+$/.test(text) && !known.some((id) => id.toLowerCase() === lower)) {
        out.unshift({ label: `Look up ${text}`, tag: "Riot ID", href: idHref(text) });
      }
      return out;
    }
    if (!index) return [];
    const found = [];
    const sep = text.match(/^(.*?)\s+(?:vs?\.?|versus)(?:\s+(.*))?$/i) ?? text.match(/^(.*?)\s*[/,]\s*(.*)$/);
    if (sep && sep[1]) {
      pairs(norm(sep[1]), norm(sep[2] ?? ""), found);
    } else {
      for (const { c, s } of champs(norm(text), 6)) found.push({ s: s + 5, c });
      // Without "vs" a pair needs both names clear ("lee sin" is not Nidalee vs Singed)
      const words = text.split(/\s+/);
      const split = [];
      for (let k = 1; k < words.length; k++) {
        pairs(norm(words.slice(0, k).join("")), norm(words.slice(k).join("")), split);
      }
      const floor = found.length ? 65 : 30;
      found.push(...split.filter((f) => f.s >= floor));
    }
    found.sort((x, y) => y.s - x.s || (x.b && y.b ? x.b.name.localeCompare(y.b.name) : 0));
    const seen = new Set();
    const out = [];
    for (const f of found) {
      const key = f.c ? f.c.slug : `${f.a.slug}/${f.b.slug}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push(f.c
        ? { label: f.c.name, tag: "Champion", href: champHref(f.c), icon: f.c.key }
        : { label: `${f.a.name} vs ${f.b.name}`, tag: roleNames[f.r] ?? f.r, href: pairHref(f.a, f.b, f.r), icon: f.a.key, icon2: f.b.key });
      if (out.length === 8) break;
    }
    for (const id of known.slice(0, 2)) out.push({ label: id, tag: "Your games", href: idHref(id) });
    return out;
  };

  const list = document.createElement("div");
  list.className = "look-list";
  list.id = "look-list";
  list.setAttribute("role", "listbox");
  list.setAttribute("aria-label", "Suggestions");
  list.hidden = true;
  form.append(list);
  input.type = "search";
  input.setAttribute("role", "combobox");
  input.setAttribute("aria-autocomplete", "list");
  input.setAttribute("aria-controls", list.id);
  input.setAttribute("aria-expanded", "false");
  // Keeps the focus in the box, so a tap on an option is not lost to the blur
  list.addEventListener("pointerdown", (e) => e.preventDefault());

  let shown = [];
  let active = -1;
  const icon = (key) => {
    const img = document.createElement("img");
    img.src = `https://ddragon.leagueoflegends.com/cdn/${index.ddragon}/img/champion/${key}.png`;
    img.alt = "";
    img.width = img.height = 22;
    return img;
  };
  const setActive = (i) => {
    active = i;
    shown.forEach((a, j) => a.setAttribute("aria-selected", String(j === i)));
    if (i >= 0) {
      input.setAttribute("aria-activedescendant", shown[i].id);
      shown[i].scrollIntoView({ block: "nearest" });
    } else input.removeAttribute("aria-activedescendant");
  };
  const close = () => {
    list.hidden = true;
    input.setAttribute("aria-expanded", "false");
    setActive(-1);
  };
  function update() {
    const opts = options(input.value);
    list.replaceChildren();
    shown = opts.map((o, i) => {
      const a = document.createElement("a");
      a.id = `look-opt-${i}`;
      a.href = o.href;
      a.setAttribute("role", "option");
      a.tabIndex = -1;
      if (o.icon && index) a.append(icon(o.icon));
      if (o.icon2 && index) a.append(icon(o.icon2));
      const label = document.createElement("span");
      label.textContent = o.label;
      const tag = document.createElement("small");
      tag.textContent = o.tag;
      a.append(label, tag);
      list.append(a);
      return a;
    });
    if (!shown.length && input.value.trim() && (index || input.value.includes("#"))) {
      const p = document.createElement("p");
      p.textContent = input.value.includes("#")
        ? "A Riot ID is Name#TAG, for example Faker#KR1."
        : "No champion or matchup by that name. A Riot ID needs its tag: Name#TAG.";
      list.append(p);
    }
    list.hidden = !list.childElementCount;
    input.setAttribute("aria-expanded", String(!list.hidden));
    setActive(shown.length && input.value.trim() ? 0 : -1);
  }

  input.addEventListener("focus", () => {
    load();
    update();
  });
  input.addEventListener("input", () => {
    load();
    update();
  });
  form.addEventListener("focusout", (e) => {
    if (!form.contains(e.relatedTarget)) close();
  });
  input.addEventListener("keydown", (e) => {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      if (list.hidden) update();
      if (!shown.length) return;
      const step = e.key === "ArrowDown" ? 1 : -1;
      setActive((active + step + shown.length) % shown.length);
    } else if (e.key === "Escape") {
      if (!list.hidden) {
        e.preventDefault();
        close();
      } else input.blur();
    }
  });
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const text = input.value.trim();
    if (!text) return;
    if (!index && !text.includes("#")) {
      await load();
      update();
    }
    const go = shown[active >= 0 ? active : 0];
    if (go) location.href = go.href;
  });
  addEventListener("keydown", (e) => {
    if (e.key !== "/" || e.ctrlKey || e.metaKey || e.altKey) return;
    const t = e.target;
    if (t.closest?.("input, textarea, select, [contenteditable]")) return;
    e.preventDefault();
    input.focus();
  });
})();

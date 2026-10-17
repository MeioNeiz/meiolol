// Minimum games selector (html.zig minGames). Each [data-min-list] shows its first
// data-show rows (all without it) whose data-games reaches the choice; from data-strict
// up a row also needs data-clear="1". data-count names an element to hold the count.
// input[data-min-search], if any, also hides rows unless each word of the text ("ahri
// zed", "Ahri vs Zed") is in one of their data-name champions ("Ahri|Zed"), ignoring case
// and punctuation; while it has text, [data-min-group] blocks with no row left are hidden
// and the one with the most games shown goes first.
"use strict";

(() => {
  const select = document.querySelector(".min-games select");
  if (!select) return;
  const key = `min-games:${select.dataset.key}`;
  const strict = Number(select.dataset.strict);
  const search = document.querySelector("input[data-min-search]");
  const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
  const groups = [...document.querySelectorAll("[data-min-group]")];
  const groupsEnd = groups.length ? groups[groups.length - 1].nextSibling : null;
  try {
    const saved = localStorage.getItem(key);
    if ([...select.options].some((o) => o.value === saved)) select.value = saved;
  } catch {}

  function apply() {
    const min = Number(select.value);
    const chance = strict > 0 && min >= strict;
    const words = (search ? search.value.split(/\s+/).map(norm) : [])
      .filter((x) => x && !["v", "vs", "versus"].includes(x));
    const q = words.length > 0;
    const named = (row) => {
      const names = row.dataset.name.split("|").map(norm);
      return words.every((x) => names.some((n) => n.includes(x)));
    };
    const passes = (row) =>
      Number(row.dataset.games) >= min && (!chance || row.dataset.clear === "1") && named(row);
    for (const list of document.querySelectorAll("[data-min-list]")) {
      const limit = Number(list.dataset.show || Infinity);
      let shown = 0;
      for (const row of list.querySelectorAll("[data-games]")) {
        row.hidden = !(shown < limit && passes(row));
        if (!row.hidden) shown++;
      }
      const empty = list.querySelector(".empty");
      if (empty) {
        empty.dataset.text ??= empty.textContent;
        empty.textContent = q ? "None matching the search with this many games."
          : empty.dataset.text;
        empty.hidden = shown > 0;
      }
      const count = list.dataset.count && document.getElementById(list.dataset.count);
      if (count) count.textContent = shown;
    }
    if (!groups.length) return;
    const games = (g) => [...g.querySelectorAll("[data-games]:not([hidden])")]
      .reduce((t, r) => t + Number(r.dataset.games), 0);
    const order = groups.map((g, i) => ({ g, i, n: q ? games(g) : 0 }));
    // With no match anywhere, every block stays to say so
    const some = order.some((o) => o.n > 0);
    for (const o of order) o.g.hidden = some && o.n === 0;
    order.sort((a, b) => b.n - a.n || a.i - b.i);
    for (const o of order) groups[0].parentElement.insertBefore(o.g, groupsEnd);
  }

  select.addEventListener("change", () => {
    try {
      localStorage.setItem(key, select.value);
    } catch {}
    apply();
  });
  if (search) {
    search.addEventListener("input", apply);
    search.parentElement.hidden = false;
  }
  select.closest(".min-games").hidden = false;
  apply();
  // Back restores the search text after this script ran, with no input event
  addEventListener("pageshow", apply);
})();

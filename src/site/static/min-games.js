// Minimum games selector (html.zig minGames). Each [data-min-list] shows its first
// data-show rows (all without it) whose data-games reaches the choice; from data-strict
// up a row also needs data-clear="1". data-count names an element to hold the count.
// input[data-min-search], if any, also hides rows none of whose data-name champions
// ("Ahri|Syndra") contain the text, ignoring case, spaces and punctuation.
"use strict";

(() => {
  const select = document.querySelector(".min-games select");
  if (!select) return;
  const key = `min-games:${select.dataset.key}`;
  const strict = Number(select.dataset.strict);
  const search = document.querySelector("input[data-min-search]");
  const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
  try {
    const saved = localStorage.getItem(key);
    if ([...select.options].some((o) => o.value === saved)) select.value = saved;
  } catch {}

  function apply() {
    const min = Number(select.value);
    const chance = strict > 0 && min >= strict;
    const q = search ? norm(search.value) : "";
    const named = (row) => !q || row.dataset.name.split("|").some((n) => norm(n).includes(q));
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
        empty.textContent = q ? "None with this champion and this many games." : empty.dataset.text;
        empty.hidden = shown > 0;
      }
      const count = list.dataset.count && document.getElementById(list.dataset.count);
      if (count) count.textContent = shown;
    }
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
})();

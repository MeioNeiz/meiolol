// Minimum games selector (html.zig minGames). Each [data-min-list] shows its first
// data-show rows (all without it) whose data-games reaches the choice; from data-strict
// up a row also needs data-clear="1". data-count names an element to hold the count.
"use strict";

(() => {
  const select = document.querySelector(".min-games select");
  if (!select) return;
  const key = `min-games:${select.dataset.key}`;
  const strict = Number(select.dataset.strict);
  try {
    const saved = localStorage.getItem(key);
    if ([...select.options].some((o) => o.value === saved)) select.value = saved;
  } catch {}

  function apply() {
    const min = Number(select.value);
    const chance = strict > 0 && min >= strict;
    const passes = (row) =>
      Number(row.dataset.games) >= min && (!chance || row.dataset.clear === "1");
    for (const list of document.querySelectorAll("[data-min-list]")) {
      const limit = Number(list.dataset.show || Infinity);
      let shown = 0;
      for (const row of list.querySelectorAll("[data-games]")) {
        row.hidden = !(shown < limit && passes(row));
        if (!row.hidden) shown++;
      }
      const empty = list.querySelector(".empty");
      if (empty) empty.hidden = shown > 0;
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
  select.closest(".min-games").hidden = false;
  apply();
})();

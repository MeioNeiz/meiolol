// Champion tables (root.zig tierTable, opponentTable). table[data-sortable]: a click on a
// th[data-sort] sorts by that column, "num" by each cell's data-v (blank last), "text"
// by its data-v or else its text; td.rank cells renumber the shown rows.
// input[data-filter=ID] hides rows
// of table#ID whose data-name lacks the text; a search also finds rows marked data-rare,
// which stay hidden otherwise until button[data-show-rare=ID] shows them.
// input[data-min=ATTR][data-for=ID]: rows of table#ID whose data-ATTR is under its value
// count as data-rare, [data-rare-count=ID] their number; button[data-no-min=ID] sets
// them to 0. Kept in this browser by table id. By id, not sibling order: markup between them moves.
// A table's sort is kept in this browser by its id (the same table on every champion's
// page), by column name; table._resort() sorts redrawn rows the same way.
"use strict";

(() => {
  for (const table of document.querySelectorAll("table[data-sortable]")) {
    const body = table.tBodies[0];
    const heads = [...table.tHead.rows[0].cells];
    const renumber = () => {
      let n = 0;
      for (const row of body.rows) {
        const rank = row.querySelector("td.rank");
        if (rank && !row.hidden) rank.textContent = ++n;
      }
    };
    const sortBy = (th, descending) => {
      const i = heads.indexOf(th);
      const num = th.dataset.sort === "num";
      const key = (row) => {
        const cell = row.cells[i];
        if (!num) return (cell.dataset.v ?? cell.textContent.trim()).toLowerCase();
        const v = cell.dataset.v;
        return v === "" || v === undefined ? NaN : Number(v);
      };
      const rows = [...body.rows];
      rows.sort((a, b) => {
        const x = key(a), y = key(b);
        if (num && Number.isNaN(x)) return Number.isNaN(y) ? 0 : 1;
        if (num && Number.isNaN(y)) return -1;
        const order = x < y ? -1 : x > y ? 1 : 0;
        return descending ? -order : order;
      });
      body.append(...rows);
      for (const h of heads) h.removeAttribute("aria-sort");
      th.setAttribute("aria-sort", descending ? "descending" : "ascending");
      renumber();
    };
    const key = table.id && `sort:${table.id}`;
    const name = (th) => th.textContent.trim();
    for (const th of heads) {
      if (!th.dataset.sort) continue;
      th.tabIndex = 0;
      const toggle = () => {
        const current = th.getAttribute("aria-sort");
        // Numbers start high first, names A to Z
        const descending = current ? current === "ascending" : th.dataset.sort === "num";
        sortBy(th, descending);
        try {
          if (key) localStorage.setItem(key, JSON.stringify({ col: name(th), descending }));
        } catch {}
      };
      th.addEventListener("click", toggle);
      th.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          toggle();
        }
      });
    }
    table._renumber = renumber;
    table._resort = () => {
      const th = heads.find((h) => h.hasAttribute("aria-sort"));
      if (th) sortBy(th, th.getAttribute("aria-sort") === "descending");
    };
    let saved = null;
    try {
      saved = key && JSON.parse(localStorage.getItem(key));
    } catch {}
    const th = saved && heads.find((h) => h.dataset.sort && name(h) === saved.col);
    if (th) sortBy(th, saved.descending === true);
    else renumber();
  }

  const filters = new Map();
  for (const input of document.querySelectorAll("input[data-filter]")) {
    const table = document.getElementById(input.dataset.filter);
    const filter = () => {
      const q = input.value.trim().toLowerCase();
      for (const row of table.tBodies[0].rows) {
        const rare = row.hasAttribute("data-rare") && !table.dataset.showRare && !q;
        row.hidden = rare || !row.dataset.name.toLowerCase().includes(q);
      }
      table._renumber?.();
    };
    filters.set(table, filter);
    input.addEventListener("input", filter);
    // Back restores the search text after this script ran, with no input event
    addEventListener("pageshow", () => input.value && filter());
  }

  for (const button of document.querySelectorAll("button[data-show-rare]")) {
    const table = document.getElementById(button.dataset.showRare);
    button.addEventListener("click", () => {
      table.dataset.showRare = "1";
      for (const row of table.tBodies[0].querySelectorAll("tr[data-rare]")) row.hidden = false;
      table._renumber?.();
      button.parentElement.hidden = true;
    });
  }

  const minInputs = [...document.querySelectorAll("input[data-min][data-for]")];
  for (const id of new Set(minInputs.map((i) => i.dataset.for))) {
    const table = document.getElementById(id);
    const inputs = minInputs.filter((i) => i.dataset.for === id);
    const count = document.querySelector(`[data-rare-count="${id}"]`);
    const key = `min:${id}`;
    try {
      const saved = JSON.parse(localStorage.getItem(key)) ?? {};
      for (const i of inputs) {
        if (Number.isFinite(saved[i.dataset.min])) i.value = saved[i.dataset.min];
      }
    } catch {}
    const apply = () => {
      let rare = 0;
      for (const row of table.tBodies[0].rows) {
        const under = inputs.some((i) => Number(row.dataset[i.dataset.min]) < Number(i.value));
        row.toggleAttribute("data-rare", under);
        if (under) rare++;
      }
      if (count) {
        count.textContent = rare;
        count.parentElement.hidden = rare === 0;
      }
      const filter = filters.get(table);
      if (filter) return filter();
      for (const row of table.tBodies[0].rows) row.hidden = row.hasAttribute("data-rare");
      table._renumber?.();
    };
    const save = () => {
      try {
        localStorage.setItem(key, JSON.stringify(Object.fromEntries(
          inputs.map((i) => [i.dataset.min, Number(i.value)]))));
      } catch {}
    };
    for (const i of inputs) {
      i.addEventListener("input", () => {
        save();
        apply();
      });
    }
    for (const button of document.querySelectorAll(`button[data-no-min="${id}"]`)) {
      button.addEventListener("click", () => {
        for (const i of inputs) i.value = 0;
        save();
        apply();
      });
    }
    inputs[0].closest("[hidden]")?.removeAttribute("hidden");
    apply();
  }
})();

// Champion tables (root.zig tierTable, opponentTable). table[data-sortable]: a click on a
// th[data-sort] sorts by that column, "num" by each cell's data-v (blank last), "text"
// by its text; td.rank cells renumber the shown rows. input[data-filter=ID] hides rows
// of table#ID whose data-name lacks the text. button[data-show-rare=ID] shows the rows
// marked data-rare in table#ID. By id, not sibling order: markup between them moves.
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
        if (!num) return cell.textContent.trim().toLowerCase();
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
    for (const th of heads) {
      if (!th.dataset.sort) continue;
      th.tabIndex = 0;
      const toggle = () => {
        const current = th.getAttribute("aria-sort");
        // Numbers start high first, names A to Z
        const descending = current ? current === "ascending" : th.dataset.sort === "num";
        sortBy(th, descending);
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
    renumber();
  }

  for (const input of document.querySelectorAll("input[data-filter]")) {
    const table = document.getElementById(input.dataset.filter);
    input.addEventListener("input", () => {
      const q = input.value.trim().toLowerCase();
      for (const row of table.tBodies[0].rows) {
        const rare = row.hasAttribute("data-rare") && !table.dataset.showRare;
        row.hidden = rare || !row.dataset.name.toLowerCase().includes(q);
      }
      table._renumber?.();
    });
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
})();

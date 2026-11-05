// Injected by the shell into each of its pages before their own scripts (win.zig,
// mac.zig): the one place that knows the native side, so pages stay the site's files.
// Shell messages (src/shell/channel.zig ToPage) arrive as `meiolol` events on window,
// the message in event.detail; meiolol.send(m) posts a FromPage message.
(() => {
  const wv = window.chrome && window.chrome.webview;
  if (!wv) return;
  // A site page in the app's window (ui/appbar.zig links there): its bar and menu gain
  // the way back, and it gets no channel (the shell drops its messages anyway)
  const app = window.meiololApp || 'https://meiolol.app/';
  if (!location.href.startsWith(app)) {
    addEventListener('DOMContentLoaded', () => {
      for (const n of document.querySelectorAll('header .links, header .c-sitemenu:not(.acctmenu)')) {
        const a = document.createElement('a');
        a.href = app;
        a.textContent = 'App';
        n.prepend(a);
      }
    });
    return;
  }
  window.meiolol = { send: (m) => wv.postMessage(JSON.stringify(m)) };
  wv.addEventListener('message', (e) => {
    if (e.data && e.data.reload) return location.reload();
    dispatchEvent(new CustomEvent('meiolol', { detail: e.data }));
  });
  // The board's seats and "Your lane" (ui/draftboard.zig Seat.act "lane N"): the lane
  // panel switches without a handler in ui-app.wasm
  addEventListener('click', (e) => {
    const el = e.target.closest && e.target.closest('[data-act^="lane "]');
    if (el) return meiolol.send({ lane: +el.dataset.act.slice(5) });
    // The app bar and settings (ui/appbar.zig): static HTML, the message on the element
    const sh = e.target.closest && e.target.closest('[data-shell]');
    if (sh) meiolol.send(JSON.parse(sh.dataset.shell));
  });
  // An enemy seat dropped on another (ui/draftboard.zig: a team's seats in role order):
  // the two swap roles. The live board's seats only (a lane act or the shown one):
  // practice's carry its own acts
  const enemy = (el) => el.closest && el.closest('.c-draft .seat[data-side="them"]');
  const movable = (s) => !!s && (s.matches('[data-act^="lane "]') || s.hasAttribute('data-sel'));
  const row = (s) => Array.prototype.indexOf.call(s.parentNode.querySelectorAll(':scope > .seat'), s);
  let from = -1;
  let over = null;
  const target = (e) => {
    const s = from >= 0 && enemy(e.target);
    return movable(s) ? s : null;
  };
  const leave = () => {
    if (over) delete over.dataset.drop;
    over = null;
  };
  addEventListener('mousedown', (e) => {
    const s = enemy(e.target);
    if (movable(s)) s.draggable = true;
  });
  addEventListener('dragstart', (e) => {
    const s = enemy(e.target);
    if (!movable(s)) return;
    from = row(s);
    e.dataTransfer.effectAllowed = 'move';
  });
  addEventListener('dragover', (e) => {
    const l = target(e);
    if (l !== over) leave();
    if (!l) return;
    e.preventDefault();
    over = l;
    l.dataset.drop = '';
  });
  addEventListener('drop', (e) => {
    const l = target(e);
    if (!l) return;
    e.preventDefault();
    const to = row(l);
    if (to !== from) meiolol.send({ swap: [from, to] });
  });
  addEventListener('dragend', () => {
    from = -1;
    leave();
  });
  const page = location.pathname.replace(/^\//, '') || 'index.html';
  addEventListener('DOMContentLoaded', () => {
    requestAnimationFrame(() => requestAnimationFrame(() => meiolol.send({ painted: { page } })));
  });
  // Sheets the player opens (ui/gamebuild.zig details[data-keep]) stay as they left them
  // across the page's reloads; a page without one forgets, so the next game starts closed
  addEventListener('DOMContentLoaded', () => {
    const key = 'meiolol-open';
    const keep = document.querySelectorAll('details[data-keep]');
    try {
      if (!keep.length) return sessionStorage.removeItem(key);
      const open = new Set(JSON.parse(sessionStorage.getItem(key) || '[]'));
      for (const d of keep) {
        d.open = open.has(d.dataset.keep);
        d.addEventListener('toggle', () => {
          if (d.open) open.add(d.dataset.keep);
          else open.delete(d.dataset.keep);
          try {
            sessionStorage.setItem(key, JSON.stringify([...open]));
          } catch {}
        });
      }
    } catch {}
  });
})();

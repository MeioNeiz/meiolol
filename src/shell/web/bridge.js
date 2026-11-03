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
  const page = location.pathname.replace(/^\//, '') || 'index.html';
  addEventListener('DOMContentLoaded', () => {
    requestAnimationFrame(() => requestAnimationFrame(() => meiolol.send({ painted: { page } })));
  });
})();

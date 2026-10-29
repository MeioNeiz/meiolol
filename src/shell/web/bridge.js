// Injected by the shell into each of its pages before their own scripts (win.zig,
// mac.zig): the one place that knows the native side, so pages stay the site's files.
// Shell messages (src/shell/channel.zig ToPage) arrive as `meiolol` events on window,
// the message in event.detail; meiolol.send(m) posts a FromPage message.
(() => {
  const wv = window.chrome && window.chrome.webview;
  if (!wv) return;
  window.meiolol = { send: (m) => wv.postMessage(JSON.stringify(m)) };
  wv.addEventListener('message', (e) => {
    if (e.data && e.data.reload) return location.reload();
    dispatchEvent(new CustomEvent('meiolol', { detail: e.data }));
  });
  const page = location.pathname.replace(/^\//, '') || 'index.html';
  addEventListener('DOMContentLoaded', () => {
    requestAnimationFrame(() => requestAnimationFrame(() => meiolol.send({ painted: { page } })));
  });
})();

// For measuring the webview app only (deploy/shell.sh pages adds it to the draft board
// mock; never shipped): draws --demo's made-up champ select on the DraftBoard and says
// when each one is on screen, so measure.zig can time the push
(() => {
  const esc = (s) => s.replace(/[&<>"']/g, (ch) => '&#' + ch.charCodeAt(0) + ';');
  function seat(el, s) {
    el.classList.toggle('sel', s.state === 'picking');
    el.classList.toggle('open', !s.key);
    const ci = el.querySelector('.ci');
    const nm = el.querySelector('.nm');
    if (s.key) {
      if (ci.tagName !== 'IMG' || ci.dataset.key !== s.key) {
        const img = document.createElement('img');
        img.className = 'ci';
        img.dataset.key = s.key;
        img.src = 'icons/champ/' + s.key + '.png';
        img.alt = s.name;
        ci.replaceWith(img);
      }
      nm.innerHTML = '<b>' + esc(s.name) + '</b>' + (s.state === 'picking' ? '<small>Picking</small>' : '');
    } else {
      if (ci.tagName === 'IMG') {
        const span = document.createElement('span');
        span.className = 'ci empty';
        span.textContent = '?';
        ci.replaceWith(span);
      }
      nm.innerHTML = '<b class="ph">' + (s.state === 'picking' ? 'Picking' : 'Waiting') + '</b>';
    }
  }
  addEventListener('meiolol', (ev) => {
    const m = ev.detail.champ_select;
    if (!m) return;
    const rows = document.querySelectorAll('.board .lane-row');
    m.seats.forEach((s, i) => {
      const row = rows[i % 5];
      if (row) seat(row.querySelector(i < 5 ? '.seat.us' : '.seat.them'), s);
    });
    const h = document.querySelector('.head h1');
    if (h) h.textContent = 'Champ select ' + m.timer + 's';
    const ws = document.querySelector('.ws-l .us');
    if (ws && m.blue != null) ws.textContent = 'Blue ' + m.blue.toFixed(1) + '%';
    requestAnimationFrame(() => window.meiolol && meiolol.send({ drawn: m.seq }));
  });
})();

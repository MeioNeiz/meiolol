// The UI sweep (docs/plan/ui/README.md Tooling), run by deploy/qa.sh: each page type at
// 320, 390, 768 and 1280 wide (phones with touch), and the gallery's components in their
// 320 and 390 px containers. Warnings only: it reports, never fails a build.
//   node deploy/qa.mjs BASE [--webkit] [--shots DIR] [--only PATH,...]
import { createRequire } from 'module';
import { mkdirSync } from 'fs';
const require = createRequire(process.env.HOME + '/personal/browser-tool/package.json');
const pw = require('playwright-core');

const args = process.argv.slice(2);
const base = (args.find(a => !a.startsWith('--') && /^https?:/.test(a)) || 'http://localhost:8093').replace(/\/$/, '');
const flag = n => args.includes(n);
const opt = n => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : null; };
const shots = opt('--shots');
if (shots) mkdirSync(shots, { recursive: true });

const pages = opt('--only')?.split(',') || [
  '/', '/champions.html', '/role/mid.html', '/champion/ahri.html', '/matchup/index.html', '/pool.html',
  '/learn.html', '/daily.html', '/your.html', '/method.html',
];
const widths = [[320, true], [390, true], [768, false], [1280, false]];

const engine = flag('--webkit') ? pw.webkit : pw.chromium;
const browser = await engine.launch(flag('--webkit') ? {} : { channel: 'chrome', headless: true });
let warnings = 0;
const warn = (where, msg) => { warnings++; console.log(`warn ${where}: ${msg}`); };

// In the page: what overflows, text under 11 px, small tap targets
function measure(touch) {
  const out = { overflow: [], small: new Set(), taps: [], sw: document.documentElement.scrollWidth, vw: innerWidth };
  const name = el => el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') +
    (typeof el.className === 'string' && el.className ? '.' + el.className.trim().split(/\s+/).join('.') : '');
  const clipped = el => {
    for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) {
      const o = getComputedStyle(p).overflowX;
      if (o !== 'visible') return true;
    }
    return false;
  };
  const shown = el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
  for (const el of document.querySelectorAll('body *')) {
    if (!shown(el) || el.closest('svg') && el.tagName !== 'svg') continue;
    const r = el.getBoundingClientRect();
    if (r.right > innerWidth + 1 && !clipped(el) && out.overflow.length < 6) out.overflow.push(`${name(el)} to ${Math.round(r.right)}`);
    if ([...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim()) && parseFloat(getComputedStyle(el).fontSize) < 11) out.small.add(name(el));
  }
  const floor = 24, phone = 44;
  for (const el of document.querySelectorAll('a[href], button, input, select, [role=tab], [tabindex="0"]')) {
    if (!shown(el)) continue;
    const r = el.getBoundingClientRect();
    const after = getComputedStyle(el, '::after');
    const h = Math.max(r.height, after.content !== 'none' && after.position === 'absolute' ? parseFloat(after.height) || 0 : 0);
    const inline = getComputedStyle(el).display === 'inline' && el.closest('p, li, td');
    if (inline) continue; // a link in running text: WCAG's inline exception
    const need = touch ? phone : floor;
    if (h < need || r.width < floor) out.taps.push(`${name(el)} ${Math.round(r.width)}x${Math.round(h)}`);
  }
  out.small = [...out.small].slice(0, 6);
  return out;
}

// The gallery: each component state against its fixed-width container
function frames() {
  const out = [];
  for (const f of document.querySelectorAll('.g-frame[data-w]')) {
    const fr = f.getBoundingClientRect();
    const right = fr.right - parseFloat(getComputedStyle(f).paddingRight);
    for (const st of f.querySelectorAll('.g-state')) {
      const comp = st.closest('.g-sec').id, cap = st.querySelector(':scope > .g-cap')?.textContent;
      for (const el of st.querySelectorAll('*')) {
        const r = el.getBoundingClientRect();
        if (!r.width || r.right <= right + 0.5) continue;
        let p = el.parentElement, clip = false;
        for (; p && p !== st; p = p.parentElement) if (getComputedStyle(p).overflowX !== 'visible') clip = true;
        if (clip) continue;
        out.push(`${comp} "${cap}" at ${f.dataset.w}px: ${el.tagName.toLowerCase()}.${el.className || ''} ${Math.round(r.right - right)} px over`);
        break;
      }
      for (const el of st.querySelectorAll('*')) {
        const cs = getComputedStyle(el);
        if ((cs.overflowX === 'auto' || cs.overflowX === 'scroll') && el.scrollWidth > el.clientWidth + 1) {
          out.push(`${comp} "${cap}" at ${f.dataset.w}px: ${el.className} scrolls (${el.scrollWidth} in ${el.clientWidth})`);
        }
      }
    }
  }
  return out;
}

async function visit(path, w, touch) {
  const ctx = await browser.newContext({
    viewport: { width: w, height: touch ? 844 : 900 }, hasTouch: touch, isMobile: touch && !flag('--webkit'),
    userAgent: undefined,
  });
  const page = await ctx.newPage();
  const where = `${path} ${w}`;
  page.on('console', m => m.type() === 'error' && warn(where, 'console: ' + m.text().slice(0, 200)));
  page.on('pageerror', e => warn(where, 'page error: ' + String(e).slice(0, 200)));
  page.on('requestfailed', r => !r.url().includes('/__dev') && warn(where, `failed ${r.url()}: ${r.failure()?.errorText}`));
  page.on('response', r => r.status() >= 400 && warn(where, `${r.status()} ${r.url()}`));
  // 'load', not networkidle: the dev page keeps a reload poll open
  const res = await page.goto(base + path, { waitUntil: 'load' }).catch(e => (warn(where, String(e)), null));
  if (!res) return ctx.close();
  await page.waitForTimeout(400);
  const m = await page.evaluate(measure, touch);
  if (m.sw > m.vw) warn(where, `page scrolls sideways (${m.sw} in ${m.vw})`);
  for (const o of m.overflow) warn(where, 'past the viewport: ' + o);
  if (m.small.length) warn(where, 'text under 11 px: ' + m.small.join(', '));
  if (m.taps.length) warn(where, `${m.taps.length} tap targets under ${touch ? 44 : 24} px: ` + m.taps.slice(0, 5).join(', '));
  if (path.startsWith('/gallery')) for (const f of await page.evaluate(frames)) warn('gallery', f);
  if (shots) await page.screenshot({ path: `${shots}/${path.replace(/[\/.]+/g, '_').replace(/^_|_$/g, '') || 'home'}-${w}.png`, fullPage: true });
  await ctx.close();
}

await visit('/gallery', 1280, false);
for (const p of pages) for (const [w, touch] of widths) await visit(p, w, touch);
await browser.close();
console.log(`qa: ${warnings} warnings (${flag('--webkit') ? 'webkit' : 'chromium'}, ${base})`);

// CSP and Trusted Types check (src/site/csp.zig): each page in headless Chrome, scrolled
// and the header search opened, with every console error and securitypolicyviolation.
// Exits 1 if any page has one. 404s and 401s for resources are left out (a small dev
// snapshot lacks data files; /account asks for a session). NOTES=1 sets the dev server's
// notes cookie (the overlay). LOGIN=1 signs in as meiolol-check first (/private, /admin,
// the notes overlay), out at the end:
//   LOGIN=1 vault run meiolol/local -- node deploy/csp.mjs BASE
// Also lists scripts from elsewhere or /cdn-cgi/ (Cloudflare's injections).
//   node deploy/csp.mjs BASE [PATH...]
// meio.lol from the Mac (Sophos re-signs its TLS): through C01,
//   ssh -fN -L 8443:meio.lol:443 essex-vm
//   MAP='meio.lol:443 127.0.0.1:8443' node deploy/csp.mjs https://meio.lol
import { createRequire } from 'module';
const require = createRequire(process.env.HOME + '/personal/browser-tool/package.json');
const pw = require('playwright-core');

const base = (process.argv[2] || 'http://localhost:8080').replace(/\/$/, '');
const pages = process.argv.length > 3 ? process.argv.slice(3) : [
  '/', '/champions', '/champions/top', '/champions/akali', '/champions/akali/mid', '/matchups',
  '/matchups/top/darius-vs-garen', '/daily', '/patch', '/patch?region=all', '/pickup', '/pickup/top',
  '/pool', '/learn', '/your', '/your#view=highlights', '/game', '/method', '/download', '/privacy',
  '/terms', '/login', '/account', '/signup', '/join', '/nosuch', '/private', '/private/tester',
  '/admin', '/admin/notes',
];
const args = process.env.MAP ? [`--host-resolver-rules=MAP ${process.env.MAP}`] : [];
const browser = await pw.chromium.launch({ channel: 'chrome', headless: true, args });
const ctx = await browser.newContext({ userAgent: 'Mozilla/5.0 meiolol-agent csp' });
// In a page, not ctx.request: that skips MAP
const post = async (path, body) => {
  const pg = await ctx.newPage();
  await pg.goto(base + '/nosuch');
  const st = await pg.evaluate(async ([path, body]) => (await fetch(path, { method: 'POST', body,
    headers: { 'content-type': 'application/json', 'x-meiolol-action': '1' } })).status, [path, body]);
  await pg.close();
  return st;
};
if (process.env.LOGIN) {
  const st = await post('/auth/login', JSON.stringify({ username: 'meiolol-check', password: process.env.MEIOLOL_CHECK_PASSWORD }));
  if (st >= 300) { console.log('login failed', st); process.exit(1); }
}
if (process.env.NOTES) await ctx.addCookies([{ name: 'meiolol_notes', value: '1', url: base }]);
await ctx.addInitScript(() => document.addEventListener('securitypolicyviolation', e =>
  console.error(`CSPV ${e.violatedDirective} ${e.blockedURI} ${e.sample || ''}`)));
let bad = 0;
for (const p of pages) {
  const page = await ctx.newPage();
  const errs = [];
  page.on('console', m => { if (m.type() === 'error') errs.push(m.text().slice(0, 220)); });
  page.on('pageerror', e => errs.push('pageerror ' + String(e).slice(0, 220)));
  let status = 0;
  try {
    const r = await page.goto(base + p, { waitUntil: 'load', timeout: 30000 });
    status = r ? r.status() : 0;
  } catch (e) { errs.push('goto ' + e.message.slice(0, 100)); }
  await page.waitForTimeout(1500);
  try {
    for (let i = 0; i < 8; i++) { await page.mouse.wheel(0, 900); await page.waitForTimeout(250); }
    await page.waitForTimeout(1000);
    await page.focus('[data-island=search] input', { timeout: 1000 });
    await page.waitForTimeout(1500);
  } catch {}
  let info = '';
  try {
    info = await page.evaluate(() => {
      const m = document.querySelector('meta[http-equiv=Content-Security-Policy]');
      const tt = !!m && /require-trusted-types-for/.test(m.content);
      const isl = [...document.querySelectorAll('[data-island]')]
        .map(e => e.dataset.island + (e.dataset.failed ? '!FAILED' : '')).join(',');
      const foreign = [...document.scripts].map(s => s.src)
        .filter(u => u && (new URL(u).origin != location.origin || u.includes('/cdn-cgi/')));
      return `csp=${!!m} tt=${tt} islands=${isl}` + (foreign.length ? ' FOREIGN=' + foreign.join(',') : '');
    });
  } catch (e) { errs.push('eval ' + e.message.slice(0, 80)); }
  const real = errs.filter(e => !/Failed to load resource: the server responded with a status of 40[14]/.test(e));
  if (real.length || /FAILED|FOREIGN/.test(info)) bad++;
  console.log(p, status, info, real.length ? '\n   ' + real.join('\n   ') : 'OK');
  await page.close();
}
if (process.env.LOGIN) await post('/auth/logout', '');
await browser.close();
console.log(bad ? `${bad} pages with errors` : 'all clean');
process.exit(bad ? 1 : 0);

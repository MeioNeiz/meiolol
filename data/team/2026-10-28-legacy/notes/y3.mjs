import { createRequire } from 'module';
const require = createRequire(process.env.HOME + '/personal/browser-tool/package.json');
const pw = require('playwright-core');
const base = 'http://localhost:8091', out = process.argv[2];
const b = await pw.chromium.launch({ channel: 'chrome', headless: true });
for (const [w, dark] of [[1800, true], [360, false]]) {
  const p = await b.newPage({ viewport: { width: w, height: 1000 }, colorScheme: dark ? 'dark' : 'light' });
  const errs = []; p.on('console', m => m.type() === 'error' && errs.push(m.text())); p.on('pageerror', e => errs.push(String(e)));
  const reqs = []; p.on('request', r => r.url().includes('/api/friends') && reqs.push(r.url().replace(base, '')));
  await p.goto(base + '/games');
  console.log(w, 'example tabs', await p.locator('.c-yviews [role=tab]').allTextContents());
  await p.goto(base + '/games#id=Fixture%23EUW');
  await p.waitForSelector('.c-yviews [role=tab]:has-text("Friends")', { timeout: 20000 });
  console.log(w, 'lookup tabs', await p.locator('.c-yviews [role=tab]').allTextContents());
  await p.click('.c-yviews [role=tab]:has-text("Friends")');
  await p.waitForSelector('.c-yfriends .c-table, .c-yfriends .note', { timeout: 15000 });
  await p.waitForTimeout(800);
  console.log(w, 'url', p.url(), 'friends text:', (await p.textContent('.c-yfriends')).slice(0, 200));
  await p.screenshot({ path: `${out}/y3-${w}.png` });
  await p.click('.c-yfriends tbody tr >> nth=0').catch(e => console.log('row click', e.message));
  await p.waitForTimeout(500);
  await p.locator('.c-yfriends').screenshot({ path: `${out}/y3-${w}-open.png` });
  console.log(w, 'reqs', reqs, 'errors', errs);
  await p.close();
}
await b.close();

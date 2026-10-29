import { createRequire } from 'module';
const require = createRequire(process.env.HOME + '/personal/browser-tool/package.json');
const pw = require('playwright-core');
const base = 'http://localhost:8091', out = process.argv[2];
const b = await pw.chromium.launch({ channel: 'chrome', headless: true });
for (const [w, dark] of [[1800, true], [360, false]]) {
  const p = await b.newPage({ viewport: { width: w, height: 900 }, colorScheme: dark ? 'dark' : 'light' });
  const errs = []; p.on('console', m => m.type() === 'error' && errs.push(m.text())); p.on('pageerror', e => errs.push(String(e)));
  await p.goto(base + '/games#id=Fixture%23EUW');
  await p.waitForSelector('.c-ylook .acts', { timeout: 15000 });
  await p.waitForTimeout(500);
  await p.screenshot({ path: `${out}/y1-${w}.png` });
  const ls = await p.evaluate(() => [localStorage.getItem('your-recent'), localStorage.getItem('your-last')]);
  console.log(w, 'stored', ls);
  await p.click('.c-ylook .acts button >> nth=0');
  await p.waitForTimeout(1500);
  console.log(w, 'after refresh:', await p.textContent('.c-ylook p'), '|', await p.textContent('.c-ylook .acts button >> nth=0'));
  await p.screenshot({ path: `${out}/y1-${w}-check.png` });
  // a bare visit reopens
  await p.goto(base + '/games'); await p.waitForTimeout(2500);
  console.log(w, 'bare visit url', p.url(), 'player', await p.textContent('.c-player h1, .c-player .name').catch(() => '?'));
  await p.click('.c-ylook .acts button:has-text("Not you")');
  await p.waitForTimeout(800);
  console.log(w, 'not you url', p.url(), 'last', await p.evaluate(() => localStorage.getItem('your-last')));
  await p.goto(base + '/games'); await p.waitForTimeout(1500);
  console.log(w, 'after not you, bare', p.url());
  console.log(w, 'errors', errs);
  await p.close();
}
await b.close();

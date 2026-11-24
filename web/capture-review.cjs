/* Unmodified screenshots of the production Web release. No game-state/debug hooks.
   npm run capture:review (server at GAME_URL or localhost:8060).
   Runs the real touch purchase/stock/sale/save scenario, then a fresh desktop session. */
const {spawn} = require('node:child_process');
const fs = require('node:fs/promises');
const path = require('node:path');
const {chromium} = require('playwright');
const root = path.resolve(__dirname, '..');
const output = path.join(root, 'builds/review');
const docs = path.join(root, 'docs');
const prefix = process.env.REVIEW_PREFIX || 'pastel';
async function capture() {
  await new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [path.join(__dirname, 'smoke.cjs'), '--gameplay'], {
      cwd: __dirname, stdio: 'inherit', env: {...process.env, BROWSERS: 'chromium', CAPTURE_DIR: output}
    });
    child.on('error', reject);
    child.on('exit', code => code === 0 ? resolve() : reject(new Error(`Gameplay check exited ${code}`)));
  });
  for (const [source, destination] of [
    ['chromium-supplier.png', 'pastel-mobile-supplier.png'],
    ['chromium-storage.png', 'pastel-mobile-storage.png'],
    ['chromium-visitors.png', 'pastel-mobile-shop.png'],
    ['chromium-checkout-after.png', 'pastel-mobile-checkout.png'],
    ['chromium-390x844.png', 'pastel-mobile-portrait.png']
  ]) await fs.copyFile(path.join(output, source), path.join(docs, destination.replace('pastel', prefix)));
  const browser = await chromium.launch({
    args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
    ...(process.env.CHROMIUM_PATH ? {executablePath: process.env.CHROMIUM_PATH} : {})
  });
  try {
    const page = await browser.newPage({viewport: {width: 1366, height: 768}});
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => {if (/SCRIPT ERROR:|\bERROR:/.test(m.text())) errors.push(m.text());});
    await page.goto(process.env.GAME_URL || 'http://127.0.0.1:8060/');
    await page.locator('#start').click();
    await page.waitForFunction(() => document.body.dataset.gameReady === 'true');
    await page.waitForTimeout(500);
    await page.screenshot({path: path.join(docs, `${prefix}-title.png`)});
    const canvas = await page.locator('#canvas').boundingBox();
    await page.mouse.click(canvas.x + canvas.width / 2, canvas.y + canvas.height * 260 / 360);
    await page.waitForTimeout(500);
    await page.screenshot({path: path.join(docs, `${prefix}-shop.png`)});
    await page.keyboard.press('KeyI');
    await page.waitForTimeout(300);
    await page.screenshot({path: path.join(docs, `${prefix}-inventory.png`)});
    if (errors.length) throw new Error(errors.join('\n'));
  } finally {await browser.close();}
  console.log(`Saved real desktop and mobile Web release captures in docs/${prefix}-*.png`);
}
capture().catch(error => {console.error(error); process.exitCode = 1;});

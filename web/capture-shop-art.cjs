/* Real mobile export screenshots, using only player-visible controls. */
const assert = require('node:assert/strict');
const {webkit, devices} = require('playwright');

(async () => {
  const browser = await webkit.launch(process.env.WEBKIT_PATH ? {executablePath: process.env.WEBKIT_PATH} : {});
  const context = await browser.newContext({...devices['iPhone 13 landscape'], screen: undefined});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' || /SCRIPT ERROR:|\bERROR:/.test(message.text())) errors.push(message.text());
  });
  const tap = async (x, y) => {
    const canvas = page.locator('#canvas');
    const bounds = await canvas.boundingBox();
    const [width, height] = await canvas.evaluate(c => [c.width, c.height]);
    await page.touchscreen.tap(bounds.x + x * bounds.width / width, bounds.y + y * bounds.height / height);
    await page.waitForTimeout(350);
  };
  const capture = async name => {
    await page.screenshot({path: `../docs/${process.env.CAPTURE_PREFIX || 'illustrated-shop'}-${name}.png`, scale: 'css'});
    console.log(`Captured shop ${name}`);
  };
  try {
    await page.goto(process.env.GAME_URL || 'http://127.0.0.1:8060/');
    await page.locator('#start').tap();
    await page.waitForFunction(() => document.body.dataset.gameReady === 'true');
    await page.waitForTimeout(900);
    await tap(150, 177); // New game.
    await tap(450, 320); // Keep the existing default character.
    await require('./train-helpers.cjs').skipTrain(page, tap);
    await page.waitForTimeout(900);
    await capture('mobile');
    await page.setViewportSize({width: 390, height: 844});
    await page.waitForTimeout(900);
    await capture('mobile-portrait');
    await page.locator('[data-code="KeyI"]').tap();
    await page.waitForTimeout(400);
    await capture('mobile-inventory');
    assert.deepEqual(errors, [], 'No browser or engine errors during capture');
  } finally {
    await context.close();
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});

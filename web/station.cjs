/* Real exported station, ordinary touch controls, IndexedDB observation only. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const {chromium, webkit, devices} = require('playwright');
const helpers = require('./train-helpers.cjs');
const docs = process.argv.includes('--docs');
const output = process.env.CAPTURE_DIR || '../builds/browser-checks';

async function check(engine) {
  const browser = await ({chromium, webkit}[engine]).launch(engine === 'chromium' ? {
    args: ['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']
  } : {});
  const context = await browser.newContext({...devices['iPhone 13 landscape'], screen: undefined});
  const page = await context.newPage(), errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error' || /SCRIPT ERROR:|\bERROR:/.test(m.text())) errors.push(m.text()); });
  const wait = ms => page.waitForTimeout(ms);
  const tap = async (x,y) => {
    const b = await page.locator('#canvas').boundingBox();
    const [w,h] = await page.locator('#canvas').evaluate(c => [c.width,c.height]);
    await page.touchscreen.tap(b.x+x*b.width/w,b.y+y*b.height/h); await wait(250);
  };
  const boot = async () => { await page.locator('#start').tap();
    await page.waitForFunction(() => document.body.dataset.gameReady === 'true',null,{timeout:60000}); await wait(800); };
  const capture = async name => {
    await page.screenshot({path:path.join(output,`${engine}-station-${name}.png`),scale:'css'});
    if (docs && engine === 'webkit' && ['mobile-portrait','mobile-landscape','portrait-bag','schedule','temporary-shop'].includes(name))
      await page.screenshot({path:`../docs/station-web-${name}.png`,scale:'css'});
  };
  const action = async code => { await page.locator(`[data-code="${code}"]`).tap(); await wait(300); };
  try {
    await page.goto(process.env.GAME_URL || 'http://127.0.0.1:8060/'); await boot();
    await tap(150,177); await tap(450,90); await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.insertText('Рин'); await tap(600,186); await tap(450,320);
    await helpers.arriveStation(page,tap);
    const arrival = await helpers.saved(page);
    assert.equal(arrival.journey.location,'station'); assert.equal(arrival.character.name,'Рин');
    assert.equal(arrival.character.hairstyle,1); assert.equal(arrival.minute,480);
    await capture('arrival');
    // The location survives an app restart immediately, before the train leaves.
    await page.reload(); await boot(); await tap(150,206); await wait(1000);
    assert.equal(await page.locator('#movement').isVisible(),true);
    assert.equal((await helpers.saved(page)).journey.location,'station');
    await wait(10500);
    const departed = await helpers.saved(page);
    assert.equal(departed.journey.arrival_time,10); assert.equal(departed.minute,480);
    assert.deepEqual(departed.economy,arrival.economy);
    await helpers.stationWalk(page,350,260); await helpers.stationWalk(page,570,260);
    await helpers.stationWalk(page,570,315); await helpers.stationWalk(page,510,315);
    assert.equal(await page.locator('#action-label').textContent(),'Прочитать расписание');
    await action('KeyE'); assert(await page.locator('[data-code="KeyE"]').isDisabled());
    await capture('schedule'); await action('Escape');
    await capture('platform');
    // DOM controls and screen-space HUD continue to fit after both rotations.
    for (const viewport of [{width:390,height:844},{width:844,height:390}]) {
      await page.setViewportSize(viewport); await wait(700);
      assert.deepEqual(await page.locator('#canvas').evaluate(c => [c.width,c.height]),[640,360]);
      for (const selector of ['#canvas','[data-code="ArrowUp"]','[data-code="KeyE"]','[data-code="KeyI"]','[data-code="Escape"]']) {
        const b = await page.locator(selector).boundingBox();
        assert(b && b.x>=0 && b.y>=0 && b.x+b.width<=viewport.width+1 && b.y+b.height<=viewport.height+1);
      }
      await action('KeyI'); await capture(viewport.height>viewport.width?'portrait-bag':'landscape-bag'); await action('Escape');
      await capture(viewport.height>viewport.width?'mobile-portrait':'mobile-landscape');
    }
    await helpers.stationWalk(page,350,315); await helpers.stationWalk(page,350,422);
    await helpers.stationWalk(page,467,422);
    assert.equal(await page.locator('#action-label').textContent(),'Прочитать указатель');
    await action('KeyE'); await capture('village-sign'); await action('Escape');
    await capture('village-path');
    const before = await helpers.saved(page);
    await page.reload(); await boot(); await tap(150,206); await wait(1400);
    const restored = await helpers.saved(page);
    assert.equal(restored.journey.location,'station'); assert.equal(restored.journey.arrival_time,10);
    assert.deepEqual(restored.journey.position,before.journey.position);
    assert.deepEqual(restored.character,arrival.character); assert.deepEqual(restored.economy,arrival.economy);
    await helpers.stationWalk(page,690,422); await wait(1800);
    assert.equal((await helpers.saved(page)).journey.location,'shop');
    await capture('temporary-shop');
    await page.reload(); await boot(); await tap(150,206); await wait(1000);
    assert.equal((await helpers.saved(page)).journey.location,'shop');
    assert.deepEqual(errors,[],`${engine}: browser/engine errors`);
    console.log(`${engine}: arrival/restart, departed train, frozen shop, schedule/sign, touch routes, portrait/landscape bag, station Continue, temporary shop + Continue: PASS`);
  } catch(e) { await capture('failure').catch(()=>{}); throw e; }
  finally { await context.close(); await browser.close(); }
}
(async()=>{await fs.mkdir(output,{recursive:true});for(const engine of (process.env.BROWSERS||'chromium,webkit').split(','))await check(engine)})().catch(e=>{console.error(e);process.exitCode=1});

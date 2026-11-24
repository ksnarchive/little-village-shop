/* Browser integration against the real release export; no game/debug hooks. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const {chromium, webkit} = require('playwright');
const url = process.env.GAME_URL || 'http://127.0.0.1:8060/';
const output = process.env.CAPTURE_DIR || '../builds/browser-checks';
const fullGameplay = process.argv.includes('--gameplay');
const engines = (process.env.BROWSERS || 'chromium,webkit').split(',');

async function check(name) {
  const options = name === 'chromium' ? {
    args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
    ...(process.env.CHROMIUM_PATH ? {executablePath: process.env.CHROMIUM_PATH} : {})
  } : (process.env.WEBKIT_PATH ? {executablePath: process.env.WEBKIT_PATH} : {});
  const browser = await ({chromium, webkit}[name]).launch(options);
  try {
    const context = await browser.newContext({viewport: {width: 844, height: 390}, hasTouch: true, isMobile: true, deviceScaleFactor: 3});
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (message.type() === 'error' || /SCRIPT ERROR:|\bERROR:/.test(message.text())) errors.push(message.text());
    });
    page.on('response', response => { if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`); });
    const wait = ms => page.waitForTimeout(ms);
    const capture = async label => page.screenshot({path: `${output}/${name}-${label}.png`, scale: 'css'});
    const tap = async (x, y) => {
      const b = await page.locator('#canvas').boundingBox();
      await page.touchscreen.tap(b.x + x * b.width / 640, b.y + y * b.height / 360);
      await wait(250);
    };
    const action = async code => {
      const button = page.locator(`[data-code="${code}"]`);
      if (code === 'KeyE' && !fullGameplay && await button.isDisabled()) return;
      await button.tap(); await wait(250);
    };
    // A held pointer exercises the same Pointer Events/capture path as a held finger.
    const hold = async (code, ms) => {
      const b = await page.locator(`[data-code="${code}"]`).boundingBox();
      await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2);
      await page.mouse.down(); await wait(ms); await page.mouse.up(); await wait(150);
    };
    const layers = await Promise.all(['body', 'clothes', 'face', 'eyes', 'hair'].map(async layer => fs.readFile(path.join(__dirname, `../assets/characters/${layer}.png`), 'base64')));
    // Observe rendered pixels: fixed walk durations drift on slower CI machines.
    // This reads the actual sprite, without reading or changing gameplay state.
    let lastPosition = {x: 320, y: 222};
    const playerPosition = async () => {
      const found = await page.evaluate(async ({layers, lastPosition}) => {
      async function pixels(url) {
        const img = new Image(); img.src = url; await img.decode();
        const surface = document.createElement('canvas');
        surface.width = img.width; surface.height = img.height;
        const ctx = surface.getContext('2d'); ctx.drawImage(img, 0, 0);
        return ctx.getImageData(0, 0, img.width, img.height);
      }
      const sheets = await Promise.all(layers.map(data => pixels('data:image/png;base64,' + data)));
      const source = new ImageData(288, 32);
      const tints = [[245,211,189], [255,255,255], [255,255,255], [116,81,61], [128,96,75]];
      for (let n = 0; n < sheets.length; n++) {
        const sheet = sheets[n];
        // Default hair is row 0, every layer has the same 12 aligned cells.
        for (let i = 0; i < source.data.length; i += 4) {
          if (!sheet.data[i + 3]) continue;
          for (let c = 0; c < 3; c++) source.data[i + c] = Math.round(sheet.data[i + c] * tints[n][c] / 255);
          source.data[i + 3] = 255;
        }
      }
      const frame = await pixels(document.getElementById('canvas').toDataURL());
      // Match the actual nearest-filtered sprite at the compact room's 1.15 zoom.
      // Return world coordinates; gameplay checks still drive ordinary input.
      const zoom = 1.15;
      let best = null;
      for (let pose = 0; pose < 12; pose++) {
        const samples = [];
        for (let y = 4; y < 29; y++) for (let x = 3; x < 21; x++) {
          const i = (y * source.width + pose * 24 + x) * 4;
          // Flat interior pixels survive the zoom's subpixel phase unchanged.
          const same = (dx, dy) => {
            const j = ((y + dy) * source.width + pose * 24 + x + dx) * 4;
            return [0, 1, 2, 3].every(c => source.data[j + c] === source.data[i + c]);
          };
          if (source.data[i + 3] === 255 && same(-1, 0) && same(1, 0) && same(0, -1) && same(0, 1)) samples.push([
            Math.floor((x + .5) * zoom), Math.floor((y + .5) * zoom), ...source.data.slice(i, i + 3)
          ]);
        }
        // A 350ms held input moves at most 34 world pixels. Keeping the search
        // near the previous observation also avoids similarly coloured decor.
        const expectedLeft = (lastPosition.x - 12 - 320) * zoom + 320;
        const expectedTop = (lastPosition.y - 20 - 180) * zoom + 180;
        for (let top = Math.max(40, Math.floor(expectedTop - 55)); top < Math.min(325, expectedTop + 55); top++)
          for (let left = Math.max(105, Math.floor(expectedLeft - 55)); left < Math.min(525, expectedLeft + 55); left++) {
          let hits = 0;
          for (let n = 0; n < samples.length; n++) {
            const [x, y, r, g, b] = samples[n];
            const i = ((top + y) * frame.width + left + x) * 4;
            if (Math.abs(frame.data[i] - r) <= 1 && Math.abs(frame.data[i + 1] - g) <= 1 && Math.abs(frame.data[i + 2] - b) <= 1) hits++;
            if (hits + samples.length - n - 1 < samples.length * .65) break;
          }
          const score = hits / samples.length;
          if (score >= .65 && (!best || score > best.score)) best = {
            x: (left + 12 * zoom - 320) / zoom + 320,
            y: (top + 20 * zoom - 180) / zoom + 180, score
          };
        }
      }
      if (best) return best;
      throw new Error('Shopkeeper sprite not visible in the rendered world');
      }, {layers, lastPosition});
      lastPosition = found;
      return found;
    };
    const walkTo = async (x, y) => {
      for (let attempt = 0; attempt < 24; attempt++) {
        const position = await playerPosition();
        if (process.env.TRACE_ROUTES) console.log({target: [x,y], position});
        const dx = x - position.x, dy = y - position.y;
        if (Math.abs(dx) <= 4 && Math.abs(dy) <= 4) return;
        const horizontal = Math.abs(dx) > Math.abs(dy);
        const distance = horizontal ? dx : dy;
        await hold(horizontal ? (dx > 0 ? 'ArrowRight' : 'ArrowLeft') : (dy > 0 ? 'ArrowDown' : 'ArrowUp'),
          Math.max(40, Math.min(350, Math.abs(distance) / 95 * 1000)));
      }
      throw new Error(`Cannot reach (${x}, ${y}); sprite at ${JSON.stringify(await playerPosition())}`);
    };
    const start = async () => {
      await page.locator('#start').tap();
      await page.waitForFunction(() => document.body.dataset.gameReady === 'true', null, {timeout: 60000});
      await wait(700);
    };
    const saved = () => page.evaluate(() => new Promise((resolve, reject) => {
      const request = indexedDB.open('/userfs');
      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        const db = request.result;
        const tx = db.transaction('FILE_DATA', 'readonly');
        const cursor = tx.objectStore('FILE_DATA').openCursor();
        let result = null;
        cursor.onsuccess = () => {
          const c = cursor.result;
          if (!c) return;
          if (String(c.key).endsWith('/village_save.json')) result = JSON.parse(new TextDecoder().decode(c.value.contents));
          c.continue();
        };
        tx.oncomplete = () => { db.close(); resolve(result); };
        tx.onerror = () => { db.close(); reject(tx.error); };
      };
    }));
    const awaitSave = async predicate => {
      for (let attempt = 0; attempt < 40; attempt++) {
        const data = await saved();
        if (data && predicate(data)) return data;
        await wait(250);
      }
      throw new Error(`Save did not reach expected state: ${JSON.stringify(await saved())}`);
    };
    await page.goto(url);
    await start(); await tap(150, 177); // New game, fresh isolated browser context.
    await tap(450, 320); // Confirm default character in the separate wardrobe.
    await awaitSave(data => data.economy.balance === '100');
    await action('KeyI'); await capture('bag'); await action('KeyI');
    if (fullGameplay) {
      await walkTo(320, 255); await walkTo(424, 255);
      assert.equal(await page.locator('#action-label').textContent(), 'Заказать товары');
      await action('KeyE');
      assert(await page.locator('[data-code="KeyE"]').isDisabled(), 'Interaction is unavailable while a menu is open');
      await tap(500, 124); // Order one apple: 100 -> 97.
      await capture('supplier'); await action('Escape');
      await walkTo(208, 255); await action('KeyE');
      for (let count = 0; count < 3; count++) await tap(444, 122);
      await capture('storage'); await action('Escape');
      await walkTo(320, 255); await walkTo(320, 180); await walkTo(208, 180);
      await action('KeyE'); await tap(464, 133); // Stock one apple, keep two in the bag.
      await capture('shelf'); await action('Escape');
      await walkTo(320, 180); await walkTo(320, 260); await walkTo(246, 260);
      await capture('interior');
      // Let the real clock reach 09:00 and the first real visitor reach the counter.
      await wait(45000); await capture('visitors');
      await action('KeyE'); await capture('checkout-before');
      // The first visitor can still be walking on a slower CI renderer. Checkout
      // deliberately lets that visit finish; rejected taps must not create sales.
      // Keep the menu open (blocking new arrivals) and serve once it becomes ready.
      for (let attempt = 0; attempt < 20; attempt++) {
        await tap(320, 250);
        await wait(500);
      }
      await wait(9000); await capture('checkout-after');
      await action('Escape'); await action('Escape');
      // Closing checkout can admit the next empty-handed visitor before pause opens.
      // Respect the real empty-shop save guard instead of relying on that frame timing.
      let saveReady = false;
      for (let attempt = 0; attempt < 40; attempt++) {
        saveReady = await page.evaluate(async () => {
          const img = new Image(); img.src = document.getElementById('canvas').toDataURL(); await img.decode();
          const surface = document.createElement('canvas'); surface.width = 640; surface.height = 360;
          const ctx = surface.getContext('2d'); ctx.drawImage(img, 0, 0);
          const [r, g, b] = ctx.getImageData(130, 194, 1, 1).data;
          return r === 188 && g === 197 && b === 172; // Enabled muted sage (#BCC5AC), distinct from disabled paper.
        });
        if (saveReady) break;
        await action('Escape'); await wait(500); await action('Escape');
      }
      assert(saveReady, `${name}: shop did not become empty for manual saving`);
      await tap(320, 192);
    } else {
      // Continuous release gate: exercise real on-screen input and persistence
      // during preparation, independently of visitor timing and sprite occlusion.
      for (const code of ['ArrowDown', 'ArrowRight', 'ArrowUp', 'ArrowLeft']) await hold(code, 160);
      await action('KeyE');
      await capture('interior');
      await action('Escape'); await tap(320, 192);
    }
    await capture('saved');
    const data = await awaitSave(data => fullGameplay ? data.economy.completed_sales === '1' : data.minute > 480);
    assert.equal(data.economy.balance, fullGameplay ? '102' : '100');
    assert.equal(data.bag.items.apple || 0, fullGameplay ? 2 : 0);
    assert.equal(data.storage.items.apple, fullGameplay ? 4 : 6);
    assert.equal(data.shelves.LeftShelf.items.apple || 0, 0);
    const minute = data.minute;
    await page.reload(); await start(); await tap(150, 202); // Continue.
    await action('Escape'); await tap(320, 192);
    const restored = await awaitSave(next => next.minute > minute);
    assert.deepEqual(restored.character, data.character);
    assert.deepEqual(restored.economy, data.economy);
    assert.deepEqual(restored.bag, data.bag);
    assert.deepEqual(restored.storage, data.storage);
    await capture('continued');
    // Rotation and small landscape: canvas and controls stay inside the browser viewport.
    for (const viewport of [{width: 390, height: 844}, {width: 667, height: 375}, {width: 844, height: 300}]) {
      await page.setViewportSize(viewport); await wait(300);
      for (const selector of ['#canvas', ...['ArrowUp', 'ArrowLeft', 'ArrowRight', 'ArrowDown', 'KeyE', 'KeyI', 'Escape'].map(code => `[data-code="${code}"]`)]) {
        const b = await page.locator(selector).boundingBox();
        assert(b && b.x >= 0 && b.y >= 0 && b.x + b.width <= viewport.width + 1 && b.y + b.height <= viewport.height + 1, `${name}: ${selector} outside ${JSON.stringify(viewport)}`);
      }
      await capture(`${viewport.width}x${viewport.height}`);
    }
    assert.deepEqual(errors, [], `${name}: browser/engine errors`);
    console.log(`${name}: touch UI, ${fullGameplay ? 'purchase/transfer/restock/sale' : 'D-pad/menus/manual-save'}, IndexedDB save + Continue, rotation: PASS`);
    await context.close();
  } catch (error) {
    const page = browser.contexts()[0]?.pages()[0];
    if (page) await page.screenshot({path: `${output}/${name}-failure.png`, scale: 'css'}).catch(() => {});
    throw error;
  } finally { await browser.close(); }
}
(async () => { await fs.mkdir(output, {recursive: true}); for (const name of engines) await check(name); })().catch(error => { console.error(error); process.exitCode = 1; });

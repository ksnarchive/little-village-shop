/* Real HTTP cache + real release export, same origin and IndexedDB across updates. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const http = require('node:http');
const {webkit, devices} = require('playwright');
const directory = path.resolve(__dirname, '../builds/web');
const output = path.resolve(__dirname, '../builds/browser-checks');
const previous = '1'.repeat(40);

(async () => {
  const info = JSON.parse(await fs.readFile(path.join(directory, 'build-info.json')));
  assert.notEqual(info.commit, previous);
  let current = previous;
  let unavailable = false;
  const requests = [];
  const server = http.createServer(async (req, res) => {
    const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname.split('/').pop()) || 'index.html';
    requests.push(name);
    if (name === 'build-info.json') {
      res.writeHead(unavailable ? 503 : 200, {'Content-Type':'application/json', 'Cache-Control':'max-age=600'});
      return res.end(JSON.stringify({...info, commit:current, entry:`index.${current}.html`}));
    }
    // Both release filenames exist on the fixture host. Their PCK contents are
    // identical: this test isolates update routing and persistence from gameplay changes.
    if (!/^[a-zA-Z0-9.-]+$/.test(name)) { res.writeHead(404); return res.end(); }
    const source = name.replace(previous, info.commit);
    try {
      let content = await fs.readFile(path.join(directory, source));
      if (name.endsWith('.html')) content = Buffer.from(content.toString().replaceAll(info.commit, name.includes(previous) ? previous : info.commit));
      const type = name.endsWith('.wasm') ? 'application/wasm' : name.endsWith('.js') ? 'text/javascript' : name.endsWith('.html') ? 'text/html' : 'application/octet-stream';
      res.writeHead(200, {'Content-Type':type, 'Cache-Control':'max-age=600'});
      res.end(content);
    } catch { res.writeHead(404); res.end(); }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}/little-village-shop/`;
  const browser = await webkit.launch();
  const context = await browser.newContext({...devices['iPhone 13 landscape']});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR:|\bERROR:/.test(message.text())) errors.push(message.text()); });
  const tap = async (x, y) => {
    const b = await page.locator('#canvas').boundingBox();
    await page.touchscreen.tap(b.x + x * b.width / 640, b.y + y * b.height / 360);
    await page.waitForTimeout(300);
  };
  const boot = async () => {
    await page.locator('#start').tap();
    await page.waitForFunction(() => document.body.dataset.gameReady === 'true');
    await page.waitForTimeout(700);
  };
  // Read all persisted bytes, including settings and backup saves. Never alter IDB.
  const persisted = () => page.evaluate(() => new Promise((resolve, reject) => {
    const request = indexedDB.open('/userfs');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('FILE_DATA', 'readonly');
      const r = tx.objectStore('FILE_DATA').getAll();
      r.onsuccess = () => { const values = r.result.map(v => Array.from(v.contents || [])); db.close(); resolve(values); };
      r.onerror = () => reject(r.error);
    };
  }));
  try {
    await fs.mkdir(output, {recursive:true});
    await page.goto(url);
    await page.waitForFunction(sha => document.documentElement.dataset.build === sha, previous);
    await boot(); await tap(150,177); await tap(450,320);
    await page.waitForFunction(() => !document.body.classList.contains('frontend'));
    await page.waitForTimeout(2000);
    const before = await persisted();
    assert(before.some(v => Buffer.from(v).toString().includes('"character"')), 'Real game save exists');
    // Simulate a deployment while old HTML and engine resources are still fresh
    // in WebKit's cache. Reload the old release URL, then the cached stable entry.
    current = info.commit;
    requests.length = 0;
    await page.goto(new URL(`index.${previous}.html`, url).href);
    await page.waitForFunction(sha => document.documentElement.dataset.build === sha, info.commit);
    await boot();
    assert.equal(await page.locator('html').getAttribute('data-build'), info.commit);
    assert.equal(await page.locator('#movement').isVisible(), false);
    assert.deepEqual(await persisted(), before, 'Loading update preserves every persisted byte');
    for (const extension of ['js','wasm','pck']) {
      assert(requests.includes(`index.${info.commit}.${extension}`), `New ${extension} requested`);
      assert(!requests.includes(`index.${previous}.${extension}`), `No stale ${extension} requested`);
      assert(!requests.includes(`index.${extension}`), `No unversioned ${extension} requested`);
    }
    await page.screenshot({path:path.join(output,'webkit-update-menu.png')});
    await tap(150,177); await page.keyboard.press('Escape'); // Existing-save warning: cancel.
    assert.deepEqual(await persisted(), before);
    await tap(150,177); await page.keyboard.press('Shift+Tab'); await page.keyboard.press('Enter'); await page.waitForTimeout(300); // Open editor, not replacement.
    await tap(320,274); // Back from wardrobe.
    assert.deepEqual(await persisted(), before, 'Cancelling wardrobe preserves save');
    await page.keyboard.press('Enter'); // Continue is focused after Back.
    await page.waitForFunction(() => !document.body.classList.contains('frontend'));
    assert(await page.locator('#movement').isVisible());
    assert(await page.locator('[data-code="KeyI"]').isEnabled());
    await page.screenshot({path:path.join(output,'webkit-update-continued.png')});
    await page.goto(url); // Stable bootstrap is cached but its manifest fetch is not.
    await page.waitForFunction(sha => document.documentElement.dataset.build === sha, info.commit);
    assert.deepEqual(await persisted(), before);
    assert.equal(page.url(), url, 'Bookmarks and reloads use the stable URL');
    // A failed version check must never silently launch cached game resources.
    unavailable = true;
    requests.length = 0;
    await page.goto(new URL(`index.${info.commit}.html`, url).href);
    await page.waitForFunction(() => document.querySelector('#notice').textContent.includes('Игра не загрузилась'));
    assert(await page.locator('#start').isDisabled());
    assert(!requests.some(name => /\.(js|wasm|pck)$/.test(name)));
    assert.deepEqual(await persisted(), before);
    assert.deepEqual(errors, []);
    console.log('webkit iPhone: cached HTML update, versioned JS/WASM/PCK, cancel/Continue, unchanged IndexedDB, fail-closed version check: PASS');
  } catch (error) {
    await page.screenshot({path:path.join(output,'webkit-update-failure.png')}).catch(() => {});
    throw error;
  } finally { await context.close(); await browser.close(); await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });

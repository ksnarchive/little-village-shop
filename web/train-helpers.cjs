// Shared real UI action for checks whose subject begins in the shop.
exports.arriveStation = async (page, tap) => {
  const [width, height] = await page.locator('#canvas').evaluate(c => [c.width, c.height]);
  await tap(width - 70, 30);
  await tap(width / 2, height / 2 + 44);
  await page.waitForFunction(() => !document.body.classList.contains('frontend'), null, {timeout: 10000});
  await page.waitForTimeout(900);
};

// Read the persisted position to steer ordinary D-pad input, without game hooks.
exports.saved = page => page.evaluate(() => new Promise((resolve, reject) => {
  const r = indexedDB.open('/userfs'); r.onerror = () => reject(r.error);
  r.onsuccess = () => {
    const db = r.result, tx = db.transaction('FILE_DATA', 'readonly'); let value = null;
    const cursor = tx.objectStore('FILE_DATA').openCursor();
    cursor.onsuccess = () => { const c = cursor.result; if (!c) return;
      if (String(c.key).endsWith('/village_save.json')) value = JSON.parse(new TextDecoder().decode(c.value.contents));
      c.continue(); };
    tx.oncomplete = () => { db.close(); resolve(value); }; tx.onerror = () => reject(tx.error);
  };
}));

exports.stationWalk = async (page, x, y) => {
  for (let step = 0; step < 35; step++) {
    const data = await exports.saved(page);
    if (data?.journey?.location === 'shop') return;
    if (!data?.journey) throw Error('Station save is missing');
    const [px, py] = data.journey.position, dx = x - px, dy = y - py;
    if (process.env.TRACE_ROUTES) console.log('station route', {target:[x,y],position:[px,py]});
    if (Math.abs(dx) < 6 && Math.abs(dy) < 6) return;
    const horizontal = Math.abs(dx) > Math.abs(dy), distance = horizontal ? dx : dy;
    const code = horizontal ? (dx > 0 ? 'ArrowRight' : 'ArrowLeft') : (dy > 0 ? 'ArrowDown' : 'ArrowUp');
    const b = await page.locator(`[data-code="${code}"]`).boundingBox();
    await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2);
    await page.mouse.down(); await page.waitForTimeout(Math.max(45, Math.min(900, Math.abs(distance) / 95 * 1000)));
    await page.mouse.up();
    // The destination file is committed before the fade, but IndexedDB sync is
    // asynchronous. Never steer the new room from a stale outdoor checkpoint.
    await page.waitForTimeout(x >= 676 && px > 590 ? 4000 : 2200);
  }
  throw Error(`Station route cannot reach (${x}, ${y}): ${JSON.stringify(await exports.saved(page))}`);
};

exports.leaveStation = async page => {
  await exports.stationWalk(page, 350, 422);
  await exports.stationWalk(page, 690, 422);
  await page.waitForTimeout(1600);
  const data = await exports.saved(page);
  if (data?.journey?.location !== 'shop') throw Error('Village path did not reach the shop');
};

exports.skipTrain = async (page, tap) => {
  await exports.arriveStation(page, tap);
  await exports.leaveStation(page);
};

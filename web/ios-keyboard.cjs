/* Mobile WebKit regression against the real Godot export.
 * WebKit on Linux does not show Apple's keyboard or reproduce iOS focus zoom.
 * Native DOM focus/fonts/rotation are real. A test-only VisualViewport fixture
 * models keyboard occlusion, Safari panning and late dismissal notifications.
 */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const {webkit, devices} = require('playwright');
const output = process.env.CAPTURE_DIR || '../builds/browser-checks';

(async () => {
  await fs.mkdir(output, {recursive:true});
  const browser = await webkit.launch();
  const context = await browser.newContext({...devices['iPhone 13 landscape'], screen:undefined});
  await context.addInitScript(() => {
    const native = window.visualViewport;
    const events = new EventTarget();
    let override = null;
    for (const key of ['width','height','offsetTop','offsetLeft','pageTop','pageLeft','scale']) {
      Object.defineProperty(events, key, {get:() => override && key in override ? override[key] : native[key]});
    }
    for (const type of ['resize','scroll']) native.addEventListener(type, () => events.dispatchEvent(new Event(type)));
    Object.defineProperty(window, 'visualViewport', {value:events});
    window.keyboardViewportFixture = {
      set(value, type = 'resize') { override = value; if (type) events.dispatchEvent(new Event(type)); },
      clear(notify = true) { override = null; if (notify) events.dispatchEvent(new Event('resize')); }
    };
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error' || /SCRIPT ERROR:|\bERROR:/.test(message.text())) errors.push(message.text()); });
  const wait = ms => page.waitForTimeout(ms);
  const tap = async (x,y) => {
    const box = await page.locator('#canvas').boundingBox();
    const [w,h] = await page.locator('#canvas').evaluate(c => [c.width,c.height]);
    await page.touchscreen.tap(box.x+x*box.width/w, box.y+y*box.height/h);
    await wait(250);
  };
  const editing = () => page.evaluate(() => document.activeElement.matches('input,textarea,[contenteditable="true"]'));
  const dimensions = () => page.locator('#canvas').evaluate(c => [c.width,c.height]);
  async function contained(label) {
    const result = await page.evaluate(() => {
      const layout = document.getElementById('layout');
      const css = getComputedStyle(layout), v = visualViewport;
      const safe = {left:v.offsetLeft+parseFloat(css.paddingLeft), top:v.offsetTop+parseFloat(css.paddingTop), right:v.offsetLeft+v.width-parseFloat(css.paddingRight), bottom:v.offsetTop+v.height-parseFloat(css.paddingBottom)};
      const canvas = document.getElementById('canvas').getBoundingClientRect();
      return {safe, canvas:{x:canvas.x,y:canvas.y,right:canvas.right,bottom:canvas.bottom,width:canvas.width,height:canvas.height}};
    });
    const {canvas:c,safe:s} = result;
    assert(c.width > 0 && c.height > 0 && c.x >= s.left-1 && c.y >= s.top-1 && c.right <= s.right+1 && c.bottom <= s.bottom+1, `${label}: ${JSON.stringify(result)}`);
    return c;
  }
  const saved = () => page.evaluate(() => new Promise((resolve,reject) => {
    const request = indexedDB.open('/userfs');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result, tx = db.transaction('FILE_DATA','readonly');
      const cursor = tx.objectStore('FILE_DATA').openCursor(); let value = null;
      cursor.onsuccess = () => {const c=cursor.result;if(!c)return;if(String(c.key).endsWith('/village_save.json'))value=JSON.parse(new TextDecoder().decode(c.value.contents));c.continue();};
      tx.oncomplete = () => {db.close();resolve(value);};
    };
  }));
  try {
    await page.goto(process.env.GAME_URL || 'http://127.0.0.1:8060/');
    await page.locator('#start').tap();
    await page.waitForFunction(() => document.body.dataset.gameReady === 'true', null, {timeout:60000});
    await wait(900);
    const meta = await page.locator('meta[name="viewport"]').getAttribute('content');
    assert(!/user-scalable\s*=\s*(no|0)|(?:maximum|minimum)-scale/i.test(meta), 'No browser zoom restriction');
    await tap(150,177);
    assert.equal(await editing(),false,'Opening wardrobe must not focus a native text/IME field');
    for (const field of await page.locator('#screen input,#screen textarea,#screen [contenteditable="true"]').all()) {
      assert(await field.evaluate(e => parseFloat(getComputedStyle(e).fontSize)>=16), 'Every Godot keyboard/IME proxy has at least 16 CSS px before focus');
    }
    await tap(450,90);
    assert.equal(await editing(),true,'Only deliberately tapping the name opens native input');
    await page.locator('#screen input:enabled').fill('Ника');
    await wait(150);
    await page.setViewportSize({width:390,height:844});
    await wait(500);
    assert.deepEqual(await dimensions(),[400,740]);
    assert.equal(await page.locator('#screen input:enabled').inputValue(),'Ника','Typing survives rotation');
    const original = await contained('portrait before keyboard');

    // Explicit notch/home-indicator insets; Playwright does not emulate real safe-area hardware.
    await page.evaluate(() => {
      for (const [side,size] of Object.entries({top:44,right:12,bottom:34,left:12})) document.documentElement.style.setProperty(`--safe-${side}`,`${size}px`);
      keyboardViewportFixture.set({width:390,height:320,offsetLeft:0,offsetTop:120,scale:1});
    });
    await wait(200);
    assert.deepEqual(await dimensions(),[400,740],'Keyboard occlusion does not flip logical orientation');
    await contained('keyboard visual viewport and safe area');
    const proxyAligned = await page.locator('#screen input:enabled').evaluate(e => {
      const a=e.getBoundingClientRect(),b=document.getElementById('canvas').getBoundingClientRect();
      return ['left','top','width','height'].every(k => Math.abs(a[k]-b[k])<1);
    });
    assert(proxyAligned,'Native input proxy stays aligned with the resized canvas');
    await page.evaluate(() => keyboardViewportFixture.set({width:360,height:260,offsetLeft:15,offsetTop:150,scale:1},'scroll'));
    await wait(200);
    await contained('Safari pans its visible area');
    // Focusout can precede the final viewport restoration; no resize event in this case.
    await page.locator('#screen input:enabled').evaluate(e => e.blur());
    await wait(80);
    await page.evaluate(() => {
      keyboardViewportFixture.clear(false);
      for (const side of ['top','right','bottom','left']) document.documentElement.style.removeProperty(`--safe-${side}`);
    });
    await wait(550);
    assert.equal(await editing(),false);
    const restored = await contained('after keyboard dismissal');
    for (const key of ['x','y','width','height']) assert(Math.abs(restored[key]-original[key])<1,'Closing keyboard restores the original complete game rect');
    // User pinch zoom is neither reset nor cancelled by counter-scaling the layout.
    const layoutBefore = await page.locator('#layout').boundingBox();
    await page.evaluate(() => keyboardViewportFixture.set({width:260,height:500,offsetLeft:20,offsetTop:30,scale:1.5}));
    await wait(150);
    assert.deepEqual(await page.locator('#layout').boundingBox(),layoutBefore,'Deliberate zoom is not counteracted');
    assert.equal(await page.locator('meta[name="viewport"]').getAttribute('content'),meta);
    await page.setViewportSize({width:844,height:390});
    await wait(350);
    assert.deepEqual(await dimensions(),[640,360],'Rotation also works during deliberate zoom');
    const zoomLayout = await page.locator('#layout').boundingBox();
    assert(Math.abs(zoomLayout.width-844)<1 && Math.abs(zoomLayout.height-390)<1,'Zoom cannot leave stale portrait layout dimensions after rotation');
    assert.equal(await page.evaluate(() => visualViewport.scale),1.5,'User zoom is not reset');
    assert.equal(await editing(),false,'Rotating after blur does not reopen native editing');
    await page.setViewportSize({width:390,height:844});
    await wait(350);
    await page.evaluate(() => keyboardViewportFixture.clear());
    await wait(150);
    // Repeat editing, then dismiss by tapping a normal in-game action.
    await tap(200,382);
    assert.equal(await editing(),true,'Name can be intentionally reopened after blur');
    await tap(350,700);
    await wait(1700);
    assert.equal(await editing(),false,'Editor -> train leaves no stale keyboard focus');
    let data = null;
    for (let attempt=0;attempt<40;attempt++) { data=await saved();if(data)break;await wait(200); }
    assert(data && data.character.name==='Ника' && data.story.train_complete===false,'Name and unfinished train save are unchanged');
    await contained('train after keyboard dismissal');
    await page.screenshot({path:`${output}/webkit-ios-keyboard-train-portrait.png`,scale:'css'});
    for (const size of [{width:844,height:390},{width:375,height:667},{width:667,height:375},{width:844,height:300},{width:390,height:844}]) {
      await page.setViewportSize(size);await wait(400);
      assert.deepEqual(await dimensions(),size.height>size.width?[400,740]:[640,360]);
      await contained(`train ${size.width}x${size.height}`);
      assert.equal(await editing(),false,'Rotation never reopens keyboard');
      if(size.width===844&&size.height===390)await page.screenshot({path:`${output}/webkit-ios-keyboard-train-landscape.png`,scale:'css'});
    }
    assert.deepEqual(errors,[]);
    console.log('WebKit iPhone: explicit-only name focus, >=16px native fields/IME, visualViewport occlusion/pan/late blur, safe area, restored canvas, train + rotation, zoom preserved: PASS (OS keyboard/auto-zoom not emulated)');
  } catch (error) {
    await page.screenshot({path:`${output}/webkit-ios-keyboard-failure.png`,scale:'css'}).catch(()=>{});
    throw error;
  } finally {await context.close();await browser.close();}
})().catch(error => {console.error(error);process.exitCode=1;});

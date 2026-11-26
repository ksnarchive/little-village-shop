/* Real release-export UI checks and captures. No state-injection/debug APIs. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const {chromium, webkit, devices} = require('playwright');
const url = process.env.GAME_URL || 'http://127.0.0.1:8060/';
const output = process.env.CAPTURE_DIR || '../builds/browser-checks';
const engines = (process.env.BROWSERS || 'chromium,webkit').split(',');
const docs = process.argv.includes('--docs');
async function check(engine) {
  const browser = await ({chromium, webkit}[engine]).launch(engine === 'chromium' ? {
    ...(process.env.CHROMIUM_PATH ? {executablePath: process.env.CHROMIUM_PATH} : {}),
    args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist']
  } : {});
  // Let Playwright rotate screen with viewport instead of pinning the descriptor's portrait screen.
  const context = await browser.newContext({...devices['iPhone 13 landscape'], screen: undefined});
  const page = await context.newPage();
  const errors=[];
  page.on('pageerror', error=>errors.push(error.message));
  page.on('console', msg=>{if(msg.type()==='error'||/SCRIPT ERROR:|\bERROR:/.test(msg.text())) {errors.push(msg.text());console.error(msg.text());}});
  const wait = ms=>page.waitForTimeout(ms);
  const capture = async name=> {
    await page.screenshot({path:path.join(output,`${engine}-${name}.png`),scale:'css'});
    if(docs&&engine==='chromium') await page.screenshot({path:path.join(__dirname,`../docs/${name}.png`),scale:'css'});
  };
  const tap=async(x,y)=>{const b=await page.locator('#canvas').boundingBox();const dim=await page.locator('#canvas').evaluate(c=>[c.width,c.height]);await page.touchscreen.tap(b.x+x*b.width/dim[0],b.y+y*b.height/dim[1]);await wait(200);};
  const boot=async()=>{await page.locator('#start').tap();await page.waitForFunction(()=>document.body.dataset.gameReady==='true',null,{timeout:60000});await wait(1000);};
  const spritePixels=()=>page.evaluate(async()=>{
    const image=new Image();image.src=document.querySelector('#canvas').toDataURL();await image.decode();
    const surface=document.createElement('canvas');surface.width=76;surface.height=96;
    const ctx=surface.getContext('2d');ctx.drawImage(image,282,160,76,96,0,0,76,96);
    return Array.from(ctx.getImageData(0,0,76,96).data);
  });
  const saved=()=>page.evaluate(()=>new Promise((resolve,reject)=>{
    const r=indexedDB.open('/userfs');r.onerror=()=>reject(r.error);r.onsuccess=()=>{
      const db=r.result,tx=db.transaction('FILE_DATA','readonly'),cursor=tx.objectStore('FILE_DATA').openCursor();let result=null;
      cursor.onsuccess=()=>{const c=cursor.result;if(!c)return;if(String(c.key).endsWith('/village_save.json'))result=JSON.parse(new TextDecoder().decode(c.value.contents));c.continue();};
      tx.oncomplete=()=>{db.close();resolve(result)};tx.onerror=()=>reject(tx.error);
    };
  }));
  const awaitSave=async()=>{for(let i=0;i<40;i++){const data=await saved();if(data)return data;await wait(250)}throw Error('No persisted character');};
  try {
    await page.goto(url);await boot();
    assert(await page.locator('body').evaluate(b=>b.classList.contains('frontend')));
    assert.equal(await page.locator('#movement').isVisible(),false);
    await capture('main-menu');
    await tap(150,277); // Settings.
    await capture('settings');
    await tap(320,300); // Done.
    await tap(150,177); // New game.
    assert.equal(await page.locator('#movement').isVisible(),false);
    await capture('wardrobe-default');
    await tap(320,274); // Back: cancellation must not create a save.
    assert.equal(await saved(),null);
    await tap(150,177); // Return to wardrobe.

    // Opening the editor leaves the keyboard closed. Tap the name deliberately.
    await tap(450,90);
    await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText('Лёва');await wait(200);
    await tap(600,138); // Skin, next.
    await tap(600,186); // Hairstyle, next.
    await capture('character-bob');
    // Random appearance, repeatable only in that every field must remain valid.
    await tap(480,274);await capture('character-random-1');
    await tap(480,274);await capture('character-random-2');
    await tap(122,336); // Rotate.
    await tap(176,336); // Walk preview.
    await capture('character-side-walking');
    // Portrait frontend uses its own 400x740 viewport, not a shrunken landscape UI.
    await page.setViewportSize({width:390,height:844});await wait(1000);
    assert.deepEqual(await page.locator('#canvas').evaluate(c=>[c.width,c.height]),[400,740]);
    const b=await page.locator('#canvas').boundingBox();
    assert(b.x>=0&&b.y>=0&&b.x+b.width<=391&&b.y+b.height<=845);
    await capture('wardrobe-iphone-portrait');
    // Mobile WebKit has no wheel input; follow-focus scrolls the real Godot list.
    for(let i=0;i<15;i++) await page.keyboard.press('Tab');
    await wait(400);
    await capture('wardrobe-iphone-outfits');
    await tap(210,699); // Confirm.
    const data=await awaitSave();
    assert.equal(data.character.name,'Лёва');assert.equal(data.version,3);
    for(const [key,count] of Object.entries({skin:6,hairstyle:8,hair_color:8,eyes:6,outfit:6}))assert(Number.isInteger(data.character[key])&&data.character[key]>=0&&data.character[key]<count);
    assert.equal(data.story.train_complete,false);
    await require('./train-helpers.cjs').skipTrain(page,tap);
    assert.equal(await page.locator('body').evaluate(b=>b.classList.contains('frontend')),false);
    assert.equal(await page.locator('#movement').isVisible(),true);
    await page.setViewportSize({width:1280,height:720});await wait(600);await capture('character-in-shop');const firstSprite=await spritePixels();
    await page.reload();await boot();await tap(150,206); // Continue with non-default appearance.
    await wait(500);await capture('character-continued');
    // Idle now breathes and blinks. Require the exact original rendered pose to
    // recur, rather than requiring two unrelated animation clocks to be equal.
    let samePose=false;
    for(let attempt=0;attempt<60;attempt++) {
      if(JSON.stringify(await spritePixels())===JSON.stringify(firstSprite)){samePose=true;break;}
      await wait(100);
    }
    assert(samePose,'Rendered non-default character survives Continue pixel for pixel through the idle cycle');
    // Manual save after Continue proves loaded appearance is retained by the real player.
    await page.keyboard.press('Escape');await wait(200);await tap(320,192);await wait(1800);
    assert.deepEqual((await saved()).character,data.character);
    assert.deepEqual(errors,[],`${engine}: browser/engine errors`);
    console.log(`${engine}: frontend, settings, Cyrillic name, live choices/random/turn/walk, portrait, character + progress persistence: PASS`);
  } catch(error) {console.error(errors);await page.screenshot({path:path.join(output,`${engine}-frontend-failure.png`)}).catch(()=>{});throw error;}
  finally {await context.close();await browser.close();}
}
(async()=>{await fs.mkdir(output,{recursive:true});for(const engine of engines)await check(engine);})().catch(error=>{console.error(error);process.exitCode=1});

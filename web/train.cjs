/* Real release UI + IndexedDB observation, without game/debug hooks. */
const assert=require('node:assert/strict'), fs=require('node:fs/promises'),path=require('node:path');
const {chromium,webkit,devices}=require('playwright');
const output=process.env.CAPTURE_DIR||'../builds/browser-checks',docs=process.argv.includes('--docs');
async function check(engine){
 const browser=await ({chromium,webkit}[engine]).launch(engine==='chromium'?{args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist'],...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{})}:{});
 const context=await browser.newContext({...devices['iPhone 13 landscape'],screen:undefined,viewport:{width:1280,height:720}}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR:|\bERROR:/.test(m.text()))errors.push(m.text())});
 const wait=ms=>page.waitForTimeout(ms);
 const tap=async(x,y)=>{const b=await page.locator('#canvas').boundingBox(),[w,h]=await page.locator('#canvas').evaluate(c=>[c.width,c.height]);await page.touchscreen.tap(b.x+x*b.width/w,b.y+y*b.height/h);await wait(180)};
 const boot=async()=>{await page.locator('#start').tap();await page.waitForFunction(()=>document.body.dataset.gameReady==='true',null,{timeout:60000});await wait(800)};
 const saved=()=>page.evaluate(()=>new Promise((resolve,reject)=>{const r=indexedDB.open('/userfs');r.onerror=()=>reject(r.error);r.onsuccess=()=>{const db=r.result,tx=db.transaction('FILE_DATA','readonly'),q=tx.objectStore('FILE_DATA').openCursor();let result=null;q.onsuccess=()=>{const c=q.result;if(!c)return;if(String(c.key).endsWith('/village_save.json'))result=JSON.parse(new TextDecoder().decode(c.value.contents));c.continue()};tx.oncomplete=()=>{db.close();resolve(result)};tx.onerror=()=>reject(tx.error)}}));
 const until=async predicate=>{for(let i=0;i<60;i++){const data=await saved();if(data&&predicate(data)){console.log(engine, "checkpoint", data.story);return data;}await wait(200)}throw Error(`Unexpected checkpoint ${JSON.stringify(await saved())}`)};
 const capture=async name=>{await page.screenshot({path:path.join(output,`${engine}-${name}.png`),scale:'css'});if(docs&&engine==='chromium')await page.screenshot({path:path.join(__dirname,`../docs/${name}.png`),scale:'css'})};
 const image=()=>page.locator('#canvas').evaluate(c=>c.toDataURL());
 try{
  await page.goto(process.env.GAME_URL||'http://127.0.0.1:8060/');await boot();await tap(150,177);
  await tap(450,90);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText('Тая');await tap(600,138);await tap(600,186);await tap(450,320);
  const initial=await until(d=>d.story?.train_line===0&&!d.story.train_complete);assert.equal(initial.character.name,'Тая');assert.equal(initial.version,4);assert.equal(await page.locator('#movement').isVisible(),false);
  await wait(4200);assert.equal((await saved()).story.train_line,0,'No auto-advancing dialogue');await capture('train-interior-dialogue');
  const frame=await image();await wait(550);assert.notEqual(await image(),frame,'Rendered landscape moves');
  await tap(100,160);await tap(100,160);await until(d=>d.story.train_line===1);assert.equal((await saved()).story.train_line,1,'Touch reveals without double advancement');
  await page.keyboard.press('Enter');await until(d=>d.story.train_line===2);
  await page.reload();await boot();await tap(150,206);await wait(700);assert.equal((await saved()).story.train_line,2,'Continue resumes trip');assert.equal(await page.locator('#movement').isVisible(),false);
  await page.setViewportSize({width:390,height:844});await wait(600);assert.deepEqual(await page.locator('#canvas').evaluate(c=>[c.width,c.height]),[400,740]);
  await wait(4000);await tap(350,700);await until(d=>d.story.train_line===3);await wait(4000);await capture('train-iphone-portrait');
  await tap(330,30);await capture('train-skip-confirmation');await tap(200,360);assert.equal((await saved()).story.train_line,3,'Cancel preserves progress');
  for(const v of [{width:667,height:375},{width:844,height:300},{width:390,height:844}]){await page.setViewportSize(v);await wait(400);const b=await page.locator('#canvas').boundingBox();assert(b.x>=0&&b.y>=0&&b.x+b.width<=v.width+1&&b.y+b.height<=v.height+1);assert.equal(await page.locator('#movement').isVisible(),false)}
  await page.setViewportSize({width:1280,height:720});await wait(600);
  for(let line=4;line<=10;line++){await wait(4000);await page.keyboard.press('Space');await until(d=>d.story.train_line===line)}
  await wait(3900);await capture('train-arrival');await page.keyboard.press('Enter');await wait(400);await until(d=>d.story.train_complete);await page.waitForFunction(()=>!document.body.classList.contains('frontend'));await capture('train-hero-on-station');
  const completed=await saved();assert.equal(completed.journey.location,'station');assert.deepEqual(completed.character,initial.character);for(const key of ['economy','storage','bag','shelves','minute'])assert.deepEqual(completed[key],initial[key],`Train preserves ${key}`);
  await page.reload();await boot();await tap(150,206);await page.waitForFunction(()=>!document.body.classList.contains('frontend'));assert.equal(await page.locator('#movement').isVisible(),true);assert.deepEqual(errors,[],`${engine}: browser/engine errors`);
  console.log(`${engine}: train motion, touch/keyboard, manual dialogue, interrupted Continue, portrait/rotation, cancel skip, arrival/fade, identity + shop persistence: PASS`);
 }catch(e){await capture('train-failure').catch(()=>{});console.error(errors);throw e}finally{await context.close();await browser.close()}
}
(async()=>{await fs.mkdir(output,{recursive:true});for(const engine of (process.env.BROWSERS||'chromium,webkit').split(','))await check(engine)})().catch(e=>{console.error(e);process.exitCode=1});

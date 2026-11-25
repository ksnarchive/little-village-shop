/* Screenshots of the real export using player-visible controls only. */
const {chromium,devices}=require('playwright');
(async()=>{
 const browser=await chromium.launch({args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 const context=await browser.newContext({...devices['iPhone 13 landscape'],screen:undefined,viewport:{width:1280,height:720}}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR:|\bERROR:/.test(m.text()))errors.push(m.text())});
 const wait=ms=>page.waitForTimeout(ms),tap=async(x,y)=>{const b=await page.locator('#canvas').boundingBox(),[w,h]=await page.locator('#canvas').evaluate(c=>[c.width,c.height]);await page.touchscreen.tap(b.x+x*b.width/w,b.y+y*b.height/h);await wait(300)};
 const capture=async name=>{await page.screenshot({path:`../docs/${name}.png`,scale:'css'});console.log(name)};
 try{
  await page.goto(process.env.GAME_URL||'http://127.0.0.1:8060/');await page.locator('#start').tap();await page.waitForFunction(()=>document.body.dataset.gameReady==='true');await wait(900);
  await tap(150,177);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText('Тая');await tap(600,186);await tap(450,320);await wait(4200);
  await capture('train-art-monologue');await page.keyboard.press('h');await wait(200);await capture('train-art-full-scene');await tap(100,120);
  await page.setViewportSize({width:390,height:844});await wait(900);await capture('train-art-iphone-portrait');
  await page.setViewportSize({width:844,height:390});await wait(900);await capture('train-art-iphone-landscape');
  console.log('Errors:',errors);if(errors.length)throw Error(errors.join('\n'));
 }finally{await context.close();await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});

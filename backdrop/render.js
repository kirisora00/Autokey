// Usage: node render.js "$PWD" 2 out.png  -> renders backdrop.html at 6000x4000
const {chromium}=require('playwright');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:3000,height:2000},deviceScaleFactor:+(process.argv[3]||1)});
await p.goto('file://'+process.argv[2]+'/backdrop.html');await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(300);
await p.screenshot({path:process.argv[2]+'/'+(process.argv[4]||'preview.png')});await b.close();})();

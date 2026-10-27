import {Miniflare} from 'miniflare';
import {build} from 'esbuild';
import {readFileSync,readdirSync,mkdirSync,rmSync} from 'node:fs';
import assert from 'node:assert/strict';
const base=new URL('../',import.meta.url).pathname;
mkdirSync(base+'outputs',{recursive:true});
const persist=base+'outputs/runtime-test-db';rmSync(persist,{recursive:true,force:true});
await build({entryPoints:[base+'tests/runtime-worker.mjs'],bundle:true,format:'esm',platform:'browser',target:'es2022',outfile:base+'outputs/runtime-worker.mjs'});
const options={modules:true,scriptPath:base+'outputs/runtime-worker.mjs',compatibilityDate:'2026-05-15',d1Databases:{DB:'test-accounting-runtime'},d1Persist:persist};
let mf=new Miniflare(options);
try{const db=await mf.getD1Database('DB');const sql=readdirSync(base+'drizzle').filter(f=>f.endsWith('.sql')).sort().map(f=>readFileSync(base+'drizzle/'+f,'utf8')).join('\n--> statement-breakpoint\n');const statements=sql.split('--> statement-breakpoint').map(x=>x.trim()).filter(Boolean);await db.batch(statements.map(s=>db.prepare(s)));
async function call(payload,status=200){const r=await mf.dispatchFetch('http://test.local/',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(payload)});const data=await r.json();assert.equal(r.status,status,JSON.stringify(data));return data}
const {companyId}=await call({op:'create',input:{name:'Runtime Training',currency:'EGP',mode:'training',startDate:'2026-01-01',seed:true}});
let s=await call({op:'snapshot',companyId});assert.equal(s.entries.length,10);assert.equal(s.company.revision,1);
let r=await call({op:'reports',companyId,from:'2026-01-01',to:'2026-01-31'});assert.equal(r.assets,12600000);assert.equal(r.currentProfit,400000);assert.ok(Object.values(r.checks).every(x=>x===0));
await call({op:'snapshot',companyId,user:'other-runtime-user'},404);
const ac=Object.fromEntries(s.accounts.map(a=>[a.code,a.id]));
const draft=await call({op:'action',companyId,input:{action:'save_entry',revision:s.company.revision,entry:{date:'2026-01-20',reference:'RUNTIME-CAP',memo:'قيد اختبار وقت التشغيل',lines:[{accountId:ac['1110'],debit:'0.30',credit:'0',flow:'financing'},{accountId:ac['3110'],debit:'0',credit:'0.30'}]}}});
s=await call({op:'snapshot',companyId});await call({op:'action',companyId,input:{action:'post_entry',revision:s.company.revision,entryId:draft.entryId}});
await mf.dispose();mf=new Miniflare(options);
s=await call({op:'snapshot',companyId});assert.equal(s.entries.length,11);assert.equal(s.entries.find(e=>e.id===draft.entryId).status,'posted');r=await call({op:'reports',companyId,from:'2026-01-01',to:'2026-01-31'});assert.equal(r.cashClosing,8500030);assert.equal(r.assets,12600030);assert.equal(r.currentProfit,400000);assert.ok(Object.values(r.checks).every(x=>x===0));console.log('PASS: real Worker+D1 runtime, schema/seed, exact posting, ownership rejection, reports and persistence across Worker restart.');
}finally{await mf.dispose()}

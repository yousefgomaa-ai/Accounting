import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {readFileSync,readdirSync,existsSync,mkdirSync,writeFileSync,renameSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=fileURLToPath(new URL('../',import.meta.url));
const config=path.join(root,'dist/server/wrangler.json');
if(!existsSync(config))throw new Error('Run npm run build before applying local migrations.');
const dir=path.join(root,'.wrangler');mkdirSync(dir,{recursive:true});
const state=path.join(dir,'mizan-local-migrations.json');
const applied=existsSync(state)?JSON.parse(readFileSync(state,'utf8')):{};
for(const file of readdirSync(path.join(root,'drizzle')).filter(f=>f.endsWith('.sql')).sort()){
 const full=path.join(root,'drizzle',file),hash=createHash('sha256').update(readFileSync(full)).digest('hex');
 if(applied[file]){if(applied[file]!==hash)throw new Error('Applied migration was modified: '+file);continue;}
 const result=spawnSync(process.execPath,['--import','./scripts/sites-env.mjs','./node_modules/wrangler/bin/wrangler.js','d1','execute','DB','--local','--config','dist/server/wrangler.json','--persist-to','.wrangler/state','--file','drizzle/'+file],{cwd:root,stdio:'inherit'});
 if(result.error)throw result.error;if(result.status!==0)process.exit(result.status||1);
 applied[file]=hash;writeFileSync(state+'.tmp',JSON.stringify(applied,null,2)+'\n');renameSync(state+'.tmp',state);
}
console.log('Local migrations are up to date.');

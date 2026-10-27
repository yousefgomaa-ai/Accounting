// Email + password accounts with server-side sessions stored in D1.
// Passwords: PBKDF2-SHA256 (100k iterations, the Workers maximum), random salt.
// Sessions: random 32-byte token in an HttpOnly cookie; only its SHA-256 is stored.
import {AccountingError} from './accounting.mjs';

export const SESSION_COOKIE='mizan_session';
export const SESSION_DAYS=30;
const ITERATIONS=100000;
const MAX_FAILURES=10;
const FAILURE_WINDOW_MS=15*60*1000;
const enc=new TextEncoder();

const b64=bytes=>btoa(String.fromCharCode(...bytes));
const unb64=text=>Uint8Array.from(atob(text),c=>c.charCodeAt(0));
const hex=bytes=>[...bytes].map(b=>b.toString(16).padStart(2,'0')).join('');
const random=n=>crypto.getRandomValues(new Uint8Array(n));
async function sha256(text){return hex(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(text))))}
async function pbkdf2(password,salt,iterations){const key=await crypto.subtle.importKey('raw',enc.encode(password),'PBKDF2',false,['deriveBits']);return new Uint8Array(await crypto.subtle.deriveBits({name:'PBKDF2',hash:'SHA-256',salt,iterations},key,256))}
function sameBytes(a,b){if(a.length!==b.length)return false;let diff=0;for(let i=0;i<a.length;i++)diff|=a[i]^b[i];return diff===0}

export async function hashPassword(password){const salt=random(16);return `pbkdf2$${ITERATIONS}$${b64(salt)}$${b64(await pbkdf2(password,salt,ITERATIONS))}`}
export async function verifyPassword(password,stored){const [scheme,iter,salt,hash]=String(stored).split('$');if(scheme!=='pbkdf2'||!salt||!hash)return false;return sameBytes(await pbkdf2(password,unb64(salt),Number(iter)),unb64(hash))}

export function normalizeEmail(value){const email=String(value||'').trim().toLowerCase();if(email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw new AccountingError('اكتب بريدًا إلكترونيًا صحيحًا.');return email}
function checkPassword(value){const password=String(value||'');if(password.length<8)throw new AccountingError('كلمة المرور يجب ألا تقل عن 8 أحرف.');if(password.length>200)throw new AccountingError('كلمة المرور أطول من المسموح.');return password}
function cleanName(value){const name=String(value||'').trim().slice(0,100);return name||null}
const toUser=row=>({userId:row.id,email:row.email,fullName:row.full_name||null,displayName:row.full_name||row.email});

async function startSession(db,userId){const token=b64(random(32)).replace(/[+/=]/g,c=>({'+':'-','/':'_','=':''})[c]);const now=Date.now();await db.prepare('INSERT INTO sessions (id,user_id,expires_at,created_at) VALUES (?,?,?,?)').bind(await sha256(token),userId,now+SESSION_DAYS*864e5,new Date(now).toISOString()).run();return token}

export async function signUp(db,input){const email=normalizeEmail(input?.email),password=checkPassword(input?.password),fullName=cleanName(input?.name);if(await db.prepare('SELECT 1 FROM users WHERE email=?').bind(email).first())throw new AccountingError('هذا البريد مسجّل بالفعل. سجّل الدخول بدلًا من ذلك.',409);const id=crypto.randomUUID();try{await db.prepare('INSERT INTO users (id,email,full_name,password_hash,created_at) VALUES (?,?,?,?,?)').bind(id,email,fullName,await hashPassword(password),new Date().toISOString()).run()}catch{throw new AccountingError('هذا البريد مسجّل بالفعل. سجّل الدخول بدلًا من ذلك.',409)}return {user:toUser({id,email,full_name:fullName}),token:await startSession(db,id)}}

export async function signIn(db,input){const email=normalizeEmail(input?.email),password=String(input?.password||'');const since=Date.now()-FAILURE_WINDOW_MS;const failures=await db.prepare('SELECT count(*) AS n FROM login_failures WHERE email=? AND at>?').bind(email,since).first();if((failures?.n||0)>=MAX_FAILURES)throw new AccountingError('محاولات دخول كثيرة. انتظر 15 دقيقة ثم أعد المحاولة.',429);const row=await db.prepare('SELECT id,email,full_name,password_hash FROM users WHERE email=?').bind(email).first();if(!row||!await verifyPassword(password,row.password_hash)){await db.prepare('INSERT INTO login_failures (email,at) VALUES (?,?)').bind(email,Date.now()).run();await db.prepare('DELETE FROM login_failures WHERE at<?').bind(since).run();throw new AccountingError('البريد أو كلمة المرور غير صحيحة.',401)}await db.prepare('DELETE FROM login_failures WHERE email=?').bind(email).run();return {user:toUser(row),token:await startSession(db,row.id)}}

export async function sessionUser(db,token){if(!token)return null;const row=await db.prepare('SELECT u.id,u.email,u.full_name,s.expires_at FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.id=?').bind(await sha256(token)).first();if(!row)return null;if(row.expires_at<=Date.now()){await signOut(db,token);return null}return toUser(row)}

export async function signOut(db,token){if(token)await db.prepare('DELETE FROM sessions WHERE id=?').bind(await sha256(token)).run()}

export function readCookie(header,name=SESSION_COOKIE){for(const part of String(header||'').split(';')){const i=part.indexOf('=');if(i>0&&part.slice(0,i).trim()===name)return part.slice(i+1).trim()}return null}
export function sessionCookie(token,secure){const attrs=[`${SESSION_COOKIE}=${token||''}`,'Path=/','HttpOnly','SameSite=Lax',token?`Max-Age=${SESSION_DAYS*86400}`:'Max-Age=0'];if(secure)attrs.push('Secure');return attrs.join('; ')}

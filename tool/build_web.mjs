// Builds the website (build/web) with offline support.
//
//   node tool/build_web.mjs            build only
//   node tool/build_web.mjs --deploy   build, then publish to Cloudflare Pages
//
// After `flutter build web`, this fills in web/sw.js's VERSION, ENGINE and
// PRECACHE so each build replaces the phone's saved copy of the app in one go.
import { execSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, readdirSync, statSync, rmSync, existsSync } from 'node:fs';
import { join, relative, sep, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'build', 'web');
const run = (cmd, cwd = root) => execSync(cmd, { cwd, stdio: 'inherit', shell: true });

run('flutter build web --release --no-web-resources-cdn --pwa-strategy=none');

// Flutter's own worker is not used (web/sw.js is).
for (const f of ['flutter_service_worker.js']) if (existsSync(join(out, f))) rmSync(join(out, f));

const files = [];
(function walk(dir) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walk(full);
    else files.push(relative(out, full).split(sep).join('/'));
  }
})(out);

// Saved on install: everything the app needs to open, except the renderer
// (canvaskit/, big; kept separately once the phone has loaded it), the
// licence text (only for the licences page) and server-only files.
const skip = (f) =>
  f === 'sw.js' || f.startsWith('_') || f.startsWith('canvaskit/') || f.endsWith('.map') ||
  f === 'assets/NOTICES' || f === '.last_build_id' || f === 'version.json';
const precache = files.filter((f) => !skip(f)).sort();
precache.unshift('./');

const hash = createHash('sha256');
for (const f of precache.slice(1)) hash.update(f).update(readFileSync(join(out, f)));
const version = hash.digest('hex').slice(0, 12);

const bootstrap = readFileSync(join(out, 'flutter_bootstrap.js'), 'utf8');
const engine = (bootstrap.match(/"engineRevision"\s*:\s*"([0-9a-f]+)"/) || [])[1] || version;

const swPath = join(out, 'sw.js');
let sw = readFileSync(swPath, 'utf8');
const set = (name, value) => {
  const re = new RegExp(`^const ${name} = .*;$`, 'm');
  if (!re.test(sw)) throw new Error(`sw.js: missing "const ${name} = ...;"`);
  sw = sw.replace(re, `const ${name} = ${value};`);
};
set('VERSION', JSON.stringify(version));
set('ENGINE', JSON.stringify(engine.slice(0, 12)));
set('PRECACHE', JSON.stringify(precache, null, 0));
writeFileSync(swPath, sw);

const kb = precache.slice(1).reduce((n, f) => n + statSync(join(out, f)).size, 0) / 1024;
console.log(`\nWebsite built: version ${version}, engine ${engine.slice(0, 12)}, ` +
  `${precache.length} files saved for offline (${Math.round(kb)} KB).`);

if (process.argv.includes('--deploy')) {
  // cloudflare/functions holds the sign-in pass-through; wrangler picks it up
  // from the folder it runs in.
  run('npx wrangler pages deploy ../build/web --project-name taka-koi --branch main --commit-dirty=true',
    join(root, 'cloudflare'));
}

// Taka Koi offline support.
//
// Keeps the app's own files on the phone so it opens without internet.
// Your data (tours, expenses, debts) is kept separately by Firestore's
// offline storage and syncs by itself once you're back online.
//
// tool/build_web.mjs fills in the three values below for every build, so a
// new version replaces the old files in one go. Don't edit them by hand.
const VERSION = 'dev';
const ENGINE = 'dev';
const PRECACHE = [];

const APP = 'taka-koi-app-' + VERSION;     // this version's files
const ENGINE_CACHE = 'taka-koi-ck-' + ENGINE; // Flutter's renderer (big; kept while the engine is the same)
const EXT = 'taka-koi-ext-1';             // Firebase scripts and fonts from Google (fixed, versioned URLs)

const scopeUrl = (path) => new URL(path, self.registration.scope).href;
const isEngineFile = (url) => url.pathname.includes('/canvaskit/');

// Files from Google that the app needs to start offline.
function isExternalStatic(url) {
  return (url.hostname === 'www.gstatic.com' && url.pathname.startsWith('/firebasejs/'))
    || url.hostname === 'fonts.gstatic.com'
    || url.hostname === 'fonts.googleapis.com';
}

// Same-site files the worker may keep. Sign-in pages (/__/) always go live.
function isOwnStatic(url) {
  return url.origin === self.location.origin
    && !url.pathname.startsWith('/__/')
    && !url.pathname.endsWith('/sw.js');
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    if (VERSION === 'dev') return; // unbuilt copy: cache nothing
    const app = await caches.open(APP);
    await app.addAll(PRECACHE.map((path) => new Request(scopeUrl(path), { cache: 'reload' })));

    // New Flutter engine: fetch the same renderer files this phone used before,
    // so the update also opens offline.
    if (!(await caches.has(ENGINE_CACHE))) {
      const used = new Set();
      for (const key of await caches.keys()) {
        if (!key.startsWith('taka-koi-ck-')) continue;
        for (const req of await (await caches.open(key)).keys()) used.add(new URL(req.url).pathname);
      }
      if (used.size) {
        const engine = await caches.open(ENGINE_CACHE);
        await engine.addAll([...used].map((path) => new Request(new URL(path, self.location.origin).href, { cache: 'reload' })));
      }
    }
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      const oldApp = key.startsWith('taka-koi-app-') && key !== APP;
      const oldEngine = key.startsWith('taka-koi-ck-') && key !== ENGINE_CACHE;
      if (oldApp || oldEngine) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

function cacheFor(url) {
  if (isExternalStatic(url)) return EXT;
  return isEngineFile(url) ? ENGINE_CACHE : APP;
}

async function cacheFirst(request) {
  const url = new URL(request.url);
  const name = cacheFor(url);
  const cache = await caches.open(name);
  const hit = await cache.match(request, { ignoreSearch: name !== EXT });
  if (hit) return hit;
  const response = await fetch(request);
  if (response.ok && (response.type === 'basic' || response.type === 'cors')) {
    cache.put(request, response.clone()).catch(() => {});
  }
  return response;
}

// Opening the app: use the newest page when online, the saved one otherwise.
async function openPage(request) {
  const cache = await caches.open(APP);
  try {
    const response = await Promise.race([
      fetch(request),
      new Promise((_, reject) => setTimeout(() => reject(new Error('slow')), 4000)),
    ]);
    if (response.ok) cache.put(scopeUrl('./'), response.clone()).catch(() => {});
    return response;
  } catch (_) {
    return (await cache.match(scopeUrl('./')))
      || (await cache.match(scopeUrl('index.html')))
      || Response.error();
  }
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || VERSION === 'dev') return;
  const url = new URL(request.url);

  if (request.mode === 'navigate' && isOwnStatic(url)) {
    event.respondWith(openPage(request));
  } else if (isOwnStatic(url) || isExternalStatic(url)) {
    event.respondWith(cacheFirst(request));
  }
  // Everything else (Firestore, sign-in, maps…) goes straight to the network.
});

// After the first screen, the page lists the files it loaded (renderer, fonts,
// Firebase scripts) so they're kept too, even ones fetched before this worker
// was in charge.
self.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.type !== 'keep' || !Array.isArray(data.urls) || VERSION === 'dev') return;
  event.waitUntil((async () => {
    for (const raw of data.urls.slice(0, 200)) {
      let url;
      try { url = new URL(raw); } catch (_) { continue; }
      if (!(isOwnStatic(url) || isExternalStatic(url))) continue;
      const cache = await caches.open(cacheFor(url));
      if (await cache.match(url.href, { ignoreSearch: !isExternalStatic(url) })) continue;
      try {
        const response = await fetch(url.href, { mode: url.origin === self.location.origin ? 'same-origin' : 'cors' });
        if (response.ok) await cache.put(url.href, response);
      } catch (_) { /* offline or blocked: try again next launch */ }
    }
  })());
});

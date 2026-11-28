// Service de l'application intervenant (app.html) : la rend installable et l'ouvre
// même avec un réseau faible. Il ne s'occupe que des fichiers de l'application ;
// les autres pages du site (projets, caisse) et les appels au serveur passent sans lui.
const CACHE = 'caisse-app-v2';
const FICHIERS = ['app.html', 'app.webmanifest', 'app-icone-192.png', 'app-icone-512.png', 'config.js'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FICHIERS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((cles) => Promise.all(cles.filter((k) => k.startsWith('caisse-app-') && k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

// Réseau d'abord (pour avoir la dernière version), le cache si le réseau ne répond pas.
self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== self.location.origin) return;
  const nom = url.pathname.split('/').pop() || '';
  if (!FICHIERS.includes(nom)) return;
  e.respondWith(
    fetch(e.request)
      .then((r) => { const copie = r.clone(); caches.open(CACHE).then((c) => c.put(e.request, copie)); return r; })
      .catch(() => caches.match(e.request, { ignoreSearch: true }))
  );
});

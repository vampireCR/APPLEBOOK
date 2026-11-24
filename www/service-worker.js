const CACHE_NAME = "theapplebook-v9";

const FILES_TO_CACHE = [
  "./",
  "./index.html",
  "./style.css",
  "./app.js",
  "./achievements.css",
  "./achievements.js",
  "./profile.css",
  "./profile.js",
  "./extras.css",
  "./extras.js",
  "./pwa.js",
  "./moderation.js",
  "./manifest.json",
  "./icons/icon-192.png",
  "./icons/icon-512.png"
];

// Установка новой версии
self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(async cache => {
      await Promise.all(
        FILES_TO_CACHE.map(async file => {
          try {
            await cache.add(file);
          } catch (error) {
            console.warn(
              "TheAppleBook: Не удалось добавить в кеш:",
              file,
              error
            );
          }
        })
      );
    })
  );

  self.skipWaiting();
});

// Удаление старых кешей
self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(key => key !== CACHE_NAME)
          .map(key => caches.delete(key))
      )
    )
  );

  self.clients.claim();
});

// Получение файлов
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;

  const url = new URL(event.request.url);

  if (url.origin !== self.location.origin) return;
  const scopePath = new URL(self.registration.scope).pathname;
  if (!url.pathname.startsWith(scopePath) || url.search) return;
  const scopeRelativePath = url.pathname.slice(scopePath.length);
  const cacheKey = scopeRelativePath ? `./${scopeRelativePath}` : "./";
  if (event.request.mode !== "navigate" && !FILES_TO_CACHE.includes(cacheKey)) return;

  const refresh = fetch(event.request).then(async response => {
    if (response?.ok) {
      const cache = await caches.open(CACHE_NAME);
      await cache.put(event.request, response.clone());
    }
    return response;
  });
  event.waitUntil(refresh.then(() => {}).catch(() => {}));

  event.respondWith((async () => {
    const cached = await caches.match(event.request);
    if (cached) return cached;

    try {
      return await refresh;
    } catch {
      if (event.request.mode === "navigate") {
        const fallback = await caches.match("./index.html");
        if (fallback) return fallback;
      }

      return new Response("Нет подключения к интернету", {
        status: 503,
        headers: { "Content-Type": "text/plain; charset=utf-8" }
      });
    }
  })());
});


// Web Push: notification payloads are delivered by the configured push sender.
self.addEventListener("push", event => {
  let payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch { payload = { body: event.data?.text() || "У тебя новое событие." }; }
  const title = payload.title || "TheAppleBook";
  const options = {
    body: payload.body || "Открой приложение, чтобы посмотреть.",
    icon: "./icons/icon-192.png",
    badge: "./icons/icon-192.png",
    data: { url: payload.url || "./" },
    tag: payload.tag || "theapplebook-notification",
    renotify: false
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", event => {
  event.notification.close();
  const targetUrl = new URL(event.notification.data?.url || "./", self.location.origin).href;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const client of windows) {
      if ("focus" in client) { await client.focus(); if ("navigate" in client) await client.navigate(targetUrl); return; }
    }
    if (self.clients.openWindow) await self.clients.openWindow(targetUrl);
  })());
});

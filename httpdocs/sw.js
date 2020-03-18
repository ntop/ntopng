const CACHE_VERSION = 'v0.0.2a'
const CONTENT_TO_CACHE = [
    '/',
    '/offline/index.html',
    '/css/ntopng.css',
    '/js/jquery.js',
    '/img/logo-ntop.svg',
    '/bootstrap-4.4.0-dist/css/bootstrap.min.css',
    '/bootstrap-4.4.0-dist/js/bootstrap.min.js',
];

self.addEventListener('install', (event) => {
    event.waitUntil((async () => {
        const cache = await caches.open(CACHE_VERSION);
        await cache.addAll(CONTENT_TO_CACHE);
    })());
});

self.addEventListener('activate', (event) => {
    event.waitUntil((async () => {
        // Enable navigation preload if it's supported.
        // See https://developers.google.com/web/updates/2017/02/navigation-preload
        if ('navigationPreload' in self.registration) {
            await self.registration.navigationPreload.enable();
        }
    })());

    // Tell the active service worker to take control of the page immediately.
    self.clients.claim();
});

self.addEventListener('fetch', (event) => {
    // console.log(`[ntopng-sw] Fetched resource ${event.request.url}`);
    if (event.request.mode === 'navigate') {
        event.respondWith((async () => {
            try {
                // First, try to use the navigation preload response if it's supported.
                const preloadResponse = await event.preloadResponse;
                if (preloadResponse) {
                    return preloadResponse;
                }

                const networkResponse = await fetch(event.request);
                return networkResponse;
            }
            catch (error) {
                // catch is only triggered if an exception is thrown, which is likely
                // due to a network error.
                // If fetch() returns a valid HTTP response with a response code in
                // the 4xx or 5xx range, the catch() will NOT be called.
                console.log('Fetch failed; returning offline page instead.', error);

                const cache = await caches.open(CACHE_VERSION);
                const cachedResponse = await cache.match('/offline/index.html');
                return cachedResponse;
            }
        })());
    }

});
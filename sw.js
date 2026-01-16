const CACHE_NAME = 'spark-v1';
const urlsToCache = [
    '/Spark/',
    '/Spark/index.html',
    '/Spark/onboarding.html',
    '/Spark/onboarding1.html',
    '/Spark/signup.html',
    '/Spark/login.html',
    '/Spark/plan.html',
    '/Spark/payment.html',
    '/Spark/match.html',
    '/Spark/chat.html',
    '/Spark/timer.html',
    '/Spark/reveal.html',
    '/Spark/revealed.html',
    '/Spark/exit.html',
    '/Spark/blueocean.jpeg',
    '/Spark/fonts/CabinetGrotesk-Medium.woff2',
    '/Spark/fonts/CabinetGrotesk-Medium.woff',
    '/Spark/fonts/CabinetGrotesk-Medium.ttf'
];

self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(urlsToCache))
    );
});

self.addEventListener('fetch', event => {
    event.respondWith(
        caches.match(event.request)
            .then(response => response || fetch(event.request))
    );
});

// Push notification handling
self.addEventListener('push', event => {
    if (!event.data) return;

    const data = event.data.json();
    const options = {
        body: data.body || 'You have a new message',
        icon: '/blueocean.jpeg',
        badge: '/blueocean.jpeg',
        vibrate: [100, 50, 100],
        data: {
            url: data.url || '/chat.html',
            matchId: data.matchId
        },
        actions: [
            { action: 'open', title: 'Open' },
            { action: 'dismiss', title: 'Dismiss' }
        ],
        tag: data.tag || 'spark-notification',
        renotify: true
    };

    event.waitUntil(
        self.registration.showNotification(data.title || 'Spark', options)
    );
});

// Handle notification click
self.addEventListener('notificationclick', event => {
    event.notification.close();

    if (event.action === 'dismiss') return;

    const urlToOpen = event.notification.data?.url || '/chat.html';

    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true })
            .then(windowClients => {
                // Check if there's already a window open
                for (const client of windowClients) {
                    if (client.url.includes('sparkadate') && 'focus' in client) {
                        client.navigate(urlToOpen);
                        return client.focus();
                    }
                }
                // If no window is open, open a new one
                if (clients.openWindow) {
                    return clients.openWindow(urlToOpen);
                }
            })
    );
});

// Handle notification close
self.addEventListener('notificationclose', event => {
    // Analytics or cleanup can be done here
});

const CACHE_NAME = 'spark-v1';
const urlsToCache = [
    '/',
    '/index.html',
    '/chat.html',
    '/blueocean.jpeg'
];

self.addEventListener('install', event => {
    console.log('Service Worker installing...');
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => {
                console.log('Opened cache');
                return cache.addAll(urlsToCache);
            })
            .catch(err => {
                console.error('Cache addAll failed:', err);
            })
    );
    self.skipWaiting(); // Force the waiting service worker to become the active service worker
});

self.addEventListener('activate', event => {
    console.log('Service Worker activating...');
    event.waitUntil(self.clients.claim()); // Claim clients immediately
});

self.addEventListener('fetch', event => {
    event.respondWith(
        caches.match(event.request)
            .then(response => response || fetch(event.request))
    );
});

// Push notification handling
self.addEventListener('push', event => {
    console.log('Push notification received:', event);
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

self.addEventListener('notificationclick', event => {
    console.log('Notification clicked:', event);
    event.notification.close();
    
    if (event.action === 'dismiss') return;
    
    const urlToOpen = event.notification.data?.url || '/chat.html';
    
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true })
            .then(windowClients => {
                for (const client of windowClients) {
                    if (client.url.includes('sparkadate') && 'focus' in client) {
                        client.navigate(urlToOpen);
                        return client.focus();
                    }
                }
                if (clients.openWindow) {
                    return clients.openWindow(urlToOpen);
                }
            })
    );
});

self.addEventListener('notificationclose', event => {
    console.log('Notification closed:', event);
});

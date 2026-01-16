import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken } from '../middleware/auth.js';
import webpush from 'web-push';

const router = express.Router();

// Configure web-push with VAPID keys
// These should be set in environment variables
const vapidPublicKey = process.env.VAPID_PUBLIC_KEY;
const vapidPrivateKey = process.env.VAPID_PRIVATE_KEY;

if (vapidPublicKey && vapidPrivateKey) {
    webpush.setVapidDetails(
        'mailto:support@sparkadate.online',
        vapidPublicKey,
        vapidPrivateKey
    );
}

// Get VAPID public key for client subscription
router.get('/vapid-public-key', (req, res) => {
    if (!vapidPublicKey) {
        return res.status(500).json({ error: 'Push notifications not configured' });
    }
    res.json({ publicKey: vapidPublicKey });
});

// Subscribe to push notifications
router.post('/subscribe', authenticateToken, async (req, res) => {
    try {
        const { subscription } = req.body;
        const userId = req.user.id;

        if (!subscription || !subscription.endpoint || !subscription.keys) {
            return res.status(400).json({ error: 'Invalid subscription data' });
        }

        // Store the subscription
        const { error } = await supabase
            .from('push_subscriptions')
            .upsert({
                user_id: userId,
                endpoint: subscription.endpoint,
                p256dh: subscription.keys.p256dh,
                auth: subscription.keys.auth
            }, {
                onConflict: 'user_id,endpoint'
            });

        if (error) throw error;

        res.json({ success: true });
    } catch (error) {
        console.error('Push subscribe error:', error);
        res.status(500).json({ error: 'Failed to save subscription' });
    }
});

// Unsubscribe from push notifications
router.post('/unsubscribe', authenticateToken, async (req, res) => {
    try {
        const { endpoint } = req.body;
        const userId = req.user.id;

        const { error } = await supabase
            .from('push_subscriptions')
            .delete()
            .eq('user_id', userId)
            .eq('endpoint', endpoint);

        if (error) throw error;

        res.json({ success: true });
    } catch (error) {
        console.error('Push unsubscribe error:', error);
        res.status(500).json({ error: 'Failed to remove subscription' });
    }
});

// Send push notification to a user (internal use)
export async function sendPushToUser(userId, notification) {
    if (!vapidPublicKey || !vapidPrivateKey) {
        console.log('Push notifications not configured');
        return;
    }

    try {
        const { data: subscriptions } = await supabase
            .from('push_subscriptions')
            .select('*')
            .eq('user_id', userId);

        if (!subscriptions || subscriptions.length === 0) {
            return;
        }

        const payload = JSON.stringify(notification);

        const results = await Promise.allSettled(
            subscriptions.map(sub => {
                const subscription = {
                    endpoint: sub.endpoint,
                    keys: {
                        p256dh: sub.p256dh,
                        auth: sub.auth
                    }
                };
                return webpush.sendNotification(subscription, payload);
            })
        );

        // Clean up failed subscriptions (likely unsubscribed)
        for (let i = 0; i < results.length; i++) {
            if (results[i].status === 'rejected') {
                const error = results[i].reason;
                if (error.statusCode === 410 || error.statusCode === 404) {
                    // Subscription expired or invalid, remove it
                    await supabase
                        .from('push_subscriptions')
                        .delete()
                        .eq('endpoint', subscriptions[i].endpoint);
                }
            }
        }
    } catch (error) {
        console.error('Send push notification error:', error);
    }
}

export default router;

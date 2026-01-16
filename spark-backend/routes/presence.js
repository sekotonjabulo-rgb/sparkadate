import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// Heartbeat - Update user's online status and last_seen
router.post('/heartbeat', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const now = new Date().toISOString();

        const { error } = await supabase
            .from('users')
            .update({
                is_online: true,
                last_seen: now
            })
            .eq('id', userId);

        if (error) throw error;

        res.json({ success: true, last_seen: now });
    } catch (error) {
        console.error('Heartbeat error:', error);
        res.status(500).json({ error: 'Failed to update presence' });
    }
});

// Set user offline (called on logout or page unload)
router.post('/offline', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;

        const { error } = await supabase
            .from('users')
            .update({
                is_online: false,
                last_seen: new Date().toISOString()
            })
            .eq('id', userId);

        if (error) throw error;

        res.json({ success: true });
    } catch (error) {
        console.error('Set offline error:', error);
        res.status(500).json({ error: 'Failed to update presence' });
    }
});

// Get user's online status by ID
router.get('/:userId', authenticateToken, async (req, res) => {
    try {
        const { userId } = req.params;

        const { data: user, error } = await supabase
            .from('users')
            .select('id, is_online, last_seen')
            .eq('id', userId)
            .single();

        if (error) throw error;

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Calculate if user is truly online (last_seen within 2 minutes)
        const lastSeen = new Date(user.last_seen);
        const now = new Date();
        const diffMinutes = (now - lastSeen) / (1000 * 60);

        // User is considered online if is_online is true AND last_seen is within 2 minutes
        const isOnline = user.is_online && diffMinutes < 2;

        res.json({
            userId: user.id,
            isOnline,
            lastSeen: user.last_seen
        });
    } catch (error) {
        console.error('Get presence error:', error);
        res.status(500).json({ error: 'Failed to get presence' });
    }
});

// Get online status for a match partner
router.get('/match/:matchId', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;
        const currentUserId = req.user.id;

        // Get the match to find the other user
        const { data: match, error: matchError } = await supabase
            .from('matches')
            .select('user_a_id, user_b_id')
            .eq('id', matchId)
            .single();

        if (matchError) throw matchError;

        if (!match) {
            return res.status(404).json({ error: 'Match not found' });
        }

        // Determine the partner's ID
        const partnerId = match.user_a_id === currentUserId
            ? match.user_b_id
            : match.user_a_id;

        // Get partner's presence info
        const { data: partner, error: userError } = await supabase
            .from('users')
            .select('id, is_online, last_seen')
            .eq('id', partnerId)
            .single();

        if (userError) throw userError;

        // Handle case where presence columns might not exist or be null
        if (!partner.last_seen) {
            return res.json({
                partnerId: partner.id,
                isOnline: false,
                lastSeen: null
            });
        }

        // Calculate if partner is truly online
        const lastSeen = new Date(partner.last_seen);
        const now = new Date();
        const diffMinutes = (now - lastSeen) / (1000 * 60);
        const isOnline = partner.is_online === true && diffMinutes < 2;

        res.json({
            partnerId: partner.id,
            isOnline,
            lastSeen: partner.last_seen
        });
    } catch (error) {
        console.error('Get match presence error:', error);
        res.status(500).json({ error: 'Failed to get match presence' });
    }
});

export default router;

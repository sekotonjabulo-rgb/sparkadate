import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// Set typing status
router.post('/:matchId', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;
        const { isTyping } = req.body;
        const userId = req.user.id;

        // Verify user is part of this match
        const { data: match } = await supabase
            .from('matches')
            .select('user_a_id, user_b_id')
            .eq('id', matchId)
            .single();

        if (!match || (match.user_a_id !== userId && match.user_b_id !== userId)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        // Upsert typing status
        const { error } = await supabase
            .from('typing_status')
            .upsert({
                match_id: matchId,
                user_id: userId,
                is_typing: isTyping,
                started_at: isTyping ? new Date().toISOString() : null
            }, {
                onConflict: 'match_id,user_id'
            });

        if (error) throw error;

        res.json({ success: true });
    } catch (error) {
        console.error('Set typing status error:', error);
        res.status(500).json({ error: 'Failed to update typing status' });
    }
});

// Get partner's typing status
router.get('/:matchId', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;
        const userId = req.user.id;

        // Verify user is part of this match and get partner ID
        const { data: match } = await supabase
            .from('matches')
            .select('user_a_id, user_b_id')
            .eq('id', matchId)
            .single();

        if (!match || (match.user_a_id !== userId && match.user_b_id !== userId)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        const partnerId = match.user_a_id === userId ? match.user_b_id : match.user_a_id;

        // Get partner's typing status
        const { data: typingStatus } = await supabase
            .from('typing_status')
            .select('is_typing, started_at')
            .eq('match_id', matchId)
            .eq('user_id', partnerId)
            .single();

        if (!typingStatus) {
            return res.json({ isTyping: false });
        }

        // Check if typing status is stale (older than 5 seconds)
        if (typingStatus.is_typing && typingStatus.started_at) {
            const startedAt = new Date(typingStatus.started_at);
            const now = new Date();
            const diffSeconds = (now - startedAt) / 1000;

            if (diffSeconds > 5) {
                // Typing status is stale, treat as not typing
                return res.json({ isTyping: false });
            }
        }

        res.json({ isTyping: typingStatus.is_typing });
    } catch (error) {
        console.error('Get typing status error:', error);
        res.status(500).json({ error: 'Failed to get typing status' });
    }
});

export default router;

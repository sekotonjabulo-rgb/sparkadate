import express from 'express';
import { supabase } from '../config/supabase.js';

const router = express.Router();

// Join waitlist
router.post('/join', async (req, res) => {
    try {
        const { full_name, email } = req.body;

        // Validate input
        if (!full_name || !email) {
            return res.status(400).json({ error: 'Full name and email are required' });
        }

        // Validate email format
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({ error: 'Invalid email format' });
        }

        // Check if email already exists
        const { data: existing } = await supabase
            .from('waitlist')
            .select('id')
            .eq('email', email)
            .single();

        if (existing) {
            return res.status(409).json({ error: 'Email already registered' });
        }

        // Generate unique referral code
        const referralCode = `SPARK${Date.now().toString(36).toUpperCase()}`;

        // Insert into waitlist
        const { data: waitlistEntry, error } = await supabase
            .from('waitlist')
            .insert({
                full_name,
                email,
                referral_code: referralCode
            })
            .select()
            .single();

        if (error) throw error;

        res.status(201).json({ 
            message: 'Successfully joined waitlist',
            waitlistEntry: {
                id: waitlistEntry.id,
                referral_code: waitlistEntry.referral_code
            }
        });
    } catch (error) {
        console.error('Waitlist join error:', error);
        res.status(500).json({ error: 'Failed to join waitlist' });
    }
});

// Get waitlist count
router.get('/count', async (req, res) => {
    try {
        const { count, error } = await supabase
            .from('waitlist')
            .select('*', { count: 'exact', head: true });

        if (error) throw error;

        res.json({ count: count || 0 });
    } catch (error) {
        console.error('Get waitlist count error:', error);
        res.status(500).json({ error: 'Failed to get waitlist count' });
    }
});

// Get waitlist position by email
router.post('/position', async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }

        // Get the user's entry
        const { data: userEntry, error: userError } = await supabase
            .from('waitlist')
            .select('created_at')
            .eq('email', email)
            .single();

        if (userError || !userEntry) {
            return res.status(404).json({ error: 'Email not found in waitlist' });
        }

        // Count entries created before this one
        const { count, error: countError } = await supabase
            .from('waitlist')
            .select('*', { count: 'exact', head: true })
            .lt('created_at', userEntry.created_at);

        if (countError) throw countError;

        res.json({ position: (count || 0) + 1 });
    } catch (error) {
        console.error('Get position error:', error);
        res.status(500).json({ error: 'Failed to get position' });
    }
});

export default router;

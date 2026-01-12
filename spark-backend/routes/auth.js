import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { createClient } from '@supabase/supabase-js';

const router = express.Router();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

// SIGNUP ROUTE
router.post('/signup', async (req, res) => {
    try {
        const { email, password, display_name, age, gender, seeking, location } = req.body;

        const { data: existingUser } = await supabase
            .from('users')
            .select('id')
            .eq('email', email)
            .single();

        if (existingUser) return res.status(400).json({ error: 'Email already registered' });

        const password_hash = await bcrypt.hash(password, 10);

        const { data: user, error } = await supabase
            .from('users')
            .insert({ email, password_hash, display_name, age, gender, seeking, location })
            .select().single();

        if (error) throw error;

        // Initialize user profiles
        await supabase.from('personality_profiles').insert({ user_id: user.id });
        await supabase.from('user_preferences').insert({ user_id: user.id });

        const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });

        res.status(201).json({
            user: { id: user.id, email: user.email, display_name: user.display_name },
            token
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to create account' });
    }
});

// LOGIN ROUTE (The missing piece that caused your 404)
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        const { data: user, error } = await supabase
            .from('users')
            .select('*')
            .eq('email', email)
            .single();

        if (error || !user) return res.status(401).json({ error: 'Invalid email or password' });

        const isMatch = await bcrypt.compare(password, user.password_hash);
        if (!isMatch) return res.status(401).json({ error: 'Invalid email or password' });

        const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });

        res.json({
            user: { id: user.id, email: user.email, display_name: user.display_name },
            token
        });
    } catch (error) {
        res.status(500).json({ error: 'Login failed' });
    }
});

export default router;

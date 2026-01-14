import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { createClient } from '@supabase/supabase-js';

async function geocodeLocation(locationText) {
    try {
        const response = await fetch(`https://geocode.maps.co/search?q=${encodeURIComponent(locationText)}&api_key=${process.env.GEOCODE_API_KEY}`);
        const data = await response.json();
        if (data && data.length > 0) {
            return { latitude: parseFloat(data[0].lat), longitude: parseFloat(data[0].lon) };
        }
        return { latitude: null, longitude: null };
    } catch (error) {
        console.error('Geocoding failed:', error);
        return { latitude: null, longitude: null };
    }
}

const router = express.Router();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

// SIGNUP ROUTE
router.post('/signup', async (req, res) => {
    try {
const { email, password, display_name, age, gender, seeking, location, latitude: providedLat, longitude: providedLon } = req.body;

let latitude = providedLat;
let longitude = providedLon;

if (!latitude || !longitude) {
    const coords = await geocodeLocation(location);
    latitude = coords.latitude;
    longitude = coords.longitude;
}
        const { data: existingUser } = await supabase
            .from('users')
            .select('id')
            .eq('email', email)
            .single();

        if (existingUser) return res.status(400).json({ error: 'Email already registered' });

        const password_hash = await bcrypt.hash(password, 10);

        const { data: user, error } = await supabase
            .from('users')
            .insert({ email, password_hash, display_name, age, gender, seeking, location, latitude, longitude })
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

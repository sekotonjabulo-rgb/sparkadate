import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { createClient } from '@supabase/supabase-js';

const router = express.Router();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

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

function calculateDistanceKm(lat1, lon1, lat2, lon2) {
    if (!lat1 || !lon1 || !lat2 || !lon2) return null;
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function processMatchQueue(newUser) {
    try {
        console.log('=== PROCESSING MATCH QUEUE ===');
        console.log('New user:', newUser.display_name, newUser.id);

        const { data: queuedUsers } = await supabase
            .from('match_queue')
            .select('user_id')
            .eq('is_active', true);

        if (!queuedUsers || queuedUsers.length === 0) {
            console.log('No users in queue');
            return null;
        }

        console.log('Users in queue:', queuedUsers.length);

        const genderMap = { man: 'men', woman: 'women' };

        for (const queued of queuedUsers) {
            const { data: queuedUser } = await supabase
                .from('users')
                .select('*, user_preferences(*)')
                .eq('id', queued.user_id)
                .single();

            if (!queuedUser) continue;

            console.log('Checking queued user:', queuedUser.display_name);

            const preferences = queuedUser.user_preferences?.[0] || queuedUser.user_preferences;

            // Check age preferences
            if (newUser.age < (preferences?.age_min || 18) || newUser.age > (preferences?.age_max || 99)) {
                console.log('Age mismatch, skipping');
                continue;
            }

            // Check gender/seeking compatibility
            const queuedSeeksNew = queuedUser.seeking === 'everyone' || queuedUser.seeking === genderMap[newUser.gender];
            const newSeeksQueued = newUser.seeking === 'everyone' || newUser.seeking === genderMap[queuedUser.gender];
            
            if (!queuedSeeksNew || !newSeeksQueued) {
                console.log('Gender/seeking mismatch, skipping');
                continue;
            }

            // Check distance
            const distance = calculateDistanceKm(newUser.latitude, newUser.longitude, queuedUser.latitude, queuedUser.longitude);
            const maxDistance = preferences?.max_distance_km || 80;
            
            if (distance !== null && distance > maxDistance) {
                console.log(`Distance ${Math.round(distance)}km exceeds max ${maxDistance}km, skipping`);
                continue;
            }

            // Found a match! Create it
            console.log('Compatible match found!');

            const revealHours = Math.floor(Math.random() * 108) + 12;
            const revealAvailableAt = new Date(Date.now() + revealHours * 60 * 60 * 1000);

            const { data: match, error } = await supabase
                .from('matches')
                .insert({
                    user_a_id: queuedUser.id,
                    user_b_id: newUser.id,
                    compatibility_score: 0.5,
                    recommended_reveal_hours: revealHours,
                    reveal_available_at: revealAvailableAt.toISOString()
                })
                .select()
                .single();

            if (error) {
                console.error('Queue match creation error:', error);
                continue;
            }

            // Remove from queue
            await supabase
                .from('match_queue')
                .update({ is_active: false })
                .eq('user_id', queuedUser.id);

            // Create conversation analytics
            await supabase
                .from('conversation_analytics')
                .insert({ match_id: match.id });

            console.log(`Queue match created: ${queuedUser.display_name} + ${newUser.display_name}`);
            console.log('=== END MATCH QUEUE ===');
            return match;
        }

        console.log('No compatible users found in queue');
        console.log('=== END MATCH QUEUE ===');
        return null;
    } catch (error) {
        console.error('Process match queue error:', error);
        return null;
    }
}

// SIGNUP ROUTE
router.post('/signup', async (req, res) => {
    try {
        const { email, password, display_name, age, gender, seeking, location, latitude: providedLat, longitude: providedLon } = req.body;

        const { data: existingUser } = await supabase
            .from('users')
            .select('id')
            .eq('email', email)
            .single();

        if (existingUser) return res.status(400).json({ error: 'Email already registered' });

        // Handle coordinates
        let latitude = providedLat;
        let longitude = providedLon;

        if (!latitude || !longitude) {
            const coords = await geocodeLocation(location);
            latitude = coords.latitude;
            longitude = coords.longitude;
        }

        const password_hash = await bcrypt.hash(password, 10);

        const { data: user, error } = await supabase
            .from('users')
            .insert({ email, password_hash, display_name, age, gender, seeking, location, latitude, longitude })
            .select()
            .single();

        if (error) throw error;

        // Initialize user profiles
        await supabase.from('personality_profiles').insert({ user_id: user.id });
        await supabase.from('user_preferences').insert({ user_id: user.id });

        // Process match queue for new user
        const queueMatch = await processMatchQueue(user);

        const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });

        res.status(201).json({
            user: { id: user.id, email: user.email, display_name: user.display_name },
            token,
            matched: queueMatch ? true : false
        });
    } catch (error) {
        console.error('Signup error:', error);
        res.status(500).json({ error: 'Failed to create account' });
    }
});

// LOGIN ROUTE
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
        console.error('Login error:', error);
        res.status(500).json({ error: 'Login failed' });
    }
});

export default router;

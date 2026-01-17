import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { createClient } from '@supabase/supabase-js';
import { generateToken, generateVerificationCode, sendVerificationEmail, sendPasswordResetEmail } from '../services/email.js';

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

        const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '30d' });

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

        const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '30d' });

        res.json({
            user: { id: user.id, email: user.email, display_name: user.display_name },
            token
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Login failed' });
    }
});

// REFRESH TOKEN ROUTE
router.post('/refresh', async (req, res) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'No token provided' });
        }

        const token = authHeader.split(' ')[1];

        try {
            // Verify the token (even if expired, we still decode it)
            const decoded = jwt.verify(token, process.env.JWT_SECRET, { ignoreExpiration: true });

            // Check if user still exists
            const { data: user, error } = await supabase
                .from('users')
                .select('id, email, display_name')
                .eq('id', decoded.id)
                .single();

            if (error || !user) {
                return res.status(401).json({ error: 'User not found' });
            }

            // Issue a new token
            const newToken = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '30d' });

            res.json({
                user: { id: user.id, email: user.email, display_name: user.display_name },
                token: newToken
            });
        } catch (jwtError) {
            return res.status(401).json({ error: 'Invalid token' });
        }
    } catch (error) {
        console.error('Token refresh error:', error);
        res.status(500).json({ error: 'Token refresh failed' });
    }
});

// REQUEST PASSWORD RESET
router.post('/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }

        // Check if user exists
        const { data: user } = await supabase
            .from('users')
            .select('id, email')
            .eq('email', email.toLowerCase().trim())
            .single();

        // Always return success to prevent email enumeration
        if (!user) {
            return res.json({ message: 'If an account exists, a reset link has been sent' });
        }

        // Generate reset token
        const resetToken = generateToken();
        const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

        // Store reset token in database
        await supabase
            .from('password_resets')
            .upsert({
                user_id: user.id,
                token: resetToken,
                expires_at: expiresAt.toISOString(),
                used: false
            }, { onConflict: 'user_id' });

        // Send reset email
        await sendPasswordResetEmail(user.email, resetToken);

        res.json({ message: 'If an account exists, a reset link has been sent' });
    } catch (error) {
        console.error('Forgot password error:', error);
        res.status(500).json({ error: 'Failed to process request' });
    }
});

// VERIFY RESET TOKEN
router.get('/verify-reset-token', async (req, res) => {
    try {
        const { token } = req.query;

        if (!token) {
            return res.status(400).json({ error: 'Token is required', valid: false });
        }

        const { data: resetRecord } = await supabase
            .from('password_resets')
            .select('*, users(email)')
            .eq('token', token)
            .eq('used', false)
            .single();

        if (!resetRecord) {
            return res.json({ valid: false, error: 'Invalid or expired token' });
        }

        if (new Date(resetRecord.expires_at) < new Date()) {
            return res.json({ valid: false, error: 'Token has expired' });
        }

        res.json({ valid: true, email: resetRecord.users?.email });
    } catch (error) {
        console.error('Verify reset token error:', error);
        res.status(500).json({ error: 'Failed to verify token', valid: false });
    }
});

// RESET PASSWORD
router.post('/reset-password', async (req, res) => {
    try {
        const { token, password } = req.body;

        if (!token || !password) {
            return res.status(400).json({ error: 'Token and password are required' });
        }

        if (password.length < 8) {
            return res.status(400).json({ error: 'Password must be at least 8 characters' });
        }

        // Find valid reset token
        const { data: resetRecord } = await supabase
            .from('password_resets')
            .select('*')
            .eq('token', token)
            .eq('used', false)
            .single();

        if (!resetRecord) {
            return res.status(400).json({ error: 'Invalid or expired reset token' });
        }

        if (new Date(resetRecord.expires_at) < new Date()) {
            return res.status(400).json({ error: 'Reset token has expired' });
        }

        // Hash new password
        const password_hash = await bcrypt.hash(password, 10);

        // Update user password
        const { error: updateError } = await supabase
            .from('users')
            .update({ password_hash })
            .eq('id', resetRecord.user_id);

        if (updateError) throw updateError;

        // Mark token as used
        await supabase
            .from('password_resets')
            .update({ used: true })
            .eq('id', resetRecord.id);

        res.json({ message: 'Password has been reset successfully' });
    } catch (error) {
        console.error('Reset password error:', error);
        res.status(500).json({ error: 'Failed to reset password' });
    }
});

// SEND EMAIL VERIFICATION
router.post('/send-verification', async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }

        const { data: user } = await supabase
            .from('users')
            .select('id, email, email_verified')
            .eq('email', email.toLowerCase().trim())
            .single();

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        if (user.email_verified) {
            return res.json({ message: 'Email already verified' });
        }

        // Generate verification code
        const code = generateVerificationCode();
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

        // Store verification code
        await supabase
            .from('email_verifications')
            .upsert({
                user_id: user.id,
                code,
                expires_at: expiresAt.toISOString(),
                used: false
            }, { onConflict: 'user_id' });

        // Send verification email
        await sendVerificationEmail(user.email, code);

        res.json({ message: 'Verification code sent' });
    } catch (error) {
        console.error('Send verification error:', error);
        res.status(500).json({ error: 'Failed to send verification code' });
    }
});

// VERIFY EMAIL CODE
router.post('/verify-email', async (req, res) => {
    try {
        const { email, code } = req.body;

        if (!email || !code) {
            return res.status(400).json({ error: 'Email and code are required' });
        }

        const { data: user } = await supabase
            .from('users')
            .select('id')
            .eq('email', email.toLowerCase().trim())
            .single();

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Check verification code
        const { data: verification } = await supabase
            .from('email_verifications')
            .select('*')
            .eq('user_id', user.id)
            .eq('code', code)
            .eq('used', false)
            .single();

        if (!verification) {
            return res.status(400).json({ error: 'Invalid verification code' });
        }

        if (new Date(verification.expires_at) < new Date()) {
            return res.status(400).json({ error: 'Verification code has expired' });
        }

        // Mark email as verified
        await supabase
            .from('users')
            .update({ email_verified: true })
            .eq('id', user.id);

        // Mark code as used
        await supabase
            .from('email_verifications')
            .update({ used: true })
            .eq('id', verification.id);

        res.json({ message: 'Email verified successfully', verified: true });
    } catch (error) {
        console.error('Verify email error:', error);
        res.status(500).json({ error: 'Failed to verify email' });
    }
});

export default router;

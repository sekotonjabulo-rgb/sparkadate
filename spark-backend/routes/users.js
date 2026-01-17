import express from 'express';
import multer from 'multer';
import { supabase } from '../config/supabase.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

// Get user profile
router.get('/me', authenticateToken, async (req, res) => {
    try {
        const { data: user, error } = await supabase
            .from('users')
            .select(`
                *,
                user_photos(*),
                user_preferences(*),
                personality_profiles(*)
            `)
            .eq('id', req.user.id)
            .single();

        if (error) throw error;

        delete user.password_hash;
        res.json({ user });
    } catch (error) {
        console.error('Get user error:', error);
        res.status(500).json({ error: 'Failed to get user' });
    }
});

// Update user profile
router.patch('/me', authenticateToken, async (req, res) => {
    try {
        const allowedFields = ['display_name', 'location'];
        const updates = {};

        for (const field of allowedFields) {
            if (req.body[field] !== undefined) {
                updates[field] = req.body[field];
            }
        }

        updates.updated_at = new Date().toISOString();

        const { data: user, error } = await supabase
            .from('users')
            .update(updates)
            .eq('id', req.user.id)
            .select()
            .single();

        if (error) throw error;

        delete user.password_hash;
        res.json({ user });
    } catch (error) {
        console.error('Update user error:', error);
        res.status(500).json({ error: 'Failed to update user' });
    }
});

// Update preferences
router.patch('/me/preferences', authenticateToken, async (req, res) => {
    try {
        const { age_min, age_max, max_distance_km, relationship_intent, dealbreakers } = req.body;

        // Build update object with only defined values
        const updates = { updated_at: new Date().toISOString() };
        if (age_min !== undefined) updates.age_min = age_min;
        if (age_max !== undefined) updates.age_max = age_max;
        if (max_distance_km !== undefined) updates.max_distance_km = max_distance_km;
        if (relationship_intent !== undefined) updates.relationship_intent = relationship_intent;
        if (dealbreakers !== undefined) updates.dealbreakers = dealbreakers;

        // Helper function to upsert preferences
        async function upsertPreferences(data) {
            const { data: existing } = await supabase
                .from('user_preferences')
                .select('id')
                .eq('user_id', req.user.id)
                .single();

            if (existing) {
                return await supabase
                    .from('user_preferences')
                    .update(data)
                    .eq('user_id', req.user.id)
                    .select()
                    .single();
            } else {
                return await supabase
                    .from('user_preferences')
                    .insert({ user_id: req.user.id, ...data })
                    .select()
                    .single();
            }
        }

        let result = await upsertPreferences(updates);

        // If failed and we included relationship_intent, try without it
        if (result.error && updates.relationship_intent !== undefined) {
            console.log('Retrying preferences update without relationship_intent');
            const { relationship_intent: _, ...updatesWithoutIntent } = updates;
            result = await upsertPreferences(updatesWithoutIntent);
        }

        if (result.error) throw result.error;

        res.json({ preferences: result.data });
    } catch (error) {
        console.error('Update preferences error:', error);
        res.status(500).json({ error: 'Failed to update preferences' });
    }
});

// Add photo (URL-based)
router.post('/me/photos', authenticateToken, async (req, res) => {
    try {
        const { photo_url, is_primary } = req.body;

        if (is_primary) {
            await supabase
                .from('user_photos')
                .update({ is_primary: false })
                .eq('user_id', req.user.id);
        }

        const { data: photo, error } = await supabase
            .from('user_photos')
            .insert({
                user_id: req.user.id,
                photo_url,
                is_primary: is_primary || false
            })
            .select()
            .single();

        if (error) throw error;

        res.status(201).json({ photo });
    } catch (error) {
        console.error('Add photo error:', error);
        res.status(500).json({ error: 'Failed to add photo' });
    }
});

// Upload photo (file-based with Supabase Storage)
router.post('/me/photos/upload', authenticateToken, upload.single('photo'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No photo provided' });
        }

        const userId = req.user.id;
        const isPrimary = req.body.is_primary === 'true' || req.body.is_primary === true;
        const uploadOrder = parseInt(req.body.upload_order) || 0;
        const fileExt = req.file.mimetype.split('/')[1] || 'jpg';
        const fileName = `${userId}/${Date.now()}_${uploadOrder}.${fileExt}`;

        const { data: uploadData, error: uploadError } = await supabase.storage
            .from('user-photos')
            .upload(fileName, req.file.buffer, {
                contentType: req.file.mimetype,
                upsert: false
            });

        if (uploadError) {
            console.error('Storage upload error:', uploadError);
            throw uploadError;
        }

        const { data: urlData } = supabase.storage
            .from('user-photos')
            .getPublicUrl(fileName);

        const photoUrl = urlData.publicUrl;

        if (isPrimary) {
            await supabase
                .from('user_photos')
                .update({ is_primary: false })
                .eq('user_id', userId);
        }

        const { data: photo, error: dbError } = await supabase
            .from('user_photos')
            .insert({
                user_id: userId,
                photo_url: photoUrl,
                is_primary: isPrimary,
                upload_order: uploadOrder
            })
            .select()
            .single();

        if (dbError) {
            console.error('Database insert error:', dbError);
            throw dbError;
        }

        res.status(201).json({ photo });
    } catch (error) {
        console.error('Photo upload error:', error);
        res.status(500).json({ error: 'Failed to upload photo' });
    }
});

// Delete photo
router.delete('/me/photos/:photoId', authenticateToken, async (req, res) => {
    try {
        const { photoId } = req.params;
        const userId = req.user.id;

        const { data: photo } = await supabase
            .from('user_photos')
            .select('*')
            .eq('id', photoId)
            .eq('user_id', userId)
            .single();

        if (!photo) {
            return res.status(404).json({ error: 'Photo not found' });
        }

        const fileName = photo.photo_url.split('/').pop();
        const filePath = `${userId}/${fileName}`;

        await supabase.storage
            .from('user-photos')
            .remove([filePath]);

        const { error } = await supabase
            .from('user_photos')
            .delete()
            .eq('id', photoId)
            .eq('user_id', userId);

        if (error) throw error;

        res.json({ deleted: true });
    } catch (error) {
        console.error('Delete photo error:', error);
        res.status(500).json({ error: 'Failed to delete photo' });
    }
});

// Delete user account
router.delete('/me', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;

        // Delete user photos from storage
        const { data: photos } = await supabase
            .from('user_photos')
            .select('photo_url')
            .eq('user_id', userId);

        if (photos && photos.length > 0) {
            const filePaths = photos.map(p => {
                const fileName = p.photo_url.split('/').pop();
                return `${userId}/${fileName}`;
            });
            await supabase.storage.from('user-photos').remove(filePaths);
        }

        // Delete related data (order matters due to foreign keys)
        await supabase.from('user_photos').delete().eq('user_id', userId);
        await supabase.from('user_preferences').delete().eq('user_id', userId);
        await supabase.from('personality_profiles').delete().eq('user_id', userId);
        await supabase.from('typing_status').delete().eq('user_id', userId);
        await supabase.from('push_subscriptions').delete().eq('user_id', userId);

        // Delete messages sent by user
        await supabase.from('messages').delete().eq('sender_id', userId);

        // Delete matches where user is involved
        await supabase.from('matches').delete().or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`);

        // Finally delete the user
        const { error } = await supabase
            .from('users')
            .delete()
            .eq('id', userId);

        if (error) throw error;

        res.json({ deleted: true });
    } catch (error) {
        console.error('Delete account error:', error);
        res.status(500).json({ error: 'Failed to delete account' });
    }
});

export default router;

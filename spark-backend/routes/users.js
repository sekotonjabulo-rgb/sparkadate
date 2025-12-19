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

        const { data: preferences, error } = await supabase
            .from('user_preferences')
            .update({
                age_min,
                age_max,
                max_distance_km,
                relationship_intent,
                dealbreakers,
                updated_at: new Date().toISOString()
            })
            .eq('user_id', req.user.id)
            .select()
            .single();

        if (error) throw error;

        res.json({ preferences });
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

export default router;

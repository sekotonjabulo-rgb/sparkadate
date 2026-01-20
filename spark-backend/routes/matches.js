import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken } from '../middleware/auth.js';
import { calculateCompatibility } from '../services/gemini.js';

const router = express.Router();

function calculateDistanceKm(lat1, lon1, lat2, lon2) {
    if (!lat1 || !lon1 || !lat2 || !lon2) return null;
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function hasProfileData(profile) {
    if (!profile) return false;
    return profile.total_messages_analyzed > 0 || 
           profile.humor_score !== null || 
           profile.formality_score !== null;
}

router.get('/current', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;

        // First check for active/revealed matches
        const { data: match } = await supabase
            .from('matches')
            .select(`
                *,
                user_a:users!matches_user_a_id_fkey(id, display_name, age),
                user_b:users!matches_user_b_id_fkey(id, display_name, age)
            `)
            .or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`)
            .in('status', ['active', 'revealed'])
            .order('matched_at', { ascending: false })
            .limit(1)
            .single();

        if (match) {
            const partner = match.user_a_id === userId ? match.user_b : match.user_a;
            return res.json({
                match: {
                    id: match.id,
                    partner: {
                        id: partner.id,
                        display_name: partner.display_name,
                        age: partner.age
                    },
                    matched_at: match.matched_at,
                    reveal_available_at: match.reveal_available_at,
                    reveal_requested_by: match.reveal_requested_by,
                    reveal_requested_at: match.reveal_requested_at,
                    revealed_seen_by: match.revealed_seen_by || [],
                    status: match.status,
                    partner_left: false
                }
            });
        }

        // Check if partner left a recent match (within last 24 hours)
        const { data: exitedMatch } = await supabase
            .from('matches')
            .select(`
                *,
                user_a:users!matches_user_a_id_fkey(id, display_name, age),
                user_b:users!matches_user_b_id_fkey(id, display_name, age)
            `)
            .or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`)
            .in('status', ['exited_a', 'exited_b'])
            .neq('exited_by', userId)
            .order('exited_at', { ascending: false })
            .limit(1)
            .single();

        if (exitedMatch) {
            // Check if this exit was recent and user hasn't acknowledged it
            const exitedAt = new Date(exitedMatch.exited_at);
            const now = new Date();
            const hoursSinceExit = (now - exitedAt) / (1000 * 60 * 60);

            // Only show partner_left if it was within last 24 hours
            if (hoursSinceExit < 24) {
                const partner = exitedMatch.user_a_id === userId ? exitedMatch.user_b : exitedMatch.user_a;
                return res.json({
                    match: {
                        id: exitedMatch.id,
                        partner: {
                            id: partner.id,
                            display_name: partner.display_name,
                            age: partner.age
                        },
                        matched_at: exitedMatch.matched_at,
                        status: exitedMatch.status,
                        partner_left: true,
                        exited_at: exitedMatch.exited_at
                    }
                });
            }
        }

        return res.json({ match: null });
    } catch (error) {
        console.error('Get current match error:', error);
        res.status(500).json({ error: 'Failed to get match' });
    }
});

router.post('/find', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;

        const { data: existingMatch } = await supabase
            .from('matches')
            .select('id')
            .or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`)
            .in('status', ['active', 'revealed'])
            .single();

        if (existingMatch) {
            return res.status(400).json({ error: 'Already have an active match' });
        }

        const { data: user } = await supabase
            .from('users')
            .select('*, user_preferences(*), personality_profiles(*)')
            .eq('id', userId)
            .single();

        const preferences = user.user_preferences?.[0] || user.user_preferences;
        const userProfile = user.personality_profiles?.[0] || user.personality_profiles;
        const maxDistanceKm = preferences?.max_distance_km || 80;

        const { data: candidates } = await supabase
            .from('users')
            .select('*, personality_profiles(*), interest_mappings(*), user_preferences(*)')
            .neq('id', userId)
            .eq('is_active', true)
            .eq('is_banned', false)
            .gte('age', preferences?.age_min || 18)
            .lte('age', preferences?.age_max || 99);

        if (!candidates || candidates.length === 0) {
            await supabase
                .from('match_queue')
                .upsert({ user_id: userId, is_active: true });
            return res.json({ match: null, queued: true });
        }

        // Get users who are already in active matches
        const { data: activeMatchUserIds } = await supabase
            .from('matches')
            .select('user_a_id, user_b_id')
            .in('status', ['active', 'revealed']);

        const matchedUserIds = new Set();
        activeMatchUserIds?.forEach(m => {
            matchedUserIds.add(m.user_a_id);
            matchedUserIds.add(m.user_b_id);
        });

        // Get previous matches to avoid re-matching
        const { data: previousMatches } = await supabase
            .from('matches')
            .select('user_a_id, user_b_id')
            .or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`);

        const previousMatchUserIds = new Set();
        previousMatches?.forEach(m => {
            if (m.user_a_id === userId) {
                previousMatchUserIds.add(m.user_b_id);
            } else {
                previousMatchUserIds.add(m.user_a_id);
            }
        });

        // Filter to available candidates
        const availableCandidates = candidates.filter(c =>
            !matchedUserIds.has(c.id) && !previousMatchUserIds.has(c.id)
        );

        // Filter by gender preferences, distance, and relationship intent
        const userIntent = preferences?.relationship_intent || 'unsure';
        const validCandidates = availableCandidates.filter(c => {
            const genderMap = { man: 'men', woman: 'women' };
            const userSeeks = user.seeking === 'everyone' || user.seeking === genderMap[c.gender];
            const candidateSeeks = c.seeking === 'everyone' || c.seeking === genderMap[user.gender];
            if (!userSeeks || !candidateSeeks) return false;

            const distance = calculateDistanceKm(user.latitude, user.longitude, c.latitude, c.longitude);
            if (distance !== null && distance > maxDistanceKm) return false;

            // Check relationship intent compatibility
            const candidatePrefs = c.user_preferences?.[0] || c.user_preferences;
            const candidateIntent = candidatePrefs?.relationship_intent || 'unsure';

            // If either user is "unsure", match with anyone
            // Otherwise, intents should match or be compatible
            if (userIntent !== 'unsure' && candidateIntent !== 'unsure') {
                // Strict matching for serious/casual - they shouldn't mix
                if ((userIntent === 'serious' && candidateIntent === 'casual') ||
                    (userIntent === 'casual' && candidateIntent === 'serious')) {
                    return false;
                }
            }

            return true;
        });

        if (validCandidates.length === 0) {
            await supabase
                .from('match_queue')
                .upsert({ user_id: userId, is_active: true });
            return res.json({ match: null, queued: true });
        }

        let bestMatch;

        // If only 1-2 candidates, just pick the first one (skip AI scoring)
        if (validCandidates.length <= 2) {
            const candidate = validCandidates[0];
            const distance = calculateDistanceKm(user.latitude, user.longitude, candidate.latitude, candidate.longitude);
            bestMatch = {
                candidate,
                candidateProfile: candidate.personality_profiles?.[0] || candidate.personality_profiles,
                compatibility: null,
                score: 0.5,
                distance
            };
        } else {
            // Score top 5 candidates in parallel (not 10)
            const candidatesToScore = validCandidates.slice(0, 5);

            const scoringPromises = candidatesToScore.map(async (candidate) => {
                const candidateProfile = candidate.personality_profiles?.[0] || candidate.personality_profiles;
                let compatibility = null;
                let score = 0.5;

                // Only call AI if both users have profile data
                if (hasProfileData(userProfile) && hasProfileData(candidateProfile)) {
                    try {
                        compatibility = await calculateCompatibility(
                            userProfile,
                            candidateProfile,
                            [],
                            candidate.interest_mappings || []
                        );
                        score = compatibility?.compatibility_score || 0.5;
                    } catch (error) {
                        // Silently use default score on error
                    }
                } else if (hasProfileData(userProfile) || hasProfileData(candidateProfile)) {
                    score = 0.55;
                }

                // Boost for closer users
                const distance = calculateDistanceKm(user.latitude, user.longitude, candidate.latitude, candidate.longitude);
                if (distance !== null && distance < 20) {
                    score += 0.05;
                }

                return { candidate, candidateProfile, compatibility, score, distance };
            });

            const scoredCandidates = await Promise.all(scoringPromises);
            scoredCandidates.sort((a, b) => b.score - a.score);
            bestMatch = scoredCandidates[0];
        }

        const revealHours = bestMatch.compatibility?.recommended_reveal_hours || Math.floor(Math.random() * 108) + 12;
        const revealAvailableAt = new Date(Date.now() + revealHours * 60 * 60 * 1000);

        const { data: match, error } = await supabase
            .from('matches')
            .insert({
                user_a_id: userId,
                user_b_id: bestMatch.candidate.id,
                compatibility_score: bestMatch.score,
                recommended_reveal_hours: revealHours,
                reveal_available_at: revealAvailableAt.toISOString()
            })
            .select()
            .single();

        if (error) throw error;

        await supabase
            .from('conversation_analytics')
            .insert({ match_id: match.id });

        // Update queue entries for both users
        await supabase
            .from('match_queue')
            .update({
                matched_at: new Date().toISOString(),
                matched_with: bestMatch.candidate.id,
                is_active: false
            })
            .eq('user_id', userId)
            .eq('is_active', true);

        await supabase
            .from('match_queue')
            .update({
                matched_at: new Date().toISOString(),
                matched_with: userId,
                is_active: false
            })
            .eq('user_id', bestMatch.candidate.id)
            .eq('is_active', true);

        res.json({
            match: {
                id: match.id,
                partner: {
                    id: bestMatch.candidate.id,
                    display_name: bestMatch.candidate.display_name,
                    age: bestMatch.candidate.age
                },
                compatibility_score: bestMatch.score,
                reveal_available_at: match.reveal_available_at
            }
        });
    } catch (error) {
        console.error('Find match error:', error);
        res.status(500).json({ error: 'Failed to find match' });
    }
});

router.post('/:matchId/reveal', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;
        const userId = req.user.id;

        const { data: match } = await supabase
            .from('matches')
            .select('*')
            .eq('id', matchId)
            .single();

        if (!match || (match.user_a_id !== userId && match.user_b_id !== userId)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        if (match.reveal_requested_by && match.reveal_requested_by !== userId) {
            await supabase
                .from('matches')
                .update({
                    status: 'revealed',
                    revealed_at: new Date().toISOString()
                })
                .eq('id', matchId);

            return res.json({ revealed: true });
        }

        await supabase
            .from('matches')
            .update({
                reveal_requested_by: userId,
                reveal_requested_at: new Date().toISOString()
            })
            .eq('id', matchId);

        res.json({ requested: true, waiting_for_partner: true });
    } catch (error) {
        console.error('Reveal request error:', error);
        res.status(500).json({ error: 'Failed to request reveal' });
    }
});

router.post('/:matchId/seen', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;
        const userId = req.user.id;

        const { data: match } = await supabase
            .from('matches')
            .select('*')
            .eq('id', matchId)
            .single();

        if (!match || (match.user_a_id !== userId && match.user_b_id !== userId)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        if (match.status !== 'revealed') {
            return res.status(400).json({ error: 'Match not yet revealed' });
        }

        const { error } = await supabase.rpc('add_to_revealed_seen_by', {
            match_id: matchId,
            user_id: userId
        });

        if (error) throw error;

        res.json({ success: true });
    } catch (error) {
        console.error('Mark reveal seen error:', error);
        res.status(500).json({ error: 'Failed to mark reveal as seen' });
    }
});

router.post('/:matchId/exit', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;
        const userId = req.user.id;

        const { data: match } = await supabase
            .from('matches')
            .select('*')
            .eq('id', matchId)
            .single();

        if (!match || (match.user_a_id !== userId && match.user_b_id !== userId)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        const exitStage = match.revealed_at ? 'post_reveal' : 'pre_reveal';

        await supabase
            .from('matches')
            .update({
                status: match.user_a_id === userId ? 'exited_a' : 'exited_b',
                exited_by: userId,
                exited_at: new Date().toISOString(),
                exit_stage: exitStage
            })
            .eq('id', matchId);

        const { data: user } = await supabase
            .from('users')
            .select('subscription_tier, exits_remaining')
            .eq('id', userId)
            .single();

        if (user.subscription_tier === 'free' && user.exits_remaining > 0) {
            await supabase
                .from('users')
                .update({ exits_remaining: user.exits_remaining - 1 })
                .eq('id', userId);
        }

        // Increment total_conversations_analyzed for both users
        const partnerId = match.user_a_id === userId ? match.user_b_id : match.user_a_id;
        
        await supabase.rpc('increment_conversations_analyzed', { user_id_param: userId });
        await supabase.rpc('increment_conversations_analyzed', { user_id_param: partnerId });

        res.json({ exited: true });
    } catch (error) {
        console.error('Exit match error:', error);
        res.status(500).json({ error: 'Failed to exit match' });
    }
});

router.get('/:matchId/photos', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;
        const userId = req.user.id;

        const { data: match } = await supabase
            .from('matches')
            .select('*')
            .eq('id', matchId)
            .single();

        if (!match || (match.user_a_id !== userId && match.user_b_id !== userId)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        const partnerId = match.user_a_id === userId ? match.user_b_id : match.user_a_id;

        const { data: photos, error } = await supabase
            .from('user_photos')
            .select('*')
            .eq('user_id', partnerId)
            .order('upload_order', { ascending: true });

        if (error) throw error;

        res.json({ photos: photos || [] });
    } catch (error) {
        console.error('Get match photos error:', error);
        res.status(500).json({ error: 'Failed to get photos' });
    }
});

export default router;

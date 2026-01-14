import express from 'express';
import { supabase } from '../config/supabase.js';
import { authenticateToken } from '../middleware/auth.js';
import { analyzeMessage, analyzeConversation, updatePersonalityProfile } from '../services/gemini.js';

const router = express.Router();

// Calculate average response time for a user across all their conversations
async function calculateAvgResponseTime(userId) {
    try {
        const { data: userMatches } = await supabase
            .from('matches')
            .select('id, user_a_id, user_b_id')
            .or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`);

        if (!userMatches || userMatches.length === 0) return null;

        const matchIds = userMatches.map(m => m.id);
        
        const { data: allMessages } = await supabase
            .from('messages')
            .select('*')
            .in('match_id', matchIds)
            .order('sent_at', { ascending: true });

        if (!allMessages || allMessages.length < 2) return null;

        const responseTimes = [];

        // Group messages by match
        const messagesByMatch = {};
        allMessages.forEach(msg => {
            if (!messagesByMatch[msg.match_id]) {
                messagesByMatch[msg.match_id] = [];
            }
            messagesByMatch[msg.match_id].push(msg);
        });

        // Calculate response times for each match
        for (const matchId in messagesByMatch) {
            const messages = messagesByMatch[matchId];
            
            for (let i = 1; i < messages.length; i++) {
                const currentMsg = messages[i];
                const previousMsg = messages[i - 1];

                // Only count if this user is responding to the other person
                if (currentMsg.sender_id === userId && previousMsg.sender_id !== userId) {
                    const responseTime = (new Date(currentMsg.sent_at) - new Date(previousMsg.sent_at)) / 1000;
                    
                    // Only count reasonable response times (under 24 hours)
                    if (responseTime > 0 && responseTime < 86400) {
                        responseTimes.push(responseTime);
                    }
                }
            }
        }

        if (responseTimes.length === 0) return null;

        const avgResponseTime = responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length;
        return Math.round(avgResponseTime);
    } catch (error) {
        console.error('Calculate response time error:', error);
        return null;
    }
}

// Calculate vulnerability progression (how quickly user opens up)
async function calculateVulnerabilityProgression(userId) {
    try {
        const { data: userMessages } = await supabase
            .from('messages')
            .select('depth_level, sent_at')
            .eq('sender_id', userId)
            .not('depth_level', 'is', null)
            .order('sent_at', { ascending: true });

        if (!userMessages || userMessages.length < 3) return null;

        // Compare average depth of first third vs last third of messages
        const thirdLength = Math.floor(userMessages.length / 3);
        const earlyMessages = userMessages.slice(0, thirdLength);
        const lateMessages = userMessages.slice(-thirdLength);

        const earlyAvgDepth = earlyMessages.reduce((sum, m) => sum + m.depth_level, 0) / earlyMessages.length;
        const lateAvgDepth = lateMessages.reduce((sum, m) => sum + m.depth_level, 0) / lateMessages.length;

        // Calculate progression as normalized difference (0 to 1)
        // Higher value means user opens up more over time
        const progression = Math.max(0, Math.min(1, (lateAvgDepth - earlyAvgDepth) / 4 + 0.5));
        
        return Math.round(progression * 100) / 100;
    } catch (error) {
        console.error('Calculate vulnerability progression error:', error);
        return null;
    }
}

// Calculate profile confidence based on data quantity
function calculateProfileConfidence(totalMessagesAnalyzed, totalConversationsAnalyzed) {
    // Base confidence on message count (max contribution: 0.7)
    const messageConfidence = Math.min(0.7, totalMessagesAnalyzed / 100);
    
    // Bonus for multiple conversations (max contribution: 0.3)
    const conversationConfidence = Math.min(0.3, totalConversationsAnalyzed / 10);
    
    return Math.round((messageConfidence + conversationConfidence) * 100) / 100;
}

// Send message
router.post('/:matchId', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;
        const { content } = req.body;
        const senderId = req.user.id;

        // Verify user is part of this match
        const { data: match } = await supabase
            .from('matches')
            .select('*')
            .eq('id', matchId)
            .single();

        if (!match || (match.user_a_id !== senderId && match.user_b_id !== senderId)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        // Get recent messages for context
        const { data: recentMessages } = await supabase
            .from('messages')
            .select('content, sender_id')
            .eq('match_id', matchId)
            .order('sent_at', { ascending: false })
            .limit(5);

        // Analyze message with Groq
        const analysis = await analyzeMessage(content, recentMessages || []);

        // Save message
        const { data: message, error } = await supabase
            .from('messages')
            .insert({
                match_id: matchId,
                sender_id: senderId,
                content,
                sentiment_score: analysis?.sentiment_score,
                extracted_topics: analysis?.extracted_topics,
                emotional_tone: analysis?.emotional_tone,
                depth_level: analysis?.depth_level
            })
            .select()
            .single();

        if (error) throw error;

        // Update match message count
        const newMessageCount = (match.total_messages || 0) + 1;
        await supabase
            .from('matches')
            .update({ total_messages: newMessageCount })
            .eq('id', matchId);

        // Update personality profile every 5 messages
        if (newMessageCount % 5 === 0) {
            const { data: allUserMessages } = await supabase
                .from('messages')
                .select('*')
                .eq('sender_id', senderId);

            const profileUpdate = await updatePersonalityProfile(senderId, allUserMessages);

            if (profileUpdate) {
                // Calculate additional metrics
                const avgResponseTime = await calculateAvgResponseTime(senderId);
                const vulnerabilityProgression = await calculateVulnerabilityProgression(senderId);
                
                // Get current conversation count
                const { data: currentProfile } = await supabase
                    .from('personality_profiles')
                    .select('total_conversations_analyzed')
                    .eq('user_id', senderId)
                    .single();

                const totalConversations = currentProfile?.total_conversations_analyzed || 0;
                const profileConfidence = calculateProfileConfidence(allUserMessages.length, totalConversations);

                await supabase
                    .from('personality_profiles')
                    .update({
                        avg_message_length: profileUpdate.avg_message_length,
                        avg_response_time_seconds: avgResponseTime,
                        formality_score: profileUpdate.formality_score,
                        humor_score: profileUpdate.humor_score,
                        emoji_frequency: profileUpdate.emoji_frequency,
                        question_asking_rate: profileUpdate.question_asking_rate,
                        depth_preference: profileUpdate.depth_preference,
                        emotional_openness_speed: profileUpdate.emotional_openness_speed,
                        vulnerability_progression: vulnerabilityProgression,
                        positivity_score: profileUpdate.positivity_score,
                        emotional_expressiveness: profileUpdate.emotional_expressiveness,
                        empathy_signals: profileUpdate.empathy_signals,
                        conflict_handling_style: profileUpdate.conflict_handling_style,
                        profile_confidence: profileConfidence,
                        total_messages_analyzed: allUserMessages.length,
                        updated_at: new Date().toISOString()
                    })
                    .eq('user_id', senderId);
            }
        }

        res.status(201).json({ message, analysis });
    } catch (error) {
        console.error('Send message error:', error);
        res.status(500).json({ error: 'Failed to send message' });
    }
});

// Get messages for a match
router.get('/:matchId', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;
        const userId = req.user.id;

        // Verify user is part of this match
        const { data: match } = await supabase
            .from('matches')
            .select('*')
            .eq('id', matchId)
            .single();

        if (!match || (match.user_a_id !== userId && match.user_b_id !== userId)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        const { data: messages, error } = await supabase
            .from('messages')
            .select('*')
            .eq('match_id', matchId)
            .order('sent_at', { ascending: true });

        if (error) throw error;

        res.json({ messages });
    } catch (error) {
        console.error('Get messages error:', error);
        res.status(500).json({ error: 'Failed to get messages' });
    }
});

// Analyze full conversation (called periodically or on demand)
router.post('/:matchId/analyze', authenticateToken, async (req, res) => {
    try {
        const { matchId } = req.params;

        const { data: messages } = await supabase
            .from('messages')
            .select('*')
            .eq('match_id', matchId)
            .order('sent_at', { ascending: true });

        if (!messages || messages.length < 5) {
            return res.status(400).json({ error: 'Not enough messages to analyze' });
        }

        const analysis = await analyzeConversation(messages);

        if (analysis) {
            // Update conversation analytics
            await supabase
                .from('conversation_analytics')
                .upsert({
                    match_id: matchId,
                    total_messages: messages.length,
                    ...analysis,
                    updated_at: new Date().toISOString()
                });
        }

        res.json({ analysis });
    } catch (error) {
        console.error('Analyze conversation error:', error);
        res.status(500).json({ error: 'Failed to analyze conversation' });
    }
});

export default router;

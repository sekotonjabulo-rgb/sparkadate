import { supabase } from '../config/supabase.js';
import { sendPushToUser } from '../routes/push.js';

const EXPIRY_INTERVAL_MS = 15 * 60 * 1000; // Check every 15 minutes
const NO_MESSAGE_EXPIRY_HOURS = 24;
const NO_REPLY_EXPIRY_HOURS = 48;

/**
 * Expire matches where neither user sent a single message within 24 hours.
 */
async function expireZeroMessageMatches() {
    const cutoff = new Date(Date.now() - NO_MESSAGE_EXPIRY_HOURS * 60 * 60 * 1000).toISOString();

    const { data: staleMatches, error } = await supabase
        .from('matches')
        .select('id, user_a_id, user_b_id, matched_at')
        .in('status', ['active', 'revealed'])
        .lt('matched_at', cutoff)
        .or('total_messages.is.null,total_messages.eq.0');

    if (error) {
        console.error('[Match Expiry] Error querying zero-message matches:', error);
        return 0;
    }

    if (!staleMatches || staleMatches.length === 0) return 0;

    const now = new Date().toISOString();

    for (const match of staleMatches) {
        const { error: updateError } = await supabase
            .from('matches')
            .update({
                status: 'expired',
                expired_at: now,
                expire_reason: 'no_messages'
            })
            .eq('id', match.id);

        if (updateError) {
            console.error(`[Match Expiry] Failed to expire match ${match.id}:`, updateError);
        } else {
            console.log(`[Match Expiry] Expired match ${match.id} (no messages after ${NO_MESSAGE_EXPIRY_HOURS}h)`);
        }
    }

    return staleMatches.length;
}

/**
 * Expire matches where only one side sent messages and got no reply within 48 hours.
 */
async function expireOneSidedMatches() {
    const cutoff = new Date(Date.now() - NO_REPLY_EXPIRY_HOURS * 60 * 60 * 1000).toISOString();

    // Get active matches older than 48h that have at least 1 message
    const { data: candidates, error } = await supabase
        .from('matches')
        .select('id, user_a_id, user_b_id, matched_at, total_messages')
        .in('status', ['active', 'revealed'])
        .lt('matched_at', cutoff)
        .gt('total_messages', 0);

    if (error) {
        console.error('[Match Expiry] Error querying one-sided matches:', error);
        return 0;
    }

    if (!candidates || candidates.length === 0) return 0;

    let expiredCount = 0;
    const now = new Date().toISOString();

    for (const match of candidates) {
        // Check if messages are one-sided (all from same sender)
        const { data: senderIds, error: msgError } = await supabase
            .from('messages')
            .select('sender_id')
            .eq('match_id', match.id)
            .is('deleted_at', null);

        if (msgError) {
            console.error(`[Match Expiry] Error checking messages for match ${match.id}:`, msgError);
            continue;
        }

        if (!senderIds || senderIds.length === 0) continue;

        const uniqueSenders = new Set(senderIds.map(m => m.sender_id));

        // If only one person sent messages, this is a one-sided match
        if (uniqueSenders.size === 1) {
            const senderId = [...uniqueSenders][0];
            const ghostId = match.user_a_id === senderId ? match.user_b_id : match.user_a_id;

            const { error: updateError } = await supabase
                .from('matches')
                .update({
                    status: 'expired',
                    expired_at: now,
                    expire_reason: 'no_reply'
                })
                .eq('id', match.id);

            if (updateError) {
                console.error(`[Match Expiry] Failed to expire match ${match.id}:`, updateError);
            } else {
                console.log(`[Match Expiry] Expired match ${match.id} (no reply after ${NO_REPLY_EXPIRY_HOURS}h, ghost: ${ghostId})`);

                // Notify the person who actually tried — they deserve to know
                sendPushToUser(senderId, {
                    title: 'Match Expired',
                    body: 'Your match didn\'t reply in time. You\'re back in the pool — let\'s find someone better.',
                    url: '/match.html',
                    tag: `match-expired-${match.id}`
                });

                expiredCount++;
            }
        }
    }

    return expiredCount;
}

/**
 * Run the full expiry sweep.
 */
async function runExpirySweep() {
    const startTime = Date.now();
    console.log('[Match Expiry] Starting expiry sweep...');

    try {
        const zeroMsgExpired = await expireZeroMessageMatches();
        const oneSidedExpired = await expireOneSidedMatches();

        const elapsed = Date.now() - startTime;
        const total = zeroMsgExpired + oneSidedExpired;

        if (total > 0) {
            console.log(`[Match Expiry] Sweep complete in ${elapsed}ms — expired ${zeroMsgExpired} zero-message + ${oneSidedExpired} one-sided = ${total} total`);
        } else {
            console.log(`[Match Expiry] Sweep complete in ${elapsed}ms — no matches to expire`);
        }
    } catch (error) {
        console.error('[Match Expiry] Sweep failed:', error);
    }
}

/**
 * Start the periodic match expiry check.
 */
export function startMatchExpiry() {
    // Run immediately on startup to clean up any backlog
    runExpirySweep();

    // Then run every 15 minutes
    const intervalId = setInterval(runExpirySweep, EXPIRY_INTERVAL_MS);

    console.log(`[Match Expiry] Auto-expire enabled — checking every ${EXPIRY_INTERVAL_MS / 60000} minutes`);
    console.log(`[Match Expiry] Rules: ${NO_MESSAGE_EXPIRY_HOURS}h for 0-message matches, ${NO_REPLY_EXPIRY_HOURS}h for no-reply matches`);

    return intervalId;
}

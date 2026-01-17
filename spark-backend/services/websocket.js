import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import { supabase } from '../config/supabase.js';

let io = null;

// Map of matchId -> Set of socket ids
const matchRooms = new Map();
// Map of socket id -> user info
const socketUsers = new Map();
// Map of userId -> socket id
const userSockets = new Map();

export function initializeWebSocket(server, allowedOrigins) {
    io = new Server(server, {
        cors: {
            origin: allowedOrigins,
            methods: ['GET', 'POST'],
            credentials: true
        },
        pingTimeout: 60000,
        pingInterval: 25000
    });

    // Authentication middleware
    io.use(async (socket, next) => {
        try {
            const token = socket.handshake.auth.token;
            if (!token) {
                return next(new Error('Authentication required'));
            }

            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            socket.userId = decoded.id;
            socket.userEmail = decoded.email;
            next();
        } catch (error) {
            next(new Error('Invalid token'));
        }
    });

    io.on('connection', (socket) => {
        console.log(`[WS] User connected: ${socket.userId}`);

        // Store user-socket mapping
        userSockets.set(socket.userId, socket.id);
        socketUsers.set(socket.id, { userId: socket.userId });

        // Update user presence
        updatePresence(socket.userId, true);

        // Join a match room
        socket.on('join-match', async (matchId) => {
            try {
                // Verify user is part of this match
                const { data: match } = await supabase
                    .from('matches')
                    .select('user_a_id, user_b_id')
                    .eq('id', matchId)
                    .single();

                if (!match || (match.user_a_id !== socket.userId && match.user_b_id !== socket.userId)) {
                    socket.emit('error', { message: 'Not authorized for this match' });
                    return;
                }

                // Leave any previous match rooms
                socket.rooms.forEach(room => {
                    if (room !== socket.id) {
                        socket.leave(room);
                    }
                });

                // Join new room
                socket.join(matchId);
                socketUsers.get(socket.id).matchId = matchId;

                if (!matchRooms.has(matchId)) {
                    matchRooms.set(matchId, new Set());
                }
                matchRooms.get(matchId).add(socket.id);

                console.log(`[WS] User ${socket.userId} joined match ${matchId}`);

                // Notify partner
                const partnerId = match.user_a_id === socket.userId ? match.user_b_id : match.user_a_id;
                const partnerSocketId = userSockets.get(partnerId);
                if (partnerSocketId) {
                    io.to(partnerSocketId).emit('partner-online', { isOnline: true });
                }
            } catch (error) {
                console.error('[WS] Join match error:', error);
            }
        });

        // Handle new message
        socket.on('send-message', async (data) => {
            try {
                const { matchId, content, replyToId } = data;
                const userInfo = socketUsers.get(socket.id);

                if (!userInfo?.matchId || userInfo.matchId !== matchId) {
                    socket.emit('error', { message: 'Not in this match room' });
                    return;
                }

                // Broadcast to the room (including sender for confirmation)
                io.to(matchId).emit('new-message', {
                    id: data.tempId, // Use temp ID until confirmed
                    content,
                    sender_id: socket.userId,
                    reply_to_id: replyToId,
                    sent_at: new Date().toISOString(),
                    pending: true
                });
            } catch (error) {
                console.error('[WS] Send message error:', error);
            }
        });

        // Handle typing status
        socket.on('typing', (data) => {
            const { matchId, isTyping } = data;
            const userInfo = socketUsers.get(socket.id);

            if (userInfo?.matchId === matchId) {
                socket.to(matchId).emit('partner-typing', { isTyping });
            }
        });

        // Handle presence heartbeat
        socket.on('heartbeat', () => {
            updatePresence(socket.userId, true);
        });

        // Handle disconnect
        socket.on('disconnect', () => {
            console.log(`[WS] User disconnected: ${socket.userId}`);

            const userInfo = socketUsers.get(socket.id);
            if (userInfo?.matchId) {
                const room = matchRooms.get(userInfo.matchId);
                if (room) {
                    room.delete(socket.id);
                    if (room.size === 0) {
                        matchRooms.delete(userInfo.matchId);
                    }
                }

                // Notify partner of offline status
                socket.to(userInfo.matchId).emit('partner-online', { isOnline: false });
            }

            userSockets.delete(socket.userId);
            socketUsers.delete(socket.id);

            // Update presence to offline
            updatePresence(socket.userId, false);
        });
    });

    console.log('[WS] WebSocket server initialized');
    return io;
}

async function updatePresence(userId, isOnline) {
    try {
        if (isOnline) {
            await supabase
                .from('user_presence')
                .upsert({
                    user_id: userId,
                    last_seen: new Date().toISOString(),
                    is_online: true
                }, { onConflict: 'user_id' });
        } else {
            await supabase
                .from('user_presence')
                .update({
                    is_online: false,
                    last_seen: new Date().toISOString()
                })
                .eq('user_id', userId);
        }
    } catch (error) {
        console.error('[WS] Presence update error:', error);
    }
}

// Emit to a specific match room
export function emitToMatch(matchId, event, data) {
    if (io) {
        io.to(matchId).emit(event, data);
    }
}

// Emit to a specific user
export function emitToUser(userId, event, data) {
    const socketId = userSockets.get(userId);
    if (io && socketId) {
        io.to(socketId).emit(event, data);
    }
}

// Broadcast message confirmation (after DB save)
export function confirmMessage(matchId, message) {
    if (io) {
        io.to(matchId).emit('message-confirmed', message);
    }
}

export function getIO() {
    return io;
}

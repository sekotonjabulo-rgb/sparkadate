-- Migration: Chat Enhancements
-- Adds support for message editing, deletion, replies, and typing indicators

-- Add columns to messages table for edit/delete/reply functionality
ALTER TABLE messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS original_content TEXT DEFAULT NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES messages(id) DEFAULT NULL;

-- Create typing status table for real-time typing indicators
CREATE TABLE IF NOT EXISTS typing_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    is_typing BOOLEAN DEFAULT false,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(match_id, user_id)
);

-- Create push subscriptions table for web push notifications
CREATE TABLE IF NOT EXISTS push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    endpoint TEXT NOT NULL,
    p256dh TEXT NOT NULL,
    auth TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, endpoint)
);

-- Create index for faster typing status lookups
CREATE INDEX IF NOT EXISTS idx_typing_status_match_id ON typing_status(match_id);

-- Create index for faster push subscription lookups
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);

-- Create index for reply lookups
CREATE INDEX IF NOT EXISTS idx_messages_reply_to_id ON messages(reply_to_id);

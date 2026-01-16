-- Migration: Add presence tracking fields to users table
-- Run this migration in your Supabase SQL Editor

-- Add is_online column (defaults to false)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

-- Add last_seen column (timestamp of last activity)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create an index on last_seen for efficient queries
CREATE INDEX IF NOT EXISTS idx_users_last_seen ON users(last_seen);

-- Create an index on is_online for efficient filtering
CREATE INDEX IF NOT EXISTS idx_users_is_online ON users(is_online);

-- Optional: Create a function to automatically set users offline after inactivity
-- This can be called by a scheduled job (e.g., Supabase pg_cron)
CREATE OR REPLACE FUNCTION mark_inactive_users_offline()
RETURNS void AS $$
BEGIN
    UPDATE users
    SET is_online = false
    WHERE is_online = true
    AND last_seen < NOW() - INTERVAL '2 minutes';
END;
$$ LANGUAGE plpgsql;

-- Optional: Schedule the function to run every minute (requires pg_cron extension)
-- Uncomment if you have pg_cron enabled in Supabase
-- SELECT cron.schedule('mark-users-offline', '* * * * *', 'SELECT mark_inactive_users_offline()');

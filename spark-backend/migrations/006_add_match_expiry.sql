-- Migration 006: Add match auto-expiry support
-- Run this in Supabase SQL Editor
--
-- Matches with 0 messages auto-expire after 24 hours.
-- Matches with one-sided messages (no reply) auto-expire after 48 hours.
-- Expired users return to the matching pool automatically.

-- Add expired_at column to track when a match was auto-expired
ALTER TABLE matches ADD COLUMN IF NOT EXISTS expired_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- Add expire_reason to distinguish between expiry types
ALTER TABLE matches ADD COLUMN IF NOT EXISTS expire_reason VARCHAR(50) DEFAULT NULL;

-- Index on status + matched_at for efficient expiry queries
-- The background job queries active matches older than 24/48 hours
CREATE INDEX IF NOT EXISTS idx_matches_status_matched_at ON matches(status, matched_at);

-- Index on expired_at for querying recently expired matches
CREATE INDEX IF NOT EXISTS idx_matches_expired_at ON matches(expired_at) WHERE expired_at IS NOT NULL;

-- Comments
COMMENT ON COLUMN matches.expired_at IS 'Timestamp when match was auto-expired due to inactivity';
COMMENT ON COLUMN matches.expire_reason IS 'Reason for expiry: no_messages (24h, 0 msgs) or no_reply (48h, one-sided)';

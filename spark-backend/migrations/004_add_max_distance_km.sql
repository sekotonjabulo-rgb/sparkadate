-- Add max_distance_km column to user_preferences if it doesn't exist
ALTER TABLE user_preferences
ADD COLUMN IF NOT EXISTS max_distance_km INTEGER DEFAULT 50;

-- Create index for matching queries
CREATE INDEX IF NOT EXISTS idx_user_preferences_max_distance_km
ON user_preferences(max_distance_km);

-- Comment explaining the column
COMMENT ON COLUMN user_preferences.max_distance_km IS 'Maximum distance in kilometers for matching preferences';

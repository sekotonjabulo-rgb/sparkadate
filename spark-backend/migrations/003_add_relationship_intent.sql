-- Add relationship_intent column to user_preferences if it doesn't exist
ALTER TABLE user_preferences
ADD COLUMN IF NOT EXISTS relationship_intent VARCHAR(50) DEFAULT 'unsure';

-- Create index for matching queries
CREATE INDEX IF NOT EXISTS idx_user_preferences_relationship_intent
ON user_preferences(relationship_intent);

-- Comment explaining the values
COMMENT ON COLUMN user_preferences.relationship_intent IS 'User relationship intent: casual, serious, friends, unsure';

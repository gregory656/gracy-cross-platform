-- =====================================================
-- GRACYAI ARCHITECTURAL OVERRIDE - DATABASE MIGRATIONS
-- =====================================================

-- 1. Add hidden_by array to chat_rooms table for persistence
ALTER TABLE chat_rooms 
ADD COLUMN IF NOT EXISTS hidden_by UUID[] DEFAULT '{}';

-- 2. Add is_archived and is_hidden columns to chat_members table
ALTER TABLE chat_members 
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;

-- 3. Ensure posts table has proper indexing for category filtering
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);

-- 4. Add updated_at column to chat_members for tracking changes
ALTER TABLE chat_members 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 5. Create function to safely append to hidden_by array
CREATE OR REPLACE FUNCTION append_to_hidden_array()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.hidden_by IS NULL THEN
        NEW.hidden_by := ARRAY[NEW.hidden_by];
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SAMPLE DATA VERIFICATION QUERIES
-- =====================================================

-- Check if Silent Confessions exist in posts table
SELECT COUNT(*) as confession_count, 
       MIN(created_at) as oldest_confession,
       MAX(created_at) as newest_confession
FROM posts 
WHERE category = 'silent_confessions';

-- Check current chat_rooms structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'chat_rooms' 
  AND column_name IN ('hidden_by', 'is_hidden', 'is_archived');

-- Check for any messages that might cause overflow
SELECT COUNT(*) as total_messages,
       COUNT(CASE WHEN sender_id = 'gracy_ai_official' THEN 1 END) as ai_messages
FROM messages;

-- =====================================================
-- CLEANUP QUERIES (Run if needed)
-- =====================================================

-- Remove any orphaned chat_members records
DELETE FROM chat_members 
WHERE user_id NOT IN (SELECT id FROM profiles WHERE id IS NOT NULL);

-- Update any NULL hidden_by arrays
UPDATE chat_rooms 
SET hidden_by = '{}' 
WHERE hidden_by IS NULL;

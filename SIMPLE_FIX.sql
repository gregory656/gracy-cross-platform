-- =====================================================
-- SIMPLE FIX - RUN THIS FIRST
-- =====================================================

-- This script fixes the basic issues without complex relationships

-- 1. Add missing columns to posts table
ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'discussions',
ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE;

-- 2. Add missing columns to chat_rooms  
ALTER TABLE chat_rooms
ADD COLUMN IF NOT EXISTS hidden_by TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. Add missing columns to chat_members
ALTER TABLE chat_members
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 4. Fix existing Silent Confessions
UPDATE posts 
SET category = 'silent_confessions',
    is_anonymous = TRUE
WHERE content ILIKE ANY(ARRAY['%confession%', '%silent confession%', '%anonymous confession%'])
   AND (category IS NULL OR category != 'silent_confessions');

-- 5. Fix other uncategorized posts based on content
UPDATE posts 
SET category = 'marketplace'
WHERE content ILIKE ANY(ARRAY['%for sale%', '%selling%', '%price%', '%ksh%', '%kes%'])
   AND category IS NULL;

UPDATE posts 
SET category = 'housing'
WHERE content ILIKE ANY(ARRAY['%rent%', '%housing%', '%apartment%', '%hostel%'])
   AND category IS NULL;

UPDATE posts 
SET category = 'events_parties'
WHERE content ILIKE ANY(ARRAY['%event%', '%party%', '%celebration%'])
   AND category IS NULL;

UPDATE posts 
SET category = 'projects'
WHERE content ILIKE ANY(ARRAY['%project%', '%collaboration%', '%team up%'])
   AND category IS NULL;

-- 6. Set remaining NULL categories to discussions
UPDATE posts 
SET category = 'discussions'
WHERE category IS NULL;

-- 7. Create indexes
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_hidden_by ON chat_rooms USING GIN (hidden_by);

-- 8. Simple hide/unhide functions
CREATE OR REPLACE FUNCTION hide_chat(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE chat_rooms 
    SET hidden_by = array_append(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id),
        updated_at = NOW()
    WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION unhide_chat(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE chat_rooms 
    SET hidden_by = array_remove(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id),
        updated_at = NOW()
    WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check posts by category
SELECT 
    category,
    COUNT(*) as count,
    COUNT(CASE WHEN is_anonymous THEN 1 END) as anonymous_count
FROM posts 
GROUP BY category 
ORDER BY count DESC;

-- Check hidden chats
SELECT COUNT(*) as hidden_chats
FROM chat_rooms 
WHERE hidden_by IS NOT NULL AND array_length(hidden_by, 1) > 0;

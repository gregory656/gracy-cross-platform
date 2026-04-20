-- =====================================================
-- FINAL WORKING FIX - SIMPLE AND CORRECT
-- =====================================================

-- Step 1: Add missing columns with error handling
ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'discussions';

ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE;

-- Step 2: Fix Silent Confessions using SIMPLE LIKE (no arrays)
UPDATE posts 
SET category = 'silent_confessions',
    is_anonymous = TRUE
WHERE content LIKE '%confession%' 
   OR content LIKE '%silent confession%'
   OR (author_name IS NULL AND content LIKE '%confession%');

-- Step 3: Fix other uncategorized posts with simple patterns
UPDATE posts 
SET category = 'marketplace'
WHERE (content LIKE '%for sale%' OR content LIKE '%selling%' OR content LIKE '%price%' OR content LIKE '%ksh%' OR content LIKE '%kes%')
   AND category IS NULL;

UPDATE posts 
SET category = 'housing'
WHERE (content LIKE '%rent%' OR content LIKE '%housing%' OR content LIKE '%apartment%' OR content LIKE '%hostel%')
   AND category IS NULL;

UPDATE posts 
SET category = 'events_parties'
WHERE (content LIKE '%event%' OR content LIKE '%party%' OR content LIKE '%celebration%')
   AND category IS NULL;

UPDATE posts 
SET category = 'projects'
WHERE (content LIKE '%project%' OR content LIKE '%collaboration%' OR content LIKE '%team up%')
   AND category IS NULL;

-- Step 4: Set remaining NULL categories to discussions
UPDATE posts 
SET category = 'discussions'
WHERE category IS NULL;

-- Step 5: Add chat visibility columns
ALTER TABLE chat_rooms
ADD COLUMN IF NOT EXISTS hidden_by TEXT[] DEFAULT '{}';

ALTER TABLE chat_rooms
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE;

ALTER TABLE chat_members
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE;

ALTER TABLE chat_members
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;

-- Step 6: Simple hide function (works with either approach)
CREATE OR REPLACE FUNCTION hide_chat_room(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Try array approach first
    UPDATE chat_rooms 
    SET hidden_by = array_append(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id)
    WHERE id = p_room_id;
    
    -- If no rows affected, try boolean approach
    IF NOT FOUND THEN
        UPDATE chat_rooms 
        SET is_hidden = TRUE
        WHERE id = p_room_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Simple unhide function
CREATE OR REPLACE FUNCTION unhide_chat_room(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Try array approach first
    UPDATE chat_rooms 
    SET hidden_by = array_remove(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id)
    WHERE id = p_room_id;
    
    -- If no rows affected, try boolean approach
    IF NOT FOUND THEN
        UPDATE chat_rooms 
        SET is_hidden = FALSE
        WHERE id = p_room_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VERIFICATION - Run these to check your work
-- =====================================================

-- Check Silent Confessions
SELECT 
    category,
    COUNT(*) as count,
    COUNT(CASE WHEN is_anonymous THEN 1 END) as anonymous_count
FROM posts 
GROUP BY category
ORDER BY count DESC;

-- Check chat columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'posts' 
   OR table_name = 'chat_rooms'
   OR table_name = 'chat_members'
ORDER BY table_name, ordinal_position;

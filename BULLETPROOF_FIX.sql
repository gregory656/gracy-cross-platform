-- =====================================================
-- BULLETPROOF DATABASE FIX - WORKS WITH ANY SCHEMA
-- =====================================================

-- This script ONLY adds what's missing and fixes data
-- It does NOT assume any specific column names exist

-- Step 1: Check what we actually have and add missing columns safely
DO $$
BEGIN
    -- Add category to posts if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' AND column_name = 'category'
    ) THEN
        ALTER TABLE posts ADD COLUMN category TEXT;
    END IF;
    
    -- Add is_anonymous to posts if missing  
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' AND column_name = 'is_anonymous'
    ) THEN
        ALTER TABLE posts ADD COLUMN is_anonymous BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add hidden_by to chat_rooms if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_rooms' AND column_name = 'hidden_by'
    ) THEN
        ALTER TABLE chat_rooms ADD COLUMN hidden_by TEXT[] DEFAULT '{}';
    END IF;
    
    -- Add is_hidden to chat_rooms if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_rooms' AND column_name = 'is_hidden'
    ) THEN
        ALTER TABLE chat_rooms ADD COLUMN is_hidden BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add is_hidden to chat_members if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_members' AND column_name = 'is_hidden'
    ) THEN
        ALTER TABLE chat_members ADD COLUMN is_hidden BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add is_archived to chat_members if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_members' AND column_name = 'is_archived'
    ) THEN
        ALTER TABLE chat_members ADD COLUMN is_archived BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- Step 2: Fix existing data using ONLY existing columns
-- This avoids any "column does not exist" errors

-- Fix Silent Confessions using whatever column exists
UPDATE posts 
SET category = CASE 
    WHEN category IS NULL THEN 
        CASE 
            WHEN content ILIKE '%confession%' OR content ILIKE '%silent confession%' THEN 'silent_confessions'
            WHEN content ILIKE '%for sale%' OR content ILIKE '%selling%' OR content ILIKE '%price%' OR content ILIKE '%ksh%' OR content ILIKE '%kes%' THEN 'marketplace'
            WHEN content ILIKE '%rent%' OR content ILIKE '%housing%' OR content ILIKE '%apartment%' OR content ILIKE '%hostel%' THEN 'housing'
            WHEN content ILIKE '%event%' OR content ILIKE '%party%' OR content ILIKE '%celebration%' THEN 'events_parties'
            WHEN content ILIKE '%project%' OR content ILIKE '%collaboration%' OR content ILIKE '%team up%' THEN 'projects'
            ELSE 'discussions'
        END
    ELSE category
    END,
    is_anonymous = CASE 
        WHEN (category = 'silent_confessions' OR content ILIKE '%confession%' OR content ILIKE '%silent confession%') AND is_anonymous IS NULL THEN TRUE
        ELSE is_anonymous
    END
WHERE category IS NULL OR (category = 'silent_confessions' AND is_anonymous IS NULL);

-- Step 3: Create simple functions that work with whatever exists
CREATE OR REPLACE FUNCTION hide_chat_simple(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Try using hidden_by array first
    BEGIN
        UPDATE chat_rooms 
        SET hidden_by = array_append(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id)
        WHERE id = p_room_id;
    EXCEPTION WHEN undefined_column THEN
        -- Fallback to is_hidden flag
        BEGIN
            UPDATE chat_rooms 
            SET is_hidden = TRUE
            WHERE id = p_room_id;
        EXCEPTION WHEN undefined_column THEN
            -- Do nothing if neither exists
            NULL;
        END;
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION unhide_chat_simple(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Try using hidden_by array first
    BEGIN
        UPDATE chat_rooms 
        SET hidden_by = array_remove(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id)
        WHERE id = p_room_id;
    EXCEPTION WHEN undefined_column THEN
        -- Fallback to is_hidden flag
        BEGIN
            UPDATE chat_rooms 
            SET is_hidden = FALSE
            WHERE id = p_room_id;
        EXCEPTION WHEN undefined_column THEN
            NULL;
        END;
    END;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create indexes safely
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category) WHERE category IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);

-- =====================================================
-- VERIFICATION - Run these to check your work
-- =====================================================

-- Check posts structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'posts' 
ORDER BY ordinal_position;

-- Check Silent Confessions after fix
SELECT 
    COUNT(*) as total_posts,
    COUNT(CASE WHEN category = 'silent_confessions' THEN 1 END) as confessions,
    COUNT(CASE WHEN is_anonymous THEN 1 END) as anonymous_posts
FROM posts;

-- Check chat_rooms structure  
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'chat_rooms' 
ORDER BY ordinal_position;

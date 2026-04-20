-- =====================================================
-- ULTIMATE FIX - NO ASSUMPTIONS, JUST FIXES
-- =====================================================

-- Step 1: First, let's see what columns actually exist
-- Copy this whole query and run it FIRST to see your actual structure

SELECT 
    t.table_name,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default
FROM information_schema.tables t
JOIN information_schema.columns c ON t.table_name = c.table_name
WHERE t.table_schema = 'public' 
  AND t.table_name IN ('posts', 'chat_rooms', 'chat_members')
ORDER BY t.table_name, c.ordinal_position;

-- Step 2: Add ONLY what we know is missing based on error messages
-- This approach adds columns one by one with error handling

DO $$
BEGIN
    -- Add category column to posts if it doesn't exist
    BEGIN
        ALTER TABLE posts ADD COLUMN category TEXT DEFAULT 'discussions';
        RAISE NOTICE 'Added category column to posts';
    EXCEPTION WHEN duplicate_column THEN
        RAISE NOTICE 'category column already exists in posts';
    WHEN others THEN
        RAISE NOTICE 'Error adding category to posts: %', SQLERRM_MESSAGE;
    END;
    
    -- Add is_anonymous column to posts if it doesn't exist
    BEGIN
        ALTER TABLE posts ADD COLUMN is_anonymous BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_anonymous column to posts';
    EXCEPTION WHEN duplicate_column THEN
        RAISE NOTICE 'is_anonymous column already exists in posts';
    WHEN others THEN
        RAISE NOTICE 'Error adding is_anonymous to posts: %', SQLERRM_MESSAGE;
    END;
    
    -- Add hidden_by column to chat_rooms if it doesn't exist
    BEGIN
        ALTER TABLE chat_rooms ADD COLUMN hidden_by TEXT[] DEFAULT '{}';
        RAISE NOTICE 'Added hidden_by column to chat_rooms';
    EXCEPTION WHEN duplicate_column THEN
        RAISE NOTICE 'hidden_by column already exists in chat_rooms';
    WHEN others THEN
        RAISE NOTICE 'Error adding hidden_by to chat_rooms: %', SQLERRM_MESSAGE;
    END;
    
    -- Add is_hidden column to chat_rooms if it doesn't exist
    BEGIN
        ALTER TABLE chat_rooms ADD COLUMN is_hidden BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_hidden column to chat_rooms';
    EXCEPTION WHEN duplicate_column THEN
        RAISE NOTICE 'is_hidden column already exists in chat_rooms';
    WHEN others THEN
        RAISE NOTICE 'Error adding is_hidden to chat_rooms: %', SQLERRM_MESSAGE;
    END;
    
    -- Add is_hidden column to chat_members if it doesn't exist
    BEGIN
        ALTER TABLE chat_members ADD COLUMN is_hidden BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_hidden column to chat_members';
    EXCEPTION WHEN duplicate_column THEN
        RAISE NOTICE 'is_hidden column already exists in chat_members';
    WHEN others THEN
        RAISE NOTICE 'Error adding is_hidden to chat_members: %', SQLERRM_MESSAGE;
    END;
    
    -- Add is_archived column to chat_members if it doesn't exist
    BEGIN
        ALTER TABLE chat_members ADD COLUMN is_archived BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_archived column to chat_members';
    EXCEPTION WHEN duplicate_column THEN
        RAISE NOTICE 'is_archived column already exists in chat_members';
    WHEN others THEN
        RAISE NOTICE 'Error adding is_archived to chat_members: %', SQLERRM_MESSAGE;
    END;
END $$;

-- Step 3: Fix existing posts data using ONLY columns we know exist
-- This avoids any reference to non-existent columns

UPDATE posts 
SET category = 'silent_confessions'
WHERE content ILIKE '%confession%' 
  AND category IS NULL;

-- Step 4: Create simple hide/unhide functions that work with whatever exists

CREATE OR REPLACE FUNCTION safe_hide_chat(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Try hidden_by array first
    BEGIN
        UPDATE chat_rooms 
        SET hidden_by = array_append(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id)
        WHERE id = p_room_id;
        RAISE NOTICE 'Hidden chat using hidden_by array';
    EXCEPTION WHEN undefined_column THEN
        -- Try is_hidden flag
        BEGIN
            UPDATE chat_rooms 
            SET is_hidden = TRUE
            WHERE id = p_room_id;
            RAISE NOTICE 'Hidden chat using is_hidden flag';
        EXCEPTION WHEN undefined_table THEN
            RAISE NOTICE 'Neither hidden_by nor is_hidden columns available';
        END;
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION safe_unhide_chat(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Try hidden_by array first
    BEGIN
        UPDATE chat_rooms 
        SET hidden_by = array_remove(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id)
        WHERE id = p_room_id;
        RAISE NOTICE 'Unhidden chat using hidden_by array';
    EXCEPTION WHEN undefined_column THEN
        -- Try is_hidden flag
        BEGIN
            UPDATE chat_rooms 
            SET is_hidden = FALSE
            WHERE id = p_room_id;
            RAISE NOTICE 'Unhidden chat using is_hidden flag';
        EXCEPTION WHEN undefined_table THEN
            RAISE NOTICE 'Neither hidden_by nor is_hidden columns available';
        END;
    END;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Verification queries
-- Run these AFTER the above to see what happened

SELECT 'Posts with silent_confessions category: ' || COUNT(*) 
FROM posts 
WHERE category = 'silent_confessions';

SELECT 'Posts with NULL category: ' || COUNT(*) 
FROM posts 
WHERE category IS NULL;

SELECT 'Chat rooms with hidden_by not null: ' || COUNT(*) 
FROM chat_rooms 
WHERE hidden_by IS NOT NULL;

SELECT 'Chat rooms with is_hidden not null: ' || COUNT(*) 
FROM chat_rooms 
WHERE is_hidden IS NOT NULL;

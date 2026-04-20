-- =====================================================
-- COMPLETE DATABASE FIX FOR GRACYAI EVOLUTION
-- =====================================================

-- First, let's check what columns actually exist and add missing ones
-- This approach works regardless of current schema state

-- 1. Add missing columns to chat_rooms table (if they don't exist)
DO $$
BEGIN
    -- Add hidden_by column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_rooms' 
        AND column_name = 'hidden_by'
    ) THEN
        ALTER TABLE chat_rooms ADD COLUMN hidden_by TEXT[] DEFAULT '{}';
    END IF;

    -- Add is_hidden column if it doesn't exist  
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_rooms' 
        AND column_name = 'is_hidden'
    ) THEN
        ALTER TABLE chat_rooms ADD COLUMN is_hidden BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add updated_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_rooms' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE chat_rooms ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- 2. Add missing columns to posts table (if they don't exist)
DO $$
BEGIN
    -- Add category column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' 
        AND column_name = 'category'
    ) THEN
        ALTER TABLE posts ADD COLUMN category TEXT DEFAULT 'discussions';
    END IF;

    -- Add is_anonymous column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' 
        AND column_name = 'is_anonymous'
    ) THEN
        ALTER TABLE posts ADD COLUMN is_anonymous BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- 3. Add missing columns to chat_members table (if they don't exist)
DO $$
BEGIN
    -- Add is_hidden column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_members' 
        AND column_name = 'is_hidden'
    ) THEN
        ALTER TABLE chat_members ADD COLUMN is_hidden BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add is_archived column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_members' 
        AND column_name = 'is_archived'
    ) THEN
        ALTER TABLE chat_members ADD COLUMN is_archived BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add updated_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_members' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE chat_members ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- 4. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_updated_at ON chat_rooms(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_members_user_id ON chat_members(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_members_room_id ON chat_members(room_id);

-- 5. Simple functions that work with the actual schema

-- Hide chat room (works with either hidden_by array or is_hidden flag)
CREATE OR REPLACE FUNCTION hide_chat_room(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Try updating hidden_by array first (if it exists)
    BEGIN
        UPDATE chat_rooms 
        SET hidden_by = array_append(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id),
            updated_at = NOW()
        WHERE id = p_room_id;
    EXCEPTION WHEN undefined_column THEN
        -- If hidden_by doesn't exist, try is_hidden flag
        BEGIN
            UPDATE chat_rooms 
            SET is_hidden = TRUE,
                updated_at = NOW()
            WHERE id = p_room_id;
        EXCEPTION WHEN undefined_column THEN
            -- If neither exists, do nothing
            NULL;
        END;
    END;
END;
$$ LANGUAGE plpgsql;

-- Unhide chat room
CREATE OR REPLACE FUNCTION unhide_chat_room(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Try updating hidden_by array first
    BEGIN
        UPDATE chat_rooms 
        SET hidden_by = array_remove(COALESCE(hidden_by, ARRAY[]::TEXT[]), p_user_id),
            updated_at = NOW()
        WHERE id = p_room_id;
    EXCEPTION WHEN undefined_column THEN
        -- If hidden_by doesn't exist, try is_hidden flag
        BEGIN
            UPDATE chat_rooms 
            SET is_hidden = FALSE,
                updated_at = NOW()
            WHERE id = p_room_id;
        EXCEPTION WHEN undefined_column THEN
            NULL;
        END;
    END;
END;
$$ LANGUAGE plpgsql;

-- Archive chat room
CREATE OR REPLACE FUNCTION archive_chat_room(p_room_id TEXT, p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO chat_members (room_id, user_id, is_archived, updated_at)
    VALUES (p_room_id, p_user_id, TRUE, NOW())
    ON CONFLICT (room_id, user_id) 
    DO UPDATE SET is_archived = TRUE, updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- 6. Update existing Silent Confessions to ensure they have proper category
UPDATE posts 
SET category = 'silent_confessions' 
WHERE content ILIKE '%confession%' 
   OR content ILIKE '%silent confession%'
   OR (author_name IS NULL AND content IS NOT NULL);

-- 7. Fix any posts with NULL category
UPDATE posts 
SET category = 'discussions' 
WHERE category IS NULL;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check current schema
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN ('chat_rooms', 'posts', 'chat_members', 'messages')
ORDER BY table_name, ordinal_position;

-- Check Silent Confessions
SELECT COUNT(*) as confession_count,
       category
FROM posts 
WHERE category = 'silent_confessions'
GROUP BY category;

-- Check chat visibility setup
SELECT COUNT(*) as total_rooms,
       COUNT(CASE WHEN hidden_by IS NOT NULL THEN 1 END) as rooms_with_hidden_array,
       COUNT(CASE WHEN is_hidden IS NOT NULL THEN 1 END) as rooms_with_hidden_flag
FROM chat_rooms;

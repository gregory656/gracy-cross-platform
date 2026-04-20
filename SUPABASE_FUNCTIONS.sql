-- =====================================================
-- SUPABASE FUNCTIONS FOR CHAT VISIBILITY PERSISTENCE
-- =====================================================

-- Function to add user to hidden_by array in chat_rooms
CREATE OR REPLACE FUNCTION add_to_hidden(p_room_id TEXT, p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE chat_rooms 
    SET hidden_by = array_append(
        COALESCE(hidden_by, ARRAY[]::UUID[]), 
        p_user_id::UUID
    ),
    updated_at = NOW()
    WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql;

-- Function to remove user from hidden_by array in chat_rooms
CREATE OR REPLACE FUNCTION remove_from_hidden(p_room_id TEXT, p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE chat_rooms 
    SET hidden_by = array_remove(
        COALESCE(hidden_by, ARRAY[]::UUID[]), 
        p_user_id::UUID
    ),
    updated_at = NOW()
    WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get all non-hidden chat rooms for a user
CREATE OR REPLACE FUNCTION get_visible_chats(p_user_id UUID)
RETURNS TABLE (
    id TEXT,
    room_hash TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT cr.id, cr.room_hash, cr.created_at, cr.updated_at
    FROM chat_rooms cr
    WHERE NOT EXISTS (
        SELECT 1 FROM unnest(COALESCE(cr.hidden_by, ARRAY[]::UUID[])) as hidden_id
        WHERE hidden_id = p_user_id
    )
    OR cr.hidden_by IS NULL
    ORDER BY cr.updated_at DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Index on hidden_by array for faster containment checks
CREATE INDEX IF NOT EXISTS idx_chat_rooms_hidden_by 
ON chat_rooms USING GIN (hidden_by);

-- Index for chat_members user queries
CREATE INDEX IF NOT EXISTS idx_chat_members_user_id 
ON chat_members (user_id);

-- Index for chat_members room queries  
CREATE INDEX IF NOT EXISTS idx_chat_members_room_user 
ON chat_rooms (room_id, user_id);

-- =====================================================
-- REALTIME SUBSCRIPTION HELPERS
-- =====================================================

-- Policy to allow users to see their own chat visibility changes
CREATE POLICY "Users can view own chat members" ON chat_members
FOR SELECT USING (auth.uid() = user_id);

-- Policy to allow users to update their own chat visibility
CREATE POLICY "Users can update own chat members" ON chat_members
FOR UPDATE USING (auth.uid() = user_id);

-- Policy to allow users to insert their own chat members
CREATE POLICY "Users can insert own chat members" ON chat_members
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Message Status Tracking for Industrial Chat UI
-- Run this in Supabase SQL Editor

-- 1. Add status tracking to messages
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'sent', -- 'sent', 'delivered', 'read'
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS read_at TIMESTAMP WITH TIME ZONE;

-- 2. Indexing for speed
CREATE INDEX IF NOT EXISTS idx_messages_status ON messages(status);
CREATE INDEX IF NOT EXISTS idx_messages_status_room ON messages(room_id, status);

-- 3. Cleanup (Optional: Force all current messages to 'read')
UPDATE messages SET status = 'read' WHERE status IS NULL;

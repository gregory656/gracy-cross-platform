-- Final Elite Schema Update
-- Run this in Supabase SQL Editor

-- 1. Update profiles table with premium features
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS verification_level TEXT DEFAULT 'none',
ADD COLUMN IF NOT EXISTS is_ghost_mode BOOLEAN DEFAULT false;

-- 2. Update messages table with enhanced status tracking
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'sent',
ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES messages(id),
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS read_at TIMESTAMP WITH TIME ZONE;

-- 3. Indexing for elite performance
CREATE INDEX IF NOT EXISTS idx_messages_status ON messages(status);
CREATE INDEX IF NOT EXISTS idx_messages_status_room ON messages(room_id, status);
CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON messages(reply_to_id);
CREATE INDEX IF NOT EXISTS idx_profiles_premium ON profiles(is_premium);
CREATE INDEX IF NOT EXISTS idx_profiles_verification ON profiles(verification_level);

-- 4. Initialize existing data
UPDATE messages SET status = 'read' WHERE status IS NULL;
UPDATE profiles SET verification_level = 'none' WHERE verification_level IS NULL;

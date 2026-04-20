-- GracyAI Stories Table Migration (Fixed Syntax)
-- Run in Supabase SQL Editor (v2: no partial indexes)

-- Drop if exists (careful!)
DROP TABLE IF EXISTS stories CASCADE;
DROP VIEW IF EXISTS active_stories;

-- Create table
CREATE TABLE stories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours',
  viewed_by UUID[] DEFAULT ARRAY[]::UUID[]
);

-- Standard indexes
CREATE INDEX idx_stories_user_id ON stories (user_id);
CREATE INDEX idx_stories_expires ON stories (expires_at);
CREATE INDEX idx_stories_active ON stories (user_id, expires_at);

-- Enable RLS
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY stories_insert ON stories FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY stories_select ON stories FOR SELECT USING (expires_at > NOW());
CREATE POLICY stories_update ON stories FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY stories_delete ON stories FOR DELETE USING (auth.uid() = user_id);

-- Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE stories;

-- Active view
CREATE VIEW active_stories AS 
  SELECT * FROM stories 
  WHERE expires_at > NOW();

-- Test insert (replace with real user_id)
-- INSERT INTO stories (user_id, content) VALUES ('00000000-0000-0000-0000-000000000000', 'Test story!');
-- SELECT * FROM active_stories;


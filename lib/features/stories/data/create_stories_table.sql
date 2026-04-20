-- GracyAI Stories Table Migration
-- Run in Supabase SQL Editor

-- Enable RLS
ALTER TABLE IF EXISTS stories ENABLE ROW LEVEL SECURITY;

-- Create table
CREATE TABLE IF NOT EXISTS stories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours',
  viewed_by UUID[] DEFAULT ARRAY[]::UUID[],
  
  -- Indexes for perf
  INDEX idx_stories_user_id (user_id),
  INDEX idx_stories_expires (expires_at) WHERE expires_at > NOW(),
  INDEX idx_stories_active (user_id) WHERE expires_at > NOW()
);

-- RLS Policies (adjust as needed)
CREATE POLICY stories_insert ON stories FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY stories_select ON stories FOR SELECT USING (expires_at > NOW());
CREATE POLICY stories_update ON stories FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY stories_delete ON stories FOR DELETE USING (auth.uid() = user_id);

-- Realtime (broadcast inserts/updates)
ALTER PUBLICATION supabase_realtime ADD TABLE stories;

-- View for active stories
CREATE VIEW active_stories AS 
  SELECT * FROM stories 
  WHERE expires_at > NOW();

-- Sample insert (test)
-- INSERT INTO stories (user_id, content) VALUES ('your-user-id', 'Test story!');


-- =====================================================
-- FINAL DATABASE SETUP - CATEGORIES & RELATIONSHIPS
-- =====================================================

-- First, let's see what we actually have
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN ('posts', 'feed_categories', 'categories')
ORDER BY table_name, ordinal_position;

-- =====================================================
-- STEP 1: Create proper categories table if it doesn't exist
-- =====================================================

CREATE TABLE IF NOT EXISTS feed_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    tag TEXT NOT NULL,
    icon_name TEXT,
    color TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert standard categories if they don't exist
INSERT INTO feed_categories (slug, name, tag, icon_name, color, sort_order) VALUES
    ('silent_confessions', 'Silent Confessions', '#Confession', 'nights_stay_outlined', '#6B46C1', 1),
    ('discussions', 'Discussions', '#Discussion', 'forum_outlined', '#007AFF', 2),
    ('marketplace', 'Marketplace', '#Marketplace', 'storefront_outlined', '#00C2FF', 3),
    ('housing', 'Housing', '#Housing', 'home_work_outlined', '#FF6B35', 4),
    ('events_parties', 'Events/Parties', '#Events', 'celebration_outlined', '#FF3B30', 5),
    ('projects', 'Projects', '#Projects', 'rocket_launch_outlined', '#30D158', 6)
ON CONFLICT (slug) DO NOTHING;

-- =====================================================
-- STEP 2: Fix posts table category relationship
-- =====================================================

-- Add category column if it doesn't exist (with proper relationship)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' 
        AND column_name = 'category'
    ) THEN
        ALTER TABLE posts ADD COLUMN category TEXT DEFAULT 'discussions';
        
        -- Add foreign key constraint if feed_categories exists
        ALTER TABLE posts 
        ADD CONSTRAINT fk_posts_category 
        FOREIGN KEY (category) REFERENCES feed_categories(slug) 
        ON DELETE SET NULL;
    END IF;
    
    -- Add is_anonymous if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' 
        AND column_name = 'is_anonymous'
    ) THEN
        ALTER TABLE posts ADD COLUMN is_anonymous BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add category_id if we want proper FK relationship
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' 
        AND column_name = 'category_id'
    ) THEN
        ALTER TABLE posts ADD COLUMN category_id UUID REFERENCES feed_categories(id);
    END IF;
END $$;

-- =====================================================
-- STEP 3: Update existing posts to have proper categories
-- =====================================================

-- Update posts that look like confessions to have silent_confessions category
UPDATE posts 
SET category = 'silent_confessions',
    is_anonymous = TRUE
WHERE content ILIKE ANY(ARRAY['%confession%', '%silent confession%', '%anonymous confession%'])
   OR (author_name IS NULL AND content ILIKE '%confession%');

-- Update posts with marketplace keywords
UPDATE posts 
SET category = 'marketplace'
WHERE content ILIKE ANY(ARRAY['%for sale%', '%selling%', '%price%', '%ksh%', '%kes%', '%buy%', '%market%'])
   AND category IS NULL;

-- Update posts with housing keywords  
UPDATE posts 
SET category = 'housing'
WHERE content ILIKE ANY(ARRAY['%rent%', '%housing%', '%apartment%', '%hostel%', '%accommodation%'])
   AND category IS NULL;

-- Update posts with events keywords
UPDATE posts 
SET category = 'events_parties'
WHERE content ILIKE ANY(ARRAY['%event%', '%party%', '%celebration%', '%meetup%', '%gathering%'])
   AND category IS NULL;

-- Update posts with projects keywords
UPDATE posts 
SET category = 'projects'
WHERE content ILIKE ANY(ARRAY['%project%', '%collaboration%', '%looking for%', '%team up%', '%startup%'])
   AND category IS NULL;

-- Set remaining uncategorized posts to discussions
UPDATE posts 
SET category = 'discussions'
WHERE category IS NULL;

-- =====================================================
-- STEP 4: Create proper indexes
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_category_created ON posts(category, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_categories_slug ON feed_categories(slug);
CREATE INDEX IF NOT EXISTS idx_feed_categories_sort ON feed_categories(sort_order);

-- =====================================================
-- STEP 5: Create view for posts with category info
-- =====================================================

CREATE OR REPLACE VIEW posts_with_categories AS
SELECT 
    p.*,
    fc.name as category_name,
    fc.tag as category_tag,
    fc.icon_name as category_icon,
    fc.color as category_color,
    fc.sort_order as category_sort_order
FROM posts p
LEFT JOIN feed_categories fc ON p.category = fc.slug
ORDER BY p.created_at DESC;

-- =====================================================
-- STEP 6: Functions for safe category operations
-- =====================================================

-- Function to get posts by category (handles missing categories gracefully)
CREATE OR REPLACE FUNCTION get_posts_by_category(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0,
    p_category_filter TEXT DEFAULT NULL
) RETURNS TABLE (
    id TEXT,
    author_id TEXT,
    content TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    category TEXT,
    is_anonymous BOOLEAN,
    -- Add other post fields as needed
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0
) AS $$
BEGIN
    -- Try querying with category relationship first
    BEGIN
        RETURN QUERY
        SELECT p.id, p.author_id, p.content, p.created_at, p.category, p.is_anonymous,
               COALESCE(p.likes_count, 0) as likes_count,
               COALESCE(p.comments_count, 0) as comments_count,
               COALESCE(p.view_count, 0) as view_count
        FROM posts p
        LEFT JOIN feed_categories fc ON p.category = fc.slug
        WHERE (p_category_filter IS NULL OR p.category = p_category_filter)
        ORDER BY p.created_at DESC
        LIMIT p_limit OFFSET p_offset;
    EXCEPTION WHEN undefined_table THEN
        -- If feed_categories doesn't exist, query posts directly
        RETURN QUERY
        SELECT id, author_id, content, created_at, category, is_anonymous,
               COALESCE(likes_count, 0) as likes_count,
               COALESCE(comments_count, 0) as comments_count,
               COALESCE(view_count, 0) as view_count
        FROM posts
        WHERE (p_category_filter IS NULL OR category = p_category_filter)
        ORDER BY created_at DESC
        LIMIT p_limit OFFSET p_offset;
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check categories are properly set up
SELECT * FROM feed_categories ORDER BY sort_order;

-- Check Silent Confessions count
SELECT 
    COUNT(*) as total_confessions,
    COUNT(CASE WHEN is_anonymous THEN 1 END) as anonymous_confessions,
    MIN(created_at) as oldest_confession
FROM posts 
WHERE category = 'silent_confessions';

-- Check category distribution
SELECT 
    fc.name as category_name,
    COUNT(p.id) as post_count
FROM feed_categories fc
LEFT JOIN posts p ON fc.slug = p.category
GROUP BY fc.id, fc.name, fc.sort_order
ORDER BY fc.sort_order;

-- Sample query to get posts with categories (use this in your app)
SELECT * FROM get_posts_by_category(20, 0, NULL); -- All posts
SELECT * FROM get_posts_by_category(20, 0, 'silent_confessions'); -- Only confessions

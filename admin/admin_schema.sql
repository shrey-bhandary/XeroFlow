-- XeroFlow Admin Portal - Database Schema Updates
-- Run this in your Supabase SQL Editor AFTER the initial schema

-- ============================================
-- 1. CREATE ADMINS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on admins
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- Create trigger for updated_at (drop first if exists)
DROP TRIGGER IF EXISTS update_admins_updated_at ON admins;
CREATE TRIGGER update_admins_updated_at BEFORE UPDATE ON admins
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 2. ENHANCE ORDERS TABLE (add print details)
-- ============================================
ALTER TABLE orders ADD COLUMN IF NOT EXISTS file_names TEXT[];
ALTER TABLE orders ADD COLUMN IF NOT EXISTS copies INTEGER DEFAULT 1;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_color BOOLEAN DEFAULT FALSE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_double_sided BOOLEAN DEFAULT FALSE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS paper_size TEXT DEFAULT 'A4';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS total_pages INTEGER;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS processed_by UUID REFERENCES admins(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS picked_up_at TIMESTAMP WITH TIME ZONE;

-- ============================================
-- 3. RLS POLICIES FOR ADMIN ACCESS
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "Admins can read all orders" ON orders;
DROP POLICY IF EXISTS "Admins can update all orders" ON orders;
DROP POLICY IF EXISTS "Admins can read all students" ON students;

-- Allow reading all orders (for admin portal)
-- Note: In production, implement proper JWT-based admin auth
CREATE POLICY "Admins can read all orders" ON orders
  FOR SELECT USING (true);

-- Allow updating all orders
CREATE POLICY "Admins can update all orders" ON orders
  FOR UPDATE USING (true);

-- Allow reading all students for order display
CREATE POLICY "Admins can read all students" ON students
  FOR SELECT USING (true);

-- ============================================
-- 4. INSERT A DEFAULT ADMIN USER
-- ============================================
-- Change these credentials in production!
INSERT INTO admins (email, name, password_hash, is_active)
VALUES ('admin@xeroflow.live', 'Xerox Admin', 'admin123', true)
ON CONFLICT (email) DO NOTHING;

-- ============================================
-- 5. CREATE INDEXES FOR BETTER PERFORMANCE
-- ============================================
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_processed_at ON orders(processed_at);
CREATE INDEX IF NOT EXISTS idx_admins_email ON admins(email);

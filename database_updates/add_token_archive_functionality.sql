-- ============================================================
-- ADD ARCHIVE FUNCTIONALITY TO TOKENS TABLE
-- Run this in your Supabase SQL Editor
-- ============================================================

-- Add archive-related columns to tokens table
ALTER TABLE public.tokens 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE;

ALTER TABLE public.tokens 
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

ALTER TABLE public.tokens 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Update existing records to have archived = false (in case any are null)
UPDATE public.tokens 
SET archived = FALSE 
WHERE archived IS NULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tokens_archived 
ON public.tokens(archived);

CREATE INDEX IF NOT EXISTS idx_tokens_assigned_to_archived 
ON public.tokens(assigned_to, archived);

CREATE INDEX IF NOT EXISTS idx_tokens_assigned_by_archived 
ON public.tokens(assigned_by, archived);

-- Create a trigger function to automatically update updated_at
CREATE OR REPLACE FUNCTION update_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger to tokens table
DROP TRIGGER IF EXISTS update_tokens_updated_at_trigger ON public.tokens;
CREATE TRIGGER update_tokens_updated_at_trigger
    BEFORE UPDATE ON public.tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_tokens_updated_at();

-- Update RLS policies to handle archived tokens
-- The existing policies will continue to work, but we can optimize them
DROP POLICY IF EXISTS "Admins full access to tokens" ON public.tokens;
DROP POLICY IF EXISTS "MDEs can view own tokens" ON public.tokens;
DROP POLICY IF EXISTS "MDEs can update own token status" ON public.tokens;

-- Recreate policies with better performance (archived tokens are still accessible)
CREATE POLICY "Admins full access to tokens"
  ON public.tokens FOR ALL
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  );

CREATE POLICY "MDEs can view own tokens"
  ON public.tokens FOR SELECT
  USING (assigned_to = auth.uid());

CREATE POLICY "MDEs can update own token status"
  ON public.tokens FOR UPDATE
  USING (assigned_to = auth.uid());

-- Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'tokens' 
  AND column_name IN ('archived', 'archived_at', 'updated_at')
ORDER BY column_name;

-- Show current tokens table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'tokens'
ORDER BY ordinal_position;
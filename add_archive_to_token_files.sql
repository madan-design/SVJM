-- ============================================================
-- ADD ARCHIVE FUNCTIONALITY TO TOKEN_FILES TABLE
-- Run this in your Supabase SQL Editor
-- ============================================================

-- Add archive-related columns to token_files table
ALTER TABLE public.token_files 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE;

ALTER TABLE public.token_files 
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

ALTER TABLE public.token_files 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Update existing records to have archived = false (in case any are null)
UPDATE public.token_files 
SET archived = FALSE 
WHERE archived IS NULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_token_files_archived 
ON public.token_files(archived);

CREATE INDEX IF NOT EXISTS idx_token_files_token_archived 
ON public.token_files(token_id, archived);

CREATE INDEX IF NOT EXISTS idx_token_files_uploaded_by_archived 
ON public.token_files(uploaded_by, archived);

-- Create a trigger function to automatically update updated_at
CREATE OR REPLACE FUNCTION update_token_files_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger to token_files table
DROP TRIGGER IF EXISTS update_token_files_updated_at_trigger ON public.token_files;
CREATE TRIGGER update_token_files_updated_at_trigger
    BEFORE UPDATE ON public.token_files
    FOR EACH ROW
    EXECUTE FUNCTION update_token_files_updated_at();

-- Update RLS policies to handle archived files
-- Drop existing policies and recreate them to include archived column handling
DROP POLICY IF EXISTS "MDEs can manage own token files" ON public.token_files;
DROP POLICY IF EXISTS "MDEs can view files of assigned tokens" ON public.token_files;

-- Recreate policies with archive support
CREATE POLICY "MDEs can manage own token files"
  ON public.token_files FOR ALL
  USING (uploaded_by = auth.uid());

CREATE POLICY "MDEs can view files of assigned tokens"
  ON public.token_files FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.tokens t
      WHERE t.id = token_id AND t.assigned_to = auth.uid()
    )
  );

-- Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'token_files' 
  AND column_name IN ('archived', 'archived_at', 'updated_at')
ORDER BY column_name;
-- Add archive functionality to token_files table
-- Run this in your Supabase SQL Editor

-- Add archived column (boolean, default false)
ALTER TABLE token_files 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE;

-- Add archived_at column (timestamp)
ALTER TABLE token_files 
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

-- Add updated_at column if it doesn't exist
ALTER TABLE token_files 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create an index on archived column for better performance
CREATE INDEX IF NOT EXISTS idx_token_files_archived ON token_files(archived);

-- Create an index on token_id and archived for better query performance
CREATE INDEX IF NOT EXISTS idx_token_files_token_archived ON token_files(token_id, archived);

-- Update existing records to have archived = false
UPDATE token_files SET archived = FALSE WHERE archived IS NULL;

-- Create a trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply the trigger to token_files table
DROP TRIGGER IF EXISTS update_token_files_updated_at ON token_files;
CREATE TRIGGER update_token_files_updated_at
    BEFORE UPDATE ON token_files
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Verify the changes
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'token_files' 
AND column_name IN ('archived', 'archived_at', 'updated_at');
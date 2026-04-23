-- Add legacy_folder_id column to existing token_files table
-- This allows the existing table to handle both regular token files and legacy files

ALTER TABLE token_files 
ADD COLUMN legacy_folder_id UUID REFERENCES legacy_folders(id) ON DELETE CASCADE;

-- Create index for better performance
CREATE INDEX idx_token_files_legacy_folder_id ON token_files(legacy_folder_id);

-- Update RLS policies to handle legacy files
DROP POLICY IF EXISTS "Users can view their files" ON token_files;
DROP POLICY IF EXISTS "Users can insert their files" ON token_files;
DROP POLICY IF EXISTS "Users can update their files" ON token_files;

-- New policies that handle both token files and legacy files
CREATE POLICY "Users can view their token files" ON token_files
    FOR SELECT USING (
        auth.uid() = uploaded_by OR 
        (legacy_folder_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM legacy_folders 
            WHERE id = legacy_folder_id AND created_by = auth.uid()
        ))
    );

CREATE POLICY "Users can insert token files" ON token_files
    FOR INSERT WITH CHECK (auth.uid() = uploaded_by);

CREATE POLICY "Users can update their token files" ON token_files
    FOR UPDATE USING (auth.uid() = uploaded_by);
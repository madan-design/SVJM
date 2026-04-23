-- Fix RLS policies for token_files to handle legacy file uploads properly

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their token files" ON token_files;
DROP POLICY IF EXISTS "Users can insert token files" ON token_files;
DROP POLICY IF EXISTS "Users can update their token files" ON token_files;

-- Create new policies that properly handle both token files and legacy files
CREATE POLICY "Users can view token and legacy files" ON token_files
    FOR SELECT USING (
        auth.uid() = uploaded_by OR 
        (token_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM tokens 
            WHERE id = token_id AND assigned_to = auth.uid()
        )) OR
        (legacy_folder_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM legacy_folders 
            WHERE id = legacy_folder_id AND created_by = auth.uid()
        ))
    );

CREATE POLICY "Users can insert token and legacy files" ON token_files
    FOR INSERT WITH CHECK (
        auth.uid() = uploaded_by AND (
            (token_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM tokens 
                WHERE id = token_id AND assigned_to = auth.uid()
            )) OR
            (legacy_folder_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM legacy_folders 
                WHERE id = legacy_folder_id AND created_by = auth.uid()
            )) OR
            (token_id IS NULL AND legacy_folder_id IS NULL)
        )
    );

CREATE POLICY "Users can update their token and legacy files" ON token_files
    FOR UPDATE USING (auth.uid() = uploaded_by);

CREATE POLICY "Users can delete their token and legacy files" ON token_files
    FOR DELETE USING (auth.uid() = uploaded_by);
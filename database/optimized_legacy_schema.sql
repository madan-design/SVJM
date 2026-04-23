-- Optimized Legacy Files Database Schema
-- Designed to work perfectly with the Flutter pipeline and variable mappings

-- Drop existing objects first
DROP TABLE IF EXISTS legacy_files CASCADE;
DROP TABLE IF EXISTS legacy_folders CASCADE;
DROP VIEW IF EXISTS active_legacy_folders CASCADE;
DROP VIEW IF EXISTS archived_legacy_folders CASCADE;
DROP FUNCTION IF EXISTS archive_legacy_folder(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS restore_legacy_folder(UUID) CASCADE;
DROP FUNCTION IF EXISTS delete_legacy_folder(UUID, UUID) CASCADE;

-- Remove legacy_folder_id column if it exists
ALTER TABLE token_files DROP COLUMN IF EXISTS legacy_folder_id CASCADE;

-- Add legacy_folder_id column to token_files (this is what your Flutter code expects)
ALTER TABLE token_files 
ADD COLUMN legacy_folder_id UUID REFERENCES legacy_folders(id) ON DELETE CASCADE;

-- Create legacy_folders table with exact structure your Flutter code expects
CREATE TABLE legacy_folders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    folder_name TEXT NOT NULL,
    year INTEGER NOT NULL CHECK (year >= 2000 AND year <= 2100),
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    description TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'completed', 'archived', 'deleted')) NOT NULL,
    archived_at TIMESTAMP WITH TIME ZONE,
    archived_by UUID REFERENCES auth.users(id),
    completed_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID REFERENCES auth.users(id),
    
    -- Ensure unique folder names per user/year/month combination
    UNIQUE(folder_name, year, month, created_by)
);

-- Indexes for optimal performance based on your queries
CREATE INDEX idx_legacy_folders_created_by_status ON legacy_folders(created_by, status);
CREATE INDEX idx_legacy_folders_status ON legacy_folders(status);
CREATE INDEX idx_legacy_folders_archived_at ON legacy_folders(archived_at DESC) WHERE status = 'archived';
CREATE INDEX idx_legacy_folders_year_month ON legacy_folders(year, month);
CREATE INDEX idx_token_files_legacy_folder_id ON token_files(legacy_folder_id) WHERE legacy_folder_id IS NOT NULL;

-- Enable RLS
ALTER TABLE legacy_folders ENABLE ROW LEVEL SECURITY;

-- RLS Policies for legacy_folders (optimized for your use cases)
CREATE POLICY "Users can view their non-deleted legacy folders" ON legacy_folders
    FOR SELECT USING (created_by = auth.uid() AND status != 'deleted');

CREATE POLICY "Users can insert their legacy folders" ON legacy_folders
    FOR INSERT WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can update their legacy folders" ON legacy_folders
    FOR UPDATE USING (created_by = auth.uid());

CREATE POLICY "Admins can view completed legacy folders" ON legacy_folders
    FOR SELECT USING (
        status = 'completed' AND 
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Update RLS policies for token_files to handle legacy files
DROP POLICY IF EXISTS "Users can view token and legacy files" ON token_files;
DROP POLICY IF EXISTS "Users can insert token and legacy files" ON token_files;
DROP POLICY IF EXISTS "Users can update their token and legacy files" ON token_files;
DROP POLICY IF EXISTS "Users can delete their token and legacy files" ON token_files;

CREATE POLICY "Users can view their files" ON token_files
    FOR SELECT USING (
        uploaded_by = auth.uid() OR
        (token_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM tokens WHERE id = token_id AND assigned_to = auth.uid()
        )) OR
        (legacy_folder_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM legacy_folders WHERE id = legacy_folder_id AND created_by = auth.uid()
        ))
    );

CREATE POLICY "Users can insert files" ON token_files
    FOR INSERT WITH CHECK (
        uploaded_by = auth.uid() AND (
            (token_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM tokens WHERE id = token_id AND assigned_to = auth.uid()
            )) OR
            (legacy_folder_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM legacy_folders WHERE id = legacy_folder_id AND created_by = auth.uid()
            )) OR
            (token_id IS NULL AND legacy_folder_id IS NULL)
        )
    );

CREATE POLICY "Users can update their files" ON token_files
    FOR UPDATE USING (uploaded_by = auth.uid());

CREATE POLICY "Users can delete their files" ON token_files
    FOR DELETE USING (uploaded_by = auth.uid());

-- Trigger for updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_legacy_folders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_legacy_folders_updated_at
    BEFORE UPDATE ON legacy_folders
    FOR EACH ROW
    EXECUTE FUNCTION update_legacy_folders_updated_at();

-- Optimized functions that match your Flutter service methods exactly
CREATE OR REPLACE FUNCTION archive_legacy_folder(folder_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE legacy_folders 
    SET 
        status = 'archived',
        archived_at = NOW(),
        archived_by = user_id
    WHERE id = folder_id AND created_by = user_id AND status IN ('draft', 'completed');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION restore_legacy_folder(folder_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE legacy_folders 
    SET 
        status = 'draft',
        archived_at = NULL,
        archived_by = NULL
    WHERE id = folder_id AND status = 'archived';
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_legacy_folder(folder_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    file_paths TEXT[];
BEGIN
    -- Get all file paths for this folder
    SELECT ARRAY_AGG(file_path) INTO file_paths
    FROM token_files 
    WHERE legacy_folder_id = folder_id;
    
    -- Delete files from storage (this would need to be handled by your Flutter code)
    -- Mark folder as deleted (soft delete)
    UPDATE legacy_folders 
    SET 
        status = 'deleted',
        deleted_at = NOW(),
        deleted_by = user_id
    WHERE id = folder_id AND created_by = user_id;
    
    -- Delete file records from database
    DELETE FROM token_files WHERE legacy_folder_id = folder_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Views that match your query patterns
CREATE VIEW active_legacy_folders AS
SELECT * FROM legacy_folders 
WHERE status IN ('draft', 'completed')
ORDER BY created_at DESC;

CREATE VIEW archived_legacy_folders AS
SELECT * FROM legacy_folders 
WHERE status = 'archived'
ORDER BY archived_at DESC;

CREATE VIEW my_legacy_folders AS
SELECT * FROM legacy_folders 
WHERE created_by = auth.uid() AND status != 'deleted'
ORDER BY created_at DESC;

CREATE VIEW my_active_legacy_folders AS
SELECT * FROM legacy_folders 
WHERE created_by = auth.uid() AND status IN ('draft', 'completed')
ORDER BY created_at DESC;

CREATE VIEW my_archived_legacy_folders AS
SELECT * FROM legacy_folders 
WHERE created_by = auth.uid() AND status = 'archived'
ORDER BY archived_at DESC;

-- Grant permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON legacy_folders TO authenticated;
GRANT SELECT ON active_legacy_folders TO authenticated;
GRANT SELECT ON archived_legacy_folders TO authenticated;
GRANT SELECT ON my_legacy_folders TO authenticated;
GRANT SELECT ON my_active_legacy_folders TO authenticated;
GRANT SELECT ON my_archived_legacy_folders TO authenticated;
GRANT EXECUTE ON FUNCTION archive_legacy_folder(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION restore_legacy_folder(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_legacy_folder(UUID, UUID) TO authenticated;

-- Insert some sample data for testing (optional)
-- INSERT INTO legacy_folders (folder_name, year, month, created_by, status) 
-- VALUES ('Test Folder', 2024, 1, auth.uid(), 'draft');

COMMENT ON TABLE legacy_folders IS 'Stores legacy file folders with year/month organization';
COMMENT ON COLUMN legacy_folders.status IS 'Status flow: draft -> completed -> archived -> deleted';
COMMENT ON COLUMN token_files.legacy_folder_id IS 'Links files to legacy folders, NULL for regular token files';
-- Complete Legacy System Database Schema
-- This schema handles both legacy folders and files with proper archive/restore/delete operations

-- Legacy folders table
CREATE TABLE legacy_folders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    folder_name TEXT NOT NULL,
    description TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'archived', 'deleted')),
    archived_at TIMESTAMP WITH TIME ZONE,
    archived_by UUID REFERENCES auth.users(id),
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID REFERENCES auth.users(id)
);

-- Legacy files table (updated to reference folders)
CREATE TABLE legacy_files (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT,
    file_type TEXT,
    folder_id UUID REFERENCES legacy_folders(id) ON DELETE CASCADE,
    uploaded_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    description TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'archived', 'deleted')),
    archived_at TIMESTAMP WITH TIME ZONE,
    archived_by UUID REFERENCES auth.users(id),
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX idx_legacy_folders_status ON legacy_folders(status);
CREATE INDEX idx_legacy_folders_created_by ON legacy_folders(created_by);
CREATE INDEX idx_legacy_files_status ON legacy_files(status);
CREATE INDEX idx_legacy_files_folder_id ON legacy_files(folder_id);
CREATE INDEX idx_legacy_files_uploaded_by ON legacy_files(uploaded_by);

-- Enable RLS
ALTER TABLE legacy_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE legacy_files ENABLE ROW LEVEL SECURITY;

-- RLS Policies for legacy_folders
CREATE POLICY "Users can view active and archived legacy folders" ON legacy_folders
    FOR SELECT USING (status IN ('active', 'archived'));

CREATE POLICY "Users can insert legacy folders" ON legacy_folders
    FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update their legacy folders" ON legacy_folders
    FOR UPDATE USING (auth.uid() = created_by);

-- RLS Policies for legacy_files
CREATE POLICY "Users can view active and archived legacy files" ON legacy_files
    FOR SELECT USING (status IN ('active', 'archived'));

CREATE POLICY "Users can insert legacy files" ON legacy_files
    FOR INSERT WITH CHECK (auth.uid() = uploaded_by);

CREATE POLICY "Users can update their legacy files" ON legacy_files
    FOR UPDATE USING (auth.uid() = uploaded_by);

-- Update triggers
CREATE OR REPLACE FUNCTION update_legacy_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_legacy_folders_updated_at
    BEFORE UPDATE ON legacy_folders
    FOR EACH ROW
    EXECUTE FUNCTION update_legacy_updated_at();

CREATE TRIGGER trigger_update_legacy_files_updated_at
    BEFORE UPDATE ON legacy_files
    FOR EACH ROW
    EXECUTE FUNCTION update_legacy_updated_at();

-- Folder management functions
CREATE OR REPLACE FUNCTION archive_legacy_folder(folder_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE legacy_folders 
    SET 
        status = 'archived',
        archived_at = NOW(),
        archived_by = user_id
    WHERE id = folder_id AND status = 'active';
    
    -- Also archive all files in the folder
    UPDATE legacy_files 
    SET 
        status = 'archived',
        archived_at = NOW(),
        archived_by = user_id
    WHERE folder_id = folder_id AND status = 'active';
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION restore_legacy_folder(folder_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE legacy_folders 
    SET 
        status = 'active',
        archived_at = NULL,
        archived_by = NULL
    WHERE id = folder_id AND status = 'archived';
    
    -- Also restore all files in the folder
    UPDATE legacy_files 
    SET 
        status = 'active',
        archived_at = NULL,
        archived_by = NULL
    WHERE folder_id = folder_id AND status = 'archived';
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_legacy_folder(folder_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE legacy_folders 
    SET 
        status = 'deleted',
        deleted_at = NOW(),
        deleted_by = user_id
    WHERE id = folder_id AND status IN ('active', 'archived');
    
    -- Also delete all files in the folder
    UPDATE legacy_files 
    SET 
        status = 'deleted',
        deleted_at = NOW(),
        deleted_by = user_id
    WHERE folder_id = folder_id AND status IN ('active', 'archived');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- File management functions
CREATE OR REPLACE FUNCTION archive_legacy_file(file_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE legacy_files 
    SET 
        status = 'archived',
        archived_at = NOW(),
        archived_by = user_id
    WHERE id = file_id AND status = 'active';
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION restore_legacy_file(file_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE legacy_files 
    SET 
        status = 'active',
        archived_at = NULL,
        archived_by = NULL
    WHERE id = file_id AND status = 'archived';
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_legacy_file(file_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE legacy_files 
    SET 
        status = 'deleted',
        deleted_at = NOW(),
        deleted_by = user_id
    WHERE id = file_id AND status IN ('active', 'archived');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Views for easy querying
CREATE VIEW active_legacy_folders AS
SELECT * FROM legacy_folders WHERE status = 'active';

CREATE VIEW archived_legacy_folders AS
SELECT * FROM legacy_folders WHERE status = 'archived';

CREATE VIEW active_legacy_files AS
SELECT * FROM legacy_files WHERE status = 'active';

CREATE VIEW archived_legacy_files AS
SELECT * FROM legacy_files WHERE status = 'archived';

-- Grant permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON legacy_folders TO authenticated;
GRANT ALL ON legacy_files TO authenticated;
GRANT SELECT ON active_legacy_folders TO authenticated;
GRANT SELECT ON archived_legacy_folders TO authenticated;
GRANT SELECT ON active_legacy_files TO authenticated;
GRANT SELECT ON archived_legacy_files TO authenticated;
GRANT EXECUTE ON FUNCTION archive_legacy_folder(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION restore_legacy_folder(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_legacy_folder(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION archive_legacy_file(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION restore_legacy_file(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_legacy_file(UUID, UUID) TO authenticated;
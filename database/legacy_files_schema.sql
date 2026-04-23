-- Legacy Files Database Schema
-- This schema handles legacy files with proper archive/restore/delete operations

-- Main legacy files table
CREATE TABLE legacy_files (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT,
    file_type TEXT,
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

-- Index for better performance
CREATE INDEX idx_legacy_files_status ON legacy_files(status);
CREATE INDEX idx_legacy_files_uploaded_by ON legacy_files(uploaded_by);
CREATE INDEX idx_legacy_files_created_at ON legacy_files(created_at DESC);

-- RLS (Row Level Security) policies
ALTER TABLE legacy_files ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see all active and archived files
CREATE POLICY "Users can view active and archived legacy files" ON legacy_files
    FOR SELECT USING (status IN ('active', 'archived'));

-- Policy: Users can insert their own files
CREATE POLICY "Users can insert legacy files" ON legacy_files
    FOR INSERT WITH CHECK (auth.uid() = uploaded_by);

-- Policy: Users can update files they uploaded (for archive/restore operations)
CREATE POLICY "Users can update their legacy files" ON legacy_files
    FOR UPDATE USING (auth.uid() = uploaded_by OR auth.uid() = archived_by);

-- Policy: Users can soft delete files they uploaded
CREATE POLICY "Users can delete their legacy files" ON legacy_files
    FOR UPDATE USING (auth.uid() = uploaded_by);

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_legacy_files_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER trigger_update_legacy_files_updated_at
    BEFORE UPDATE ON legacy_files
    FOR EACH ROW
    EXECUTE FUNCTION update_legacy_files_updated_at();

-- Function to archive a legacy file
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

-- Function to restore a legacy file from archive
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

-- Function to permanently delete a legacy file
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

-- View for active legacy files only
CREATE VIEW active_legacy_files AS
SELECT * FROM legacy_files WHERE status = 'active';

-- View for archived legacy files only
CREATE VIEW archived_legacy_files AS
SELECT * FROM legacy_files WHERE status = 'archived';

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON legacy_files TO authenticated;
GRANT SELECT ON active_legacy_files TO authenticated;
GRANT SELECT ON archived_legacy_files TO authenticated;
GRANT EXECUTE ON FUNCTION archive_legacy_file(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION restore_legacy_file(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_legacy_file(UUID, UUID) TO authenticated;
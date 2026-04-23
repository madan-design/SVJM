-- Automated Cleanup for Deleted Legacy Folders
-- This script sets up automatic cleanup of marked-for-deletion folders

-- 1. Create the cleanup function
CREATE OR REPLACE FUNCTION cleanup_deleted_folders()
RETURNS TABLE(
  folders_deleted INTEGER,
  files_deleted INTEGER,
  cleanup_timestamp TIMESTAMP
) AS $$
DECLARE
  folder_count INTEGER := 0;
  file_count INTEGER := 0;
BEGIN
  -- Count files to be deleted
  SELECT COUNT(*) INTO file_count
  FROM token_files 
  WHERE legacy_folder_id IN (
    SELECT id FROM legacy_folders 
    WHERE folder_name LIKE '%DELETED_%'
  );
  
  -- Count folders to be deleted
  SELECT COUNT(*) INTO folder_count
  FROM legacy_folders 
  WHERE folder_name LIKE '%DELETED_%';
  
  -- Delete files first (foreign key constraint)
  DELETE FROM token_files 
  WHERE legacy_folder_id IN (
    SELECT id FROM legacy_folders 
    WHERE folder_name LIKE '%DELETED_%'
  );
  
  -- Delete folders
  DELETE FROM legacy_folders 
  WHERE folder_name LIKE '%DELETED_%';
  
  -- Log the cleanup
  INSERT INTO cleanup_logs (folders_deleted, files_deleted, cleanup_timestamp)
  VALUES (folder_count, file_count, NOW());
  
  -- Return results
  RETURN QUERY SELECT folder_count, file_count, NOW()::TIMESTAMP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create cleanup logs table to track automated cleanups
CREATE TABLE IF NOT EXISTS cleanup_logs (
  id SERIAL PRIMARY KEY,
  folders_deleted INTEGER NOT NULL DEFAULT 0,
  files_deleted INTEGER NOT NULL DEFAULT 0,
  cleanup_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- 3. Enable Row Level Security on cleanup_logs
ALTER TABLE cleanup_logs ENABLE ROW LEVEL SECURITY;

-- 4. Create policy for cleanup_logs (admin only)
CREATE POLICY "Admin can view cleanup logs" ON cleanup_logs
  FOR SELECT USING (
    auth.jwt() ->> 'role' = 'admin'
  );

-- 5. Schedule automatic cleanup every day at 2 AM
-- Note: This requires the pg_cron extension to be enabled
-- Contact Supabase support to enable pg_cron on your project

-- Uncomment the line below after enabling pg_cron:
-- SELECT cron.schedule('cleanup-deleted-folders', '0 2 * * *', 'SELECT cleanup_deleted_folders();');

-- 6. Manual cleanup function (for testing)
CREATE OR REPLACE FUNCTION manual_cleanup_deleted_folders()
RETURNS JSON AS $$
DECLARE
  result RECORD;
BEGIN
  SELECT * INTO result FROM cleanup_deleted_folders();
  
  RETURN json_build_object(
    'success', true,
    'folders_deleted', result.folders_deleted,
    'files_deleted', result.files_deleted,
    'cleanup_timestamp', result.cleanup_timestamp
  );
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Grant execute permissions
GRANT EXECUTE ON FUNCTION cleanup_deleted_folders() TO authenticated;
GRANT EXECUTE ON FUNCTION manual_cleanup_deleted_folders() TO authenticated;
-- Complete cleanup script to drop all legacy-related database objects

-- Step 1: Drop views first (they depend on tables)
DROP VIEW IF EXISTS active_legacy_files CASCADE;
DROP VIEW IF EXISTS archived_legacy_files CASCADE;
DROP VIEW IF EXISTS active_legacy_folders CASCADE;
DROP VIEW IF EXISTS archived_legacy_folders CASCADE;

-- Step 2: Drop functions (they reference tables)
DROP FUNCTION IF EXISTS archive_legacy_file(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS restore_legacy_file(UUID) CASCADE;
DROP FUNCTION IF EXISTS delete_legacy_file(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS archive_legacy_folder(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS restore_legacy_folder(UUID) CASCADE;
DROP FUNCTION IF EXISTS delete_legacy_folder(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS update_legacy_updated_at() CASCADE;

-- Step 3: Drop triggers
DROP TRIGGER IF EXISTS trigger_update_legacy_folders_updated_at ON legacy_folders;
DROP TRIGGER IF EXISTS trigger_update_legacy_files_updated_at ON legacy_files;

-- Step 4: Remove the legacy_folder_id column from token_files (if it was added)
ALTER TABLE token_files DROP COLUMN IF EXISTS legacy_folder_id CASCADE;

-- Step 5: Drop tables (legacy_files first due to foreign key dependency)
DROP TABLE IF EXISTS legacy_files CASCADE;
DROP TABLE IF EXISTS legacy_folders CASCADE;

-- Step 6: Reset storage bucket to original state (optional)
-- Uncomment the line below if you want to make the bucket public again
-- UPDATE storage.buckets SET public = true WHERE id = 'project-files';

-- Step 7: Clean up any remaining policies (if they exist)
-- Note: This might fail if the storage policy system is different in your version
-- DELETE FROM storage.policies WHERE bucket_id = 'project-files';

PRINT 'All legacy database objects have been dropped successfully.';
-- Cleanup script to remove existing legacy_files schema
-- Run this BEFORE executing complete_legacy_schema.sql

-- Drop views first (they depend on tables)
DROP VIEW IF EXISTS active_legacy_files CASCADE;
DROP VIEW IF EXISTS archived_legacy_files CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS archive_legacy_file(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS restore_legacy_file(UUID) CASCADE;
DROP FUNCTION IF EXISTS delete_legacy_file(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS update_legacy_files_updated_at() CASCADE;

-- Drop triggers
DROP TRIGGER IF EXISTS trigger_update_legacy_files_updated_at ON legacy_files;

-- Drop table
DROP TABLE IF EXISTS legacy_files CASCADE;

-- Clean up any remaining policies (just in case)
-- Note: Policies are automatically dropped when table is dropped
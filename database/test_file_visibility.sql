-- Test query to check if admin can see MDE uploaded files
-- Run this in Supabase SQL Editor to verify file visibility

-- 1. Check regular token files (MDE uploads to assigned projects)
SELECT 
  tf.file_name,
  tf.uploaded_at,
  t.project_name,
  t.status as token_status,
  p.name as designer_name,
  p.role as designer_role
FROM token_files tf
JOIN tokens t ON tf.token_id = t.id
JOIN profiles p ON t.assigned_to = p.id
WHERE tf.legacy_folder_id IS NULL
ORDER BY tf.uploaded_at DESC
LIMIT 10;

-- 2. Check legacy files (MDE uploads to legacy folders)
SELECT 
  tf.file_name,
  tf.uploaded_at,
  lf.folder_name,
  lf.status as folder_status,
  lf.year,
  lf.month,
  p.name as designer_name,
  p.role as designer_role
FROM token_files tf
JOIN legacy_folders lf ON tf.legacy_folder_id = lf.id
JOIN profiles p ON lf.created_by = p.id
WHERE tf.legacy_folder_id IS NOT NULL
  AND lf.folder_name NOT LIKE '%_DELETED_%'
ORDER BY tf.uploaded_at DESC
LIMIT 10;

-- 3. Check if there are any files at all
SELECT 
  COUNT(*) as total_files,
  COUNT(CASE WHEN legacy_folder_id IS NULL THEN 1 END) as token_files,
  COUNT(CASE WHEN legacy_folder_id IS NOT NULL THEN 1 END) as legacy_files
FROM token_files;

-- 4. Check if there are any tokens assigned to MDEs
SELECT 
  t.project_name,
  t.status,
  p.name as assigned_to,
  p.role,
  t.created_at
FROM tokens t
JOIN profiles p ON t.assigned_to = p.id
WHERE p.role = 'mde'
ORDER BY t.created_at DESC
LIMIT 5;
-- Fix storage bucket RLS policies for project-files bucket

-- First, let's see what policies exist (run this to check current policies)
-- SELECT * FROM storage.policies WHERE bucket_id = 'project-files';

-- Drop existing storage policies for project-files bucket
DELETE FROM storage.policies WHERE bucket_id = 'project-files';

-- Create new storage policies that handle both token files and legacy files
INSERT INTO storage.policies (id, bucket_id, name, definition, check_definition, command)
VALUES 
(
    'project-files-select-policy',
    'project-files',
    'Users can view their uploaded files',
    'auth.uid()::text = (storage.foldername(name))[1] OR auth.uid()::text = (storage.foldername(name))[2]',
    NULL,
    'SELECT'
),
(
    'project-files-insert-policy', 
    'project-files',
    'Users can upload files',
    'auth.uid() IS NOT NULL',
    'auth.uid() IS NOT NULL',
    'INSERT'
),
(
    'project-files-update-policy',
    'project-files', 
    'Users can update their files',
    'auth.uid() IS NOT NULL',
    'auth.uid() IS NOT NULL',
    'UPDATE'
),
(
    'project-files-delete-policy',
    'project-files',
    'Users can delete their files', 
    'auth.uid() IS NOT NULL',
    NULL,
    'DELETE'
);

-- Alternative: If the above doesn't work, try this simpler approach
-- This allows any authenticated user to upload/manage files in project-files bucket

-- DELETE FROM storage.policies WHERE bucket_id = 'project-files';

-- INSERT INTO storage.policies (id, bucket_id, name, definition, check_definition, command)
-- VALUES 
-- (
--     'project-files-all-policy',
--     'project-files',
--     'Authenticated users can manage files',
--     'auth.role() = ''authenticated''',
--     'auth.role() = ''authenticated''',
--     'ALL'
-- );
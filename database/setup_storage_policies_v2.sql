-- Re-enable RLS and set up proper storage policies using Supabase functions

-- Step 1: Re-enable RLS on the bucket
UPDATE storage.buckets SET public = false WHERE id = 'project-files';

-- Step 2: Create storage policies using Supabase policy functions
-- Note: If these functions don't exist, you'll need to set policies via Supabase Dashboard

-- Allow authenticated users to SELECT (view/download) files
SELECT storage.create_policy(
    'project-files-select',
    'project-files',
    'SELECT',
    'auth.role() = ''authenticated''',
    NULL
);

-- Allow authenticated users to INSERT (upload) files
SELECT storage.create_policy(
    'project-files-insert',
    'project-files', 
    'INSERT',
    'auth.role() = ''authenticated''',
    'auth.role() = ''authenticated'''
);

-- Allow authenticated users to UPDATE files
SELECT storage.create_policy(
    'project-files-update',
    'project-files',
    'UPDATE', 
    'auth.role() = ''authenticated''',
    'auth.role() = ''authenticated'''
);

-- Allow authenticated users to DELETE files
SELECT storage.create_policy(
    'project-files-delete',
    'project-files',
    'DELETE',
    'auth.role() = ''authenticated''',
    NULL
);
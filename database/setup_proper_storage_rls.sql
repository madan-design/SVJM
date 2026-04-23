-- Re-enable RLS on project-files bucket with proper policies

-- Step 1: Re-enable RLS on the bucket
UPDATE storage.buckets SET public = false WHERE id = 'project-files';

-- Step 2: Clear any existing policies
DELETE FROM storage.policies WHERE bucket_id = 'project-files';

-- Step 3: Create proper RLS policies for project-files bucket
-- Policy for SELECT (viewing/downloading files)
INSERT INTO storage.policies (bucket_id, name, definition, command)
VALUES (
    'project-files',
    'Authenticated users can view files',
    'auth.role() = ''authenticated''',
    'SELECT'
);

-- Policy for INSERT (uploading files)  
INSERT INTO storage.policies (bucket_id, name, definition, command, check_definition)
VALUES (
    'project-files',
    'Authenticated users can upload files',
    'auth.role() = ''authenticated''',
    'INSERT',
    'auth.role() = ''authenticated'''
);

-- Policy for UPDATE (updating files)
INSERT INTO storage.policies (bucket_id, name, definition, command, check_definition)
VALUES (
    'project-files',
    'Authenticated users can update files',
    'auth.role() = ''authenticated''',
    'UPDATE', 
    'auth.role() = ''authenticated'''
);

-- Policy for DELETE (deleting files)
INSERT INTO storage.policies (bucket_id, name, definition, command)
VALUES (
    'project-files',
    'Authenticated users can delete files',
    'auth.role() = ''authenticated''',
    'DELETE'
);
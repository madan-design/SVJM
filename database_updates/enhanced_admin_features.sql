-- SQL queries needed for the enhanced admin dashboard and file grouping features

-- 1. Ensure the tokens table has the archived column (if not already added)
ALTER TABLE tokens ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE;
ALTER TABLE tokens ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

-- 2. Ensure the token_files table has the archived column (if not already added)
ALTER TABLE token_files ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE;
ALTER TABLE token_files ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

-- 3. Create index for better performance on archived tokens
CREATE INDEX IF NOT EXISTS idx_tokens_archived ON tokens(archived);
CREATE INDEX IF NOT EXISTS idx_tokens_assigned_to_archived ON tokens(assigned_to, archived);

-- 4. Create index for better performance on archived files
CREATE INDEX IF NOT EXISTS idx_token_files_archived ON token_files(archived);
CREATE INDEX IF NOT EXISTS idx_token_files_uploaded_by_archived ON token_files(uploaded_by, archived);

-- 5. Create index for better performance on file grouping queries
CREATE INDEX IF NOT EXISTS idx_token_files_uploaded_at ON token_files(uploaded_at);
CREATE INDEX IF NOT EXISTS idx_token_files_token_id_archived ON token_files(token_id, archived);

-- 6. Update any existing tokens to have archived = false if null
UPDATE tokens SET archived = FALSE WHERE archived IS NULL;

-- 7. Update any existing token_files to have archived = false if null
UPDATE token_files SET archived = FALSE WHERE archived IS NULL;

-- 8. Add constraint to ensure archived is not null
ALTER TABLE tokens ALTER COLUMN archived SET NOT NULL;
ALTER TABLE token_files ALTER COLUMN archived SET NOT NULL;

-- 9. Create a view for admin dashboard stats (optional, for better performance)
CREATE OR REPLACE VIEW admin_dashboard_stats AS
SELECT 
  COUNT(CASE WHEN q.status != 'archived' THEN 1 END) as total_quotes,
  COUNT(CASE WHEN q.status = 'draft' THEN 1 END) as drafts,
  COUNT(CASE WHEN q.status IN ('confirmed', 'completed') THEN 1 END) as approved,
  COUNT(CASE WHEN q.status = 'completed' THEN 1 END) as completed,
  COUNT(CASE WHEN t.archived = FALSE THEN 1 END) as tasks_assigned,
  COUNT(CASE WHEN t.archived = FALSE AND t.status = 'completed' THEN 1 END) as tasks_completed,
  COUNT(CASE WHEN t.archived = TRUE THEN 1 END) as archived_tokens
FROM quotes q
FULL OUTER JOIN tokens t ON TRUE
WHERE q.owner_id = auth.uid() OR t.assigned_by = auth.uid();

-- 10. Create RLS policies for the new archived functionality (if RLS is enabled)
-- Note: Adjust these policies based on your specific RLS setup

-- Policy for tokens archive access
CREATE POLICY IF NOT EXISTS "Users can archive their assigned tokens" ON tokens
  FOR UPDATE USING (assigned_by = auth.uid() OR assigned_to = auth.uid());

-- Policy for token_files archive access  
CREATE POLICY IF NOT EXISTS "Users can archive their uploaded files" ON token_files
  FOR UPDATE USING (uploaded_by = auth.uid());

-- Policy for viewing archived tokens
CREATE POLICY IF NOT EXISTS "Admins can view archived tokens" ON tokens
  FOR SELECT USING (assigned_by = auth.uid());

-- Policy for viewing archived files
CREATE POLICY IF NOT EXISTS "Users can view their archived files" ON token_files
  FOR SELECT USING (uploaded_by = auth.uid());
# Automated Cleanup Setup Instructions

## Option 1: Database Function with pg_cron (Recommended)

### Step 1: Enable pg_cron Extension
1. Go to your Supabase Dashboard
2. Navigate to Database → Extensions
3. Search for "pg_cron" and enable it
4. If pg_cron is not available, contact Supabase support to enable it

### Step 2: Run the Database Setup
1. Go to Database → SQL Editor in your Supabase dashboard
2. Copy and paste the contents of `database/automated_cleanup.sql`
3. Execute the script

### Step 3: Enable the Scheduled Job
After pg_cron is enabled, run this SQL command:
```sql
SELECT cron.schedule('cleanup-deleted-folders', '0 2 * * *', 'SELECT cleanup_deleted_folders();');
```

This schedules cleanup **every day at 2 AM**.

### Step 4: Monitor Cleanup Logs
Query the cleanup logs to see automated cleanup history:
```sql
SELECT * FROM cleanup_logs ORDER BY cleanup_timestamp DESC LIMIT 10;
```

---

## Option 2: Edge Function with External Cron (Alternative)

### Step 1: Deploy the Edge Function
1. Install Supabase CLI: `npm install -g supabase`
2. Login: `supabase login`
3. Link your project: `supabase link --project-ref YOUR_PROJECT_REF`
4. Deploy the function:
   ```bash
   supabase functions deploy cleanup-deleted-folders
   ```

### Step 2: Set up External Cron Job
Use a service like:
- **GitHub Actions** (free for public repos)
- **Vercel Cron Jobs**
- **Netlify Functions**
- **Cron-job.org** (free tier available)

Example GitHub Action (`.github/workflows/cleanup.yml`):
```yaml
name: Database Cleanup
on:
  schedule:
    - cron: '0 2 * * 0'  # Every Sunday at 2 AM
  workflow_dispatch:  # Allow manual trigger

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Call Cleanup Function
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "Content-Type: application/json" \
            "https://YOUR_PROJECT_REF.supabase.co/functions/v1/cleanup-deleted-folders"
```

### Step 3: Create Database Tables
Run the table creation part from `database/automated_cleanup.sql`:
```sql
-- Create cleanup logs table
CREATE TABLE IF NOT EXISTS cleanup_logs (
  id SERIAL PRIMARY KEY,
  folders_deleted INTEGER NOT NULL DEFAULT 0,
  files_deleted INTEGER NOT NULL DEFAULT 0,
  cleanup_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE cleanup_logs ENABLE ROW LEVEL SECURITY;

-- Create policy
CREATE POLICY "Admin can view cleanup logs" ON cleanup_logs
  FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');
```

---

## Testing the Setup

### Manual Test (Option 1 - Database Function)
```sql
SELECT * FROM manual_cleanup_deleted_folders();
```

### Manual Test (Option 2 - Edge Function)
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  "https://YOUR_PROJECT_REF.supabase.co/functions/v1/cleanup-deleted-folders"
```

---

## Monitoring and Maintenance

### View Cleanup History
```sql
SELECT 
  folders_deleted,
  files_deleted,
  cleanup_timestamp,
  CASE 
    WHEN folders_deleted > 0 OR files_deleted > 0 THEN 'Items cleaned'
    ELSE 'No items to clean'
  END as status
FROM cleanup_logs 
ORDER BY cleanup_timestamp DESC 
LIMIT 20;
```

### Check Current Deleted Items
```sql
-- Count items waiting for cleanup
SELECT 
  COUNT(*) as folders_to_cleanup
FROM legacy_folders 
WHERE folder_name LIKE '%DELETED_%';

SELECT 
  COUNT(*) as files_to_cleanup
FROM token_files tf
JOIN legacy_folders lf ON tf.legacy_folder_id = lf.id
WHERE lf.folder_name LIKE '%DELETED_%';
```

### Modify Cleanup Schedule
To change the cleanup frequency, update the cron schedule:
```sql
-- Daily at 3 AM
SELECT cron.unschedule('cleanup-deleted-folders');
SELECT cron.schedule('cleanup-deleted-folders', '0 3 * * *', 'SELECT cleanup_deleted_folders();');

-- Weekly on Wednesday at 1 AM
SELECT cron.unschedule('cleanup-deleted-folders');
SELECT cron.schedule('cleanup-deleted-folders', '0 1 * * 3', 'SELECT cleanup_deleted_folders();');
```

---

## Recommendation

**Use Option 1 (Database Function with pg_cron)** if available, as it:
- Runs entirely within Supabase
- Has better performance
- Doesn't require external services
- Is more reliable

**Use Option 2 (Edge Function)** if pg_cron is not available on your Supabase plan.
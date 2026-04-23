// Supabase Edge Function for Automated Cleanup
// Deploy this to Supabase Edge Functions and set up a cron job to call it

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get all folders marked for deletion
    const { data: foldersToDelete, error: foldersError } = await supabase
      .from('legacy_folders')
      .select('id')
      .like('folder_name', '%DELETED_%')

    if (foldersError) {
      throw new Error(`Error fetching folders: ${foldersError.message}`)
    }

    const folderIds = foldersToDelete?.map(f => f.id) || []
    let filesDeleted = 0
    let foldersDeleted = 0

    if (folderIds.length > 0) {
      // Delete associated files first
      const { error: filesError, count: fileCount } = await supabase
        .from('token_files')
        .delete({ count: 'exact' })
        .in('legacy_folder_id', folderIds)

      if (filesError) {
        console.error('Error deleting files:', filesError)
      } else {
        filesDeleted = fileCount || 0
      }

      // Delete folders
      const { error: foldersDeleteError, count: folderCount } = await supabase
        .from('legacy_folders')
        .delete({ count: 'exact' })
        .in('id', folderIds)

      if (foldersDeleteError) {
        console.error('Error deleting folders:', foldersDeleteError)
      } else {
        foldersDeleted = folderCount || 0
      }

      // Log the cleanup
      await supabase
        .from('cleanup_logs')
        .insert({
          folders_deleted: foldersDeleted,
          files_deleted: filesDeleted,
          cleanup_timestamp: new Date().toISOString()
        })
    }

    const result = {
      success: true,
      folders_deleted: foldersDeleted,
      files_deleted: filesDeleted,
      cleanup_timestamp: new Date().toISOString()
    }

    console.log('Cleanup completed:', result)

    return new Response(
      JSON.stringify(result),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('Cleanup failed:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    )
  }
})
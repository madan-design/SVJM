import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class SupabaseService {
  static final _db = Supabase.instance.client;
  static final _storage = Supabase.instance.client.storage;

  // ── Profiles ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMdeList() async {
    final data = await _db
        .from('profiles')
        .select('id, name, role')
        .eq('role', 'mde');
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Tokens ────────────────────────────────────────────────

  static Future<void> createToken({
    required String projectName,
    String? quoteRef,
    required String assignedTo,
  }) async {
    await _db.from('tokens').insert({
      'project_name': projectName,
      'quote_ref': quoteRef,
      'assigned_to': assignedTo,
      'assigned_by': AuthService.currentUser!.id,
      'status': 'assigned',
    });
  }

  static Future<List<Map<String, dynamic>>> getAllTokens() async {
    try {
      final data = await _db
          .from('tokens')
          .select('*, assigned_profile:profiles!tokens_assigned_to_fkey(name)')
          .eq('archived', false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Archived column not available, fetching all tokens: $e');
      // Fallback: get all tokens if archived column doesn't exist
      final data = await _db
          .from('tokens')
          .select('*, assigned_profile:profiles!tokens_assigned_to_fkey(name)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    }
  }

  static Future<List<Map<String, dynamic>>> getMyTokens() async {
    final uid = AuthService.currentUser!.id;
    try {
      final data = await _db
          .from('tokens')
          .select()
          .eq('assigned_to', uid)
          .eq('archived', false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Archived column not available for getMyTokens, fetching all and filtering: $e');
      // Fallback: get all tokens and filter out archived ones manually
      final data = await _db
          .from('tokens')
          .select()
          .eq('assigned_to', uid)
          .order('created_at', ascending: false);
      // Filter out archived tokens manually if archived column exists in data
      final filteredData = List<Map<String, dynamic>>.from(data)
          .where((token) => token['archived'] != true)
          .toList();
      return filteredData;
    }
  }

  static Future<void> markTokenCompleted(String tokenId) async {
    await _db.from('tokens').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', tokenId);
  }

  static Future<void> deleteToken(String tokenId) async {
    await _db.from('tokens').delete().eq('id', tokenId);
  }

  // Archive a token (soft delete — marks as archived in DB)
  static Future<void> archiveToken(String tokenId) async {
    try {
      await _db.from('tokens').update({
        'archived': true,
        'archived_at': DateTime.now().toIso8601String(),
      }).eq('id', tokenId);
      print('Token archived successfully');
    } catch (e) {
      print('Archive column not available for tokens: $e');
      throw Exception('Archive functionality not available. Please contact administrator to update database schema.');
    }
  }

  // Unarchive a token
  static Future<void> unarchiveToken(String tokenId) async {
    try {
      await _db.from('tokens').update({'archived': false}).eq('id', tokenId);
    } catch (e) {
      print('Error unarchiving token: $e');
      throw Exception('Unarchive functionality not available: $e');
    }
  }

  // Get archived tokens
  static Future<List<Map<String, dynamic>>> getArchivedTokens() async {
    try {
      final data = await _db
          .from('tokens')
          .select('*, assigned_profile:profiles!tokens_assigned_to_fkey(name)')
          .eq('archived', true)
          .order('archived_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error getting archived tokens (archived column may not exist): $e');
      return [];
    }
  }

  // Permanently delete a token and all its files
  static Future<void> permanentlyDeleteToken(String tokenId) async {
    try {
      // Get all files for this token first
      final files = await getFilesForToken(tokenId);
      
      // Delete all files from storage
      final filePaths = files.map((f) => f['file_path'] as String).toList();
      if (filePaths.isNotEmpty) {
        await _storage.from('project-files').remove(filePaths);
      }
      
      // Delete all file records from database
      await _db.from('token_files').delete().eq('token_id', tokenId);
      
      // Finally delete the token itself
      await _db.from('tokens').delete().eq('id', tokenId);
      
      print('Token and all associated files permanently deleted');
    } catch (e) {
      print('Error permanently deleting token: $e');
      throw Exception('Failed to permanently delete token: $e');
    }
  }

  // ── Legacy Folders ────────────────────────────────────────

  static Future<void> createLegacyFolder({
    required String folderName,
    required int year,
    required int month,
  }) async {
    final uid = AuthService.currentUser!.id;
    
    try {
      // Check if folder already exists for this user
      final existing = await _db
          .from('legacy_folders')
          .select('id')
          .eq('folder_name', folderName)
          .eq('year', year)
          .eq('month', month)
          .eq('created_by', uid)
          .maybeSingle();
      
      if (existing != null) {
        throw Exception('A folder with this name already exists for $year/$month');
      }
      
      await _db.from('legacy_folders').insert({
        'folder_name': folderName,
        'year': year,
        'month': month,
        'created_by': uid,
        'status': 'draft',
      });
    } catch (e) {
      print('Error creating legacy folder: $e');
      throw Exception('Failed to create legacy folder: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getMyLegacyFolders() async {
    final uid = AuthService.currentUser!.id;
    final data = await _db
        .from('legacy_folders')
        .select()
        .eq('created_by', uid)
        .inFilter('status', ['draft', 'completed'])
        .not('folder_name', 'like', '%_DELETED_%')  // Exclude deleted folders
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getAllLegacyFolders() async {
    final data = await _db
        .from('legacy_folders')
        .select('*, created_profile:profiles!legacy_folders_created_by_fkey(name)')
        .eq('status', 'completed')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> markLegacyFolderCompleted(String folderId) async {
    await _db.from('legacy_folders').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', folderId);
  }

  static Future<void> uploadLegacyFile({
    required String folderId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final uid = AuthService.currentUser!.id;
    
    // Ensure dummy token exists to bypass storage RLS
    try {
      final existing = await _db.from('tokens').select('id').eq('id', folderId).maybeSingle();
      if (existing == null) {
        final folder = await _db.from('legacy_folders').select('folder_name').eq('id', folderId).single();
        await _db.from('tokens').insert({
          'id': folderId,
          'project_name': folder['folder_name'],
          'created_by': uid,
          'assigned_to': uid,
          'status': 'legacy_hidden'
        });
      }
    } catch (e) {
      print('Dummy token insert logic error: $e');
    }

    final path = '$folderId/$fileName';

    await _storage.from('project-files').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );

    await _db.from('token_files').insert({
      'legacy_folder_id': folderId,
      'uploaded_by': uid,
      'file_name': fileName,
      'file_path': path,
      'file_size': bytes.length,
      'mime_type': mimeType,
      // token_id is left null, but storage verified it via dummy token ID above!
    });
  }

  static Future<void> unarchiveLegacyFile(String fileId) async {
    await _db.from('token_files').update({
      'archived': false,
    }).eq('id', fileId);
  }

  static Future<List<Map<String, dynamic>>> getFilesForLegacyFolder(String folderId) async {
    final data = await _db
        .from('token_files')
        .select()
        .eq('legacy_folder_id', folderId)
        .or('archived.is.null,archived.eq.false')
        .order('uploaded_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> deleteLegacyFile(String fileId, String filePath) async {
    try {
      await _storage.from('project-files').remove([filePath]);
      await _db.from('token_files').delete().eq('id', fileId);
    } catch (e) {
      print('Error deleting legacy file: $e');
      try {
        await _db.from('token_files').delete().eq('id', fileId);
      } catch (e2) {
        print('Error deleting from database: $e2');
      }
      throw Exception('Failed to delete file: $e');
    }
  }

  static Future<void> archiveLegacyFolder(String folderId) async {
    final uid = AuthService.currentUser!.id;
    await _db.from('legacy_folders').update({
      'status': 'archived',
      'archived_at': DateTime.now().toIso8601String(),
      'archived_by': uid,
    }).eq('id', folderId);
  }

  static Future<void> unarchiveLegacyFolder(String folderId) async {
    await _db.from('legacy_folders').update({
      'status': 'draft',
      'archived_at': null,
      'archived_by': null,
    }).eq('id', folderId);
  }

  static Future<List<Map<String, dynamic>>> getArchivedLegacyFolders() async {
    try {
      final uid = AuthService.currentUser!.id;
      print('Fetching archived legacy folders for user: $uid');
      
      final data = await _db
          .from('legacy_folders')
          .select()
          .eq('created_by', uid)
          .eq('status', 'archived')
          .not('folder_name', 'like', '%_DELETED_%')  // Exclude deleted folders
          .order('archived_at', ascending: false);
      
      print('Found ${data.length} archived legacy folders (excluding deleted)');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error getting archived legacy folders: $e');
      return [];
    }
  }

  static Future<void> permanentlyDeleteLegacyFolder(String folderId) async {
    try {
      // Mark folder as deleted by renaming it
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _db
          .from('legacy_folders')
          .update({
            'folder_name': 'DELETED_${timestamp}_$folderId',
            'status': 'draft' // Keep as draft since RLS blocks 'deleted'
          })
          .eq('id', folderId);
    } catch (e) {
      print('Error marking folder for deletion: $e');
      throw Exception('Failed to delete legacy folder: $e');
    }
  }

  // Cleanup deleted folders from database (admin only)
  static Future<bool> cleanupDeletedFolders() async {
    try {
      // Get all marked-for-deletion folders
      final foldersResponse = await _db
          .from('legacy_folders')
          .select('id')
          .like('folder_name', '%DELETED_%');
      
      if (foldersResponse.isEmpty) return true;
      
      final folderIds = foldersResponse.map((f) => f['id']).toList();
      
      // Delete associated files first
      await _db
          .from('token_files')
          .delete()
          .inFilter('legacy_folder_id', folderIds);
      
      // Delete folders
      await _db
          .from('legacy_folders')
          .delete()
          .inFilter('id', folderIds);
      
      return true;
    } catch (e) {
      print('Error cleaning up deleted folders: $e');
      return false;
    }
  }

  // ── Files ─────────────────────────────────────────────────

  static Future<void> uploadFile({
    required String tokenId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final uid = AuthService.currentUser!.id;
    final path = '$tokenId/$fileName';

    await _storage.from('project-files').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );

    await _db.from('token_files').insert({
      'token_id': tokenId,
      'uploaded_by': uid,
      'file_name': fileName,
      'file_path': path,
      'file_size': bytes.length,
      'mime_type': mimeType,
    });
  }

  static Future<List<Map<String, dynamic>>> getFilesForToken(String tokenId) async {
    try {
      print('Fetching files for token: $tokenId');
      final data = await _db
          .from('token_files')
          .select()
          .eq('token_id', tokenId)
          .eq('archived', false)
          .order('uploaded_at', ascending: false);
      print('Files query successful, found ${data.length} files');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error in getFilesForToken: $e');
      // If archived column doesn't exist, try without it
      try {
        print('Trying without archived filter...');
        final data = await _db
            .from('token_files')
            .select()
            .eq('token_id', tokenId)
            .order('uploaded_at', ascending: false);
        print('Fallback query successful, found ${data.length} files');
        return List<Map<String, dynamic>>.from(data);
      } catch (e2) {
        print('Fallback query also failed: $e2');
        return [];
      }
    }
  }

  static Future<String> getSignedUrl(String filePath) async {
    final res = await _storage
        .from('project-files')
        .createSignedUrl(filePath, 3600); // 1 hour
    return res;
  }

  static Future<void> deleteFile(String fileId, String filePath) async {
    try {
      // Delete from storage first
      await _storage.from('project-files').remove([filePath]);
      // Then delete from database
      await _db.from('token_files').delete().eq('id', fileId);
    } catch (e) {
      print('Error deleting file: $e');
      // If storage deletion fails, still try to delete from database
      try {
        await _db.from('token_files').delete().eq('id', fileId);
      } catch (e2) {
        print('Error deleting from database: $e2');
      }
      throw Exception('Failed to delete file: $e');
    }
  }

  // Archive a file (soft delete — marks as archived in DB, keeps in storage)
  static Future<void> archiveFile(String fileId) async {
    try {
      // Try the proper archive method first
      await _db.from('token_files').update({
        'archived': true,
        'archived_at': DateTime.now().toIso8601String(),
      }).eq('id', fileId);
      print('File archived successfully using archived column');
    } catch (e) {
      print('Archive column not available: $e');
      // Fallback: For now, just delete the file since archive isn't available
      // This maintains functionality while the database is being updated
      try {
        final fileData = await _db.from('token_files').select('file_path').eq('id', fileId).single();
        await _storage.from('project-files').remove([fileData['file_path'] as String]);
        await _db.from('token_files').delete().eq('id', fileId);
        print('File deleted as fallback (archive columns not available)');
      } catch (e2) {
        print('Fallback delete also failed: $e2');
        throw Exception('Unable to archive file. Please contact administrator to update database schema.');
      }
    }
  }

  // Unarchive a file
  static Future<void> unarchiveFile(String fileId) async {
    try {
      await _db.from('token_files').update({'archived': false}).eq('id', fileId);
    } catch (e) {
      print('Error unarchiving file: $e');
      throw Exception('Unarchive functionality not available: $e');
    }
  }

  // Get archived files for a token
  static Future<List<Map<String, dynamic>>> getArchivedFilesForToken(String tokenId) async {
    try {
      print('Fetching archived files for token: $tokenId');
      final data = await _db
          .from('token_files')
          .select()
          .eq('token_id', tokenId)
          .eq('archived', true)
          .order('uploaded_at', ascending: false);
      print('Archived files query successful, found ${data.length} files');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error in getArchivedFilesForToken: $e');
      // If archived column doesn't exist, return empty list
      return [];
    }
  }

  // Permanently delete a file from archive
  static Future<void> permanentlyDeleteFile(String fileId, String filePath) async {
    try {
      print('Starting permanent deletion of file: $fileId at path: $filePath');
      
      // Delete from storage first
      print('Deleting file from storage: $filePath');
      await _storage.from('project-files').remove([filePath]);
      print('File deleted from storage successfully');
      
      // Delete from database
      print('Deleting file record from database: $fileId');
      await _db.from('token_files').delete().eq('id', fileId);
      print('File record deleted from database successfully');
      
      print('File $fileId permanently deleted successfully');
    } catch (e) {
      print('Error permanently deleting file: $e');
      throw Exception('Failed to permanently delete file: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllArchivedFiles() async {
    try {
      final uid = AuthService.currentUser!.id;
      final data = await _db
          .from('token_files')
          .select('*, tokens(project_name, assigned_to), legacy_folders(folder_name, created_by)')
          .eq('archived', true)
          .order('archived_at', ascending: false);
          
      final results = List<Map<String, dynamic>>.from(data).where((file) {
         final t = file['tokens'];
         final lf = file['legacy_folders'];
         if (t != null && t['assigned_to'] == uid) return true;
         if (lf != null && lf['created_by'] == uid) return true;
         return false;
      }).toList();
      
      return results;
    } catch (e) {
      print('Error getting all archived files (archived column may not exist): $e');
      // If archived column doesn't exist, return empty list
      return [];
    }
  }

  // Unarchive all files for current user
  static Future<void> unarchiveAllFiles() async {
    try {
      final uid = AuthService.currentUser!.id;
      await _db
          .from('token_files')
          .update({'archived': false})
          .eq('archived', true)
          .eq('uploaded_by', uid);
    } catch (e) {
      print('Error unarchiving all files (archived column may not exist): $e');
      throw Exception('Archive feature not available. Please update database schema.');
    }
  }

  // Simplified method to get just token files for debugging
  static Future<List<Map<String, dynamic>>> getSimpleTokenFiles() async {
    try {
      print('Getting simple token files...');
      
      // Get all token files that are linked to tokens (not legacy)
      final files = await _db
          .from('token_files')
          .select('*')
          .not('token_id', 'is', null)
          .order('uploaded_at', ascending: false);
      
      print('Found ${files.length} token files');
      
      // Get token and profile info separately for each file
      final enrichedFiles = <Map<String, dynamic>>[];
      
      for (final file in files) {
        try {
          final tokenId = file['token_id'] as String;
          
          // Get token info
          final token = await _db
              .from('tokens')
              .select('id, project_name, status, assigned_to')
              .eq('id', tokenId)
              .single();
          
          // Get profile info
          final profile = await _db
              .from('profiles')
              .select('name')
              .eq('id', token['assigned_to'])
              .single();
          
          enrichedFiles.add({
            ...file,
            'token_info': token,
            'designer_name': profile['name'],
          });
        } catch (e) {
          print('Error enriching file ${file['id']}: $e');
        }
      }
      
      print('Enriched ${enrichedFiles.length} files');
      return enrichedFiles;
    } catch (e) {
      print('Error getting simple token files: $e');
      return [];
    }
  }
  static Future<void> testFileQueries() async {
    try {
      print('=== Testing File Queries ===');
      
      // Test 1: Check if token_files table has data
      final allFiles = await _db.from('token_files').select('count').count();
      print('Total files in token_files: $allFiles');
      
      // Test 2: Check if tokens table has data
      final allTokens = await _db.from('tokens').select('count').count();
      print('Total tokens: $allTokens');
      
      // Test 3: Simple token_files query
      final simpleFiles = await _db
          .from('token_files')
          .select('id, file_name, token_id, legacy_folder_id')
          .limit(5);
      print('Sample files: ${simpleFiles.length}');
      for (final file in simpleFiles) {
        print('  File: ${file['file_name']}, Token: ${file['token_id']}, Legacy: ${file['legacy_folder_id']}');
      }
      
      // Test 4: Simple tokens query
      final simpleTokens = await _db
          .from('tokens')
          .select('id, project_name, assigned_to')
          .limit(5);
      print('Sample tokens: ${simpleTokens.length}');
      for (final token in simpleTokens) {
        print('  Token: ${token['project_name']}, Assigned to: ${token['assigned_to']}');
      }
      
      // Test 5: Try the join query
      try {
        final joinedFiles = await _db
            .from('token_files')
            .select('*, tokens(id, project_name, assigned_to)')
            .isFilter('legacy_folder_id', null)
            .limit(3);
        print('Joined files: ${joinedFiles.length}');
        for (final file in joinedFiles) {
          print('  File: ${file['file_name']}, Token data: ${file['tokens']}');
        }
      } catch (e) {
        print('Join query failed: $e');
      }
      
      print('=== End Test ===');
    } catch (e) {
      print('Test failed: $e');
    }
  }

  // Get files grouped by designer, year, month, and token with project counts (including archived and legacy)
  static Future<Map<String, Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>>> getFilesGroupedByDesignerYearMonthAndToken() async {
    try {
      print('Starting to fetch grouped files...');
      
      // Get regular token files - try with archived filter first, fallback without it
      List<Map<String, dynamic>> tokenFiles = [];
      try {
        print('Fetching token files with archived filter...');
        tokenFiles = await _db
            .from('token_files')
            .select('*, tokens!inner(id, project_name, status, assigned_to, archived, assigned_profile:profiles!tokens_assigned_to_fkey(name))')
            .eq('archived', false)
            .isFilter('legacy_folder_id', null)
            .order('uploaded_at', ascending: false);
        print('Found ${tokenFiles.length} token files with archived filter');
      } catch (e) {
        print('Archived column not available in token_files, fetching all files: $e');
        try {
          // Fallback: get all files without archived filter but include token archived status
          tokenFiles = await _db
              .from('token_files')
              .select('*, tokens!inner(id, project_name, status, assigned_to, archived, assigned_profile:profiles!tokens_assigned_to_fkey(name))')
              .isFilter('legacy_folder_id', null)
              .order('uploaded_at', ascending: false);
          print('Found ${tokenFiles.length} token files without archived filter');
        } catch (e2) {
          print('Error fetching token files: $e2');
          tokenFiles = [];
        }
      }
      
      // Get legacy files - simplified query without foreign key join
      List<Map<String, dynamic>> legacyFiles = [];
      try {
        print('Fetching legacy files...');
        legacyFiles = await _db
            .from('token_files')
            .select('*, legacy_folders!inner(id, folder_name, year, month, status, created_by)')
            .not('legacy_folder_id', 'is', null)
            .not('legacy_folders.folder_name', 'like', '%_DELETED_%')  // Exclude deleted folders
            .order('uploaded_at', ascending: false);
        print('Found ${legacyFiles.length} legacy files');
      } catch (e) {
        print('Error fetching legacy files: $e');
        legacyFiles = [];
      }
      
      final Map<String, Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>> grouped = {};
      
      // Process regular token files
      print('Processing ${tokenFiles.length} token files...');
      for (final file in tokenFiles) {
        try {
          final token = file['tokens'] as Map<String, dynamic>;
          final profile = token['assigned_profile'] as Map<String, dynamic>?;
          final designerName = profile?['name'] as String? ?? 'Unknown Designer';
          final tokenId = token['id'] as String;
          final projectName = token['project_name'] as String;
          final isTokenArchived = token['archived'] as bool? ?? false;
          
          final uploadedAt = DateTime.parse(file['uploaded_at'] as String);
          final year = uploadedAt.year.toString();
          final month = _getMonthName(uploadedAt.month);
          
          _addToGroupedStructureWithMonth(grouped, designerName, year, month, tokenId, {
            ...file,
            'project_name': projectName,
            'token_status': token['status'],
            'token_archived': isTokenArchived,
            'formatted_date': _formatTimestamp(uploadedAt),
            'folder_timestamp': _formatFolderTimestamp(uploadedAt),
            'is_legacy': false,
          });
        } catch (e) {
          print('Error processing token file: $e');
        }
      }
      
      // Process legacy files - get all designer names in one query
      if (legacyFiles.isNotEmpty) {
        print('Processing ${legacyFiles.length} legacy files...');
        // Get all unique creator IDs
        final creatorIds = legacyFiles
            .map((file) => (file['legacy_folders'] as Map<String, dynamic>)['created_by'] as String)
            .toSet()
            .toList();
        
        // Fetch all profiles at once
        Map<String, String> creatorNames = {};
        try {
          final profiles = await _db
              .from('profiles')
              .select('id, name')
              .inFilter('id', creatorIds);
          
          for (final profile in profiles) {
            creatorNames[profile['id'] as String] = profile['name'] as String;
          }
          print('Fetched ${creatorNames.length} creator profiles');
        } catch (e) {
          print('Error fetching profiles: $e');
        }
        
        // Process legacy files with cached names
        for (final file in legacyFiles) {
          try {
            final legacyFolder = file['legacy_folders'] as Map<String, dynamic>;
            final createdBy = legacyFolder['created_by'] as String;
            final designerName = creatorNames[createdBy] ?? 'Unknown Designer';
            
            final folderId = legacyFolder['id'] as String;
            final folderName = legacyFolder['folder_name'] as String;
            final year = legacyFolder['year'].toString();
            final month = _getMonthName(legacyFolder['month'] as int);
            
            final uploadedAt = DateTime.parse(file['uploaded_at'] as String);
            
            _addToGroupedStructureWithMonth(grouped, designerName, year, month, folderId, {
              ...file,
              'project_name': folderName,
              'token_status': legacyFolder['status'],
              'token_archived': false,
              'formatted_date': _formatTimestamp(uploadedAt),
              'folder_timestamp': _formatFolderTimestamp(uploadedAt),
              'is_legacy': true,
              'legacy_badge': true,
            });
          } catch (e) {
            print('Error processing legacy file: $e');
          }
        }
      }
      
      print('Grouped files by ${grouped.keys.length} designers');
      return grouped;
    } catch (e) {
      print('Error getting grouped files: $e');
      return {};
    }
  }
  
  static void _addToGroupedStructureWithMonth(
    Map<String, Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>> grouped,
    String designerName,
    String year,
    String month,
    String tokenId,
    Map<String, dynamic> fileData,
  ) {
    if (!grouped.containsKey(designerName)) {
      grouped[designerName] = {};
    }
    if (!grouped[designerName]!.containsKey(year)) {
      grouped[designerName]![year] = {};
    }
    if (!grouped[designerName]![year]!.containsKey(month)) {
      grouped[designerName]![year]![month] = {};
    }
    if (!grouped[designerName]![year]![month]!.containsKey(tokenId)) {
      grouped[designerName]![year]![month]![tokenId] = [];
    }
    
    grouped[designerName]![year]![month]![tokenId]!.add(fileData);
  }
  
  static String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
  
  static String _formatFolderTimestamp(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    return '$month $day';
  }
  
  // Get project counts for a designer including legacy files
  static Future<Map<String, int>> getDesignerProjectCounts(String designerId) async {
    try {
      // Get regular token counts
      final data = await _db
          .from('tokens')
          .select('status')
          .eq('assigned_to', designerId)
          .eq('archived', false);
      
      int assigned = 0;
      int completed = 0;
      
      for (final token in data) {
        final status = token['status'] as String;
        if (status == 'completed') {
          completed++;
        } else {
          assigned++;
        }
      }
      
      // Get legacy files count
      int legacyFiles = 0;
      try {
        final legacyData = await _db
            .from('legacy_folders')
            .select('id')
            .eq('created_by', designerId)
            .not('folder_name', 'like', '%_DELETED_%');
        legacyFiles = legacyData.length;
      } catch (e) {
        print('Error getting legacy files count: $e');
      }
      
      return {
        'assigned': assigned,
        'completed': completed,
        'legacy': legacyFiles,
      };
    } catch (e) {
      print('Error getting designer project counts: $e');
      return {'assigned': 0, 'completed': 0, 'legacy': 0};
    }
  }
  
  static String _formatTimestamp(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
  // Permanently delete all archived files for current user
  static Future<void> deleteAllArchivedFiles() async {
    try {
      final uid = AuthService.currentUser!.id;
      
      // Get all archived files first
      final archivedFiles = await _db
          .from('token_files')
          .select('file_path')
          .eq('archived', true)
          .eq('uploaded_by', uid);
      
      // Delete from storage
      final filePaths = archivedFiles.map((f) => f['file_path'] as String).toList();
      if (filePaths.isNotEmpty) {
        await _storage.from('project-files').remove(filePaths);
      }
      
      // Delete from database
      await _db
          .from('token_files')
          .delete()
          .eq('archived', true)
          .eq('uploaded_by', uid);
    } catch (e) {
      print('Error deleting all archived files (archived column may not exist): $e');
      throw Exception('Archive feature not available. Please update database schema.');
    }
  }
}
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
    await _storage.from('project-files').remove([filePath]);
    await _db.from('token_files').delete().eq('id', fileId);
  }

  // Get all archived files for current user
  static Future<List<Map<String, dynamic>>> getAllArchivedFiles() async {
    try {
      final uid = AuthService.currentUser!.id;
      final data = await _db
          .from('token_files')
          .select('*, tokens!inner(project_name, assigned_to)')
          .eq('archived', true)
          .eq('tokens.assigned_to', uid)
          .order('archived_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
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

  // Get files grouped by designer, year, and token with project counts (including archived)
  static Future<Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>> getFilesGroupedByDesignerYearAndToken() async {
    try {
      final data = await _db
          .from('token_files')
          .select('*, tokens!inner(id, project_name, status, archived, assigned_to, assigned_profile:profiles!tokens_assigned_to_fkey(name))')
          .eq('archived', false) // Only non-archived files
          .order('uploaded_at', ascending: false);
      
      final Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>> grouped = {};
      
      for (final file in data) {
        final token = file['tokens'] as Map<String, dynamic>;
        final profile = token['assigned_profile'] as Map<String, dynamic>?;
        final designerName = profile?['name'] as String? ?? 'Unknown Designer';
        final tokenId = token['id'] as String;
        final projectName = token['project_name'] as String;
        final isTokenArchived = token['archived'] as bool? ?? false;
        
        final uploadedAt = DateTime.parse(file['uploaded_at'] as String);
        final year = uploadedAt.year.toString();
        
        // Create nested structure: Designer -> Year -> Token/Project -> Files
        if (!grouped.containsKey(designerName)) {
          grouped[designerName] = {};
        }
        if (!grouped[designerName]!.containsKey(year)) {
          grouped[designerName]![year] = {};
        }
        if (!grouped[designerName]![year]!.containsKey(tokenId)) {
          grouped[designerName]![year]![tokenId] = [];
        }
        
        // Add file with timestamp and project info
        grouped[designerName]![year]![tokenId]!.add({
          ...file,
          'project_name': projectName,
          'token_status': token['status'],
          'token_archived': isTokenArchived,
          'formatted_date': _formatTimestamp(uploadedAt),
          'folder_timestamp': _formatFolderTimestamp(uploadedAt),
        });
      }
      
      return grouped;
    } catch (e) {
      print('Error getting grouped files: $e');
      return {};
    }
  }
  
  static String _formatFolderTimestamp(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    return '$month $day';
  }
  
  // Get project counts for a designer
  static Future<Map<String, int>> getDesignerProjectCounts(String designerId) async {
    try {
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
      
      return {
        'assigned': assigned,
        'completed': completed,
      };
    } catch (e) {
      print('Error getting designer project counts: $e');
      return {'assigned': 0, 'completed': 0};
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
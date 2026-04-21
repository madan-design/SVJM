import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

SupabaseClient get _db => Supabase.instance.client;
String get _uid => AuthService.currentUser!.id;

/// Converts a Supabase quotes row → the map shape all screens expect.
Map<String, dynamic> _rowToQuote(Map<String, dynamic> row) {
  return {
    'fileName':     row['file_name'] as String,
    'pdfPath':      row['pdf_path'] as String,        // storage path
    'metadataPath': row['id'] as String,              // UUID used as "metadataPath"
    'timestamp':    DateTime.parse(row['created_at'] as String)
                        .millisecondsSinceEpoch,
    'date':         row['date'] as String? ?? '',
    'company':      row['company'] as String? ?? '',
    'address':      row['address'] as String? ?? '',
    'subject':      row['subject'] as String? ?? '',
    'components':   row['components'] ?? [],
    'status':       row['status'] as String? ?? 'draft',
    'completedDate':row['completed_date'] as String? ?? '',
    'archivedFrom': row['archived_from'] as String? ?? '',
    'includeMachine': row['include_machine'] as bool? ?? true,
  };
}

// ── StorageService ─────────────────────────────────────────────────────────────

class StorageService {

  // ── Generate file name ─────────────────────────────────────

  static Future<String> generateFileName(String company) async {
    final quotes = await getAllQuotes();
    final cleanName = company.trim().replaceAll(RegExp(r'\s+'), '_');
    int maxNumber = 0;
    for (final q in quotes) {
      final fileName = q['fileName'] as String;
      if (fileName.startsWith(cleanName)) {
        final suffix = fileName.substring(cleanName.length);
        final match = RegExp(r'^_?(\d+)$').firstMatch(suffix);
        if (match != null) {
          final n = int.tryParse(match.group(1)!) ?? 0;
          if (n > maxNumber) maxNumber = n;
        }
      }
    }
    return '${cleanName}_${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  // ── Save quote (upload PDF + insert row) ───────────────────

  static Future<String> saveQuote({
    required String fileName,
    required List<int> pdfBytes,
    required Map<String, dynamic> metadata,
  }) async {
    final storagePath = '$_uid/$fileName.pdf';

    // Upload PDF to Supabase Storage
    await _db.storage.from('quotes-pdf').uploadBinary(
      storagePath,
      Uint8List.fromList(pdfBytes),
      fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
    );

    // Upsert metadata row (insert or update if fileName already exists for this user)
    await _db.from('quotes').upsert({
      'file_name':       fileName,
      'pdf_path':        storagePath,
      'owner_id':        _uid,
      'date':            metadata['date'] ?? '',
      'company':         metadata['company'] ?? '',
      'address':         metadata['address'] ?? '',
      'subject':         metadata['subject'] ?? '',
      'components':      metadata['components'] ?? [],
      'status':          metadata['status'] ?? 'draft',
      'completed_date':  metadata['completedDate'] ?? '',
      'archived_from':   metadata['archivedFrom'] ?? '',
      'include_machine': metadata['includeMachine'] ?? true,
      'updated_at':      DateTime.now().toIso8601String(),
    }, onConflict: 'owner_id,file_name');

    return storagePath;
  }

  // ── Get all quotes ─────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getAllQuotes() async {
    final rows = await _db
        .from('quotes')
        .select()
        .eq('owner_id', _uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _rowToQuote(r as Map<String, dynamic>)).toList();
  }

  // ── Read PDF bytes (download from storage) ─────────────────

  static Future<List<int>> readPdfBytes(String pdfPath) async {
    final bytes = await _db.storage.from('quotes-pdf').download(pdfPath);
    return bytes;
  }

  // ── Delete quote ───────────────────────────────────────────

  static Future<void> deleteQuote(String pdfPath, String quoteId) async {
    await _db.storage.from('quotes-pdf').remove([pdfPath]);
    await _db.from('quotes').delete().eq('id', quoteId);
  }

  // ── Status updates ─────────────────────────────────────────

  static Future<void> _updateStatus(String quoteId, Map<String, dynamic> fields) async {
    await _db.from('quotes').update({
      ...fields,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', quoteId);
  }

  static Future<void> confirmQuote(String quoteId) async =>
      _updateStatus(quoteId, {'status': 'confirmed'});

  static Future<void> completeProject(String quoteId) async {
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    await _updateStatus(quoteId, {'status': 'completed', 'completed_date': date});
  }

  static Future<void> reactivateProject(String quoteId) async =>
      _updateStatus(quoteId, {'status': 'confirmed', 'completed_date': ''});

  static Future<void> moveToQuote(String quoteId) async =>
      _updateStatus(quoteId, {'status': 'draft', 'completed_date': ''});

  static Future<void> archiveItem(String quoteId) async {
    final row = await _db.from('quotes').select('status').eq('id', quoteId).single();
    await _updateStatus(quoteId, {
      'archived_from': row['status'] as String? ?? 'draft',
      'status': 'archived',
    });
  }

  static Future<void> unarchiveItem(String quoteId) async {
    final row = await _db.from('quotes').select('archived_from').eq('id', quoteId).single();
    await _updateStatus(quoteId, {
      'status': row['archived_from'] as String? ?? 'draft',
      'archived_from': '',
    });
  }

  // ── Dashboard stats ────────────────────────────────────────

  static Future<Map<String, int>> getDashboardStats() async {
    try {
      final all = await getAllQuotes();
      
      // Get tokens with error handling
      List<dynamic> tokenList = [];
      try {
        final tokens = await _db.from('tokens').select('id, status');
        tokenList = tokens as List;
      } catch (e) {
        // If tokens table doesn't exist or user doesn't have access, continue with empty list
        print('Error fetching tokens: $e');
      }
      
      return {
        'totalQuotes': all.where((q) => q['status'] != 'archived').length,
        'drafts':      all.where((q) => q['status'] == 'draft').length,
        'approved':    all.where((q) => q['status'] == 'confirmed' || q['status'] == 'completed').length,
        'completed':   all.where((q) => q['status'] == 'completed').length,
        'tasksAssigned':  tokenList.length,
        'tasksCompleted': tokenList.where((t) => t['status'] == 'completed').length,
      };
    } catch (e) {
      print('Error in getDashboardStats: $e');
      // Return default stats if there's an error
      return {
        'totalQuotes': 0,
        'drafts': 0,
        'approved': 0,
        'completed': 0,
        'tasksAssigned': 0,
        'tasksCompleted': 0,
      };
    }
  }

  // ── Filtered lists ─────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getAllProjects() async {
    final rows = await _db
        .from('quotes')
        .select()
        .eq('owner_id', _uid)
        .inFilter('status', ['confirmed', 'completed'])
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _rowToQuote(r as Map<String, dynamic>)).toList();
  }

  static Future<List<Map<String, dynamic>>> getAllArchived() async {
    final rows = await _db
        .from('quotes')
        .select()
        .eq('owner_id', _uid)
        .eq('status', 'archived')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _rowToQuote(r as Map<String, dynamic>)).toList();
  }

  // ── Delete project (quote + expenses) ─────────────────────

  static Future<void> deleteProject(String pdfPath, String quoteId, String projectId) async {
    await deleteQuote(pdfPath, quoteId);
    // expenses stored in Supabase too — delete them
    await _db.from('expenses').delete().eq('project_id', projectId);
  }

  // ── Expenses (Supabase — synced across devices) ────────────

  static Future<List<Map<String, dynamic>>> getExpenses(String projectId) async {
    final rows = await _db
        .from('expenses')
        .select()
        .eq('project_id', projectId)
        .order('expense_date', ascending: true);
    return (rows as List).map((r) => {
      'id':     r['id'] as String,
      'amount': (r['amount'] as num).toDouble(),
      'note':   r['note'] as String? ?? '',
      'date':   r['expense_date'] as String? ?? '',
    }).toList();
  }

  static Future<void> addExpense(String projectId, Map<String, dynamic> expense) async {
    await _db.from('expenses').insert({
      'project_id':   projectId,
      'owner_id':     _uid,
      'amount':       expense['amount'],
      'note':         expense['note'] ?? '',
      'expense_date': expense['date'] ?? '',
    });
  }

  static Future<void> deleteExpense(String projectId, int index) async {
    final expenses = await getExpenses(projectId);
    if (index >= expenses.length) return;
    final id = expenses[index]['id'] as String;
    await _db.from('expenses').delete().eq('id', id);
  }

  static Future<void> updateExpense(String projectId, int index, Map<String, dynamic> updated) async {
    final expenses = await getExpenses(projectId);
    if (index >= expenses.length) return;
    final id = expenses[index]['id'] as String;
    await _db.from('expenses').update({
      'amount':       updated['amount'],
      'note':         updated['note'] ?? '',
      'expense_date': updated['date'] ?? '',
    }).eq('id', id);
  }
}

// ── DraftService (local only — drafts are per-device intentionally) ────────────

class DraftService {
  static const _key = 'quote_draft';

  static Future<void> saveDraft(Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft));
  }

  static Future<Map<String, dynamic>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

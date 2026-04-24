import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mime/mime.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/web_drag_drop_stub.dart'
    if (dart.library.html) '../../widgets/web_drag_drop.dart';

class LegacyFilesScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onFolderArchived;
  
  const LegacyFilesScreen({super.key, this.onFolderArchived});

  @override
  State<LegacyFilesScreen> createState() => _LegacyFilesScreenState();
}

class _LegacyFilesScreenState extends State<LegacyFilesScreen> {
  List<Map<String, dynamic>> _folders = [];
  String _searchQuery = '';
  bool _loading = true;
  final List<Map<String, dynamic>> _archivedFolders = []; // Track archived folders

  List<Map<String, dynamic>> get _filteredFolders {
    if (_searchQuery.isEmpty) return _folders;
    final query = _searchQuery.toLowerCase();
    return _folders.where((folder) {
      final name = (folder['folder_name'] as String).toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _loading = true);
    try {
      final folders = await SupabaseService.getMyLegacyFolders();
      if (mounted) {
        setState(() {
          _folders = folders;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading legacy folders: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading folders: $e')),
        );
      }
    }
  }

  Future<void> _createNewFolder() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CreateFolderDialog(),
    );

    if (result != null) {
      try {
        await SupabaseService.createLegacyFolder(
          folderName: result['folderName'],
          year: result['year'],
          month: result['month'],
        );
        await _loadFolders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Folder created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _openFolder(Map<String, dynamic> folder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LegacyFolderDetailScreen(folder: folder),
      ),
    );
    // Only reload if folder status might have changed (e.g., marked as completed)
    if (result == true) {
      await _loadFolders();
    }
  }

  Future<void> _archiveFolder(Map<String, dynamic> folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Folder'),
        content: Text('Archive "${folder['folder_name']}"? You can restore it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        print('Archiving folder: ${folder['folder_name']} (ID: ${folder['id']})');
        await SupabaseService.archiveLegacyFolder(folder['id']);
        print('Folder archived successfully in database');
        
        // Remove the folder from the current list immediately
        setState(() {
          _folders.removeWhere((f) => f['id'] == folder['id']);
        });
        
        // Create archived folder data
        final archivedFolder = {
          ...folder,
          'status': 'archived',
          'archived_at': DateTime.now().toIso8601String(),
          'archived_by': AuthService.currentUser!.id,
        };
        
        // Add to local tracking
        _archivedFolders.add(archivedFolder);
        
        // Immediately notify parent via callback
        if (widget.onFolderArchived != null) {
          print('Calling parent callback immediately for archived folder');
          widget.onFolderArchived!(archivedFolder);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Folder archived successfully')),
          );
        }
      } catch (e) {
        print('Error archiving folder: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error archiving folder: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // When user leaves the screen, return any archived folders to parent
        if (didPop && _archivedFolders.isNotEmpty) {
          print('Screen closing, returning ${_archivedFolders.length} archived folders to parent');
          // Use a post-frame callback to ensure proper navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop({
                'action': 'archived_batch',
                'folders': _archivedFolders,
              });
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('Old Files'),
          backgroundColor: const Color(0xFFC40000),
          foregroundColor: Colors.white,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search folders...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),
        ),
        body: _filteredFolders.isEmpty
            ? _EmptyState(onCreateFolder: _createNewFolder)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredFolders.length,
                itemBuilder: (context, index) {
                  final folder = _filteredFolders[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LegacyFolderCard(
                      folder: folder,
                      isDark: isDark,
                      onTap: () => _openFolder(folder),
                      onArchive: () => _archiveFolder(folder),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _createNewFolder,
          backgroundColor: const Color(0xFFC40000),
          foregroundColor: Colors.white,
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}

// ── Create Folder Dialog ───────────────────────────────────────────────────────

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog();

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final _folderNameController = TextEditingController();
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isValid = false;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _folderNameController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isValid = _folderNameController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      title: const Text('Create New Folder'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Folder Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _folderNameController,
              decoration: const InputDecoration(
                hintText: 'Enter folder name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('Year'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: List.generate((DateTime.now().year + 5) - 2000 + 1, (index) {
                final year = (DateTime.now().year + 5) - index;
                return DropdownMenuItem(value: year, child: Text(year.toString()));
              }),
              onChanged: (value) => setState(() => _selectedYear = value!),
            ),
            const SizedBox(height: 16),
            const Text('Month'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedMonth,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _months.asMap().entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key + 1,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedMonth = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValid
              ? () => Navigator.pop(context, {
                    'folderName': _folderNameController.text.trim(),
                    'year': _selectedYear,
                    'month': _selectedMonth,
                  })
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC40000),
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Folder'),
        ),
      ],
    );
  }
}

// ── Legacy Folder Card ─────────────────────────────────────────────────────────

class _LegacyFolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  const _LegacyFolderCard({
    required this.folder,
    required this.isDark,
    required this.onTap,
    required this.onArchive,
  });

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final folderName = folder['folder_name'] as String;
    final year = folder['year'] as int;
    final month = folder['month'] as int;
    final status = folder['status'] as String;
    final isDraft = status == 'draft';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC40000).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_rounded,
                    color: Color(0xFFC40000),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folderName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_getMonthName(month)} $year',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDraft 
                                  ? const Color(0xFFFF9800).withValues(alpha: 0.1)
                                  : const Color(0xFF00C853).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDraft ? const Color(0xFFFF9800) : const Color(0xFF00C853),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isDraft ? 'Draft' : 'Completed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDraft ? const Color(0xFFFF9800) : const Color(0xFF00C853),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDraft 
                            ? const Color(0xFFFF9800).withValues(alpha: 0.1)
                            : const Color(0xFF00C853).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDraft ? const Color(0xFFFF9800) : const Color(0xFF00C853),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isDraft ? 'Draft' : 'Completed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDraft ? const Color(0xFFFF9800) : const Color(0xFF00C853),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onArchive,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.archive_rounded,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateFolder;

  const _EmptyState({required this.onCreateFolder});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 48,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Old Folders Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create folders to organize your old files\nby name, year, and month',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateFolder,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC40000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Legacy Folder Detail Screen ────────────────────────────────────────────────

class _LegacyFolderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> folder;

  const _LegacyFolderDetailScreen({required this.folder});

  @override
  State<_LegacyFolderDetailScreen> createState() => _LegacyFolderDetailScreenState();
}


class _LegacyFolderDetailScreenState extends State<_LegacyFolderDetailScreen> {
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _uploading = false;
  bool _isDragOver = false;

  static const _allowedExtensions = [
    'x_t', 'xt', 'step', 'stp', 'prt', 'igs', 'iges', 'stl', 'obj', 'sat',
    'catpart', 'catproduct', 'ipt', 'iam', 'sldprt', 'sldasm',
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'jpg', 'jpeg', 'png', 'bmp', 'gif', 'tiff',
    'dwg', 'dxf', 'zip', 'rar', '7z',
  ];

  @override
  void initState() {
    super.initState();
    _loadFiles();
    
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WebDragDropHandler.setupDragListeners(
          () => setState(() => _isDragOver = true),
          () => setState(() => _isDragOver = false),
          (files) => _handleWebDroppedFiles(files),
        );
      });
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WebDragDropHandler.removeDragListeners();
    }
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      final files = await SupabaseService.getFilesForLegacyFolder(widget.folder['id']);
      if (mounted) {
        setState(() {
          _files = files;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading files: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    await _uploadFiles(result.files);
  }

  Future<void> _uploadFiles(List<PlatformFile> files) async {
    setState(() => _uploading = true);
    int success = 0;
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      
      final ext = file.name.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name}: File type not supported')));
        }
        continue;
      }
      
      final mime = lookupMimeType(file.name) ?? 'application/octet-stream';
      try {
        await SupabaseService.uploadLegacyFile(
          folderId: widget.folder['id'],
          fileName: file.name,
          bytes: Uint8List.fromList(bytes),
          mimeType: mime,
        );
        success++;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload ${file.name}: $e')));
        }
      }
    }
    setState(() => _uploading = false);
    if (success > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$success file${success > 1 ? "s" : ""} uploaded')));
      }
      await _loadFiles();
    }
  }

  Future<void> _handleWebDroppedFiles(List<dynamic> files) async {
    if (!kIsWeb) return;
    try {
      final platformFiles = await WebDragDropHandler.handleDroppedFiles(
        files,
        _allowedExtensions,
      );
      if (platformFiles.isNotEmpty) {
        await _uploadFiles(platformFiles);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No supported files found')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing dropped files: $e')),
        );
      }
    }
  }

  Future<void> _unarchiveFile(Map<String, dynamic> file) async {
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore File'),
          content: Text('Restore "${file['file_name']}"? It will be moved back to the active list.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (ok == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restoring file...')));
        }
        await SupabaseService.unarchiveLegacyFile(file['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File restored successfully!')));
        }
        await _loadFiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _archiveFile(Map<String, dynamic> file) async {
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Archive File'),
          content: Text('Archive "${file['file_name']}"? The file will be moved to your archive.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (ok == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archiving file...'), duration: Duration(seconds: 2)));
        }
        await SupabaseService.archiveFile(file['id'] as String);
        await _loadFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File archived successfully')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        String message = 'Error archiving file';
        if (e.toString().contains('database schema')) {
          message = 'Archive feature requires database update. File was deleted instead.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange));
      }
    }
  }

  Future<void> _viewFile(String filePath, String fileName) async {
    try {
      final url = await SupabaseService.getSignedUrl(filePath);
      if (mounted) await FileActions.viewFile(context, url, fileName: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _downloadFile(String filePath, String fileName) async {
    try {
      final url = await SupabaseService.getSignedUrl(filePath);
      if (mounted) await FileActions.downloadFile(context, url, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _markComplete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text('Mark this folder as completed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SupabaseService.markLegacyFolderCompleted(widget.folder['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folder marked as completed!')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 700;
    final folderName = widget.folder['folder_name'] as String;
    final status = widget.folder['status'] as String;
    final isDraft = status == 'draft';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(folderName),
        backgroundColor: const Color(0xFFC40000),
        foregroundColor: Colors.white,
        actions: [
          if (isDraft)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _markComplete,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildFilesTab(isDark, isWide, isDraft),
    );
  }

  Widget _buildFileList(bool isDark, bool isWide, bool isDraft) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.folder_open_rounded, size: 20),
        const SizedBox(width: 8),
        Text('Files (${_files.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      if (!isWide && _files.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('← Swipe left to reveal actions',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
      const SizedBox(height: 12),
      if (_files.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Icon(Icons.upload_file_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No files uploaded yet', style: TextStyle(color: Colors.grey.shade500)),
          ]),
        )
      else
        ..._files.map((f) {
          final fileName = f['file_name'] as String;
          final filePath = f['file_path'] as String;
          final canView = FileActions.isViewable(fileName);

          return isWide 
              ? Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Text(FileActions.fileIcon(fileName), style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(FileActions.formatSize(f['file_size'] as int?),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ])),
                      if (canView)
                        _LegacyFileActionBtn(
                          icon: Icons.visibility_rounded,
                          label: 'View',
                          color: const Color(0xFF1565C0),
                          onTap: () => _viewFile(filePath, fileName),
                        ),
                      const SizedBox(width: 6),
                      _LegacyFileActionBtn(
                        icon: Icons.download_rounded,
                        label: 'Download',
                        color: const Color(0xFF2E7D32),
                        onTap: () => _downloadFile(filePath, fileName),
                      ),
                      if (isDraft) ...[
                        const SizedBox(width: 6),
                        _LegacyFileActionBtn(
                          icon: Icons.archive_outlined,
                          label: 'Archive',
                          color: Colors.orange.shade400,
                          onTap: () => _archiveFile(f),
                        ),
                      ],
                    ]),
                  ),
                )
              : _LegacySlidableFileItem(
                  fileData: f,
                  fileName: fileName,
                  filePath: filePath,
                  canView: canView,
                  isDark: isDark,
                  isDraft: isDraft,
                  onView: () => _viewFile(filePath, fileName),
                  onDownload: () => _downloadFile(filePath, fileName),
                  onArchive: () => _archiveFile(f),
                );
        }),
    ]);
  }

  Widget _buildFilesTab(bool isDark, bool isWide, bool isDraft) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: isWide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _buildFileList(isDark, isWide, isDraft)),
              const SizedBox(width: 24),
              if (isDraft) SizedBox(width: 320, child: _buildUploadPanel(isDark)),
            ])
          : Column(children: [
              if (isDraft) ...[_buildUploadPanel(isDark), const SizedBox(height: 20)],
              _buildFileList(isDark, isWide, isDraft),
            ]),
    );
  }

  Widget _buildUploadPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Upload Files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('3D files, PDFs, drawings, images & more',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        kIsWeb ? _LegacyCrossPlatformUploader(
          isDark: isDark,
          uploading: _uploading,
          isDragOver: _isDragOver,
          onTap: _uploading ? null : _pickAndUpload,
        ) : GestureDetector(
          onTap: _uploading ? null : _pickAndUpload,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _uploading
                ? const Column(children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Uploading...', style: TextStyle(fontSize: 13)),
                  ])
                : Column(children: [
                    Icon(Icons.cloud_upload_rounded, size: 40,
                        color: const Color(0xFF1565C0).withValues(alpha: 0.7)),
                    const SizedBox(height: 10),
                    const Text('Tap to choose files',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ]),
          ),
        ),
        const SizedBox(height: 12),
        Text('Supported: .step .x_t .prt .igs .stl .dwg .pdf .doc .jpg .png .zip and more',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ]),
    );
  }
}

class _LegacySlidableFileItem extends StatefulWidget {
  final Map<String, dynamic> fileData;
  final String fileName;
  final String filePath;
  final bool canView;
  final bool isDark;
  final bool isDraft;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onArchive;

  const _LegacySlidableFileItem({
    required this.fileData,
    required this.fileName,
    required this.filePath,
    required this.canView,
    required this.isDark,
    required this.isDraft,
    required this.onView,
    required this.onDownload,
    required this.onArchive,
  });

  @override
  State<_LegacySlidableFileItem> createState() => _LegacySlidableFileItemState();
}

class _LegacySlidableFileItemState extends State<_LegacySlidableFileItem> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _drag = 0;
  bool _isOpen = false;

  static const double _revealFraction = 0.35;
  static const double _snapThreshold = 0.15;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _anim = _ctrl.drive(CurveTween(curve: Curves.easeOut));
  }

  @override
  void dispose() { 
    _ctrl.dispose(); 
    super.dispose(); 
  }

  void _onDragUpdate(DragUpdateDetails d, double max) =>
      setState(() => _drag = (_drag - d.delta.dx).clamp(0.0, max));

  void _onDragEnd(DragEndDetails d, double max) =>
      _drag / max >= _snapThreshold ? _snapOpen(max) : _snapClose();

  void _snapOpen(double max) {
    _anim = Tween<double>(begin: _drag, end: max).chain(CurveTween(curve: Curves.easeOut)).animate(_ctrl);
    _ctrl.forward(from: 0).then((_) => setState(() { _drag = max; _isOpen = true; }));
  }

  void _snapClose() {
    _anim = Tween<double>(begin: _drag, end: 0).chain(CurveTween(curve: Curves.easeOut)).animate(_ctrl);
    _ctrl.forward(from: 0).then((_) => setState(() { _drag = 0; _isOpen = false; }));
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { 
        _snapClose(); 
        onTap(); 
      },
      child: Container(
        width: 36, 
        height: 36,
        decoration: BoxDecoration(
          color: color, 
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35), 
              blurRadius: 6, 
              offset: const Offset(0, 2)
            )
          ]
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _actionPanel(double w) {
    final bg = widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(12), 
        bottomRight: Radius.circular(12)
      ),
      child: Container(
        width: w, 
        color: bg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (widget.canView)
              _actionBtn(Icons.visibility_rounded, const Color(0xFF1565C0), widget.onView),
            _actionBtn(Icons.download_rounded, const Color(0xFF2E7D32), widget.onDownload),
            if (widget.isDraft)
              _actionBtn(Icons.archive_outlined, Colors.orange.shade600, widget.onArchive),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final maxSwipe = fullWidth * _revealFraction;

        return GestureDetector(
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxSwipe),
          onHorizontalDragEnd: (d) => _onDragEnd(d, maxSwipe),
          child: SizedBox(
            width: fullWidth,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (ctx, _) {
                  final offset = _ctrl.isAnimating ? _anim.value : _drag;
                  return Stack(children: [
                    Positioned(
                      left: fullWidth - offset, 
                      top: 0, 
                      bottom: 0, 
                      width: maxSwipe,
                      child: _actionPanel(maxSwipe),
                    ),
                    Transform.translate(
                      offset: Offset(-offset, 0),
                      child: SizedBox(
                        width: fullWidth,
                        child: Material(
                          color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 2,
                          shadowColor: Colors.black12,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _isOpen ? _snapClose() : widget.onView(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(children: [
                                Text(FileActions.fileIcon(widget.fileName), 
                                    style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      Text(widget.fileName, 
                                          style: const TextStyle(
                                            fontSize: 14, 
                                            fontWeight: FontWeight.w500
                                          )),
                                      Text(FileActions.formatSize(widget.fileData['file_size'] as int?),
                                          style: TextStyle(
                                            fontSize: 12, 
                                            color: Colors.grey.shade500
                                          )),
                                    ]
                                  )
                                ),
                                Icon(
                                  Icons.chevron_left, 
                                  size: 14, 
                                  color: Colors.grey.shade400
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _LegacyFileActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LegacyFileActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _LegacyCrossPlatformUploader extends StatelessWidget {
  final bool isDark;
  final bool uploading;
  final bool isDragOver;
  final VoidCallback? onTap;

  const _LegacyCrossPlatformUploader({
    required this.isDark,
    required this.uploading,
    required this.isDragOver,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: isDragOver 
              ? (isDark ? const Color(0xFF2E4A3D) : const Color(0xFFE8F5E8))
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F8FF)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDragOver 
                ? const Color(0xFF2E7D32)
                : Colors.grey.shade300,
            width: isDragOver ? 2 : 1,
          ),
        ),
        child: uploading
            ? const Column(children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 12),
                Text('Uploading...', style: TextStyle(fontSize: 13)),
              ])
            : Column(children: [
                Icon(
                  isDragOver ? Icons.file_download : Icons.cloud_upload_rounded,
                  size: 40,
                  color: isDragOver 
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF1565C0).withValues(alpha: 0.7),
                ),
                const SizedBox(height: 10),
                Text(
                  isDragOver ? 'Drop files here' : 'Click to choose files',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                    color: isDragOver ? const Color(0xFF2E7D32) : null,
                  ),
                ),
                if (!isDragOver && kIsWeb) ...[
                  const SizedBox(height: 4),
                  Text(
                    'or drag & drop here',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';

class LegacyFilesScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onFolderArchived;
  
  const LegacyFilesScreen({super.key, this.onFolderArchived});

  @override
  State<LegacyFilesScreen> createState() => _LegacyFilesScreenState();
}

class _LegacyFilesScreenState extends State<LegacyFilesScreen> {
  List<Map<String, dynamic>> _folders = [];
  bool _loading = true;
  final List<Map<String, dynamic>> _archivedFolders = []; // Track archived folders

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
          title: const Text('Legacy Files'),
          backgroundColor: const Color(0xFFC40000),
          foregroundColor: Colors.white,
        ),
        body: _folders.isEmpty
            ? _EmptyState(onCreateFolder: _createNewFolder)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _folders.length,
                itemBuilder: (context, index) {
                  final folder = _folders[index];
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
              items: List.generate(10, (index) {
                final year = DateTime.now().year - 5 + index;
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
              'No Legacy Folders Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create folders to organize your legacy files\nby name, year, and month',
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

  @override
  void initState() {
    super.initState();
    _loadFiles();
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

  Future<void> _uploadFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _uploading = true);
      
      try {
        for (final file in result.files) {
          if (file.bytes != null) {
            await SupabaseService.uploadLegacyFile(
              folderId: widget.folder['id'],
              fileName: file.name,
              bytes: file.bytes!,
              mimeType: _getMimeType(file.name),
            );
          }
        }
        
        await _loadFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${result.files.length} file(s) uploaded successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading files: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'doc': case 'docx': return 'application/msword';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'dwg': return 'application/acad';
      case 'step': case 'stp': return 'application/step';
      case 'iges': case 'igs': return 'application/iges';
      default: return 'application/octet-stream';
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${file['file_name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.deleteLegacyFile(file['id'], file['file_path']);
        await _loadFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting file: $e')),
          );
        }
      }
    }
  }

  Future<void> _markCompleted() async {
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one file before marking as completed')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text('Mark this folder as completed? It will be visible to admin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.markLegacyFolderCompleted(widget.folder['id']);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Folder marked as completed')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error marking as completed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folderName = widget.folder['folder_name'] as String;
    final status = widget.folder['status'] as String;
    final isDraft = status == 'draft';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(folderName),
        backgroundColor: const Color(0xFFC40000),
        foregroundColor: Colors.white,
        actions: [
          if (isDraft) ...[
            IconButton(
              icon: const Icon(Icons.upload_file_rounded),
              onPressed: _uploading ? null : _uploadFiles,
              tooltip: 'Upload Files',
            ),
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: _markCompleted,
              tooltip: 'Mark Completed',
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_uploading)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFFC40000).withValues(alpha: 0.1),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Uploading files...'),
                      ],
                    ),
                  ),
                Expanded(
                  child: _files.isEmpty
                      ? _EmptyFilesState(
                          isDraft: isDraft,
                          onUpload: _uploadFiles,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _files.length,
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FileCard(
                                file: file,
                                isDark: isDark,
                                canDelete: isDraft,
                                onDelete: () => _deleteFile(file),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: isDraft
          ? FloatingActionButton(
              onPressed: _uploading ? null : _uploadFiles,
              backgroundColor: const Color(0xFFC40000),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

// ── File Card ──────────────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final Map<String, dynamic> file;
  final bool isDark;
  final bool canDelete;
  final VoidCallback onDelete;

  const _FileCard({
    required this.file,
    required this.isDark,
    required this.canDelete,
    required this.onDelete,
  });

  String _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return '📄';
      case 'doc': case 'docx': return '📝';
      case 'jpg': case 'jpeg': case 'png': return '🖼️';
      case 'dwg': return '📐';
      case 'step': case 'stp': case 'iges': case 'igs': return '🔧';
      default: return '📎';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = file['file_name'] as String;
    final fileSize = file['file_size'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFC40000).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              _getFileIcon(fileName),
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          fileName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          _formatFileSize(fileSize),
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        trailing: canDelete
            ? IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}

// ── Empty Files State ──────────────────────────────────────────────────────────

class _EmptyFilesState extends StatelessWidget {
  final bool isDraft;
  final VoidCallback onUpload;

  const _EmptyFilesState({
    required this.isDraft,
    required this.onUpload,
  });

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
                Icons.upload_file_rounded,
                size: 48,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isDraft ? 'No Files Uploaded Yet' : 'Folder Completed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDraft
                  ? 'Upload files to this legacy folder\nand mark as completed when done'
                  : 'This folder has been marked as completed\nand is now visible to admin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
                height: 1.4,
              ),
            ),
            if (isDraft) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC40000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
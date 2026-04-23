import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import 'mde_project_screen.dart';
import 'legacy_files_screen.dart';

class AppBreakpoints {
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1024;
}

class FileActions {
  static String fileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return '📄';
      case 'doc': case 'docx': return '📝';
      case 'xls': case 'xlsx': return '📊';
      case 'jpg': case 'jpeg': case 'png': case 'gif': return '🖼️';
      case 'zip': case 'rar': return '📦';
      default: return '📄';
    }
  }
}

Future<void> confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}

class MdeHomeScreen extends StatefulWidget {
  const MdeHomeScreen({super.key});

  @override
  State<MdeHomeScreen> createState() => _MdeHomeScreenState();
}

class _MdeHomeScreenState extends State<MdeHomeScreen> {
  String _mdeName = 'Designer';
  List<Map<String, dynamic>> _assigned = [];
  List<Map<String, dynamic>> _completed = [];
  List<Map<String, dynamic>> _archivedFiles = [];
  List<Map<String, dynamic>> _archivedLegacyFolders = [];
  bool _loading = true;
  int _selectedIndex = 0; // web sidebar nav
  int _expandedIndex = -1; // accordion

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _restoreFile(Map<String, dynamic> file) async {
    try {
      await SupabaseService.unarchiveFile(file['id'] as String);
      // Remove from local archived list immediately
      setState(() {
        _archivedFiles.removeWhere((f) => f['id'] == file['id']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File restored successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring file: $e')),
        );
      }
    }
  }

  bool _isRestoring = false; // Add this flag to prevent double operations

  Future<void> _restoreLegacyFolder(Map<String, dynamic> folder) async {
    if (_isRestoring) {
      debugPrint('Restore already in progress, ignoring...');
      return;
    }
    
    setState(() => _isRestoring = true);
    
    try {
      debugPrint('Restoring legacy folder: ${folder['folder_name']} (ID: ${folder['id']})');
      await SupabaseService.unarchiveLegacyFolder(folder['id'] as String);
      debugPrint('Legacy folder restored, updating UI...');
      
      // Remove from local archived list immediately
      setState(() {
        _archivedLegacyFolders.removeWhere((f) => f['id'] == folder['id']);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Legacy folder restored successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error restoring legacy folder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring folder: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  Future<void> _deleteLegacyFolder(Map<String, dynamic> folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete Folder'),
        content: Text('Permanently delete "${folder['folder_name']}" and all its files? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        debugPrint('Permanently deleting legacy folder: ${folder['folder_name']} (ID: ${folder['id']})');
        await SupabaseService.permanentlyDeleteLegacyFolder(folder['id']);
        debugPrint('Legacy folder deletion completed');
        
        // Remove from local list immediately
        setState(() {
          _archivedLegacyFolders.removeWhere((f) => f['id'] == folder['id']);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Legacy folder permanently deleted')),
          );
        }
        
      } catch (e) {
        debugPrint('Error permanently deleting legacy folder: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _permanentlyDeleteFile(Map<String, dynamic> file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete File'),
        content: Text('Permanently delete "${file['file_name']}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        debugPrint('Permanently deleting file: ${file['file_name']} (ID: ${file['id']})');
        await SupabaseService.permanentlyDeleteFile(file['id'] as String, file['file_path'] as String);
        debugPrint('File permanently deleted from database and storage');
        
        // Remove from local list immediately
        setState(() {
          _archivedFiles.removeWhere((f) => f['id'] == file['id']);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File permanently deleted')));
        }
      } catch (e) {
        debugPrint('Error permanently deleting file: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting file: $e')));
        }
      }
    }
  }

  Future<void> _unarchiveAllFiles() async {
    if (_archivedFiles.isEmpty) return;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unarchive All Files'),
        content: Text('Restore all ${_archivedFiles.length} archived files?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore All'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await SupabaseService.unarchiveAllFiles();
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All files restored successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error restoring files: $e')));
        }
      }
    }
  }

  Future<void> _deleteAllArchivedFiles() async {
    if (_archivedFiles.isEmpty) return;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Archived Files'),
        content: Text('Permanently delete all ${_archivedFiles.length} archived files? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await SupabaseService.deleteAllArchivedFiles();
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All archived files deleted permanently')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting files: $e')));
        }
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await AuthService.getProfile();
      final tokens = await SupabaseService.getMyTokens();
      
      // Get all archived files for current user
      final allArchivedFiles = await SupabaseService.getAllArchivedFiles();
      
      // Get archived legacy folders
      final archivedLegacyFolders = await SupabaseService.getArchivedLegacyFolders();
      
      debugPrint('MDE _load: Found ${archivedLegacyFolders.length} archived legacy folders');
      
      if (mounted) {
        setState(() {
          _mdeName = profile?['name'] ?? 'Designer';
          _assigned = tokens.where((t) => t['status'] == 'assigned').toList();
          _completed = tokens.where((t) => t['status'] == 'completed').toList();
          _archivedFiles = allArchivedFiles;
          _archivedLegacyFolders = archivedLegacyFolders;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in MDE _load: $e');
      if (mounted) {
        setState(() {
          _mdeName = 'Designer';
          _assigned = [];
          _completed = [];
          _archivedFiles = [];
          _archivedLegacyFolders = [];
          _loading = false;
        });
      }
    }
  }

  static const _navItems = [
    _NavItemData('Dashboard', Icons.dashboard_rounded),
    _NavItemData('Assigned', Icons.pending_actions_rounded),
    _NavItemData('Completed', Icons.check_circle_rounded),
    _NavItemData('Legacy Files', Icons.folder_special_rounded),
    _NavItemData('Archive', Icons.archive_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb && AppBreakpoints.isDesktop(context);

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (isDesktop) {
      return _WebMdeShell(
        mdeName: _mdeName,
        selectedIndex: _selectedIndex,
        onNavTap: (i) => setState(() => _selectedIndex = i),
        navItems: _navItems,
        assigned: _assigned,
        completed: _completed,
        archivedFiles: _archivedFiles,
        archivedLegacyFolders: _archivedLegacyFolders,
        onLogout: () => confirmLogout(context),
        onProjectTap: (token) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MdeProjectScreen(token: token)),
        ).then((_) => _load()),
        onRestoreFile: _restoreFile,
        onDeleteFile: _permanentlyDeleteFile,
        onRestoreLegacyFolder: _restoreLegacyFolder,
        onDeleteLegacyFolder: _deleteLegacyFolder,
        onRestoreAll: _unarchiveAllFiles,
        onDeleteAll: _deleteAllArchivedFiles,
        isDark: isDark,
        onLegacyArchive: (archivedFolder) {
          print('Web: Received archive callback: ${archivedFolder['folder_name']}');
          setState(() {
            _archivedLegacyFolders.insert(0, archivedFolder);
            print('Web: Added folder to main archive list. Total: ${_archivedLegacyFolders.length}');
          });
        },
      );
    }

    return _MobileMdeHome(
      mdeName: _mdeName,
      assigned: _assigned,
      completed: _completed,
      archivedFiles: _archivedFiles,
      archivedLegacyFolders: _archivedLegacyFolders,
      expandedIndex: _expandedIndex,
      onToggle: (i) => setState(() => _expandedIndex = _expandedIndex == i ? -1 : i),
      isDark: isDark,
      onLogout: () => confirmLogout(context),
      onProjectTap: (token) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MdeProjectScreen(token: token)),
      ).then((_) => _load()),
      onRestoreFile: _restoreFile,
      onDeleteFile: _permanentlyDeleteFile,
      onRestoreLegacyFolder: _restoreLegacyFolder,
      onDeleteLegacyFolder: _deleteLegacyFolder,
      onRefresh: _load,
      onLegacyArchive: (archivedFolder) {
        // Handle archived folder from legacy files screen
        print('Received archived folder in main widget: ${archivedFolder['folder_name']}');
        setState(() {
          _archivedLegacyFolders.insert(0, archivedFolder);
          print('Added folder to archive list. Total archived folders: ${_archivedLegacyFolders.length}');
        });
      },
    );
  }
}

// ── Web MDE Shell ──────────────────────────────────────────────────────────────

class _WebMdeShell extends StatefulWidget {
  final String mdeName;
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final List<_NavItemData> navItems;
  final List<Map<String, dynamic>> assigned;
  final List<Map<String, dynamic>> completed;
  final List<Map<String, dynamic>> archivedFiles;
  final List<Map<String, dynamic>> archivedLegacyFolders;
  final VoidCallback onLogout;
  final void Function(Map<String, dynamic>) onProjectTap;
  final void Function(Map<String, dynamic>) onRestoreFile;
  final void Function(Map<String, dynamic>) onDeleteFile;
  final void Function(Map<String, dynamic>) onRestoreLegacyFolder;
  final void Function(Map<String, dynamic>) onDeleteLegacyFolder;
  final VoidCallback onRestoreAll;
  final VoidCallback onDeleteAll;
  final bool isDark;
  final void Function(Map<String, dynamic>) onLegacyArchive; // Add callback

  const _WebMdeShell({
    required this.mdeName, required this.selectedIndex, required this.onNavTap,
    required this.navItems, required this.assigned, required this.completed,
    required this.archivedFiles, required this.archivedLegacyFolders, required this.onLogout, required this.onProjectTap,
    required this.onRestoreFile, required this.onDeleteFile, required this.onRestoreLegacyFolder, required this.onDeleteLegacyFolder,
    required this.onRestoreAll, required this.onDeleteAll, required this.isDark, required this.onLegacyArchive,
  });

  @override
  State<_WebMdeShell> createState() => _WebMdeShellState();
}

class _WebMdeShellState extends State<_WebMdeShell> {

  Widget _pageForIndex(int i) {
    switch (i) {
      case 0: return _MdeDashboardPage(assigned: widget.assigned, completed: widget.completed, isDark: widget.isDark);
      case 1: return _ProjectListPage(title: 'Assigned Projects', tokens: widget.assigned,
          color: const Color(0xFF1565C0), isDark: widget.isDark, onTap: widget.onProjectTap);
      case 2: return _ProjectListPage(title: 'Completed Projects', tokens: widget.completed,
          color: const Color(0xFF2E7D32), isDark: widget.isDark, onTap: widget.onProjectTap);
      case 3: return LegacyFilesScreen(
          onFolderArchived: widget.onLegacyArchive,
        );
      case 4: return _MdeArchivePage(
          archivedFiles: widget.archivedFiles, archivedLegacyFolders: widget.archivedLegacyFolders, isDark: widget.isDark, 
          onRestore: widget.onRestoreFile, onDelete: widget.onDeleteFile, onRestoreLegacyFolder: widget.onRestoreLegacyFolder, onDeleteLegacyFolder: widget.onDeleteLegacyFolder,
          onRestoreAll: widget.onRestoreAll, onDeleteAll: widget.onDeleteAll);
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidebarBg = widget.isDark ? const Color(0xFF0F0F0F) : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FA),
      body: Row(children: [
        // Sidebar
        SizedBox(
          width: 240,
          child: Container(
            color: sidebarBg,
            child: Column(children: [
              // Brand
              Container(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/new_logo.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('SVJM', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Mould & Solutions', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                  ]),
                ]),
              ),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              // Nav
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: widget.navItems.length,
                  itemBuilder: (_, i) {
                    final item = widget.navItems[i];
                    final selected = widget.selectedIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: selected ? const Color(0xFF1565C0).withValues(alpha: 0.85) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => widget.onNavTap(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Icon(item.icon,
                                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                size: 20),
                              const SizedBox(width: 12),
                              Text(item.label, style: TextStyle(
                                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.75),
                                fontSize: 14,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              )),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // User + logout
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1565C0),
                    child: Text(widget.mdeName.isNotEmpty ? widget.mdeName[0].toUpperCase() : 'M',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.mdeName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                    Text('Mould Design Engineer', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                  ])),
                  IconButton(
                    icon: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
                    tooltip: 'Logout',
                    onPressed: widget.onLogout,
                  ),
                ]),
              ),
            ]),
          ),
        ),
        // Main content
        Expanded(
          child: Column(children: [
            // Top bar
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(bottom: BorderSide(
                  color: widget.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06))),
              ),
              child: Row(children: [
                Text(widget.navItems[widget.selectedIndex].label, style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1A2E),
                )),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF1565C0),
                      child: Text(widget.mdeName.isNotEmpty ? widget.mdeName[0].toUpperCase() : 'M',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(widget.mdeName, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white70 : const Color(0xFF1A1A2E))),
                    const SizedBox(width: 4),
                    Text('· MDE', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                ),
              ]),
            ),
            Expanded(child: _pageForIndex(widget.selectedIndex)),
          ]),
        ),
      ]),
    );
  }
}

// ── Mobile MDE Home ────────────────────────────────────────────────────────────

class _MobileMdeHome extends StatelessWidget {
  final String mdeName;
  final List<Map<String, dynamic>> assigned;
  final List<Map<String, dynamic>> completed;
  final List<Map<String, dynamic>> archivedFiles;
  final List<Map<String, dynamic>> archivedLegacyFolders;
  final int expandedIndex;
  final void Function(int) onToggle;
  final bool isDark;
  final VoidCallback onLogout;
  final void Function(Map<String, dynamic>) onProjectTap;
  final void Function(Map<String, dynamic>) onRestoreFile;
  final void Function(Map<String, dynamic>) onDeleteFile;
  final void Function(Map<String, dynamic>) onRestoreLegacyFolder;
  final void Function(Map<String, dynamic>) onDeleteLegacyFolder;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic>) onLegacyArchive; // Add callback for archive

  const _MobileMdeHome({
    required this.mdeName, required this.assigned, required this.completed,
    required this.archivedFiles, required this.archivedLegacyFolders, required this.expandedIndex, required this.onToggle, required this.isDark,
    required this.onLogout, required this.onProjectTap, required this.onRestoreFile, required this.onDeleteFile,
    required this.onRestoreLegacyFolder, required this.onDeleteLegacyFolder, required this.onRefresh, required this.onLegacyArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1565C0),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/new_logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          const Text('SVJM', style: TextStyle(color: Colors.white)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white24,
                child: Text(mdeName.isNotEmpty ? mdeName[0].toUpperCase() : 'M',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 2),
              Text(mdeName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: onLogout,
              ),
            ]),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats
          Row(children: [
            Expanded(child: _StatCard(label: 'Assigned', count: assigned.length,
                icon: Icons.pending_actions_rounded, color: const Color(0xFF1565C0), isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Completed', count: completed.length,
                icon: Icons.check_circle_rounded, color: const Color(0xFF2E7D32), isDark: isDark)),
          ]),
          const SizedBox(height: 20),
          // Assigned accordion
          _FolderAccordion(
            title: 'Assigned Projects', icon: Icons.pending_actions_rounded,
            color: const Color(0xFF1565C0), count: assigned.length,
            isOpen: expandedIndex == 0, onToggle: () => onToggle(0),
            isDark: isDark, tokens: assigned, onTap: onProjectTap,
          ),
          const SizedBox(height: 12),
          // Completed accordion
          _FolderAccordion(
            title: 'Completed Projects', icon: Icons.check_circle_rounded,
            color: const Color(0xFF2E7D32), count: completed.length,
            isOpen: expandedIndex == 1, onToggle: () => onToggle(1),
            isDark: isDark, tokens: completed, onTap: onProjectTap,
          ),
          const SizedBox(height: 12),
          // Legacy Files accordion
          _FolderAccordion(
            title: 'Legacy Files', icon: Icons.folder_special_rounded,
            color: const Color(0xFF9C27B0), count: 0, // Will be updated later
            isOpen: expandedIndex == 2, onToggle: () => onToggle(2),
            isDark: isDark, tokens: [], onTap: (_) {},
            isLegacy: true,
            onLegacyTap: () async {
              print('Opening Legacy Files screen');
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LegacyFilesScreen(
                    onFolderArchived: (archivedFolder) {
                      print('Received immediate archive callback: ${archivedFolder['folder_name']}');
                      onLegacyArchive(archivedFolder);
                    },
                  ),
                ),
              );
              print('Returned from Legacy Files screen with result: $result');
              
              // Handle any remaining archived folders from batch return
              if (result != null && result is Map) {
                if (result['action'] == 'archived_batch') {
                  print('Processing batch archived folders result');
                  final archivedFolders = result['folders'] as List<Map<String, dynamic>>;
                  print('Adding ${archivedFolders.length} remaining folders to archive list');
                  for (final archivedFolder in archivedFolders) {
                    onLegacyArchive(archivedFolder);
                  }
                  print('Batch archive callback completed');
                }
              } else {
                print('No additional archive data from screen close');
              }
            },
          ),
          const SizedBox(height: 12),
          // Archive accordion
          _FolderAccordion(
            title: 'Archived Items', icon: Icons.archive_rounded,
            color: const Color(0xFF555555), count: archivedFiles.length + archivedLegacyFolders.length,
            isOpen: expandedIndex == 3, onToggle: () => onToggle(3),
            isDark: isDark, tokens: [], onTap: (_) {},
            isArchive: true, archivedFiles: archivedFiles, archivedLegacyFolders: archivedLegacyFolders,
            onRestoreFile: onRestoreFile, onDeleteFile: onDeleteFile,
            onRestoreLegacyFolder: onRestoreLegacyFolder, onDeleteLegacyFolder: onDeleteLegacyFolder,
          ),
        ],
      ),
    );
  }
}

// ── Web Dashboard Page ─────────────────────────────────────────────────────────

class _MdeDashboardPage extends StatelessWidget {
  final List<Map<String, dynamic>> assigned;
  final List<Map<String, dynamic>> completed;
  final bool isDark;

  const _MdeDashboardPage({required this.assigned, required this.completed, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('My Dashboard', style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Text('View your assigned and completed design projects.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 32),
        Row(children: [
          _StatCard(label: 'Assigned', count: assigned.length,
              icon: Icons.pending_actions_rounded, color: const Color(0xFF1565C0), isDark: isDark),
          const SizedBox(width: 16),
          _StatCard(label: 'Completed', count: completed.length,
              icon: Icons.check_circle_rounded, color: const Color(0xFF2E7D32), isDark: isDark),
        ]),
        const SizedBox(height: 32),
        if (assigned.isNotEmpty) ...[
          Text('Recent Assigned', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
          const SizedBox(height: 12),
          ...assigned.take(3).map((t) => _ProjectTile(token: t, color: const Color(0xFF1565C0),
              isDark: isDark, onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => MdeProjectScreen(token: t))))),
        ],
      ]),
    );
  }
}

// ── Web Project List Page ──────────────────────────────────────────────────────

class _ProjectListPage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> tokens;
  final Color color;
  final bool isDark;
  final void Function(Map<String, dynamic>) onTap;

  const _ProjectListPage({required this.title, required this.tokens,
      required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        const SizedBox(height: 20),
        if (tokens.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.folder_open_rounded, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('No projects here', style: TextStyle(color: Colors.grey.shade500)),
            ]),
          ))
        else
          Wrap(
            spacing: 16, runSpacing: 16,
            children: tokens.map((t) => SizedBox(
              width: 300,
              child: _ProjectTile(token: t, color: color, isDark: isDark, onTap: () => onTap(t)),
            )).toList(),
          ),
      ]),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Map<String, dynamic> token;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ProjectTile({required this.token, required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.folder_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(token['project_name'] as String,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
              const SizedBox(height: 4),
              Text('Tap to open', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({required this.label, required this.count, required this.icon,
      required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }
}

// ── Folder Accordion (mobile) ──────────────────────────────────────────────────

class _FolderAccordion extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final bool isOpen;
  final VoidCallback onToggle;
  final bool isDark;
  final List<Map<String, dynamic>> tokens;
  final void Function(Map<String, dynamic>) onTap;
  final bool isArchive;
  final bool isLegacy;
  final List<Map<String, dynamic>>? archivedFiles;
  final void Function(Map<String, dynamic>)? onRestoreFile;
  final void Function(Map<String, dynamic>)? onDeleteFile;
  final List<Map<String, dynamic>>? archivedLegacyFolders;
  final void Function(Map<String, dynamic>)? onRestoreLegacyFolder;
  final void Function(Map<String, dynamic>)? onDeleteLegacyFolder;
  final VoidCallback? onLegacyTap;

  const _FolderAccordion({
    required this.title, required this.icon, required this.color,
    required this.count, required this.isOpen, required this.onToggle,
    required this.isDark, required this.tokens, required this.onTap,
    this.isArchive = false, this.isLegacy = false, this.archivedFiles, this.archivedLegacyFolders,
    this.onRestoreFile, this.onDeleteFile, this.onRestoreLegacyFolder, this.onDeleteLegacyFolder, this.onLegacyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('$count project${count != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ])),
              Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: ClipRect(
            child: Column(
              children: isOpen
                  ? isLegacy
                      ? [Container(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton.icon(
                            onPressed: onLegacyTap,
                            icon: const Icon(Icons.folder_special_rounded, size: 18),
                            label: const Text('Open Legacy Files'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                        )]
                      : isArchive
                      ? ((archivedFiles?.isEmpty ?? true) && (archivedLegacyFolders?.isEmpty ?? true))
                          ? [Container(
                              padding: const EdgeInsets.all(16),
                              child: Text('No archived items.', 
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            )]
                          : [
                              // Archived Files
                              if (archivedFiles?.isNotEmpty ?? false) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Text('Files', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                                ),
                                ...archivedFiles!.map((f) => Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    leading: Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                      child: Icon(Icons.insert_drive_file_rounded, color: color, size: 20),
                                    ),
                                    title: Text(f['file_name'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                    subtitle: Text('From: ${f['tokens']?['project_name'] ?? 'Unknown Project'}', 
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.unarchive_rounded, color: Colors.green, size: 18),
                                          onPressed: () => onRestoreFile?.call(f),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_forever_rounded, color: Colors.red.shade400, size: 18),
                                          onPressed: () => onDeleteFile?.call(f),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                              ],
                              // Archived Legacy Folders
                              if (archivedLegacyFolders?.isNotEmpty ?? false) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Text('Legacy Folders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                                ),
                                ...archivedLegacyFolders!.map((folder) => Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    leading: Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(color: const Color(0xFF9C27B0).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.folder_special_rounded, color: Color(0xFF9C27B0), size: 20),
                                    ),
                                    title: Text(folder['folder_name'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                    subtitle: Text('Legacy • ${folder['year']}/${folder['month'].toString().padLeft(2, '0')}', 
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.unarchive_rounded, color: Colors.green, size: 18),
                                          onPressed: () => onRestoreLegacyFolder?.call(folder),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_forever_rounded, color: Colors.red.shade400, size: 18),
                                          onPressed: () => onDeleteLegacyFolder?.call(folder),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                              ],
                            ]
                      : tokens.isEmpty
                          ? [Container(
                              padding: const EdgeInsets.all(16),
                              child: Text('No projects here.', 
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            )]
                          : tokens.map((t) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.folder_rounded, color: color, size: 20),
                                ),
                                title: Text(t['project_name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                subtitle: Text('Tap to open', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                onTap: () => onTap(t),
                              ),
                            )).toList()
                  : [const SizedBox.shrink()],
            ),
          ),
        ),
      ]),
    );
  }
}

class _NavItemData {
  final String label;
  final IconData icon;
  const _NavItemData(this.label, this.icon);
}

// ── MDE Archive Page (web only) ───────────────────────────────────────────────

class _MdeArchivePage extends StatelessWidget {
  final List<Map<String, dynamic>> archivedFiles;
  final List<Map<String, dynamic>> archivedLegacyFolders;
  final bool isDark;
  final void Function(Map<String, dynamic>) onRestore;
  final void Function(Map<String, dynamic>) onDelete;
  final void Function(Map<String, dynamic>) onRestoreLegacyFolder;
  final void Function(Map<String, dynamic>) onDeleteLegacyFolder;
  final VoidCallback onRestoreAll;
  final VoidCallback onDeleteAll;

  const _MdeArchivePage({
    required this.archivedFiles, required this.archivedLegacyFolders, required this.isDark, required this.onRestore, 
    required this.onDelete, required this.onRestoreLegacyFolder, required this.onDeleteLegacyFolder,
    required this.onRestoreAll, required this.onDeleteAll
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Archived Items', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
                  const SizedBox(height: 6),
                  Text('Files and folders you have archived.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (archivedFiles.isNotEmpty || archivedLegacyFolders.isNotEmpty) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.unarchive_rounded, size: 16),
                label: const Text('Restore All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                onPressed: onRestoreAll,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: const Text('Delete All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                onPressed: onDeleteAll,
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        if (archivedFiles.isEmpty && archivedLegacyFolders.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.archive_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('No archived items', style: TextStyle(color: Colors.grey.shade500)),
            ]),
          ))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Archived Files Section
              if (archivedFiles.isNotEmpty) ...[
                Text('Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16, runSpacing: 16,
                  children: archivedFiles.map((f) => SizedBox(
                    width: 320,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(FileActions.fileIcon(f['file_name'] as String), style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f['file_name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                        ]),
                        const SizedBox(height: 8),
                        Text('From: ${f['tokens']['project_name'] as String}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        if (f['archived_at'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Archived: ${_formatDate(f['archived_at'] as String)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: ElevatedButton.icon(
                            icon: const Icon(Icons.unarchive_rounded, size: 16),
                            label: const Text('Restore'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => onRestore(f),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: ElevatedButton.icon(
                            icon: const Icon(Icons.delete_forever_rounded, size: 16),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => onDelete(f),
                          )),
                        ]),
                      ]),
                    ),
                  )).toList(),
                ),
                if (archivedLegacyFolders.isNotEmpty) const SizedBox(height: 32),
              ],
              // Archived Legacy Folders Section
              if (archivedLegacyFolders.isNotEmpty) ...[
                Text('Legacy Folders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16, runSpacing: 16,
                  children: archivedLegacyFolders.map((folder) => SizedBox(
                    width: 320,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Text('📁', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(folder['folder_name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                        ]),
                        const SizedBox(height: 8),
                        Text('Legacy • ${folder['year']}/${folder['month'].toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        if (folder['archived_at'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Archived: ${_formatDate(folder['archived_at'] as String)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: ElevatedButton.icon(
                            icon: const Icon(Icons.unarchive_rounded, size: 16),
                            label: const Text('Restore'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => onRestoreLegacyFolder(folder),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: ElevatedButton.icon(
                            icon: const Icon(Icons.delete_forever_rounded, size: 16),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => onDeleteLegacyFolder(folder),
                          )),
                        ]),
                      ]),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
      ]),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}

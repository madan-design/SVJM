import re

with open('lib/screens/mde/legacy_files_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Update _unarchiveFile logic in _LegacyFolderDetailScreenState
old_unarchive_decl = """  Future<void> _archiveFile(Map<String, dynamic> file) async {
    try {"""

new_unarchive_decl = """  Future<void> _unarchiveFile(Map<String, dynamic> file) async {
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
    try {"""
    
if "Future<void> _unarchiveFile" not in code:
    code = code.replace(old_unarchive_decl, new_unarchive_decl)

# 2. Add unarchiving logic to wide UI
old_unarchive_btn = """                      if (isArchiveTab) ...[
                        const SizedBox(width: 6),
                        _LegacyFileActionBtn(
                          icon: Icons.unarchive_rounded,
                          label: 'Restore',
                          color: Colors.green,
                          onTap: () async {
                              // We can unarchive by setting archived=false natively via SupabaseService
                              // SupabaseService.unarchiveFile doesn't exist natively for token files so we use a raw query if necessary
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File restored!')));
                              // Need to mock or implement unarchive
                          },
                        ),
                      ],"""

new_unarchive_btn = """                      if (isArchiveTab) ...[
                        const SizedBox(width: 6),
                        _LegacyFileActionBtn(
                          icon: Icons.unarchive_rounded,
                          label: 'Restore',
                          color: Colors.green,
                          onTap: () => _unarchiveFile(f),
                        ),
                      ],"""

code = code.replace(old_unarchive_btn, new_unarchive_btn)

# 3. Add unarchiving logic to mobile UI in builder
old_smobile = """              : _LegacySlidableFileItem(
                  fileData: f,
                  fileName: fileName,
                  filePath: filePath,
                  canView: canView,
                  isDark: isDark,
                  isDraft: isDraft,
                  onView: () => _viewFile(filePath, fileName),
                  onDownload: () => _downloadFile(filePath, fileName),
                  onArchive: () => _archiveFile(f),
                );"""

new_smobile = """              : _LegacySlidableFileItem(
                  fileData: f,
                  fileName: fileName,
                  filePath: filePath,
                  canView: canView,
                  isDark: isDark,
                  isDraft: isDraft,
                  isArchiveTab: isArchiveTab,
                  onView: () => _viewFile(filePath, fileName),
                  onDownload: () => _downloadFile(filePath, fileName),
                  onArchive: () => _archiveFile(f),
                  onUnarchive: () => _unarchiveFile(f),
                );"""
code = code.replace(old_smobile, new_smobile)

# 4. update _LegacySlidableFileItem definition
old_sclass = """  final VoidCallback onView;
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
  });"""

new_sclass = """  final bool isArchiveTab;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;

  const _LegacySlidableFileItem({
    required this.fileData,
    required this.fileName,
    required this.filePath,
    required this.canView,
    required this.isDark,
    required this.isDraft,
    required this.isArchiveTab,
    required this.onView,
    required this.onDownload,
    required this.onArchive,
    required this.onUnarchive,
  });"""
code = code.replace(old_sclass, new_sclass)

# 5. update actionPanel in _LegacySlidableFileItem
old_action_panel = """  Widget _actionPanel(double w) {
    final bg = widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    return ClipRRect(
      borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
      child: Container(
        width: w, color: bg,
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
  }"""

new_action_panel = """  Widget _actionPanel(double w) {
    final bg = widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    return ClipRRect(
      borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
      child: Container(
        width: w, color: bg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (widget.canView)
              _actionBtn(Icons.visibility_rounded, const Color(0xFF1565C0), widget.onView),
            _actionBtn(Icons.download_rounded, const Color(0xFF2E7D32), widget.onDownload),
            if (widget.isDraft && !widget.isArchiveTab)
              _actionBtn(Icons.archive_outlined, Colors.orange.shade600, widget.onArchive),
            if (widget.isArchiveTab)
              _actionBtn(Icons.unarchive_rounded, Colors.green, widget.onUnarchive),
          ],
        ),
      ),
    );
  }"""
code = code.replace(old_action_panel, new_action_panel)

with open('lib/screens/mde/legacy_files_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
print("legacy_files_screen patched.")

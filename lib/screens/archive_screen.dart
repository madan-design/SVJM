import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/project_service.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await StorageService.getAllArchived();
    setState(() { _items = all; _loading = false; });
  }

  String _typeLabel(String archivedFrom) {
    switch (archivedFrom) {
      case 'confirmed': return 'Live Project';
      case 'completed': return 'Completed Project';
      default: return 'Quote';
    }
  }

  IconData _typeIcon(String archivedFrom) {
    switch (archivedFrom) {
      case 'confirmed': return Icons.bolt_rounded;
      case 'completed': return Icons.check_circle_rounded;
      default: return Icons.description_rounded;
    }
  }

  Color _typeColor(String archivedFrom) {
    switch (archivedFrom) {
      case 'confirmed': return const Color(0xFFE6A817);
      case 'completed': return const Color(0xFF2E7D32);
      default: return const Color(0xFF1565C0);
    }
  }

  Future<void> _unarchive(Map<String, dynamic> item) async {
    await StorageService.unarchiveItem(item['metadataPath'] as String);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored to ${_typeLabel(item['archivedFrom'] as String? ?? 'draft')}')),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final projectId = ProjectService.generateProjectId(
      item['company'] as String, item['fileName'] as String,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text('Permanently delete "${item['fileName']}"?\nThis cannot be undone.'),
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
      await StorageService.deleteProject(
        item['pdfPath'] as String, item['metadataPath'] as String, projectId,
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Archive'), centerTitle: true, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.archive_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('Archive is empty', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Text('Archived quotes and projects appear here',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final archivedFrom = item['archivedFrom'] as String? ?? 'draft';
                    final color = _typeColor(archivedFrom);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 1,
                        shadowColor: Colors.black12,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_typeIcon(archivedFrom), color: color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['fileName'] as String,
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                                            color: isDark ? Colors.white : Colors.black87)),
                                    const SizedBox(height: 3),
                                    Text(item['company'] as String,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(_typeLabel(archivedFrom),
                                          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    tooltip: 'Un-Archive',
                                    icon: const Icon(Icons.unarchive_rounded, color: Colors.green, size: 22),
                                    onPressed: () => _unarchive(item),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: Icon(Icons.delete_rounded, color: Colors.red.shade400, size: 22),
                                    onPressed: () => _delete(item),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

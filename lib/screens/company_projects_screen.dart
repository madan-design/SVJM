import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../services/storage_service.dart';
import 'project_detail_screen.dart';

class CompanyProjectsScreen extends StatefulWidget {
  final String company;
  final List<Map<String, dynamic>> projects;

  const CompanyProjectsScreen({
    super.key,
    required this.company,
    required this.projects,
  });

  @override
  State<CompanyProjectsScreen> createState() => _CompanyProjectsScreenState();
}

class _CompanyProjectsScreenState extends State<CompanyProjectsScreen> {
  late List<Map<String, dynamic>> _projects;

  @override
  void initState() {
    super.initState();
    _projects = List.from(widget.projects);
  }

  Future<void> _reload() async {
    final all = await StorageService.getAllProjects();
    setState(() => _projects = all.where((p) => p['company'] == widget.company).toList());
  }

  Future<void> _completeProject(Map<String, dynamic> p) async {
    final ok = await _confirm(context, 'Mark as Completed', 'Mark this project as completed?',
        confirmLabel: 'Complete', confirmColor: Colors.green.shade600);
    if (ok) { await StorageService.completeProject(p['metadataPath'] as String); await _reload(); }
  }

  Future<void> _reactivate(Map<String, dynamic> p) async {
    final ok = await _confirm(context, 'Move to Live', 'Move this project back to Live?',
        confirmLabel: 'Move to Live', confirmColor: Colors.amber.shade700);
    if (ok) { await StorageService.reactivateProject(p['metadataPath'] as String); await _reload(); }
  }

  Future<void> _moveToQuote(Map<String, dynamic> p) async {
    final ok = await _confirm(context, 'Move to Quote', 'Move this project back to Quote (draft) state?',
        confirmLabel: 'Move to Quote', confirmColor: Colors.blue.shade700);
    if (ok) {
      await StorageService.moveToQuote(p['metadataPath'] as String);
      await _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved back to Quote history')));
    }
  }

  Future<void> _archiveProject(Map<String, dynamic> p) async {
    final ok = await _confirm(context, 'Archive Project', 'Archive this project? You can restore it from the Archive section.',
        confirmLabel: 'Archive', confirmColor: Colors.grey.shade700);
    if (ok) {
      await StorageService.archiveItem(p['metadataPath'] as String);
      await _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project archived')));
    }
  }

  Future<bool> _confirm(BuildContext ctx, String title, String content,
      {required String confirmLabel, required Color confirmColor}) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final live = _projects.where((p) => p['status'] == 'confirmed').toList();
    final completed = _projects.where((p) => p['status'] == 'completed').toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.company),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (live.isNotEmpty) ...[
            _SectionHeader(title: 'Live Projects', icon: Icons.bolt_rounded, color: const Color(0xFFE6A817)),
            const SizedBox(height: 8),
            ...live.map((p) => _ProjectCard(
              key: ValueKey(p['fileName']),
              project: p,
              isLive: true,
              isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: p))).then((_) => _reload()),
              onComplete: () => _completeProject(p),
              onMoveToQuote: () => _moveToQuote(p),
              onArchive: () => _archiveProject(p),
            )),
            const SizedBox(height: 20),
          ],
          if (completed.isNotEmpty) ...[
            _SectionHeader(title: 'Completed Projects', icon: Icons.check_circle_rounded, color: const Color(0xFF2E7D32)),
            const SizedBox(height: 8),
            ...completed.map((p) => _ProjectCard(
              key: ValueKey(p['fileName']),
              project: p,
              isLive: false,
              isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: p))).then((_) => _reload()),
              onReactivate: () => _reactivate(p),
              onMoveToQuote: () => _moveToQuote(p),
              onArchive: () => _archiveProject(p),
            )),
          ],
          if (live.isEmpty && completed.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(children: [
                  Icon(Icons.folder_open_rounded, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No projects found', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface)),
    ]);
  }
}

// ── Project Card ───────────────────────────────────────────────────────────────

class _ProjectCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final bool isLive;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onReactivate;
  final VoidCallback onMoveToQuote;
  final VoidCallback onArchive;

  const _ProjectCard({
    super.key,
    required this.project,
    required this.isLive,
    required this.isDark,
    required this.onTap,
    this.onComplete,
    this.onReactivate,
    required this.onMoveToQuote,
    required this.onArchive,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _drag = 0;
  bool _isOpen = false;

  // Live: complete + moveToQuote + archive = 3 buttons → wider panel
  // Completed: reactivate + moveToQuote + archive = 3 buttons → wider panel
  static const double _revealFraction = 0.38;
  static const double _snapThreshold = 0.15;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _anim = _ctrl.drive(CurveTween(curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
      onTap: () { _snapClose(); onTap(); },
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _actionPanel(double w) {
    final bg = widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    return ClipRRect(
      borderRadius: const BorderRadius.only(topRight: Radius.circular(14), bottomRight: Radius.circular(14)),
      child: Container(
        width: w, color: bg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (widget.isLive)
              _actionBtn(Icons.check_rounded, Colors.green.shade600, widget.onComplete!),
            if (!widget.isLive)
              _actionBtn(Icons.replay_rounded, Colors.amber.shade600, widget.onReactivate!),
            _actionBtn(Icons.description_rounded, Colors.blue.shade600, widget.onMoveToQuote),
            _actionBtn(Icons.archive_rounded, Colors.grey.shade600, widget.onArchive),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ProjectService.generateProjectId(
        widget.project['company'] as String, widget.project['fileName'] as String);
    final budget = ProjectService.totalBudget(widget.project['components'] as List);
    final isLive = widget.isLive;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                      left: fullWidth - offset, top: 0, bottom: 0, width: maxSwipe,
                      child: _actionPanel(maxSwipe),
                    ),
                    Transform.translate(
                      offset: Offset(-offset, 0),
                      child: SizedBox(
                        width: fullWidth,
                        child: Material(
                          color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          elevation: 2,
                          shadowColor: Colors.black12,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _isOpen ? _snapClose() : widget.onTap(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              child: Row(children: [
                                // Status indicator bar
                                Container(
                                  width: 4, height: 44,
                                  decoration: BoxDecoration(
                                    color: isLive ? const Color(0xFFE6A817) : const Color(0xFF2E7D32),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(widget.project['company'] as String,
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
                                              color: widget.isDark ? Colors.white : Colors.black87)),
                                      const SizedBox(height: 3),
                                      Text('ID: $projectId',
                                          style: TextStyle(fontSize: 12,
                                              color: widget.isDark ? Colors.white54 : Colors.black45)),
                                      const SizedBox(height: 2),
                                      Text('Budget: ${ProjectService.formatAmount(budget)}',
                                          style: TextStyle(fontSize: 12,
                                              color: widget.isDark ? Colors.white70 : Colors.black54)),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isLive ? const Color(0xFFFFF3CD) : const Color(0xFFD4EDDA),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isLive ? '🟡 Live' : '🟢 Done',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Icon(Icons.chevron_left, size: 14, color: Colors.grey.shade400),
                                  ],
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

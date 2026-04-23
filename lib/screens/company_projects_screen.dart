import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/project_service.dart';
import 'project_detail_screen.dart';

class CompanyProjectsScreen extends StatefulWidget {
  final String companyName;

  const CompanyProjectsScreen({
    super.key,
    required this.companyName,
  });

  @override
  State<CompanyProjectsScreen> createState() => _CompanyProjectsScreenState();
}

class _CompanyProjectsScreenState extends State<CompanyProjectsScreen> {
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _liveProjects = [];
  List<Map<String, dynamic>> _completedProjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allProjects = await StorageService.getAllProjects();
      final companyProjects = allProjects
          .where((project) => project['company'] == widget.companyName)
          .toList();

      final live = companyProjects
          .where((project) => project['status'] == 'confirmed')
          .toList();
      
      final completed = companyProjects
          .where((project) => project['status'] == 'completed')
          .toList();

      setState(() {
        _projects = companyProjects;
        _liveProjects = live;
        _completedProjects = completed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading projects: $e')),
        );
      }
    }
  }

  void _navigateToProject(Map<String, dynamic> project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailScreen(project: project),
      ),
    ).then((_) => _loadProjects());
  }

  Future<void> _completeProject(Map<String, dynamic> project) async {
    try {
      await StorageService.completeProject(project['metadataPath']);
      _loadProjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project marked as completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing project: $e')),
        );
      }
    }
  }

  Future<void> _moveToQuote(Map<String, dynamic> project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Quote'),
        content: Text('Move ${ProjectService.generateProjectId(project['company'], project['fileName'] ?? '')} back to quotes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFC40000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await StorageService.moveToQuote(project['metadataPath']);
        _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project moved back to quotes')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error moving project: $e')),
          );
        }
      }
    }
  }

  Future<void> _archiveProject(Map<String, dynamic> project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Project'),
        content: Text('Archive ${ProjectService.generateProjectId(project['company'], project['fileName'] ?? '')}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
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
        await StorageService.archiveItem(project['metadataPath']);
        _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project archived')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error archiving project: $e')),
          );
        }
      }
    }
  }

  Future<void> _reactivateProject(Map<String, dynamic> project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivate Project'),
        content: Text('Move ${ProjectService.generateProjectId(project['company'], project['fileName'] ?? '')} back to live projects?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await StorageService.reactivateProject(project['metadataPath']);
        _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project reactivated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reactivating project: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.companyName),
        backgroundColor: const Color(0xFFC40000),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? const Center(
                  child: Text(
                    'No projects found for this company',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_liveProjects.isNotEmpty) ...[
                        _buildSectionHeader('🟡 Live Projects', _liveProjects.length),
                        const SizedBox(height: 16),
                        ..._liveProjects.map((project) => _buildLiveProjectCard(project)),
                        const SizedBox(height: 24),
                      ],
                      if (_completedProjects.isNotEmpty) ...[
                        _buildSectionHeader('🟢 Completed Projects', _completedProjects.length),
                        const SizedBox(height: 16),
                        ..._completedProjects.map((project) => _buildCompletedProjectCard(project)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Text(
      '$title ($count)',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: const Color(0xFFC40000),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLiveProjectCard(Map<String, dynamic> project) {
    final projectId = ProjectService.generateProjectId(project['company'], project['fileName'] ?? '');
    final totalBudget = ProjectService.totalBudget(project['components'] ?? []);
    
    return Dismissible(
      key: Key(project['metadataPath']),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.orange,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Archive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.archive, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Complete project
          await _completeProject(project);
          return false;
        } else if (direction == DismissDirection.endToStart) {
          // Archive project
          await _archiveProject(project);
          return false;
        }
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _navigateToProject(project),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        projectId,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Live',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'complete':
                            _completeProject(project);
                            break;
                          case 'moveToQuote':
                            _moveToQuote(project);
                            break;
                          case 'archive':
                            _archiveProject(project);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'complete',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Complete'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'moveToQuote',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Move to Quote'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Archive'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Date: ${project['date']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Budget: ${ProjectService.formatAmount(totalBudget)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Color(0xFFC40000),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '← Swipe right to complete • Swipe left to archive →',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedProjectCard(Map<String, dynamic> project) {
    final projectId = ProjectService.generateProjectId(project['company'], project['fileName'] ?? '');
    final totalBudget = ProjectService.totalBudget(project['components'] ?? []);
    
    return Dismissible(
      key: Key(project['metadataPath']),
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.refresh, color: Colors.white),
            SizedBox(width: 8),
            Text('Reactivate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.orange,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Archive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.archive, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Reactivate project
          await _reactivateProject(project);
          return false;
        } else if (direction == DismissDirection.endToStart) {
          // Archive project
          await _archiveProject(project);
          return false;
        }
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _navigateToProject(project),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        projectId,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'reactivate':
                            _reactivateProject(project);
                            break;
                          case 'moveToQuote':
                            _moveToQuote(project);
                            break;
                          case 'archive':
                            _archiveProject(project);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'reactivate',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Move back to Live'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'moveToQuote',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Move to Quote'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Archive'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Date: ${project['date']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Budget: ${ProjectService.formatAmount(totalBudget)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Color(0xFFC40000),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '← Swipe right to reactivate • Swipe left to archive →',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
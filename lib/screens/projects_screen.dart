import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'company_projects_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Map<String, List<Map<String, dynamic>>> groupedProjects = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final all = await StorageService.getAllProjects();
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final p in all) {
      grouped.putIfAbsent(p['company'] as String, () => []).add(p);
    }
    setState(() {
      groupedProjects = grouped;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final companies = groupedProjects.keys.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Projects'), centerTitle: true, elevation: 0),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedProjects.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.work_outline_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No confirmed projects yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: companies.length,
                  itemBuilder: (context, i) {
                    final company = companies[i];
                    final projects = groupedProjects[company]!;
                    final liveCount = projects.where((p) => p['status'] == 'confirmed').length;
                    final completedCount = projects.where((p) => p['status'] == 'completed').length;
                    final total = projects.length;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 2,
                        shadowColor: Colors.black12,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompanyProjectsScreen(company: company, projects: projects),
                            ),
                          ).then((_) => _load()),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Folder icon with accent
                                Container(
                                  width: 52, height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC40000).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.folder_rounded, size: 30, color: Color(0xFFC40000)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(company,
                                          style: TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          )),
                                      const SizedBox(height: 6),
                                      Row(children: [
                                        if (liveCount > 0) _badge('🟡 $liveCount Live', const Color(0xFFFFF3CD)),
                                        if (liveCount > 0 && completedCount > 0) const SizedBox(width: 6),
                                        if (completedCount > 0) _badge('🟢 $completedCount Done', const Color(0xFFD4EDDA)),
                                      ]),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('$total', style: const TextStyle(
                                        fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFC40000))),
                                    Text('project${total > 1 ? 's' : ''}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
    );
  }
}

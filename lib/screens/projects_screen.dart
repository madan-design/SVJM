import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<String> get _filteredCompanies {
    if (_searchQuery.isEmpty) return groupedProjects.keys.toList();
    return groupedProjects.keys
        .where((company) => company.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 800; // implies desktop web layout generally
    final isDesktopWeb = kIsWeb && isWide;
    final companies = _filteredCompanies;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
      appBar: isDesktopWeb ? null : AppBar(
        title: const Text('Projects', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _buildSearchBar(isDark),
          ),
        ),
      ),
      body: Column(
        children: [
          if (isDesktopWeb)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: _buildSearchBar(isDark),
            ),
          Expanded(
            child: isLoading
                ? _buildLoadingState(isDark)
                : groupedProjects.isEmpty
                    ? _buildEmptyState(isDark)
                    : companies.isEmpty
                        ? _buildNoResultsState(isDark)
                        : _buildProjectsList(companies, isDark, isWide),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search companies...',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey.shade500, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFFC40000),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text('Loading projects...', style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 14,
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.work_outline_rounded, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text('No confirmed projects yet', 
              style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Confirmed quotes will appear here as projects', 
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text('No companies found', 
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Try a different search term', 
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildProjectsList(List<String> companies, bool isDark, bool isWide) {
    if (isWide) {
      return _buildGridLayout(companies, isDark);
    } else {
      return _buildListLayout(companies, isDark);
    }
  }

  Widget _buildGridLayout(List<String> companies, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 3,
        childAspectRatio: 1.6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: companies.length,
      itemBuilder: (context, index) {
        final company = companies[index];
        final projects = groupedProjects[company]!;
        return _buildModernCompanyCard(company, projects, isDark, isGrid: true);
      },
    );
  }

  Widget _buildListLayout(List<String> companies, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: companies.length,
      itemBuilder: (context, index) {
        final company = companies[index];
        final projects = groupedProjects[company]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildModernCompanyCard(company, projects, isDark, isGrid: false),
        );
      },
    );
  }

  Widget _buildModernCompanyCard(String company, List<Map<String, dynamic>> projects, bool isDark, {required bool isGrid}) {
    final liveCount = projects.where((p) => p['status'] == 'confirmed').length;
    final completedCount = projects.where((p) => p['status'] == 'completed').length;
    final total = projects.length;
    
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyProjectsScreen(companyName: company),
        ),
      ).then((_) => _load()),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(isGrid ? 16 : 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isGrid ? _buildGridCardContent(company, liveCount, completedCount, total, isDark) 
                     : _buildListCardContent(company, liveCount, completedCount, total, isDark),
      ),
    );
  }

  Widget _buildGridCardContent(String company, int liveCount, int completedCount, int total, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC40000), Color(0xFFA30000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.business_rounded, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC40000).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$total',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC40000),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                company,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'project${total > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const Spacer(),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (liveCount > 0) _buildStatusBadge('$liveCount Live', const Color(0xFFF59E0B)),
                  if (completedCount > 0) _buildStatusBadge('$completedCount Done', const Color(0xFF10B981)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListCardContent(String company, int liveCount, int completedCount, int total, bool isDark) {
    return Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC40000), Color(0xFFA30000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.business_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                company,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '$total project${total > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (liveCount > 0) _buildStatusBadge('$liveCount Live', const Color(0xFFF59E0B)),
                  if (liveCount > 0 && completedCount > 0) const SizedBox(width: 6),
                  if (completedCount > 0) _buildStatusBadge('$completedCount Done', const Color(0xFF10B981)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.arrow_forward_ios_rounded, 
              color: Colors.grey.shade500, size: 14),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/auth_service.dart';
import '../widgets/main_layout.dart';
import '../widgets/app_shell.dart';
import '../screens/form_slides.dart';
import '../screens/history_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/archive_screen.dart';
import '../screens/admin/assign_project_screen.dart';

/// Layout manager that provides persistent navigation on web
class LayoutManager extends StatefulWidget {
  final bool isAdmin;
  
  const LayoutManager({super.key, required this.isAdmin});

  @override
  State<LayoutManager> createState() => _LayoutManagerState();
}

class _LayoutManagerState extends State<LayoutManager> {
  String _userName = 'User';
  String _userRole = 'user';
  int _selectedIndex = 0;
  Widget? _currentContent;
  Widget? _subContent; // For nested content within main sections
  String? _subTitle; // Title for sub-content

  // Navigation items for admin
  static const _adminNavItems = [
    MainLayoutNavItem(label: 'Dashboard', icon: Icons.dashboard_rounded),
    MainLayoutNavItem(label: 'Quote Generator', icon: Icons.description_rounded),
    MainLayoutNavItem(label: 'Projects', icon: Icons.work_rounded),
    MainLayoutNavItem(label: 'Archive', icon: Icons.archive_rounded),
    MainLayoutNavItem(label: 'Assign Designer', icon: Icons.assignment_rounded),
  ];

  // Navigation items for regular user
  static const _userNavItems = [
    MainLayoutNavItem(label: 'Dashboard', icon: Icons.dashboard_rounded),
    MainLayoutNavItem(label: 'Quote Generator', icon: Icons.description_rounded),
    MainLayoutNavItem(label: 'Projects', icon: Icons.work_rounded),
    MainLayoutNavItem(label: 'Archive', icon: Icons.archive_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _updateContent();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.getProfile();
    if (mounted && profile != null) {
      setState(() {
        _userName = profile['name'] ?? 'User';
        _userRole = profile['role'] ?? 'user';
      });
    }
  }

  void _updateContent() {
    setState(() {
      _currentContent = _getContentForIndex(_selectedIndex);
      _subContent = null; // Clear sub-content when changing main nav
      _subTitle = null;
    });
  }

  void _showSubContent(Widget content, [String? title]) {
    setState(() {
      _subContent = content;
      _subTitle = title;
    });
  }

  void _clearSubContent() {
    setState(() {
      _subContent = null;
      _subTitle = null;
    });
  }

  Widget _getContentForIndex(int index) {
    if (widget.isAdmin) {
      switch (index) {
        case 0: return const _DashboardContent();
        case 1: return const _QuoteGeneratorContent();
        case 2: return const _ProjectsContent();
        case 3: return const _ArchiveContent();
        case 4: return const _AssignDesignerContent();
        default: return const _DashboardContent();
      }
    } else {
      switch (index) {
        case 0: return const _DashboardContent();
        case 1: return const _QuoteGeneratorContent();
        case 2: return const _ProjectsContent();
        case 3: return const _ArchiveContent();
        default: return const _DashboardContent();
      }
    }
  }

  String _getTitleForIndex(int index) {
    final navItems = widget.isAdmin ? _adminNavItems : _userNavItems;
    return navItems[index].label;
  }

  String _getCurrentTitle() {
    if (_subTitle != null) return _subTitle!;
    return _getTitleForIndex(_selectedIndex);
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
      _updateContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 900;
    final navItems = widget.isAdmin ? _adminNavItems : _userNavItems;

    if (isDesktop) {
      return MainLayout(
        title: _getCurrentTitle(),
        navItems: navItems,
        selectedIndex: _selectedIndex,
        onNavTap: _onNavTap,
        userName: _userName,
        userRole: _userRole,
        onLogout: () => confirmLogout(context),
        showBackButton: _subContent != null,
        onBack: _clearSubContent,
        child: _subContent ?? _currentContent ?? const _DashboardContent(),
      );
    }

    // Mobile: show traditional home screen
    return _currentContent ?? const _DashboardContent();
  }
}

// ── Content Widgets ────────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 900;
    
    if (!isDesktop) {
      // Mobile: show traditional home screen cards
      return _MobileDashboard();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to SVJM', style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
          const SizedBox(height: 6),
          Text('Manage your quotes, projects, and business operations.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 32),
          
          // Quick Actions
          Text('Quick Actions', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
          const SizedBox(height: 16),
          
          Wrap(spacing: 12, runSpacing: 12, children: [
            _QuickActionCard('Create Quote', Icons.add_circle_outline, const Color(0xFFC40000), isDark, () {
              final layoutState = context.findAncestorStateOfType<_LayoutManagerState>();
              layoutState?._onNavTap(1); // Navigate to Quote Generator
            }),
            _QuickActionCard('View Projects', Icons.work_outline, const Color(0xFF1565C0), isDark, () {
              final layoutState = context.findAncestorStateOfType<_LayoutManagerState>();
              layoutState?._onNavTap(2); // Navigate to Projects
            }),
            _QuickActionCard('Archive', Icons.archive, const Color(0xFF2E7D32), isDark, () {
              final layoutState = context.findAncestorStateOfType<_LayoutManagerState>();
              layoutState?._onNavTap(3); // Navigate to Archive
            }),
          ]),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  
  const _QuickActionCard(this.title, this.icon, this.color, this.isDark, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF1A1A2E)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _MobileDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Return the traditional mobile home screen
    // This will be implemented to show the card-based navigation
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVJM'),
        backgroundColor: const Color(0xFFC40000),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Mobile Dashboard - Traditional Home Screen'),
      ),
    );
  }
}

class _QuoteGeneratorContent extends StatelessWidget {
  const _QuoteGeneratorContent();

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 900;
    
    if (!isDesktop) {
      // Mobile: navigate to full screen
      return const FormSlides();
    }

    // Web: show quote generator menu in content area
    return _WebQuoteGenerator();
  }
}

class _WebQuoteGenerator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quote Generator', style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text('Create new quotes or browse history',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 32),
          
          Wrap(spacing: 16, runSpacing: 16, children: [
            _buildMenuCard(
              context,
              'Create Quote',
              'Start a new quote',
              Icons.add_circle_outline_rounded,
              const Color(0xFFC40000),
              () => _navigateToCreateQuote(context),
            ),
            _buildMenuCard(
              context,
              'Quote History',
              'View all past quotes',
              Icons.history_rounded,
              const Color(0xFF1565C0),
              () => _navigateToHistory(context),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, 
      IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      width: 280,
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ])),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ]),
          ),
        ),
      ),
    );
  }

  void _navigateToCreateQuote(BuildContext context) {
    // Find the layout manager and switch to create quote content
    final layoutState = context.findAncestorStateOfType<_LayoutManagerState>();
    layoutState?._showSubContent(const FormSlides(), 'Create Quote');
  }

  void _navigateToHistory(BuildContext context) {
    // Find the layout manager and switch to history content
    final layoutState = context.findAncestorStateOfType<_LayoutManagerState>();
    layoutState?._showSubContent(const HistoryScreen(), 'Quote History');
  }
}

class _ProjectsContent extends StatelessWidget {
  const _ProjectsContent();

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 900;
    
    if (!isDesktop) {
      return const ProjectsScreen();
    }

    // Web: show projects in content area
    return const ProjectsScreen();
  }
}

class _ArchiveContent extends StatelessWidget {
  const _ArchiveContent();

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 900;
    
    if (!isDesktop) {
      return const ArchiveScreen();
    }

    // Web: show archive in content area
    return const ArchiveScreen();
  }
}

class _AssignDesignerContent extends StatelessWidget {
  const _AssignDesignerContent();

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 900;
    
    if (!isDesktop) {
      return const AssignProjectScreen();
    }

    // Web: show assign designer in content area
    return const AssignProjectScreen();
  }
}
import 'package:flutter/material.dart';
import 'form_slides.dart';
import 'history_screen.dart';
import 'projects_screen.dart';
import 'archive_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Gradient app bar
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFC40000), Color(0xFF8B0000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SVJM',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Mould & Solutions',
                            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                ),
              ),
                titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
            ),
            backgroundColor: const Color(0xFFC40000),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                _NavCard(
                  title: 'Quote Generator',
                  subtitle: 'Create & manage quotes',
                  icon: Image.asset('assets/Quote generator.png', width: 32, height: 32, fit: BoxFit.contain),
                  accentColor: const Color(0xFFC40000),
                  bgColor: isDark ? const Color(0xFF2A1A1A) : const Color(0xFFFFF5F5),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _QuoteMenuScreen())),
                ),

                const SizedBox(height: 12),

                _NavCard(
                  title: 'Projects',
                  subtitle: 'Track live & completed projects',
                  icon: Image.asset('assets/projects.png', width: 32, height: 32, fit: BoxFit.contain),
                  accentColor: const Color(0xFF1565C0),
                  bgColor: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F6FF),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
                ),

                const SizedBox(height: 12),

                _NavCard(
                  title: 'Archive',
                  subtitle: 'View & restore archived items',
                  icon: const Icon(Icons.archive_rounded, size: 32, color: Color(0xFF555555)),
                  accentColor: const Color(0xFF555555),
                  bgColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveScreen())),
                ),

              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final Color accentColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteMenuScreen extends StatelessWidget {
  const _QuoteMenuScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quote Generator'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MenuCard(
              icon: Icons.add_circle_outline_rounded,
              label: 'Create Quote',
              subtitle: 'Start a new quote',
              color: const Color(0xFFC40000),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormSlides())),
            ),
            const SizedBox(height: 16),
            _MenuCard(
              icon: Icons.history_rounded,
              label: 'History',
              subtitle: 'View all past quotes',
              color: const Color(0xFF1565C0),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
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
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }
}

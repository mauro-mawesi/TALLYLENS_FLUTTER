import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  static const _tabRoutes = ['/', '/dashboard', '/notifications', '/profile'];
  late final AnimationController _fabController;
  int _lastIndex = -1;
  String? _lastRoute;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  int _locationToTabIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabRoutes.length; i++) {
      if (loc == _tabRoutes[i] || loc.startsWith(_tabRoutes[i] + '/')) return i;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    context.go(_tabRoutes[index]);
  }

  void _maybeAnimateFab(int currentIndex, String currentRoute) {
    final cameFromAdd = _lastRoute != null && _lastRoute!.startsWith('/add');
    if (currentIndex == 0 && (_lastIndex != 0 || cameFromAdd)) {
      // Pequeña animación de scale + glow al volver a Home
      _fabController.forward(from: 0);
    }
    _lastIndex = currentIndex;
    _lastRoute = currentRoute;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final extra = bottomPad > 0 ? 8.0 : 0.0; // dar un pequeño margen sin crecer demasiado
    final currentIndex = _locationToTabIndex(context);
    final currentRoute = GoRouterState.of(context).uri.toString();
    _maybeAnimateFab(currentIndex, currentRoute);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: BottomAppBar(
            height: 64 + extra,
            color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavIcon(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_outlined,
              label: l10n?.dashboardTitle ?? 'Home',
              active: currentIndex == 0,
              onTap: () => _onTap(context, 0),
            ),
            _NavIcon(
              icon: Icons.auto_graph_outlined,
              activeIcon: Icons.auto_graph_outlined,
              label: l10n?.insightsTab ?? 'Insights',
              active: currentIndex == 1,
              onTap: () => _onTap(context, 1),
            ),
            const SizedBox(width: 48), // espacio para el FAB
            _NavIcon(
              icon: Icons.notifications_outlined,
              activeIcon: Icons.notifications_outlined,
              label: l10n?.notificationsTab ?? 'Alerts',
              active: currentIndex == 2,
              onTap: () => _onTap(context, 2),
            ),
            _NavIcon(
              icon: Icons.person_outline,
              activeIcon: Icons.person_outline,
              label: l10n?.profileTitle ?? 'Profile',
              active: currentIndex == 3,
              onTap: () => _onTap(context, 3),
            ),
          ],
        ),
      ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          final t = CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack).value;
          final scale = 0.94 + (0.06 * t); // 0.94 -> 1.0
          final glow = 2.0 + (8.0 * t); // 2 -> 10 blur
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: cs.primary.withOpacity(0.55 * t), blurRadius: 24 * t + glow, spreadRadius: 1),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                child: Ink(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF8A2BE2), Color(0xFF00E3FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.push('/add'),
                    splashColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.12),
                    highlightColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.08),
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavIcon({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkResponse(
      onTap: onTap,
      splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              scale: active ? 1.08 : 1.0,
              child: Container(
                decoration: active
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, spreadRadius: 0.5)],
                      )
                    : null,
                child: Icon(active ? activeIcon : icon, color: color, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

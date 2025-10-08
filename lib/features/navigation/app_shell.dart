import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/physics.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  static const _tabRoutes = ['/', '/dashboard', '/budgets', '/notifications', '/profile'];
  late final AnimationController _fabController;
  late final AnimationController _fabVisibilityController;
  int _lastIndex = -1;
  String? _lastRoute;

  // Spring simulation for elastic effect
  final SpringDescription _spring = const SpringDescription(
    mass: 1.0,
    stiffness: 200.0,
    damping: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabVisibilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0, // Start visible
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    _fabVisibilityController.dispose();
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
    final cameFromAdd = _lastRoute != null && (_lastRoute!.startsWith('/add') || _lastRoute!.contains('/budgets/create'));

    // Show FAB on home (0) and budgets (2), hide on others
    final shouldShowFab = currentIndex == 0 || currentIndex == 2;

    if (shouldShowFab) {
      // Show with spring animation
      _fabVisibilityController.animateWith(
        SpringSimulation(_spring, 0.0, 1.0, _fabVisibilityController.velocity),
      );
      // Bounce animation when entering these screens
      if (currentIndex == 0 && (_lastIndex != 0 || cameFromAdd)) {
        _fabController.animateWith(SpringSimulation(_spring, 0.0, 1.0, 0.0));
      }
      if (currentIndex == 2 && (_lastIndex != 2 || cameFromAdd)) {
        _fabController.animateWith(SpringSimulation(_spring, 0.0, 1.0, 0.0));
      }
    } else {
      // Hide smoothly
      _fabVisibilityController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeInCubic);
    }

    _lastIndex = currentIndex;
    _lastRoute = currentRoute;
  }

  Widget _buildFabForRoute(BuildContext context, int currentIndex, ColorScheme cs) {
    // Determine action based on current screen
    final VoidCallback onTapAction;
    if (currentIndex == 0) {
      // Home screen - add receipt
      onTapAction = () => context.push('/add');
    } else if (currentIndex == 2) {
      // Budgets screen - create budget
      onTapAction = () => context.push('/budgets/create');
    } else {
      // Default - add receipt
      onTapAction = () => context.push('/add');
    }

    // Single animated FAB that changes functionality based on screen
    return AnimatedBuilder(
      animation: Listenable.merge([_fabController, _fabVisibilityController]),
      builder: (context, child) {
        // Spring-based animation for natural bounce
        final t = _fabController.value;

        // Apply spring simulation for visibility
        final simulation = SpringSimulation(_spring, 0.0, 1.0, 0.0);
        final visibility = _fabVisibilityController.value;

        // Scale with spring effect
        final scale = visibility;

        final glow = 2.0 + (8.0 * t);
        final opacity = visibility;

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.55 * t * opacity),
                    blurRadius: 24 * t + glow,
                    spreadRadius: 1,
                  ),
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
                    onTap: onTapAction,
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
          ),
        );
      },
    );
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
      bottomNavigationBar: AnimatedBuilder(
        animation: _fabVisibilityController,
        builder: (context, child) {
          // Spring-based visibility
          final visibility = _fabVisibilityController.value;

          final hasFab = visibility > 0.5;
          // Animate notch margin smoothly
          final notchMargin = 8.0 * visibility;

          // Add elastic squeeze effect to the bar itself
          final heightScale = 1.0 + (0.02 * (1.0 - visibility)); // Slight vertical squeeze

          return Transform.scale(
            scaleY: heightScale,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: BottomAppBar(
                  height: 68 + extra,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
                  shape: hasFab ? const CircularNotchedRectangle() : null,
                  notchMargin: notchMargin,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    // Simple scale + fade transition
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    key: ValueKey(hasFab),
                    mainAxisAlignment: hasFab ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceEvenly,
                    children: [
                      // Iconos se reacomodan según si hay FAB o no
                      if (hasFab) ...[
                        // Grupo izquierdo (3 iconos) cuando hay FAB
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                              _NavIcon(
                                icon: Icons.analytics_outlined,
                                activeIcon: Icons.analytics,
                                label: 'Budgets',
                                active: currentIndex == 2,
                                onTap: () => _onTap(context, 2),
                              ),
                            ],
                          ),
                        ),
                        // Espacio para el FAB
                        SizedBox(width: 72 * visibility),
                        // Grupo derecho (2 iconos)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _NavIcon(
                                icon: Icons.notifications_outlined,
                                activeIcon: Icons.notifications,
                                label: l10n?.notificationsTab ?? 'Alerts',
                                active: currentIndex == 3,
                                onTap: () => _onTap(context, 3),
                              ),
                              _NavIcon(
                                icon: Icons.person_outline,
                                activeIcon: Icons.person,
                                label: l10n?.profileTitle ?? 'Profile',
                                active: currentIndex == 4,
                                onTap: () => _onTap(context, 4),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Todos los iconos distribuidos uniformemente cuando no hay FAB
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
                        _NavIcon(
                          icon: Icons.analytics_outlined,
                          activeIcon: Icons.analytics,
                          label: 'Budgets',
                          active: currentIndex == 2,
                          onTap: () => _onTap(context, 2),
                        ),
                        _NavIcon(
                          icon: Icons.notifications_outlined,
                          activeIcon: Icons.notifications,
                          label: l10n?.notificationsTab ?? 'Alerts',
                          active: currentIndex == 3,
                          onTap: () => _onTap(context, 3),
                        ),
                        _NavIcon(
                          icon: Icons.person_outline,
                          activeIcon: Icons.person,
                          label: l10n?.profileTitle ?? 'Profile',
                          active: currentIndex == 4,
                          onTap: () => _onTap(context, 4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildFabForRoute(context, currentIndex, cs),
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.6);

    return InkResponse(
      onTap: onTap,
      splashColor: primaryColor.withOpacity(0.12),
      highlightColor: primaryColor.withOpacity(0.06),
      radius: 32,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with smooth scaling
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              scale: active ? 1.12 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: active
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(0.12),
                      )
                    : null,
                child: Icon(
                  active ? activeIcon : icon,
                  color: active ? primaryColor : inactiveColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Active indicator bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: active ? 24 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

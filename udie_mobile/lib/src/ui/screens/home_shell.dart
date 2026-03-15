import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_store.dart';
import '../../theme.dart';
import '../widgets/sync_badge.dart';
import 'map_screen.dart';
import 'news_screen.dart';
import 'route_screen.dart';
import 'sources_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final List<Widget> _pages;

  static const _destinations = [
    (
      icon: Icons.map_outlined,
      selectedIcon: Icons.map_rounded,
      label: 'Map',
    ),
    (
      icon: Icons.feed_outlined,
      selectedIcon: Icons.feed_rounded,
      label: 'Intel',
    ),
    (
      icon: Icons.alt_route_outlined,
      selectedIcon: Icons.alt_route_rounded,
      label: 'Route',
    ),
    (
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub_rounded,
      label: 'Sources',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Pages are created once and reused.  Each screen subscribes to the
    // store via its own ListenableBuilder, so they update independently
    // without causing the entire shell to rebuild.
    _pages = [
      MapScreen(store: widget.store),
      NewsScreen(store: widget.store),
      RouteScreen(store: widget.store),
      SourcesScreen(store: widget.store),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: UdieTheme.bgGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: _BlurAppBar(store: widget.store),
        body: IndexedStack(
          index: _index,
          children: _pages,
        ),
        bottomNavigationBar: _BottomNav(
          selectedIndex: _index,
          onChanged: (v) => setState(() => _index = v),
          destinations: _destinations,
        ),
      ),
    );
  }
}

// ── Blurred AppBar ────────────────────────────────────────────────────────────

class _BlurAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BlurAppBar({required this.store});

  final AppStore store;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final top = MediaQuery.of(context).padding.top;
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: kToolbarHeight + top,
              decoration: BoxDecoration(
                color: UdieTheme.bg.withValues(alpha: 0.72),
                border: const Border(
                  bottom: BorderSide(color: UdieTheme.border),
                ),
              ),
              padding: EdgeInsets.only(top: top, left: 16, right: 8),
              child: Row(
                children: [
                  // Logo mark
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: UdieTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(UdieTheme.radiusSm),
                      border: Border.all(
                        color: UdieTheme.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: UdieTheme.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UDIE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: UdieTheme.textPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '${store.area.city} · ${store.namespace}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: UdieTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sync badge
                  SyncBadge(state: store.syncState),
                  // Refresh button
                  IconButton(
                    tooltip: 'Sync now',
                    onPressed: store.refreshAll,
                    icon: AnimatedRotation(
                      turns: store.syncState == SyncState.connecting || store.syncState == SyncState.syncing ? 1 : 0,
                      duration: const Duration(milliseconds: 600),
                      child: const Icon(
                        Icons.sync_rounded,
                        size: 20,
                        color: UdieTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onChanged,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<
      ({
        IconData icon,
        IconData selectedIcon,
        String label,
      })> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UdieTheme.surface0,
        border: const Border(top: BorderSide(color: UdieTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: destinations[i].icon,
                    selectedIcon: destinations[i].selectedIcon,
                    label: destinations[i].label,
                    selected: selectedIndex == i,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: UdieTheme.durationMedium,
              curve: UdieTheme.curveDefault,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: widget.selected
                    ? UdieTheme.accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(UdieTheme.radiusFull),
              ),
              child: Icon(
                widget.selected ? widget.selectedIcon : widget.icon,
                color: widget.selected
                    ? UdieTheme.accent
                    : UdieTheme.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: UdieTheme.durationFast,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: widget.selected
                    ? UdieTheme.accent
                    : UdieTheme.textMuted,
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}

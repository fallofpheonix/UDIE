import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../state/app_store.dart';
import '../../theme/udie_theme.dart';
import '../widgets/sync_badge.dart';
import '../widgets/tactical_bottom_nav.dart';
import 'map_screen.dart';
import 'news_screen.dart';
import 'route_screen.dart';
import 'sources_screen.dart';
import 'telemetry_screen.dart';

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
      MapScreen(
        store: widget.store,
        onOpenRoutePlanner: () => setState(() => _index = 2),
      ),
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
        extendBody: true,
        appBar: _BlurAppBar(store: widget.store),
        body: IndexedStack(
          index: _index,
          children: _pages,
        ),
        bottomNavigationBar: TacticalBottomNav(
          currentIndex: _index,
          onTap: (v) => setState(() => _index = v),
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
                  IconButton(
                    tooltip: 'Telemetry',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TelemetryScreen(store: store),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.radar_rounded,
                      size: 20,
                      color: UdieTheme.textSecondary,
                    ),
                  ),
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

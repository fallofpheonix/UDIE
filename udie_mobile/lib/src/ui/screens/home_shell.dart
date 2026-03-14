import 'package:flutter/material.dart';

import '../../state/app_store.dart';
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final pages = [
          MapScreen(store: widget.store),
          NewsScreen(store: widget.store),
          RouteScreen(store: widget.store),
          SourcesScreen(store: widget.store),
        ];

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF18263A)],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UDIE'),
                  Text(
                    '${widget.store.area.city} • ${widget.store.namespace}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              actions: [
                SyncBadge(state: widget.store.syncState),
                IconButton(
                  tooltip: 'Sync now',
                  onPressed: widget.store.refreshAll,
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
            body: IndexedStack(index: _index, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (v) => setState(() => _index = v),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.feed_outlined),
                  selectedIcon: Icon(Icons.feed),
                  label: 'News',
                ),
                NavigationDestination(
                  icon: Icon(Icons.alt_route_outlined),
                  selectedIcon: Icon(Icons.alt_route),
                  label: 'Route',
                ),
                NavigationDestination(
                  icon: Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub),
                  label: 'Sources',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

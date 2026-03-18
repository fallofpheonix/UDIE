import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/app_models.dart';
import '../../state/app_store.dart';
import '../../theme/udie_theme.dart';
import '../widgets/skeleton_loader.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final DateFormat _formatter;

  @override
  void initState() {
    super.initState();
    _formatter = DateFormat('dd MMM, HH:mm');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

        return Column(
          children: [
            SizedBox(height: topPad),
            // ── Category filter strip ──────────────────────────────────────────
            SizedBox(
              height: 48,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: UdieTheme.sp12,
                  vertical: UdieTheme.sp6,
                ),
                scrollDirection: Axis.horizontal,
                children: [
                  // "All" chip
                  _CategoryChip(
                    category: 'All',
                    icon: Icons.apps_rounded,
                    selected: store.activeNewsCategories.isEmpty,
                    color: UdieTheme.accent,
                    onTap: () {
                      store.clearActiveCategories();
                      store.refreshNewsOnly();
                    },
                  ),
                  const SizedBox(width: UdieTheme.sp6),
                  ...store.availableCategories.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: UdieTheme.sp6),
                      child: _CategoryChip(
                        category: c,
                        icon: UdieTheme.categoryIcon(c),
                        selected: store.activeNewsCategories.contains(c),
                        color: UdieTheme.categoryColor(c),
                        onTap: () {
                          store.toggleCategory(c);
                          store.refreshNewsOnly();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── News list ──────────────────────────────────────────────────────
            Expanded(
              child: (store.syncState == SyncState.connecting || store.syncState == SyncState.syncing) && store.news.isEmpty
                  ? const _LoadingSkeleton()
                  : store.news.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          onRefresh: store.refreshNewsOnly,
                          color: UdieTheme.accent,
                          backgroundColor: UdieTheme.surface1,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              UdieTheme.sp12,
                              UdieTheme.sp8,
                              UdieTheme.sp12,
                              UdieTheme.sp24,
                            ),
                            itemCount: store.news.length,
                            itemBuilder: (context, index) {
                              final item = store.news[index];
                              return _NewsCard(item: item, formatter: _formatter);
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String category;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: UdieTheme.durationFast,
        curve: UdieTheme.curveDefault,
        padding: const EdgeInsets.symmetric(
          horizontal: UdieTheme.sp10,
          vertical: UdieTheme.sp4,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : UdieTheme.surface2.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(UdieTheme.radiusFull),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.6)
                : UdieTheme.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? color : UdieTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              category,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : UdieTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── News card ─────────────────────────────────────────────────────────────────

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.formatter});

  final AreaNewsItem item;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    final catColor = UdieTheme.categoryColor(item.category);
    final catIcon = UdieTheme.categoryIcon(item.category);

    return Container(
      margin: const EdgeInsets.only(bottom: UdieTheme.sp10),
      decoration: BoxDecoration(
        color: UdieTheme.surface1,
        borderRadius: BorderRadius.circular(UdieTheme.radiusLg),
        border: Border.all(color: UdieTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openLink(item.url),
          splashColor: catColor.withValues(alpha: 0.06),
          highlightColor: catColor.withValues(alpha: 0.04),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(
                  width: 3,
                  color: catColor,
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(UdieTheme.sp14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category + time
                        Row(
                          children: [
                            Icon(catIcon, size: 12, color: catColor),
                            const SizedBox(width: 4),
                            Text(
                              item.category,
                              style: TextStyle(
                                color: catColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              formatter.format(item.publishedAt.toLocal()),
                              style: const TextStyle(
                                fontSize: 11,
                                color: UdieTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: UdieTheme.sp8),
                        // Title
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: UdieTheme.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: UdieTheme.sp6),
                        // Summary
                        Text(
                          item.summary,
                          style: const TextStyle(
                            fontSize: 12,
                            color: UdieTheme.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: UdieTheme.sp8),
                        // Source + link hint
                        Row(
                          children: [
                            const Icon(
                              Icons.sensors_rounded,
                              size: 11,
                              color: UdieTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.source,
                              style: const TextStyle(
                                fontSize: 11,
                                color: UdieTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (item.url.isNotEmpty)
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 12,
                                color: UdieTheme.accent,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        UdieTheme.sp12,
        UdieTheme.sp8,
        UdieTheme.sp12,
        UdieTheme.sp24,
      ),
      itemCount: 5,
      itemBuilder: (_, index) => Container(
        margin: const EdgeInsets.only(bottom: UdieTheme.sp10),
        padding: const EdgeInsets.all(UdieTheme.sp14),
        decoration: BoxDecoration(
          color: UdieTheme.surface1,
          borderRadius: BorderRadius.circular(UdieTheme.radiusLg),
          border: Border.all(color: UdieTheme.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 80, height: 11),
            SizedBox(height: 10),
            SkeletonText(lines: 2),
            SizedBox(height: 8),
            SkeletonBox(width: 120, height: 10),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: UdieTheme.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: UdieTheme.border),
            ),
            child: const Icon(
              Icons.feed_outlined,
              size: 28,
              color: UdieTheme.textMuted,
            ),
          ),
          const SizedBox(height: UdieTheme.sp16),
          const Text(
            'No intelligence signals',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: UdieTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Adjust filters or sync to load the latest feed.',
            style: TextStyle(
              fontSize: 13,
              color: UdieTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

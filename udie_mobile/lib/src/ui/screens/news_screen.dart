import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../state/app_store.dart';
import '../../theme.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM, HH:mm');

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: store.availableCategories
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryChip(
                      category: c,
                      selected: store.activeNewsCategories.contains(c),
                      onSelected: (_) {
                        store.toggleCategory(c);
                        store.refreshNewsOnly();
                      },
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: store.refreshNewsOnly,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
              itemCount: store.news.length,
              itemBuilder: (context, index) {
                final item = store.news[index];
                final catColor = UdieTheme.categoryColor(item.category);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openLink(item.url),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: catColor.withValues(alpha: 0.55),
                                  ),
                                ),
                                child: Text(
                                  item.category,
                                  style: TextStyle(
                                    color: catColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(item.summary),
                          const SizedBox(height: 8),
                          Text(
                            '${item.source} • ${formatter.format(item.publishedAt.toLocal())}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }
}

/// A filter chip that uses the category's theme color when selected.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final String category;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final color = UdieTheme.categoryColor(category);
    return FilterChip(
      selected: selected,
      label: Text(category),
      selectedColor: color.withValues(alpha: 0.25),
      checkmarkColor: color,
      side: selected
          ? BorderSide(color: color.withValues(alpha: 0.7))
          : BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      onSelected: onSelected,
    );
  }
}


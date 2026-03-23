import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../state/app_store.dart';
import '../../theme/udie_theme.dart';
import '../widgets/ui_components.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _radius;
  late String _selectedCity;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final area = widget.store.area;
    _baseUrl = TextEditingController(text: widget.store.baseUrl);
    _selectedCity = kCityCoordinates.keys.contains(area.city)
        ? area.city
        : kOperationalCityName;
    _lat = TextEditingController(text: area.center.latitude.toStringAsFixed(6));
    _lng = TextEditingController(
      text: area.center.longitude.toStringAsFixed(6),
    );
    _radius = TextEditingController(text: area.radiusKm.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final topPad =
        MediaQuery.of(context).padding.top + kToolbarHeight + UdieTheme.sp8;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        UdieTheme.sp16,
        topPad + UdieTheme.sp8,
        UdieTheme.sp16,
        UdieTheme.sp32,
      ),
      children: [
        // ── Workspace section ─────────────────────────────────────────────
        const SectionHeader('Workspace'),
        const SizedBox(height: UdieTheme.sp12),
        Container(
          padding: const EdgeInsets.all(UdieTheme.sp16),
          decoration: BoxDecoration(
            color: UdieTheme.surface1,
            borderRadius: BorderRadius.circular(UdieTheme.radiusLg),
            border: Border.all(color: UdieTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backend URL
              TextField(
                controller: _baseUrl,
                style: const TextStyle(
                  fontSize: 13,
                  color: UdieTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  labelText: 'Backend Base URL Override',
                  prefixIcon: Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: UdieTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: UdieTheme.sp12),
              // City picker
              DropdownButtonFormField<String>(
                initialValue: _selectedCity,
                dropdownColor: UdieTheme.surface2,
                style: const TextStyle(
                  color: UdieTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(
                    Icons.location_city_rounded,
                    size: 16,
                    color: UdieTheme.textMuted,
                  ),
                ),
                items: kCityCoordinates.keys
                    .map(
                      (city) => DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  final center = kCityCoordinates[value]!;
                  setState(() {
                    _selectedCity = value;
                    _lat.text = center[0].toStringAsFixed(6);
                    _lng.text = center[1].toStringAsFixed(6);
                  });
                },
              ),
              const SizedBox(height: UdieTheme.sp12),
              // Lat / Lng / Radius
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lat,
                      style: const TextStyle(
                        fontSize: 12,
                        color: UdieTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(labelText: 'Lat'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: UdieTheme.sp8),
                  Expanded(
                    child: TextField(
                      controller: _lng,
                      style: const TextStyle(
                        fontSize: 12,
                        color: UdieTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(labelText: 'Lng'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: UdieTheme.sp8),
                  SizedBox(
                    width: 88,
                    child: TextField(
                      controller: _radius,
                      style: const TextStyle(
                        fontSize: 12,
                        color: UdieTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(labelText: 'Km'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UdieTheme.sp16),
              // Apply button
              AnimatedSwitcher(
                duration: UdieTheme.durationFast,
                child: _isSaving
                    ? Container(
                        key: const ValueKey('saving'),
                        height: 48,
                        decoration: BoxDecoration(
                          color: UdieTheme.accent.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(UdieTheme.radiusMd),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                UdieTheme.accent,
                              ),
                            ),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        key: const ValueKey('apply'),
                        onPressed: () => _applyAndSync(store),
                        icon: const Icon(
                          Icons.sync_rounded,
                          size: 18,
                        ),
                        label: const Text('Apply & Sync'),
                      ),
              ),
              // Error message
              ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) {
                  if (widget.store.lastError == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: UdieTheme.sp10),
                    child: Container(
                      padding: const EdgeInsets.all(UdieTheme.sp10),
                      decoration: BoxDecoration(
                        color: UdieTheme.danger.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(UdieTheme.radiusSm),
                        border: Border.all(
                          color: UdieTheme.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: UdieTheme.danger,
                          ),
                          const SizedBox(width: UdieTheme.sp8),
                          Expanded(
                            child: Text(
                              widget.store.lastError!,
                              style: const TextStyle(
                                color: UdieTheme.danger,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: UdieTheme.sp24),

        // ── Source diagnostics section ─────────────────────────────────────
        ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final sources = widget.store.sources;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  'Source Diagnostics',
                  trailing: Text(
                    '${sources.length} sources',
                    style: const TextStyle(
                      fontSize: 11,
                      color: UdieTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: UdieTheme.sp12),
                if (sources.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(UdieTheme.sp20),
                    decoration: BoxDecoration(
                      color: UdieTheme.surface1,
                      borderRadius: BorderRadius.circular(UdieTheme.radiusLg),
                      border: Border.all(color: UdieTheme.border),
                    ),
                    child: const Center(
                      child: Text(
                        'No source data – sync to load diagnostics.',
                        style: TextStyle(
                          fontSize: 13,
                          color: UdieTheme.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: UdieTheme.surface1,
                      borderRadius: BorderRadius.circular(UdieTheme.radiusLg),
                      border: Border.all(color: UdieTheme.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < sources.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          _SourceRow(source: sources[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _applyAndSync(AppStore store) async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final radius = double.tryParse(_radius.text.trim());
    if (lat == null || lng == null || radius == null) return;

    setState(() => _isSaving = true);
    await store.updateBaseUrl(_baseUrl.text);
    store.updateArea(
      city: _selectedCity,
      lat: lat,
      lng: lng,
      radiusKm: radius.clamp(1, 20).toDouble(),
    );
    await store.refreshAll();
    if (mounted) setState(() => _isSaving = false);
  }
}

// ── Source row ────────────────────────────────────────────────────────────────

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final SourceStatus source;

  @override
  Widget build(BuildContext context) {
    final hasError = source.lastError != null;
    final statusColor = hasError ? UdieTheme.danger : UdieTheme.ok;
    final catColor = UdieTheme.categoryColor(source.category);
    final subtitle = source.detail.isNotEmpty
        ? source.detail
        : '${source.category} · ${source.eventCount} events · ${source.newsCount} news';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UdieTheme.sp14,
        vertical: UdieTheme.sp12,
      ),
      child: Row(
        children: [
          // Category dot
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(UdieTheme.radiusSm),
              border: Border.all(color: catColor.withValues(alpha: 0.3)),
            ),
            child: Icon(
              UdieTheme.categoryIcon(source.category),
              color: catColor,
              size: 16,
            ),
          ),
          const SizedBox(width: UdieTheme.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: UdieTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: UdieTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      source.lastError!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: UdieTheme.danger,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: UdieTheme.sp8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              if ((source.statusLabel ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  source.statusLabel!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

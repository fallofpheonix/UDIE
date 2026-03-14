import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../state/app_store.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final markers = store.events
        .take(180)
        .map(
          (event) => Marker(
            point: event.point,
            width: 40,
            height: 40,
            child: Tooltip(
              message: event.title,
              child: Icon(
                Icons.warning_rounded,
                color: _severityColor(event.severity),
                size: 18 + (event.severity * 14),
              ),
            ),
          ),
        )
        .toList(growable: false);

    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(
            '${store.area.center.latitude}-${store.area.center.longitude}-${store.area.radiusKm}',
          ),
          options: MapOptions(
            initialCenter: store.area.center,
            initialZoom: 11,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.udie.mobile',
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: store.area.center,
                  radius: store.area.radiusKm * 120,
                  useRadiusInMeter: true,
                  color: Colors.blue.withValues(alpha: 0.14),
                  borderColor: Colors.blue.withValues(alpha: 0.75),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${store.area.city} • ${store.events.length} disruptions',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: store.refreshAll,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Radius ${store.area.radiusKm.toStringAsFixed(0)} km'),
                  Slider(
                    min: 1,
                    max: 20,
                    divisions: 19,
                    value: store.area.radiusKm,
                    onChanged: (v) {
                      store.updateArea(
                        city: store.area.city,
                        lat: store.area.center.latitude,
                        lng: store.area.center.longitude,
                        radiusKm: v,
                      );
                    },
                    onChangeEnd: (_) => store.refreshAll(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _severityColor(double s) {
    if (s >= 0.7) return const Color(0xFFE63946);
    if (s >= 0.35) return const Color(0xFFF4A261);
    return const Color(0xFF2A9D8F);
  }
}

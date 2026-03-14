import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../state/app_store.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final TextEditingController _startLat;
  late final TextEditingController _startLng;
  late final TextEditingController _endLat;
  late final TextEditingController _endLng;

  @override
  void initState() {
    super.initState();
    final c = widget.store.area.center;
    _startLat = TextEditingController(text: c.latitude.toStringAsFixed(6));
    _startLng = TextEditingController(text: c.longitude.toStringAsFixed(6));
    _endLat = TextEditingController(
      text: (c.latitude + 0.03).toStringAsFixed(6),
    );
    _endLng = TextEditingController(
      text: (c.longitude + 0.03).toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _startLat.dispose();
    _startLng.dispose();
    _endLat.dispose();
    _endLng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final risk = widget.store.lastRisk;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'Route Risk Evaluator',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _coordRow('Start', _startLat, _startLng),
        const SizedBox(height: 8),
        _coordRow('End', _endLat, _endLng),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _onEvaluate,
          child: const Text('Evaluate Risk'),
        ),
        const SizedBox(height: 14),
        if (risk != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk ${risk.riskScore.toStringAsFixed(3)} • ${risk.classification}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Density: ${risk.riskDensity.toStringAsFixed(4)}'),
                  Text('Contributing events: ${risk.contributingEvents}'),
                  Text('Eval latency: ${risk.evalLatencyMs} ms'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _coordRow(
    String label,
    TextEditingController lat,
    TextEditingController lng,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: lat,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: lng,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onEvaluate() async {
    final sLat = double.tryParse(_startLat.text.trim());
    final sLng = double.tryParse(_startLng.text.trim());
    final eLat = double.tryParse(_endLat.text.trim());
    final eLng = double.tryParse(_endLng.text.trim());
    if (sLat == null || sLng == null || eLat == null || eLng == null) {
      return;
    }
    await widget.store.evaluateRisk(
      start: LatLng(sLat, sLng),
      end: LatLng(eLat, eLng),
    );
  }
}

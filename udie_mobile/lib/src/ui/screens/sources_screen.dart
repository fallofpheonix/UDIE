import 'package:flutter/material.dart';

import '../../state/app_store.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  static const Map<String, List<double>> _indianCityCenters = {
    'Delhi': [28.6139, 77.2090],
    'Mumbai': [19.0760, 72.8777],
    'Bengaluru': [12.9716, 77.5946],
    'Chennai': [13.0827, 80.2707],
    'Hyderabad': [17.3850, 78.4867],
    'Kolkata': [22.5726, 88.3639],
    'Pune': [18.5204, 73.8567],
    'Ahmedabad': [23.0225, 72.5714],
    'Jaipur': [26.9124, 75.7873],
    'Lucknow': [26.8467, 80.9462],
    'Bhopal': [23.2599, 77.4126],
    'Patna': [25.5941, 85.1376],
    'Guwahati': [26.1445, 91.7362],
    'Chandigarh': [30.7333, 76.7794],
    'Srinagar': [34.0837, 74.7973],
    'Kochi': [9.9312, 76.2673],
    'Thiruvananthapuram': [8.5241, 76.9366],
    'Nagpur': [21.1458, 79.0882],
    'Indore': [22.7196, 75.8577],
    'Surat': [21.1702, 72.8311],
    'Kanpur': [26.4499, 80.3319],
    'Varanasi': [25.3176, 82.9739],
    'Visakhapatnam': [17.6868, 83.2185],
    'Coimbatore': [11.0168, 76.9558],
    'Madurai': [9.9252, 78.1198],
  };

  late final TextEditingController _baseUrl;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _radius;
  late String _selectedCity;

  @override
  void initState() {
    super.initState();
    final area = widget.store.area;
    _baseUrl = TextEditingController(text: widget.store.baseUrl);
    _selectedCity = _indianCityCenters.keys.contains(area.city)
        ? area.city
        : 'Delhi';
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

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Workspace',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _baseUrl,
                  decoration: const InputDecoration(
                    labelText: 'Backend Base URL',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCity,
                  decoration: const InputDecoration(labelText: 'Indian City'),
                  items: _indianCityCenters.keys
                      .map(
                        (city) => DropdownMenuItem<String>(
                          value: city,
                          child: Text(city),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    final center = _indianCityCenters[value]!;
                    setState(() {
                      _selectedCity = value;
                      _lat.text = center[0].toStringAsFixed(6);
                      _lng.text = center[1].toStringAsFixed(6);
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lat,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lng,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _radius,
                        decoration: const InputDecoration(labelText: 'Km'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () async {
                    final lat = double.tryParse(_lat.text.trim());
                    final lng = double.tryParse(_lng.text.trim());
                    final radius = double.tryParse(_radius.text.trim());
                    if (lat == null || lng == null || radius == null) {
                      return;
                    }
                    store.updateBaseUrl(_baseUrl.text);
                    store.updateArea(
                      city: _selectedCity,
                      lat: lat,
                      lng: lng,
                      radiusKm: radius.clamp(1, 20).toDouble(),
                    );
                    await store.refreshAll();
                  },
                  child: const Text('Apply & Sync'),
                ),
                if (store.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      store.lastError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Source Diagnostics',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...store.sources.map(
          (s) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(s.name),
              subtitle: Text(
                '${s.category} • events ${s.eventCount} • news ${s.newsCount}',
              ),
              trailing: Icon(
                s.lastError == null ? Icons.check_circle : Icons.error,
                color: s.lastError == null
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

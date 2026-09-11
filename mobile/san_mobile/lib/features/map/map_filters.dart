import 'package:flutter/material.dart';

class MapFilterValues {
  final String state;
  final String city;
  final bool showShelters;
  final bool showNgos;
  final bool showFloodAreas;
  final bool showRoadClosures;
  final bool showLandslideWarnings;
  final bool showHeavyRainAlerts;

  const MapFilterValues({
    required this.state,
    required this.city,
    required this.showShelters,
    required this.showNgos,
    this.showFloodAreas = true,
    this.showRoadClosures = true,
    this.showLandslideWarnings = true,
    this.showHeavyRainAlerts = true,
  });

  MapFilterValues copyWith({
    String? state,
    String? city,
    bool? showShelters,
    bool? showNgos,
    bool? showFloodAreas,
    bool? showRoadClosures,
    bool? showLandslideWarnings,
    bool? showHeavyRainAlerts,
  }) {
    return MapFilterValues(
      state: state ?? this.state,
      city: city ?? this.city,
      showShelters: showShelters ?? this.showShelters,
      showNgos: showNgos ?? this.showNgos,
      showFloodAreas: showFloodAreas ?? this.showFloodAreas,
      showRoadClosures: showRoadClosures ?? this.showRoadClosures,
      showLandslideWarnings: showLandslideWarnings ?? this.showLandslideWarnings,
      showHeavyRainAlerts: showHeavyRainAlerts ?? this.showHeavyRainAlerts,
    );
  }
}

class MapFilters extends StatefulWidget {
  final MapFilterValues initial;
  final void Function(MapFilterValues values) onApply;
  final VoidCallback? onClear;

  const MapFilters({
    super.key,
    required this.initial,
    required this.onApply,
    this.onClear,
  });

  @override
  State<MapFilters> createState() => _MapFiltersState();
}

class _MapFiltersState extends State<MapFilters> {
  late final TextEditingController _stateCtrl;
  late final TextEditingController _cityCtrl;
  late bool _showShelters;
  late bool _showNgos;
  late bool _showFloodAreas;
  late bool _showRoadClosures;
  late bool _showLandslideWarnings;
  late bool _showHeavyRainAlerts;

  @override
  void initState() {
    super.initState();
    _stateCtrl = TextEditingController(text: widget.initial.state);
    _cityCtrl = TextEditingController(text: widget.initial.city);
    _showShelters = widget.initial.showShelters;
    _showNgos = widget.initial.showNgos;
    _showFloodAreas = widget.initial.showFloodAreas;
    _showRoadClosures = widget.initial.showRoadClosures;
    _showLandslideWarnings = widget.initial.showLandslideWarnings;
    _showHeavyRainAlerts = widget.initial.showHeavyRainAlerts;
  }

  @override
  void dispose() {
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Map Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stateCtrl,
              decoration: const InputDecoration(
                labelText: 'State (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'City (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Aid Locations',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
              ),
            ),
            SwitchListTile(
              value: _showShelters,
              onChanged: (v) => setState(() => _showShelters = v),
              title: const Text('Show Shelters'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _showNgos,
              onChanged: (v) => setState(() => _showNgos = v),
              title: const Text('Show NGOs'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Disaster Overlays',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
              ),
            ),
            SwitchListTile(
              value: _showFloodAreas,
              onChanged: (v) => setState(() => _showFloodAreas = v),
              title: const Text('Show Flood Areas'),
              secondary: const Icon(Icons.water, color: Colors.blue),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _showRoadClosures,
              onChanged: (v) => setState(() => _showRoadClosures = v),
              title: const Text('Show Road Closures'),
              secondary: const Icon(Icons.block, color: Colors.red),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _showLandslideWarnings,
              onChanged: (v) => setState(() => _showLandslideWarnings = v),
              title: const Text('Show Landslide Warnings'),
              secondary: const Icon(Icons.landscape, color: Colors.orange),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _showHeavyRainAlerts,
              onChanged: (v) => setState(() => _showHeavyRainAlerts = v),
              title: const Text('Show Heavy Rain Alerts'),
              secondary: const Icon(Icons.grain, color: Colors.purple),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _stateCtrl.clear();
                      _cityCtrl.clear();
                      setState(() {
                        _showShelters = true;
                        _showNgos = true;
                        _showFloodAreas = true;
                        _showRoadClosures = true;
                        _showLandslideWarnings = true;
                        _showHeavyRainAlerts = true;
                      });
                      widget.onClear?.call();
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final values = MapFilterValues(
                        state: _stateCtrl.text.trim(),
                        city: _cityCtrl.text.trim(),
                        showShelters: _showShelters,
                        showNgos: _showNgos,
                        showFloodAreas: _showFloodAreas,
                        showRoadClosures: _showRoadClosures,
                        showLandslideWarnings: _showLandslideWarnings,
                        showHeavyRainAlerts: _showHeavyRainAlerts,
                      );
                      widget.onApply(values);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

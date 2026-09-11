import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/navigation.dart';
import '../../core/parse.dart';

import '../../core/dio_client.dart';
import '../pps/pps_logged_in_booking_page.dart';
import '../pps/pps_slot_booking_page.dart';
import 'disaster_models.dart';
import 'disaster_service.dart';
import 'guest_shelter_request_page.dart';
import 'map_filters.dart';

class _ShelterAvailability {
  final String label;
  final Color color;
  final bool isFull;

  const _ShelterAvailability({
    required this.label,
    required this.color,
    required this.isFull,
  });
}

class AidMapPage extends StatefulWidget {
  final bool isGuest;
  final int initialGuestTab;

  const AidMapPage({
    super.key,
    this.isGuest = false,
    this.initialGuestTab = 0,
  });

  @override
  State<AidMapPage> createState() => _AidMapPageState();
}

class _AidMapPageState extends State<AidMapPage> {
  final Dio _dio = DioClient.create();

  GoogleMapController? _mapController;

  // Default center (Kuala Lumpur) if location not granted
  static const LatLng _defaultCenter = LatLng(3.1390, 101.6869);
  LatLng _currentCenter = _defaultCenter;
  bool _hasLocationPermission = false;

  bool _loading = true;
  String? _error;

  MapFilterValues _filters = const MapFilterValues(
    state: '',
    city: '',
    showShelters: true,
    showNgos: true,
    showFloodAreas: false,
    showRoadClosures: false,
    showLandslideWarnings: false,
    showHeavyRainAlerts: false,
  );

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }
    return null;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }
    return null;
  }

  _ShelterAvailability _availability(int? capacity, int? occupancy) {
    if (capacity == null || capacity <= 0) {
      return const _ShelterAvailability(label: 'Available', color: Colors.green, isFull: false);
    }
    final current = occupancy ?? 0;
    if (current >= capacity) {
      return const _ShelterAvailability(label: 'FULL', color: Colors.red, isFull: true);
    }
    if (current >= (capacity * 0.8).ceil()) {
      return const _ShelterAvailability(label: 'Almost full', color: Colors.amber, isFull: false);
    }
    return const _ShelterAvailability(label: 'Available', color: Colors.green, isFull: false);
  }

  static const double _markerIconSize = 80.0;
  static const double _fabBottomPadding = 80.0;

  BitmapDescriptor? _shelterIcon;
  BitmapDescriptor? _ngoIcon;

  final Set<Marker> _markers = {};
  List<Map<String, dynamic>> _shelters = [];
  List<Map<String, dynamic>> _ngos = [];
    // MarkerId -> details for bottom sheet
  final Map<String, Map<String, dynamic>> _markerData = {};

  // ── Disaster overlays ────────────────────────────────────────────────────
  final DisasterService _disasterService = DisasterService();

  final Set<Polygon> _floodPolygons = {};
  final Set<Polyline> _roadClosures = {};
  final Set<Circle> _rainCircles = {};

  List<FloodZone> _floodZones = [];
  List<RoadClosure> _roadClosureList = [];
  List<LandslideWarning> _landslideWarnings = [];
  List<HeavyRainAlert> _heavyRainAlerts = [];

  /// Per-source warning messages
  final List<String> _disasterWarnings = [];

  bool _legendExpanded = false;

  // Guest bottom nav tab index (0 = Map, 1 = PPS Slot Booking)
// Guest bottom nav tab index (0 = Map, 1 = PPS Slot Booking)
  late int _tabIndex;

  @override
  void initState() {
    super.initState();

    // If opened from /map, initialGuestTab = 0.
    // If opened from /pps-booking, initialGuestTab = 1.
    _tabIndex = widget.initialGuestTab;

    _init();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
      _disasterWarnings.clear();
    });

    try {
      // Pre-generate icon bitmaps once and cache them.
      _shelterIcon ??= await _markerIconFromIcon(Icons.home, Colors.blue);
      _ngoIcon ??= await _markerIconFromIcon(Icons.volunteer_activism, Colors.red);

      await _trySetUserLocation();
      await _loadMarkers();

    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trySetUserLocation() async {
    // Ask permission
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _hasLocationPermission = false;
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _hasLocationPermission = false;
      return; // keep default center
    }
    if (permission == LocationPermission.deniedForever) {
      _hasLocationPermission = false;

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text('Please enable location permission in Settings to use this feature.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Geolocator.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }


    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _hasLocationPermission = true;
    _currentCenter = LatLng(pos.latitude, pos.longitude);
  }

  /// Creates a circular [BitmapDescriptor] marker icon by drawing [iconData]
  /// (white) centred on a filled circle of [color], then converting it to PNG
  /// bytes for [BitmapDescriptor.fromBytes].
  Future<BitmapDescriptor> _markerIconFromIcon(IconData iconData, Color color) async {
    const double size = _markerIconSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    canvas.drawCircle(
      center,
      size / 2,
      Paint()..color = color,
    );

    final painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.525,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    painter.layout();

    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }

    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }

  Future<void> _loadMarkers() async {
    final markers = <Marker>{};
    _markerData.clear();

    // Use cached icons (generated once in _init).
    final shelterIcon = _shelterIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    final ngoIcon = _ngoIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

    final qp = <String, dynamic>{};
    if (_filters.state.isNotEmpty) qp['state'] = _filters.state;
    if (_filters.city.isNotEmpty) qp['city'] = _filters.city;

    // Fetch shelters
    if (_filters.showShelters) {
      final res = await _dio.get('/map/shelters', queryParameters: qp);
      final data = (res.data as Map).cast<String, dynamic>();
      if (data['ok'] != true) throw Exception(data['error'] ?? 'Failed to load shelters');
      final list = (data['shelters'] as List).cast<dynamic>();
      _shelters = list.map((e) => (e as Map).cast<String, dynamic>()).toList();

      for (final s in _shelters) {
        final lat = _toDouble(s['latitude']);
        final lng = _toDouble(s['longitude']);
        if (lat == null || lng == null) continue;

        final id = (s['shelter_id'] as num).toInt();
        final name = s['shelter_name']?.toString() ?? 'Shelter';
        final city = s['city']?.toString() ?? '';
        final state = s['state']?.toString() ?? '';
        final capacity = _toInt(s['capacity']);
        final occupancy = _toInt(s['current_occupancy']);

        final markerKey = 'shelter_$id';
        final address = [
          s['address_line']?.toString() ?? '',
          s['city']?.toString() ?? '',
          s['state']?.toString() ?? '',
          s['postal_code']?.toString() ?? '',
        ].where((x) => x.trim().isNotEmpty).join(', ');

        _markerData[markerKey] = {
          'type': 'Shelter',
          'name': name,
          'address': address,
          'lat': lat,
          'lng': lng,
          'capacity': capacity,
          'current_occupancy': occupancy,
          'shelter_id': id,
        };

        markers.add(
          Marker(
            markerId: MarkerId(markerKey),
            position: LatLng(lat, lng),
            onTap: () => _showMarkerDetails(markerKey),
            infoWindow: InfoWindow(
              title: name,
              snippet: [city, state].where((x) => x.trim().isNotEmpty).join(', '),
            ),
            icon: shelterIcon,
          ),
        );


      }
    } else {
      _shelters = [];
    }

    // Fetch NGOs
    if (_filters.showNgos) {
      final res = await _dio.get('/map/ngos', queryParameters: qp);
      final data = (res.data as Map).cast<String, dynamic>();
      if (data['ok'] != true) throw Exception(data['error'] ?? 'Failed to load NGOs');
      final list = (data['ngos'] as List).cast<dynamic>();
      _ngos = list.map((e) => (e as Map).cast<String, dynamic>()).toList();

      for (final n in _ngos) {
        final lat = _toDouble(n['latitude']);
        final lng = _toDouble(n['longitude']);
        if (lat == null || lng == null) continue;

        final id = (n['ngo_id'] as num).toInt();
        final name = n['ngo_name']?.toString() ?? 'NGO';
        final city = n['city']?.toString() ?? '';
        final state = n['state']?.toString() ?? '';

        final markerKey = 'ngo_$id';
        final address = [
          n['address_line']?.toString() ?? '',
          n['city']?.toString() ?? '',
          n['state']?.toString() ?? '',
          n['postal_code']?.toString() ?? '',
        ].where((x) => x.trim().isNotEmpty).join(', ');

        _markerData[markerKey] = {
          'type': 'NGO',
          'name': name,
          'address': address,
          'lat': lat,
          'lng': lng,
        };

        markers.add(
          Marker(
            markerId: MarkerId(markerKey),
            position: LatLng(lat, lng),
            onTap: () => _showMarkerDetails(markerKey),
            infoWindow: InfoWindow(
              title: name,
              snippet: [city, state].where((x) => x.trim().isNotEmpty).join(', '),
            ),
            icon: ngoIcon,
          ),
        );

      }
    } else {
      _ngos = [];
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(markers);
      });
    }
  }

  // ── Disaster overlay loading ────────────────────────────────────────────

  Future<void> _loadDisasterOverlays() async {
    final newPolygons = <Polygon>{};
    final newPolylines = <Polyline>{};
    final newCircles = <Circle>{};
    final disasterMarkers = <Marker>{};
    final newWarnings = <String>[];

    // Run all four fetches concurrently; each is best-effort.
    final results = await Future.wait([
      _filters.showFloodAreas
          ? _disasterService.fetchFloodZones()
          : Future.value(<FloodZone>[]),
      _filters.showRoadClosures
          ? _disasterService.fetchRoadClosures()
          : Future.value(<RoadClosure>[]),
      _filters.showLandslideWarnings
          ? _disasterService.fetchLandslideWarnings()
          : Future.value(<LandslideWarning>[]),
      _filters.showHeavyRainAlerts
          ? _disasterService.fetchHeavyRainAlerts()
          : Future.value(<HeavyRainAlert>[]),
    ]);

    // Cast results
    final zones = results[0] as List<FloodZone>;
    final closures = results[1] as List<RoadClosure>;
    final slides = results[2] as List<LandslideWarning>;
    final rains = results[3] as List<HeavyRainAlert>;

    _floodZones = zones;
    _roadClosureList = closures;
    _landslideWarnings = slides;
    _heavyRainAlerts = rains;

    // Note: if all lists are empty the external APIs may be unreachable, but
    // we do not surface a blocking error — overlays are best-effort.

    // ── Flood polygons ──────────────────────────────────────────────────
    for (int i = 0; i < zones.length; i++) {
      final z = zones[i];
      final fillColor = _floodFillColor(z.severity);
      final strokeColor = _floodStrokeColor(z.severity);

      if (z.points.length >= 3) {
        newPolygons.add(
          Polygon(
            polygonId: PolygonId('flood_${z.id}'),
            points: z.points,
            fillColor: fillColor.withValues(alpha:0.35),
            strokeColor: strokeColor,
            strokeWidth: 2,
            consumeTapEvents: true,
            onTap: () => _showDisasterDetails(
              type: 'Flood Area',
              title: z.name,
              subtitle: [z.district, z.state].where((s) => s.isNotEmpty).join(', '),
              detail: 'Severity: ${z.severity.name.toUpperCase()}',
              updatedAt: z.updatedAt,
              iconColor: strokeColor,
              icon: Icons.water,
            ),
          ),
        );
      } else if (z.center != null) {
        // Fall back to a marker when polygon has no boundary data
        final key = 'flood_${z.id}';
        _markerData[key] = {
          'type': 'Flood Area',
          'name': z.name,
          'detail': 'Severity: ${z.severity.name.toUpperCase()}',
          'location': [z.district, z.state].where((s) => s.isNotEmpty).join(', '),
          'updatedAt': z.updatedAt?.toLocal().toString().substring(0, 16),
          'lat': z.center!.latitude,
          'lng': z.center!.longitude,
        };
        disasterMarkers.add(
          Marker(
            markerId: MarkerId(key),
            position: z.center!,
            onTap: () => _showMarkerDetails(key),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(title: z.name, snippet: 'Flood Area'),
          ),
        );
      }
    }

    // ── Road closure polylines ──────────────────────────────────────────
    for (int i = 0; i < closures.length; i++) {
      final c = closures[i];
      if (c.path.length >= 2) {
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('road_${c.id}'),
            points: c.path,
            color: Colors.red,
            width: 5,
            patterns: [PatternItem.dash(12), PatternItem.gap(6)],
            consumeTapEvents: true,
            onTap: () => _showDisasterDetails(
              type: 'Road Closure',
              title: c.roadName,
              subtitle: [c.district, c.state].where((s) => s.isNotEmpty).join(', '),
              detail: c.reason.isNotEmpty ? 'Reason: ${c.reason}' : '',
              updatedAt: c.startDate,
              iconColor: Colors.red,
              icon: Icons.block,
            ),
          ),
        );
      } else if (c.center != null) {
        final key = 'road_${c.id}';
        _markerData[key] = {
          'type': 'Road Closure',
          'name': c.roadName,
          'detail': c.reason.isNotEmpty ? 'Reason: ${c.reason}' : '',
          'location': [c.district, c.state].where((s) => s.isNotEmpty).join(', '),
          'updatedAt': c.startDate?.toLocal().toString().substring(0, 16),
          'lat': c.center!.latitude,
          'lng': c.center!.longitude,
        };
        disasterMarkers.add(
          Marker(
            markerId: MarkerId(key),
            position: c.center!,
            onTap: () => _showMarkerDetails(key),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
            infoWindow: InfoWindow(title: c.roadName, snippet: 'Road Closed'),
          ),
        );
      }
    }

    // ── Landslide warning markers ───────────────────────────────────────
    for (final w in slides) {
      final key = 'landslide_${w.id}';
      _markerData[key] = {
        'type': 'Landslide Warning',
        'name': w.locationName,
        'detail': 'Risk: ${w.risk.name.toUpperCase()}',
        'location': [w.district, w.state].where((s) => s.isNotEmpty).join(', '),
        'updatedAt': w.reportedAt?.toLocal().toString().substring(0, 16),
        'lat': w.position.latitude,
        'lng': w.position.longitude,
      };
      disasterMarkers.add(
        Marker(
          markerId: MarkerId(key),
          position: w.position,
          onTap: () => _showMarkerDetails(key),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: w.locationName, snippet: 'Landslide Warning'),
        ),
      );
    }

    // ── Heavy rain markers + circles ───────────────────────────────────
    for (final r in rains) {
      final key = 'rain_${r.id}';
      _markerData[key] = {
        'type': 'Heavy Rain Alert',
        'name': r.stationName,
        'detail': 'Rainfall: ${r.rainfallMmPerHr.toStringAsFixed(1)} mm/hr',
        'location': [r.district, r.state].where((s) => s.isNotEmpty).join(', '),
        'updatedAt': r.readingAt?.toLocal().toString().substring(0, 16),
        'lat': r.position.latitude,
        'lng': r.position.longitude,
      };
      disasterMarkers.add(
        Marker(
          markerId: MarkerId(key),
          position: r.position,
          onTap: () => _showMarkerDetails(key),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: r.stationName,
            snippet: '${r.rainfallMmPerHr.toStringAsFixed(1)} mm/hr',
          ),
        ),
      );
      newCircles.add(
        Circle(
          circleId: CircleId('rain_circle_${r.id}'),
          center: r.position,
          radius: 2000, // 2 km visual radius
          fillColor: Colors.purple.withValues(alpha:0.15),
          strokeColor: Colors.purple.withValues(alpha:0.5),
          strokeWidth: 1,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _floodPolygons
          ..clear()
          ..addAll(newPolygons);
        _roadClosures
          ..clear()
          ..addAll(newPolylines);
        _rainCircles
          ..clear()
          ..addAll(newCircles);

        // Merge disaster markers into the existing _markers set
        _markers.removeWhere(
          (m) =>
              m.markerId.value.startsWith('flood_') ||
              m.markerId.value.startsWith('road_') ||
              m.markerId.value.startsWith('landslide_') ||
              m.markerId.value.startsWith('rain_'),
        );
        _markers.addAll(disasterMarkers);

        _disasterWarnings
          ..clear()
          ..addAll(newWarnings);
      });
    }
  }

  Color _floodFillColor(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.high:
        return Colors.red;
      case FloodSeverity.medium:
        return Colors.orange;
      case FloodSeverity.low:
        return Colors.blue;
    }
  }

  Color _floodStrokeColor(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.high:
        return Colors.red.shade800;
      case FloodSeverity.medium:
        return Colors.orange.shade800;
      case FloodSeverity.low:
        return Colors.blue.shade800;
    }
  }

  void _showDisasterDetails({
    required String type,
    required String title,
    required String subtitle,
    required String detail,
    DateTime? updatedAt,
    required Color iconColor,
    required IconData icon,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 14)),
              ],
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(detail, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
              if (updatedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Updated: ${updatedAt.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Legend widget ───────────────────────────────────────────────────────

  Widget _buildLegend() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: _legendExpanded ? _buildLegendExpanded() : _legendCollapsed(),
    );
  }

  Widget _legendCollapsed() {
    return IconButton(
      icon: const Icon(Icons.layers, size: 20),
      tooltip: 'Legend',
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      onPressed: () => setState(() => _legendExpanded = true),
    );
  }

  Widget _buildLegendExpanded() {
    const items = [
      _LegendItem(color: Colors.blue, label: 'Flood Area', icon: Icons.water),
      _LegendItem(color: Colors.red, label: 'Road Closed', icon: Icons.block),
      _LegendItem(color: Colors.orange, label: 'Landslide', icon: Icons.landscape),
      _LegendItem(color: Colors.purple, label: 'Heavy Rain', icon: Icons.grain),
      _LegendItem(color: Colors.blue, label: 'Shelter', icon: Icons.home),
      _LegendItem(color: Colors.red, label: 'NGO', icon: Icons.volunteer_activism),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Legend', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _legendExpanded = false),
                child: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: item.color, size: 15),
                  const SizedBox(width: 6),
                  Text(item.label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return MapFilters(
          initial: _filters,
          onApply: (values) async {
            Navigator.of(context).pop();
            setState(() {
              _filters = values;
              _loading = true;
              _error = null;
              _disasterWarnings.clear();
            });
            try {
              await _loadMarkers();
            } catch (e) {
              if (mounted) setState(() => _error = e.toString());
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          onClear: () async {
          },
        );
      },
    );
  }


  Future<void> _moveTo(LatLng target) async {
    final controller = _mapController;

    if (!mounted || controller == null) return;

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(target, 13),
      );
    } catch (e) {
      debugPrint('Map move error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isGuest ? 'Aid Map (Guest)' : 'Map';
    final colorScheme = Theme.of(context).colorScheme;

    final mapBody = Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _currentCenter, zoom: 12),
          myLocationEnabled: _hasLocationPermission,
          myLocationButtonEnabled: _hasLocationPermission,
          markers: _markers,
          polygons: _floodPolygons,
          polylines: _roadClosures,
          circles: _rainCircles,
          onMapCreated: (c) async {
            _mapController = c;

            if (!mounted) return;

            await Future.delayed(
              const Duration(milliseconds: 300),
            );

            if (!mounted) return;

            await _moveTo(_currentCenter);
          },
        ),
        // Top info panel
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Shelters: ${_shelters.length}   NGOs: ${_ngos.length}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            Text(
                              'Floods: ${_floodZones.length}   Roads closed: ${_roadClosureList.length}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.filter_list),
                        tooltip: 'Filters',
                      ),
                      IconButton(
                        onPressed: _init,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  if (_filters.state.isNotEmpty || _filters.city.isNotEmpty)
                    Text(
                      'Filter: ${_filters.state}${_filters.state.isNotEmpty && _filters.city.isNotEmpty ? ', ' : ''}${_filters.city}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colorScheme.error, fontSize: 12),
                      ),
                    ),
                  // Inline warnings for external API sources
                  for (final warning in _disasterWarnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              warning,
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Bottom-left legend
        Positioned(
          bottom: 24,
          left: 12,
          child: _buildLegend(),
        ),

        if (_loading)
          const Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Loading map data...'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    final mapFab = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'nearest',
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          tooltip: 'Nearest shelter',
          onPressed: () async {
            final s = _nearestShelter();
            if (s == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No shelters with coordinates')),
              );
              return;
            }

            final lat = parseDouble(s['latitude']);
            final lng = parseDouble(s['longitude']);
            final name = s['shelter_name']?.toString() ?? 'Shelter';

            if (lat == null || lng == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('This shelter has no valid latitude/longitude')),
              );
              return;
            }

            final ok = await NavigationHelper.navigateTo(destLat: lat, destLng: lng);

            if (!ok && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open Google Maps')),
              );
            } else {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Navigating to nearest shelter: $name')),
              );
            }
          },
          child: const Icon(Icons.my_location),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.small(
          heroTag: 'filters',
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          tooltip: 'Filter',
          onPressed: _openFilters,
          child: const Icon(Icons.filter_alt),
        ),
      ],
    );

    if (widget.isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: 'Login',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
        body: IndexedStack(
          index: _tabIndex,
          children: [
            Stack(
              children: [
                mapBody,

                Positioned(
                  left: 16,
                  top: 96,
                  child: mapFab,
                ),
              ],
            ),

            const PpsSlotBookingPage(),
          ],
        ),
        floatingActionButton: null,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_outlined),
              label: 'PPS Booking',
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        mapBody,
        Positioned(
          left: 16,
          top: 96,
          child: mapFab,
        ),
      ],
    );
  }
  

  void _showMarkerDetails(String markerKey) {
    final data = _markerData[markerKey];
    if (data == null) return;

    final type = data['type']?.toString() ?? '';
    final name = data['name']?.toString() ?? '';
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    final parentContext = context;

    // Disaster marker types have a 'detail' + 'location' + 'updatedAt' structure
    final isDisasterMarker = type == 'Flood Area' ||
        type == 'Road Closure' ||
        type == 'Landslide Warning' ||
        type == 'Heavy Rain Alert';

    if (isDisasterMarker) {
      final detail = data['detail']?.toString() ?? '';
      final location = data['location']?.toString() ?? '';
      final updatedAt = data['updatedAt']?.toString() ?? '';

      final (iconData, iconColor) = switch (type) {
        'Flood Area' => (Icons.water, Colors.blue),
        'Road Closure' => (Icons.block, Colors.red),
        'Landslide Warning' => (Icons.landscape, Colors.orange),
        'Heavy Rain Alert' => (Icons.grain, Colors.purple),
        _ => (Icons.info_outline, Colors.grey),
      };

      showModalBottomSheet(
        context: parentContext,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(iconData, color: iconColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      type,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: iconColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(location, style: const TextStyle(fontSize: 14)),
                ],
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(detail,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ],
                if (updatedAt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Updated: $updatedAt',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(parentContext).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // ── Standard shelter / NGO bottom sheet ──
    final address = data['address']?.toString() ?? '';
    final capacity = _toInt(data['capacity']);
    final occupancy = _toInt(data['current_occupancy']);
    final availability = type == 'Shelter' ? _availability(capacity, occupancy) : null;

    showModalBottomSheet(
      context: parentContext,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(address.isEmpty ? '(No address)' : address),
                if (availability != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: availability.color.withValues(alpha:0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: availability.color),
                        ),
                        child: Text(
                          availability.label,
                          style: TextStyle(color: availability.color, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      Text('Capacity: ${capacity ?? '-'}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('Occupied: ${occupancy ?? '-'}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
                if (availability != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: availability.isFull
                          ? null
                          : () async {
                              Navigator.of(sheetContext).pop();
                              final refreshed = await Navigator.of(parentContext).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => widget.isGuest
                                      ? GuestShelterRequestPage(
                                          shelterId: (data['shelter_id'] as num?)?.toInt() ?? 0,
                                          shelterName: name,
                                          capacity: capacity,
                                          currentOccupancy: occupancy,
                                          availabilityLabel: availability.label,
                                          availabilityColor: availability.color,
                                          isFull: availability.isFull,
                                        )
                                      : PpsLoggedInBookingPage(
                                          shelterId: (data['shelter_id'] as num?)?.toInt() ?? 0,
                                          shelterName: name,
                                          capacity: capacity,
                                          currentOccupancy: occupancy,
                                          availabilityLabel: availability.label,
                                          availabilityColor: availability.color,
                                          isFull: availability.isFull,
                                        ),
                                ),
                              );
                              if (refreshed == true && mounted) {
                                await _init();
                              }
                            },
                      icon: const Icon(Icons.edit_calendar),
                      label: Text(availability.isFull
                          ? 'PPS FULL'
                          : (widget.isGuest ? 'Request PPS Slot' : 'Book PPS Slot')),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (lat == null || lng == null)
                            ? null
                            : () async {
                                final ok = await NavigationHelper.navigateTo(
                                  destLat: lat,
                                  destLng: lng,
                                  travelMode: 'driving',
                                );
                                if (!ok && mounted) {
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    const SnackBar(content: Text('Could not open Google Maps')),
                                  );
                                }
                              },
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  Map<String, dynamic>? _nearestShelter() {
    if (_shelters.isEmpty) return null;

    final here = _currentCenter;
    Map<String, dynamic>? best;
    double bestDist = double.infinity;

    for (final s in _shelters) {
      final lat = parseDouble(s['latitude']);
      final lng = parseDouble(s['longitude']);
      if (lat == null || lng == null) continue;
      final d = _distanceMeters(here, LatLng(lat, lng));
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

}

// Helper for the legend
class _LegendItem {
  final Color color;
  final String label;
  final IconData icon;

  const _LegendItem({required this.color, required this.label, required this.icon});
}

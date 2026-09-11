import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/config.dart';

const _osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';

// ---------------------------------------------------------------------------
// Page entry point
// ---------------------------------------------------------------------------

class InAppNavigationPage extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String destName;

  const InAppNavigationPage({
    super.key,
    required this.destLat,
    required this.destLng,
    this.destName = 'Destination',
  });

  @override
  State<InAppNavigationPage> createState() => _InAppNavigationPageState();
}

class _InAppNavigationPageState extends State<InAppNavigationPage> {
  GoogleMapController? _mapController;
  final Dio _dio = Dio();

  Position? _userPosition;
  bool _loadingLocation = true;
  bool _loadingRoutes = false;
  String? _error;

  List<_RouteOption> _routes = [];
  int _selectedIndex = 0;
  bool _avoidTolls = false;

  // ---- navigation mode ----
  bool _navigating = false;
  StreamSubscription<Position>? _positionStream;
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // ---- location ----

  Future<void> _initLocation() async {
    setState(() {
      _loadingLocation = true;
      _error = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Location permission denied. Please enable it in Settings.');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _userPosition = pos;
        _loadingLocation = false;
      });
      await _fetchRoutes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _error = e.toString();
      });
    }
  }

  // ---- directions API ----

  Future<void> _fetchRoutes() async {
    if (_userPosition == null) return;
    setState(() {
      _loadingRoutes = true;
      _error = null;
    });

    bool triedGoogle = false;
    try {
      final origin = '${_userPosition!.latitude},${_userPosition!.longitude}';
      final dest = '${widget.destLat},${widget.destLng}';
      final avoidParam = _avoidTolls ? '&avoid=tolls' : '';

      final url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$origin'
          '&destination=$dest'
          '&alternatives=true'
          '$avoidParam'
          '&key=${AppConfig.mapsApiKey}';

      final res = await _dio.get(url);
      final body = res.data as Map<String, dynamic>;

      final status = body['status']?.toString() ?? '';
      if (status == 'REQUEST_DENIED') {
        triedGoogle = true;
        throw Exception('Google Directions API access denied, falling back to OSRM');
      }
      if (status != 'OK') {
        throw Exception('Directions API returned status: $status');
      }

      final rawRoutes = (body['routes'] as List).cast<Map<String, dynamic>>();
      final parsed = rawRoutes.take(3).map(_RouteOption.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _routes = parsed;
        _selectedIndex = 0;
        _loadingRoutes = false;
      });
      _fitMapToSelectedRoute();
      return;
    } catch (e) {
      if (!triedGoogle) {
        if (!mounted) return;
        setState(() {
          _loadingRoutes = false;
          _error = 'Could not fetch routes: $e';
        });
        return;
      }
    }

    try {
      final originCoord =
          '${_userPosition!.longitude},${_userPosition!.latitude}';
      final destCoord = '${widget.destLng},${widget.destLat}';

      final url =
          '$_osrmBaseUrl'
          '/$originCoord;$destCoord'
          '?overview=full&alternatives=true&steps=true';

      final res = await _dio.get(url);
      final body = res.data as Map<String, dynamic>;

      final code = body['code']?.toString() ?? '';
      if (code != 'Ok') {
        throw Exception('OSRM routing returned: $code');
      }

      final rawRoutes = (body['routes'] as List).cast<Map<String, dynamic>>();
      final parsed =
          rawRoutes.take(3).map(_RouteOption.fromOsrmJson).toList();

      if (!mounted) return;
      setState(() {
        _routes = parsed;
        _selectedIndex = 0;
        _loadingRoutes = false;
      });
      _fitMapToSelectedRoute();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRoutes = false;
        _error = 'Could not fetch routes: $e';
      });
    }
  }

  // ---- map helpers ----

  void _fitMapToSelectedRoute() {
    if (_routes.isEmpty || _mapController == null) return;
    final points = _routes[_selectedIndex].polylinePoints;
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  // ---- navigation mode helpers ----

  void _startNavigation() {
    if (_routes.isEmpty) return;
    setState(() {
      _navigating = true;
      _currentStepIndex = 0;
    });
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate);
  }

  void _stopNavigation() {
    _positionStream?.cancel();
    _positionStream = null;
    setState(() => _navigating = false);
    _fitMapToSelectedRoute();
  }

  void _onPositionUpdate(Position pos) {
    if (!mounted) return;
    setState(() {
      _userPosition = pos;
      _currentStepIndex = _advanceStepIndex(pos);
    });
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 17.5,
          tilt: 45,
          bearing: pos.heading,
        ),
      ),
    );
  }

  int _advanceStepIndex(Position pos) {
    final steps = _routes[_selectedIndex].steps;
    if (steps.isEmpty) return 0;
    int idx = _currentStepIndex;
    while (idx < steps.length - 1) {
      final next = steps[idx + 1];
      final dist = _haversineMeters(
        pos.latitude, pos.longitude,
        next.point.latitude, next.point.longitude,
      );
      if (dist < 30) {
        idx++;
      } else {
        break;
      }
    }
    return idx;
  }

  static double _haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLambda = (lng2 - lng1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};
    for (int i = 0; i < _routes.length; i++) {
      final isSelected = i == _selectedIndex;
      polylines.add(Polyline(
        polylineId: PolylineId('route_$i'),
        points: _routes[i].polylinePoints,
        color: isSelected ? Colors.blue : Colors.blueGrey.withOpacity(0.5),
        width: isSelected ? 6 : 3,
        zIndex: isSelected ? 1 : 0,
      ));
    }
    return polylines;
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destLat, widget.destLng),
        infoWindow: InfoWindow(title: widget.destName),
      ),
      if (_userPosition != null && !_navigating)
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
    };
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final destLatLng = LatLng(widget.destLat, widget.destLng);

    if (_loadingLocation) {
      return Scaffold(
        appBar: AppBar(title: Text('Navigate to ${widget.destName}')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Getting your location…'),
            ],
          ),
        ),
      );
    }

    if (_error != null && _routes.isEmpty && _userPosition == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Navigate to ${widget.destName}')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _userPosition == null ? _initLocation : _fetchRoutes,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final googleMap = GoogleMap(
      initialCameraPosition: CameraPosition(target: destLatLng, zoom: 12),
      onMapCreated: (controller) {
        _mapController = controller;
        _fitMapToSelectedRoute();
      },
      markers: _buildMarkers(),
      polylines: _buildPolylines(),
      myLocationEnabled: true,
      myLocationButtonEnabled: !_navigating,
      compassEnabled: _navigating,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
    );

    // ---- Navigation mode: full-screen map + instruction banner ----
    if (_navigating) {
      final steps = _routes.isNotEmpty ? _routes[_selectedIndex].steps : <_NavStep>[];
      final currentStep = steps.isNotEmpty ? steps[_currentStepIndex] : null;

      return Scaffold(
        body: Stack(
          children: [
            googleMap,
            // Instruction banner at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _InstructionBanner(step: currentStep),
            ),
            // Stop navigation button at bottom
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: ElevatedButton.icon(
                onPressed: _stopNavigation,
                icon: const Icon(Icons.close),
                label: const Text('Stop Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ---- Overview mode: map + routes panel + Start button ----
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigate to ${widget.destName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                _avoidTolls ? Icons.money_off : Icons.attach_money,
                size: 16,
              ),
              label: Text(_avoidTolls ? 'No Tolls' : 'All Routes'),
              selected: _avoidTolls,
              onSelected: (_) {
                setState(() => _avoidTolls = !_avoidTolls);
                _fetchRoutes();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _routes.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _startNavigation,
              icon: const Icon(Icons.navigation),
              label: const Text('Start Navigation'),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          // Map
          Expanded(child: googleMap),

          // Routes panel
          _RoutesPanel(
            routes: _routes,
            selectedIndex: _selectedIndex,
            loading: _loadingRoutes,
            error: _error,
            onSelectRoute: (i) {
              setState(() => _selectedIndex = i);
              _fitMapToSelectedRoute();
            },
            onRetry: _fetchRoutes,
          ),
          // Space for FAB
          const SizedBox(height: 72),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Routes bottom panel
// ---------------------------------------------------------------------------

class _RoutesPanel extends StatelessWidget {
  final List<_RouteOption> routes;
  final int selectedIndex;
  final bool loading;
  final String? error;
  final void Function(int) onSelectRoute;
  final VoidCallback onRetry;

  const _RoutesPanel({
    required this.routes,
    required this.selectedIndex,
    required this.loading,
    required this.error,
    required this.onSelectRoute,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                const Text(
                  'Available Routes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (error != null && routes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, style: TextStyle(color: colorScheme.error)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (routes.isEmpty && !loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No routes found.'),
            )
          else
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                itemCount: routes.length,
                itemBuilder: (context, i) {
                  final route = routes[i];
                  final isSelected = i == selectedIndex;
                  return _RouteCard(
                    route: route,
                    index: i,
                    isSelected: isSelected,
                    onTap: () => onSelectRoute(i),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual route card
// ---------------------------------------------------------------------------

class _RouteCard extends StatelessWidget {
  final _RouteOption route;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteCard({
    required this.route,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isSelected ? colorScheme.primary : colorScheme.outline,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isSelected ? colorScheme.onPrimary : colorScheme.surface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.summary.isEmpty ? 'Route ${index + 1}' : route.summary,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? colorScheme.onPrimaryContainer : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 13, color: colorScheme.primary),
                      const SizedBox(width: 3),
                      Text(route.duration, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 10),
                      Icon(Icons.straighten, size: 13, color: colorScheme.secondary),
                      const SizedBox(width: 3),
                      Text(route.distance, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            if (route.hasTolls)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  label: const Text('Toll', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.attach_money, size: 14),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.orange.withOpacity(0.15),
                ),
              ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, color: colorScheme.primary, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Instruction banner (shown during navigation)
// ---------------------------------------------------------------------------

class _InstructionBanner extends StatelessWidget {
  final _NavStep? step;

  const _InstructionBanner({required this.step});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: Colors.blue.shade800,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              const Icon(Icons.navigation, color: Colors.white, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  step?.instruction ?? 'Follow the route',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (step != null && step!.distanceM > 0) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmtDist(step!.distanceM),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'ahead',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDist(double m) {
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }
}

// ---------------------------------------------------------------------------
// Navigation step model
// ---------------------------------------------------------------------------

class _NavStep {
  final String instruction;
  final double distanceM;
  final LatLng point;

  const _NavStep({
    required this.instruction,
    required this.distanceM,
    required this.point,
  });
}

// ---------------------------------------------------------------------------
// Route model
// ---------------------------------------------------------------------------

class _RouteOption {
  static final _htmlTagRegExp = RegExp(r'<[^>]+>');
  static final _whitespaceRegExp = RegExp(r'\s+');

  final String summary;
  final String duration;
  final String distance;
  final bool hasTolls;
  final List<LatLng> polylinePoints;
  final List<_NavStep> steps;

  const _RouteOption({
    required this.summary,
    required this.duration,
    required this.distance,
    required this.hasTolls,
    required this.polylinePoints,
    required this.steps,
  });

  /// Parse a route from the OSRM Routing API response.
  factory _RouteOption.fromOsrmJson(Map<String, dynamic> json) {
    final durationSec = (json['duration'] as num?)?.toDouble() ?? 0.0;
    final distanceM = (json['distance'] as num?)?.toDouble() ?? 0.0;

    final legs = (json['legs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final summary =
        legs.isNotEmpty ? (legs.first['summary']?.toString() ?? '') : '';

    final encodedPolyline = json['geometry']?.toString() ?? '';
    final points = _decodePolyline(encodedPolyline);

    // Parse turn-by-turn steps from the first leg.
    final rawSteps = legs.isNotEmpty
        ? (legs.first['steps'] as List?)?.cast<Map<String, dynamic>>() ?? []
        : <Map<String, dynamic>>[];
    final navSteps = rawSteps.map((s) {
      final maneuver = (s['maneuver'] as Map?)?.cast<String, dynamic>() ?? {};
      final roadName = s['name']?.toString() ?? '';
      final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
      final loc = (maneuver['location'] as List?) ?? [];
      final lat = loc.length >= 2 ? (loc[1] as num).toDouble() : 0.0;
      final lng = loc.isNotEmpty ? (loc[0] as num).toDouble() : 0.0;
      return _NavStep(
        instruction: _osrmInstruction(maneuver, roadName),
        distanceM: dist,
        point: LatLng(lat, lng),
      );
    }).toList();

    return _RouteOption(
      summary: summary,
      duration: _formatDurationSeconds(durationSec.round()),
      distance: _formatDistanceMeters(distanceM),
      hasTolls: false,
      polylinePoints: points,
      steps: navSteps,
    );
  }

  static String _osrmInstruction(
      Map<String, dynamic> maneuver, String roadName) {
    final type = maneuver['type']?.toString() ?? '';
    final modifier = maneuver['modifier']?.toString() ?? '';
    final ontoRoad = roadName.isNotEmpty ? ' onto $roadName' : '';
    final onRoad = roadName.isNotEmpty ? ' on $roadName' : '';
    switch (type) {
      case 'depart':
        return 'Head ${modifier.isNotEmpty ? modifier : 'forward'}$onRoad';
      case 'arrive':
        return 'Arrive at destination';
      case 'turn':
        return 'Turn $modifier$ontoRoad';
      case 'merge':
        return 'Merge $modifier$ontoRoad';
      case 'on ramp':
      case 'off ramp':
        return 'Take the ramp$ontoRoad';
      case 'fork':
        return 'Keep $modifier$ontoRoad';
      case 'end of road':
        return 'Turn $modifier$ontoRoad';
      case 'roundabout':
      case 'rotary':
        final exit = maneuver['exit']?.toString() ?? '';
        return 'Take exit $exit at the roundabout';
      default:
        final base = type.length > 1
            ? type[0].toUpperCase() + type.substring(1)
            : type.toUpperCase().isNotEmpty
                ? type.toUpperCase()
                : 'Continue';
        return '$base${modifier.isNotEmpty ? ' $modifier' : ''}$onRoad';
    }
  }

  static String _formatDurationSeconds(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '${hours}h' : '${hours}h ${rem}min';
  }

  static String _formatDistanceMeters(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  factory _RouteOption.fromJson(Map<String, dynamic> json) {
    final legs = (json['legs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final leg = legs.isNotEmpty ? legs.first : <String, dynamic>{};

    final duration = (leg['duration'] as Map?)?['text']?.toString() ?? '';
    final distance = (leg['distance'] as Map?)?['text']?.toString() ?? '';
    final summary = json['summary']?.toString() ?? '';

    // Detect tolls from warnings or step instructions
    final warnings = (json['warnings'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
    bool hasTolls = warnings.any((w) => w.contains('toll'));

    final rawSteps = (leg['steps'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (!hasTolls) {
      hasTolls = rawSteps.any((s) {
        final instr = (s['html_instructions'] ?? '').toString().toLowerCase();
        return instr.contains('toll');
      });
    }

    // Parse turn-by-turn steps.
    final navSteps = rawSteps.map((s) {
      final rawInstr = (s['html_instructions'] ?? '').toString();
      final instr = rawInstr.replaceAll(_htmlTagRegExp, ' ').trim().replaceAll(_whitespaceRegExp, ' ');
      final distM = ((s['distance'] as Map?)?['value'] as num?)?.toDouble() ?? 0.0;
      final startLoc = (s['start_location'] as Map?) ?? {};
      final lat = (startLoc['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (startLoc['lng'] as num?)?.toDouble() ?? 0.0;
      return _NavStep(instruction: instr, distanceM: distM, point: LatLng(lat, lng));
    }).toList();

    final encodedPolyline =
        (json['overview_polyline'] as Map?)?['points']?.toString() ?? '';
    final points = _decodePolyline(encodedPolyline);

    return _RouteOption(
      summary: summary,
      duration: duration,
      distance: distance,
      hasTolls: hasTolls,
      polylinePoints: points,
      steps: navSteps,
    );
  }

  /// Google encoded polyline decoder.
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

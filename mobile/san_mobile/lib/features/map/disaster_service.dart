import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'disaster_models.dart';

/// Fetches real-world disaster data from:
///   • JPS InfoBanjir  — https://publicinfobanjir.water.gov.my/api/
///   • data.gov.my     — https://api.data.gov.my/
///
/// Every public method is **best-effort**: it returns an empty list on any
/// network / parse error so that the map still loads if an external source
/// is unavailable.
class DisasterService {
  static const String _jpsBase = 'https://publicinfobanjir.water.gov.my/api';
  static const String _dataGovBase = 'https://api.data.gov.my';

  /// Threshold (mm/hr) above which a rainfall reading is treated as a heavy
  /// rain alert.
  static const double _heavyRainThresholdMmPerHr = 30.0;

  final Dio _dio;

  DisasterService({Dio? dio}) : _dio = dio ?? Dio();

  // -------------------------------------------------------------------------
  // Flood zones — JPS InfoBanjir /activefloods
  // -------------------------------------------------------------------------

  Future<List<FloodZone>> fetchFloodZones() async {
    try {
      final response = await _dio.get(
        '$_jpsBase/activefloods',
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
          headers: {'Accept': 'application/json'},
        ),
      );

      final raw = response.data;
      List<dynamic> items;

      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        items = (raw['data'] ?? raw['floods'] ?? raw['results'] ?? []) as List<dynamic>;
      } else {
        return [];
      }

      final zones = <FloodZone>[];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) continue;
        final zone = _parseFloodZone(item, i);
        if (zone != null) zones.add(zone);
      }
      return zones;
    } catch (e) {
      debugPrint('[DisasterService] fetchFloodZones error: $e');
      return [];
    }
  }

  FloodZone? _parseFloodZone(Map<dynamic, dynamic> m, int index) {
    try {
      // Coordinates: some endpoints return a GeoJSON polygon, others a lat/lng
      List<LatLng> points = [];
      LatLng? center;

      final geometry = m['geometry'];
      if (geometry is Map && geometry['coordinates'] is List) {
        final ring = geometry['coordinates'];
        List<dynamic> coords = ring;
        if (coords.isNotEmpty && coords.first is List && coords.first.first is List) {
          coords = coords.first as List<dynamic>;
        }
        for (final c in coords) {
          if (c is List && c.length >= 2) {
            final lng = _toDouble(c[0]);
            final lat = _toDouble(c[1]);
            if (lat != null && lng != null) points.add(LatLng(lat, lng));
          }
        }
      }

      final lat = _toDouble(m['latitude'] ?? m['lat'] ?? m['Latitude']);
      final lng = _toDouble(m['longitude'] ?? m['lng'] ?? m['Longitude']);
      if (lat != null && lng != null) center = LatLng(lat, lng);

      // At least one visual representation required
      if (points.isEmpty && center == null) return null;

      return FloodZone(
        id: (m['id'] ?? m['floodId'] ?? m['flood_id'] ?? index).toString(),
        name: (m['name'] ?? m['floodName'] ?? m['flood_area'] ?? 'Flood Area').toString(),
        district: (m['district'] ?? m['daerah'] ?? '').toString(),
        state: (m['state'] ?? m['negeri'] ?? '').toString(),
        severity: floodSeverityFromString(
          (m['severity'] ?? m['level'] ?? m['category'])?.toString(),
        ),
        points: points,
        center: center ?? (points.isNotEmpty ? points.first : null),
        updatedAt: _parseDateTime(m['updatedAt'] ?? m['updated_at'] ?? m['datetime']),
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Heavy rain alerts — JPS InfoBanjir /rainfall
  // -------------------------------------------------------------------------

  Future<List<HeavyRainAlert>> fetchHeavyRainAlerts() async {
    try {
      final response = await _dio.get(
        '$_jpsBase/rainfall',
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
          headers: {'Accept': 'application/json'},
        ),
      );

      final raw = response.data;
      List<dynamic> items;

      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        items = (raw['data'] ?? raw['stations'] ?? raw['results'] ?? []) as List<dynamic>;
      } else {
        return [];
      }

      final alerts = <HeavyRainAlert>[];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) continue;
        final alert = _parseRainfallStation(item, i);
        if (alert != null) alerts.add(alert);
      }
      return alerts;
    } catch (e) {
      debugPrint('[DisasterService] fetchHeavyRainAlerts error: $e');
      return [];
    }
  }

  HeavyRainAlert? _parseRainfallStation(Map<dynamic, dynamic> m, int index) {
    try {
      final lat = _toDouble(m['latitude'] ?? m['lat'] ?? m['Latitude']);
      final lng = _toDouble(m['longitude'] ?? m['lng'] ?? m['Longitude']);
      if (lat == null || lng == null) return null;

      final reading = _toDouble(
            m['reading'] ?? m['value'] ?? m['rainfall'] ?? m['rain_mm_per_hr'],
          ) ??
          0.0;
      if (reading < _heavyRainThresholdMmPerHr) return null;

      return HeavyRainAlert(
        id: (m['id'] ?? m['stationId'] ?? m['station_id'] ?? index).toString(),
        stationName:
            (m['name'] ?? m['stationName'] ?? m['station_name'] ?? 'Rain Station').toString(),
        district: (m['district'] ?? m['daerah'] ?? '').toString(),
        state: (m['state'] ?? m['negeri'] ?? '').toString(),
        rainfallMmPerHr: reading,
        position: LatLng(lat, lng),
        readingAt: _parseDateTime(m['datetime'] ?? m['readingAt'] ?? m['reading_at']),
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Landslide warnings — JPS water-level / slope data
  // The JPS API does not publish a dedicated landslide endpoint at the time of
  // writing, so we query the data.gov.my open-data catalogue for slope-related
  // incident records. Results are returned as best-effort.
  // -------------------------------------------------------------------------

  Future<List<LandslideWarning>> fetchLandslideWarnings() async {
    try {
      final response = await _dio.get(
        '$_dataGovBase/data-catalogue',
        queryParameters: {
          'id': 'slope_failure',
          'limit': 200,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
          headers: {'Accept': 'application/json'},
        ),
      );

      final raw = response.data;
      List<dynamic> items;

      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        items = (raw['data'] ?? raw['results'] ?? raw['records'] ?? []) as List<dynamic>;
      } else {
        return [];
      }

      final warnings = <LandslideWarning>[];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) continue;
        final w = _parseLandslideRecord(item, i);
        if (w != null) warnings.add(w);
      }
      return warnings;
    } catch (e) {
      debugPrint('[DisasterService] fetchLandslideWarnings error: $e');
      return [];
    }
  }

  LandslideWarning? _parseLandslideRecord(Map<dynamic, dynamic> m, int index) {
    try {
      final lat = _toDouble(m['latitude'] ?? m['lat'] ?? m['Latitude']);
      final lng = _toDouble(m['longitude'] ?? m['lng'] ?? m['Longitude']);
      if (lat == null || lng == null) return null;

      return LandslideWarning(
        id: (m['id'] ?? m['incidentId'] ?? m['incident_id'] ?? index).toString(),
        locationName:
            (m['location'] ?? m['locationName'] ?? m['location_name'] ?? 'Landslide Site')
                .toString(),
        district: (m['district'] ?? m['daerah'] ?? '').toString(),
        state: (m['state'] ?? m['negeri'] ?? '').toString(),
        risk: landslideRiskFromString(
          (m['risk'] ?? m['severity'] ?? m['level'])?.toString(),
        ),
        position: LatLng(lat, lng),
        reportedAt:
            _parseDateTime(m['reportedAt'] ?? m['reported_at'] ?? m['date'] ?? m['datetime']),
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Road closures — data.gov.my JKR catalogue
  // -------------------------------------------------------------------------

  Future<List<RoadClosure>> fetchRoadClosures() async {
    try {
      final response = await _dio.get(
        '$_dataGovBase/data-catalogue',
        queryParameters: {
          'id': 'jkr_road_closure',
          'limit': 200,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
          headers: {'Accept': 'application/json'},
        ),
      );

      final raw = response.data;
      List<dynamic> items;

      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        items = (raw['data'] ?? raw['results'] ?? raw['records'] ?? []) as List<dynamic>;
      } else {
        return [];
      }

      final closures = <RoadClosure>[];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) continue;
        final c = _parseRoadClosure(item, i);
        if (c != null) closures.add(c);
      }
      return closures;
    } catch (e) {
      debugPrint('[DisasterService] fetchRoadClosures error: $e');
      return [];
    }
  }

  RoadClosure? _parseRoadClosure(Map<dynamic, dynamic> m, int index) {
    try {
      List<LatLng> path = [];
      LatLng? center;

      // GeoJSON LineString support
      final geometry = m['geometry'];
      if (geometry is Map && geometry['coordinates'] is List) {
        final coords = geometry['coordinates'] as List<dynamic>;
        for (final c in coords) {
          if (c is List && c.length >= 2) {
            final lng = _toDouble(c[0]);
            final lat = _toDouble(c[1]);
            if (lat != null && lng != null) path.add(LatLng(lat, lng));
          }
        }
      }

      final lat = _toDouble(m['latitude'] ?? m['lat'] ?? m['Latitude']);
      final lng = _toDouble(m['longitude'] ?? m['lng'] ?? m['Longitude']);
      if (lat != null && lng != null) center = LatLng(lat, lng);

      if (path.isEmpty && center == null) return null;

      return RoadClosure(
        id: (m['id'] ?? m['closureId'] ?? m['closure_id'] ?? index).toString(),
        roadName: (m['road'] ?? m['roadName'] ?? m['road_name'] ?? m['jalan'] ?? 'Road').toString(),
        reason: (m['reason'] ?? m['sebab'] ?? m['cause'] ?? '').toString(),
        district: (m['district'] ?? m['daerah'] ?? '').toString(),
        state: (m['state'] ?? m['negeri'] ?? '').toString(),
        path: path,
        center: center ?? (path.isNotEmpty ? path.first : null),
        startDate: _parseDateTime(m['startDate'] ?? m['start_date'] ?? m['tarikh_mula']),
        endDate: _parseDateTime(m['endDate'] ?? m['end_date'] ?? m['tarikh_tamat']),
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

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

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }
    return null;
  }
}

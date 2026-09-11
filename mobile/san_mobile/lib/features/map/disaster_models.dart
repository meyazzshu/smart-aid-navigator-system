import 'package:google_maps_flutter/google_maps_flutter.dart';

// ---------------------------------------------------------------------------
// FloodZone — from JPS InfoBanjir active-floods API
// ---------------------------------------------------------------------------

enum FloodSeverity { low, medium, high }

FloodSeverity floodSeverityFromString(String? s) {
  switch (s?.toLowerCase()) {
    case 'high':
      return FloodSeverity.high;
    case 'medium':
      return FloodSeverity.medium;
    default:
      return FloodSeverity.low;
  }
}

class FloodZone {
  final String id;
  final String name;
  final String district;
  final String state;
  final FloodSeverity severity;

  /// Polygon boundary points (may be empty — fall back to a marker at [center]).
  final List<LatLng> points;

  /// Fallback centre used when [points] is empty.
  final LatLng? center;

  final DateTime? updatedAt;

  const FloodZone({
    required this.id,
    required this.name,
    required this.district,
    required this.state,
    required this.severity,
    required this.points,
    this.center,
    this.updatedAt,
  });
}

// ---------------------------------------------------------------------------
// RoadClosure — from data.gov.my / JKR road-closure catalogue
// ---------------------------------------------------------------------------

class RoadClosure {
  final String id;
  final String roadName;
  final String reason;
  final String district;
  final String state;

  /// Path of the closed road segment. Rendered as a polyline.
  final List<LatLng> path;

  /// Fallback centre marker when path has fewer than 2 points.
  final LatLng? center;

  final DateTime? startDate;
  final DateTime? endDate;

  const RoadClosure({
    required this.id,
    required this.roadName,
    required this.reason,
    required this.district,
    required this.state,
    required this.path,
    this.center,
    this.startDate,
    this.endDate,
  });
}

// ---------------------------------------------------------------------------
// LandslideWarning — derived from JPS / Slope Engineering Branch data
// ---------------------------------------------------------------------------

enum LandslideRisk { low, medium, high }

LandslideRisk landslideRiskFromString(String? s) {
  switch (s?.toLowerCase()) {
    case 'high':
      return LandslideRisk.high;
    case 'medium':
      return LandslideRisk.medium;
    default:
      return LandslideRisk.low;
  }
}

class LandslideWarning {
  final String id;
  final String locationName;
  final String district;
  final String state;
  final LandslideRisk risk;
  final LatLng position;
  final DateTime? reportedAt;

  const LandslideWarning({
    required this.id,
    required this.locationName,
    required this.district,
    required this.state,
    required this.risk,
    required this.position,
    this.reportedAt,
  });
}

// ---------------------------------------------------------------------------
// HeavyRainAlert — from JPS InfoBanjir rainfall stations
// ---------------------------------------------------------------------------

class HeavyRainAlert {
  final String id;
  final String stationName;
  final String district;
  final String state;

  /// Rainfall reading in mm/hr.
  final double rainfallMmPerHr;

  final LatLng position;
  final DateTime? readingAt;

  const HeavyRainAlert({
    required this.id,
    required this.stationName,
    required this.district,
    required this.state,
    required this.rainfallMmPerHr,
    required this.position,
    this.readingAt,
  });
}

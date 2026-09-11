import 'package:url_launcher/url_launcher.dart';
import 'package:meta/meta.dart';

class NavigationHelper {
  static bool _isValidLatitude(double value) => value >= -90 && value <= 90;
  static bool _isValidLongitude(double value) => value >= -180 && value <= 180;

  static ({double lat, double lng}) _normalizeCoordinates(double lat, double lng) {
    if (_isValidLatitude(lat) && _isValidLongitude(lng)) {
      return (lat: lat, lng: lng);
    }

    if (_isValidLatitude(lng) && _isValidLongitude(lat)) {
      return (lat: lng, lng: lat);
    }

    return (lat: lat, lng: lng);
  }

  @visibleForTesting
  static ({double lat, double lng}) normalizeCoordinates(double lat, double lng) {
    return _normalizeCoordinates(lat, lng);
  }

  /// Opens Google Maps directions to destination.
  /// travelMode: driving, walking, bicycling, transit
  static Future<bool> navigateTo({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
    String? destinationLabel,
    String travelMode = 'driving',
  }) async {
    final dest = normalizeCoordinates(destLat, destLng);

    final destination = destinationLabel == null || destinationLabel.trim().isEmpty
        ? '${dest.lat},${dest.lng}'
        : '${dest.lat},${dest.lng} (${destinationLabel.trim()})';

    final params = <String, String>{
      'api': '1',
      'destination': destination,
      'travelmode': travelMode,
    };

    if (originLat != null && originLng != null) {
      final origin = normalizeCoordinates(originLat, originLng);
      params['origin'] = '${origin.lat},${origin.lng}';
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', params);
    print('GOOGLE MAPS URL: $uri');

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens Google Maps to show a specific location pin
  static Future<bool> openLocation({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final q = label == null || label.trim().isEmpty
        ? '$lat,$lng'
        : Uri.encodeComponent('$label ($lat,$lng)');
    final url = 'https://www.google.com/maps/search/?api=1&query=$q';
    final uri = Uri.parse(url);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

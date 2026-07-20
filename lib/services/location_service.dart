import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

class RouteResult {
  final List<ll.LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class LocationService {
  // Free public OSRM demo server — no API key, no billing account needed.
  // It's a shared community server: not guaranteed uptime and can rate-limit
  // heavy traffic, so callers should throttle requests (see
  // order_tracking_screen.dart). If this app grows a lot, consider
  // self-hosting OSRM or switching to a paid provider at that point.
  static const _osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';

  static Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are turned off. Please enable GPS.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission is permanently denied. Enable it in app settings.');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<RouteResult> getRoute({
    required ll.LatLng from,
    required ll.LatLng to,
  }) async {
    final url = Uri.parse(
      '$_osrmBaseUrl/${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}?overview=full&geometries=geojson',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Routing server returned HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List?;
    if (data['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw Exception('No route found between rider and customer.');
    }

    final route = routes.first as Map<String, dynamic>;
    final coords = (route['geometry']['coordinates'] as List)
        .map((c) => ll.LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();

    return RouteResult(
      points: coords,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
    );
  }
}

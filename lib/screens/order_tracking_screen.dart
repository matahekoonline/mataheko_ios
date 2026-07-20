import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/okada_order.dart';
import '../models/okada_rider.dart';
import '../services/location_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OkadaOrder order;
  final OkadaRider rider;
  const OrderTrackingScreen({super.key, required this.order, required this.rider});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _mapController = MapController();
  StreamSubscription<DocumentSnapshot>? _riderLocSub;

  late final ll.LatLng _customerPos;
  ll.LatLng? _riderPos;
  DateTime? _riderPosUpdatedAt;

  List<ll.LatLng> _routePoints = [];
  double? _distanceMeters;
  double? _durationSeconds;
  DateTime? _lastRouteFetch;
  bool _fetchingRoute = false;
  String? _routeError;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _customerPos = ll.LatLng(widget.order.customerLat, widget.order.customerLng);
    _riderLocSub = FirebaseFirestore.instance
        .collection('rider_locations')
        .doc(widget.rider.id)
        .snapshots()
        .listen(_onRiderLocationUpdate);
  }

  void _onRiderLocationUpdate(DocumentSnapshot snap) {
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    setState(() {
      _riderPos = ll.LatLng(lat, lng);
      _riderPosUpdatedAt = DateTime.now();
    });
    _maybeFetchRoute();
    _fitBounds();
  }

  Future<void> _maybeFetchRoute() async {
    if (_riderPos == null || _fetchingRoute) return;
    // Throttle: the free OSRM demo server is shared public infrastructure,
    // so refresh the route at most every 15s rather than on every GPS ping.
    if (_lastRouteFetch != null &&
        DateTime.now().difference(_lastRouteFetch!) < const Duration(seconds: 15)) {
      return;
    }
    _fetchingRoute = true;
    _lastRouteFetch = DateTime.now();
    try {
      final result = await LocationService.getRoute(from: _riderPos!, to: _customerPos);
      if (!mounted) return;
      setState(() {
        _routePoints = result.points;
        _distanceMeters = result.distanceMeters;
        _durationSeconds = result.durationSeconds;
        _routeError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _routeError = 'Could not load route: $e');
    } finally {
      _fetchingRoute = false;
    }
  }

  void _fitBounds() {
    if (_riderPos == null || !_mapReady) return;
    final bounds = LatLngBounds.fromPoints([_riderPos!, _customerPos]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text('This will stop tracking this trip.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('okada_orders')
        .doc(widget.order.id)
        .update({'status': 'cancelled'});
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _riderLocSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riderStale = _riderPosUpdatedAt == null ||
        DateTime.now().difference(_riderPosUpdatedAt!) > const Duration(minutes: 2);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking ${widget.rider.riderName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel order',
            onPressed: _cancelOrder,
          ),
        ],
      ),
      body: Column(
        children: [
          if (riderStale)
            Container(
              width: double.infinity,
              color: Colors.orange[100],
              padding: const EdgeInsets.all(10),
              child: Text(
                _riderPos == null
                    ? 'Waiting for the rider to go online and share their location…'
                    : "Rider's location hasn't updated in a while.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange[900], fontSize: 12),
              ),
            ),
          if (_routeError != null)
            Container(
              width: double.infinity,
              color: Colors.red[50],
              padding: const EdgeInsets.all(8),
              child: Text(_routeError!,
                  style: const TextStyle(color: Colors.red, fontSize: 11), textAlign: TextAlign.center),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _riderPos ?? _customerPos,
                initialZoom: 14,
                onMapReady: () {
                  _mapReady = true;
                  _fitBounds();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // Required by OSM's usage policy — set this to your app's
                  // actual applicationId / package name.
                  userAgentPackageName: 'com.mataheko.app',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: _routePoints, strokeWidth: 4, color: Colors.green[700]!),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _customerPos,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 36),
                    ),
                    if (_riderPos != null)
                      Marker(
                        point: _riderPos!,
                        width: 40,
                        height: 40,
                        child: Icon(Icons.two_wheeler, color: Colors.green[800], size: 32),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_distanceMeters != null && _durationSeconds != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${(_distanceMeters! / 1000).toStringAsFixed(1)} km away · '
                '~${(_durationSeconds! / 60).ceil()} min',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import '../models/okada_order.dart';
import '../models/okada_rider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

/// Lets a rider "go online" so their live location streams to Firestore,
/// and — when an order is assigned to them — shows a live map guiding
/// them to the customer, with distance/ETA and a handoff to Google Maps
/// for actual turn-by-turn voice navigation.
///
/// Identification comes from the signed-in Firebase user: if
/// `okada_riders/{uid}` exists, this screen treats them as that rider
/// directly — no picking a name from a list.
///
/// Note: location only streams while this screen is open and the app is
/// in the foreground. Backgrounding the app or locking the phone stops
/// updates on Android. True background tracking needs
/// ACCESS_BACKGROUND_LOCATION + a foreground service — a bigger addition,
/// ask if you want that next.
class RiderModeScreen extends StatefulWidget {
  const RiderModeScreen({super.key});

  @override
  State<RiderModeScreen> createState() => _RiderModeScreenState();
}

class _RiderModeScreenState extends State<RiderModeScreen> {
  OkadaRider? _rider;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<QuerySnapshot>? _orderSub;
  final _mapController = MapController();

  bool _loading = true;
  bool _online = false;
  bool _connecting = false;
  String? _error;

  ll.LatLng? _riderPos;
  OkadaOrder? _activeOrder;
  List<ll.LatLng> _routePoints = [];
  double? _distanceMeters;
  double? _durationSeconds;
  DateTime? _lastRouteFetch;
  bool _fetchingRoute = false;
  String? _routeError;
  bool _mapReady = false;
  bool _followMode = true; // true = camera follows rider closely; false = overview of both points

  @override
  void initState() {
    super.initState();
    _loadRider();
  }

  Future<void> _loadRider() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'You need to be signed in to use Rider Mode.';
      });
      return;
    }

    final data = await AuthService.instance.getOkadaRiderDoc();
    if (!mounted) return;

    setState(() {
      _rider = data != null ? OkadaRider.fromMap(uid, data) : null;
      _online = data?['isOnline'] == true;
      _loading = false;
    });

    if (_rider != null) {
      _listenForActiveOrder(uid);
    }
  }

  void _listenForActiveOrder(String uid) {
    _orderSub = FirebaseFirestore.instance
        .collection('okada_orders')
        .where('riderId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        setState(() {
          _activeOrder = null;
          _routePoints = [];
          _distanceMeters = null;
          _durationSeconds = null;
        });
      } else {
        final order = OkadaOrder.fromMap(snap.docs.first.id, snap.docs.first.data());
        setState(() => _activeOrder = order);
        _maybeFetchRoute();
        _fitBounds();
      }
    });
  }

  Future<void> _maybeFetchRoute() async {
    if (_riderPos == null || _activeOrder == null || _fetchingRoute) return;
    // Throttle: the free OSRM demo server is shared public infrastructure,
    // so refresh the route at most every 15s rather than on every GPS ping.
    if (_lastRouteFetch != null &&
        DateTime.now().difference(_lastRouteFetch!) < const Duration(seconds: 15)) {
      return;
    }
    _fetchingRoute = true;
    _lastRouteFetch = DateTime.now();
    try {
      final destination = ll.LatLng(_activeOrder!.customerLat, _activeOrder!.customerLng);
      final result = await LocationService.getRoute(from: _riderPos!, to: destination);
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
    if (_riderPos == null || _activeOrder == null || !_mapReady) return;

    if (_followMode) {
      // Driving-style view: camera stays centered tightly on the rider,
      // zoomed in like an active navigation app.
      _mapController.move(_riderPos!, 17);
    } else {
      // Overview: zoom out just enough to show both the rider and the
      // customer pickup point on screen at once.
      final destination = ll.LatLng(_activeOrder!.customerLat, _activeOrder!.customerLng);
      final bounds = LatLngBounds.fromPoints([_riderPos!, destination]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    }
  }

  void _toggleFollowMode() {
    setState(() => _followMode = !_followMode);
    _fitBounds();
  }

  Future<void> _openInGoogleMaps() async {
    final order = _activeOrder;
    if (order == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${order.customerLat},${order.customerLng}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _goOnline() async {
    final rider = _rider;
    if (rider == null) return;

    setState(() {
      _error = null;
      _connecting = true;
    });

    try {
      await LocationService.getCurrentPosition(); // triggers permission prompt
    } catch (e) {
      setState(() {
        _error = 'Could not get location: $e';
        _connecting = false;
      });
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // meters — avoids spamming Firestore on tiny movements
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final newPos = ll.LatLng(pos.latitude, pos.longitude);
        setState(() => _riderPos = newPos);

        FirebaseFirestore.instance.collection('rider_locations').doc(rider.id).set(
          {
            'lat': pos.latitude,
            'lng': pos.longitude,
            'online': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (_activeOrder != null) {
          _maybeFetchRoute();
          _fitBounds();
        }
      },
      onError: (e) {
        if (mounted) setState(() => _error = 'Location stream error: $e');
      },
    );

    // Keep okada_riders/{uid}.isOnline in sync too, so other screens that
    // read the rider doc (rather than rider_locations) see the same status.
    await AuthService.instance.setRiderOnlineStatus(true);

    if (mounted) {
      setState(() {
        _online = true;
        _connecting = false;
      });
    }
  }

  Future<void> _goOffline() async {
    await _positionSub?.cancel();
    _positionSub = null;
    final rider = _rider;
    if (rider != null) {
      await FirebaseFirestore.instance.collection('rider_locations').doc(rider.id).set(
        {'online': false, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await AuthService.instance.setRiderOnlineStatus(false);
    }
    if (mounted) setState(() => _online = false);
  }

  Future<void> _completeOrder() async {
    final order = _activeOrder;
    if (order == null) return;
    await FirebaseFirestore.instance
        .collection('okada_orders')
        .doc(order.id)
        .update({'status': 'completed'});
  }

  Future<void> _cancelOrder() async {
    final order = _activeOrder;
    if (order == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this pickup?'),
        content: const Text('The customer will be notified this order was cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('okada_orders')
        .doc(order.id)
        .update({'status': 'cancelled'});
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _orderSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rider Mode')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rider == null
                ? Padding(padding: const EdgeInsets.all(20), child: _buildNotRegistered())
                : (_activeOrder != null && _online)
                    ? _buildActiveOrderMap()
                    : Padding(padding: const EdgeInsets.all(20), child: _buildIdleContent()),
      ),
    );
  }

  Widget _buildNotRegistered() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.motorcycle_outlined, size: 56, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'You\'re not registered as an Okada rider yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          _error ??
              'Complete your provider profile and select Okada as your category to start riding.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildIdleContent() {
    // Has an active order but hasn't gone online yet — prompt them to,
    // since going online is what starts location sharing + the live map.
    if (_activeOrder != null && !_online) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active, size: 56, color: Colors.orange[700]),
          const SizedBox(height: 16),
          const Text(
            'You have a new pickup!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Go online to start sharing your location and see the route to the customer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _connecting ? null : _goOnline,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _connecting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Go Online & Start Navigation'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_online) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.location_on, color: Colors.green[700], size: 40),
                const SizedBox(height: 8),
                Text(
                  'You are online as ${_rider?.riderName ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Waiting for a pickup. Your location is being shared while '
                  'this screen stays open.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _goOffline,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Go Offline'),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.motorcycle, color: Colors.black54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _rider?.riderName ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Tap Go Online to start sharing your location.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _connecting ? null : _goOnline,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _connecting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Go Online'),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveOrderMap() {
    final order = _activeOrder!;
    final destination = ll.LatLng(order.customerLat, order.customerLng);
    final riderStale = _riderPos == null;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.green[700],
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.two_wheeler, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Heading to customer pickup',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
                tooltip: 'Open in Google Maps (leaves app)',
                onPressed: _openInGoogleMaps,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Cancel pickup',
                onPressed: _cancelOrder,
              ),
            ],
          ),
        ),
        if (riderStale)
          Container(
            width: double.infinity,
            color: Colors.orange[100],
            padding: const EdgeInsets.all(8),
            child: Text(
              'Getting your location…',
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
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _riderPos ?? destination,
                  initialZoom: 14,
                  onMapReady: () {
                    _mapReady = true;
                    _fitBounds();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                        point: destination,
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
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(
                  onPressed: _toggleFollowMode,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green[800],
                  tooltip: _followMode ? 'Show full route' : 'Follow my location',
                  child: Icon(_followMode ? Icons.map_outlined : Icons.my_location),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_distanceMeters != null && _durationSeconds != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${(_distanceMeters! / 1000).toStringAsFixed(1)} km away · '
                    '~${(_durationSeconds! / 60).ceil()} min to customer',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleFollowMode,
                      icon: Icon(_followMode ? Icons.map_outlined : Icons.my_location),
                      label: Text(_followMode ? 'Show Route' : 'Follow Me'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _completeOrder,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Picked Up'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

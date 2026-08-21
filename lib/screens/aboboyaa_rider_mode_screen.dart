import 'package:flutter/material.dart';

import '../models/aboboyaa_rider.dart';
import '../services/auth_service.dart';

/// Lets a signed-in Aboboyaa rider toggle their own Available / Unavailable
/// status — the Aboboyaa equivalent of RiderModeScreen (Okada).
///
/// Aboboyaa riders don't have a live order/navigation system the way Okada
/// riders do (there's no AboboyaaOrder model), so this screen is simpler:
/// it just flips `aboboyaa_riders/{uid}.isAvailable`, which is the same
/// field AboboyaaRidersScreen's list and the "Available"/"Unavailable"
/// badge on AboboyaaDetailScreen read.
///
/// Identification comes from the signed-in Firebase user: if
/// `aboboyaa_riders/{uid}` exists, this screen treats them as that rider
/// directly — no picking a name from a list.
class AboboyaaRiderModeScreen extends StatefulWidget {
  const AboboyaaRiderModeScreen({super.key});

  @override
  State<AboboyaaRiderModeScreen> createState() =>
      _AboboyaaRiderModeScreenState();
}

class _AboboyaaRiderModeScreenState extends State<AboboyaaRiderModeScreen> {
  AboboyaaRider? _rider;
  bool _loading = true;
  bool _available = false;
  bool _updating = false;
  String? _error;

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

    final data = await AuthService.instance.getAboboyaaDoc();
    if (!mounted) return;

    setState(() {
      _rider = data != null ? AboboyaaRider.fromMap(uid, data) : null;
      _available = data?['isAvailable'] == true;
      _loading = false;
    });
  }

  Future<void> _setAvailability(bool available) async {
    setState(() {
      _updating = true;
      _error = null;
    });

    try {
      await AuthService.instance.setAboboyaaAvailability(available);
      if (mounted) setState(() => _available = available);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not update status: $e');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rider Mode')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rider == null
                  ? _buildNotRegistered()
                  : _buildStatusContent(),
        ),
      ),
    );
  }

  Widget _buildNotRegistered() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.two_wheeler, size: 56, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'You\'re not registered as an Aboboyaa rider yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          _error ??
              'Complete your provider profile and select Aboboyaa as your category to start riding.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStatusContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_rider!.isPending) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_top, color: Colors.orange[800]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Your registration is still pending admin approval. '
                    'You can set your status now, but you won\'t show up '
                    'publicly until approved.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _available ? Colors.green[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _available ? Colors.green[200]! : Colors.grey[300]!,
            ),
          ),
          child: Column(
            children: [
              Icon(
                _available ? Icons.check_circle : Icons.radio_button_unchecked,
                color: _available ? Colors.green[700] : Colors.grey[500],
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                _available
                    ? 'You are Available as ${_rider!.riderName}'
                    : 'You are Unavailable',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _available
                    ? 'Customers can see you as an available Aboboyaa rider.'
                    : 'Switch on to let customers know you can take loads.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          onPressed: _updating ? null : () => _setAvailability(!_available),
          style: ElevatedButton.styleFrom(
            backgroundColor: _available ? Colors.red[600] : Colors.green[700],
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _updating
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_available ? 'Go Unavailable' : 'Go Available'),
        ),
      ],
    );
  }
}

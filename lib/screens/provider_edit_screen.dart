import 'package:flutter/material.dart';
import '../models/admin_provider_record.dart';
import '../services/auth_service.dart';

/// Admin-only screen for one provider. Renders every field in the raw
/// Firestore doc as an editable control (String/num/bool/List<String>),
/// since the 7 category collections don't share a schema and a
/// hand-built form per category would be 7x the maintenance. Timestamp
/// fields (createdAt/updatedAt) are shown read-only since editing them
/// doesn't make sense.
///
/// Also exposes: approve/unapprove, delete the provider listing only, and
/// delete the provider listing + linked users/{uid} profile doc. See
/// AuthService.deleteUserAccountData for why the Firebase Auth account
/// itself isn't touched by any of this.
class ProviderEditScreen extends StatefulWidget {
  final AdminProviderRecord record;
  const ProviderEditScreen({super.key, required this.record});

  @override
  State<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

class _ProviderEditScreenState extends State<ProviderEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _original;
  late List<String> _editableKeys;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _boolValues = {};
  bool _saving = false;
  late bool _isApproved;

  static const _readOnlyKeys = {'createdAt', 'updatedAt'};

  @override
  void initState() {
    super.initState();
    _original = Map<String, dynamic>.from(widget.record.data);
    _isApproved = widget.record.isApproved;

    _editableKeys = _original.keys.where((k) => !_readOnlyKeys.contains(k)).toList()
      ..sort();

    for (final key in _editableKeys) {
      final value = _original[key];
      if (value is bool) {
        _boolValues[key] = value;
      } else if (value is List) {
        _controllers[key] = TextEditingController(text: value.join(', '));
      } else {
        _controllers[key] = TextEditingController(text: value?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildUpdatedData() {
    final updated = <String, dynamic>{};
    for (final key in _editableKeys) {
      final originalValue = _original[key];
      if (originalValue is bool) {
        updated[key] = _boolValues[key];
      } else if (originalValue is List) {
        final text = _controllers[key]!.text;
        updated[key] = text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (originalValue is int) {
        updated[key] = int.tryParse(_controllers[key]!.text.trim()) ?? originalValue;
      } else if (originalValue is double) {
        updated[key] = double.tryParse(_controllers[key]!.text.trim()) ?? originalValue;
      } else {
        updated[key] = _controllers[key]!.text.trim();
      }
    }
    return updated;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AuthService.instance.updateProviderRecord(
        widget.record.collection,
        widget.record.id,
        _buildUpdatedData(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleApproval() async {
    setState(() => _saving = true);
    try {
      await AuthService.instance.setProviderApproved(
        widget.record.collection,
        widget.record.id,
        !_isApproved,
      );
      setState(() => _isApproved = !_isApproved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete({required bool includeUserAccount}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(includeUserAccount
            ? 'Delete provider & user data?'
            : 'Delete this listing?'),
        content: Text(
          includeUserAccount
              ? 'This permanently deletes "${widget.record.displayName}" from '
                  '${widget.record.category} and removes their users/ profile '
                  'doc, so they lose admin/role status and no longer appear '
                  'anywhere in the app.\n\n'
                  "Note: this does NOT delete their Firebase Auth login itself "
                  "— the client app can't delete another user's Auth account. "
                  "If you need to fully revoke their login too, remove them "
                  "from Firebase Console > Authentication, or set up a Cloud "
                  "Function for it.\n\nThis can't be undone."
              : 'This permanently removes "${widget.record.displayName}" '
                  'from the ${widget.record.category} list. Their user '
                  'account and role are left untouched.\n\nThis can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      if (includeUserAccount) {
        await AuthService.instance.deleteProviderAndUserData(
          collection: widget.record.collection,
          providerId: widget.record.id,
          possibleUid: widget.record.possibleUid,
        );
      } else {
        await AuthService.instance
            .deleteProviderRecord(widget.record.collection, widget.record.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Deleted.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fieldFor(String key) {
    final originalValue = _original[key];

    if (originalValue is bool) {
      return SwitchListTile(
        title: Text(key),
        value: _boolValues[key] ?? false,
        activeColor: Colors.green[700],
        onChanged: (v) => setState(() => _boolValues[key] = v),
      );
    }

    final isList = originalValue is List;
    final isNumber = originalValue is num;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: isList ? 2 : 1,
        decoration: InputDecoration(
          labelText: key,
          helperText: isList ? 'Comma-separated' : null,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record.displayName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _saving
                ? null
                : () => showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.person_off_outlined),
                              title: const Text('Delete listing only'),
                              subtitle:
                                  const Text('Keeps their user account/role'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _confirmDelete(includeUserAccount: false);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.delete_forever,
                                  color: Colors.red[700]),
                              title: const Text('Delete listing + user data'),
                              subtitle: const Text('Removes their profile too'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _confirmDelete(includeUserAccount: true);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(widget.record.category),
                        backgroundColor: Colors.green[100],
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: Icon(
                          _isApproved ? Icons.check_circle : Icons.hourglass_empty,
                          size: 16,
                          color: _isApproved ? Colors.green[800] : Colors.orange[800],
                        ),
                        label: Text(_isApproved ? 'Approved' : 'Pending'),
                        backgroundColor:
                            _isApproved ? Colors.green[50] : Colors.orange[50],
                        onPressed: _toggleApproval,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._editableKeys.map(_fieldFor),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Changes'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

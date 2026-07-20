import 'package:flutter/material.dart';
import '../models/sports_models.dart';
import '../services/sports_service.dart';

class AddEditFixtureScreen extends StatefulWidget {
  final String sportType;
  final bool hasGoals;
  final List<SportsTeam> teams;
  final SportsFixture? existing;

  const AddEditFixtureScreen({
    super.key,
    required this.sportType,
    required this.hasGoals,
    required this.teams,
    this.existing,
  });

  @override
  State<AddEditFixtureScreen> createState() => _AddEditFixtureScreenState();
}

class _AddEditFixtureScreenState extends State<AddEditFixtureScreen> {
  String? _homeTeamId;
  String? _awayTeamId;
  late DateTime _matchDate;
  late final TextEditingController _venueController;
  bool _completed = false;
  late final TextEditingController _homeScoreController;
  late final TextEditingController _awayScoreController;
  late List<FixtureScorer> _scorers;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _homeTeamId = e?.homeTeamId ?? (widget.teams.isNotEmpty ? widget.teams.first.id : null);
    _awayTeamId = e?.awayTeamId ?? (widget.teams.length > 1 ? widget.teams[1].id : null);
    _matchDate = e?.matchDate ?? DateTime.now().add(const Duration(days: 1));
    _venueController = TextEditingController(text: e?.venue ?? '');
    _completed = e?.status == 'completed';
    _homeScoreController = TextEditingController(text: e?.homeScore?.toString() ?? '');
    _awayScoreController = TextEditingController(text: e?.awayScore?.toString() ?? '');
    _scorers = List<FixtureScorer>.from(e?.scorers ?? const []);
  }

  @override
  void dispose() {
    _venueController.dispose();
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  String _teamName(String? id) => widget.teams
      .firstWhere((t) => t.id == id, orElse: () => const SportsTeam(id: '', sportType: '', name: 'Unknown'))
      .name;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_matchDate));
    if (time == null) return;
    setState(() {
      _matchDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _addScorerDialog() async {
    final homeId = _homeTeamId;
    final awayId = _awayTeamId;
    if (homeId == null || awayId == null) return;

    String selectedTeamId = homeId;
    SportsPlayer? selectedPlayer;
    final goalsController = TextEditingController(text: '1');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Add Goal Scorer'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<String>(
                      value: selectedTeamId,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(value: homeId, child: Text(_teamName(homeId))),
                        DropdownMenuItem(value: awayId, child: Text(_teamName(awayId))),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          selectedTeamId = v;
                          selectedPlayer = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<SportsPlayer>>(
                      stream: SportsService.instance.playersStream(widget.sportType, teamId: selectedTeamId),
                      builder: (context, snap) {
                        final players = snap.data ?? const <SportsPlayer>[];
                        if (players.isEmpty) {
                          return const Text('No players on this team yet.');
                        }
                        return DropdownButton<SportsPlayer>(
                          value: selectedPlayer,
                          isExpanded: true,
                          hint: const Text('Select player'),
                          items:
                              players.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                          onChanged: (p) => setDialogState(() => selectedPlayer = p),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: goalsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Goals'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    final player = selectedPlayer;
                    final goals = int.tryParse(goalsController.text.trim()) ?? 0;
                    if (player == null || goals <= 0) return;
                    setState(() {
                      _scorers.add(FixtureScorer(
                        playerId: player.id,
                        playerName: player.name,
                        teamId: selectedTeamId,
                        teamName: _teamName(selectedTeamId),
                        goals: goals,
                      ));
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (_homeTeamId == null || _awayTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick both teams')));
      return;
    }
    if (_homeTeamId == _awayTeamId) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Home and away teams must be different')));
      return;
    }
    final venue = _venueController.text.trim();
    int? homeScore;
    int? awayScore;
    if (_completed) {
      homeScore = int.tryParse(_homeScoreController.text.trim());
      awayScore = int.tryParse(_awayScoreController.text.trim());
      if (homeScore == null || awayScore == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter both scores')));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final fixture = SportsFixture(
        id: widget.existing?.id ?? '',
        sportType: widget.sportType,
        homeTeamId: _homeTeamId!,
        homeTeamName: _teamName(_homeTeamId),
        awayTeamId: _awayTeamId!,
        awayTeamName: _teamName(_awayTeamId),
        matchDate: _matchDate,
        venue: venue,
        status: _completed ? 'completed' : 'scheduled',
        homeScore: homeScore,
        awayScore: awayScore,
        scorers: _completed ? _scorers : const [],
      );

      if (_isEditing) {
        await SportsService.instance.updateFixture(widget.existing!.id, fixture.toMap());
      } else {
        await SportsService.instance.addFixture(fixture);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete fixture?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SportsService.instance.deleteFixture(widget.existing!.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.teams.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Fixture')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Add at least two teams before creating fixtures.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Fixture' : 'Add Fixture'),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete, tooltip: 'Delete fixture'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _homeTeamId,
            decoration: const InputDecoration(labelText: 'Home team', border: OutlineInputBorder()),
            items: widget.teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (v) => setState(() => _homeTeamId = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _awayTeamId,
            decoration: const InputDecoration(labelText: 'Away team', border: OutlineInputBorder()),
            items: widget.teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (v) => setState(() => _awayTeamId = v),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date & time'),
            subtitle: Text(formatMatchDate(_matchDate)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _venueController,
            decoration: const InputDecoration(labelText: 'Venue', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Match completed'),
            subtitle: const Text('Turn on once the match has a final score'),
            value: _completed,
            activeColor: Colors.green[700],
            onChanged: (v) => setState(() => _completed = v),
          ),
          if (_completed) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _homeScoreController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Home score', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _awayScoreController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Away score', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            if (widget.hasGoals) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Goal Scorers', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addScorerDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_scorers.isEmpty)
                const Text('No scorers added yet.', style: TextStyle(color: Colors.grey))
              else
                ..._scorers.asMap().entries.map((entry) {
                  final s = entry.value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${s.playerName} (${s.teamName})'),
                    subtitle: Text('${s.goals} goal${s.goals == 1 ? '' : 's'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _scorers.removeAt(entry.key)),
                    ),
                  );
                }),
            ],
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Fixture'),
            ),
          ),
        ],
      ),
    );
  }
}

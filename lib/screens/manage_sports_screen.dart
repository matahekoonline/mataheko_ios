import 'package:flutter/material.dart';
import '../models/sports_models.dart';
import '../services/sports_service.dart';
import 'add_edit_team_screen.dart';
import 'add_edit_player_screen.dart';
import 'add_edit_fixture_screen.dart';

class ManageSportsScreen extends StatefulWidget {
  const ManageSportsScreen({super.key});

  @override
  State<ManageSportsScreen> createState() => _ManageSportsScreenState();
}

class _ManageSportsScreenState extends State<ManageSportsScreen> {
  String _sportType = 'football';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Sports'),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'football', label: Text('Football'), icon: Icon(Icons.sports_soccer)),
                      ButtonSegment(
                          value: 'volleyball', label: Text('Volleyball'), icon: Icon(Icons.sports_volleyball)),
                    ],
                    selected: {_sportType},
                    onSelectionChanged: (s) => setState(() => _sportType = s.first),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'League'),
                    Tab(text: 'Teams'),
                    Tab(text: 'Players'),
                    Tab(text: 'Fixtures'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _LeagueTab(sportType: _sportType),
            _TeamsTab(sportType: _sportType),
            _PlayersTab(sportType: _sportType),
            _FixturesTab(sportType: _sportType),
          ],
        ),
      ),
    );
  }
}

class _LeagueTab extends StatefulWidget {
  final String sportType;
  const _LeagueTab({required this.sportType});

  @override
  State<_LeagueTab> createState() => _LeagueTabState();
}

class _LeagueTabState extends State<_LeagueTab> {
  final _controller = TextEditingController();
  bool _hasGoals = true;
  bool _saving = false;
  String? _loadedFor;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SportsService.instance.setLeagueName(widget.sportType, _controller.text.trim());
      await SportsService.instance.setHasGoals(widget.sportType, _hasGoals);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SportsLeagueConfig>(
      stream: SportsService.instance.configStream(widget.sportType),
      builder: (context, snap) {
        final config = snap.data;
        // Only seed the local controller/switch the first time this sport's
        // config arrives -- otherwise every live Firestore update would
        // stomp on whatever the admin is mid-typing.
        if (config != null && _loadedFor != widget.sportType) {
          _controller.text = config.leagueName;
          _hasGoals = config.hasGoals;
          _loadedFor = widget.sportType;
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'League name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Track goals & top scorers'),
              subtitle: const Text('Shows GF/GA/GD columns and a top scorers list'),
              value: _hasGoals,
              activeColor: Colors.green[700],
              onChanged: (v) => setState(() => _hasGoals = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green[700]),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _TeamsTab extends StatelessWidget {
  final String sportType;
  const _TeamsTab({required this.sportType});

  Future<void> _confirmDelete(BuildContext context, SportsTeam team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete team?'),
        content: Text("This also removes ${team.name}'s players and fixtures. This cannot be undone."),
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
    if (confirmed == true) {
      await SportsService.instance.deleteTeam(team.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<SportsTeam>>(
        stream: SportsService.instance.teamsStream(sportType),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final teams = snap.data!;
          if (teams.isEmpty) return const Center(child: Text('No teams yet. Tap + to add one.'));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final t = teams[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[50],
                    backgroundImage:
                        (t.logoUrl != null && t.logoUrl!.isNotEmpty) ? NetworkImage(t.logoUrl!) : null,
                    child: (t.logoUrl == null || t.logoUrl!.isEmpty)
                        ? const Icon(Icons.shield_outlined)
                        : null,
                  ),
                  title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, t),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddEditTeamScreen(sportType: sportType, existing: t)),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditTeamScreen(sportType: sportType)),
        ),
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.add),
        label: const Text('Add Team'),
      ),
    );
  }
}

class _PlayersTab extends StatefulWidget {
  final String sportType;
  const _PlayersTab({required this.sportType});

  @override
  State<_PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<_PlayersTab> {
  String? _selectedTeamId;

  Future<void> _confirmDelete(BuildContext context, SportsPlayer player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete player?'),
        content: Text('Remove ${player.name}? This cannot be undone.'),
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
    if (confirmed == true) {
      await SportsService.instance.deletePlayer(player.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SportsTeam>>(
      stream: SportsService.instance.teamsStream(widget.sportType),
      builder: (context, teamsSnap) {
        final teams = teamsSnap.data ?? const <SportsTeam>[];
        if (teams.isEmpty) {
          return const Center(child: Text('Add a team first before adding players.'));
        }
        _selectedTeamId ??= teams.first.id;
        if (!teams.any((t) => t.id == _selectedTeamId)) {
          _selectedTeamId = teams.first.id;
        }
        final selectedTeamId = _selectedTeamId!;

        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  value: selectedTeamId,
                  decoration: const InputDecoration(labelText: 'Team', border: OutlineInputBorder()),
                  items: teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                  onChanged: (v) => setState(() => _selectedTeamId = v),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<SportsPlayer>>(
                  stream: SportsService.instance.playersStream(widget.sportType, teamId: selectedTeamId),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final players = snap.data!;
                    if (players.isEmpty) return const Center(child: Text('No players on this team yet.'));
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final p = players[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[50],
                              backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty)
                                  ? NetworkImage(p.photoUrl!)
                                  : null,
                              child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                                  ? const Icon(Icons.person_outline)
                                  : null,
                            ),
                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text([
                              if (p.jerseyNumber != null) '#${p.jerseyNumber}',
                              if (p.position != null && p.position!.isNotEmpty) p.position!,
                            ].join(' · ')),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(context, p),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEditPlayerScreen(
                                  sportType: widget.sportType,
                                  teamId: selectedTeamId,
                                  existing: p,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditPlayerScreen(sportType: widget.sportType, teamId: selectedTeamId),
              ),
            ),
            backgroundColor: Colors.green[700],
            icon: const Icon(Icons.add),
            label: const Text('Add Player'),
          ),
        );
      },
    );
  }
}

class _FixturesTab extends StatelessWidget {
  final String sportType;
  const _FixturesTab({required this.sportType});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SportsLeagueConfig>(
      stream: SportsService.instance.configStream(sportType),
      builder: (context, configSnap) {
        final hasGoals = configSnap.data?.hasGoals ?? (sportType == 'football');

        return StreamBuilder<List<SportsTeam>>(
          stream: SportsService.instance.teamsStream(sportType),
          builder: (context, teamsSnap) {
            final teams = teamsSnap.data ?? const <SportsTeam>[];

            return Scaffold(
              body: StreamBuilder<List<SportsFixture>>(
                stream: SportsService.instance.fixturesStream(sportType),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final fixtures = snap.data!;
                  if (fixtures.isEmpty) return const Center(child: Text('No fixtures yet. Tap + to add one.'));
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: fixtures.length,
                    itemBuilder: (context, index) {
                      final f = fixtures[index];
                      final completed = f.isCompleted;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text('${f.homeTeamName} vs ${f.awayTeamName}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${formatMatchDate(f.matchDate)} · ${f.venue}'),
                          trailing: completed
                              ? Text('${f.homeScore} - ${f.awayScore}',
                                  style: const TextStyle(fontWeight: FontWeight.bold))
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration:
                                      BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                                  child: Text('Scheduled',
                                      style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                                ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditFixtureScreen(
                                sportType: sportType,
                                hasGoals: hasGoals,
                                teams: teams,
                                existing: f,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: teams.length < 2
                    ? () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Add at least two teams first')))
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddEditFixtureScreen(sportType: sportType, hasGoals: hasGoals, teams: teams),
                          ),
                        ),
                backgroundColor: Colors.green[700],
                icon: const Icon(Icons.add),
                label: const Text('Add Fixture'),
              ),
            );
          },
        );
      },
    );
  }
}

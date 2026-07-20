import 'package:flutter/material.dart';
import '../models/sports_models.dart';
import '../services/sports_service.dart';

class SportsScreen extends StatelessWidget {
  const SportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community Sports'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.sports_soccer), text: 'Football'),
              Tab(icon: Icon(Icons.sports_volleyball), text: 'Volleyball'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SportView(sportType: 'football'),
            _SportView(sportType: 'volleyball'),
          ],
        ),
      ),
    );
  }
}

class _SportView extends StatelessWidget {
  final String sportType;
  const _SportView({required this.sportType});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SportsLeagueConfig>(
      stream: SportsService.instance.configStream(sportType),
      builder: (context, configSnap) {
        final config = configSnap.data ??
            SportsLeagueConfig(
              sportType: sportType,
              leagueName: sportType == 'football'
                  ? 'Community Football League'
                  : 'Community Volleyball League',
              hasGoals: sportType == 'football',
            );

        return StreamBuilder<List<SportsTeam>>(
          stream: SportsService.instance.teamsStream(sportType),
          builder: (context, teamsSnap) {
            final teams = teamsSnap.data ?? const <SportsTeam>[];

            return StreamBuilder<List<SportsFixture>>(
              stream: SportsService.instance.fixturesStream(sportType),
              builder: (context, fixturesSnap) {
                if (fixturesSnap.hasError) {
                  return Center(child: Text('Error: ${fixturesSnap.error}'));
                }
                if (!teamsSnap.hasData || !fixturesSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allFixtures = fixturesSnap.data!;
                final standings = SportsService.instance.computeStandings(
                  teams: teams,
                  fixtures: allFixtures,
                  includeGoals: config.hasGoals,
                );
                final topScorers = config.hasGoals
                    ? SportsService.instance.computeTopScorers(allFixtures)
                    : const <TopScorer>[];

                final upcoming = allFixtures.where((f) => f.status == 'scheduled').toList()
                  ..sort((a, b) => a.matchDate.compareTo(b.matchDate));
                final completed = allFixtures.where((f) => f.isCompleted).toList()
                  ..sort((a, b) => b.matchDate.compareTo(a.matchDate));

                final fixtureVms = upcoming
                    .map((f) => Fixture(
                          id: f.id,
                          homeTeam: f.homeTeamName,
                          awayTeam: f.awayTeamName,
                          dateText: formatMatchDate(f.matchDate),
                          venue: f.venue,
                        ))
                    .toList();

                final resultVms = completed
                    .map((f) => MatchResult(
                          id: f.id,
                          homeTeam: f.homeTeamName,
                          awayTeam: f.awayTeamName,
                          homeScore: f.homeScore ?? 0,
                          awayScore: f.awayScore ?? 0,
                          dateText: formatMatchDate(f.matchDate),
                        ))
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      config.leagueName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle('League Table'),
                    const SizedBox(height: 8),
                    _StandingsTable(standings: standings),
                    if (topScorers.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _SectionTitle('Top Scorers'),
                      const SizedBox(height: 8),
                      _TopScorersList(scorers: topScorers),
                    ],
                    const SizedBox(height: 24),
                    const _SectionTitle('Upcoming Fixtures'),
                    const SizedBox(height: 8),
                    if (fixtureVms.isEmpty)
                      const Text('No fixtures scheduled.')
                    else
                      ...fixtureVms.map((f) => _FixtureCard(fixture: f)),
                    const SizedBox(height: 24),
                    const _SectionTitle('Recent Results'),
                    const SizedBox(height: 8),
                    if (resultVms.isEmpty)
                      const Text('No results yet.')
                    else
                      ...resultVms.map((r) => _ResultCard(result: r)),
                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TopScorersList extends StatelessWidget {
  final List<TopScorer> scorers;
  const _TopScorersList({required this.scorers});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: scorers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final s = scorers[index];
          return Container(
            width: 120,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.green[100],
                  child: Icon(Icons.person, color: Colors.green[800], size: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  s.playerName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  s.teamName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.goals} goals',
                  style: TextStyle(fontSize: 11, color: Colors.green[800], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<TeamStanding> standings;
  const _StandingsTable({required this.standings});

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const Text('No standings available.');
    }
    final showGoals = standings.first.goalsFor != null;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 44,
          columnSpacing: 18,
          columns: [
            const DataColumn(label: Text('#')),
            const DataColumn(label: Text('Team')),
            const DataColumn(label: Text('P')),
            const DataColumn(label: Text('W')),
            const DataColumn(label: Text('D')),
            const DataColumn(label: Text('L')),
            if (showGoals) const DataColumn(label: Text('GF')),
            if (showGoals) const DataColumn(label: Text('GA')),
            if (showGoals) const DataColumn(label: Text('GD')),
            const DataColumn(label: Text('Pts')),
          ],
          rows: [
            for (int i = 0; i < standings.length; i++)
              DataRow(
                cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(
                    Text(
                      standings[i].teamName,
                      style: TextStyle(
                        fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  DataCell(Text('${standings[i].played}')),
                  DataCell(Text('${standings[i].won}')),
                  DataCell(Text('${standings[i].drawn}')),
                  DataCell(Text('${standings[i].lost}')),
                  if (showGoals) DataCell(Text('${standings[i].goalsFor}')),
                  if (showGoals) DataCell(Text('${standings[i].goalsAgainst}')),
                  if (showGoals) DataCell(Text('${standings[i].goalDifference}')),
                  DataCell(
                    Text(
                      '${standings[i].points}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  final Fixture fixture;
  const _FixtureCard({required this.fixture});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${fixture.homeTeam} vs ${fixture.awayTeam}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(Icons.calendar_today, size: 14, color: Colors.green[700]),
              ],
            ),
            const SizedBox(height: 6),
            Text(fixture.dateText, style: TextStyle(color: Colors.green[800], fontSize: 12)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_on, size: 12, color: Colors.grey),
                const SizedBox(width: 2),
                Text(fixture.venue, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final MatchResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                result.homeTeam,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${result.homeScore} - ${result.awayScore}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900]),
              ),
            ),
            Expanded(
              child: Text(
                result.awayTeam,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

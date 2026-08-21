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
                return StreamBuilder<List<SportsPlayer>>(
                  stream: SportsService.instance.playersStream(sportType),
                  builder: (context, playersSnap) {
                    final players = playersSnap.data ?? const <SportsPlayer>[];
                    final standings = SportsService.instance.computeStandings(
                  teams: teams,
                  fixtures: allFixtures,
                  includeGoals: config.hasGoals,
                );
                final topScorers = config.hasGoals
                    ? SportsService.instance.computeTopScorers(
                        allFixtures,
                        players: players,
                        teams: teams,
                        limit: 5,
                      )
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
                    if (sportType == 'football') ...[
                      const SizedBox(height: 24),
                      const _SectionTitle('League Sponsors'),
                      const SizedBox(height: 8),
                      const _SponsorFooter(),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
                  },
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
      height: 174,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: scorers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final s = scorers[index];
          return SizedBox(
            width: 150,
            child: Card(
              elevation: index == 0 ? 3 : 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: Colors.green[50],
                            backgroundImage: (s.playerPhotoUrl != null && s.playerPhotoUrl!.isNotEmpty)
                                ? NetworkImage(s.playerPhotoUrl!)
                                : null,
                            child: (s.playerPhotoUrl == null || s.playerPhotoUrl!.isEmpty)
                                ? Icon(Icons.person, size: 38, color: Colors.green[700])
                                : null,
                          ),
                          Positioned(
                            right: 2,
                            bottom: -2,
                            child: Container(
                              width: 38,
                              height: 38,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: (s.teamLogoUrl != null && s.teamLogoUrl!.isNotEmpty)
                                  ? ClipOval(child: Image.network(s.teamLogoUrl!, fit: BoxFit.contain))
                                  : Icon(Icons.shield_outlined, size: 22, color: Colors.green[700]),
                            ),
                          ),
                          if (index == 0)
                            Positioned(
                              left: 2,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber[700],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'TOP',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.playerName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    Text(
                      s.teamName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${s.goals} goals',
                      style: TextStyle(fontSize: 11, color: Colors.green[800], fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SponsorFooter extends StatefulWidget {
  const _SponsorFooter();

  @override
  State<_SponsorFooter> createState() => _SponsorFooterState();
}

class _SponsorFooterState extends State<_SponsorFooter> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeagueSponsor>>(
      stream: SportsService.instance.sponsorsStream('football'),
      builder: (context, snapshot) {
        final sponsors = snapshot.data ?? const <LeagueSponsor>[];
        if (sponsors.isEmpty) {
          return Container(
            height: 105,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text('League sponsors will appear here.'),
          );
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final count = sponsors.length;
                final slot = width / count;
                final logoWidth = (slot - 12).clamp(58.0, 92.0);
                final enterStagger = count <= 1 ? 0.0 : 0.10 / (count - 1);
                final exitStagger = enterStagger;
                final enterStart = 0.0;
                final enterEnd = 0.24;
                final holdEnd = 0.67;
                final exitStart = holdEnd;
                final exitEnd = 0.91;

                return Container(
                  height: 116,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade50, Colors.white, Colors.green.shade50],
                            ),
                          ),
                        ),
                      ),
                      for (int i = 0; i < sponsors.length; i++)
                        _AnimatedSponsorLogo(
                          sponsor: sponsors[i],
                          index: i,
                          count: count,
                          controllerValue: _controller.value,
                          slot: slot,
                          logoWidth: logoWidth,
                          enterStagger: enterStagger,
                          exitStagger: exitStagger,
                          enterStart: enterStart,
                          enterEnd: enterEnd,
                          exitStart: exitStart,
                          exitEnd: exitEnd,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AnimatedSponsorLogo extends StatelessWidget {
  final LeagueSponsor sponsor;
  final int index;
  final int count;
  final double controllerValue;
  final double slot;
  final double logoWidth;
  final double enterStagger;
  final double exitStagger;
  final double enterStart;
  final double enterEnd;
  final double exitStart;
  final double exitEnd;

  const _AnimatedSponsorLogo({
    required this.sponsor,
    required this.index,
    required this.count,
    required this.controllerValue,
    required this.slot,
    required this.logoWidth,
    required this.enterStagger,
    required this.exitStagger,
    required this.enterStart,
    required this.enterEnd,
    required this.exitStart,
    required this.exitEnd,
  });

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final enterDelay = index * enterStagger;
    final exitDelay = index * exitStagger;
    final enterA = enterStart + enterDelay;
    final enterB = enterEnd + enterDelay;
    final exitA = exitStart + exitDelay;
    final exitB = exitEnd + exitDelay;

    double progress;
    if (controllerValue < enterA) {
      progress = -1;
    } else if (controllerValue < enterB) {
      progress = _lerp(-1, 0, ((controllerValue - enterA) / (enterB - enterA)).clamp(0.0, 1.0));
    } else if (controllerValue < exitA) {
      progress = 0;
    } else if (controllerValue < exitB) {
      progress = _lerp(0, -1, ((controllerValue - exitA) / (exitB - exitA)).clamp(0.0, 1.0));
    } else {
      progress = -1;
    }

    final baseLeft = index * slot + (slot - logoWidth) / 2;
    final left = progress == -1
        ? (controllerValue < enterA ? slot * count + 20 : -logoWidth - 20)
        : baseLeft + progress * (slot * count + logoWidth);

    return Positioned(
      left: left,
      top: 12,
      width: logoWidth,
      height: 92,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
              ),
              child: sponsor.logoUrl.isEmpty
                  ? const Icon(Icons.business, size: 34)
                  : Image.network(
                      sponsor.logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 34),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sponsor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ],
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

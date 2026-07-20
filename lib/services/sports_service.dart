import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sports_models.dart';

/// Formats a match DateTime like the original hardcoded sample data did
/// (e.g. "Sat, 5 Jul · 4:00 PM"), without pulling in the intl package.
String formatMatchDate(DateTime d) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final weekday = weekdays[d.weekday - 1];
  final month = months[d.month - 1];
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '$weekday, ${d.day} $month · $hour12:$minute $ampm';
}

/// Firestore-backed sports management: leagues, teams, players, fixtures.
/// Collections: `sports_config` (doc id = sportType), `sports_teams`,
/// `sports_players`, `sports_fixtures`.
///
/// Standings and top-scorers are deliberately NOT stored -- they're
/// computed live from completed fixtures via [computeStandings] /
/// [computeTopScorers] every time they're read, so a score edit
/// automatically ripples through everywhere without any separate
/// "recalculate" step.
class SportsService {
  SportsService._();
  static final SportsService instance = SportsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------
  // League config
  // ---------------------------------------------------------------------

  String _defaultLeagueName(String sportType) => sportType == 'football'
      ? 'Community Football League'
      : 'Community Volleyball League';

  Stream<SportsLeagueConfig> configStream(String sportType) {
    return _db.collection('sports_config').doc(sportType).snapshots().map((snap) {
      final data = snap.data();
      return SportsLeagueConfig(
        sportType: sportType,
        leagueName: data?['leagueName'] as String? ?? _defaultLeagueName(sportType),
        hasGoals: data?['hasGoals'] as bool? ?? (sportType == 'football'),
      );
    });
  }

  Future<void> setLeagueName(String sportType, String name) async {
    await _db.collection('sports_config').doc(sportType).set({
      'leagueName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setHasGoals(String sportType, bool hasGoals) async {
    await _db.collection('sports_config').doc(sportType).set({
      'hasGoals': hasGoals,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------
  // Teams
  // ---------------------------------------------------------------------

  Stream<List<SportsTeam>> teamsStream(String sportType) {
    return _db
        .collection('sports_teams')
        .where('sportType', isEqualTo: sportType)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SportsTeam.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
  }

  /// Reserves a doc id without writing anything yet, so a brand-new team's
  /// logo can be uploaded to a path matching its eventual Firestore id
  /// before the document itself is created (same pattern as hero banners).
  String newTeamId() => _db.collection('sports_teams').doc().id;

  Future<void> createTeamWithId({
    required String id,
    required String sportType,
    required String name,
    String? logoUrl,
  }) async {
    await _db.collection('sports_teams').doc(id).set({
      'sportType': sportType,
      'name': name,
      'logoUrl': logoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTeam(String id, {String? name, String? logoUrl}) async {
    await _db.collection('sports_teams').doc(id).update({
      if (name != null) 'name': name,
      if (logoUrl != null) 'logoUrl': logoUrl,
    });
  }

  /// Deletes the team plus its players and fixtures, so nothing is left
  /// pointing at a team that no longer exists.
  Future<void> deleteTeam(String id) async {
    final batch = _db.batch();
    batch.delete(_db.collection('sports_teams').doc(id));

    final players = await _db.collection('sports_players').where('teamId', isEqualTo: id).get();
    for (final p in players.docs) {
      batch.delete(p.reference);
    }

    final homeFixtures =
        await _db.collection('sports_fixtures').where('homeTeamId', isEqualTo: id).get();
    final awayFixtures =
        await _db.collection('sports_fixtures').where('awayTeamId', isEqualTo: id).get();
    for (final f in [...homeFixtures.docs, ...awayFixtures.docs]) {
      batch.delete(f.reference);
    }

    await batch.commit();
  }

  // ---------------------------------------------------------------------
  // Players
  // ---------------------------------------------------------------------

  Stream<List<SportsPlayer>> playersStream(String sportType, {String? teamId}) {
    Query<Map<String, dynamic>> q =
        _db.collection('sports_players').where('sportType', isEqualTo: sportType);
    if (teamId != null) q = q.where('teamId', isEqualTo: teamId);
    return q.snapshots().map((snap) => snap.docs.map((d) => SportsPlayer.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.name.compareTo(b.name)));
  }

  String newPlayerId() => _db.collection('sports_players').doc().id;

  Future<void> createPlayerWithId({
    required String id,
    required String sportType,
    required String teamId,
    required String name,
    String? photoUrl,
    int? jerseyNumber,
    String? position,
  }) async {
    await _db.collection('sports_players').doc(id).set({
      'sportType': sportType,
      'teamId': teamId,
      'name': name,
      'photoUrl': photoUrl,
      'jerseyNumber': jerseyNumber,
      'position': position,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePlayer(String id, Map<String, dynamic> updates) async {
    await _db.collection('sports_players').doc(id).update(updates);
  }

  Future<void> deletePlayer(String id) async {
    await _db.collection('sports_players').doc(id).delete();
  }

  // ---------------------------------------------------------------------
  // Fixtures
  // ---------------------------------------------------------------------

  Stream<List<SportsFixture>> fixturesStream(String sportType) {
    return _db
        .collection('sports_fixtures')
        .where('sportType', isEqualTo: sportType)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => SportsFixture.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.matchDate.compareTo(b.matchDate));
      return list;
    });
  }

  Future<String> addFixture(SportsFixture fixture) async {
    final ref = _db.collection('sports_fixtures').doc();
    await ref.set({
      ...fixture.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateFixture(String id, Map<String, dynamic> updates) async {
    await _db.collection('sports_fixtures').doc(id).update(updates);
  }

  Future<void> deleteFixture(String id) async {
    await _db.collection('sports_fixtures').doc(id).delete();
  }

  // ---------------------------------------------------------------------
  // Computation -- standings & top scorers, derived live from fixtures.
  // Nothing here is persisted; call this fresh every time you have an
  // up-to-date fixtures list.
  // ---------------------------------------------------------------------

  List<TeamStanding> computeStandings({
    required List<SportsTeam> teams,
    required List<SportsFixture> fixtures,
    required bool includeGoals,
  }) {
    final byTeam = <String, _StandingAccumulator>{
      for (final t in teams) t.id: _StandingAccumulator(t.name),
    };

    for (final f in fixtures) {
      if (!f.isCompleted || f.homeScore == null || f.awayScore == null) continue;
      final home = byTeam[f.homeTeamId];
      final away = byTeam[f.awayTeamId];
      if (home == null || away == null) continue; // team since deleted

      home.played++;
      away.played++;
      home.goalsFor += f.homeScore!;
      home.goalsAgainst += f.awayScore!;
      away.goalsFor += f.awayScore!;
      away.goalsAgainst += f.homeScore!;

      if (f.homeScore! > f.awayScore!) {
        home.won++;
        away.lost++;
        home.points += 3;
      } else if (f.homeScore! < f.awayScore!) {
        away.won++;
        home.lost++;
        away.points += 3;
      } else {
        home.drawn++;
        away.drawn++;
        home.points++;
        away.points++;
      }
    }

    final result = byTeam.values
        .map((a) => TeamStanding(
              teamName: a.teamName,
              played: a.played,
              won: a.won,
              drawn: a.drawn,
              lost: a.lost,
              points: a.points,
              goalsFor: includeGoals ? a.goalsFor : null,
              goalsAgainst: includeGoals ? a.goalsAgainst : null,
            ))
        .toList();

    result.sort((a, b) {
      if (b.points != a.points) return b.points - a.points;
      final gdA = a.goalDifference ?? 0;
      final gdB = b.goalDifference ?? 0;
      if (gdB != gdA) return gdB - gdA;
      final gfA = a.goalsFor ?? 0;
      final gfB = b.goalsFor ?? 0;
      if (gfB != gfA) return gfB - gfA;
      return a.teamName.compareTo(b.teamName);
    });
    return result;
  }

  List<TopScorer> computeTopScorers(List<SportsFixture> fixtures, {int limit = 10}) {
    final totals = <String, _ScorerAccumulator>{};
    for (final f in fixtures) {
      if (!f.isCompleted) continue;
      for (final s in f.scorers) {
        final acc =
            totals.putIfAbsent(s.playerId, () => _ScorerAccumulator(s.playerName, s.teamName));
        acc.goals += s.goals;
      }
    }
    final list = totals.values
        .map((a) => TopScorer(playerName: a.playerName, teamName: a.teamName, goals: a.goals))
        .toList()
      ..sort((a, b) => b.goals.compareTo(a.goals));
    return list.take(limit).toList();
  }
}

class _StandingAccumulator {
  final String teamName;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int points = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  _StandingAccumulator(this.teamName);
}

class _ScorerAccumulator {
  final String playerName;
  final String teamName;
  int goals = 0;
  _ScorerAccumulator(this.playerName, this.teamName);
}

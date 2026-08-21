import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sports_models.dart';

/// Formats a match DateTime like:
/// Sat, 5 Jul · 4:00 PM
String formatMatchDate(DateTime d) {
  const weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final weekday = weekdays[d.weekday - 1];
  final month = months[d.month - 1];
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour >= 12 ? 'PM' : 'AM';

  return '$weekday, ${d.day} $month · $hour12:$minute $ampm';
}

/// Firestore-backed sports management.
///
/// Collections:
///   sports_config
///   sports_teams
///   sports_players
///   sports_fixtures
///   sports_sponsors
///
/// Standings and top scorers are computed from fixtures.
class SportsService {
  SportsService._();

  static final SportsService instance = SportsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ========================================================================
  // LEAGUE CONFIG
  // ========================================================================

  String _defaultLeagueName(String sportType) {
    return sportType == 'football'
        ? 'Community Football League'
        : 'Community Volleyball League';
  }

  Stream<SportsLeagueConfig> configStream(String sportType) {
    return _db
        .collection('sports_config')
        .doc(sportType)
        .snapshots()
        .map((snap) {
      final data = snap.data();

      return SportsLeagueConfig(
        sportType: sportType,
        leagueName:
        data?['leagueName'] as String? ??
            _defaultLeagueName(sportType),
        hasGoals:
        data?['hasGoals'] as bool? ??
            (sportType == 'football'),
      );
    });
  }

  Future<void> setLeagueName(
      String sportType,
      String name,
      ) async {
    await _db.collection('sports_config').doc(sportType).set(
      {
        'leagueName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setHasGoals(
      String sportType,
      bool hasGoals,
      ) async {
    await _db.collection('sports_config').doc(sportType).set(
      {
        'hasGoals': hasGoals,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ========================================================================
  // TEAMS
  // ========================================================================

  Stream<List<SportsTeam>> teamsStream(String sportType) {
    return _db
        .collection('sports_teams')
        .where(
      'sportType',
      isEqualTo: sportType,
    )
        .snapshots()
        .map((snap) {
      final teams = snap.docs
          .map(
            (doc) => SportsTeam.fromMap(
          doc.id,
          doc.data(),
        ),
      )
          .toList();

      teams.sort(
            (a, b) => a.name.compareTo(b.name),
      );

      return teams;
    });
  }

  String newTeamId() {
    return _db.collection('sports_teams').doc().id;
  }

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

  Future<void> updateTeam(
      String id, {
        String? name,
        String? logoUrl,
      }) async {
    await _db.collection('sports_teams').doc(id).update({
      if (name != null) 'name': name,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTeam(String id) async {
    final batch = _db.batch();

    batch.delete(
      _db.collection('sports_teams').doc(id),
    );

    final players = await _db
        .collection('sports_players')
        .where('teamId', isEqualTo: id)
        .get();

    for (final player in players.docs) {
      batch.delete(player.reference);
    }

    final homeFixtures = await _db
        .collection('sports_fixtures')
        .where('homeTeamId', isEqualTo: id)
        .get();

    final awayFixtures = await _db
        .collection('sports_fixtures')
        .where('awayTeamId', isEqualTo: id)
        .get();

    for (final fixture in [
      ...homeFixtures.docs,
      ...awayFixtures.docs,
    ]) {
      batch.delete(fixture.reference);
    }

    await batch.commit();
  }

  // ========================================================================
  // PLAYERS
  // ========================================================================

  Stream<List<SportsPlayer>> playersStream(
      String sportType, {
        String? teamId,
      }) {
    Query<Map<String, dynamic>> query = _db
        .collection('sports_players')
        .where(
      'sportType',
      isEqualTo: sportType,
    );

    if (teamId != null) {
      query = query.where(
        'teamId',
        isEqualTo: teamId,
      );
    }

    return query.snapshots().map((snap) {
      final players = snap.docs
          .map(
            (doc) => SportsPlayer.fromMap(
          doc.id,
          doc.data(),
        ),
      )
          .toList();

      players.sort(
            (a, b) => a.name.compareTo(b.name),
      );

      return players;
    });
  }

  String newPlayerId() {
    return _db.collection('sports_players').doc().id;
  }

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

  Future<void> updatePlayer(
      String id,
      Map<String, dynamic> updates,
      ) async {
    await _db.collection('sports_players').doc(id).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePlayer(String id) async {
    await _db
        .collection('sports_players')
        .doc(id)
        .delete();
  }

  // ========================================================================
  // LEAGUE SPONSORS
  // ========================================================================

  /// Public sponsor stream.
  ///
  /// Only active sponsors are returned.
  Stream<List<LeagueSponsor>> sponsorsStream(
      String sportType,
      ) {
    return _db
        .collection('sports_sponsors')
        .where(
      'sportType',
      isEqualTo: sportType,
    )
        .snapshots()
        .map((snap) {
      final sponsors = snap.docs
          .map(
            (doc) => LeagueSponsor.fromMap(
          doc.id,
          doc.data(),
        ),
      )
          .where((sponsor) => sponsor.active)
          .toList();

      sponsors.sort(
            (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

      return sponsors;
    });
  }

  /// Admin stream.
  ///
  /// Returns active AND inactive sponsors.
  Stream<List<LeagueSponsor>> allSponsorsStream(
      String sportType,
      ) {
    return _db
        .collection('sports_sponsors')
        .where(
      'sportType',
      isEqualTo: sportType,
    )
        .snapshots()
        .map((snap) {
      final sponsors = snap.docs
          .map(
            (doc) => LeagueSponsor.fromMap(
          doc.id,
          doc.data(),
        ),
      )
          .toList();

      sponsors.sort(
            (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

      return sponsors;
    });
  }

  /// Creates a new sponsor document ID without writing anything.
  String newSponsorId() {
    return _db.collection('sports_sponsors').doc().id;
  }

  /// Creates a NEW sponsor.
  ///
  /// New sponsors are active by default.
  ///
  /// The logo is deliberately not uploaded here. The caller:
  ///
  /// 1. Creates this Firestore document.
  /// 2. Uploads the logo.
  /// 3. Calls updateSponsor() with the returned URL.
  ///
  /// This prevents an image upload from happening before Firestore
  /// has confirmed that the admin has permission to create the sponsor.
  Future<void> createSponsorWithId({
    required String id,
    required String sportType,
    required String name,
    required String logoUrl,
    required int sortOrder,
  }) async {
    await _db
        .collection('sports_sponsors')
        .doc(id)
        .set({
      'sportType': sportType,
      'name': name,
      'logoUrl': logoUrl,
      'sortOrder': sortOrder,

      // New sponsors are active automatically.
      'active': true,

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates an existing sponsor.
  ///
  /// Every parameter except [id] is optional.
  Future<void> updateSponsor(
      String id, {
        String? name,
        String? logoUrl,
        int? sortOrder,
        bool? active,
      }) async {
    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) {
      updates['name'] = name;
    }

    if (logoUrl != null) {
      updates['logoUrl'] = logoUrl;
    }

    if (sortOrder != null) {
      updates['sortOrder'] = sortOrder;
    }

    if (active != null) {
      updates['active'] = active;
    }

    await _db
        .collection('sports_sponsors')
        .doc(id)
        .update(updates);
  }

  Future<void> deleteSponsor(String id) async {
    await _db
        .collection('sports_sponsors')
        .doc(id)
        .delete();
  }

  // ========================================================================
  // FIXTURES
  // ========================================================================

  Stream<List<SportsFixture>> fixturesStream(
      String sportType,
      ) {
    return _db
        .collection('sports_fixtures')
        .where(
      'sportType',
      isEqualTo: sportType,
    )
        .snapshots()
        .map((snap) {
      final fixtures = snap.docs
          .map(
            (doc) => SportsFixture.fromMap(
          doc.id,
          doc.data(),
        ),
      )
          .toList();

      fixtures.sort(
            (a, b) => a.matchDate.compareTo(b.matchDate),
      );

      return fixtures;
    });
  }

  String newFixtureId() {
    return _db.collection('sports_fixtures').doc().id;
  }

  Future<void> createFixtureWithId({
    required String id,
    required String sportType,
    required String homeTeamId,
    required String awayTeamId,
    required DateTime matchDate,
    String? venue,
    int? homeScore,
    int? awayScore,
    bool completed = false,
  }) async {
    await _db
        .collection('sports_fixtures')
        .doc(id)
        .set({
      'sportType': sportType,
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'matchDate': Timestamp.fromDate(matchDate),
      'venue': venue,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'completed': completed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateFixture(
      String id,
      Map<String, dynamic> updates,
      ) async {
    await _db
        .collection('sports_fixtures')
        .doc(id)
        .update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteFixture(String id) async {
    await _db
        .collection('sports_fixtures')
        .doc(id)
        .delete();
  }

  // ========================================================================
  // TOP SCORERS
  // ========================================================================

  Future<List<Map<String, dynamic>>> computeTopScorers(
      String sportType,
      ) async {
    final playersSnap = await _db
        .collection('sports_players')
        .where(
      'sportType',
      isEqualTo: sportType,
    )
        .get();

    final fixturesSnap = await _db
        .collection('sports_fixtures')
        .where(
      'sportType',
      isEqualTo: sportType,
    )
        .where(
      'completed',
      isEqualTo: true,
    )
        .get();

    final Map<String, int> goalsByPlayer = {};

    // If the fixture documents contain player goal maps,
    // use those values.
    for (final fixture in fixturesSnap.docs) {
      final data = fixture.data();

      final dynamic playerGoals = data['playerGoals'];

      if (playerGoals is Map) {
        for (final entry in playerGoals.entries) {
          final playerId = entry.key.toString();

          final goals = entry.value is num
              ? (entry.value as num).toInt()
              : int.tryParse(
            entry.value.toString(),
          ) ??
              0;

          goalsByPlayer[playerId] =
              (goalsByPlayer[playerId] ?? 0) + goals;
        }
      }
    }

    final List<Map<String, dynamic>> result = [];

    for (final playerDoc in playersSnap.docs) {
      final player = SportsPlayer.fromMap(
        playerDoc.id,
        playerDoc.data(),
      );

      result.add({
        'player': player,
        'goals': goalsByPlayer[player.id] ?? 0,
      });
    }

    result.sort((a, b) {
      final aGoals = (a['goals'] as int?) ?? 0;
      final bGoals = (b['goals'] as int?) ?? 0;

      final goalCompare = bGoals.compareTo(aGoals);

      if (goalCompare != 0) {
        return goalCompare;
      }

      final aPlayer = a['player'] as SportsPlayer;
      final bPlayer = b['player'] as SportsPlayer;

      return aPlayer.name.compareTo(bPlayer.name);
    });

    return result;
  }
}
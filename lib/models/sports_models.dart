import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-sport league settings, editable by the admin from ManageSportsScreen.
class SportsLeagueConfig {
  final String sportType;
  final String leagueName;

  /// Whether this sport tracks goals/points-scored stats -- i.e. whether
  /// the standings table shows GF/GA/GD columns and there's a Top Scorers
  /// list. Football: true. Volleyball: false, since "goals" don't map onto
  /// sets the same way -- keeps the original simpler standings table.
  final bool hasGoals;

  const SportsLeagueConfig({
    required this.sportType,
    required this.leagueName,
    required this.hasGoals,
  });
}

class SportsTeam {
  final String id;
  final String sportType;
  final String name;
  final String? logoUrl;

  const SportsTeam({
    required this.id,
    required this.sportType,
    required this.name,
    this.logoUrl,
  });

  factory SportsTeam.fromMap(String id, Map<String, dynamic> map) {
    return SportsTeam(
      id: id,
      sportType: map['sportType'] as String? ?? 'football',
      name: map['name'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
    );
  }
}

class SportsPlayer {
  final String id;
  final String sportType;
  final String teamId;
  final String name;
  final String? photoUrl;
  final int? jerseyNumber;
  final String? position;

  const SportsPlayer({
    required this.id,
    required this.sportType,
    required this.teamId,
    required this.name,
    this.photoUrl,
    this.jerseyNumber,
    this.position,
  });

  factory SportsPlayer.fromMap(String id, Map<String, dynamic> map) {
    return SportsPlayer(
      id: id,
      sportType: map['sportType'] as String? ?? 'football',
      teamId: map['teamId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      jerseyNumber: (map['jerseyNumber'] as num?)?.toInt(),
      position: map['position'] as String?,
    );
  }
}

/// One player's goal contribution within a single completed fixture.
/// Denormalizes playerName/teamName at write time (rather than joining
/// against sports_players/sports_teams every time top scorers are
/// computed) so the top-scorers list still shows correct historical names
/// even if a player is later renamed or removed from their team.
class FixtureScorer {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final int goals;

  const FixtureScorer({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.goals,
  });

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        'playerName': playerName,
        'teamId': teamId,
        'teamName': teamName,
        'goals': goals,
      };

  factory FixtureScorer.fromMap(Map<String, dynamic> map) => FixtureScorer(
        playerId: map['playerId'] as String? ?? '',
        playerName: map['playerName'] as String? ?? '',
        teamId: map['teamId'] as String? ?? '',
        teamName: map['teamName'] as String? ?? '',
        goals: (map['goals'] as num?)?.toInt() ?? 0,
      );
}

class SportsFixture {
  final String id;
  final String sportType;
  final String homeTeamId;
  final String homeTeamName;
  final String awayTeamId;
  final String awayTeamName;
  final DateTime matchDate;
  final String venue;
  final String status; // 'scheduled' | 'completed'
  final int? homeScore;
  final int? awayScore;
  final List<FixtureScorer> scorers;

  const SportsFixture({
    required this.id,
    required this.sportType,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.matchDate,
    required this.venue,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.scorers = const [],
  });

  bool get isCompleted => status == 'completed';

  factory SportsFixture.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['matchDate'];
    final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
    final rawScorers = (map['scorers'] as List?) ?? const [];
    return SportsFixture(
      id: id,
      sportType: map['sportType'] as String? ?? 'football',
      homeTeamId: map['homeTeamId'] as String? ?? '',
      homeTeamName: map['homeTeamName'] as String? ?? '',
      awayTeamId: map['awayTeamId'] as String? ?? '',
      awayTeamName: map['awayTeamName'] as String? ?? '',
      matchDate: date,
      venue: map['venue'] as String? ?? '',
      status: map['status'] as String? ?? 'scheduled',
      homeScore: (map['homeScore'] as num?)?.toInt(),
      awayScore: (map['awayScore'] as num?)?.toInt(),
      scorers: rawScorers
          .map((s) => FixtureScorer.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }

  /// Does NOT include createdAt -- SportsService adds that separately on
  /// create only, so re-saving an edited fixture never clobbers its
  /// original creation timestamp.
  Map<String, dynamic> toMap() => {
        'sportType': sportType,
        'homeTeamId': homeTeamId,
        'homeTeamName': homeTeamName,
        'awayTeamId': awayTeamId,
        'awayTeamName': awayTeamName,
        'matchDate': Timestamp.fromDate(matchDate),
        'venue': venue,
        'status': status,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'scorers': scorers.map((s) => s.toMap()).toList(),
      };
}

// ---------------------------------------------------------------------
// Pure display value-objects consumed by SportsScreen's widgets. Computed
// live from SportsFixture/SportsTeam by SportsService -- never stored in
// Firestore directly, so there's nothing to keep in sync: change a score,
// and standings/top-scorers recompute automatically on next read.
// ---------------------------------------------------------------------

class TeamStanding {
  final String teamName;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int points;
  final int? goalsFor;
  final int? goalsAgainst;

  const TeamStanding({
    required this.teamName,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.points,
    this.goalsFor,
    this.goalsAgainst,
  });

  int? get goalDifference =>
      (goalsFor != null && goalsAgainst != null) ? goalsFor! - goalsAgainst! : null;
}

class TopScorer {
  final String playerName;
  final String teamName;
  final int goals;

  const TopScorer({
    required this.playerName,
    required this.teamName,
    required this.goals,
  });
}

class Fixture {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String dateText;
  final String venue;

  const Fixture({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.dateText,
    required this.venue,
  });
}

class MatchResult {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final String dateText;

  const MatchResult({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.dateText,
  });
}

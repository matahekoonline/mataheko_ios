import '../models/sports_models.dart';

// PLACEHOLDER DATA — replace team names, scores, and fixtures with real
// Mataheko-Afienya community league results as they happen.

final List<TeamStanding> footballStandings = [
  const TeamStanding(teamName: 'Mataheko FC', played: 8, won: 6, drawn: 1, lost: 1, points: 19, goalsFor: 18, goalsAgainst: 7),
  const TeamStanding(teamName: 'Afienya United', played: 8, won: 5, drawn: 2, lost: 1, points: 17, goalsFor: 15, goalsAgainst: 9),
  const TeamStanding(teamName: 'Zongo Stars', played: 8, won: 4, drawn: 2, lost: 2, points: 14, goalsFor: 13, goalsAgainst: 10),
  const TeamStanding(teamName: 'Junction Boys', played: 8, won: 2, drawn: 3, lost: 3, points: 9, goalsFor: 9, goalsAgainst: 12),
  const TeamStanding(teamName: 'Market Rangers', played: 8, won: 1, drawn: 1, lost: 6, points: 4, goalsFor: 6, goalsAgainst: 17),
];

final List<TopScorer> footballTopScorers = [
  const TopScorer(playerName: 'Kwame Asante', teamName: 'Mataheko FC', goals: 9),
  const TopScorer(playerName: 'Yaw Boateng', teamName: 'Afienya United', goals: 7),
  const TopScorer(playerName: 'Kofi Mensah', teamName: 'Zongo Stars', goals: 6),
  const TopScorer(playerName: 'Kwabena Owusu', teamName: 'Mataheko FC', goals: 5),
  const TopScorer(playerName: 'Emmanuel Tetteh', teamName: 'Junction Boys', goals: 4),
];

final List<Fixture> footballFixtures = [
  const Fixture(
    id: 'ff1',
    homeTeam: 'Mataheko FC',
    awayTeam: 'Junction Boys',
    dateText: 'Sat, 5 Jul · 4:00 PM',
    venue: 'Mataheko Community Park',
  ),
  const Fixture(
    id: 'ff2',
    homeTeam: 'Afienya United',
    awayTeam: 'Market Rangers',
    dateText: 'Sun, 6 Jul · 3:30 PM',
    venue: 'Afienya Park',
  ),
];

final List<MatchResult> footballResults = [
  const MatchResult(
    id: 'fr1',
    homeTeam: 'Zongo Stars',
    awayTeam: 'Market Rangers',
    homeScore: 3,
    awayScore: 1,
    dateText: 'Sun, 29 Jun',
  ),
  const MatchResult(
    id: 'fr2',
    homeTeam: 'Mataheko FC',
    awayTeam: 'Afienya United',
    homeScore: 2,
    awayScore: 2,
    dateText: 'Sat, 28 Jun',
  ),
];

// --- Volleyball ---

final List<TeamStanding> volleyballStandings = [
  const TeamStanding(teamName: 'Mataheko Spikers', played: 6, won: 5, drawn: 0, lost: 1, points: 15),
  const TeamStanding(teamName: 'Afienya Smashers', played: 6, won: 4, drawn: 0, lost: 2, points: 12),
  const TeamStanding(teamName: 'Community Aces', played: 6, won: 2, drawn: 0, lost: 4, points: 6),
  const TeamStanding(teamName: 'Junction Blockers', played: 6, won: 1, drawn: 0, lost: 5, points: 3),
];

final List<Fixture> volleyballFixtures = [
  const Fixture(
    id: 'vf1',
    homeTeam: 'Mataheko Spikers',
    awayTeam: 'Community Aces',
    dateText: 'Fri, 4 Jul · 5:00 PM',
    venue: 'Mataheko Sports Court',
  ),
];

final List<MatchResult> volleyballResults = [
  const MatchResult(
    id: 'vr1',
    homeTeam: 'Afienya Smashers',
    awayTeam: 'Junction Blockers',
    homeScore: 3,
    awayScore: 1,
    dateText: 'Wed, 1 Jul',
  ),
];

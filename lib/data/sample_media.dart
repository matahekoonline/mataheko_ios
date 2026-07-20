import '../models/media_item.dart';

// PLACEHOLDER DATA — using public Creative Commons demo videos so the
// player works out of the box. Replace sourceId/creatorName/title with
// real local creators once they start submitting content.
//
// For YouTube: sourceId = the video ID (the part after "v=" in the URL)
// For Spotify: sourceId = the full track/artist/album share link
final List<MediaItem> sampleMedia = [
  const MediaItem(
    id: 'v1',
    title: 'Sample Community Highlight Reel',
    creatorName: 'Demo Creator',
    type: MediaType.video,
    source: MediaSource.youtube,
    sourceId: 'aqz-KE-bpKQ', // Big Buck Bunny (Creative Commons) — replace
    thumbnailNote: 'Local event / highlight video placeholder',
  ),
  const MediaItem(
    id: 'v2',
    title: 'Sample Church Service Clip',
    creatorName: 'Demo Church',
    type: MediaType.video,
    source: MediaSource.youtube,
    sourceId: 'M7lc1UVf-VE', // Google demo video — replace
    thumbnailNote: 'Sunday service recording placeholder',
  ),
  const MediaItem(
    id: 'm1',
    title: 'Sample Track One',
    creatorName: 'Demo Artist',
    type: MediaType.music,
    source: MediaSource.spotify,
    sourceId: 'https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b',
    thumbnailNote: 'Original single — replace with real artist link',
  ),
  const MediaItem(
    id: 'm2',
    title: 'Sample Gospel Recording',
    creatorName: 'Demo Choir',
    type: MediaType.music,
    source: MediaSource.spotify,
    sourceId: 'https://open.spotify.com/track/7GhIk7Il098yCjg4BQjzvb',
    thumbnailNote: 'Choir recording placeholder',
  ),
];

class TorrentEntry {
  final String title;
  final String url;
  final String? color;
  final String? size;
  final int? seeders;
  final int? leechers;
  final String source; // 'tamilmv', 'csv', 'rarbg'
  final String? infoHash; // For direct magnet construction
  final String? posterUrl;

  TorrentEntry({
    required this.title,
    required this.url,
    this.color,
    this.size,
    this.seeders,
    this.leechers,
    this.source = 'tamilmv',
    this.infoHash,
    this.posterUrl,
  });
}

class TorrentDownload {
  final String name;
  final String size;
  final String magnetLink;
  final String? torrentFileUrl;
  final String? posterUrl;
  final int? seeders;
  final int? leechers;

  TorrentDownload({
    required this.name,
    required this.size,
    required this.magnetLink,
    this.torrentFileUrl,
    this.posterUrl,
    this.seeders,
    this.leechers,
  });
}

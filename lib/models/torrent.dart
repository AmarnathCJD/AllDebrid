class TorrentEntry {
  final String title;
  final String url;
  final String? color;

  TorrentEntry({
    required this.title,
    required this.url,
    this.color,
  });
}

class TorrentDownload {
  final String name;
  final String size;
  final String magnetLink;
  final String? torrentFileUrl;
  final String? posterUrl;

  TorrentDownload({
    required this.name,
    required this.size,
    required this.magnetLink,
    this.torrentFileUrl,
    this.posterUrl,
  });
}

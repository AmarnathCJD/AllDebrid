/// Link Models for AllDebrid
class LinkInfo {
  final String link;
  final String filename;
  final int size;
  final String host;
  final String hostDomain;
  final String? error;

  LinkInfo({
    required this.link,
    required this.filename,
    required this.size,
    required this.host,
    required this.hostDomain,
    this.error,
  });

  factory LinkInfo.fromJson(Map<String, dynamic> json) {
    return LinkInfo(
      link: json['link'] ?? '',
      filename: json['filename'] ?? '',
      size: json['size'] ?? 0,
      host: json['host'] ?? '',
      hostDomain: json['hostDomain'] ?? '',
      error: json['error']?['message'],
    );
  }

  bool get hasError => error != null;
}

class UnlockedLink {
  final String link;
  final String host;
  final String filename;
  final bool paws;
  final int filesize;
  final List<StreamOption> streams;
  final String id;
  final String hostDomain;
  final int delayed;

  UnlockedLink({
    required this.link,
    required this.host,
    required this.filename,
    required this.paws,
    required this.filesize,
    required this.streams,
    required this.id,
    required this.hostDomain,
    required this.delayed,
  });

  factory UnlockedLink.fromJson(Map<String, dynamic> json) {
    return UnlockedLink(
      link: json['link'] ?? '',
      host: json['host'] ?? '',
      filename: json['filename'] ?? '',
      paws: json['paws'] ?? false,
      filesize: json['filesize'] ?? 0,
      streams: (json['streams'] as List<dynamic>?)
              ?.map((e) => StreamOption.fromJson(e))
              .toList() ??
          [],
      id: json['id'] ?? '',
      hostDomain: json['hostDomain'] ?? '',
      delayed: json['delayed'] ?? 0,
    );
  }

  bool get isDelayed => delayed > 0;
  bool get hasStreams => streams.isNotEmpty;
}

class StreamOption {
  final String id;
  final String ext;
  final dynamic quality;
  final int filesize;
  final String proto;
  final String name;
  final double tb;
  final int abr;

  StreamOption({
    required this.id,
    required this.ext,
    required this.quality,
    required this.filesize,
    required this.proto,
    required this.name,
    required this.tb,
    required this.abr,
  });

  factory StreamOption.fromJson(Map<String, dynamic> json) {
    return StreamOption(
      id: json['id'] ?? '',
      ext: json['ext'] ?? '',
      quality: json['quality'],
      filesize: json['filesize'] ?? 0,
      proto: json['proto'] ?? '',
      name: json['name'] ?? '',
      tb: (json['tb'] ?? 0).toDouble(),
      abr: json['abr'] ?? 0,
    );
  }

  String get qualityString {
    if (quality is int) return '${quality}p';
    if (quality is String) return quality;
    return 'Unknown';
  }
}

class StreamingLink {
  final String link;
  final String filename;
  final int filesize;
  final int delayed;

  StreamingLink({
    required this.link,
    required this.filename,
    required this.filesize,
    required this.delayed,
  });

  factory StreamingLink.fromJson(Map<String, dynamic> json) {
    return StreamingLink(
      link: json['link'] ?? '',
      filename: json['filename'] ?? '',
      filesize: json['filesize'] ?? 0,
      delayed: json['delayed'] ?? 0,
    );
  }
}

class DelayedLink {
  final int status;
  final int timeLeft;
  final String? link;

  DelayedLink({
    required this.status,
    required this.timeLeft,
    this.link,
  });

  factory DelayedLink.fromJson(Map<String, dynamic> json) {
    return DelayedLink(
      status: json['status'] ?? 0,
      timeLeft: json['time_left'] ?? 0,
      link: json['link'],
    );
  }

  bool get isReady => status == 2 && link != null;
}

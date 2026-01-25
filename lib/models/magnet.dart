/// Magnet Models for AllDebrid
library;

enum MagnetStatusCode {
  queued(0, 'Queued', '⏳'),
  downloading(1, 'Downloading', '⬇️'),
  compressing(2, 'Compressing', '📦'),
  uploading(3, 'Uploading', '⬆️'),
  ready(4, 'Ready', '✅'),
  error(5, 'Error', '❌'),
  processing(6, 'Processing', '⚙️');

  final int code;
  final String label;
  final String emoji;

  const MagnetStatusCode(this.code, this.label, this.emoji);

  static MagnetStatusCode fromCode(int code) {
    return MagnetStatusCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => MagnetStatusCode.queued,
    );
  }
}

class MagnetUploadResult {
  final String magnet;
  final String? hash;
  final String? name;
  final int? size;
  final bool? ready;
  final int? id;
  final String? error;

  MagnetUploadResult({
    required this.magnet,
    this.hash,
    this.name,
    this.size,
    this.ready,
    this.id,
    this.error,
  });

  factory MagnetUploadResult.fromJson(Map<String, dynamic> json) {
    return MagnetUploadResult(
      magnet: json['magnet'] ?? '',
      hash: json['hash'],
      name: json['name'],
      size: json['size'],
      ready: json['ready'],
      id: json['id'],
      error: json['error']?['message'],
    );
  }

  bool get hasError => error != null;
}

class MagnetStatus {
  final int id;
  final String filename;
  final int size;
  final String hash;
  final String status;
  final int statusCode;
  final int downloaded;
  final int uploaded;
  final int seeders;
  final int downloadSpeed;
  final int uploadSpeed;
  final int uploadDate;
  final int completionDate;

  MagnetStatus({
    required this.id,
    required this.filename,
    required this.size,
    required this.hash,
    required this.status,
    required this.statusCode,
    required this.downloaded,
    required this.uploaded,
    required this.seeders,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.uploadDate,
    required this.completionDate,
  });

  factory MagnetStatus.fromJson(Map<String, dynamic> json) {
    return MagnetStatus(
      id: json['id'] ?? 0,
      filename: json['filename'] ?? '',
      size: json['size'] ?? 0,
      hash: json['hash'] ?? '',
      status: json['status'] ?? '',
      statusCode: json['statusCode'] ?? 0,
      downloaded: json['downloaded'] ?? 0,
      uploaded: json['uploaded'] ?? 0,
      seeders: json['seeders'] ?? 0,
      downloadSpeed: json['downloadSpeed'] ?? 0,
      uploadSpeed: json['uploadSpeed'] ?? 0,
      uploadDate: json['uploadDate'] ?? 0,
      completionDate: json['completionDate'] ?? 0,
    );
  }

  MagnetStatusCode get magnetStatusCode =>
      MagnetStatusCode.fromCode(statusCode);

  double get progress {
    if (size == 0) return 0;
    return (downloaded / size) * 100;
  }

  bool get isReady => statusCode == MagnetStatusCode.ready.code;
  bool get isDownloading => statusCode == MagnetStatusCode.downloading.code;
  bool get isError => statusCode == MagnetStatusCode.error.code;

  DateTime get uploadDateTime =>
      DateTime.fromMillisecondsSinceEpoch(uploadDate * 1000);
  DateTime? get completionDateTime => completionDate > 0
      ? DateTime.fromMillisecondsSinceEpoch(completionDate * 1000)
      : null;
}

class MagnetFile {
  final String name;
  final int size;
  final String? link;
  final List<MagnetFile> files;

  MagnetFile({
    required this.name,
    required this.size,
    this.link,
    required this.files,
  });

  factory MagnetFile.fromJson(Map<String, dynamic> json) {
    return MagnetFile(
      name: json['n'] ?? '',
      size: json['s'] ?? 0,
      link: json['l'],
      files: (json['e'] as List<dynamic>?)
              ?.map((e) => MagnetFile.fromJson(e))
              .toList() ??
          [],
    );
  }

  bool get isDirectory => files.isNotEmpty;
  bool get hasLink => link != null && link!.isNotEmpty;
}

class FlatFile {
  final String path;
  final String name;
  final int size;
  final String link;

  FlatFile({
    required this.path,
    required this.name,
    required this.size,
    required this.link,
  });
}

/// Flatten magnet files recursively
List<FlatFile> flattenMagnetFiles(List<MagnetFile> files,
    [String basePath = '']) {
  final result = <FlatFile>[];

  for (final f in files) {
    final currentPath = basePath.isEmpty ? f.name : '$basePath/${f.name}';

    if (f.files.isNotEmpty) {
      result.addAll(flattenMagnetFiles(f.files, currentPath));
    } else if (f.link != null && f.link!.isNotEmpty) {
      result.add(FlatFile(
        path: currentPath,
        name: f.name,
        size: f.size,
        link: f.link!,
      ));
    }
  }

  return result;
}

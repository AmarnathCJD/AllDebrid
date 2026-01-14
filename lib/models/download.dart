enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class Download {
  final String id;
  final String url;
  final String filename;
  final String savePath;
  int totalSize; // Made mutable for updating during download
  int downloadedSize;
  DownloadStatus status;
  int speed;
  String? error;
  DateTime createdAt;
  DateTime? completedAt;

  Download({
    required this.id,
    required this.url,
    required this.filename,
    required this.savePath,
    required this.totalSize,
    this.downloadedSize = 0,
    this.status = DownloadStatus.pending,
    this.speed = 0,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  double get progress {
    if (totalSize == 0) return 0;
    return downloadedSize / totalSize;
  }

  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isCompleted => status == DownloadStatus.completed;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isPending => status == DownloadStatus.pending;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'filename': filename,
      'savePath': savePath,
      'totalSize': totalSize,
      'downloadedSize': downloadedSize,
      'status': status.index,
      'speed': speed,
      'error': error,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Download.fromJson(Map<String, dynamic> json) {
    return Download(
      id: json['id'],
      url: json['url'],
      filename: json['filename'],
      savePath: json['savePath'],
      totalSize: json['totalSize'],
      downloadedSize: json['downloadedSize'] ?? 0,
      status: DownloadStatus.values[json['status'] ?? 0],
      speed: json['speed'] ?? 0,
      error: json['error'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}

import 'package:intl/intl.dart';

String formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return '0 B';

  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  final i = (bytes == 0) ? 0 : (bytes.bitLength - 1) ~/ 10;
  final size = bytes / (1 << (i * 10));

  return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
}

// Alias for formatBytes
String formatSize(int bytes, {int decimals = 2}) =>
    formatBytes(bytes, decimals: decimals);

String formatSpeed(int bytesPerSecond) {
  return '${formatBytes(bytesPerSecond)}/s';
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  } else {
    return '${seconds}s';
  }
}

String formatEta(int remainingBytes, int speed) {
  if (speed <= 0) return '∞';

  final seconds = remainingBytes ~/ speed;
  return formatDuration(Duration(seconds: seconds));
}

String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays > 7) {
    return DateFormat('MMM d, yyyy').format(date);
  } else if (difference.inDays > 1) {
    return '${difference.inDays} days ago';
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else if (difference.inHours > 1) {
    return '${difference.inHours} hours ago';
  } else if (difference.inHours == 1) {
    return '1 hour ago';
  } else if (difference.inMinutes > 1) {
    return '${difference.inMinutes} minutes ago';
  } else {
    return 'Just now';
  }
}

String formatTimestamp(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  return DateFormat('MMM d, yyyy h:mm a').format(date);
}

String getFileExtension(String filename) {
  final parts = filename.split('.');
  return parts.length > 1 ? parts.last.toLowerCase() : '';
}

String getFileIcon(String filename) {
  final ext = getFileExtension(filename);

  if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v'].contains(ext)) {
    return '🎬';
  }

  if (['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a', 'wma'].contains(ext)) {
    return '🎵';
  }

  if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(ext)) {
    return '🖼️';
  }

  if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].contains(ext)) {
    return '📦';
  }
  if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt']
      .contains(ext)) {
    return '📄';
  }

  if (['srt', 'sub', 'ass', 'ssa', 'vtt'].contains(ext)) {
    return '📝';
  }

  return '📁';
}

bool isVideoFile(String filename) {
  final ext = getFileExtension(filename);
  return ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v']
      .contains(ext);
}

bool isAudioFile(String filename) {
  final ext = getFileExtension(filename);
  return ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a', 'wma'].contains(ext);
}

String truncateString(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}

bool isValidApiKey(String key) {
  return key.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(key);
}

String? extractInfoHash(String magnet) {
  final match = RegExp(r'btih:([a-zA-Z0-9]+)').firstMatch(magnet);
  return match?.group(1)?.toLowerCase();
}

bool isMagnetUri(String s) {
  return s.toLowerCase().startsWith('magnet:?');
}

bool isInfoHash(String s) {
  if (s.length != 40 && s.length != 32) return false;
  return RegExp(r'^[a-fA-F0-9]+$').hasMatch(s);
}

String toMagnetUri(String hash) {
  return 'magnet:?xt=urn:btih:$hash';
}

String cleanFilename(String filename) {
  String name = filename.replaceAll('.', ' ').replaceAll('_', ' ');

  name = name.replaceAll(RegExp(r'www\.1TamilMV\..*'), '');
  // and all such urls
  name = name.replaceAll(RegExp(r'www\..*'), '');
  final patterns = [
    RegExp(r'\b(19|20)\d{2}\b.*'), // Year and everything after
    RegExp(r'\bS\d{1,2}(E\d{1,2})?.*',
        caseSensitive: false), // Season/Episode info
    RegExp(
        r'\b(1080p|720p|480p|2160p|4k|HD|SD|WEB-DL|BluRay|BRRip|DVDRip|H264|x264|x265|HEVC|AAC|AC3)\b.*',
        caseSensitive: false), // Quality/Codecs
    RegExp(r'\[.*?\]'), // Brackets content
    RegExp(r'\(.*?\)'), // Parentheses content
  ];

  for (var pattern in patterns) {
    name = name.replaceAll(pattern, '');
  }

  name = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();

  return name.replaceAll(RegExp(r'\s+'), ' ');
}

int getProgressColor(double progress) {
  if (progress >= 100) {
    return 0xFF10B981;
  } else if (progress >= 75) {
    return 0xFF22D3EE;
  } else if (progress >= 50) {
    return 0xFF6366F1;
  } else if (progress >= 25) {
    return 0xFFF59E0B;
  } else {
    return 0xFF64748B;
  }
}

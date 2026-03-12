import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

final _subtitleDio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
));

class SubtitleCatResult {
  final String id;
  final String fileName;
  final String downloadLink;
  final String detailsUrl;
  final String? language;
  final String? flagUrl;
  final int? downloadCount;
  final bool isDirect;

  SubtitleCatResult({
    required this.id,
    required this.fileName,
    required this.downloadLink,
    required this.detailsUrl,
    this.language,
    this.flagUrl,
    this.downloadCount,
    this.isDirect = false,
  });
}

class SubtitleCatLanguage {
  final String languageName;
  final String downloadUrl;
  final String format;

  SubtitleCatLanguage({
    required this.languageName,
    required this.downloadUrl,
    required this.format,
  });
}

class SubtitleCatService {
  static const String baseUrl = 'https://www.subtitlecat.com';

  // Priority languages to show first
  static const List<String> priorityLanguages = [
    'English',
    'Hindi',
    'Malayalam',
    'Korean',
    'Japanese',
    'Tamil',
    'Telugu',
    'Kannada',
  ];

  /// Search for subtitles on SubtitleCat
  static Future<List<SubtitleCatResult>> searchSubtitles(
    String query,
  ) async {
    try {
      final url = '$baseUrl/index.php?search=${Uri.encodeComponent(query)}';
      final response = await _subtitleDio.get<String>(url,
          options: Options(responseType: ResponseType.plain));

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Failed to search subtitles');
      }

      final results = <SubtitleCatResult>[];
      final html = response.data!;
      final pattern = RegExp(
        r"""<a[^>]+href=["']\/?(subs\/\d+\/[^"']+)["'][^>]*>([^<]+)<\/a>""",
        caseSensitive: false,
        dotAll: true,
        multiLine: true,
      );

      for (final match in pattern.allMatches(html)) {
        final rawUrl = match.group(1) ?? '';
        final fileName = match.group(2) ?? '';

        if (rawUrl.isNotEmpty && fileName.isNotEmpty) {
          final normalizedUrl = _ensureLeadingSlash(rawUrl);
          final parts = normalizedUrl.split('/');
          final id = parts.length > 2 ? parts[2] : normalizedUrl;
          results.add(
            SubtitleCatResult(
              id: id,
              fileName: fileName,
              downloadLink: '',
              detailsUrl: normalizedUrl,
            ),
          );
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Get available languages and download links for a subtitle
  static Future<List<SubtitleCatLanguage>> getSubtitleLanguages(
    String detailsUrl,
  ) async {
    try {
      final normalizedDetails = _ensureLeadingSlash(detailsUrl);
      final url = '$baseUrl$normalizedDetails';
      final response = await _subtitleDio.get<String>(url,
          options: Options(responseType: ResponseType.plain));

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Failed to fetch subtitle details');
      }
      final languages = <SubtitleCatLanguage>[];
      final html = response.data!;

      final pattern = RegExp(
        r"""<div[^>]*class="sub-single"[^>]*>\s*<span><img[^>]+></span>\s*<span>([^<]+)</span>\s*<span><a[^>]+href=['"](/subs/\d+/[^'"<>]+\.(?:srt|vtt|ass|ssa))['"][^>]*class="green-link">Download</a>""",
        caseSensitive: false,
        multiLine: true,
      );

      for (final match in pattern.allMatches(html)) {
        final languageNameRaw = match.group(1)?.trim() ?? '';
        final languageName = languageNameRaw
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .trim();
        final rawDownloadPath = match.group(2) ?? '';

        if (languageName.isNotEmpty && rawDownloadPath.isNotEmpty) {
          final normalizedDownloadPath = _ensureLeadingSlash(rawDownloadPath);
          languages.add(
            SubtitleCatLanguage(
              languageName: languageName,
              downloadUrl: '$baseUrl$normalizedDownloadPath',
              format: normalizedDownloadPath.split('.').last,
            ),
          );
        }
      }

      // Sort by priority languages
      languages.sort((a, b) {
        final aPriority = priorityLanguages.indexOf(a.languageName);
        final bPriority = priorityLanguages.indexOf(b.languageName);

        if (aPriority == -1 && bPriority == -1) return 0;
        if (aPriority == -1) return 1;
        if (bPriority == -1) return -1;
        return aPriority.compareTo(bPriority);
      });
      return languages;
    } catch (e) {
      return [];
    }
  }

  static Future<String?> downloadSubtitle(
    String downloadUrl,
    String fileName,
  ) async {
    try {
      final response = await _subtitleDio.get<Uint8List>(downloadUrl,
          options: Options(responseType: ResponseType.bytes));

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Failed to download subtitle');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.data!);

      return file.path;
    } catch (e) {
      return null;
    }
  }

  static String _ensureLeadingSlash(String path) {
    if (path.startsWith('/')) return path;
    return '/$path';
  }
}

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
      print('Searching SubtitleCat for: $query');
      final url = '$baseUrl/index.php?search=${Uri.encodeComponent(query)}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to search subtitles');
      }

      final results = <SubtitleCatResult>[];
      final html = response.body;
      print('Search response length: ${html.length}');
      print('Search snippet: ${html.substring(0, html.length.clamp(0, 200))}');

      // Parse search results from HTML
      // Look for links in format: /subs/ID/filename
      final pattern = RegExp(
        r"""<a[^>]+href=["']\/?(subs\/\d+\/[^"']+)["'][^>]*>([^<]+)<\/a>""",
        caseSensitive: false,
        dotAll: true,
        multiLine: true,
      );

      for (final match in pattern.allMatches(html)) {
        final rawUrl = match.group(1) ?? '';
        final fileName = match.group(2) ?? '';
        print('Regex match: url=$rawUrl title=$fileName');

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

      print('Found ${results.length} subtitle results');
      return results;
    } catch (e) {
      print('Error searching subtitles: $e');
      return [];
    }
  }

  /// Get available languages and download links for a subtitle
  static Future<List<SubtitleCatLanguage>> getSubtitleLanguages(
    String detailsUrl,
  ) async {
    try {
      print('Fetching subtitle details from: $detailsUrl');
      final normalizedDetails = _ensureLeadingSlash(detailsUrl);
      final url = '$baseUrl$normalizedDetails';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch subtitle details');
      }
      final languages = <SubtitleCatLanguage>[];
      final html = response.body;

      // Parse language links from details page
      // Look for download links like: /subs/75/filename-ar.srt
      // Match pattern: flag span, language span, download link (skip translate buttons)
      final pattern = RegExp(
        r"""<div[^>]*class="sub-single"[^>]*>\s*<span><img[^>]+></span>\s*<span>([^<]+)</span>\s*<span><a[^>]+href=['"](/subs/\d+/[^'"<>]+\.(?:srt|vtt|ass|ssa))['"][^>]*class="green-link">Download</a>""",
        caseSensitive: false,
        multiLine: true,
      );

      for (final match in pattern.allMatches(html)) {
        final languageNameRaw = match.group(1)?.trim() ?? '';
        // Decode HTML entities like &nbsp; &amp; etc
        final languageName = languageNameRaw
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .trim();
        final rawDownloadPath = match.group(2) ?? '';
        print('Language match: $languageName download=$rawDownloadPath');

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

      print('Found ${languages.length} language variants');
      return languages;
    } catch (e) {
      print('Error fetching subtitle languages: $e');
      return [];
    }
  }

  /// Download subtitle file
  static Future<String?> downloadSubtitle(
    String downloadUrl,
    String fileName,
  ) async {
    try {
      print('Downloading subtitle from: $downloadUrl');
      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download subtitle');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      print('Subtitle saved to: ${file.path}');
      return file.path;
    } catch (e) {
      print('Error downloading subtitle: $e');
      return null;
    }
  }

  static String _ensureLeadingSlash(String path) {
    if (path.startsWith('/')) return path;
    return '/$path';
  }
}

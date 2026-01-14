import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/torrent.dart';

class TorrentScraperService {
  final Dio _dio;
  String _baseUrl = 'https://www.1tamilmv.do';

  TorrentScraperService() : _dio = Dio() {
    _dio.options.followRedirects = true;
    _dio.options.maxRedirects = 5;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  void updateBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String get baseUrl => _baseUrl;

  /// Fetch homepage and extract movie entries
  Future<List<TorrentEntry>> fetchHomepage() async {
    try {
      final response = await _dio.get(_baseUrl);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      return _parseHomepage(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
            'Connection timeout - Provider temporarily unavailable');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Network error - Check your connection');
      } else if (e.response != null) {
        throw Exception(
            'Server error (${e.response!.statusCode}) - Provider temporarily unavailable');
      } else {
        throw Exception('Failed to connect - Provider may be down');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  List<TorrentEntry> _parseHomepage(String html) {
    final document = html_parser.parse(html);
    final entries = <TorrentEntry>[];
    final seen = <String>{};

    // Find the widget with recent posts
    final widgets = document.querySelectorAll('.ipsWidget_inner');

    for (final widget in widgets) {
      // Look for strong tags which contain the movie titles
      final strongTags = widget.querySelectorAll('strong');

      for (final strong in strongTags) {
        // Get all text before the first <a> tag - this is the movie title
        final strongHtml = strong.innerHtml;
        final linkMatch =
            RegExp(r'^(.*?)<a\s+href="([^"]+)"').firstMatch(strongHtml);

        if (linkMatch != null) {
          var title = linkMatch.group(1) ?? '';
          final href = linkMatch.group(2);

          // Clean up the title
          title = title
              .replaceAll('&nbsp;', ' ')
              .replaceAll(RegExp(r'<[^>]*>'), '') // Remove any HTML tags
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

          // Skip if title is empty or too short, or if we've seen this URL
          if (title.isEmpty ||
              title.length < 3 ||
              href == null ||
              !href.contains('/forums/topic/')) {
            continue;
          }

          final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

          // Avoid duplicates
          if (seen.contains(fullUrl)) continue;
          seen.add(fullUrl);

          // Extract color from link if present
          final linkTag = strong.querySelector('a[href*="/forums/topic/"]');
          final colorSpan = linkTag?.querySelector('span[style*="color"]');
          final color =
              colorSpan?.attributes['style']?.contains('color') == true
                  ? _extractColor(colorSpan!.attributes['style']!)
                  : null;

          entries.add(TorrentEntry(
            title: title,
            url: fullUrl,
            color: color,
          ));
        }
      }
    }

    return entries;
  }

  String? _extractColor(String style) {
    final match =
        RegExp(r'color:\s*(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3}|rgb\([^)]+\))')
            .firstMatch(style);
    return match?.group(1);
  }

  /// Fetch torrent page and extract magnet links
  Future<List<TorrentDownload>> fetchTorrentLinks(String url) async {
    try {
      final response = await _dio.get(url);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      return _parseTorrentPage(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
            'Connection timeout - Provider temporarily unavailable');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Network error - Check your connection');
      } else if (e.response != null) {
        throw Exception(
            'Server error (${e.response!.statusCode}) - Provider temporarily unavailable');
      } else {
        throw Exception('Failed to connect - Provider may be down');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  List<TorrentDownload> _parseTorrentPage(String html) {
    final document = html_parser.parse(html);
    final downloads = <TorrentDownload>[];

    // Extract poster URL - look for first image in post content
    String? posterUrl;
    final postContent = document.querySelector(
        '.ipsType_richText, .cPost_contentWrap, [data-role=\"commentContent\"]');
    if (postContent != null) {
      final firstImg = postContent.querySelector('img');
      if (firstImg != null) {
        posterUrl = firstImg.attributes['src'];
        if (posterUrl != null && !posterUrl.startsWith('http')) {
          posterUrl = '$_baseUrl$posterUrl';
        }
      }
    }

    // Find all magnet links
    final magnetLinks = document.querySelectorAll('a[href^="magnet:"]');

    // Try to extract titles from JSON-LD first
    Map<String, String> magnetToTitle = {};
    try {
      final jsonLdScript =
          document.querySelector('script[type="application/ld+json"]');
      if (jsonLdScript != null) {
        final jsonText = jsonLdScript.text;
        // Extract the "text" field which contains individual quality titles
        final textMatch = RegExp(r'"text":\s*"([^"]+)"').firstMatch(jsonText);
        if (textMatch != null) {
          final text = textMatch
              .group(1)!
              .replaceAll(r'\u00a0', ' ')
              .replaceAll(r'\n', '\n')
              .replaceAll(r'\t', '');

          // Split by lines and find titles ending with ":"
          final lines = text.split('\n');
          String? currentTitle;
          int titleIndex = 0;

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();

            // Look for title lines (end with ":")
            if (line.endsWith(':') &&
                !line.contains('TamilMV') &&
                !line.contains('Click Here')) {
              currentTitle = line.substring(0, line.length - 1).trim();
            }
            // Look for torrent filename or MAGNET keyword
            else if (currentTitle != null &&
                (line.contains('.torrent') || line.toUpperCase() == 'MAGNET')) {
              // Map this title to the magnet at titleIndex
              if (titleIndex < magnetLinks.length) {
                final magnetUrl =
                    magnetLinks[titleIndex].attributes['href'] ?? '';
                magnetToTitle[magnetUrl] = currentTitle;
                titleIndex++;
              }
              currentTitle = null;
            }
          }
        }
      }
    } catch (e) {
      // Silently ignore JSON-LD parsing errors
    }

    for (final magnetLink in magnetLinks) {
      final magnetUrl = magnetLink.attributes['href'] ?? '';

      var parent = magnetLink.parent;
      String? name;
      String size = 'Unknown';
      String? torrentFileUrl;

      // First, check if we have a title from JSON-LD
      if (magnetToTitle.containsKey(magnetUrl)) {
        name = magnetToTitle[magnetUrl];

        // Extract size from the title if present
        final sizeMatch =
            RegExp(r'(\d+\.?\d*\s*(?:GB|MB|TB))', caseSensitive: false)
                .firstMatch(name!);
        if (sizeMatch != null) {
          size = sizeMatch.group(1)!;
        }
      }

      // Fallback to HTML parsing if JSON-LD didn't provide title

      for (var i = 0; i < 10 && parent != null; i++) {
        // Look for the text content that contains the full title
        // The format is: "Title (Year) Quality - Details - Size - ESub :"
        final textContent = parent.text;

        // Look for the line that ends with " :" before the torrent link
        if (name == null && textContent.contains(':')) {
          final lines = textContent.split('\n');
          for (var line in lines) {
            line = line.trim();
            // Skip empty lines and navigation/header text
            if (line.isEmpty ||
                line.contains('TamilMV Official') ||
                line.contains('Click Here') ||
                line.startsWith('www.') ||
                line.toUpperCase().contains('MAGNET') ||
                line.contains('.torrent')) {
              continue;
            }

            // Look for lines ending with ":"  - these contain the full title with quality
            if (line.endsWith(':')) {
              var fullTitle = line.substring(0, line.length - 1).trim();

              // Remove any leading bullets or markers
              fullTitle = fullTitle.replaceAll(RegExp(r'^[•\-\*]\s*'), '');

              // Extract size if present in the title
              final sizeMatch = RegExp(r'\s+-\s+(\d+\.?\d*\s*(?:GB|MB|TB))\s*-',
                      caseSensitive: false)
                  .firstMatch(fullTitle);
              if (sizeMatch != null) {
                size = sizeMatch.group(1)!;
              }

              // This should be our full title with quality info
              if (fullTitle.length > 10 &&
                  (fullTitle.contains('1080p') ||
                      fullTitle.contains('720p') ||
                      fullTitle.contains('4K') ||
                      fullTitle.contains('PreDVD') ||
                      fullTitle.contains('HDRip') ||
                      fullTitle.contains('WEB-DL') ||
                      fullTitle.contains('BluRay'))) {
                name = fullTitle;
                break;
              }
            }
          }
        }

        // Look for torrent file link
        final torrentFileLink = parent.querySelector(
            'a[href*=\"attachment.php\"][data-fileext=\"torrent\"]');
        if (torrentFileLink != null) {
          torrentFileUrl = torrentFileLink.attributes['href'];
          if (torrentFileUrl != null && !torrentFileUrl.startsWith('http')) {
            torrentFileUrl = '$_baseUrl$torrentFileUrl';
          }
        }

        if (name != null && size != 'Unknown') break;
        parent = parent.parent;
      }

      // Fallback: Extract name from torrent filename if title not found
      if (name == null && torrentFileUrl != null) {
        parent = magnetLink.parent;
        for (var i = 0; i < 10 && parent != null; i++) {
          final torrentFileLink = parent.querySelector(
              'a[href*=\"attachment.php\"][data-fileext=\"torrent\"]');
          if (torrentFileLink != null) {
            var fullName = torrentFileLink.text.trim();

            // Clean up the name
            fullName = fullName.replaceAll(RegExp(r'^www\.\w+\.\w+ - '), '');
            fullName = fullName.replaceAll(RegExp(r'\.mkv\.torrent$'), '');
            fullName = fullName.replaceAll(RegExp(r'\.torrent$'), '');

            // Extract size from filename if present and size still unknown
            if (size == 'Unknown') {
              final fileSizeMatch =
                  RegExp(r' - (\d+\.?\d*\s*(?:GB|MB|TB))', caseSensitive: false)
                      .firstMatch(fullName);
              if (fileSizeMatch != null) {
                size = fileSizeMatch.group(1)!;
              }
            }

            name = fullName;
            break;
          }
          parent = parent.parent;
        }
      }

      // Last resort: Extract name from magnet dn parameter
      if (name == null) {
        final dnMatch = RegExp(r'dn=([^&]+)').firstMatch(magnetUrl);
        if (dnMatch != null) {
          name = Uri.decodeComponent(dnMatch.group(1)!.replaceAll('+', ' '));
          name = name.replaceAll(RegExp(r'^www\.\w+\.\w+ - '), '');
          name = name.replaceAll(RegExp(r'\.mkv$'), '');
        }
      }

      // Extract size from magnet xl parameter if still not found
      if (size == 'Unknown') {
        final xlMatch = RegExp(r'xl=(\d+)').firstMatch(magnetUrl);
        if (xlMatch != null) {
          final bytes = int.tryParse(xlMatch.group(1)!);
          if (bytes != null) {
            size = _formatBytes(bytes);
          }
        }
      }

      downloads.add(TorrentDownload(
        name: name ?? 'Untitled',
        size: size,
        magnetLink: magnetUrl,
        torrentFileUrl: torrentFileUrl,
        posterUrl: posterUrl, // Use the same poster for all variants
      ));
    }

    return downloads;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void dispose() {
    _dio.close();
  }
}

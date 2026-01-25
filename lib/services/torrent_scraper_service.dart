import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/torrent.dart';

class TorrentScraperService {
  final Dio _dio;
  String _baseUrl = 'https://www.1tamilmv.rsvp';

  List<TorrentEntry>? _cachedHomepageEntries;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  TorrentScraperService() : _dio = Dio() {
    _dio.options.followRedirects = true;
    _dio.options.maxRedirects = 5;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };
  }

  void updateBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _cachedHomepageEntries = null;
  }

  String get baseUrl => _baseUrl;

  /// Search across all providers
  Future<List<TorrentEntry>> search(String query) async {
    if (query.isEmpty) {
      return fetchHomepage();
    }

    final results = <TorrentEntry>[];
    final futures = [
      searchTamilMv(query),
      searchTorrentsCsv(query),
      searchRarbg(query),
      search1377x(query),
      searchTorrentTip(query),
    ];

    final responses = await Future.wait(
      futures.map((f) => f.catchError((_) => <TorrentEntry>[])),
    );

    for (final response in responses) {
      results.addAll(response);
    }

    // Sort by seeders (highest first), but keep TamilMV entries at top if no seeders
    results.sort((a, b) {
      final aSeeders = a.seeders ?? 0;
      final bSeeders = b.seeders ?? 0;
      if (aSeeders == 0 && bSeeders == 0) {
        // Both have no seeders, keep TamilMV first
        if (a.source == 'tamilmv' && b.source != 'tamilmv') return -1;
        if (b.source == 'tamilmv' && a.source != 'tamilmv') return 1;
        return 0;
      }
      return bSeeders.compareTo(aSeeders);
    });

    return results;
  }

  /// Search TamilMV
  Future<List<TorrentEntry>> searchTamilMv(String query) async {
    if (_cachedHomepageEntries != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      final queryLower = query.toLowerCase();
      return _cachedHomepageEntries!.where((entry) {
        return entry.title.toLowerCase().contains(queryLower);
      }).toList();
    }

    try {
      // TamilMV search URL
      final searchUrl = '$_baseUrl/index.php';
      final response = await _dio.get(
        searchUrl,
        queryParameters: {
          'app': 'core',
          'module': 'search',
          'controller': 'search',
          'q': query,
          'type': 'forums_topic',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      return _parseSearchResults(response.data, query);
    } catch (e) {
      // Fallback: filter homepage results by query
      try {
        final homepageEntries = await fetchHomepage();
        final queryLower = query.toLowerCase();
        return homepageEntries.where((entry) {
          return entry.title.toLowerCase().contains(queryLower);
        }).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Parse TamilMV search results
  List<TorrentEntry> _parseSearchResults(String html, String query) {
    final document = html_parser.parse(html);
    final entries = <TorrentEntry>[];
    final seen = <String>{};
    final queryLower = query.toLowerCase();

    // Try to find search result links
    final links = document.querySelectorAll('a[href*="/forums/topic/"]');

    for (final link in links) {
      final href = link.attributes['href'];
      if (href == null) continue;

      var title = link.text.trim();

      // Clean up title
      title = title
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (title.isEmpty || title.length < 3) continue;

      // Filter by query
      if (!title.toLowerCase().contains(queryLower)) continue;

      final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

      if (seen.contains(fullUrl)) continue;
      seen.add(fullUrl);

      // Extract size from title if present
      String? size;
      final sizeMatch = RegExp(r'\[(.*?)\]').firstMatch(title);
      if (sizeMatch != null) {
        size = sizeMatch.group(1);
      }

      entries.add(TorrentEntry(
        title: title,
        url: fullUrl,
        size: size,
        source: 'tamilmv',
      ));
    }

    return entries;
  }

  /// Torrents-CSV API search
  Future<List<TorrentEntry>> searchTorrentsCsv(String query) async {
    try {
      final response = await _dio.get(
        'https://torrents-csv.com/service/search',
        queryParameters: {'q': query, 'size': '20'},
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = response.data;
      final torrents = data['torrents'] as List<dynamic>? ?? [];

      return torrents.map((t) {
        final infoHash = t['infohash'] as String;
        final name = t['name'] as String;
        final sizeBytes = t['size_bytes'] as int;
        final seeders = t['seeders'] as int;
        final leechers = t['leechers'] as int;

        return TorrentEntry(
          title: name,
          url: 'magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(name)}',
          size: _formatBytes(sizeBytes),
          seeders: seeders,
          leechers: leechers,
          source: 'csv',
          infoHash: infoHash,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Rarbg search
  Future<List<TorrentEntry>> searchRarbg(String query) async {
    try {
      final response = await _dio.get(
        'https://www.rarbgproxy.to/search/',
        queryParameters: {'search': query},
      );

      if (response.statusCode != 200) {
        return [];
      }

      return _parseRarbgSearch(response.data);
    } catch (e) {
      return [];
    }
  }

  List<TorrentEntry> _parseRarbgSearch(String html) {
    final document = html_parser.parse(html);
    final entries = <TorrentEntry>[];

    final rows = document.querySelectorAll('tr.table2ta_rarbgproxy');

    for (final row in rows) {
      try {
        final cells = row.querySelectorAll('td.tlista_rarbgproxy');
        if (cells.length < 7) continue;

        final titleLink = cells[1].querySelector('a');
        if (titleLink == null) continue;

        var title = titleLink.text.trim();
        final href = titleLink.attributes['href'];
        if (href == null) continue;

        title = title.replaceAll('⭐', '').trim();

        final fullUrl =
            href.startsWith('http') ? href : 'https://www.rarbgproxy.to$href';

        final size = cells[4].text.trim();

        // Extract seeders from the font tag or direct text
        var seedersText = cells[5].text.trim();
        final seedersFont = cells[5].querySelector('font');
        if (seedersFont != null) {
          seedersText = seedersFont.text.trim();
        }
        final seeders = int.tryParse(seedersText) ?? 0;

        final leechersText = cells[6].text.trim();
        final leechers = int.tryParse(leechersText) ?? 0;

        entries.add(TorrentEntry(
          title: title,
          url: fullUrl,
          size: size,
          seeders: seeders,
          leechers: leechers,
          source: 'rarbg',
        ));
      } catch (e) {
        continue;
      }
    }

    return entries;
  }

  Future<List<TorrentEntry>> search1377x(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await _dio.get(
        'https://www.1377x.to/search/$encodedQuery/1/',
      );

      if (response.statusCode != 200) {
        return [];
      }

      return _parse1377xSearch(response.data);
    } catch (e) {
      return [];
    }
  }

  List<TorrentEntry> _parse1377xSearch(String html) {
    final document = html_parser.parse(html);
    final entries = <TorrentEntry>[];

    final rows = document.querySelectorAll('table.table-list tbody tr');

    for (final row in rows) {
      try {
        final cells = row.querySelectorAll('td');
        if (cells.length < 5) continue;

        // Title is in first cell (coll-1)
        final titleLink = cells[0].querySelector('a[href*="/torrent/"]');
        if (titleLink == null) continue;

        var title = titleLink.text.trim();
        final href = titleLink.attributes['href'];
        if (href == null) continue;

        final fullUrl =
            href.startsWith('http') ? href : 'https://www.1377x.to$href';

        // Seeders in coll-2 (seeds)
        final seedersText = cells[1].text.trim();
        final seeders = int.tryParse(seedersText) ?? 0;

        // Leechers in coll-3 (leeches)
        final leechersText = cells[2].text.trim();
        final leechers = int.tryParse(leechersText) ?? 0;

        // Size in coll-4
        final size = cells[4].text.trim();

        entries.add(TorrentEntry(
          title: title,
          url: fullUrl,
          size: size,
          seeders: seeders,
          leechers: leechers,
          source: '1377x',
        ));
      } catch (e) {
        continue;
      }
    }

    return entries;
  }

  Future<List<TorrentEntry>> searchTorrentTip(String query) async {
    try {
      final response = await _dio.get(
        'https://torrenttip212.top/search',
        queryParameters: {'q': query},
      );

      if (response.statusCode != 200) {
        return [];
      }

      final results = _parseTorrentTipSearch(response.data);
      return results;
    } catch (e) {
      return [];
    }
  }

  List<TorrentEntry> _parseTorrentTipSearch(String html) {
    final document = html_parser.parse(html);
    final entries = <TorrentEntry>[];

    final results = document.querySelectorAll('ul.page-list li');

    for (final result in results) {
      try {
        final titleLink = result.querySelector('div.flex-grow a');
        if (titleLink == null) {
          continue;
        }

        var title = titleLink.text.trim();
        final href = titleLink.attributes['href'];
        if (href == null) {
          continue;
        }

        final fullUrl =
            href.startsWith('http') ? href : 'https://torrenttip212.top$href';

        final dateDiv = result.querySelector('div.flex-none:last-child');
        String? dateStr;
        if (dateDiv != null) {
          dateStr = dateDiv.text.trim();
        }

        final size = '';

        entries.add(TorrentEntry(
          title: title,
          url: fullUrl,
          size: size,
          seeders: null, // Not showing seeders for TT
          leechers: null, // Use size field instead if needed
          source: 'torrenttip',
          color: dateStr, // Store date in color field for display
        ));
      } catch (e) {
        continue;
      }
    }

    return entries;
  }

  /// Fetch homepage (TamilMV latest)
  Future<List<TorrentEntry>> fetchHomepage() async {
    if (_cachedHomepageEntries != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedHomepageEntries!;
    }

    try {
      final response = await _dio.get(_baseUrl);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final entries = _parseHomepage(response.data);

      // Update cache
      _cachedHomepageEntries = entries;
      _cacheTimestamp = DateTime.now();

      return entries;
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

    final widgets = document.querySelectorAll('.ipsWidget_inner');

    for (final widget in widgets) {
      final links = widget.querySelectorAll('a[href*="/forums/topic/"]');

      for (final link in links) {
        final href = link.attributes['href'];
        if (href == null) continue;

        var title = '';
        final linkText = link.text.trim();

        // Heuristic: If link text starts with [ or is very short/technical, title is likely preceding
        bool isAttributeOnly = linkText.startsWith('[') ||
            (linkText.length < 25 &&
                (linkText.contains('1080p') || linkText.contains('720p')));

        if (!isAttributeOnly) {
          title = linkText;
        } else {
          // ========= CASE 1: Title in preceding <span><strong> sibling =========
          // Pattern: <span style="color:..."><strong>TITLE - </strong></span><strong><a href="...">
          title = _extractTitleFromPrecedingSibling(link, widget);

          // ========= CASE 2: Fallback - Robust backwards walk =========
          if (title.isEmpty) {
            Node? currentNode = link;
            var collectedText = '';

            // Walk backwards until we find a BR or hit the widget boundary
            while (currentNode != null && currentNode != widget) {
              final parent = currentNode.parentNode;
              if (parent != null) {
                final siblings = parent.nodes;
                final index = siblings.indexOf(currentNode);
                if (index > 0) {
                  currentNode = siblings[index - 1];

                  if (currentNode is Element && currentNode.localName == 'br') {
                    break;
                  }

                  // Prepend text
                  collectedText = (currentNode.text ?? '') + collectedText;
                  continue;
                }
              }

              // If no previous sibling or hit start of parent, go up
              currentNode = currentNode.parentNode;
            }

            if (collectedText.trim().isNotEmpty) {
              title = collectedText;
            } else {
              title = linkText;
            }
          }
        }

        // Clean up title
        title = title
            .replaceAll('&nbsp;', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        // Remove trailing dash often present: "Movie Name -"
        if (title.endsWith('-')) {
          title = title.substring(0, title.length - 1).trim();
        }

        if (title.isEmpty ||
            title.length < 3 ||
            !href.contains('/forums/topic/')) {
          continue;
        }

        final fullUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        if (seen.contains(fullUrl)) continue;
        seen.add(fullUrl);

        // Try to extract color from span inside link or just default
        final colorSpan = link.querySelector('span[style*="color"]');
        final color = colorSpan?.attributes['style']?.contains('color') == true
            ? _extractColor(colorSpan!.attributes['style']!)
            : null;

        // Extract extra info from link text (e.g. [1080p & 720p - x264 - 5GB...])
        String? size;
        if (linkText.startsWith('[') && linkText.endsWith(']')) {
          size = linkText.substring(1, linkText.length - 1);
        } else if (linkText.contains('[')) {
          final match = RegExp(r'\[(.*?)\]').firstMatch(linkText);
          if (match != null) size = match.group(1);
        }

        entries.add(TorrentEntry(
          title: title,
          url: fullUrl,
          color: color,
          size: size,
          source: 'tamilmv',
        ));
      }
    }

    return entries;
  }

  /// Extract title from preceding sibling elements
  /// Handles patterns like:
  /// - <span><strong>Title - </strong></span><strong><a>...</a></strong>
  /// - <strong>Title - <a>...</a></strong>
  /// - Plain text before the link
  String _extractTitleFromPrecedingSibling(Element link, Element widget) {
    final parent = link.parentNode;
    if (parent == null) return '';

    // CASE A: Link is inside <strong>, check siblings of <strong> in grandparent
    // Pattern: <span><strong>TITLE</strong></span><strong><a href="...">...</a></strong>
    if (parent is Element && parent.localName == 'strong') {
      final grandParent = parent.parentNode;
      if (grandParent != null) {
        final siblings = grandParent.nodes;
        final parentIndex = siblings.indexOf(parent);

        // Walk backwards through siblings at grandparent level
        for (var i = parentIndex - 1; i >= 0; i--) {
          final sibling = siblings[i];

          // Skip whitespace text nodes
          if (sibling is Text && sibling.text.trim().isEmpty) continue;

          // Hit a <br>, stop looking
          if (sibling is Element && sibling.localName == 'br') {
            break;
          }

          if (sibling is Element) {
            // Pattern: <span style="color:..."><strong>Title</strong></span>
            if (sibling.localName == 'span') {
              final strongInSpan = sibling.querySelector('strong');
              if (strongInSpan != null) {
                final text = strongInSpan.text.trim();
                if (text.isNotEmpty && !text.startsWith('[')) {
                  return text;
                }
              }
              // Plain span text
              final spanText = sibling.text.trim();
              if (spanText.isNotEmpty && !spanText.startsWith('[')) {
                return spanText;
              }
            }

            // Pattern: <strong>Title</strong> as direct sibling
            if (sibling.localName == 'strong') {
              final text = sibling.text.trim();
              if (text.isNotEmpty && !text.startsWith('[')) {
                return text;
              }
            }
          }

          // Text node with content
          if (sibling is Text) {
            final text = sibling.text.trim();
            if (text.isNotEmpty && !text.startsWith('[')) {
              return text;
            }
          }
        }
      }
    }

    // CASE B: Check for text directly before link in same parent
    // Pattern: <strong>Title - <a href="...">...</a></strong>
    final siblings = parent.nodes;
    final linkIndex = siblings.indexOf(link);

    var collectedText = '';
    for (var i = linkIndex - 1; i >= 0; i--) {
      final sibling = siblings[i];

      if (sibling is Element && sibling.localName == 'br') break;

      if (sibling is Text) {
        collectedText = sibling.text + collectedText;
      } else if (sibling is Element) {
        collectedText = sibling.text + collectedText;
      }
    }

    final trimmed = collectedText.trim();
    if (trimmed.isNotEmpty && !trimmed.startsWith('[')) {
      return trimmed;
    }

    return '';
  }

  String? _extractColor(String style) {
    final match =
        RegExp(r'color:\s*(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3}|rgb\([^)]+\))')
            .firstMatch(style);
    return match?.group(1);
  }

  /// Fetch torrent links from detail page
  Future<List<TorrentDownload>> fetchTorrentLinks(String url,
      {String source = 'tamilmv', String? infoHash}) async {
    // For CSV entries with direct magnet
    if (source == 'csv' && infoHash != null) {
      final name = Uri.parse(url).queryParameters['dn'] ?? 'Download';
      return [
        TorrentDownload(
          name: name,
          size: 'Unknown',
          magnetLink: url,
        ),
      ];
    }

    // For Rarbg
    if (source == 'rarbg') {
      return _fetchRarbgDetails(url);
    }

    // For TorrentTip
    if (source == 'torrenttip') {
      return _fetchTorrentTipDetails(url);
    }

    // For TamilMV and 1377x
    return _fetchTamilMvDetails(url);
  }

  Future<List<TorrentDownload>> _fetchRarbgDetails(String url) async {
    try {
      final response = await _dio.get(url);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      return _parseRarbgDetails(response.data);
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  List<TorrentDownload> _parseRarbgDetails(String html) {
    final document = html_parser.parse(html);
    final downloads = <TorrentDownload>[];

    // Find magnet link robustly
    String? magnetUrl;
    final allLinks = document.querySelectorAll('a');
    for (final link in allLinks) {
      final href = link.attributes['href'];
      if (href != null && href.startsWith('magnet:')) {
        magnetUrl = href;
        break;
      }
    }

    if (magnetUrl == null) return downloads;

    // Extract name from magnet dn parameter
    final dnMatch = RegExp(r'dn=([^&]+)').firstMatch(magnetUrl);
    var name = 'Download';
    if (dnMatch != null) {
      name = Uri.decodeComponent(dnMatch.group(1)!.replaceAll('+', ' '));
    }

    // Find size and peers by iterating through headers
    String size = 'Unknown';
    int? seeders;
    int? leechers;

    final headers = document.querySelectorAll('td.header22');
    for (final header in headers) {
      final text = header.text.trim();

      if (text.contains('Size:')) {
        final sizeCell = header.nextElementSibling;
        if (sizeCell != null) {
          size = sizeCell.text.trim();
        }
      } else if (text.contains('Peers:')) {
        final peersCell = header.nextElementSibling;
        if (peersCell != null) {
          final peersText = peersCell.text;
          final seedersMatch =
              RegExp(r'Seeders\s*:\s*(\d+)').firstMatch(peersText);
          final leechersMatch =
              RegExp(r'Leechers\s*:\s*(\d+)').firstMatch(peersText);
          if (seedersMatch != null) {
            seeders = int.tryParse(seedersMatch.group(1)!);
          }
          if (leechersMatch != null) {
            leechers = int.tryParse(leechersMatch.group(1)!);
          }
        }
      }
    }

    downloads.add(TorrentDownload(
      name: name,
      size: size,
      magnetLink: magnetUrl,
      seeders: seeders,
      leechers: leechers,
    ));

    return downloads;
  }

  Future<List<TorrentDownload>> _fetchTamilMvDetails(String url) async {
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

    String? posterUrl;
    final postContent = document.querySelector(
        '.ipsType_richText, .cPost_contentWrap, [data-role="commentContent"]');
    if (postContent != null) {
      final firstImg = postContent.querySelector('img');
      if (firstImg != null) {
        posterUrl = firstImg.attributes['src'];
        if (posterUrl != null && !posterUrl.startsWith('http')) {
          posterUrl = '$_baseUrl$posterUrl';
        }
      }
    }

    final magnetLinks = document.querySelectorAll('a[href^="magnet:"]');

    Map<String, String> magnetToTitle = {};
    try {
      final jsonLdScript =
          document.querySelector('script[type="application/ld+json"]');
      if (jsonLdScript != null) {
        final jsonText = jsonLdScript.text;
        final textMatch = RegExp(r'"text":\s*"([^"]+)"').firstMatch(jsonText);
        if (textMatch != null) {
          final text = textMatch
              .group(1)!
              .replaceAll(r'\u00a0', ' ')
              .replaceAll(r'\n', '\n')
              .replaceAll(r'\t', '');

          final lines = text.split('\n');
          String? currentTitle;
          int titleIndex = 0;

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();

            if (line.endsWith(':') &&
                !line.contains('TamilMV') &&
                !line.contains('Click Here')) {
              currentTitle = line.substring(0, line.length - 1).trim();
            } else if (currentTitle != null &&
                (line.contains('.torrent') || line.toUpperCase() == 'MAGNET')) {
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
      // Ignore
    }

    for (final magnetLink in magnetLinks) {
      final magnetUrl = magnetLink.attributes['href'] ?? '';

      var parent = magnetLink.parent;
      String? name;
      String size = 'Unknown';
      String? torrentFileUrl;

      if (magnetToTitle.containsKey(magnetUrl)) {
        name = magnetToTitle[magnetUrl];

        final sizeMatch =
            RegExp(r'(\d+\.?\d*\s*(?:GB|MB|TB))', caseSensitive: false)
                .firstMatch(name!);
        if (sizeMatch != null) {
          size = sizeMatch.group(1)!;
        }
      }

      for (var i = 0; i < 10 && parent != null; i++) {
        final textContent = parent.text;

        if (name == null && textContent.contains(':')) {
          final lines = textContent.split('\n');
          for (var line in lines) {
            line = line.trim();
            if (line.isEmpty ||
                line.contains('TamilMV Official') ||
                line.contains('Click Here') ||
                line.startsWith('www.') ||
                line.toUpperCase().contains('MAGNET') ||
                line.contains('.torrent')) {
              continue;
            }

            if (line.endsWith(':')) {
              var fullTitle = line.substring(0, line.length - 1).trim();

              fullTitle = fullTitle.replaceAll(RegExp(r'^[•\-\*]\s*'), '');

              final sizeMatch = RegExp(r'\s+-\s+(\d+\.?\d*\s*(?:GB|MB|TB))\s*-',
                      caseSensitive: false)
                  .firstMatch(fullTitle);
              if (sizeMatch != null) {
                size = sizeMatch.group(1)!;
              }

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

        final torrentFileLink = parent
            .querySelector('a[href*="attachment.php"][data-fileext="torrent"]');
        if (torrentFileLink != null) {
          torrentFileUrl = torrentFileLink.attributes['href'];
          if (torrentFileUrl != null && !torrentFileUrl.startsWith('http')) {
            torrentFileUrl = '$_baseUrl$torrentFileUrl';
          }
        }

        if (name != null && size != 'Unknown') break;
        parent = parent.parent;
      }

      if (name == null && torrentFileUrl != null) {
        parent = magnetLink.parent;
        for (var i = 0; i < 10 && parent != null; i++) {
          final torrentFileLink = parent.querySelector(
              'a[href*="attachment.php"][data-fileext="torrent"]');
          if (torrentFileLink != null) {
            var fullName = torrentFileLink.text.trim();

            fullName = fullName.replaceAll(RegExp(r'^www\.\w+\.\w+ - '), '');
            fullName = fullName.replaceAll(RegExp(r'\.mkv\.torrent$'), '');
            fullName = fullName.replaceAll(RegExp(r'\.torrent$'), '');

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

      if (name == null) {
        final dnMatch = RegExp(r'dn=([^&]+)').firstMatch(magnetUrl);
        if (dnMatch != null) {
          name = Uri.decodeComponent(dnMatch.group(1)!.replaceAll('+', ' '));
          name = name.replaceAll(RegExp(r'^www\.\w+\.\w+ - '), '');
          name = name.replaceAll(RegExp(r'\.mkv$'), '');
        }
      }

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
        posterUrl: posterUrl,
      ));
    }

    return downloads;
  }

  /// Fetch details for TorrentTip torrents
  Future<List<TorrentDownload>> _fetchTorrentTipDetails(String url) async {
    try {
      final response = await _dio.get(url);
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.data);
      final downloads = <TorrentDownload>[];

      // Find magnet links on the page
      final magnetLinks = document.querySelectorAll('a[href^="magnet:"]');

      for (final magnetLink in magnetLinks) {
        final magnetUrl = magnetLink.attributes['href'] ?? '';
        if (magnetUrl.isEmpty) continue;

        // Try to get name from page title or article title
        final titleElement = document.querySelector('h1')?.text.trim() ??
            document.querySelector('title')?.text.trim() ??
            'Unknown';

        // TorrentTip doesn't have size on search page
        const size = 'Unknown';

        downloads.add(TorrentDownload(
          name: titleElement,
          size: size,
          magnetLink: _fixMagnetLink(magnetUrl),
        ));
      }

      return downloads;
    } catch (e) {
      return [];
    }
  }

  /// Fix magnet link format - adds 'btih:' if missing
  String _fixMagnetLink(String magnet) {
    // Check if magnet link is missing btih: part
    if (magnet.contains('magnet:?xt=urn:') && !magnet.contains('btih:')) {
      // Replace "urn:" with "urn:btih:" if btih is missing
      return magnet.replaceFirst('magnet:?xt=urn:', 'magnet:?xt=urn:btih:');
    }
    return magnet;
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

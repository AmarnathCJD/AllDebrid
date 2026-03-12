import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 8),
));

class TVMazeService {
  static const String _baseUrl = 'https://api.tvmaze.com';
  static const Duration _cacheExpiry = Duration(hours: 6);

  Future<TVMazeShow?> searchShow(String title) async {
    final cacheKey = 'tvmaze_show_${title.toLowerCase().replaceAll(' ', '_')}';
    final cached = await _getCache(cacheKey);
    if (cached != null) {
      return TVMazeShow.fromJson(jsonDecode(cached));
    }

    try {
      final encodedTitle = Uri.encodeComponent(title);
      final response = await _dio.get(
          '$_baseUrl/singlesearch/shows?q=$encodedTitle');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final jsonStr = jsonEncode(data);
        await _setCache(cacheKey, jsonStr);
        return TVMazeShow.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  Future<TVMazeNextEpisode?> getNextEpisode(int showId) async {
    final cacheKey = 'tvmaze_nextepisode_$showId';
    final cached = await _getCache(cacheKey, maxAge: const Duration(hours: 2));
    if (cached != null) {
      try {
        return TVMazeNextEpisode.fromJson(jsonDecode(cached));
      } catch (_) {}
    }

    try {
      final response = await _dio.get(
          '$_baseUrl/shows/$showId?embed=nextepisode');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final embedded = data['_embedded'] as Map<String, dynamic>?;
        final nextEp = embedded?['nextepisode'] as Map<String, dynamic>?;
        if (nextEp != null) {
          final episode = TVMazeNextEpisode.fromJson(nextEp);
          await _setCache(cacheKey, jsonEncode(nextEp),
              maxAge: const Duration(hours: 2));
          return episode;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<TVMazeShowInfo?> getShowInfo(String title) async {
    try {
      final show = await searchShow(title);
      if (show == null) return null;

      final nextEpisode =
          show.status == 'Running' ? await getNextEpisode(show.id) : null;

      return TVMazeShowInfo(
        show: show,
        nextEpisode: nextEpisode,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getCache(String key,
      {Duration maxAge = _cacheExpiry}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(key);
      final timestamp = prefs.getInt('${key}_ts');

      if (stored != null && timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age < maxAge.inMilliseconds) {
          return stored;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _setCache(String key, String value,
      {Duration maxAge = _cacheExpiry}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      await prefs.setInt('${key}_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}

class TVMazeShow {
  final int id;
  final String name;
  final String status;
  final String? network;
  final String? premiered;
  final double? rating;
  final String? officialSite;

  TVMazeShow({
    required this.id,
    required this.name,
    required this.status,
    this.network,
    this.premiered,
    this.rating,
    this.officialSite,
  });

  factory TVMazeShow.fromJson(Map<String, dynamic> json) {
    final networkData = json['network'] as Map<String, dynamic>?;
    final webChannel = json['webChannel'] as Map<String, dynamic>?;
    final ratingData = json['rating'] as Map<String, dynamic>?;

    return TVMazeShow(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      status: json['status'] ?? 'Unknown',
      network:
          networkData?['name'] as String? ?? webChannel?['name'] as String?,
      premiered: json['premiered'] as String?,
      rating: (ratingData?['average'] as num?)?.toDouble(),
      officialSite: json['officialSite'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'network': {'name': network},
        'premiered': premiered,
        'rating': {'average': rating},
        'officialSite': officialSite,
      };

  bool get isRunning => status == 'Running';
}

class TVMazeNextEpisode {
  final int id;
  final String? name;
  final int season;
  final int number;
  final String? airdate;
  final String? summary;

  TVMazeNextEpisode({
    required this.id,
    this.name,
    required this.season,
    required this.number,
    this.airdate,
    this.summary,
  });

  factory TVMazeNextEpisode.fromJson(Map<String, dynamic> json) {
    return TVMazeNextEpisode(
      id: json['id'] ?? 0,
      name: json['name'] as String?,
      season: json['season'] ?? 0,
      number: json['number'] ?? 0,
      airdate: json['airdate'] as String?,
      summary: json['summary'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'season': season,
        'number': number,
        'airdate': airdate,
        'summary': summary,
      };

  DateTime? get airDateTime {
    if (airdate == null || airdate!.isEmpty) return null;
    try {
      return DateTime.parse(airdate!);
    } catch (_) {
      return null;
    }
  }

  Duration? get timeUntilAir {
    final dt = airDateTime;
    if (dt == null) return null;
    final diff = dt.difference(DateTime.now());
    return diff.isNegative ? null : diff;
  }

  String get countdownText {
    final until = timeUntilAir;
    if (until == null) return 'Aired';

    final days = until.inDays;
    final hours = until.inHours.remainder(24);
    final minutes = until.inMinutes.remainder(60);
    final seconds = until.inSeconds.remainder(60);

    final List<String> parts = [];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (days == 0) {
      parts.add('${seconds}s');
    }

    if (parts.isEmpty) return 'Airing Soon';
    return 'in ${parts.join(' ')}';
  }

  String get episodeLabel =>
      'S${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}';
}

class TVMazeShowInfo {
  final TVMazeShow show;
  final TVMazeNextEpisode? nextEpisode;

  TVMazeShowInfo({required this.show, this.nextEpisode});

  bool get isOngoing => show.isRunning;
  bool get hasNextEpisode => nextEpisode != null;
}

import 'package:dio/dio.dart';

class VideoSource {
  final String url;
  final String quality;
  final String format;
  final String size;
  final Map<String, String>? headers;

  VideoSource({
    required this.url,
    required this.quality,
    required this.format,
    required this.size,
    this.headers,
  });

  factory VideoSource.fromJson(Map<String, dynamic> json) {
    return VideoSource(
      url: json['url'] ?? '',
      quality: json['quality']?.toString() ?? 'Unknown',
      format: json['format'] ?? '',
      size: json['size']?.toString() ?? '',
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'])
          : null,
    );
  }
}

class VideoCaption {
  final String label;
  final String file;

  VideoCaption({required this.label, required this.file});

  factory VideoCaption.fromJson(Map<String, dynamic> json) {
    String label = json['label'] ?? '';
    label = label.replaceAll(' - FlowCast', '').trim();
    return VideoCaption(
      label: label,
      file: json['file'] ?? '',
    );
  }
}

class VideoSourceService {
  static const String _backendUrl = 'https://cdok.gogram.fun';
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 10),
  ));

  Future<Map<String, dynamic>> getVideoSources(
    String id,
    String season,
    String episode, {
    String serviceName = 'flowcast',
  }) async {
    try {
      final response = await _dio.post(
        '$_backendUrl/api/video',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
        data: {
          "id": id,
          "season": season,
          "episode": episode,
          "service": 'flowcast',
          "requestID":
              serviceName == 'flowcast' ? 'tvVideoProvider' : serviceName,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        var data = response.data['data'];

        if (data != null && data['data'] != null) {
          data = data['data'];
        }

        if (data != null) {
          final sources = (data['sources'] as List? ?? [])
              .map((s) => VideoSource.fromJson(s))
              .toList();

          final captions = (data['captions'] as List? ?? [])
              .map((c) => VideoCaption.fromJson(c))
              .toList();

          sources.sort((a, b) {
            final qA =
                int.tryParse(a.quality.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final qB =
                int.tryParse(b.quality.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return qB.compareTo(qA);
          });

          return {
            'sources': sources,
            'captions': captions,
          };
        }
      }
      return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
    } catch (e) {
      throw Exception('Failed to load video sources: $e');
    }
  }

  static const Map<String, String> flowCastHeaders = {
    'Referer': 'https://rivestream.org/',
    'Origin': 'https://rivestream.org',
  };
}

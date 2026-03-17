import 'package:flutter/services.dart';

class CastService {
  static const platform = MethodChannel('com.alldebrid.app/cast');

  static Future<bool> initializeCast() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('initializeCast') ?? false;
      return result;
    } catch (e) {
      print('Error initializing cast: $e');
      return false;
    }
  }

  static Future<bool> connectToDevice(
      String deviceName, String deviceAddress) async {
    try {
      final bool result = await platform.invokeMethod<bool>(
            'connectToDevice',
            {
              'deviceName': deviceName,
              'deviceAddress': deviceAddress,
            },
          ) ??
          false;
      return result;
    } catch (e) {
      print('Error connecting to device: $e');
      return false;
    }
  }

  static Future<bool> startCasting(String videoUrl, String title) async {
    try {
      final bool result = await platform.invokeMethod<bool>(
            'startCasting',
            {
              'videoUrl': videoUrl,
              'title': title,
            },
          ) ??
          false;
      return result;
    } catch (e) {
      print('Error starting cast: $e');
      return false;
    }
  }

  static Future<bool> stopCasting() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('stopCasting') ?? false;
      return result;
    } catch (e) {
      print('Error stopping cast: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> discoverDevices() async {
    try {
      final List<dynamic> result =
          await platform.invokeMethod<List<dynamic>>('discoverDevices') ?? [];
      return List<Map<String, dynamic>>.from(
        result.map((device) => Map<String, dynamic>.from(device as Map)),
      );
    } catch (e) {
      print('Error discovering devices: $e');
      return [];
    }
  }

  static Future<bool> isPaused() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('isPaused') ?? false;
      return result;
    } catch (e) {
      print('Error checking pause state: $e');
      return false;
    }
  }

  static Future<bool> pausePlayback() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('pausePlayback') ?? false;
      return result;
    } catch (e) {
      print('Error pausing: $e');
      return false;
    }
  }

  static Future<bool> resumePlayback() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('resumePlayback') ?? false;
      return result;
    } catch (e) {
      print('Error resuming: $e');
      return false;
    }
  }

  static Future<bool> seek(int positionMs) async {
    try {
      final bool result = await platform.invokeMethod<bool>(
            'seek',
            {'positionMs': positionMs},
          ) ??
          false;
      return result;
    } catch (e) {
      print('Error seeking: $e');
      return false;
    }
  }

  static Future<bool> setVolume(double volume) async {
    try {
      final bool result = await platform.invokeMethod<bool>(
            'setVolume',
            {'volume': volume},
          ) ??
          false;
      return result;
    } catch (e) {
      print('Error setting volume: $e');
      return false;
    }
  }
}

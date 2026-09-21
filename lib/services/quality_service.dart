import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:reelriot/utils/constant.dart';

class QualityService {
  QualityService._();
  static final QualityService instance = QualityService._();

  final Map<String, String> _cache = {};

  /// Fast, synchronous date-based estimate used for instant zero-CLS rendering.
  String? getQualitySync({
    required String? releaseDate,
    required bool isMovie,
  }) {
    if (!isMovie) return 'HD';
    if (releaseDate == null || releaseDate.trim().isEmpty) return null;

    try {
      final release = DateTime.parse(releaseDate.trim());
      final now = DateTime.now();

      if (release.isAfter(now)) return 'SOON';

      final diffDays = now.difference(release).inDays;
      return diffDays < 90 ? 'CAM' : 'HD';
    } catch (e) {
      return null;
    }
  }

  /// Asynchronously fetches the accurate quality badge from Caffeine API (/v1/quality/:type/:id).
  /// Checks Redis-backed server overrides, digital release detection, and temporal rules.
  Future<String?> getQualityAsync({
    required String type,
    required int? id,
    String? releaseDate,
    String? caffeineBaseUrl,
  }) async {
    if (type != 'movie') return 'HD';

    final syncEstimate = getQualitySync(
      releaseDate: releaseDate,
      isMovie: type == 'movie',
    );

    if (id == null) return syncEstimate;

    final cacheKey = '$type:$id';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final baseUrl = (caffeineBaseUrl != null && caffeineBaseUrl.isNotEmpty)
          ? caffeineBaseUrl.replaceAll(RegExp(r'/$'), '')
          : caffeineApiUrl.replaceAll(RegExp(r'/$'), '');

      final uri = Uri.parse('$baseUrl/v1/quality/$type/$id');
      final res = await http
          .get(uri, headers: caffeineApiHeaders)
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true && data['quality'] != null) {
          final q = (data['quality'] as String).toUpperCase();
          _cache[cacheKey] = q;
          return q;
        }
      }
    } catch (e) {
      debugPrint('[QualityService] Failed to fetch quality for $cacheKey: $e');
    }

    if (syncEstimate != null) {
      _cache[cacheKey] = syncEstimate;
    }
    return syncEstimate;
  }
}

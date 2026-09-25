import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:reelriot/api/endpoints.dart';
import 'package:reelriot/models/discovery_feed.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/utils/config.dart';

/// Thin HTTP wrapper around the Reelriot Discovery Engine v1.2 (`GET /v1/discovery`).
///
/// All requests attach the standard Caffeine API auth headers (bearer token).
/// On network failure or non-200 response this returns null, letting the UI
/// fall back gracefully to direct TMDB calls.
class DiscoveryService {
  DiscoveryService._();
  static final DiscoveryService instance = DiscoveryService._();

  static const _timeout = Duration(seconds: 15);

  /// Fetches the full home-screen discovery feed.
  ///
  /// [caffeineBaseUrl] — value from `AppDependencyProvider.caffeineAPIURL`
  /// [userId]         — optional; pass the signed-in user's UID for AI rows
  /// [region]         — optional; ISO-3166-1 alpha-2 (e.g. 'US')
  /// [platform]       — optional; client platform (e.g. 'android')
  /// [env]            — optional; environment (e.g. 'dev', 'prod')
  Future<DiscoveryFeed?> fetchHomeFeed({
    required String caffeineBaseUrl,
    String? userId,
    String? mediaType,
    String? region,
    String? platform,
    String? env,
  }) async {
    if (caffeineBaseUrl.trim().isEmpty) return null;

    final url = Endpoints.discoveryFeedUrl(
      caffeineBaseUrl,
      userId: userId,
      mediaType: mediaType,
      region: region,
      platform: platform,
      env: env,
    );

    try {
      debugPrint('[Discovery] GET $url');
      final res = await http
          .get(Uri.parse(url), headers: caffeineApiHeaders)
          .timeout(_timeout);

      if (res.statusCode != 200) {
        debugPrint('[Discovery] ⚠️ ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
        return null;
      }

      final decoded = jsonDecode(res.body);
      final feed = DiscoveryFeed.fromJson(decoded);
      debugPrint('[Discovery] ✅ ${feed.rows.length} rows loaded');
      return feed;
    } on SocketException catch (e) {
      debugPrint('[Discovery] SocketException: $e');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('[Discovery] Timeout: $e');
      return null;
    } catch (e) {
      debugPrint('[Discovery] Error: $e');
      return null;
    }
  }
}

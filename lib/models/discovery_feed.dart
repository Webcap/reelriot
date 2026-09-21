/// Typed model for Reelriot Discovery Engine v1.2 (`GET /v1/discovery`).
///
/// The API returns a list of content rows.  Each row has a [type] that
/// identifies its source / purpose (e.g. 'featured', 'trending',
/// 'social_buzz', 'because_you_watched', 'holiday').
library;

// ── Discovery feed root ──────────────────────────────────────────────────────

class DiscoveryFeed {
  final List<DiscoveryRow> rows;

  const DiscoveryFeed({required this.rows});

  factory DiscoveryFeed.fromJson(dynamic json) {
    if (json is Map) {
      final rawRows = json['rows'] ?? json['sections'];
      if (rawRows is List) {
        return DiscoveryFeed(
          rows: rawRows
              .whereType<Map>()
              .map((m) => DiscoveryRow.fromJson(Map<String, dynamic>.from(m)))
              .toList(),
        );
      }
    }
    
    // If the API directly returns an array of rows
    if (json is List) {
      // Check if it's an array of rows by looking for the 'items' key in the first element
      if (json.isNotEmpty && json.first is Map && (json.first as Map).containsKey('items')) {
        return DiscoveryFeed(
          rows: json
              .whereType<Map>()
              .map((m) => DiscoveryRow.fromJson(Map<String, dynamic>.from(m)))
              .toList(),
        );
      }
      
      // Fallback: treat the flat array as items for a single 'featured' row.
      return DiscoveryFeed(
        rows: [
          DiscoveryRow(
            id: 'featured',
            title: 'Featured',
            type: 'featured',
            items: json
                .whereType<Map>()
                .map((m) => DiscoveryItem.fromJson(Map<String, dynamic>.from(m)))
                .toList(),
          ),
        ],
      );
    }
    return const DiscoveryFeed(rows: []);
  }

  /// Returns the first row that matches any of the given [types].
  DiscoveryRow? rowByType(List<String> types) {
    for (final row in rows) {
      if (types.contains(row.type)) return row;
    }
    return null;
  }
}

// ── A single content row ─────────────────────────────────────────────────────

class DiscoveryRow {
  /// Stable identifier (e.g. 'featured', 'trending', 'social_buzz').
  final String id;

  /// Human-readable label (e.g. 'Trending Now', 'Because You Watched').
  final String title;

  /// Machine type from the API spec.
  final String type;

  final List<DiscoveryItem> items;

  const DiscoveryRow({
    required this.id,
    required this.title,
    required this.type,
    required this.items,
  });

  factory DiscoveryRow.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return DiscoveryRow(
      id: json['id']?.toString() ?? json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((m) => DiscoveryItem.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : [],
    );
  }
}

// ── A single content item inside a row ──────────────────────────────────────

class DiscoveryItem {
  final int tmdbId;
  final String? mediaType; // 'movie' | 'tv'
  final String? title;
  final String? posterPath;
  final String? backdropPath;
  final double? voteAverage;
  final int? runtime; // minutes, may be null for TV

  const DiscoveryItem({
    required this.tmdbId,
    this.mediaType,
    this.title,
    this.posterPath,
    this.backdropPath,
    this.voteAverage,
    this.runtime,
  });

  factory DiscoveryItem.fromJson(Map<String, dynamic> json) {
    // Support both snake_case and camelCase from the API.
    final rawId = json['tmdb_id'] ?? json['tmdbId'] ?? json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;

    final rawRating = json['vote_average'] ?? json['voteAverage'] ?? json['rating'];
    final double? rating = rawRating is num ? rawRating.toDouble() : null;

    final rawRuntime = json['runtime'];
    final int? mins = rawRuntime is int ? rawRuntime : int.tryParse(rawRuntime?.toString() ?? '');

    return DiscoveryItem(
      tmdbId: id,
      mediaType: json['media_type']?.toString() ?? json['mediaType']?.toString(),
      title: json['title']?.toString() ?? json['name']?.toString(),
      posterPath: json['poster_path']?.toString() ?? json['posterPath']?.toString(),
      backdropPath: json['backdrop_path']?.toString() ?? json['backdropPath']?.toString(),
      voteAverage: rating,
      runtime: mins,
    );
  }

  /// Formats runtime as "1h 10m" or null.
  String? get formattedRuntime {
    if (runtime == null || runtime! <= 0) return null;
    final h = runtime! ~/ 60;
    final m = runtime! % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

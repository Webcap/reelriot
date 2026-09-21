import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/models/discovery_feed.dart';
import 'package:reelriot/models/movie_models.dart';
import 'package:reelriot/models/tv.dart';
import 'package:reelriot/screens/movie_screens/movie_details.dart';
import 'package:reelriot/screens/tv_screens/tv_detail_page.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/widgets/shimmer_widget.dart';

class DiscoveryRowWidget extends StatelessWidget {
  final DiscoveryRow row;
  final bool isDark;
  final String themeMode;
  final String imageQuality;
  final bool isProxyEnabled;
  final String proxyUrl;
  final String lang;
  final bool includeAdult;

  const DiscoveryRowWidget({
    super.key,
    required this.row,
    required this.isDark,
    required this.themeMode,
    required this.imageQuality,
    required this.isProxyEnabled,
    required this.proxyUrl,
    required this.lang,
    required this.includeAdult,
  });

  @override
  Widget build(BuildContext context) {
    final textPrim = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0B0F14);
    final items = row.items;
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final cardWidth = isTablet ? 140.0 : 115.0;
    final posterHeight = cardWidth * 1.5; // True 2:3 aspect ratio
    final rowHeight = posterHeight + (isTablet ? 48.0 : 40.0);
    final isHoliday = row.type == 'holiday' ||
        row.id == 'holiday' ||
        row.title.toLowerCase().contains('holiday') ||
        row.title.toLowerCase().contains('magic');

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: EdgeInsets.fromLTRB(isTablet ? 20 : 16, 8, isTablet ? 20 : 8, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: isHoliday ? const Color(0xFFF59E0B) : const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isTablet ? 19 : 17,
                          fontWeight: FontWeight.w700,
                          color: textPrim,
                          fontFamily: 'PoppinsSB',
                        ),
                      ),
                    ),
                    if (isHoliday) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Color(0xFFF59E0B),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Cards (True 2:3 aspect ratio)
        SizedBox(
          height: rowHeight,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final imgBase = buildImageUrl(
                  tmdbBaseImageUrl, proxyUrl, isProxyEnabled, context);
              final posterUrl = item.posterPath != null
                  ? '$imgBase$imageQuality${item.posterPath}'
                  : '';

              return Padding(
                padding: EdgeInsets.only(right: isTablet ? 14 : 10),
                child: GestureDetector(
                  onTap: () {
                    final heroId = '${row.id}-${item.tmdbId}-$index';
                    final isTvItem = item.mediaType == 'tv';
                    if (isTvItem) {
                      final tvSeries = TV(
                        id: item.tmdbId,
                        name: item.title,
                        posterPath: item.posterPath,
                        backdropPath: item.backdropPath,
                        voteAverage: item.voteAverage,
                        overview: null,
                        firstAirDate: null,
                        originalLanguage: null,
                        originalName: item.title,
                        popularity: null,
                        voteCount: null,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TVDetailPage(
                            tvSeries: tvSeries,
                            heroId: heroId,
                          ),
                        ),
                      );
                    } else {
                      final movie = Movie(
                        id: item.tmdbId,
                        title: item.title,
                        posterPath: item.posterPath,
                        backdropPath: item.backdropPath,
                        voteAverage: item.voteAverage,
                        overview: null,
                        releaseDate: null,
                        adult: false,
                        originalLanguage: null,
                        originalTitle: item.title,
                        popularity: null,
                        video: false,
                        voteCount: null,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MovieDetailPage(
                            movie: movie,
                            heroId: heroId,
                          ),
                        ),
                      );
                    }
                  },
                  child: SizedBox(
                    width: cardWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Poster with rating badge (True 2:3 aspect ratio)
                        SizedBox(
                          width: cardWidth,
                          height: posterHeight,
                          child: Hero(
                            tag: '${row.id}-${item.tmdbId}-$index',
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                                  child: posterUrl.isEmpty
                                      ? Image.asset(
                                          'assets/images/na_logo.png',
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        )
                                      : CachedNetworkImage(
                                          cacheManager: cacheProp(),
                                          imageUrl: posterUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          placeholder: (_, __) =>
                                              scrollingImageShimmer(themeMode),
                                          errorWidget: (_, __, ___) =>
                                              Image.asset(
                                            'assets/images/na_logo.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                ),
                                // Star rating badge
                                if (item.voteAverage != null)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 11,
                                            color: Color(0xFFFACC15),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            item.voteAverage!
                                                .toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Title
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                          child: Text(
                            item.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isTablet ? 13 : 11,
                              fontWeight: FontWeight.w600,
                              color: textPrim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Divider(
          color: isDark ? Colors.white12 : Colors.black12,
          thickness: 1,
          endIndent: isTablet ? 24 : 20,
          indent: isTablet ? 24 : 10,
        ),
      ],
    );
  }
}

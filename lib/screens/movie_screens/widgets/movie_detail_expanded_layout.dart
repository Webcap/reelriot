import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/api/endpoints.dart';
import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/models/movie_models.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/provider/recently_watched_provider.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/screens/movie_screens/widgets/movie_about.dart';
import 'package:reelriot/screens/movie_screens/widgets/movie_details_options.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/widgets/native_ad_banner.dart';
import 'package:reelriot/widgets/watch_now_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';

// ── Design tokens (design.json) ─────────────────────────────────────────────
class _C {
  static const primary = Color(0xFFDC2626);
  static const bgSurfaceDark = Color(0xFF0B0F14);
  static const iconBgDark = Color(0x14FFFFFF);
  static const iconBgLight = Color(0x140F172A);
  static const borderDark = Color(0x14FFFFFF);
  static const borderLight = Color(0x140F172A);
  static const textPrimDark = Color(0xFFFFFFFF);
  static const textPrimLight = Color(0xFF0B0F14);
}

/// Two-column layout for the movie detail page on tablet-landscape /
/// unfolded-foldable widths (>= 840dp): poster/backdrop pinned in a
/// contained media card on the left, title/ratings/watch-now/synopsis/
/// cast/videos/recommendations scrolling together on the right. Same
/// "media left, content right" composition as the episode detail page's
/// expanded layout, and the large-screen treatment design.json specified
/// for detail pages that no screen in this app had built yet.
class MovieDetailExpandedLayout extends StatelessWidget {
  const MovieDetailExpandedLayout({
    super.key,
    required this.movie,
    required this.heroId,
    this.onTrailerTap,
  });

  final Movie movie;
  final String heroId;
  final VoidCallback? onTrailerTap;

  bool _computeIsWatched(BuildContext context) {
    final recentProvider = Provider.of<RecentProvider>(context);
    for (var m in recentProvider.movies) {
      if (m.id == movie.id) {
        final elapsed = m.elapsed ?? 0;
        final remaining = m.remaining ?? 0;
        final total = elapsed + remaining;
        return total > 0 && (elapsed / total) >= 0.9;
      }
    }
    return false;
  }

  void _shareMovie(BuildContext context) {
    SharePlus.instance.share(ShareParams(
      text: tr('share_movie', namedArgs: {
        'title': movie.title ?? '—',
        'rating': (movie.voteAverage ?? 0).toString(),
        'id': '${movie.id}',
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final isProxy = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final appDep = Provider.of<AppDependencyProvider>(context);
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrim = isDark ? _C.textPrimDark : _C.textPrimLight;
    final iconBg = isDark ? _C.iconBgDark : _C.iconBgLight;
    final border = isDark ? _C.borderDark : _C.borderLight;
    final isWatched = _computeIsWatched(context);

    final imageUrl = movie.backdropPath ?? movie.posterPath;
    final baseUrl = buildImageUrl(tmdbBaseImageUrl, proxyUrl, isProxy, context);

    final parsedReleaseDate = movie.releaseDate != null && movie.releaseDate!.isNotEmpty
        ? DateTime.tryParse(movie.releaseDate!)
        : null;

    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: pinned media card ──────────────────────────────────────
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 12, 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl == null
                          ? ColoredBox(
                              color: _C.bgSurfaceDark,
                              child: Icon(Icons.movie_outlined,
                                  size: 64, color: iconBg),
                            )
                          : CachedNetworkImage(
                              cacheManager: cacheProp(),
                              imageUrl: baseUrl +
                                  (movie.backdropPath != null
                                      ? 'original/${movie.backdropPath}'
                                      : imageQuality + movie.posterPath!),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => ColoredBox(
                                color: _C.bgSurfaceDark,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: _C.primary),
                                ),
                              ),
                              errorWidget: (_, __, ___) => ColoredBox(
                                color: _C.bgSurfaceDark,
                                child: Icon(Icons.broken_image_outlined,
                                    size: 56, color: iconBg),
                              ),
                            ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _GlassButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.pop(context),
                          iconBg: iconBg,
                          border: border,
                          textColor: textPrim,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _GlassButton(
                          icon: Icons.share_rounded,
                          onTap: () => _shareMovie(context),
                          iconBg: iconBg,
                          border: border,
                          textColor: textPrim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Right: title + ratings + watch-now + synopsis + cast + more ─
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 24, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: heroId,
                            child: Material(
                              type: MaterialType.transparency,
                              child: Text(
                                parsedReleaseDate != null
                                    ? '${movie.title} (${parsedReleaseDate.year})'
                                    : movie.title ?? '—',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: textPrim,
                                  height: 1.2,
                                  letterSpacing: 0.2,
                                  fontFamily: 'PoppinsSB',
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isWatched) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.green, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Watched',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    MovieDetailOptions(movie: movie),
                    if (parsedReleaseDate != null &&
                        appDep.displayWatchNowButton &&
                        parsedReleaseDate.isBefore(DateTime.now()))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: WatchNowButton(
                            releaseYear: parsedReleaseDate.year,
                            movieId: movie.id!,
                            movieName: movie.title,
                            adult: movie.adult,
                            posterPath: movie.posterPath,
                            backdropPath: movie.backdropPath,
                            api: Endpoints.movieDetailsUrl(movie.id!, lang),
                            releaseDate: movie.releaseDate,
                          ),
                        ),
                      ),
                    MovieAbout(movie: movie, scrollable: false),
                    if (appDep.enableBannerAds)
                      Builder(
                        builder: (context) {
                          final bannerAds = appDep.initialAds
                              .where((a) =>
                                  a.matchesPlacement('banner') ||
                                  a.matchesPlacement('ultra'))
                              .toList();
                          if (bannerAds.isEmpty) return const SizedBox.shrink();
                          return NativeAdBanner(
                            ad: bannerAds.first,
                            type: NativeAdBannerType.ultra,
                          );
                        },
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    required this.iconBg,
    required this.border,
    required this.textColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconBg;
  final Color border;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: iconBg,
          border: Border.all(color: border, width: 1),
        ),
        child: Icon(icon, size: 20, color: textColor),
      ),
    );
  }
}

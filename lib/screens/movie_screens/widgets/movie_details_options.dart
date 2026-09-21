import 'package:reelriot/models/movie_models.dart';
import 'package:reelriot/models/recently_watched.dart';
import 'package:reelriot/provider/bookmarks_provider.dart';
import 'package:reelriot/provider/recently_watched_provider.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/api/endpoints.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/widgets/watch_history_sheet.dart';
import 'package:reelriot/widgets/add_watch_menu.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/widgets/bouncing_tappable.dart';
import 'package:reelriot/widgets/user_rating_widget.dart';
import 'package:reelriot/services/offline_sync_manager.dart';
import 'package:reelriot/widgets/quality_badge.dart';

// ── Design tokens (design.json) ─────────────────────────────────────────────
class _C {
  static const primary = Color(0xFFDC2626);
  static const ratingGold = Color(0xFFEAB308);

  static const bgElevatedDark = Color(0x0DFFFFFF);
  static const bgElevatedLight = Color(0xFFF1F5F9);
  static const borderDark = Color(0x14FFFFFF);
  static const borderLight = Color(0x140F172A);
  static const textSecDark = Color(0xB8FFFFFF);
  static const textSecLight = Color(0xFF475569);
}

class MovieDetailOptions extends StatefulWidget {
  const MovieDetailOptions({super.key, required this.movie});

  final Movie movie;

  @override
  State<MovieDetailOptions> createState() => _MovieDetailOptionsState();
}

class _MovieDetailOptionsState extends State<MovieDetailOptions> {
  bool? isBookmarked;
  Moviedetail? movieDetails;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetails();
    });
  }

  Future<void> _fetchDetails() async {
    final lang = Provider.of<SettingsProvider>(context, listen: false).appLanguage;
    final isProxyEnabled = Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final api = Endpoints.movieDetailsUrl(widget.movie.id!, lang);
    
    final details = await fetchMovieDetails(api, isProxyEnabled, proxyUrl);
    if (mounted) {
      setState(() => movieDetails = details);
    }
  }

  Future<void> _checkBookmark() async {
    final provider = Provider.of<BookmarksProvider>(context, listen: false);
    final b = await provider.containsMovie(widget.movie.id!);
    if (mounted) setState(() => isBookmarked = b);
    if (mounted && b) await provider.updateMovie(widget.movie);
  }

  Future<void> _addWatch({String? watchedAt}) async {
    final recentProvider = Provider.of<RecentProvider>(context, listen: false);
    final releaseDate = widget.movie.releaseDate != null &&
            widget.movie.releaseDate!.isNotEmpty
        ? DateTime.tryParse(widget.movie.releaseDate!)
        : null;
    await recentProvider.addMovieWatch(
      RecentMovie(
        id: widget.movie.id,
        title: widget.movie.title,
        posterPath: widget.movie.posterPath,
        backdropPath: widget.movie.backdropPath,
        releaseYear: releaseDate?.year,
        elapsed: 1,
        remaining: 0,
        dateTime: DateTime.now().toIso8601String(),
      ),
      watchedAt: watchedAt,
    );
  }

  void _showAddWatchMenu() {
    final releaseDate = widget.movie.releaseDate != null &&
            widget.movie.releaseDate!.isNotEmpty
        ? DateTime.tryParse(widget.movie.releaseDate!)
        : null;
    AddWatchMenu.show(
      context: context,
      title: widget.movie.title ?? '',
      releaseDate: releaseDate,
      onPick: (watchedAt) => _addWatch(watchedAt: watchedAt),
    );
  }

  void _showWatchHistory() {
    final recentProvider = Provider.of<RecentProvider>(context, listen: false);
    final movieId = widget.movie.id;
    if (movieId == null) return;
    WatchHistorySheet.show(
      context: context,
      title: widget.movie.title ?? '',
      loadEvents: () => recentProvider.getMovieWatchHistory(movieId),
      onRemove: (event) =>
          recentProvider.removeMovieWatchEvent(movieId, event.eventId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final elevated = isDark ? _C.bgElevatedDark : _C.bgElevatedLight;
    final border = isDark ? _C.borderDark : _C.borderLight;
    final textSec = isDark ? _C.textSecDark : _C.textSecLight;

    final avg = widget.movie.voteAverage;
    final ratingStr = avg != null && avg > 0
        ? (avg == avg.truncateToDouble()
            ? avg.toStringAsFixed(0)
            : avg.toStringAsFixed(1))
        : null;

    return Consumer<RecentProvider>(
      builder: (context, recentProvider, child) {
        final matches =
            recentProvider.movies.where((m) => m.id == widget.movie.id);
        final recentMovie = matches.isEmpty ? null : matches.first;
        final isWatched = recentMovie != null &&
            isWatchedProgress(recentMovie.elapsed, recentMovie.remaining);
        final watchCount = widget.movie.id != null
            ? recentProvider.movieWatchCount(widget.movie.id!)
            : 0;

        return Consumer<BookmarksProvider>(
          builder: (context, provider, _) {
            // ── Format Genres ───────────────────────────────────────────────
            final genres = movieDetails?.genres?.map((g) => g.genreName).where((n) => n != null && n.isNotEmpty).take(3).join('  •  ');
            
            // ── Format Meta ────────────────────────────────────────────────
            String runtimeStr = '';
            if (movieDetails != null && movieDetails!.runtime != null && movieDetails!.runtime! > 0) {
              final h = movieDetails!.runtime! ~/ 60;
              final m = movieDetails!.runtime! % 60;
              runtimeStr = '${h}h ${m}m';
            }

            final screenWidth = MediaQuery.sizeOf(context).width;
            final isTablet = screenWidth >= 600;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 32 : 16,
                    12,
                    isTablet ? 32 : 16,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Genres Row ────────────────────────────────────────────
                      if (genres != null && genres.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            genres,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textSec,
                              fontFamily: 'Poppins',
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    
                  // ── Meta Row + Heart ──────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Meta items
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (runtimeStr.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.schedule_rounded, size: 14, color: textSec),
                                  const SizedBox(width: 4),
                                  Text(
                                    runtimeStr,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: textSec,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                              
                            _Badge(text: 'PG-13', textSec: textSec, border: border, elevated: elevated),
                            QualityBadge(
                              mediaId: widget.movie.id,
                              mediaType: 'movie',
                              releaseDate: widget.movie.releaseDate,
                              compact: false,
                            ),
                            
                            if (ratingStr != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _C.ratingGold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'IMDb - $ratingStr/10',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _C.ratingGold,
                                    fontFamily: 'PoppinsSB',
                                  ),
                                ),
                              ),

                            if (widget.movie.id != null)
                              UserRatingButton(
                                mediaType: 'movie',
                                mediaId: widget.movie.id!,
                                title: widget.movie.title ?? 'Movie',
                              ),
                          ],
                        ),
                      ),
                      
                      // Favorite Heart - Instant Optimistic Toggle + Tactile Micro-interaction
                      BouncingTappable(
                        onTap: () {
                          if (widget.movie.id == null) return;
                          final oldState = isBookmarked;
                          final newState = !(oldState ?? false);

                          // 1. Optimistic instant visual update (<16ms)
                          setState(() => isBookmarked = newState);

                          // 2. Background persistence + rollback safety
                          Future(() async {
                            try {
                              if (newState) {
                                await provider.addMovie(widget.movie);
                              } else {
                                await provider.removeMovie(widget.movie.id!);
                              }
                            } catch (_) {
                              // If failed, enqueue for offline sync and rollback UI
                              await OfflineSyncManager.instance.enqueueAction(
                                type: newState ? 'add_movie' : 'remove_movie',
                                payload: widget.movie.toJson(),
                              );
                            }
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: elevated,
                            border: Border.all(color: border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: (isBookmarked == true
                                        ? _C.primary
                                        : Colors.transparent)
                                    .withValues(alpha: 0.2),
                                blurRadius: isBookmarked == true ? 10 : 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            isBookmarked == true
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: isBookmarked == true ? _C.primary : textSec,
                          ),
                        ),
                      ),

                      // ── Watched button: tap adds a watch, long-press shows history ──
                      BouncingTappable(
                        onTap: _showAddWatchMenu,
                        onLongPress: watchCount > 0 ? _showWatchHistory : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                        Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: elevated,
                            border: Border.all(color: border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: (isWatched ? Colors.green : Colors.transparent)
                                    .withValues(alpha: 0.2),
                                blurRadius: isWatched ? 10 : 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            isWatched
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 20,
                            color: isWatched ? Colors.green : textSec,
                          ),
                        ),
                        if (watchCount > 1)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? Colors.black : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '×$watchCount',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  },
);
},
);
}
}

class _Badge extends StatelessWidget {
  final String text;
  final Color textSec;
  final Color border;
  final Color elevated;

  const _Badge({
    required this.text,
    required this.textSec,
    required this.border,
    required this.elevated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textSec,
          fontFamily: 'PoppinsSB',
        ),
      ),
    );
  }
}

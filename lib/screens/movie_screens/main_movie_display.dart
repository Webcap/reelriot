import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/models/discovery_feed.dart';
import 'package:reelriot/models/live_tv.dart';
import 'package:reelriot/models/movie_models.dart';
import 'package:reelriot/models/movie_stream_metadata.dart';
import 'package:reelriot/models/recently_watched.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/provider/recently_watched_provider.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/provider/sign_in_provider.dart';
import 'package:reelriot/screens/common/update_screen.dart';
import 'package:reelriot/screens/movie_screens/movie_details.dart';
import 'package:reelriot/models/tv.dart';
import 'package:reelriot/screens/tv_screens/tv_detail_page.dart';
import 'package:reelriot/screens/movie_screens/widgets/genre_list_grid.dart';
import 'package:reelriot/screens/movie_screens/widgets/movies_from_watch_providers.dart';
import 'package:reelriot/screens/movie_screens/widgets/scrolling_movie_list.dart';
import 'package:reelriot/screens/tv_screens/live_event_screen.dart';
import 'package:reelriot/services/discovery_service.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/utils/flavor_config.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/utils/globals.dart';
import 'package:reelriot/utils/globlal_methods.dart';
import 'package:reelriot/utils/theme/textStyle.dart';
import 'package:reelriot/widgets/banner_ad_widget.dart';
import 'package:reelriot/widgets/shimmer_widget.dart';
import 'package:reelriot/widgets/unified_video_loader.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/utils/sports_helpers.dart';
import 'package:reelriot/screens/movie_screens/widgets/main_movie_list.dart';
import 'package:reelriot/widgets/mobile_context_menu.dart';
import 'package:reelriot/widgets/discovery_row_widget.dart';

// ── Design tokens (mirrors design.json / dash_screen tokens) ─────────────────
class _C {
  static const primary = Color(0xFFDC2626);
  static const primaryLight = Color(0xFFEF4444);
  static const secondary = Color(0xFF7C3AED);
  static const bgCanvasDark = Color(0xFF030712);
  static const bgSurfaceDark = Color(0xFF0B0F14);
  static const bgCanvasLight = Color(0xFFF8FAFC);
  static const textPrimDark = Color(0xFFFFFFFF);
  static const textPrimLight = Color(0xFF0B0F14);
  static const textSecDark = Color(0xB8FFFFFF);
  static const textSecLight = Color(0xFF64748B);
  static const borderDark = Color(0x14FFFFFF);
  static const borderLight = Color(0x140F172A);
}

// ── Sealed carousel slide type ────────────────────────────────────────────────

sealed class _HeroSlide {}

class _MovieSlide extends _HeroSlide {
  final Movie movie;
  _MovieSlide(this.movie);
}

class _SportsSlide extends _HeroSlide {
  final FeaturedEvent event;
  _SportsSlide(this.event);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main entry widget
// ─────────────────────────────────────────────────────────────────────────────

class MainMoviesDisplay extends StatefulWidget {
  const MainMoviesDisplay({super.key});

  @override
  State<MainMoviesDisplay> createState() => _MainMoviesDisplayState();
}

class _MainMoviesDisplayState extends State<MainMoviesDisplay>
    with AutomaticKeepAliveClientMixin {
  // Discovery feed (from Caffeine /v1/discovery)
  DiscoveryFeed? _feed;
  bool _feedLoaded = false;

  // Trending movies (resolved to Movie objects for nav)
  List<Movie>? _trendingMovies;

  // Hero carousel slides (merged movies + sports)
  List<_HeroSlide>? _heroSlides;

  // Carousel page indicator
  int _heroPage = 0;

  @override
  void initState() {
    super.initState();
    // defer to next frame so context providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final appDep = context.read<AppDependencyProvider>();
    final settings = context.read<SettingsProvider>();
    final signIn = context.read<SignInProvider>();

    // 1. Fetch sports if enabled (unconditionally on load & pull-to-refresh)
    if (appDep.displayOTTDrawer) {
      appDep.fetchSportsStreams().then((_) {
        if (mounted) _buildHeroSlides();
      });
    }

    // 2. Fetch discovery feed
    final feed = await DiscoveryService.instance.fetchHomeFeed(
      caffeineBaseUrl: appDep.caffeineAPIURL,
      userId: signIn.uid,
      mediaType: 'movie',
      region: settings.defaultCountry,
      platform: 'android',
      env: FlavorConfig.envName,
    );

    if (!mounted) return;

    if (feed != null) {
      setState(() {
        _feed = feed;
        _feedLoaded = true;
      });
      // Try to populate trending from the feed; fall back to TMDB if the
      // feed came back empty or has no trending row.
      _buildTrendingMovies(feed);
      if (feed.rows.isEmpty ||
          feed.rowByType(['trending', 'community', 'social', 'tmdb']) == null) {
        _loadTrendingFallback();
      }
    } else {
      // API unreachable — load trending from TMDB directly.
      setState(() => _feedLoaded = true);
      _loadTrendingFallback();
    }

    _buildHeroSlides();
  }

  // Build trending Movie list from discovery items (best-effort, no detail fetch)
  void _buildTrendingMovies(DiscoveryFeed feed) {
    final trendingRow = feed.rowByType(['trending', 'community', 'social', 'tmdb']);
    if (trendingRow == null || trendingRow.items.isEmpty) return;

    final movies = trendingRow.items.map((item) {
      return Movie(
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
    }).toList();

    if (mounted) setState(() => _trendingMovies = movies);
  }

  // Fallback: fetch trending from TMDB directly
  void _loadTrendingFallback() {
    final settings = context.read<SettingsProvider>();
    final appDep = context.read<AppDependencyProvider>();
    fetchMovies(
      '$tmdbApiBaseUrl/trending/movie/week?api_key=$tmdbApiKey'
          '&language=${settings.appLanguage}&include_adult=${settings.isAdult}',
      settings.enableProxy,
      appDep.tmdbProxy,
    ).then((movies) {
      if (mounted) {
        setState(() => _trendingMovies = movies);
        _buildHeroSlides();
      }
    }).catchError((_) {});
  }

  // Merge hero slides: featured sports events + featured / trending movies
  void _buildHeroSlides() {
    final appDep = context.read<AppDependencyProvider>();
    final movieSlides = <_MovieSlide>[];

    // 1. Extract featured movies from discovery feed
    if (_feed != null) {
      final featuredRow = _feed!.rowByType(['featured', 'holiday', 'dynamic', 'popular', 'social', 'tmdb']);
      if (featuredRow != null && featuredRow.items.isNotEmpty) {
        for (final item in featuredRow.items.take(10)) {
          movieSlides.add(_MovieSlide(Movie(
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
          )));
        }
      }
    }

    // 2. If discovery feed has no featured movies, fallback to trending movies
    if (movieSlides.isEmpty && _trendingMovies != null && _trendingMovies!.isNotEmpty) {
      for (final movie in _trendingMovies!.take(10)) {
        movieSlides.add(_MovieSlide(movie));
      }
    }

    final slides = <_HeroSlide>[];

    // 3. Inject featured sports slides when OTT/Sports is enabled
    if (appDep.displayOTTDrawer && appDep.featuredEvents.isNotEmpty) {
      final sportsSlides = appDep.featuredEvents
          .where((e) => !appDep.isSportRowHidden(e.sport, title: e.title))
          .take(3)
          .map((e) => _SportsSlide(e))
          .toList();
      slides.addAll(sportsSlides);
    }

    // 4. Append movies so the hero carousel features both sports and top movies
    slides.addAll(movieSlides);

    if (mounted) {
      setState(() => _heroSlides = slides);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final appDep = context.watch<AppDependencyProvider>();
    final lang = settings.appLanguage;
    final region = settings.defaultCountry;
    final includeAdult = settings.isAdult;
    final themeMode = settings.appTheme;
    final signIn = context.watch<SignInProvider>();
    final isSignedIn = signIn.isSignedIn;
    final rMovies = context.watch<RecentProvider>().continueWatchingMovies;

    // Re-build hero slides reactively when sports events load
    if (appDep.displayOTTDrawer &&
        appDep.featuredEvents.isNotEmpty &&
        (_heroSlides == null ||
            !_heroSlides!.any((s) => s is _SportsSlide))) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _buildHeroSlides());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _C.primary,
      backgroundColor: isDark ? _C.bgCanvasDark : _C.bgCanvasLight,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        children: [
          // ── 1. Hero carousel ─────────────────────────────────────────────────
          _HeroCarousel(
          slides: _heroSlides,
          feedLoaded: _feedLoaded,
          themeMode: themeMode,
          isDark: isDark,
          imageQuality: settings.imageQuality,
          isProxyEnabled: settings.enableProxy,
          proxyUrl: appDep.tmdbProxy,
          currentPage: _heroPage,
          onPageChanged: (i) => setState(() => _heroPage = i),
          // Fallback: when no discovery slides, show TMDB discover widget
          fallbackWidget: _DiscoverFallbackCarousel(
            includeAdult: includeAdult,
            discoverType: 'discover',
          ),
        ),

        const UpdateBottom(),

        // ── 2. Continue Watching ─────────────────────────────────────────────
        if (isSignedIn && rMovies.isNotEmpty)
          _ContinueWatchingRow(
            movies: rMovies,
            isDark: isDark,
            themeMode: themeMode,
            imageQuality: settings.imageQuality,
            isProxyEnabled: settings.enableProxy,
            proxyUrl: appDep.tmdbProxy,
            fetchRoute: appDep.fetchRoute,
          ),

        const BannerAdWidget(),

        // ── 3. Discovery Feed Rows or Fallback ───────────────────────────────
        if (_feedLoaded && _feed != null && _feed!.rows.any((r) => r.type != 'featured'))
          ..._feed!.rows.where((row) => row.type != 'featured').map((row) {
            return DiscoveryRowWidget(
              row: row,
              isDark: isDark,
              themeMode: themeMode,
              imageQuality: settings.imageQuality,
              isProxyEnabled: settings.enableProxy,
              proxyUrl: appDep.tmdbProxy,
              lang: lang,
              includeAdult: includeAdult,
            );
          })
        else ...[
          // ── Trending Now (discovery or TMDB fallback) ─────────────────────
          _TrendingNowRow(
            movies: _trendingMovies,
            isDark: isDark,
            themeMode: themeMode,
            imageQuality: settings.imageQuality,
            isProxyEnabled: settings.enableProxy,
            proxyUrl: appDep.tmdbProxy,
            lang: lang,
            includeAdult: includeAdult,
          ),

          // ── Remaining standard rows ───────────────────────────────────────
          ScrollingMovies(
            title: tr('popular'),
            api: '$tmdbApiBaseUrl/movie/popular?api_key=$tmdbApiKey&language=$lang',
            discoverType: 'popular',
            isTrending: false,
            includeAdult: includeAdult,
          ),
          ScrollingMovies(
            title: tr('top_rated'),
            api: '$tmdbApiBaseUrl/movie/top_rated?api_key=$tmdbApiKey&region=$region&language=$lang',
            discoverType: 'top_rated',
            isTrending: false,
            includeAdult: includeAdult,
          ),
          ScrollingMovies(
            title: tr('now_playing'),
            api: '$tmdbApiBaseUrl/movie/now_playing?api_key=$tmdbApiKey&language=$lang',
            discoverType: 'now_playing',
            isTrending: false,
            includeAdult: includeAdult,
          ),
          ScrollingMovies(
            title: tr('upcoming'),
            api: _upcomingUrl(lang, region),
            discoverType: 'upcoming',
            isTrending: false,
            includeAdult: includeAdult,
          ),
        ],

        GenreListGrid(
          api: '$tmdbApiBaseUrl/genre/movie/list?api_key=$tmdbApiKey&language=$lang',
        ),
        const MoviesFromWatchProviders(),
      ],
    ));
  }

  String _upcomingUrl(String lang, String region) {
    final regionParam = region.isNotEmpty ? '&region=$region' : '';
    return '$tmdbApiBaseUrl/movie/upcoming?api_key=$tmdbApiKey&language=$lang$regionParam';
  }

  @override
  bool get wantKeepAlive => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Hero carousel widget
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCarousel extends StatelessWidget {
  final List<_HeroSlide>? slides;
  final bool feedLoaded;
  final String themeMode;
  final bool isDark;
  final String imageQuality;
  final bool isProxyEnabled;
  final String proxyUrl;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final Widget fallbackWidget;

  const _HeroCarousel({
    required this.slides,
    required this.feedLoaded,
    required this.themeMode,
    required this.isDark,
    required this.imageQuality,
    required this.isProxyEnabled,
    required this.proxyUrl,
    required this.currentPage,
    required this.onPageChanged,
    required this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 1000;
    final double carouselHeight = isLargeTablet ? 380.0 : (isTablet ? 340.0 : 230.0);
    final double viewportFraction = isLargeTablet ? 0.94 : (isTablet ? 0.92 : 0.88);

    // Loading
    if (!feedLoaded || slides == null) {
      return Column(
        children: [
          SizedBox(
            height: carouselHeight,
            child: discoverMoviesAndTVShimmer(themeMode),
          ),
        ],
      );
    }

    // No discovery slides — show the legacy TMDB carousel
    if (slides!.isEmpty) return fallbackWidget;

    final slideList = slides!;

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: slideList.length,
          options: CarouselOptions(
            height: carouselHeight,
            viewportFraction: viewportFraction,
            enlargeCenterPage: true,
            enlargeFactor: isTablet ? 0.12 : 0.10,
            enableInfiniteScroll: slideList.length > 2,
            autoPlay: slideList.length > 1,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayCurve: Curves.easeInOut,
            onPageChanged: (i, _) => onPageChanged(i),
          ),
          itemBuilder: (context, index, _) {
            final slide = slideList[index];
            if (slide is _SportsSlide) {
              return _SportHeroSlide(event: slide.event, isTablet: isTablet);
            }
            final movie = (slide as _MovieSlide).movie;
            return _MovieHeroSlide(
              movie: movie,
              heroId: 'hero-${movie.id}-$index',
              themeMode: themeMode,
              imageQuality: imageQuality,
              isProxyEnabled: isProxyEnabled,
              proxyUrl: proxyUrl,
              isTablet: isTablet,
            );
          },
        ),
        const SizedBox(height: 10),
        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slideList.length, (i) {
            final active = i == currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? (isTablet ? 26 : 20) : (isTablet ? 8 : 6),
              height: isTablet ? 8 : 6,
              decoration: BoxDecoration(
                color: active
                    ? _C.primary
                    : (isDark ? Colors.white30 : Colors.black26),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cinematic Movie Hero Slide
// ─────────────────────────────────────────────────────────────────────────────

class _MovieHeroSlide extends StatelessWidget {
  final Movie movie;
  final String heroId;
  final String themeMode;
  final String imageQuality;
  final bool isProxyEnabled;
  final String proxyUrl;
  final bool isTablet;

  const _MovieHeroSlide({
    required this.movie,
    required this.heroId,
    required this.themeMode,
    required this.imageQuality,
    required this.isProxyEnabled,
    required this.proxyUrl,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final imgBase = buildImageUrl(tmdbBaseImageUrl, proxyUrl, isProxyEnabled, context);
    // Prioritize 16:9 landscape backdrop
    final backdropUrl = (movie.backdropPath != null && movie.backdropPath!.isNotEmpty)
        ? '$imgBase$imageQuality${movie.backdropPath}'
        : (movie.posterPath != null && movie.posterPath!.isNotEmpty
            ? '$imgBase$imageQuality${movie.posterPath}'
            : '');

    final releaseYear = movie.releaseDate != null && movie.releaseDate!.length >= 4
        ? movie.releaseDate!.substring(0, 4)
        : '';
    final rating = movie.voteAverage != null && movie.voteAverage! > 0
        ? movie.voteAverage!.toStringAsFixed(1)
        : '';
    final overview = movie.overview?.trim() ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailPage(
            movie: movie,
            heroId: heroId,
          ),
        ),
      ),
      child: Hero(
        tag: heroId,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Backdrop image
              backdropUrl.isEmpty
                  ? Image.asset('assets/images/na_logo.png', fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: backdropUrl,
                      fit: BoxFit.cover,
                      cacheManager: cacheProp(),
                      placeholder: (_, __) => discoverImageShimmer(themeMode),
                      errorWidget: (_, __, ___) => Image.asset(
                        'assets/images/na_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),

              // 2. Multi-layer Dark Gradient for high readability & depth
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: isTablet ? 0.45 : 0.4),
                        Colors.black.withValues(alpha: isTablet ? 0.92 : 0.88),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              if (isTablet)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.82),
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),

              // 3. Foreground Content (Badges + Title + Metadata + Overview + Buttons)
              Positioned(
                left: isTablet ? 24 : 16,
                right: isTablet ? 24 : 16,
                bottom: isTablet ? 22 : 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge: FEATURED + Rating + Year
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 10 : 8,
                            vertical: isTablet ? 4 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: _C.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _C.primary.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isTablet ? 7 : 6,
                                height: isTablet ? 7 : 6,
                                decoration: const BoxDecoration(
                                  color: _C.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: isTablet ? 6 : 5),
                              Text(
                                'FEATURED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 11 : 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (rating.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 8 : 6,
                              vertical: isTablet ? 4 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFACC15).withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: isTablet ? 14 : 12,
                                  color: const Color(0xFFFACC15),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTablet ? 11 : 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (releaseYear.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            releaseYear,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isTablet ? 12 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: isTablet ? 8 : 6),

                    // Title
                    Text(
                      movie.title ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 26 : 18,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'PoppinsSB',
                        letterSpacing: -0.3,
                        shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Overview on tablets / larger screens
                    if (isTablet && overview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Text(
                          overview,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    // Action buttons (Watch Now + Details)
                    if (isTablet) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _C.primary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _C.primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Watch Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white30,
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline_rounded, color: Colors.white, size: 17),
                                SizedBox(width: 6),
                                Text(
                                  'Details',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sports hero slide
class _SportHeroSlide extends StatelessWidget {
  final FeaturedEvent event;
  final bool isTablet;
  const _SportHeroSlide({required this.event, this.isTablet = false});

  @override
  Widget build(BuildContext context) {
    final theme = resolveSportTheme(
      sport: event.sport,
      title: event.title,
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveEventScreen(
            event: StreameastEvent(
              id: event.id,
              title: event.title,
              url: '',
              logoUrl: event.thumbnailUrl,
              sport: event.sport,
            ),
            videoUrl: event.videoUrl,
            referrer: event.referrer ?? '',
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          gradient: LinearGradient(
            colors: theme.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: theme.accentColor.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.accentColor.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isTablet ? 19 : 15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background thumbnail (if available)
              if (event.thumbnailUrl.isNotEmpty)
                Opacity(
                  opacity: 0.25,
                  child: CachedNetworkImage(
                    imageUrl: event.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

              // Sport watermark silhouette on the right
              Positioned(
                right: -10,
                bottom: -15,
                child: Opacity(
                  opacity: 0.12,
                  child: Icon(
                    theme.icon,
                    size: isTablet ? 200 : 150,
                    color: Colors.white,
                  ),
                ),
              ),

              // Dark gradient overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // LIVE badge + title + tag + action button
              Positioned(
                left: isTablet ? 24 : 16,
                right: isTablet ? 24 : 16,
                bottom: isTablet ? 22 : 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 10 : 8,
                            vertical: isTablet ? 4 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.accentColor.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isTablet ? 8 : 6,
                                height: isTablet ? 8 : 6,
                                decoration: BoxDecoration(
                                  color: theme.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: isTablet ? 7 : 5),
                              Text(
                                '${theme.label} · LIVE NOW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 12 : 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 24 : 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'PoppinsSB',
                        shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isTablet) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.accentColor.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Watch Stream',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Continue Watching row (wide landscape cards)
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueWatchingRow extends StatefulWidget {
  final List<RecentMovie> movies;
  final bool isDark;
  final String themeMode;
  final String imageQuality;
  final bool isProxyEnabled;
  final String proxyUrl;
  final String fetchRoute;

  const _ContinueWatchingRow({
    required this.movies,
    required this.isDark,
    required this.themeMode,
    required this.imageQuality,
    required this.isProxyEnabled,
    required this.proxyUrl,
    required this.fetchRoute,
  });

  @override
  State<_ContinueWatchingRow> createState() => _ContinueWatchingRowState();
}

class _ContinueWatchingRowState extends State<_ContinueWatchingRow> {
  bool _lockTap = false;

  void _suppressTap() {
    setState(() => _lockTap = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _lockTap = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPrim = widget.isDark ? _C.textPrimDark : _C.textPrimLight;
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final cardWidth = isTablet ? 250.0 : 200.0;
    final cardHeight = isTablet ? 155.0 : 130.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: EdgeInsets.fromLTRB(isTablet ? 20 : 16, 8, isTablet ? 20 : 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _C.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr('recently_watched'),
                style: TextStyle(
                  fontSize: isTablet ? 19 : 17,
                  fontWeight: FontWeight.w700,
                  color: textPrim,
                  fontFamily: 'PoppinsSB',
                ),
              ),
            ],
          ),
        ),

        // Wide cards horizontal list
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 12),
            itemCount: widget.movies.length,
            itemBuilder: (context, index) {
              final movie = widget.movies[index];
              final isFirst = index == 0;

              final imgBase = buildImageUrl(
                tmdbBaseImageUrl,
                widget.proxyUrl,
                widget.isProxyEnabled,
                context,
              );
              final imageUrl = movie.backdropPath != null
                  ? '$imgBase${widget.imageQuality}${movie.backdropPath}'
                  : (movie.posterPath != null
                      ? '$imgBase${widget.imageQuality}${movie.posterPath}'
                      : '');

              return Padding(
                padding: EdgeInsets.only(right: isTablet ? 14 : 10),
                child: GestureDetector(
                  onLongPress: () {
                    _suppressTap();
                    final prv =
                        context.read<RecentProvider>();
                    MobileContextMenu.show(
                      context: context,
                      title: movie.title ?? '',
                      subtitle: '${movie.releaseYear}',
                      items: [
                        MobileContextMenuItem(
                          label: tr('mark_as_completed'),
                          icon: Icons.check_circle_outline,
                          onTap: () => prv.markMovieAsCompleted(movie),
                        ),
                        MobileContextMenuItem(
                          label: tr('remove_from_history'),
                          icon: Icons.delete_outline,
                          color: Colors.red,
                          onTap: () => prv.deleteMovie(movie.id!),
                        ),
                      ],
                    );
                  },
                  onTap: () {
                    if (_lockTap) return;
                    if (Provider.of<AppDependencyProvider>(context,
                            listen: false)
                        .displayWatchNowButton) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UnifiedVideoLoader(
                            mediaType: MediaType.movie,
                            download: false,
                            route: widget.fetchRoute == 'flixHQ'
                                ? StreamRoute.flixHQ
                                : StreamRoute.tmDB,
                            movieMetadata: MovieStreamMetadata(
                              backdropPath: movie.backdropPath,
                              elapsed: movie.elapsed,
                              isAdult: null,
                              movieId: movie.id,
                              movieName: movie.title,
                              posterPath: movie.posterPath,
                              releaseYear: movie.releaseYear,
                              releaseDate: null,
                            ),
                          ),
                        ),
                      );
                    } else {
                      GlobalMethods.showCustomScaffoldMessage(
                        SnackBar(
                          content: Text(
                            tr('check_connection'),
                            style: kTextSmallBodyStyle,
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                        context,
                      );
                    }
                  },
                  child: SizedBox(
                    width: cardWidth,
                    child: Stack(
                      children: [
                        // Backdrop/poster image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                          child: imageUrl.isEmpty
                              ? Image.asset(
                                  'assets/images/na_logo.png',
                                  width: cardWidth,
                                  height: cardHeight,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  cacheManager: cacheProp(),
                                  imageUrl: imageUrl,
                                  width: cardWidth,
                                  height: cardHeight,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      scrollingImageShimmer(widget.themeMode),
                                  errorWidget: (_, __, ___) => Image.asset(
                                    'assets/images/na_logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                        // Dark gradient overlay — must be direct Stack child (not inside ClipRRect)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.72),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // "Recommend" badge on first item
                        if (isFirst)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: _C.secondary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Recommend',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        // Play icon overlay
                        Center(
                          child: Container(
                            width: isTablet ? 44 : 36,
                            height: isTablet ? 44 : 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white54, width: 1.5),
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: isTablet ? 26 : 22,
                            ),
                          ),
                        ),
                        // Title + progress bar at bottom
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie.title ?? '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 13 : 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'PoppinsSB',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                child: SizedBox(
                                  height: 3,
                                  child: LinearProgressIndicator(
                                    value: (movie.elapsed ?? 0) /
                                        ((movie.elapsed ?? 0) +
                                                (movie.remaining ?? 1))
                                            .clamp(1, double.infinity),
                                    backgroundColor: Colors.white24,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            _C.primary),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
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
        const SizedBox(height: 16),
        Divider(
          color: widget.isDark ? Colors.white12 : Colors.black12,
          thickness: 1,
          endIndent: isTablet ? 24 : 20,
          indent: isTablet ? 24 : 10,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Trending Now row (compact poster cards with rating + runtime)
// ─────────────────────────────────────────────────────────────────────────────

class _TrendingNowRow extends StatelessWidget {
  final List<Movie>? movies;
  final bool isDark;
  final String themeMode;
  final String imageQuality;
  final bool isProxyEnabled;
  final String proxyUrl;
  final String lang;
  final bool includeAdult;

  const _TrendingNowRow({
    required this.movies,
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
    final textPrim = isDark ? _C.textPrimDark : _C.textPrimLight;
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final cardWidth = isTablet ? 140.0 : 115.0;
    final posterHeight = cardWidth * 1.5; // True 2:3 cinematic poster ratio
    final rowHeight = posterHeight + (isTablet ? 48.0 : 40.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: EdgeInsets.fromLTRB(isTablet ? 20 : 16, 8, isTablet ? 20 : 8, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('trending_this_week'),
                    style: TextStyle(
                      fontSize: isTablet ? 19 : 17,
                      fontWeight: FontWeight.w700,
                      color: textPrim,
                      fontFamily: 'PoppinsSB',
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: movies == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MainMoviesList(
                              title: tr('trending_this_week'),
                              api:
                                  '$tmdbApiBaseUrl/trending/movie/week?api_key=$tmdbApiKey&language=$lang',
                              includeAdult: includeAdult,
                              discoverType: 'Trending',
                              isTrending: true,
                            ),
                          ),
                        ),
                style: TextButton.styleFrom(
                  foregroundColor: _C.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  tr('view_all'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 14 : 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Cards (2:3 true aspect ratio)
        SizedBox(
          height: rowHeight,
          child: movies == null
              ? scrollingMoviesAndTVShimmer(themeMode)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 12),
                  itemCount: movies!.length,
                  itemBuilder: (context, index) {
                    final movie = movies![index];
                    final imgBase = buildImageUrl(
                        tmdbBaseImageUrl, proxyUrl, isProxyEnabled, context);
                    final posterUrl = movie.posterPath != null
                        ? '$imgBase$imageQuality${movie.posterPath}'
                        : '';

                    return Padding(
                      padding: EdgeInsets.only(right: isTablet ? 14 : 10),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MovieDetailPage(
                              movie: movie,
                              heroId: 'trending-${movie.id}-$index',
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: cardWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Poster with 2:3 aspect ratio & rating badge
                              SizedBox(
                                width: cardWidth,
                                height: posterHeight,
                                child: Hero(
                                  tag: 'trending-${movie.id}-$index',
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(isTablet ? 12 : 10),
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
                                                    scrollingImageShimmer(
                                                        themeMode),
                                                errorWidget: (_, __, ___) =>
                                                    Image.asset(
                                                  'assets/images/na_logo.png',
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                      ),
                                      // Star rating badge (top-left)
                                      if (movie.voteAverage != null)
                                        Positioned(
                                          top: 6,
                                          left: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                  alpha: 0.65),
                                              borderRadius:
                                                  BorderRadius.circular(6),
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
                                                  movie.voteAverage!
                                                      .toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w700,
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
                                padding:
                                    const EdgeInsets.fromLTRB(2, 6, 2, 0),
                                child: Text(
                                  movie.title ?? '',
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

// ─────────────────────────────────────────────────────────────────────────────
// Legacy TMDB carousel fallback (used when discovery API is unavailable)
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverFallbackCarousel extends StatefulWidget {
  final bool includeAdult;
  final String discoverType;

  const _DiscoverFallbackCarousel({
    required this.includeAdult,
    required this.discoverType,
  });

  @override
  State<_DiscoverFallbackCarousel> createState() =>
      _DiscoverFallbackCarouselState();
}

class _DiscoverFallbackCarouselState
    extends State<_DiscoverFallbackCarousel>
    with AutomaticKeepAliveClientMixin {
  List<Movie>? _movies;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final settings = context.read<SettingsProvider>();
    final appDep = context.read<AppDependencyProvider>();
    final lang = settings.appLanguage;
    final region = settings.defaultCountry;
    fetchMovies(
      '$tmdbApiBaseUrl/discover/movie?api_key=$tmdbApiKey'
          '&language=$lang&sort_by=popularity.desc'
          '&watch_region=$region&include_adult=${widget.includeAdult}',
      settings.enableProxy,
      appDep.tmdbProxy,
    ).then((v) {
      if (mounted) setState(() => _movies = v);
    }).catchError((_) {
      if (mounted) setState(() => _movies = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = context.watch<SettingsProvider>();
    final appDep = context.watch<AppDependencyProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = settings.appTheme;
    final imageQuality = settings.imageQuality;
    final isProxyEnabled = settings.enableProxy;
    final proxyUrl = appDep.tmdbProxy;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 1000;
    final double carouselHeight = isLargeTablet ? 380.0 : (isTablet ? 340.0 : 230.0);
    final double viewportFraction = isLargeTablet ? 0.94 : (isTablet ? 0.92 : 0.88);

    if (_movies == null) {
      return SizedBox(height: carouselHeight, child: discoverMoviesAndTVShimmer(themeMode));
    }
    final sportsSlides = (appDep.displayOTTDrawer && appDep.featuredEvents.isNotEmpty)
        ? appDep.featuredEvents
            .where((e) => !appDep.isSportRowHidden(e.sport, title: e.title))
            .take(3)
            .toList()
        : <FeaturedEvent>[];

    final moviesList = _movies!.take(8).toList();
    final totalCount = sportsSlides.length + moviesList.length;

    if (totalCount == 0) return const SizedBox.shrink();

    return Column(
      children: [
        CarouselSlider.builder(
          options: CarouselOptions(
            height: carouselHeight,
            viewportFraction: viewportFraction,
            enlargeCenterPage: true,
            enlargeFactor: isTablet ? 0.12 : 0.10,
            enableInfiniteScroll: totalCount > 2,
            autoPlay: totalCount > 1,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayCurve: Curves.easeInOut,
            onPageChanged: (i, _) => setState(() => _currentPage = i),
          ),
          itemCount: totalCount,
          itemBuilder: (context, index, _) {
            if (index < sportsSlides.length) {
              return _SportHeroSlide(
                event: sportsSlides[index],
                isTablet: isTablet,
              );
            }
            final movie = moviesList[index - sportsSlides.length];
            return _MovieHeroSlide(
              movie: movie,
              heroId: 'fbhero-${movie.id}-$index',
              themeMode: themeMode,
              imageQuality: imageQuality,
              isProxyEnabled: isProxyEnabled,
              proxyUrl: proxyUrl,
              isTablet: isTablet,
            );
          },
        ),
        const SizedBox(height: 10),
        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalCount, (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? (isTablet ? 26 : 20) : (isTablet ? 8 : 6),
              height: isTablet ? 8 : 6,
              decoration: BoxDecoration(
                color: active
                    ? _C.primary
                    : (isDark ? Colors.white30 : Colors.black26),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}



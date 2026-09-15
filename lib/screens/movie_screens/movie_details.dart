import 'package:flutter/material.dart';
import 'package:reelriot/api/endpoints.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/models/movie_models.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/screens/movie_screens/widgets/movie_about.dart';
import 'package:reelriot/screens/movie_screens/widgets/movie_detail_expanded_layout.dart';
import 'package:reelriot/screens/movie_screens/widgets/movie_detail_quick_info.dart';
import 'package:reelriot/screens/movie_screens/widgets/movie_details_options.dart';
import 'package:reelriot/widgets/watch_now_button.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/widgets/native_ad_banner.dart';

// ── Design tokens (design.json) ─────────────────────────────────────────────
class _C {
  static const bgCanvasDark = Color(0xFF030712);
  static const bgCanvasLight = Color(0xFFF8FAFC);
}

class MovieDetailPage extends StatefulWidget {
  final Movie movie;
  final String heroId;

  const MovieDetailPage({
    super.key,
    required this.movie,
    required this.heroId,
  });

  @override
  MovieDetailPageState createState() => MovieDetailPageState();
}

class MovieDetailPageState extends State<MovieDetailPage>
    with AutomaticKeepAliveClientMixin<MovieDetailPage> {
  final _scrollController = ScrollController();
  final _videosKey = GlobalKey();
  late Movie _movie;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFullDetailsIfNeeded();
    });
  }

  Future<void> _loadFullDetailsIfNeeded() async {
    if (_movie.id == null) return;
    if (_movie.overview == null ||
        _movie.overview!.isEmpty ||
        _movie.backdropPath == null ||
        _movie.releaseDate == null ||
        _movie.voteAverage == null) {
      final lang = Provider.of<SettingsProvider>(context, listen: false).appLanguage;
      final isProxy = Provider.of<SettingsProvider>(context, listen: false).enableProxy;
      final proxyUrl = Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
      final api = Endpoints.movieDetailsUrl(_movie.id!, lang);
      try {
        final fullMovie = await getMovie(api, isProxy, proxyUrl);
        if (mounted) {
          setState(() {
            _movie = fullMovie;
          });
        }
      } catch (e) {
        debugPrint('[MovieDetailPage] Error fetching full details: $e');
      }
    }
  }

  void _scrollToVideos() {
    final ctx = context;
    final key = _videosKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    final appDep = Provider.of<AppDependencyProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _C.bgCanvasDark : _C.bgCanvasLight;

    final parsedReleaseDate = _movie.releaseDate != null && _movie.releaseDate!.isNotEmpty
        ? DateTime.tryParse(_movie.releaseDate!)
        : null;

    final isExpanded = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      backgroundColor: bg,
      body: isExpanded
          ? MovieDetailExpandedLayout(
              movie: _movie,
              heroId: widget.heroId,
              onTrailerTap: _scrollToVideos,
            )
          : CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero poster + overlay controls + trailer chip ─────────────
          SliverToBoxAdapter(
            child: MovieDetailQuickInfo(
              heroId: widget.heroId,
              movie: _movie,
              onTrailerTap: _scrollToVideos,
            ),
          ),

          // ── Compact ratings + favorite heart ────────────────────────
          SliverToBoxAdapter(
            child: MovieDetailOptions(movie: _movie),
          ),

          // ── Full-width "Watch now" pill (primary CTA) ───────────────
          if (parsedReleaseDate != null &&
              appDep.displayWatchNowButton &&
              parsedReleaseDate.isBefore(DateTime.now()))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: WatchNowButton(
                        releaseYear: parsedReleaseDate.year,
                        movieId: _movie.id!,
                        movieName: _movie.title,
                        adult: _movie.adult,
                        posterPath: _movie.posterPath,
                        backdropPath: _movie.backdropPath,
                        api: Endpoints.movieDetailsUrl(_movie.id!, lang),
                        releaseDate: _movie.releaseDate,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Synopsis + content ─────────────────────────────────────
          SliverToBoxAdapter(
            child: MovieAbout(
              movie: _movie,
              videosKey: _videosKey,
            ),
          ),

          // ── Native Ultra Banner Ad ──────────────────────────────────
          if (appDep.enableBannerAds)
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final bannerAds = appDep.initialAds.where((a) => a.matchesPlacement('banner') || a.matchesPlacement('ultra')).toList();
                  if (bannerAds.isEmpty) return const SizedBox.shrink();
                  
                  return NativeAdBanner(
                    ad: bannerAds.first,
                    type: NativeAdBannerType.ultra,
                  );
                }
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

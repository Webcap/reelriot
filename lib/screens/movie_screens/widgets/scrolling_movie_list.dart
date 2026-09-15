import 'package:cached_network_image/cached_network_image.dart';
import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/widgets/common_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:reelriot/models/movie_models.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/screens/movie_screens/widgets/main_movie_list.dart';
import 'package:reelriot/screens/movie_screens/movie_details.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/widgets/shimmer_widget.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/models/ad.dart';
import 'package:reelriot/widgets/native_ad_poster_card.dart';
import 'package:reelriot/widgets/quality_badge.dart';

class ScrollingMovies extends StatefulWidget {
  final String api, title;
  final dynamic discoverType;
  final bool isTrending;
  final bool? includeAdult;

  const ScrollingMovies({
    super.key,
    required this.api,
    required this.title,
    this.discoverType,
    required this.isTrending,
    required this.includeAdult,
  });
  @override
  ScrollingMoviesState createState() => ScrollingMoviesState();
}

class ScrollingMoviesState extends State<ScrollingMovies>
    with AutomaticKeepAliveClientMixin {
  late int index;
  List<Movie>? moviesList;
  final ScrollController _scrollController = ScrollController();

  int pageNum = 2;
  bool isLoading = false;

  void getMoreData() async {
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        setState(() {
          isLoading = true;
        });
        if (mounted) {
          fetchMovies(
                  '${widget.api}&include_adult=${widget.includeAdult}&page=$pageNum',
                  isProxyEnabled,
                  proxyUrl)
              .then((value) {
            if (mounted) {
              setState(() {
                final existingIds = moviesList!.map((m) => m.id).toSet();
                final newMovies = value
                    .where((m) => !existingIds.contains(m.id))
                    .toList();
                moviesList!.addAll(newMovies);
                isLoading = false;
                pageNum++;
              });
            }
          });
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchMovies('${widget.api}&include_adult=${widget.includeAdult}',
            isProxyEnabled, proxyUrl)
        .then((value) {
      if (mounted) {
        setState(() {
          moviesList = value;
        });
      }
    }).catchError((e) {
      debugPrint('[ScrollingMovies] Error fetching \${widget.api}: $e');
      if (mounted) setState(() => moviesList = []);
    });
    getMoreData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final cardWidth = isTablet ? 140.0 : 115.0;
    final posterHeight = cardWidth * 1.5;
    final rowHeight = posterHeight + (isTablet ? 56.0 : 48.0);
    if (moviesList != null && moviesList!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const LeadingDot(),
                    Expanded(
                      child: Text(widget.title,
                          style: kTextHeaderStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return MainMoviesList(
                        title: widget.title,
                        api: widget.api,
                        includeAdult: widget.includeAdult,
                        discoverType: widget.discoverType.toString(),
                        isTrending: widget.isTrending,
                      );
                    }));
                  },
                  style: ButtonStyle(
                      maximumSize: WidgetStateProperty.all(const Size(200, 60)),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ))),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    child: Text(tr("view_all")),
                  ),
                )),
          ],
        ),
        SizedBox(
          width: double.infinity,
          height: rowHeight,
          child: moviesList == null || widget.includeAdult == null
              ? scrollingMoviesAndTVShimmer(themeMode)
              : Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 8),
                        itemCount: (() {
                          final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
                          final hasAd = appDep.enablePosterAds && appDep.initialAds.any((a) => a.matchesPlacement('poster'));
                          return moviesList!.length + (hasAd ? 1 : 0);
                        })(),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (BuildContext context, int index) {
                          final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
                          final posterAds = appDep.enablePosterAds
                              ? appDep.initialAds.where((a) => a.matchesPlacement('poster')).toList()
                              : <Ad>[];
                          final hasAd = posterAds.isNotEmpty;
                          
                          int adPos = 5;
                          if (widget.title.toLowerCase().contains('trending')) adPos = 3;
                          if (widget.title.toLowerCase().contains('popular')) adPos = 1;

                          if (hasAd && index == adPos) {
                            final adIndex = widget.title.hashCode.abs() % posterAds.length;
                            return NativeAdPosterCard(ad: posterAds[adIndex]);
                          }

                          final movieIndex = (hasAd && index > adPos) ? index - 1 : index;
                          if (movieIndex >= moviesList!.length) return const SizedBox.shrink();
                          
                          final movie = moviesList![movieIndex];

                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 6.0 : 4.0,
                              vertical: 2.0,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => MovieDetailPage(
                                            movie: movie,
                                            heroId:
                                                '${movie.id}-${widget.title}-${widget.discoverType}-$index')));
                              },
                              child: SizedBox(
                                width: cardWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    SizedBox(
                                      width: cardWidth,
                                      height: posterHeight,
                                      child: Hero(
                                        tag:
                                            '${movie.id}-${widget.title}-${widget.discoverType}-$index',
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(isTablet ? 12.0 : 8.0),
                                                child: movie.posterPath == null
                                                    ? Image.asset(
                                                        'assets/images/na_logo.png',
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: double.infinity)
                                                    : CachedNetworkImage(
                                                        cacheManager:
                                                            cacheProp(),
                                                        fadeOutDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    300),
                                                        fadeOutCurve:
                                                            Curves.easeOut,
                                                        fadeInDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    700),
                                                        fadeInCurve:
                                                            Curves.easeIn,
                                                        imageUrl: movie.posterPath == null
                                                            ? ''
                                                            : buildImageUrl(
                                                                    tmdbBaseImageUrl,
                                                                    proxyUrl,
                                                                    isProxyEnabled,
                                                                    context) +
                                                                imageQuality +
                                                                movie.posterPath!,
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                        placeholder: (context,
                                                                url) =>
                                                            scrollingImageShimmer(
                                                                themeMode),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            Image.asset(
                                                          'assets/images/na_logo.png',
                                                          fit: BoxFit
                                                              .cover,
                                                          width: double
                                                              .infinity,
                                                          height: double
                                                              .infinity),
                                                      ),
                                              ),
                                              if (movie.voteAverage != null)
                                                Positioned(
                                                  top: 4,
                                                  left: 4,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 5, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(6),
                                                      color: Colors.black.withValues(alpha: 0.65),
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
                                                          movie.voteAverage!.toStringAsFixed(1),
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
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: QualityBadge(
                                                  mediaId: movie.id,
                                                  mediaType: 'movie',
                                                  releaseDate: movie.releaseDate,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                                      child: Text(
                                        movie.title ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isTablet ? 12 : 11,
                                          fontWeight: FontWeight.w600,
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
                    Visibility(
                      visible: isLoading,
                      child: SizedBox(
                        width: cardWidth,
                        child: horizontalLoadMoreShimmer(themeMode),
                      ),
                    ),
                  ],
                ),
        ),
        Divider(
          color: themeMode == "light" ? Colors.black54 : Colors.white54,
          thickness: 1,
          endIndent: isTablet ? 24 : 20,
          indent: isTablet ? 24 : 10,
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/widgets/cached_image.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/utils/theme/textStyle.dart';
import 'package:reelriot/widgets/common_widgets.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:reelriot/models/dropdown_select.dart';
import 'package:reelriot/models/filter_chip.dart';
import 'package:reelriot/models/movie_models.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/screens/movie_screens/movie_details.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/widgets/shimmer_widget.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/models/ad.dart';
import 'package:reelriot/widgets/native_ad_banner.dart';

class DiscoverMovies extends StatefulWidget {
  const DiscoverMovies(
      {super.key, required this.includeAdult, required this.discoverType});
  final bool includeAdult;
  final String discoverType;
  @override
  DiscoverMoviesState createState() => DiscoverMoviesState();
}

class DiscoverMoviesState extends State<DiscoverMovies>
    with AutomaticKeepAliveClientMixin {
  List<Movie>? moviesList;
  late double deviceHeight;
  YearDropdownData yearDropdownData = YearDropdownData();
  @override
  void initState() {
    super.initState();
    getData();
  }

  List<MovieGenreFilterChipWidget> movieGenreFilterdata =
      <MovieGenreFilterChipWidget>[
    MovieGenreFilterChipWidget(genreName: tr('action'), genreValue: '28'),
    MovieGenreFilterChipWidget(genreName: tr('adventure'), genreValue: '12'),
    MovieGenreFilterChipWidget(genreName: tr('animation'), genreValue: '16'),
    MovieGenreFilterChipWidget(genreName: tr('comedy'), genreValue: '35'),
    MovieGenreFilterChipWidget(genreName: tr('crime'), genreValue: '80'),
    MovieGenreFilterChipWidget(genreName: tr('documentary'), genreValue: '99'),
    MovieGenreFilterChipWidget(genreName: tr('drama'), genreValue: '18'),
    MovieGenreFilterChipWidget(genreName: tr('family'), genreValue: '10751'),
    MovieGenreFilterChipWidget(genreName: tr('fantasy'), genreValue: '14'),
    MovieGenreFilterChipWidget(genreName: tr('history'), genreValue: '36'),
    MovieGenreFilterChipWidget(genreName: tr('horror'), genreValue: '27'),
    MovieGenreFilterChipWidget(genreName: tr('music'), genreValue: '10402'),
    MovieGenreFilterChipWidget(genreName: tr('mystery'), genreValue: '9648'),
    MovieGenreFilterChipWidget(genreName: tr('romance'), genreValue: '10749'),
    MovieGenreFilterChipWidget(
        genreName: tr('science_fiction'), genreValue: '878'),
    MovieGenreFilterChipWidget(genreName: tr('tv_movie'), genreValue: '10770'),
    MovieGenreFilterChipWidget(genreName: tr('thriller'), genreValue: '53'),
    MovieGenreFilterChipWidget(genreName: tr('war'), genreValue: '10752'),
    MovieGenreFilterChipWidget(genreName: tr('western'), genreValue: '37'),
  ];

  void getData() {
    List<String> years = yearDropdownData.yearsList.getRange(1, 26).toList();
    List<MovieGenreFilterChipWidget> genres = movieGenreFilterdata;
    years.shuffle();
    genres.shuffle();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final lang =
        Provider.of<SettingsProvider>(context, listen: false).appLanguage;
    final region =
        Provider.of<SettingsProvider>(context, listen: false).defaultCountry;
    fetchMovies(
            '$tmdbApiBaseUrl/discover/movie?api_key=$tmdbApiKey&language=$lang&sort_by=popularity.desc&watch_region=$region&include_adult=${widget.includeAdult}&primary_release_year=${years.first}&with_genres=${genres.first.genreValue}',
            isProxyEnabled,
            proxyUrl)
        .then((value) async {
      if (mounted) {
        setState(() {
          moviesList = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    deviceHeight = MediaQuery.of(context).size.height;
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const LeadingDot(),
                    Expanded(
                      child: Text(
                        tr('featured_movies'),
                        style: kTextHeaderStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          height: 350,
          // height: deviceHeight * 0.417,
          child: moviesList == null
              ? discoverMoviesAndTVShimmer(themeMode)
              : moviesList!.isEmpty
                  ? Center(
                      child: Text(
                        tr("wow_odd"),
                        style: kTextSmallBodyStyle,
                      ),
                    )
                  : CarouselSlider.builder(
                      options: CarouselOptions(
                        disableCenter: true,
                        viewportFraction: 0.6,
                        enlargeCenterPage: true,
                        autoPlay: true,
                      ),
                      itemBuilder:
                          (BuildContext context, int index, int pageViewIndex) {
                        final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
                        final heroAds = appDep.initialAds.where((a) => a.matchesPlacement('hero')).toList();
                        final hasAd = appDep.enableHeroAds && heroAds.isNotEmpty;
                        
                        // Inject ad at Index 1
                        if (hasAd && index == 1) {
                          return NativeAdBanner(
                            ad: heroAds.first,
                            type: NativeAdBannerType.hero,
                          );
                        }

                        // Shift movies if ad is present
                        final movieIndex = (hasAd && index > 1) ? index - 1 : index;
                        final movie = moviesList![movieIndex];

                        final heroTag =
                            '${movie.id}-${widget.discoverType}-$index-$pageViewIndex';
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => MovieDetailPage(
                                        movie: movie,
                                        heroId: heroTag)));
                          },
                          child: Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: CachedPosterImage(
                                  cacheManager: cacheProp(),
                                  preset: CachePreset.posterLarge,
                                  imageUrl:
                                      movie.posterPath == null
                                          ? ''
                                          : buildImageUrl(
                                                  tmdbBaseImageUrl,
                                                  proxyUrl,
                                                  isProxyEnabled,
                                                  context) +
                                              imageQuality +
                                              movie.posterPath!,
                                  themeMode: themeMode,
                                  placeholder: (context, url) =>
                                      discoverImageShimmer(themeMode),
                                  errorWidget: (context, url, error) =>
                                      Image.asset(
                                    'assets/images/na_logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                          ),
                        );
                      },
                      itemCount: (() {
                        final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
                        final hasAd = appDep.enableHeroAds && appDep.initialAds.any((a) => a.matchesPlacement('hero'));
                        return moviesList!.length + (hasAd ? 1 : 0);
                      })(),
                    ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/widgets/cached_image.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:reelriot/models/movie_models.dart';
import 'package:reelriot/screens/movie_screens/movie_details.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/widgets/shimmer_widget.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/widgets/quality_badge.dart';
import 'package:provider/provider.dart';

class MovieGridView extends StatelessWidget {
  const MovieGridView({
    super.key,
    required ScrollController scrollController,
    required this.moviesList,
    required this.imageQuality,
    required this.themeMode,
    this.heroPrefix = 'movie',
  }) : _scrollController = scrollController;

  final ScrollController _scrollController;
  final List<Movie>? moviesList;
  final String imageQuality;
  final String themeMode;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final isProxyEnabled = context.read<SettingsProvider>().enableProxy;
    final proxyUrl = context.read<AppDependencyProvider>().tmdbProxy;
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.48,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: moviesList!.length,
      itemBuilder: (BuildContext context, int index) => MovieGridItem(
        movie: moviesList![index],
        imageQuality: imageQuality,
        themeMode: themeMode,
        proxyUrl: proxyUrl,
        isProxyEnabled: isProxyEnabled,
        heroPrefix: heroPrefix,
      ),
    );
  }
}

/// Extracted grid item to avoid parent rebuilds triggering all items.
class MovieGridItem extends StatelessWidget {
  const MovieGridItem({
    super.key,
    required this.movie,
    required this.imageQuality,
    required this.themeMode,
    required this.proxyUrl,
    required this.isProxyEnabled,
    this.heroPrefix = 'movie',
  });

  final Movie movie;
  final String imageQuality;
  final String themeMode;
  final String proxyUrl;
  final bool isProxyEnabled;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final heroId = '${heroPrefix}_${movie.id}';
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return MovieDetailPage(movie: movie, heroId: heroId);
        }));
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Hero(
                tag: heroId,
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: movie.posterPath == null
                            ? Image.asset('assets/images/na_logo.png',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity)
                            : CachedPosterImage(
                                cacheManager: cacheProp(),
                                imageUrl: buildImageUrl(tmdbBaseImageUrl,
                                        proxyUrl, isProxyEnabled, context) +
                                    imageQuality +
                                    movie.posterPath!,
                                themeMode: themeMode,
                                placeholder: (context, url) =>
                                    scrollingImageShimmer(themeMode),
                                errorWidget: (context, url, error) =>
                                    Image.asset('assets/images/na_logo.png',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity),
                              ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          alignment: Alignment.topLeft,
                          width: 50,
                          height: 25,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color:
                                  themeMode == "dark" || themeMode == "amoled"
                                      ? Colors.black45
                                      : Colors.white60),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                              ),
                              Text((movie.voteAverage ?? 0.0).toStringAsFixed(1))
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 3,
                        right: 3,
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
            const SizedBox(
              height: 5,
            ),
            Expanded(
                flex: 2,
                child: Text(
                  movie.title!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )),
          ],
        ),
      ),
    );
  }
}

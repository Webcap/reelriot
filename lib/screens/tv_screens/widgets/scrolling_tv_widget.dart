import 'package:cached_network_image/cached_network_image.dart';
import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/screens/person/guest_star_details.dart';
import 'package:reelriot/widgets/common_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:reelriot/models/credits.dart';
import 'package:reelriot/models/tv.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/screens/movie_screens/cast_details.dart';
import 'package:reelriot/screens/tv_screens/tv_detail_page.dart';
import 'package:reelriot/screens/tv_screens/widgets/created_by_widget.dart';
import 'package:reelriot/screens/tv_screens/main_tv_list.dart';
import 'package:reelriot/screens/tv_screens/widgets/tvdetails_cast_crew.dart';
import 'package:reelriot/screens/tv_screens/widgets/tvepisode_cast_crew.dart';
import 'package:reelriot/screens/tv_screens/widgets/tvseason_cast_crew_details.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/widgets/shimmer_widget.dart';
import 'package:reelriot/widgets/quality_badge.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/utils/constant.dart';

class ScrollingTV extends StatefulWidget {
  final String api, title;
  final dynamic discoverType;
  final bool isTrending;
  final bool? includeAdult;
  const ScrollingTV({
    super.key,
    required this.api,
    required this.title,
    this.discoverType,
    required this.isTrending,
    required this.includeAdult,
  });
  @override
  ScrollingTVState createState() => ScrollingTVState();
}

class ScrollingTVState extends State<ScrollingTV>
    with AutomaticKeepAliveClientMixin {
  late int index;
  List<TV>? tvList;
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

        fetchTV('${widget.api}&page=$pageNum&include_adult=${widget.includeAdult}',
                isProxyEnabled, proxyUrl)
            .then((value) {
          if (mounted) {
            setState(() {
              final existingIds = tvList!.map((t) => t.id).toSet();
              final newShows =
                  value.where((t) => !existingIds.contains(t.id)).toList();
              tvList!.addAll(newShows);
              isLoading = false;
              pageNum++;
            });
          }
        });
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
    fetchTV('${widget.api}&include_adult=${widget.includeAdult}',
            isProxyEnabled, proxyUrl)
        .then((value) {
      if (mounted) {
        setState(() {
          tvList = value;
        });
      }
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
    final posterHeight = cardWidth * 1.5; // True 2:3 aspect ratio
    final rowHeight = posterHeight + (isTablet ? 56.0 : 48.0);

    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 12.0 : 8.0),
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
                      return MainTVList(
                          api: widget.api,
                          discoverType: widget.discoverType,
                          isTrending: widget.isTrending,
                          includeAdult: widget.includeAdult,
                          title: widget.title);
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
          child: tvList == null
              ? scrollingMoviesAndTVShimmer(themeMode)
              : Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 8),
                        itemCount: tvList!.length,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (BuildContext context, int index) {
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
                                        builder: (context) => TVDetailPage(
                                            tvSeries: tvList![index],
                                            heroId:
                                                '${tvList![index].id}-${widget.title}-${widget.discoverType}-$index')));
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
                                            '${tvList![index].id}-${widget.title}-${widget.discoverType}-$index',
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(isTablet ? 12.0 : 8.0),
                                                child: tvList![index].posterPath == null
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
                                                        imageUrl: tvList![index]
                                                                    .posterPath ==
                                                                null
                                                            ? ''
                                                            : buildImageUrl(
                                                                    tmdbBaseImageUrl,
                                                                    proxyUrl,
                                                                    isProxyEnabled,
                                                                    context) +
                                                                imageQuality +
                                                                tvList![index]
                                                                    .posterPath!,
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
                                              if (tvList![index].voteAverage != null)
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
                                                          tvList![index].voteAverage!.toStringAsFixed(1),
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
                                                  mediaId: tvList![index].id,
                                                  mediaType: 'tv',
                                                  releaseDate: tvList![index].firstAirDate,
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
                                        tvList![index].name ?? '',
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

class ScrollingTVArtists extends StatefulWidget {
  final String? api, title, tapButtonText;
  final int id;
  final int? episodeNumber;
  final int? seasonNumber;
  final String passedFrom;
  const ScrollingTVArtists(
      {super.key,
      this.api,
      this.title,
      this.tapButtonText,
      required this.id,
      this.episodeNumber,
      this.seasonNumber,
      required this.passedFrom});
  @override
  ScrollingTVArtistsState createState() => ScrollingTVArtistsState();
}

class ScrollingTVArtistsState extends State<ScrollingTVArtists>
    with AutomaticKeepAliveClientMixin {
  Credits? credits;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          credits = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const LeadingDot(),
                    Expanded(
                      child: Text(
                        tr("cast"),
                        style: kTextHeaderStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
                onPressed: () {
                  if (credits != null) {
                    if (widget.passedFrom == 'seasons_detail') {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) {
                        return TVSeasonCastAndCrew(
                          passedFrom: widget.passedFrom,
                          id: widget.id,
                          seasonNumber: widget.seasonNumber!,
                        );
                      }));
                    } else {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) {
                        return TVDetailCastAndCrew(
                          passedFrom: widget.passedFrom,
                          id: widget.id,
                        );
                      }));
                    }
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                  maximumSize: WidgetStateProperty.all(const Size(200, 60)),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                ),
                child: Text(tr("see_all_cast_crew")))
          ],
        ),
        SizedBox(
          width: double.infinity,
          height: 160,
          child: credits == null
              ? detailCastShimmer(themeMode)
              : credits!.cast!.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: Center(
                            child: Text(
                          tr("no_cast_tv"),
                        )),
                      ))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: credits!.cast!.length,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return CastDetailPage(
                                  cast: credits!.cast![index],
                                  heroId: '${credits!.cast![index].id}'
                                      '${credits!.cast![index].creditId}'
                                      '${credits!.cast![index].castId}',
                                );
                              }));
                            },
                            child: SizedBox(
                              width: 100,
                              child: Column(
                                children: <Widget>[
                                  Expanded(
                                    flex: 6,
                                    child: SizedBox(
                                      width: 75,
                                      child: Hero(
                                        tag: '${credits!.cast![index].id}',
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(100.0),
                                          child: credits!.cast![index]
                                                      .profilePath ==
                                                  null
                                              ? Image.asset(
                                                  'assets/images/na_logo.png',
                                                  fit: BoxFit.cover,
                                                )
                                              : CachedNetworkImage(
                                                  cacheManager: cacheProp(),
                                                  fadeOutDuration:
                                                      const Duration(
                                                          milliseconds: 300),
                                                  fadeOutCurve: Curves.easeOut,
                                                  fadeInDuration:
                                                      const Duration(
                                                          milliseconds: 700),
                                                  fadeInCurve: Curves.easeIn,
                                                  imageUrl: buildImageUrl(
                                                          tmdbBaseImageUrl,
                                                          proxyUrl,
                                                          isProxyEnabled,
                                                          context) +
                                                      imageQuality +
                                                      credits!.cast![index]
                                                          .profilePath!,
                                                  imageBuilder: (context,
                                                          imageProvider) =>
                                                      Container(
                                                    decoration: BoxDecoration(
                                                      image: DecorationImage(
                                                        image: imageProvider,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  placeholder: (context, url) =>
                                                      detailCastImageShimmer(
                                                          themeMode),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Image.asset(
                                                    'assets/images/na_logo.png',
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 6,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        credits!.cast![index].name!,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ScrollingTVCreators extends StatefulWidget {
  final String? api, title, tapButtonText;
  const ScrollingTVCreators({
    super.key,
    this.api,
    this.title,
    this.tapButtonText,
  });
  @override
  ScrollingTVCreatorsState createState() => ScrollingTVCreatorsState();
}

class ScrollingTVCreatorsState extends State<ScrollingTVCreators>
    with AutomaticKeepAliveClientMixin {
  TVDetails? tvDetails;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTVDetails(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvDetails = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const LeadingDot(),
                    Expanded(
                      child: Text(
                        tr("created_by"),
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
          height: 160,
          child: tvDetails == null
              ? detailCastShimmer(themeMode)
              : tvDetails!.createdBy!.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                          child: Text(tr("no_creators"),
                              textAlign: TextAlign.center)),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: tvDetails!.createdBy!.length,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return CreatedByPersonDetailPage(
                                  createdBy: tvDetails!.createdBy![index],
                                  heroId: '${tvDetails!.createdBy![index].id}'
                                      '${tvDetails!.createdBy![index].name}',
                                );
                              }));
                            },
                            child: SizedBox(
                              width: 100,
                              child: Column(
                                children: <Widget>[
                                  Expanded(
                                    flex: 6,
                                    child: Hero(
                                      tag:
                                          '${tvDetails!.createdBy![index].id!}',
                                      child: SizedBox(
                                        width: 75,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(100.0),
                                          child: tvDetails!.createdBy![index]
                                                      .profilePath ==
                                                  null
                                              ? Image.asset(
                                                  'assets/images/na_logo.png',
                                                  fit: BoxFit.cover,
                                                )
                                              : CachedNetworkImage(
                                                  cacheManager: cacheProp(),
                                                  fadeOutDuration:
                                                      const Duration(
                                                          milliseconds: 300),
                                                  fadeOutCurve: Curves.easeOut,
                                                  fadeInDuration:
                                                      const Duration(
                                                          milliseconds: 700),
                                                  fadeInCurve: Curves.easeIn,
                                                  imageUrl: buildImageUrl(
                                                          tmdbBaseImageUrl,
                                                          proxyUrl,
                                                          isProxyEnabled,
                                                          context) +
                                                      imageQuality +
                                                      tvDetails!
                                                          .createdBy![index]
                                                          .profilePath!,
                                                  imageBuilder: (context,
                                                          imageProvider) =>
                                                      Container(
                                                    decoration: BoxDecoration(
                                                      image: DecorationImage(
                                                        image: imageProvider,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  placeholder: (context, url) =>
                                                      detailCastImageShimmer(
                                                          themeMode),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Image.asset(
                                                    'assets/images/na_logo.png',
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 6,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        tvDetails!.createdBy![index].name!,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ScrollingTVEpisodeCasts extends StatefulWidget {
  final String? api;
  final int? id;
  final int episodeNumber;
  final int seasonNumber;
  final String passedFrom;
  const ScrollingTVEpisodeCasts({
    super.key,
    this.api,
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.passedFrom,
  });
  @override
  ScrollingTVEpisodeCastsState createState() => ScrollingTVEpisodeCastsState();
}

class ScrollingTVEpisodeCastsState extends State<ScrollingTVEpisodeCasts>
    with AutomaticKeepAliveClientMixin {
  Credits? credits;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          credits = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        credits == null
            ? Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(
                              tr("cast"),
                              style: kTextHeaderStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : credits!.cast!.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const LeadingDot(),
                            Expanded(
                              child: Text(
                                tr("cast"),
                                style: kTextHeaderStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                          child: Text(tr("no_cast_episode"),
                              textAlign: TextAlign.center)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              const LeadingDot(),
                              Expanded(
                                child: Text(
                                  tr("cast"),
                                  style: kTextHeaderStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                          onPressed: () {
                            if (credits != null) {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return TVEpisodeCastAndCrew(
                                  episodeNumber: widget.episodeNumber,
                                  seasonNumber: widget.seasonNumber,
                                  id: widget.id!,
                                );
                              }));
                            }
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.all(Colors.transparent),
                            maximumSize:
                                WidgetStateProperty.all(const Size(200, 60)),
                            shape:
                                WidgetStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                            ),
                          ),
                          child: Text(tr("see_all_cast_crew")))
                    ],
                  ),
        SizedBox(
          width: double.infinity,
          height: 160,
          child: credits == null
              ? detailCastShimmer(themeMode)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: credits!.cast!.length,
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) {
                            return CastDetailPage(
                              cast: credits!.cast![index],
                              heroId: '${credits!.cast![index].id}',
                            );
                          }));
                        },
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                flex: 6,
                                child: SizedBox(
                                  width: 75,
                                  child: Hero(
                                    tag: '${credits!.cast![index].id}',
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                      child: credits!
                                                  .cast![index].profilePath ==
                                              null
                                          ? Image.asset(
                                              'assets/images/na_logo.png',
                                              fit: BoxFit.cover,
                                            )
                                          : CachedNetworkImage(
                                              cacheManager: cacheProp(),
                                              fadeOutDuration: const Duration(
                                                  milliseconds: 300),
                                              fadeOutCurve: Curves.easeOut,
                                              fadeInDuration: const Duration(
                                                  milliseconds: 700),
                                              fadeInCurve: Curves.easeIn,
                                              imageUrl: buildImageUrl(
                                                      tmdbBaseImageUrl,
                                                      proxyUrl,
                                                      isProxyEnabled,
                                                      context) +
                                                  imageQuality +
                                                  credits!.cast![index]
                                                      .profilePath!,
                                              imageBuilder:
                                                  (context, imageProvider) =>
                                                      Container(
                                                decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                    image: imageProvider,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              placeholder: (context, url) =>
                                                  detailCastImageShimmer(
                                                      themeMode),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Image.asset(
                                                'assets/images/na_logo.png',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    credits!.cast![index].name!,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ScrollingTVEpisodeGuestStars extends StatefulWidget {
  final String? api;
  const ScrollingTVEpisodeGuestStars({
    super.key,
    this.api,
  });
  @override
  ScrollingTVEpisodeGuestStarsState createState() =>
      ScrollingTVEpisodeGuestStarsState();
}

class ScrollingTVEpisodeGuestStarsState
    extends State<ScrollingTVEpisodeGuestStars>
    with AutomaticKeepAliveClientMixin {
  Credits? credits;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          credits = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        credits == null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: <Widget>[
                    Text(
                      tr("guest_stars"),
                      style: kTextHeaderStyle,
                    ),
                  ],
                ),
              )
            : credits!.episodeGuestStars!.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                        child: Text(tr("no_guest_episode"),
                            textAlign: TextAlign.center)),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          tr("guest_stars"),
                          style: kTextHeaderStyle,
                        ),
                      ),
                    ],
                  ),
        SizedBox(
          width: double.infinity,
          height: 160,
          child: credits == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: credits!.episodeGuestStars!.length,
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) {
                            return GuestStarDetailPage(
                              cast: credits!.episodeGuestStars![index],
                              heroId:
                                  '${credits!.episodeGuestStars![index].id}',
                            );
                          }));
                        },
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                flex: 6,
                                child: SizedBox(
                                  width: 75,
                                  child: Hero(
                                    tag:
                                        '${credits!.episodeGuestStars![index].id}',
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                      child: credits!.episodeGuestStars![index]
                                                  .profilePath ==
                                              null
                                          ? Image.asset(
                                              'assets/images/na_logo.png',
                                              fit: BoxFit.cover,
                                            )
                                          : CachedNetworkImage(
                                              cacheManager: cacheProp(),
                                              fadeOutDuration: const Duration(
                                                  milliseconds: 300),
                                              fadeOutCurve: Curves.easeOut,
                                              fadeInDuration: const Duration(
                                                  milliseconds: 700),
                                              fadeInCurve: Curves.easeIn,
                                              imageUrl: buildImageUrl(
                                                      tmdbBaseImageUrl,
                                                      proxyUrl,
                                                      isProxyEnabled,
                                                      context) +
                                                  imageQuality +
                                                  credits!
                                                      .episodeGuestStars![index]
                                                      .profilePath!,
                                              imageBuilder:
                                                  (context, imageProvider) =>
                                                      Container(
                                                decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                    image: imageProvider,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              placeholder: (context, url) =>
                                                  scrollingImageShimmer(
                                                      themeMode),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Image.asset(
                                                'assets/images/na_logo.png',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    credits!.episodeGuestStars![index].name!,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

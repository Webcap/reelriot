import 'package:reelriot/utils/constant.dart';

class Endpoints {
  /// Ensures base URL has a trailing slash so path concatenation is correct
  /// (avoids "api.consumet.orgmovies" when base is "https://api.consumet.org").
  static String _b(String baseUrl) =>
      baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  static String discoverMoviesUrl(int page, String l, String region) {
    return '$tmdbApiBaseUrl'
        '/discover/movie?api_key='
        '$tmdbApiKey'
        '&language=$l&sort_by=popularity'
        '.desc&include_video=false&page'
        '=$page&region=$region';
  }

  static String nowPlayingMoviesUrl(String l) {
    return '$tmdbApiBaseUrl'
        '/movie/now_playing?api_key='
        '$tmdbApiKey'
        '&language=$l';
  }

  static String getCreditsUrl(int id, String l) {
    return '$tmdbApiBaseUrl/movie/$id/credits?api_key=$tmdbApiKey&language=$l';
  }

  static String topRatedUrl(String l, String region) {
    return '$tmdbApiBaseUrl'
        '/movie/top_rated?api_key='
        '$tmdbApiKey'
        '&region=$region&language=$l';
  }

  static String popularMoviesUrl(String l) {
    return '$tmdbApiBaseUrl'
        '/movie/popular?api_key='
        '$tmdbApiKey'
        '&language=$l';
  }

  static String trendingMoviesUrl(bool includeAdult, String l) {
    return '$tmdbApiBaseUrl'
        '/trending/movie/week?api_key='
        '$tmdbApiKey'
        '&include_adult=$includeAdult&language=$l';
  }

  static String upcomingMoviesUrl(String l, [String region = '']) {
    final regionParam = region.isNotEmpty ? '&region=$region' : '';
    return '$tmdbApiBaseUrl/movie/upcoming?api_key=$tmdbApiKey&language=$l$regionParam';
  }

  static String movieDetailsUrl(int movieId, String l) {
    return '$tmdbApiBaseUrl/movie/$movieId?api_key=$tmdbApiKey&language=$l';
  }

  static String movieGenresUrl(String l) {
    return '$tmdbApiBaseUrl/genre/movie/list?api_key=$tmdbApiKey&language=$l';
  }

  static String tvGenresUrl(String l) {
    return '$tmdbApiBaseUrl/genre/tv/list?api_key=$tmdbApiKey&language=$l';
  }

  static String getMoviesForGenre(int genreId, int page, String l) {
    return '$tmdbApiBaseUrl/discover/movie?api_key=$tmdbApiKey'
        '&sort_by=popularity.desc'
        '&include_video=false'
        '&page=$page'
        '&with_genres=$genreId&language=$l';
  }

  static String movieReviewsUrl(int movieId, int page, String l) {
    return '$tmdbApiBaseUrl/movie/$movieId/reviews?api_key=$tmdbApiKey'
        '&language=$l&page=$page';
  }

  static String movieSearchUrl(String query, bool includeAdult, String l) {
    return "$tmdbApiBaseUrl/search/movie?query=$query&include_adult=$includeAdult&language=$l&api_key=$tmdbApiKey";
  }

  static String personSearchUrl(String query, bool includeAdult, String l) {
    return "$tmdbApiBaseUrl/search/person?query=$query&include_adult=$includeAdult&language=$l&api_key=$tmdbApiKey";
  }

  static String tvSearchUrl(String query, bool includeAdult, String l) {
    return "$tmdbApiBaseUrl/search/tv?query=$query&include_adult=$includeAdult&language=$l&api_key=$tmdbApiKey";
  }

  static String getPerson(int personId, String l) {
    return "$tmdbApiBaseUrl/person/$personId?api_key=$tmdbApiKey&language=$l&append_to_response=movie_credits";
  }

  static String watchProvidersMovies(int providerId, String l, String region) {
    return '$tmdbApiBaseUrl'
        '/discover/movie?api_key='
        '$tmdbApiKey'
        '&language=$l&sort_by=popularity'
        '.desc&include_video=false'
        '&with_watch_providers=$providerId'
        '&watch_region=$region';
  }

  static String watchProvidersTVShows(
      int providerId, int page, String l, String region) {
    return '$tmdbApiBaseUrl'
        '/discover/tv?api_key='
        '$tmdbApiKey'
        '&language=$l&sort_by=popularity'
        '.desc&include_adult=false&include_video=false&page=$page'
        '&with_watch_providers=$providerId'
        '&watch_region=$region';
  }

  static String getImages(int id) {
    return '$tmdbApiBaseUrl/movie/$id/images?api_key=$tmdbApiKey';
  }

  static String getVideos(int id) {
    return '$tmdbApiBaseUrl/movie/$id/videos?api_key=$tmdbApiKey';
  }

  static String getMovieRecommendations(int id, int page, String l) {
    return '$tmdbApiBaseUrl'
        '/movie/$id/recommendations?api_key=$tmdbApiKey&language=$l&page=$page';
  }

  static String getExternalLinksForMovie(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/movie/$id/external_ids?api_key=$tmdbApiKey&language=$l';
  }

  static String getSimilarMovies(int id, int page, String l) {
    return '$tmdbApiBaseUrl'
        '/movie/$id/similar?api_key=$tmdbApiKey&language=$l&page=$page';
  }

  static String getMovieCreditsForPerson(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/person/$id/movie_credits?api_key=$tmdbApiKey&language=$l';
  }

  static String getPersonDetails(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/person/$id?api_key=$tmdbApiKey&language=$l';
  }

  static String getPersonImages(int id) {
    return '$tmdbApiBaseUrl'
        '/person/$id/images?api_key=$tmdbApiKey';
  }

  static String getMovieWatchProviders(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/movie/$id/watch/providers?api_key=$tmdbApiKey&language=$l';
  }

  static String discoverTVUrl(int page, String l, String region) {
    return '$tmdbApiBaseUrl'
        '/discover/tv?api_key=$tmdbApiKey&language=$l&sort_by=popularity.desc&page=$page&region=$region';
  }

  static String popularTVUrl(String l) {
    return '$tmdbApiBaseUrl'
        '/tv/popular?api_key=$tmdbApiKey&language=$l';
  }

  static String trendingTVUrl(String l) {
    return '$tmdbApiBaseUrl'
        '/trending/tv/week?api_key=$tmdbApiKey&language=$l';
  }

  static String topRatedTVUrl(String l) {
    return '$tmdbApiBaseUrl'
        '/tv/top_rated?api_key=$tmdbApiKey&language=$l';
  }

  static String airingTodayUrl(String l) {
    return '$tmdbApiBaseUrl'
        '/tv/airing_today?api_key=$tmdbApiKey&language=$l';
  }

  static String onTheAirUrl(String l) {
    return '$tmdbApiBaseUrl'
        '/tv/on_the_air?api_key=$tmdbApiKey&language=$l';
  }

  static String getFullTVCreditsUrl(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/aggregate_credits?api_key=$tmdbApiKey&language=$l';
  }

  static String getTVCreditsUrl(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/credits?api_key=$tmdbApiKey&language=$l';
  }

  static String getTVSeasonCreditsUrl(int id, int seasonNumber, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/season/$seasonNumber/credits?api_key=$tmdbApiKey&language=$l';
  }

  static String getFullTVSeasonCreditsUrl(int id, int seasonNumber, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/season/$seasonNumber/aggregate_credits?api_key=$tmdbApiKey&language=$l';
  }

  static String getTVSeasonImagesUrl(int id, int seasonNumber) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/season/$seasonNumber/images?api_key=$tmdbApiKey';
  }

  static String getTVEpisodeImagesUrl(
      int id, int seasonNumber, int episodeNumber) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/season/$seasonNumber/episode/$episodeNumber/images?api_key=$tmdbApiKey';
  }

  static String getTVEpisodeVideosUrl(
      int id, int seasonNumber, int episodeNumber) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/season/$seasonNumber/episode/$episodeNumber/videos?api_key=$tmdbApiKey';
  }

  static String getTVSeasonVideosUrl(int id, int seasonNumber) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/season/$seasonNumber/videos?api_key=$tmdbApiKey';
  }

  static String tvDetailsUrl(int id, String l) {
    return '$tmdbApiBaseUrl/tv/$id?api_key=$tmdbApiKey&language=$l';
  }

  static String getTVImages(int id) {
    return '$tmdbApiBaseUrl/tv/$id/images?api_key=$tmdbApiKey';
  }

  static String getTVVideos(int id) {
    return '$tmdbApiBaseUrl/tv/$id/videos?api_key=$tmdbApiKey';
  }

  static String getTVRecommendations(int id, int page, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/recommendations?api_key=$tmdbApiKey&language=$l&page=$page';
  }

  static String getSimilarTV(int id, int page, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/similar?api_key=$tmdbApiKey&language=$l&page=$page';
  }

  static String getTVShowsForGenre(int genreId, int page, String l) {
    return '$tmdbApiBaseUrl/discover/tv?api_key=$tmdbApiKey'
        '&language=$l'
        '&sort_by=popularity.desc'
        '&page=$page'
        '&with_genres=$genreId';
  }

  static String getTVCreditsForPerson(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/person/$id/tv_credits?api_key=$tmdbApiKey&language=$l';
  }

  static String getExternalLinksForPerson(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/person/$id/external_ids?api_key=$tmdbApiKey&language=$l';
  }

  static String getExternalLinksForTV(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/external_ids?api_key=$tmdbApiKey&language=$l';
  }

  static String getTVSeasons(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id?api_key=$tmdbApiKey&language=$l';
  }

  static String getSeasonDetails(int id, int seasonNum, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/season/$seasonNum?api_key=$tmdbApiKey&language=$l';
  }

  static String getCollectionDetails(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/collection/$id?api_key=$tmdbApiKey&language=$l';
  }

  static String getEpisodeCredits(
      int id, int seasonNumber, int episodeNumber, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/season/$seasonNumber/episode/$episodeNumber/credits?api_key=$tmdbApiKey&language=$l';
  }

  static String getTVWatchProviders(int id, String l) {
    return '$tmdbApiBaseUrl'
        '/tv/$id/watch/providers?api_key=$tmdbApiKey&language=$l';
  }

  static String getMovieDetails(int id, String l) {
    return '$tmdbApiBaseUrl' '/movie/$id?api_key=$tmdbApiKey&language=$l';
  }

  static String getTVDetails(int id, String l) {
    return '$tmdbApiBaseUrl' '/tv/$id?api_key=$tmdbApiKey&language=$l';
  }

  static String searchMovieTVForStreamFlixHQ(String titleName, String baseUrl) {
    return '${_b(baseUrl)}movies/flixhq/$titleName';
  }

  static String getMovieTVStreamInfoFlixHQ(
      String titleStreamId, String baseUrl) {
    return '${_b(baseUrl)}movies/flixhq/info?id=$titleStreamId';
  }

  static String getMovieTVStreamLinksFlixHQ(
      String episodeId, String mediaId, String baseUrl, String server) {
    return '${_b(baseUrl)}movies/flixhq/watch?episodeId=$episodeId&mediaId=$mediaId&server=$server';
  }

  /// Movie/TV TMDB route endpoints

  static String getMovieTVStreamInfoTMDB(
      String id, String media, String baseUrl) {
    return '${_b(baseUrl)}meta/tmdb/info/$id?type=$media';
  }

  static String getMovieTVStreamLinksTMDB(
      String baseUrl, String episodeId, String mediaId, String server) {
    return '${_b(baseUrl)}meta/tmdb/watch/$episodeId?id=$mediaId&server=$server';
  }

  static String searchExternalMovieSubtitles(int tmdbId, String languages) {
    return '$opensubtitlesBaseUrl'
        '/subtitles?tmdb_id=$tmdbId&languages=$languages&ai_translated=exclude';
  }

  static String searchExternalEpisodeSubtitles(
      int tmdbId, int episodeNum, int seasonNum, String languages) {
    return '$opensubtitlesBaseUrl'
        '/subtitles?parent_tmdb_id=$tmdbId&languages=$languages&ai_translated=exclude&season_number=$seasonNum&episode_number=$episodeNum';
  }

  static String externalSubtitleDownload() {
    return '$opensubtitlesBaseUrl' '/download';
  }

  static String tmaGetMovieSource(String baseUrl, int id) {
    return '${_b(baseUrl)}v3/movie/sources/$id';
  }

  static String tmaGetEpisodeSource(
      String baseUrl, int id, int episodeNum, int seasonNum) {
    return '${_b(baseUrl)}v3/tv/sources/$id/$seasonNum/$episodeNum';
  }

  static String getMovieEndpointCaffeineAPI(
      String baseUrl, int tmdbId, String provider, String server) {
    return '${_b(baseUrl)}$provider/watch-movie?tmdbId=$tmdbId&server=$server';
  }

  static String getTVEndpointCaffeineAPI(String baseUrl, int episode,
      int season, int tmdbId, String provider, String server) {
    return '${_b(baseUrl)}$provider/watch-tv?tmdbId=$tmdbId&season=$season&episode=$episode&server=$server';
  }



  /// ESPN scoreboard for a league on a date.
  /// [date] should be the user's local calendar date (e.g. DateTime.now()).
  /// When date is "today" in local time, omits ?dates= so ESPN returns live/upcoming games.
  static String getEspnScoreboardUrl(
      String sport, String league, DateTime date) {
    final base =
        'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/scoreboard';
    final d =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return '$base?dates=$d';
  }

  /// Caffeine API Scoreboard - All leagues aggregated or per-league.
  static String getCaffeineScoreboardUrl(String baseUrl, {String? sport, String? league, DateTime? date}) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final dateParam = date != null ? '?date=${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}' : '';
    if (sport != null && league != null) {
      return '$base/sports/$sport/$league/scoreboard$dateParam';
    }
    return '$base/sports/scoreboard/all$dateParam';
  }

  /// FlixQuest Scraper API - https://github.com/BeamlakAschalew/flixquest-scraper
  /// Providers: vixsrc, vidsrc, vidzee, uhdmovies, showbox, 4khdhub
  static String getFlixQuestStreamMovie(String baseUrl, String tmdbId,
      [String provider = 'vidsrcsu', String language = 'en', String country = 'US']) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '$base$provider/stream-movie?tmdbId=$tmdbId&language=$language&country=$country';
  }

  static String getFlixQuestStreamTV(
      String baseUrl, String tmdbId, int season, int episode,
      [String provider = 'vidsrcsu', String language = 'en', String country = 'US']) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '$base$provider/stream-tv?tmdbId=$tmdbId&season=$season&episode=$episode&language=$language&country=$country';
  }

  /// FlixAPI Multi-provider (pstream, vixsrc, showbox)
  static String getMovieStreamLinkFlixAPIMulti(
      String baseUrl, String provider, int movieId, String language, String country) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '$base$provider/stream-movie?tmdbId=$movieId&language=$language&country=$country';
  }

  static String getTVStreamLinkFlixAPIMulti(String baseUrl, String provider,
      int tmdbId, int episodeId, int seasonId, String language, String country) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '$base$provider/stream-tv?tmdbId=$tmdbId&episode=$episodeId&season=$seasonId&language=$language&country=$country';
  }

  // ─── Reelriot Discovery Engine v1.2 ──────────────────────────────────────
  /// Builds the GET /v1/discovery URL.
  /// [userId]    — optional, enables "Because you watched" AI rows.
  /// [mediaType] — optional, 'movie' or 'tv'.
  /// [region]    — optional, ISO-3166-1 alpha-2 country code.
  static String discoveryFeedUrl(
    String baseUrl, {
    String? userId,
    String? mediaType,
    String? region,
    String? platform,
    String? env,
  }) {
    final b = _b(baseUrl);
    final params = <String>[];
    if (userId != null && userId.isNotEmpty) params.add('userId=$userId');
    if (mediaType != null && mediaType.isNotEmpty) params.add('mediaType=$mediaType');
    if (region != null && region.isNotEmpty) params.add('region=$region');
    if (platform != null && platform.isNotEmpty) params.add('platform=$platform');
    if (env != null && env.isNotEmpty) params.add('env=$env');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return '${b}v1/discovery$query';
  }

  // ─── User Ratings ──────────────────────────────────────────────────────────
  /// GET /v1/user/:userId/ratings?media_type=movie|tv
  static String userRatingsUrl(String baseUrl, String userId, {String? mediaType}) {
    final b = _b(baseUrl);
    final query = (mediaType != null && mediaType.isNotEmpty) ? '?media_type=$mediaType' : '';
    return '${b}v1/user/$userId/ratings$query';
  }

  /// PUT /v1/user/:userId/ratings
  static String userRatingsPutUrl(String baseUrl, String userId) {
    final b = _b(baseUrl);
    return '${b}v1/user/$userId/ratings';
  }

  /// DELETE /v1/user/:userId/ratings?media_type=...&media_id=...
  static String userRatingsDeleteUrl(
    String baseUrl,
    String userId, {
    required String mediaType,
    required int mediaId,
    int? seasonNum,
    int? episodeNum,
  }) {
    final b = _b(baseUrl);
    final params = <String>[
      'media_type=$mediaType',
      'media_id=$mediaId',
    ];
    if (seasonNum != null) params.add('season_num=$seasonNum');
    if (episodeNum != null) params.add('episode_num=$episodeNum');
    return '${b}v1/user/$userId/ratings?${params.join('&')}';
  }
}



// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/models/custom_exceptions.dart';
import 'package:reelriot/models/espn_scoreboard.dart';
import 'package:reelriot/models/live_tv.dart';
import 'package:reelriot/screens/tv_screens/live_event_screen.dart';
import 'package:reelriot/widgets/featured_match_card.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/services/ad_service.dart';
import 'package:reelriot/widgets/banner_ad_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Removed _streamedFallbackUrl as we are Supabase-only now.

/// Prettifies scraped event titles: fix concatenation, extract status, add " vs " for match names.
String formatLiveEventTitle(String raw) {
  if (raw.trim().isEmpty) return raw;
  String s = raw.trim();
  // Ensure space after "Live Now!"
  s = s.replaceAllMapped(RegExp(r'Live Now!(\S)'), (m) => 'Live Now! ${m[1]}');
  // Ensure space after "Starts in: HH:MM:SS"
  s = s.replaceAllMapped(
      RegExp(r'(Starts in:\s*\d{2}:\d{2}(?::\d{2})?)([A-Za-z])'),
      (m) => '${m[1]} ${m[2]}');
  // Space between lowercase and uppercase (e.g. MammothChicago -> Mammoth Chicago)
  s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  // Space between digit and Uppercase letter (e.g. 41Galatasaray -> 41 Galatasaray)
  // We avoid lower case to preserve names like "76ers" or "49ers"
  s = s.replaceAllMapped(RegExp(r'(\d)([A-Z])'), (m) => '${m[1]} ${m[2]}');
  // Space after status prefixes (e.g. FTManchester -> FT Manchester)
  s = s.replaceAllMapped(RegExp(r'^(FT|HT|LIVE|PST|CAN|TBD)([A-Z1-9])'), (m) => '${m[1]} ${m[2]}');

  // Normalize separators: replace "@" and " at " with " vs " early
  s = s.replaceAll(RegExp(r'\s+at\s+', caseSensitive: false), ' vs ');
  s = s.replaceAll(RegExp(r'\s+@\s+'), ' vs ');

  // Normalize multiple "vs" that might have been created
  s = s.replaceAll(RegExp(r'\s+vs\s+vs\s+', caseSensitive: false), ' vs ');

  // Normalize multiple spaces
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Add " vs " between two teams if missing (only in the event part, not inside status)
  String prefix = '';
  String body = s;
  if (s.startsWith('Live Now!')) {
    prefix = 'Live Now! ';
    body = s.substring(9).trim();
  } else {
    final startsMatch = RegExp(r'^(Starts in:\s*\S+)\s*(.*)$').firstMatch(s);
    if (startsMatch != null) {
      prefix = '${startsMatch.group(1)!} ';
      body = (startsMatch.group(2) ?? '').trim();
    }
  }

  // Final cleanup: if we have "vs at" or "at vs" from raw input, simplify to "vs"
  body = body.replaceAll(RegExp(r'\s+vs\s+at\s+', caseSensitive: false), ' vs ');
  body = body.replaceAll(RegExp(r'\s+at\s+vs\s+', caseSensitive: false), ' vs ');

  final isNamedEvent = body.contains(':') ||
      body.contains(',') ||
      RegExp(r'(series|season|week|fight night|grand prix|championship|tournament)',
              caseSensitive: false)
          .hasMatch(body);

  if (body.isNotEmpty && !body.toLowerCase().contains(' vs ') && !isNamedEvent) {
    final words = body.split(RegExp(r'\s+'));
    if (words.length == 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      body = '${words[0]} vs ${words[1]}';
    } else if (words.length >= 4) {
      final mid = words.length ~/ 2;
      body = '${words.take(mid).join(' ')} vs ${words.skip(mid).join(' ')}';
    }
  }
  return (prefix + body).trim();
}

/// Parsed bits for display: optional status (Live Now! / Starts in: ...) and main title.
LiveEventTitleParsed parseLiveEventTitle(String raw) {
  final formatted = formatLiveEventTitle(raw);
  String? status;
  String title = formatted;
  if (formatted.startsWith('Live Now!')) {
    status = 'Live Now!';
    title = formatted.substring(9).trim();
    if (title.isEmpty) title = formatted;
  } else if (RegExp(r'^Starts in:\s*\d').hasMatch(formatted)) {
    final match = RegExp(r'^(Starts in:\s*\S+)\s*(.*)$').firstMatch(formatted);
    if (match != null) {
      status = match.group(1)!.trim();
      title = (match.group(2) ?? '').trim();
      if (title.isEmpty) title = formatted;
    }
  }
  return LiveEventTitleParsed(status: status, title: title);
}

class LiveEventTitleParsed {
  const LiveEventTitleParsed({this.status, required this.title});
  final String? status;
  final String title;
}

// Design tokens from design.json (cinematic, dark-first, primary red CTA)
abstract class _LiveTvDesign {
  static const Color bgCanvasDark = Color(0xFF030712);
  static const Color bgCanvasLight = Color(0xFFF8FAFC);
  static const Color bgSurfaceDark = Color(0xFF0B0F14);
  static const Color bgSurfaceElevated = Color(0xFF111827);
  static const Color primaryCta = Color(0xFFDC2626);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0B0F14);
  static const Color textSecondary = Color(0xB8FFFFFF);
  static const Color textTertiary = Color(0x66FFFFFF);
  static const Color borderSubtle = Color(0x14FFFFFF);
  static const Color liveGlow = Color(0x33DC2626);
  static const double radiusCard = 20.0;
  static const double radiusSm = 12.0;
  static const double radiusPill = 9999.0;
  static const double ctaHeight = 52.0;
  static const List<BoxShadow> shadowCard = [
    BoxShadow(color: Color(0x38000000), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> shadowLive = [
    BoxShadow(color: Color(0x22DC2626), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x28000000), blurRadius: 30, offset: Offset(0, 10)),
  ];
}

class ChannelList extends StatefulWidget {
  const ChannelList({super.key});

  @override
  State<ChannelList> createState() => ChannelListState();
}

class ChannelListState extends State<ChannelList> {
  List<EspnListEvent>? _todayEvents;
  Set<String> _activeStreamIds = {};
  bool _loadFailed = false;
  String _searchQuery = '';
  String? _sportFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadTodayEvents());
  }

  Future<void> loadTodayEvents() async {
    if (!mounted) return;
    setState(() => _loadFailed = false);
    
    // Refresh featured sports from Supabase (runs concurrently with ESPN load)
    try {
      context.read<AppDependencyProvider>().fetchSportsStreams();
    } catch (_) {}

    // Use device local date/time so "today" and live games match the user's timezone.
    final date = DateTime.now();
    debugPrint(
        '[LiveTV] Loading ESPN events for ${date.year}-${date.month}-${date.day} (local)');
    try {
      final todayList = await fetchEspnEventsForDayMultiLeague(date);

      // If it's early morning (before 6am), also fetch yesterday to catch late-night live games
      List<EspnListEvent> yesterdayLive = [];
      if (date.hour < 6) {
        final yesterday = date.subtract(const Duration(days: 1));
        final yesterdayList = await fetchEspnEventsForDayMultiLeague(yesterday);
        // Only keep games that are actually live or very recently ended
        yesterdayLive = yesterdayList.where((e) => e.game.isActuallyLive).toList();
      }

      final combined = [...yesterdayLive, ...todayList];
      // deduplicate by id
      final seen = <String>{};
      final list = combined.where((e) => seen.add(e.game.id)).toList();

      final activeStreams = await Supabase.instance.client
          .from('live_streams')
          .select('id, is_ended')
          .not('video_url', 'is', null)
          .eq('is_hidden', false);

      final Map<String, bool> endedInfo = {
        for (var s in (activeStreams as List))
          s['id'].toString(): s['is_ended'] == true
      };

      final activeStreamIds = endedInfo.keys.toSet();

      final updatedList = list.map((e) {
        if (endedInfo.containsKey(e.game.id)) {
          return e.copyWith(
            game: e.game.copyWith(isManualEnded: endedInfo[e.game.id]),
          );
        }
        return e;
      }).toList();

      if (!mounted) return;

      setState(() {
        _activeStreamIds = activeStreamIds;
        _todayEvents = updatedList;
      });
      debugPrint('[LiveTV] Loaded ${list.length} events');
    } catch (e, st) {
      debugPrint('[LiveTV] ESPN load failed: $e');
      debugPrint('[LiveTV] $st');
      if (!mounted) return;
      setState(() {
        _todayEvents = [];
        _loadFailed = true;
      });
    }
  }

  /// Unique sports from ESPN events, sorted.
  List<String> get _sportFilters {
    if (_todayEvents == null) return [];
    final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
    final set = <String>{};
    for (final e in _todayEvents!) {
      if (appDep.isSportRowHidden(e.sport, league: e.league, title: e.game.name, game: e.game)) {
        continue;
      }
      final s = e.sport.trim();
      if (s.isNotEmpty) set.add(s.toUpperCase());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<EspnListEvent> get _filteredEvents {
    if (_todayEvents == null) return [];
    final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
    var list = _todayEvents!
        .where((e) => !appDep.isSportRowHidden(e.sport, league: e.league, title: e.game.name, game: e.game))
        .toList();
    if (_sportFilter != null && _sportFilter!.isNotEmpty) {
      final sportLower = _sportFilter!.toLowerCase();
      list = list.where((e) => e.sport.toLowerCase() == sportLower).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) {
        final title = e.game.name.toLowerCase();
        final sport = e.sport.toLowerCase();
        final league = e.league.toLowerCase();
        return title.contains(q) || sport.contains(q) || league.contains(q);
      }).toList();
    }

    // Filter out upcoming games that are further than 30 minutes away
    final now = DateTime.now();
    list = list.where((e) {
      if (!e.game.isActuallyLive && !e.game.isEffectivelyCompleted) {
        if (e.game.startTimeUtc == null) return false;
        final diff = e.game.startTimeUtc!.difference(now).inMinutes;
        return diff <= 30;
      }
      return true; // Keep Live and Completed
    }).toList();

    // Sort events
    list = list.toList()
      ..sort((a, b) {
        final now = DateTime.now();
        final timeA = a.game.startTimeUtc;
        final timeB = b.game.startTimeUtc;

        // Group 1: Upcoming soon (within 30 mins of starting)
        final isAStartingSoon = !a.game.isActuallyLive && !a.game.isEffectivelyCompleted &&
                                timeA != null && timeA.isAfter(now) &&
                                timeA.difference(now).inMinutes <= 30;
        final isBStartingSoon = !b.game.isActuallyLive && !b.game.isEffectivelyCompleted &&
                                timeB != null && timeB.isAfter(now) &&
                                timeB.difference(now).inMinutes <= 30;

        if (isAStartingSoon != isBStartingSoon) {
          return isAStartingSoon ? -1 : 1;
        }

        // Group 2: Actually Live games
        if (a.game.isActuallyLive != b.game.isActuallyLive) {
          return a.game.isActuallyLive ? -1 : 1;
        }

        // Group 3: Other scheduled games (not starting soon, not live, not completed)
        final aSched = !a.game.isActuallyLive && !a.game.isEffectivelyCompleted;
        final bSched = !b.game.isActuallyLive && !b.game.isEffectivelyCompleted;
        if (aSched != bSched) {
          return aSched ? -1 : 1;
        }

        // Sorting within groups by time (Sooner first)
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;

        return timeA.compareTo(timeB);
      });
    return list;
  }

  Map<String, List<EspnListEvent>> get _categorizedEvents {
    final list = _filteredEvents;
    return {
      'live': list
          .where((e) => e.game.isActuallyLive && !e.game.isEffectivelyCompleted)
          .toList(),
      'upcoming': list
          .where((e) => !e.game.isActuallyLive && !e.game.isEffectivelyCompleted)
          .toList(),
      'completed': list.where((e) => e.game.isEffectivelyCompleted).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isDark = themeMode == 'dark' || themeMode == 'amoled';

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: isDark ? _LiveTvDesign.bgCanvasDark : _LiveTvDesign.bgCanvasLight,
      appBar: AppBar(
        title: Text(
          'Live Sports',
          style: TextStyle(
            color: isDark ? _LiveTvDesign.textPrimary : _LiveTvDesign.textPrimaryLight,
            fontWeight: FontWeight.w700,
            fontSize: isTablet ? 20 : 18,
            fontFamily: 'PoppinsSB',
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: isTablet,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? _LiveTvDesign.textPrimary : _LiveTvDesign.textPrimaryLight,
            size: 20,
          ),
          onPressed: () => Navigator.maybePop(context),
          tooltip: tr("back"),
        ),
        backgroundColor: isDark ? _LiveTvDesign.bgCanvasDark : _LiveTvDesign.bgCanvasLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? _LiveTvDesign.textPrimary : _LiveTvDesign.textPrimaryLight,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 32 : 20,
              vertical: isTablet ? 20 : 16,
            ),
            child: _buildBody(isDark, isTablet),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, bool isTablet) {
    final appDep = Provider.of<AppDependencyProvider>(context);
    if (!appDep.displayOTTDrawer) {
      return _buildEmptyState(isDark, "Live sports are currently disabled");
    }
    if (_loadFailed) {
      return _buildErrorCard(isDark);
    }
    if (_todayEvents == null) {
      return Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _LiveTvDesign.primaryCta,
          ),
        ),
      );
    }
    final cats = _categorizedEvents;
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final featuredEvent = appDep.featuredEvent;
    final showFeatured = featuredEvent != null &&
        !appDep.isSportRowHidden(featuredEvent.sport, title: featuredEvent.title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BannerAdWidget(),
        if (showFeatured) FeaturedMatchCard(event: featuredEvent),
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Text(
            dateStr,
            style: TextStyle(
              color: isDark
                  ? _LiveTvDesign.textSecondary
                  : Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _buildSearchCard(isDark),
        const SizedBox(height: 12),
        _buildChannelFilters(isDark),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            color: _LiveTvDesign.primaryCta,
            onRefresh: loadTodayEvents,
            child: _todayEvents!.isEmpty
                ? _buildEmptyState(isDark, "No events today")
                : (cats['live']!.isEmpty &&
                        cats['upcoming']!.isEmpty &&
                        cats['completed']!.isEmpty)
                    ? _buildEmptyState(isDark, "No events match your search")
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (cats['live']!.isNotEmpty) ...[
                            _buildSectionHeader(isDark, "LIVE NOW",
                                color: _LiveTvDesign.primaryCta, isLive: true),
                            _buildEventListOrGrid(cats['live']!, isDark, isTablet),
                            const SizedBox(height: 20),
                          ],
                          if (cats['upcoming']!.isNotEmpty) ...[
                            _buildSectionHeader(isDark, "UPCOMING"),
                            _buildEventListOrGrid(cats['upcoming']!, isDark, isTablet),
                            const SizedBox(height: 20),
                          ],
                          if (cats['completed']!.isNotEmpty) ...[
                            _buildSectionHeader(isDark, "COMPLETED"),
                            _buildEventListOrGrid(cats['completed']!, isDark, isTablet),
                          ],
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventListOrGrid(List<EspnListEvent> events, bool isDark, bool isTablet) {
    if (!isTablet) {
      return Column(
        children: events.map((event) => _buildEventTile(event, isDark)).toList(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 720;
        if (!useGrid) {
          return Column(
            children: events.map((event) => _buildEventTile(event, isDark)).toList(),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 580,
            mainAxisExtent: 205,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: events.length,
          itemBuilder: (context, index) => _MatchCard(
            event: events[index],
            isDark: isDark,
            hasStream: _activeStreamIds.contains(events[index].game.id),
            onTap: () => _openEvent(events[index]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    final isNoResults = message.toLowerCase().contains('search');
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 400,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? _LiveTvDesign.primaryCta.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNoResults
                    ? Icons.search_off_rounded
                    : Icons.sports_rounded,
                size: 32,
                color: isDark
                    ? _LiveTvDesign.textSecondary
                    : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: isDark ? _LiveTvDesign.textPrimary : Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isNoResults
                  ? 'Try a different search term or filter'
                  : 'Pull down to refresh or check back later',
              style: TextStyle(
                color: isDark
                    ? _LiveTvDesign.textTertiary
                    : Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, String title, {Color? color, bool isLive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 8),
      child: Row(
        children: [
          if (isLive) ...[
            const _LivePulse(size: 10),
            const SizedBox(width: 10),
          ] else if (color != null) ...[
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            title,
            style: TextStyle(
              color: color ?? (isDark ? _LiveTvDesign.textTertiary : Colors.black45),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(EspnListEvent event, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _MatchCard(
        event: event,
        isDark: isDark,
        hasStream: _activeStreamIds.contains(event.game.id),
        onTap: () => _openEvent(event),
      ),
    );
  }

  Future<void> _openEvent(EspnListEvent ev) async {
    debugPrint('[LiveTV] Event tapped: "${ev.game.name}" (${ev.sport})');
    final cancelRequested = Completer<void>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 16),
                const Text('Checking database...'),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (!cancelRequested.isCompleted) {
                      cancelRequested.complete();
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    StreameastEvent? matchedEvent;
    String? videoUrl;
    String referrer = '';
    String userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    try {
      if (!cancelRequested.isCompleted) {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('live_streams')
            .select()
            .eq('id', ev.game.id)
            .maybeSingle();

        if (response != null &&
            response['video_url'] != null &&
            response['video_url'].toString().isNotEmpty) {
          videoUrl = response['video_url'];
          String? ref = response['referrer']?.toString();
          String? ua = response['user_agent']?.toString();
          final src = response['sources'];
          if ((ref == null || ref.isEmpty) && src is List && src.isNotEmpty) {
            ref = src.first['referrer']?.toString();
          }
          if ((ua == null || ua.isEmpty) && src is List && src.isNotEmpty) {
            ua = src.first['user_agent']?.toString();
          }
          referrer = ref ?? '';
          if (ua != null && ua.isNotEmpty) userAgent = ua;
          matchedEvent = StreameastEvent(
            id: ev.game.id,
            title: ev.game.name,
            url: '',
            sport: ev.sport,
            logoUrl: ev.game.thumbnailUrl,
            sources: response['sources'] as List<dynamic>?,
          );
          debugPrint('[LiveTV] Found Supabase stream for ${ev.game.name}');
        }
      }
    } catch (e, st) {
      debugPrint('[LiveTV] Supabase lookup error: $e');
      debugPrint('[LiveTV] $st');
    }

    if (!mounted) return;
    if (cancelRequested.isCompleted) return;
    Navigator.of(context).pop();

    final eventToShow = matchedEvent ??
        StreameastEvent(
          id: ev.game.id,
          title: ev.game.name,
          url: '',
          sport: ev.sport,
          logoUrl: ev.game.thumbnailUrl,
        );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveEventScreen(
          event: eventToShow,
          espnGame: ev.game,
          videoUrl: videoUrl,
          referrer: referrer,
          userAgent: userAgent,
          sources: eventToShow.sources,
        ),
      ),
    );
  }

  // Removed legacy title normalization and matching methods as we use ID matching now.

  Widget _buildSearchCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color:
            isDark ? _LiveTvDesign.bgSurfaceDark : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(_LiveTvDesign.radiusSm),
        border: Border.all(
            color: isDark ? _LiveTvDesign.borderSubtle : Colors.grey.shade300),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(
          color: isDark ? _LiveTvDesign.textPrimary : null,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Search events',
          hintStyle: TextStyle(
              color: isDark ? _LiveTvDesign.textSecondary : Colors.grey),
          prefixIcon: Icon(Icons.search_rounded,
              color: isDark ? _LiveTvDesign.textSecondary : null),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildChannelFilters(bool isDark) {
    final filters = _sportFilters;
    if (filters.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: tr('all') == 'all' ? 'All' : tr('all'),
            selected: _sportFilter == null,
            isDark: isDark,
            onTap: () => setState(() => _sportFilter = null),
          ),
          const SizedBox(width: 8),
          ...filters.map((sport) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: sport,
                  selected: _sportFilter?.toUpperCase() == sport,
                  isDark: isDark,
                  onTap: () => setState(() => _sportFilter =
                      (_sportFilter?.toUpperCase() == sport) ? null : sport),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark
              ? _LiveTvDesign.bgSurfaceDark
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(_LiveTvDesign.radiusCard),
          border: Border.all(
              color:
                  isDark ? _LiveTvDesign.borderSubtle : Colors.grey.shade300),
          boxShadow: isDark ? _LiveTvDesign.shadowCard : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off_rounded,
                size: 48,
                color: isDark ? _LiveTvDesign.textSecondary : Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Could not load events',
              style: TextStyle(
                color: isDark ? _LiveTvDesign.textPrimary : null,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: _LiveTvDesign.ctaHeight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _LiveTvDesign.primaryCta,
                  foregroundColor: _LiveTvDesign.textPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_LiveTvDesign.radiusPill)),
                  elevation: 0,
                ),
                onPressed: loadTodayEvents,
                child: Text(tr("retry"),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated pulsing live indicator dot.
class _LivePulse extends StatefulWidget {
  const _LivePulse({this.size = 8});
  final double size;

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _fade = Tween<double>(begin: 0.7, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 1.0, end: 2.4).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.6,
      height: widget.size * 2.6,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: const BoxDecoration(
                    color: _LiveTvDesign.primaryCta,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: const BoxDecoration(
                color: _LiveTvDesign.primaryCta,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Redesigned match card with sport-specific layouts.
class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.event,
    required this.isDark,
    required this.hasStream,
    required this.onTap,
  });

  final EspnListEvent event;
  final bool isDark;
  final bool hasStream;
  final VoidCallback onTap;

  bool get _isMma => isMmaOrCombatSport(
        sport: event.sport,
        league: event.league,
        game: event.game,
        title: event.game.name,
      );

  @override
  Widget build(BuildContext context) {
    final g = event.game;
    final isLive = g.isActuallyLive;
    final isCompleted = g.isEffectivelyCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_LiveTvDesign.radiusSm),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? _LiveTvDesign.bgSurfaceDark
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(_LiveTvDesign.radiusSm),
            border: Border.all(
              color: isLive
                  ? _LiveTvDesign.primaryCta.withValues(alpha: 0.35)
                  : (isDark
                      ? _LiveTvDesign.borderSubtle
                      : Colors.grey.shade200),
            ),
            boxShadow: isLive
                ? _LiveTvDesign.shadowLive
                : (isDark ? _LiveTvDesign.shadowCard : null),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Red accent strip for live events
                if (isLive)
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: _LiveTvDesign.primaryCta,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(_LiveTvDesign.radiusSm),
                        bottomLeft: Radius.circular(_LiveTvDesign.radiusSm),
                      ),
                    ),
                  ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isLive ? 13 : 16,
                    right: 16,
                    top: 14,
                    bottom: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Row
                      _buildStatusRow(g, isLive, isCompleted),
                      // MMA subtitle (card name / fight info)
                      if (_isMma) ...[
                        const SizedBox(height: 6),
                        Text(
                          (g.name.contains(':')
                                  ? g.name.split(':').last.trim()
                                  : g.name)
                              .toUpperCase(),
                          style: TextStyle(
                            color: _LiveTvDesign.primaryCta,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 14),
                      // Teams / Fighters
                      _buildCompetitorRow(
                        g.away?.displayName ?? 'TBD',
                        g.away?.logoUrl,
                        (!_isMma && (isLive || isCompleted))
                            ? g.away?.score
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _buildCompetitorRow(
                        g.home?.displayName ?? 'TBD',
                        g.home?.logoUrl,
                        (!_isMma && (isLive || isCompleted))
                            ? g.home?.score
                            : null,
                      ),
                      const SizedBox(height: 12),
                      // Footer: league / sport / type
                      Text(
                        '${event.league.trim().toUpperCase() == event.sport.trim().toUpperCase() ? event.league : "${event.league} · ${event.sport}"}${g.competitionType != null ? " · ${g.competitionType}" : ""}'
                            .toUpperCase(),
                        style: TextStyle(
                          color: isDark
                              ? _LiveTvDesign.textTertiary
                              : Colors.grey.shade400,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
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
    ),
  );
}

  Widget _buildStatusRow(
      EspnScoreboardGame g, bool isLive, bool isCompleted) {
    return Row(
      children: [
        if (isLive) ...[
          const _LivePulse(size: 8),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              color: _LiveTvDesign.primaryCta,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            _getStatusText(g),
            style: TextStyle(
              color: isLive
                  ? _LiveTvDesign.primaryCta
                  : (isDark
                      ? _LiveTvDesign.textSecondary
                      : Colors.grey.shade600),
              fontSize: 12,
              fontWeight: isLive ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompetitorRow(
      String name, String? logoUrl, String? score) {
    return Row(
      children: [
        _CompetitorLogo(logoUrl: logoUrl, isDark: isDark, isMma: _isMma),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: isDark ? _LiveTvDesign.textPrimary : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (score != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? _LiveTvDesign.bgSurfaceElevated
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score,
              style: TextStyle(
                color: isDark ? _LiveTvDesign.textPrimary : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _getStatusText(EspnScoreboardGame g) {
    if (g.isActuallyLive) return g.timeOrStatus ?? 'LIVE';
    if (g.isEffectivelyCompleted) return 'FINAL';
    return g.startTimeLocal ?? 'SCHEDULED';
  }
}

/// Competitor logo — circular for MMA headshots, rounded square for teams.
class _CompetitorLogo extends StatelessWidget {
  const _CompetitorLogo(
      {this.logoUrl, required this.isDark, this.isMma = false});
  final String? logoUrl;
  final bool isDark;
  final bool isMma;

  @override
  Widget build(BuildContext context) {
    final radius = isMma ? 999.0 : 8.0;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: CachedNetworkImage(
                imageUrl: logoUrl!,
                width: 34,
                height: 34,
                fit: isMma ? BoxFit.cover : BoxFit.contain,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              ),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Icon(
      isMma ? Icons.person_rounded : Icons.sports_rounded,
      size: 18,
      color: isDark ? _LiveTvDesign.textSecondary : Colors.grey,
    );
  }
}

/// Chip for channel filter (All, NBA, NFL, ...).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_LiveTvDesign.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? _LiveTvDesign.primaryCta
                : (isDark
                    ? _LiveTvDesign.bgSurfaceDark
                    : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(_LiveTvDesign.radiusPill),
            border: Border.all(
              color: selected
                  ? _LiveTvDesign.primaryCta
                  : (isDark
                      ? _LiveTvDesign.borderSubtle
                      : Colors.grey.shade400),
              width: selected ? 0 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color:
                          _LiveTvDesign.primaryCta.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? _LiveTvDesign.textPrimary
                    : (isDark
                        ? _LiveTvDesign.textPrimary
                        : Colors.grey.shade800),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

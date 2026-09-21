import 'package:reelriot/services/player/caffeine_player_controller.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:reelriot/functions/video_utils.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/models/espn_scoreboard.dart';
import 'package:reelriot/models/live_tv.dart';
import 'package:reelriot/screens/tv_screens/live_tv_screen.dart';
import 'package:reelriot/utils/helpers/web_page.dart';
import 'package:reelriot/widgets/event_chatroom.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reelriot/services/wakelock_service.dart';
import 'package:url_launcher/url_launcher.dart';

// design.json tokens: cinematic, dark-first, primary red
abstract class _Design {
  static const Color bgCanvasDark = Color(0xFF030712); // gray-950
  static const Color bgSurfaceDark = Color(0xFF0B0F14); // gray-900
  static const Color bgSurfaceElevated = Color(0xFF111827); // gray-800
  static const Color primaryCta = Color(0xFFDC2626); // primary-600
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB8FFFFFF); // rgba(255,255,255,0.72)
  static const Color textTertiary = Color(0x66FFFFFF);
  static const Color borderSubtle = Color(0x14FFFFFF);
  static const double radiusSm = 12.0;
  static const double radiusPill = 9999.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
}

class LiveEventScreen extends StatefulWidget {
  const LiveEventScreen({
    super.key,
    required this.event,
    this.espnGame,
    this.videoUrl,
    this.referrer = '',
    this.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    this.sources,
  });

  final StreameastEvent event;
  final EspnScoreboardGame? espnGame;
  final String? videoUrl;
  final String referrer;
  final String userAgent;
  final List<dynamic>? sources;

  /// Match event title "Team A vs Team B" to an ESPN game by name overlap.
  static EspnScoreboardGame? findMatchingGame(
      String title, List<EspnScoreboardGame> games) {
    final vs = title.split(RegExp(r'\s+vs\s+', caseSensitive: false));
    if (vs.length != 2) return null;

    final stopWords = {
      'at',
      'the',
      'of',
      'vs',
      '@',
      'and',
      'a',
      'in',
      'on',
      'live',
      'ft'
    };

    final left = vs[0]
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();
    final right = vs[1]
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();

    if (left.isEmpty || right.isEmpty) return null;

    final gameNames = games.map((g) => g.name.toLowerCase()).toList();

    for (int i = 0; i < gameNames.length; i++) {
      final name = gameNames[i];
      final leftMatch = left.any((w) => name.contains(w));
      final rightMatch = right.any((w) => name.contains(w));

      if (leftMatch && rightMatch) return games[i];
    }
    return null;
  }

  @override
  State<LiveEventScreen> createState() => _LiveEventScreenState();
}

class _LiveEventScreenState extends State<LiveEventScreen> with WidgetsBindingObserver {
  CaffeinePlayerController? _controller;
  EspnScoreboardGame? _scoreGame;
  String? _currentUrl;
  String? _currentReferrer;
  String? _currentUserAgent;
  List<dynamic> _sources = [];
  bool _isEmbed = false;
  String? _embedUrl;
  int _selectedMobileTab = 0; // 0 = Chat, 1 = Info & Mirrors

  static bool isEmbedUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('vixsrc.to') ||
        lower.contains('vidsrc.to') ||
        lower.contains('vidsrc.me') ||
        lower.contains('/embed/') ||
        lower.contains('embed.su') ||
        lower.contains('sportsembed.su') ||
        lower.contains('watchfooty.st') ||
        lower.contains('streameast') ||
        (!lower.contains('.m3u8') && !lower.contains('.mp4') && !lower.contains('.mkv'));
  }

  bool get _hasStream =>
      (widget.videoUrl != null && widget.videoUrl!.trim().isNotEmpty) ||
      (_currentUrl != null && _currentUrl!.trim().isNotEmpty);

  String? get _effectiveVideoUrl => _currentUrl?.trim().isNotEmpty == true
      ? _currentUrl
      : widget.videoUrl;

  String get _effectiveReferrer => _currentReferrer ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockService.enable();
    _currentUrl = widget.videoUrl;
    _currentReferrer = widget.referrer;
    _currentUserAgent = widget.userAgent;
    _sources = widget.sources ?? [];
    if (_hasStream) _initPlayer();
    if (widget.event.sport?.toLowerCase() == 'nba') _loadNbaScore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WakelockService.enable();
    }
  }

  Future<void> _loadNbaScore() async {
    final response = await fetchNbaScoreboard();
    if (!mounted) return;
    final parsed = parseLiveEventTitle(widget.event.title);
    final game = response != null
        ? LiveEventScreen.findMatchingGame(parsed.title, response.games)
        : null;
    setState(() => _scoreGame = game);
  }

  void _onStreamError() {
    if (!mounted) return;
    debugPrint('[LiveEventScreen] ❌ Native stream failed. Attempting next mirror...');
    if (_sources.isNotEmpty) {
      final currentIndex = _sources.indexWhere((s) => s['url'] == _currentUrl);
      if (currentIndex >= 0 && currentIndex < _sources.length - 1) {
        final nextSource = _sources[currentIndex + 1];
        final nextUrl = nextSource['url']?.toString();
        if (nextUrl != null && nextUrl.isNotEmpty) {
          debugPrint('[LiveEventScreen] 🔄 Auto-switching to mirror: ${nextSource['name'] ?? nextUrl}');
          setState(() {
            _currentUrl = nextUrl;
            _currentReferrer = nextSource['referrer']?.toString() ?? '';
            final ua = nextSource['user_agent']?.toString();
            if (ua != null && ua.isNotEmpty) _currentUserAgent = ua;
          });
          _initPlayerWithUrl(nextUrl);
          return;
        }
      }
    }
  }

  void _initPlayerWithUrl(String url) {
    _controller?.dispose();
    _controller = null;

    if (isEmbedUrl(url)) {
      setState(() {
        _isEmbed = true;
        _embedUrl = url;
      });
      return;
    }

    setState(() {
      _isEmbed = false;
      _embedUrl = null;
    });

    final c = CaffeinePlayerController();
    c.addEventsListener((event) {
      if (event.type == CaffeinePlayerEventType.error) {
        _onStreamError();
      }
    });

    c.setDataSource(
      url,
      liveStream: true,
      headers: {
        'User-Agent': _currentUserAgent ?? widget.userAgent,
        'Referer': _effectiveReferrer,
        'Origin': _getOrigin(_effectiveReferrer),
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );
    _controller = c;
  }

  String _getOrigin(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme.isEmpty || uri.host.isEmpty) return url.replaceAll(RegExp(r'/$'), '');
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return url.replaceAll(RegExp(r'/$'), '');
    }
  }

  void _initPlayer() {
    final url = _effectiveVideoUrl;
    if (url != null && url.isNotEmpty) _initPlayerWithUrl(url);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockService.disable();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseLiveEventTitle(widget.event.title);
    final appDep = Provider.of<AppDependencyProvider>(context);
    final isChatEnabled = appDep.isMobileChatroomEnabled;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 720;

        return Scaffold(
          backgroundColor: _Design.bgCanvasDark,
          appBar: AppBar(
            backgroundColor: _Design.bgSurfaceDark,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Material(
                color: _Design.borderSubtle,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 20, color: _Design.textPrimary),
                  ),
                ),
              ),
            ),
            centerTitle: !isLargeScreen,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _Design.primaryCta,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    parsed.title,
                    style: const TextStyle(
                      color: _Design.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              if (!isLargeScreen && isChatEnabled)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    icon: Icon(
                      _selectedMobileTab == 0
                          ? Icons.info_outline_rounded
                          : Icons.chat_bubble_outline_rounded,
                      color: _Design.textPrimary,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedMobileTab = _selectedMobileTab == 0 ? 1 : 0;
                      });
                    },
                    tooltip: _selectedMobileTab == 0 ? 'Match Details' : 'Live Chat',
                  ),
                ),
            ],
            iconTheme: const IconThemeData(color: _Design.textPrimary),
          ),
          body: isLargeScreen
              ? _buildLargeScreenLayout(parsed, isChatEnabled)
              : _buildMobileLayout(parsed, isChatEnabled),
        );
      },
    );
  }

  // ── Large Screen Dual-Pane Layout (Tablet / Foldable / Desktop) ──
  Widget _buildLargeScreenLayout(LiveEventTitleParsed parsed, bool isChatEnabled) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column (60-65%): Video Player + Score Card + Mirrors
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(_Design.radiusSm),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildVideoPlayer(),
                  ),
                ),
                const SizedBox(height: 16),
                _EventInfoSection(
                  event: widget.event,
                  espnGame: widget.espnGame,
                  parsed: parsed,
                  scoreGame: _scoreGame,
                  sources: _sources,
                  currentUrl: _currentUrl,
                  onSourceChanged: _switchSource,
                ),
              ],
            ),
          ),
        ),
        // Vertical Divider
        Container(width: 1, color: _Design.borderSubtle),
        // Right Column (35-40%): Dedicated Full-Height Chatroom
        Expanded(
          flex: 4,
          child: isChatEnabled
              ? EventChatroom(
                  roomId: widget.event.id,
                  roomName: widget.event.title,
                  showHeader: true,
                )
              : Container(
                  color: _Design.bgSurfaceDark,
                  child: const Center(
                    child: Text(
                      'Chatroom disabled',
                      style: TextStyle(color: _Design.textTertiary),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Mobile Single-Column Layout (Phone Portrait) ──
  Widget _buildMobileLayout(LiveEventTitleParsed parsed, bool isChatEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Video Player pinned on top in 16:9
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildVideoPlayer(),
        ),
        // Tab Selector (Chat vs Match Info) if chat is enabled
        if (isChatEnabled)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: _Design.bgSurfaceDark,
              border: Border(bottom: BorderSide(color: _Design.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MobileTabButton(
                    label: 'LIVE CHAT',
                    icon: Icons.chat_bubble_rounded,
                    isSelected: _selectedMobileTab == 0,
                    onTap: () => setState(() => _selectedMobileTab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MobileTabButton(
                    label: 'MATCH & SERVERS',
                    icon: Icons.sports_rounded,
                    isSelected: _selectedMobileTab == 1,
                    onTap: () => setState(() => _selectedMobileTab = 1),
                  ),
                ),
              ],
            ),
          ),
        // Content Area: Chat or Match Info
        Expanded(
          child: IndexedStack(
            index: isChatEnabled ? _selectedMobileTab : 1,
            children: [
              if (isChatEnabled)
                EventChatroom(
                  roomId: widget.event.id,
                  roomName: widget.event.title,
                  showHeader: false,
                )
              else
                const SizedBox.shrink(),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _EventInfoSection(
                  event: widget.event,
                  espnGame: widget.espnGame,
                  parsed: parsed,
                  scoreGame: _scoreGame,
                  sources: _sources,
                  currentUrl: _currentUrl,
                  onSourceChanged: _switchSource,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    if (_isEmbed && _embedUrl != null) {
      return UrlWebPage(url: _embedUrl!);
    }
    if (_hasStream && _controller != null) {
      return Container(
        color: Colors.black,
        child: mkv.Video(
          controller: _controller!.videoController,
          controls: mkv.MaterialVideoControls,
          wakelock: false,
        ),
      );
    }
    return _NoStreamPlaceholder(eventPageUrl: widget.event.url);
  }

  void _switchSource(Map<String, dynamic> source) {
    final url = source['url']?.toString();
    final ref = source['referrer']?.toString() ?? '';
    final ua = source['user_agent']?.toString();
    if (url == null || url == _currentUrl) return;
    setState(() {
      _currentUrl = url;
      _currentReferrer = ref;
      if (ua != null && ua.isNotEmpty) _currentUserAgent = ua;
    });
    _initPlayer();
  }
}

class _MobileTabButton extends StatelessWidget {
  const _MobileTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? _Design.primaryCta.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _Design.primaryCta : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? _Design.primaryCta : _Design.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? _Design.textPrimary : _Design.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoStreamPlaceholder extends StatelessWidget {
  const _NoStreamPlaceholder({this.eventPageUrl});

  final String? eventPageUrl;

  @override
  Widget build(BuildContext context) {
    final hasEventPage =
        eventPageUrl != null && eventPageUrl!.trim().isNotEmpty;
    return Container(
      color: _Design.bgSurfaceDark,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: _Design.space6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_rounded, size: 56, color: _Design.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No stream available',
              style: TextStyle(
                color: _Design.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasEventPage
                  ? 'Open the event page to watch in browser or in-app.'
                  : 'Try again later or choose another mirror.',
              style: const TextStyle(
                color: _Design.textTertiary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasEventPage) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _openInBrowser(context, eventPageUrl!),
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text('Open in browser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Design.primaryCta,
                  side: const BorderSide(color: _Design.primaryCta),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<void> _openInBrowser(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _EventInfoSection extends StatelessWidget {
  final StreameastEvent event;
  final EspnScoreboardGame? espnGame;
  final LiveEventTitleParsed parsed;
  final EspnScoreboardGame? scoreGame;
  final List<dynamic>? sources;
  final String? currentUrl;
  final Function(Map<String, dynamic>) onSourceChanged;

  const _EventInfoSection({
    required this.event,
    this.espnGame,
    required this.parsed,
    this.scoreGame,
    this.sources,
    this.currentUrl,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayGame = scoreGame ?? espnGame;
    final isCombat = isMmaOrCombatSport(
      sport: event.sport,
      game: displayGame,
      title: event.title,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCombat &&
            displayGame != null &&
            (displayGame.isLive || displayGame.isEffectivelyCompleted)) ...[
          _ScoreRow(game: displayGame),
          const SizedBox(height: 16),
        ],
        // Match Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _Design.bgSurfaceDark,
            borderRadius: BorderRadius.circular(_Design.radiusSm),
            border: Border.all(color: _Design.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogo(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (parsed.status != null && parsed.status!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          parsed.status!,
                          style: const TextStyle(
                            color: _Design.primaryCta,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    Text(
                      parsed.title,
                      style: const TextStyle(
                        color: _Design.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (espnGame != null && espnGame!.competitionType != null)
                          ? '${espnGame!.competitionType} · ${event.sport ?? ""}'.toUpperCase()
                          : (event.sport ?? "").toUpperCase(),
                      style: const TextStyle(
                        color: _Design.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Available Mirrors Section
        if (sources != null && sources!.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'AVAILABLE SERVERS & MIRRORS',
            style: TextStyle(
              color: _Design.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sources!.length,
              itemBuilder: (context, index) {
                final source = sources![index];
                final name = source['name'] ?? 'Server ${index + 1}';
                final url = source['url'] ?? '';
                final isSelected = url == currentUrl;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) onSourceChanged(source);
                    },
                    backgroundColor: _Design.bgSurfaceDark,
                    selectedColor: _Design.primaryCta,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_Design.radiusSm),
                      side: BorderSide(
                        color: isSelected
                            ? _Design.primaryCta
                            : _Design.borderSubtle,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : _Design.textSecondary,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLogo() {
    final url = espnGame?.thumbnailUrl ?? event.logoUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_Design.radiusSm),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (_, __) => _logoPlaceholder(),
          errorWidget: (_, __, ___) => _logoPlaceholder(),
        ),
      );
    }
    return _logoPlaceholder();
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _Design.primaryCta.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(_Design.radiusSm),
      ),
      child: const Icon(Icons.live_tv_rounded,
          color: _Design.primaryCta, size: 26),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.game});

  final EspnScoreboardGame game;

  @override
  Widget build(BuildContext context) {
    if (game.isCombatSport) return const SizedBox.shrink();
    final away = game.away;
    final home = game.home;
    final status = game.status;
    if (away == null && home == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _Design.bgSurfaceDark,
        borderRadius: BorderRadius.circular(_Design.radiusSm),
        border: Border.all(color: _Design.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TeamScore(
                  name: away?.displayName ?? 'Away',
                  score: away?.score ?? '0',
                  logoUrl: away?.logoUrl,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VS',
                      style: TextStyle(
                        color: _Design.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (status != null && status.shortDetail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          status.shortDetail,
                          style: const TextStyle(
                            color: _Design.primaryCta,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _TeamScore(
                  name: home?.displayName ?? 'Home',
                  score: home?.score ?? '0',
                  logoUrl: home?.logoUrl,
                  isHome: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.name,
    required this.score,
    this.logoUrl,
    this.isHome = false,
  });

  final String name;
  final String score;
  final String? logoUrl;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isHome ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isHome) ...[
          _buildLogo(),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment:
                isHome ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _Design.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                score,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (isHome) ...[
          const SizedBox(width: 10),
          _buildLogo(),
        ],
      ],
    );
  }

  Widget _buildLogo() {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: logoUrl!,
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          placeholder: (_, __) => _smallLogoPlaceholder(),
          errorWidget: (_, __, ___) => _smallLogoPlaceholder(),
        ),
      );
    }
    return _smallLogoPlaceholder();
  }

  Widget _smallLogoPlaceholder() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.sports_rounded,
          color: _Design.textSecondary, size: 18),
    );
  }
}


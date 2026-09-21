import 'package:reelriot/services/player/caffeine_player_controller.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:reelriot/functions/video_utils.dart';
import 'package:reelriot/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reelriot/services/wakelock_service.dart';
import 'package:reelriot/screens/player/widgets/glass_player_controls.dart';
import 'package:reelriot/screens/player/widgets/cast_bottom_sheet.dart';

class LivePlayer extends StatefulWidget {
  const LivePlayer(
      {required this.videoUrl,
      required this.colors,
      required this.channelName,
      required this.referrer,
      required this.userAgent,
      super.key});
  final String videoUrl;
  final List<Color> colors;
  final String channelName;
  final String referrer;
  final String userAgent;

  @override
  State<LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends State<LivePlayer> with WidgetsBindingObserver {
  late CaffeinePlayerController _betterPlayerController;

  final GlobalKey _betterPlayerKey = GlobalKey();
  DateTime? _loadStartTime;
  DateTime? _bufferingStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStartTime = DateTime.now();

    AnalyticsService.instance.trackQoSEvent('Live Playback Attempt', {
      'channel': widget.channelName,
      'url_host': Uri.tryParse(widget.videoUrl)?.host,
    });

    _betterPlayerController = CaffeinePlayerController();
    _betterPlayerController.setDataSource(
      widget.videoUrl,
      liveStream: true,
      headers: {
        'User-Agent': widget.userAgent,
        'Referer': widget.referrer,
      },
    );

    // Force landscape, hide status/nav bars, and keep screen on
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockService.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WakelockService.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _betterPlayerController.dispose();
    
    // Restore orientations, system overlays, and disable wakelock
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockService.disable();

    super.dispose();
  }

  void _openCastSheet() {
    if (!mounted) return;
    if (_betterPlayerController.isPlaying()) {
      _betterPlayerController.pause();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CastBottomSheet(
        streamUrl: widget.videoUrl,
        title: widget.channelName,
        headers: {
          'User-Agent': widget.userAgent,
          'Referer': widget.referrer,
        },
      ),
    ).then((_) {
      if (mounted) {
        _betterPlayerController.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        leading: null,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Center(
            child: mkv.Video(
              controller: _betterPlayerController.videoController,
              controls: mkv.NoVideoControls,
              wakelock: false,
            ),
          ),
          GlassPlayerControls(
            controller: _betterPlayerController,
            title: widget.channelName,
            isLive: true,
            onBack: () => Navigator.of(context).pop(),
            onSubtitlePressed: () {}, // Subtitles usually not available for live
            onResolutionPressed: () {}, // Handle resolution switcher if needed
            onCastPressed: _openCastSheet,
          ),
        ],
      ),
    );
  }
}


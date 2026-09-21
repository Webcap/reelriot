import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/services/quality_service.dart';

class QualityBadge extends StatefulWidget {
  final int? mediaId;
  final String mediaType;
  final String? releaseDate;
  final String? initialQuality;
  final bool compact;

  const QualityBadge({
    super.key,
    required this.mediaId,
    this.mediaType = 'movie',
    this.releaseDate,
    this.initialQuality,
    this.compact = true,
  });

  @override
  State<QualityBadge> createState() => _QualityBadgeState();
}

class _QualityBadgeState extends State<QualityBadge> {
  String? _quality;

  @override
  void initState() {
    super.initState();
    // 1. Synchronous initial estimate (Zero-CLS)
    _quality = widget.initialQuality ??
        QualityService.instance.getQualitySync(
          releaseDate: widget.releaseDate,
          isMovie: widget.mediaType == 'movie',
        );

    // 2. Fetch authoritative quality from Caffeine API asynchronously
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveAuthoritativeQuality();
    });
  }

  @override
  void didUpdateWidget(covariant QualityBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId ||
        oldWidget.mediaType != widget.mediaType ||
        oldWidget.releaseDate != widget.releaseDate) {
      _quality = widget.initialQuality ??
          QualityService.instance.getQualitySync(
            releaseDate: widget.releaseDate,
            isMovie: widget.mediaType == 'movie',
          );
      _resolveAuthoritativeQuality();
    }
  }

  Future<void> _resolveAuthoritativeQuality() async {
    if (!mounted) return;
    final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
    final resolved = await QualityService.instance.getQualityAsync(
      type: widget.mediaType,
      id: widget.mediaId,
      releaseDate: widget.releaseDate,
      caffeineBaseUrl: appDep.caffeineAPIURL,
    );

    if (mounted && resolved != null && resolved != _quality) {
      setState(() {
        _quality = resolved;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _quality?.toUpperCase();
    if (q == null || q.isEmpty) {
      return const SizedBox.shrink();
    }

    // Semantic colors adhering to frontend standards
    Color bgColor;
    Color textColor = Colors.white;
    Border? border;

    switch (q) {
      case 'CAM':
        // Semantic danger ramp: high visibility warning of cam quality
        bgColor = const Color(0xFFDC2626).withValues(alpha: 0.92);
        border = Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6), width: 0.75);
        break;
      case 'SOON':
        // Semantic warning ramp: amber background, high-contrast dark text
        bgColor = const Color(0xFFD97706).withValues(alpha: 0.95);
        textColor = const Color(0xFF1E1B18);
        border = Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.7), width: 0.75);
        break;
      case 'HD':
      default:
        // Subtle dark frosted pill mirroring star rating pill
        bgColor = Colors.black.withValues(alpha: 0.70);
        border = Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.75);
        break;
    }

    final double padH = widget.compact ? 5.0 : 6.0;
    final double padV = 2.0;
    final double fontSize = widget.compact ? 9.5 : 11.0;

    return Semantics(
      label: 'Quality: $q',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.compact ? 6 : 4),
          border: border,
        ),
        child: Text(
          q,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            height: 1.1,
            fontFamily: 'PoppinsSB',
          ),
        ),
      ),
    );
  }
}

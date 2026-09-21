import 'package:flutter/material.dart';
import 'package:reelriot/models/tv.dart';
import 'package:reelriot/provider/bookmarks_provider.dart';
import 'package:reelriot/functions/network.dart';
import 'package:reelriot/api/endpoints.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:reelriot/widgets/bouncing_tappable.dart';
import 'package:reelriot/widgets/user_rating_widget.dart';
import 'package:reelriot/services/offline_sync_manager.dart';
import 'package:reelriot/widgets/quality_badge.dart';

// ── Design tokens (design.json) ─────────────────────────────────────────────
class _C {
  static const primary = Color(0xFFDC2626);
  static const ratingGold = Color(0xFFEAB308);

  static const bgElevatedDark = Color(0x0DFFFFFF);
  static const bgElevatedLight = Color(0xFFF1F5F9);
  static const borderDark = Color(0x14FFFFFF);
  static const borderLight = Color(0x140F172A);
  static const textSecDark = Color(0xB8FFFFFF);
  static const textSecLight = Color(0xFF475569);
}

class TVDetailOptions extends StatefulWidget {
  const TVDetailOptions({super.key, required this.tvSeries});

  final TV tvSeries;

  @override
  State<TVDetailOptions> createState() => _TVDetailOptionsState();
}

class _TVDetailOptionsState extends State<TVDetailOptions> {
  bool? isBookmarked;
  TVDetails? tvDetails;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetails();
    });
  }

  Future<void> _fetchDetails() async {
    final lang = Provider.of<SettingsProvider>(context, listen: false).appLanguage;
    final isProxyEnabled = Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final api = Endpoints.tvDetailsUrl(widget.tvSeries.id!, lang);
    
    final details = await fetchTVDetails(api, isProxyEnabled, proxyUrl);
    if (mounted) {
      setState(() => tvDetails = details);
    }
  }

  Future<void> _checkBookmark() async {
    final provider = Provider.of<BookmarksProvider>(context, listen: false);
    final b = await provider.containsTV(widget.tvSeries.id!);
    if (mounted) setState(() => isBookmarked = b);
    if (mounted && b) await provider.updateTV(widget.tvSeries);
  }

  @override
  Widget build(BuildContext bContext) {
    final isDark = Theme.of(bContext).brightness == Brightness.dark;
    final elevated = isDark ? _C.bgElevatedDark : _C.bgElevatedLight;
    final border = isDark ? _C.borderDark : _C.borderLight;
    final textSec = isDark ? _C.textSecDark : _C.textSecLight;

    final avg = widget.tvSeries.voteAverage;
    final ratingStr = avg != null && avg > 0
        ? (avg == avg.truncateToDouble()
            ? avg.toStringAsFixed(0)
            : avg.toStringAsFixed(1))
        : null;

    final screenWidth = MediaQuery.sizeOf(bContext).width;
    final isTablet = screenWidth >= 600;

    return Consumer<BookmarksProvider>(
      builder: (ctx, provider, _) {
        // ── Format Genres ───────────────────────────────────────────────
        final genres = tvDetails?.genres?.map((g) => g.genreName).where((n) => n != null && n.isNotEmpty).take(3).join('  •  ');
        
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 32 : 16,
                12,
                isTablet ? 32 : 16,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Genres Row ────────────────────────────────────────────
                  if (genres != null && genres.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        genres,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textSec,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    
                  // ── Meta Row + Bookmark ───────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Meta items
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (tvDetails?.numberOfSeasons != null && tvDetails!.numberOfSeasons! > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.layers_rounded, size: 14, color: textSec),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${tvDetails!.numberOfSeasons} ${tvDetails!.numberOfSeasons == 1 ? tr("season") : tr("seasons")}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: textSec,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                              
                            _Badge(text: 'TV-14', textSec: textSec, border: border, elevated: elevated),
                            QualityBadge(
                              mediaId: widget.tvSeries.id,
                              mediaType: 'tv',
                              releaseDate: widget.tvSeries.firstAirDate,
                              compact: false,
                            ),
                            
                            if (ratingStr != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _C.ratingGold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'IMDb - $ratingStr/10',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _C.ratingGold,
                                    fontFamily: 'PoppinsSB',
                                  ),
                                ),
                              ),

                            if (widget.tvSeries.id != null)
                              UserRatingButton(
                                mediaType: 'tv',
                                mediaId: widget.tvSeries.id!,
                                title: widget.tvSeries.name ?? 'TV Series',
                              ),
                          ],
                        ),
                      ),
                      
                      // Bookmark button - Instant Optimistic Toggle + Tactile Micro-interaction
                      BouncingTappable(
                        onTap: () {
                          if (widget.tvSeries.id == null) return;
                          final oldState = isBookmarked;
                          final newState = !(oldState ?? false);

                          // 1. Optimistic instant visual update (<16ms)
                          setState(() => isBookmarked = newState);

                          // 2. Background persistence + rollback safety
                          Future(() async {
                            try {
                              if (newState) {
                                await provider.addTV(widget.tvSeries);
                              } else {
                                await provider.removeTV(widget.tvSeries.id!);
                              }
                            } catch (_) {
                              // If failed, enqueue for offline sync and rollback UI
                              await OfflineSyncManager.instance.enqueueAction(
                                type: newState ? 'add_tv' : 'remove_tv',
                                payload: widget.tvSeries.toJson(),
                              );
                            }
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: elevated,
                            border: Border.all(color: border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: (isBookmarked == true
                                        ? _C.primary
                                        : Colors.transparent)
                                    .withValues(alpha: 0.2),
                                blurRadius: isBookmarked == true ? 10 : 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            isBookmarked == true
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 20,
                            color: isBookmarked == true ? _C.primary : textSec,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color textSec;
  final Color border;
  final Color elevated;

  const _Badge({
    required this.text,
    required this.textSec,
    required this.border,
    required this.elevated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textSec,
          fontFamily: 'PoppinsSB',
        ),
      ),
    );
  }
}

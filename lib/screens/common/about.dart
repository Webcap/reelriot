import 'package:reelriot/provider/settings_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/utils/globals.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reelriot/utils/version_helper.dart';
import 'package:reelriot/utils/flavor_config.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ─── Design tokens (design.json) ─────────────────────────────────────────────
class _Design {
  static const primary = Color(0xFFDC2626);

  static const bgCanvasDark = Color(0xFF030712);
  static const bgCanvasLight = Color(0xFFF8FAFC);
  static const bgSurfaceDark = Color(0xFF0B0F14);
  static const bgSurfaceLight = Color(0xFFFFFFFF);
  static const borderDark = Color(0x14FFFFFF);
  static const borderLight = Color(0x140F172A);
  static const iconBgDark = Color(0x14FFFFFF);

  static const textPrimDark = Color(0xFFFFFFFF);
  static const textPrimLight = Color(0xFF0B0F14);
  static const textSecDark = Color(0xB8FFFFFF);
  static const textSecLight = Color(0xFF64748B);

  static const radiusMd = 16.0;
  static const screenPadH = 24.0;
  static const space2 = 8.0;
  static const space4 = 16.0;
  static const shadowCard = BoxShadow(
    color: Color(0x38000000),
    blurRadius: 30,
    offset: Offset(0, 10),
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isDark = themeMode == 'dark' || themeMode == 'amoled';
    final bg = isDark ? _Design.bgCanvasDark : _Design.bgCanvasLight;
    final surface = isDark ? _Design.bgSurfaceDark : _Design.bgSurfaceLight;
    final textPrim = isDark ? _Design.textPrimDark : _Design.textPrimLight;
    final textSec = isDark ? _Design.textSecDark : _Design.textSecLight;
    final border = isDark ? _Design.borderDark : _Design.borderLight;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        centerTitle: isTablet,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrim,
            size: 20,
          ),
          onPressed: () => Navigator.maybePop(context),
          tooltip: tr("back"),
        ),
        title: Text(
          tr("about"),
          style: TextStyle(
            color: textPrim,
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'PoppinsSB',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : _Design.screenPadH,
            vertical: isTablet ? 28 : 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  // 1. Hero Header Card
                  _buildHeroHeader(isTablet, isDark, surface, border, textPrim, textSec),
                  SizedBox(height: isTablet ? 24 : 16),

                  // 2. Responsive Content Grid / Stack
                  if (isTablet)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column
                        Expanded(
                          child: Column(
                            children: [
                              _buildCommunityCard(surface, border, textPrim, textSec),
                              const SizedBox(height: 16),
                              _buildDisclaimerCard(surface, border, textPrim, textSec),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Right Column
                        Expanded(
                          child: Column(
                            children: [
                              _buildTmdbCard(surface, border, textPrim, textSec),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildCommunityCard(surface, border, textPrim, textSec),
                        const SizedBox(height: 16),
                        _buildDisclaimerCard(surface, border, textPrim, textSec),
                        const SizedBox(height: 16),
                        _buildTmdbCard(surface, border, textPrim, textSec),
                      ],
                    ),

                  const SizedBox(height: 32),

                  // 3. Clean Copyright Footer (Removed Made by Webcap & Made in NY)
                  Text(
                    '© 2016 – ${DateTime.now().year} ReelRiot. All rights reserved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSec,
                      fontSize: 13,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero Header ────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(
    bool isTablet,
    bool isDark,
    Color surface,
    Color border,
    Color textPrim,
    Color textSec,
  ) {
    final appIconWidget = Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 1.5),
        boxShadow: const [_Design.shadowCard],
      ),
      padding: const EdgeInsets.all(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          appConfig.appIcon,
          height: isTablet ? 90 : 80,
          width: isTablet ? 90 : 80,
          fit: BoxFit.contain,
        ),
      ),
    );

    if (isTablet) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1),
          boxShadow: const [_Design.shadowCard],
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            appIconWidget,
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ReelRiot',
                        style: TextStyle(
                          color: textPrim,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'PoppinsSB',
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildVersionPill(),
                      if (FlavorConfig.isDev) ...[
                        const SizedBox(width: 8),
                        _buildDevBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your All-in-One Entertainment & Streaming Hub',
                    style: TextStyle(
                      color: textSec,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildHeaderTag(Icons.movie_filter_rounded, 'Movies & TV'),
                      const SizedBox(width: 8),
                      _buildHeaderTag(Icons.sports_soccer_rounded, 'Live Sports'),
                      const SizedBox(width: 8),
                      _buildHeaderTag(Icons.tv_rounded, 'TV Sync'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Phone Hero Header
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
        boxShadow: const [_Design.shadowCard],
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          appIconWidget,
          const SizedBox(height: 16),
          Text(
            'ReelRiot',
            style: TextStyle(
              color: textPrim,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFamily: 'PoppinsSB',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your All-in-One Entertainment Hub',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSec,
              fontSize: 13.5,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildVersionPill(),
              if (FlavorConfig.isDev) ...[
                const SizedBox(width: 8),
                _buildDevBadge(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _Design.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Design.primary.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _Design.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _Design.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'PoppinsSB',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _Design.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Design.primary.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        'v$currentAppVersion',
        style: const TextStyle(
          color: _Design.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'PoppinsSB',
        ),
      ),
    );
  }

  Widget _buildDevBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.35), width: 1),
      ),
      child: const Text(
        'DEV BUILD',
        style: TextStyle(
          color: Colors.blue,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          fontFamily: 'PoppinsSB',
        ),
      ),
    );
  }

  // ── Community Card ─────────────────────────────────────────────────────────
  Widget _buildCommunityCard(Color surface, Color border, Color textPrim, Color textSec) {
    return _AboutCard(
      surface: surface,
      border: border,
      child: InkWell(
        onTap: () {
          launchUrl(
            Uri.parse('https://discord.gg/3QYKXrwtwM'),
            mode: LaunchMode.externalApplication,
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF5865F2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF5865F2).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.discord,
                    color: Color(0xFF5865F2),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join Community Discord',
                      style: TextStyle(
                        color: textPrim,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'PoppinsSB',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr("bug_notice"),
                      style: TextStyle(
                        color: textSec,
                        fontSize: 12.5,
                        fontFamily: 'Poppins',
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: textSec.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.open_in_new_rounded,
                  color: textSec,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Disclaimer Card ────────────────────────────────────────────────────────
  Widget _buildDisclaimerCard(Color surface, Color border, Color textPrim, Color textSec) {
    return _AboutCard(
      surface: surface,
      border: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.amber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Content Disclaimer',
                style: TextStyle(
                  color: textPrim,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'PoppinsSB',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'ReelRiot does not host, upload, or manage any media files on its servers. All streaming links and metadata are indexed from public third-party services.',
            style: TextStyle(
              color: textSec,
              fontSize: 12.5,
              fontFamily: 'Poppins',
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ── TMDB Card ──────────────────────────────────────────────────────────────
  Widget _buildTmdbCard(Color surface, Color border, Color textPrim, Color textSec) {
    return _AboutCard(
      surface: surface,
      border: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF01B4E4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.movie_outlined,
                  color: Color(0xFF01B4E4),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Metadata & Imagery',
                style: TextStyle(
                  color: textPrim,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'PoppinsSB',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tr("endorsment"),
            style: TextStyle(
              color: textSec,
              fontSize: 12.5,
              fontFamily: 'Poppins',
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              launchUrl(
                Uri.parse('https://themoviedb.org'),
                mode: LaunchMode.externalApplication,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF01B4E4).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF01B4E4).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/tmdb_logo.png',
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'themoviedb.org',
                    style: TextStyle(
                      color: Color(0xFF01B4E4),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'PoppinsSB',
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: Color(0xFF01B4E4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


}

class _AboutCard extends StatelessWidget {
  final Color surface;
  final Color border;
  final Widget child;

  const _AboutCard({
    required this.surface,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: const [_Design.shadowCard],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

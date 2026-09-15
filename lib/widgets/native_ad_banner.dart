import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad.dart';
import '../services/analytics_service.dart';

enum NativeAdBannerType { hero, banner, small, ultra }

class NativeAdBanner extends StatelessWidget {
  final Ad ad;
  final NativeAdBannerType type;

  const NativeAdBanner({
    super.key,
    required this.ad,
    this.type = NativeAdBannerType.banner,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        AnalyticsService.instance.trackEvent('ad_click', {
          'ad_id': ad.id,
          'title': ad.title,
          'placement': ad.placement,
          'destination_url': ad.link,
          'format': type.name,
          'timestamp': DateTime.now().toIso8601String(),
        });
        final url = Uri.parse(ad.link);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: _getMargins(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              _buildImage(context),
              _buildOverlay(),
              _buildContent(context),
              _buildBadge(),
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets _getMargins() {
    switch (type) {
      case NativeAdBannerType.hero:
        return EdgeInsets.zero;
      case NativeAdBannerType.ultra:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
      default:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
  }

  Widget _buildImage(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    double? height;
    double? aspectRatio;

    if (type == NativeAdBannerType.ultra) {
      height = 90;
    } else if (type == NativeAdBannerType.banner) {
      aspectRatio = isMobile ? (21 / 9) : (32 / 9);
    } else if (type == NativeAdBannerType.small) {
      aspectRatio = 16 / 3.5;
    } else if (type == NativeAdBannerType.hero) {
      aspectRatio = 16 / 9;
    }

    Widget image;
    if (ad.imageUrl.startsWith('http')) {
      image = CachedNetworkImage(
        imageUrl: ad.imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.white10),
        errorWidget: (context, url, error) => Container(
          color: Colors.white10,
          child: const Icon(Icons.broken_image, color: Colors.white24),
        ),
      );
    } else {
      // For simulated ads
      image = Image.asset(
        ad.imageUrl.replaceFirst('/', ''),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(color: Colors.white10),
      );
    }

    if (height != null) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: image,
      );
    }

    return AspectRatio(
      aspectRatio: aspectRatio ?? 16 / 9,
      child: image,
    );
  }

  Widget _buildOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (type == NativeAdBannerType.ultra) {
      return Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ad.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildCTA(),
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ad.title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: isMobile ? 16 : 20,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: isMobile ? 200 : 250,
              child: Text(
                ad.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: isMobile ? 11 : 13,
                ),
                maxLines: isMobile ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: isMobile ? 10 : 16),
            _buildCTA(isMobile: isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildCTA({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        ad.cta,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: isMobile ? 11 : 12,
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Positioned(
      top: 12,
      right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, size: 12, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  'SPONSORED',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

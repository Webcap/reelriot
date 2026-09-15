import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad.dart';
import '../services/analytics_service.dart';

class NativeAdPosterCard extends StatelessWidget {
  final Ad ad;

  const NativeAdPosterCard({
    super.key,
    required this.ad,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        AnalyticsService.instance.trackEvent('ad_click', {
          'ad_id': ad.id,
          'title': ad.title,
          'placement': 'poster',
          'destination_url': ad.link,
          'timestamp': DateTime.now().toIso8601String(),
        });
        final url = Uri.parse(ad.link);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: 210, // Matching standard PosterCard width
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            _buildImage(),
            _buildGradient(),
            _buildBadge(),
            _buildInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
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
      image = Image.asset(
        ad.imageUrl.replaceFirst('/', ''),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(color: Colors.white10),
      );
    }

    return Positioned.fill(child: image);
  }

  Widget _buildGradient() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black87,
            ],
            stops: [0.6, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Positioned(
      top: 12,
      left: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.6),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'SPONSORED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ad.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            ad.cta,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

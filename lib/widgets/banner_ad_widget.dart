import 'package:reelriot/services/ad_service.dart';
import 'package:flutter/material.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startapp_sdk/startapp.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  StartAppBannerAd? _bannerAd;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final remoteAdsEnabled =
        Provider.of<AppDependencyProvider>(context).enableBannerAds;
    final adService = Provider.of<AdService>(context);

    if (remoteAdsEnabled &&
        _bannerAd == null &&
        !_loading &&
        adService.isEnabled) {
      _loadAd(adService);
    } else if ((!remoteAdsEnabled || !adService.isEnabled) && _bannerAd != null) {
      setState(() {
        _bannerAd = null;
      });
    }
  }

  Future<void> _loadAd(AdService adService) async {
    _loading = true;
    final ad = await adService.loadNewBannerAd();
    if (mounted) {
      setState(() {
        _bannerAd = ad;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteAdsEnabled =
        Provider.of<AppDependencyProvider>(context).enableBannerAds;
    final adService = Provider.of<AdService>(context);

    if (remoteAdsEnabled && adService.isEnabled) {
      if (_bannerAd != null) {
        return Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: StartAppBanner(_bannerAd!),
        );
      }

      if (_loading) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final baseColor = isDark ? const Color(0xFF1E1E24) : Colors.grey.shade300;
        final highlightColor = isDark ? const Color(0xFF2E2E38) : Colors.grey.shade100;
        final blockColor = isDark ? const Color(0xFF262630) : Colors.grey.shade400;

        return Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }
}


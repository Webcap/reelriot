import 'package:cached_network_image/cached_network_image.dart';
import 'package:caffeine_core/caffeine_core.dart';
import 'package:flutter/material.dart';

/// Centralized UserAvatar widget for the Reelriot mobile app.
/// Automatically resolves avatar IDs (0-49, URLs, or null) via AvatarUtils.
class UserAvatar extends StatelessWidget {
  final dynamic avatarId;
  final double size;
  final double? borderRadius;
  final BoxBorder? border;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.avatarId,
    this.size = 40.0,
    this.borderRadius,
    this.border,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.22); // 22% squircle matching Web/TV
    final avatarUrl = AvatarUtils.getAvatarUrl(avatarId);
    final isExplicitDefault = avatarId == null ||
        avatarId.toString().trim().isEmpty ||
        avatarId.toString() == '0';

    Widget avatarWidget = Container(
      width: size,
      height: size,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1.0,
            ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF27272A), Color(0xFF141416)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: isExplicitDefault
          ? _buildDefaultAvatar()
          : CachedNetworkImage(
              imageUrl: avatarUrl,
              memCacheWidth: (size * 2.5).round(),
              memCacheHeight: (size * 2.5).round(),
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: const Color(0xFF18181B),
                child: Center(
                  child: SizedBox(
                    width: size * 0.35,
                    height: size * 0.35,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                // If offline or network error, attempt local bundled asset fallback first
                return Image.asset(
                  'assets/images/profiles/0.png',
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => _buildDefaultAvatar(),
                );
              },
            ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: size * 0.58,
        color: Colors.white,
      ),
    );
  }
}

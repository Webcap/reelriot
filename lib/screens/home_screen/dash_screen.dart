import 'package:cached_network_image/cached_network_image.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/provider/bookmarks_provider.dart';
import 'package:reelriot/provider/ratings_provider.dart';
import 'package:reelriot/provider/sign_in_provider.dart';
import 'package:reelriot/screens/common/update_screen.dart';
import 'package:reelriot/screens/profile/profile_page.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/utils/config_api.dart';
import 'package:reelriot/utils/version_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:reelriot/provider/settings_provider.dart';

import 'package:reelriot/screens/movie_screens/main_movie_display.dart';
import 'package:reelriot/screens/search/search_view.dart' show SearchPage;
import 'package:reelriot/screens/tv_screens/tv_screen.dart';
import 'package:reelriot/widgets/drawer_widget.dart';
import 'package:reelriot/widgets/offline_indicator_banner.dart';
import 'package:reelriot/utils/routes/app_pages.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

// ─── Design token constants (mirrors design.json) ────────────────────────────
class _C {
  static const primary = Color(0xFFDC2626);
  static const primaryLight = Color(0xFFEF4444);
  static const secondary = Color(0xFF7C3AED);

  static const bgCanvasDark = Color(0xFF030712);
  static const bgSurfaceDark = Color(0xFF0B0F14);
  static const bgCanvasLight = Color(0xFFF8FAFC);
  static const bgSurfaceLight = Color(0xFFFFFFFF);

  static const tabBarDark = Color(0xE0111827);
  static const tabBarLight = Color(0xEBFFFFFF);

  static const iconBgDark = Color(0x14FFFFFF);
  static const iconBgLight = Color(0x140F172A);

  static const borderDark = Color(0x14FFFFFF);
  static const borderLight = Color(0x140F172A);

  static const inactiveDark = Color(0x80FFFFFF);
  static const inactiveLight = Color(0xFF64748B);

  static const textPrimDark = Color(0xFFFFFFFF);
  static const textPrimLight = Color(0xFF0B0F14);
}

// ─── Shell ───────────────────────────────────────────────────────────────────

class CaffieneHomePage extends StatefulWidget {
  const CaffieneHomePage({super.key});

  @override
  State<CaffieneHomePage> createState() => _CaffieneHomePageState();
}

class _CaffieneHomePageState extends State<CaffieneHomePage> {
  int selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<_TabMeta> _tabs = [
    _TabMeta(icon: Icons.movie_creation_rounded, label: 'Movies'),
    _TabMeta(icon: Icons.tv_rounded, label: 'TV'),
    _TabMeta(icon: Icons.person_rounded, label: 'Profile'),
  ];

  bool _hasLaunchedOnboarding = false;
  VoidCallback? _authListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkOnboarding();
      final sp = Provider.of<SignInProvider>(context, listen: false);
      _authListener = () {
        if (mounted) _checkOnboarding();
      };
      sp.addListener(_authListener!);

      checkForcedUpdate();
      Provider.of<BookmarksProvider>(context, listen: false).syncIfNeeded();
      RatingsProvider.instance.fetchRatings();
    });
  }

  @override
  void dispose() {
    if (_authListener != null) {
      try {
        Provider.of<SignInProvider>(context, listen: false)
            .removeListener(_authListener!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _checkOnboarding() {
    if (!mounted || _hasLaunchedOnboarding) return;
    final sp = Provider.of<SignInProvider>(context, listen: false);
    if (sp.isSignedIn && sp.firstRun == true) {
      _hasLaunchedOnboarding = true;
      Get.toNamed(Routes.onboarding)?.then((_) {
        _hasLaunchedOnboarding = false;
      });
    }
  }

  Future<void> checkForcedUpdate() async {
    if (!mounted) return;
    final provider = Provider.of<AppDependencyProvider>(context, listen: false);
    try {
      final info = await fetchUpdateInfoFromApi(provider);
      if (!mounted) return;
      if (info.forcedUpdate &&
          isUpdateAvailable(currentAppVersion, info.latestVersion)) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UpdateScreen(isForced: true)),
        );
      }
    } catch (_) {
      // Keep app usable if config fetch fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final lang = settings.appLanguage;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: isDark ? _C.bgCanvasDark : _C.bgSurfaceLight,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDark ? _C.bgCanvasDark : _C.bgCanvasLight,
        drawer: Drawer(
          backgroundColor: isDark ? _C.bgSurfaceDark : _C.bgSurfaceLight,
          child: const DrawerWidget(),
        ),

        // ── Cinematic AppBar ────────────────────────────────────────────────
        appBar: _HomeAppBar(
          isDark: isDark,
          selectedIndex: selectedIndex,
          scaffoldKey: _scaffoldKey,
          onSearchTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchPage(
                includeAdult: settings.isAdult,
                lang: lang,
              ),
            ),
          ),
        ),

        // ── Cinematic Bottom Tab Bar ────────────────────────────────────────
        bottomNavigationBar: _CinematicTabBar(
          tabs: _tabs,
          selectedIndex: selectedIndex,
          isDark: isDark,
          onTabChange: (i) => setState(() => selectedIndex = i),
        ),

        body: Column(
          children: [
            const OfflineIndicatorBanner(),
            Expanded(
              child: IndexedStack(
                index: selectedIndex,
                children: const <Widget>[
                  MainMoviesDisplay(),
                  MainTVDisplay(),
                  ProfilePage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Smart AppBar — greeting on Movies tab, wordmark elsewhere ───────────

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;
  final int selectedIndex;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback onSearchTap;

  const _HomeAppBar({
    required this.isDark,
    required this.selectedIndex,
    required this.scaffoldKey,
    required this.onSearchTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Show personalized greeting only on the Movies tab (index 0)
    final showGreeting = selectedIndex == 0;
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? _C.bgCanvasDark : _C.bgCanvasLight,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: showGreeting
          ? _GreetingTitle(isDark: isDark, scaffoldKey: scaffoldKey)
          : Padding(
              padding: EdgeInsets.only(left: isTablet ? 20 : 12),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.notes_rounded,
                    isDark: isDark,
                    onTap: () => scaffoldKey.currentState?.openDrawer(),
                  ),
                  const Spacer(),
                  _GradientWordmark(isDark: isDark),
                  const Spacer(),
                ],
              ),
            ),
      actions: [
        _CircleIconButton(
          icon: Icons.search_rounded,
          isDark: isDark,
          onTap: onSearchTap,
        ),
        SizedBox(width: isTablet ? 20 : 8),
      ],
    );
  }
}

// ─── Personalized greeting row ───────────────────────────────────────────────

class _GreetingTitle extends StatelessWidget {
  final bool isDark;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const _GreetingTitle({
    required this.isDark,
    required this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    final signIn = context.watch<SignInProvider>();
    final displayName = signIn.username ?? signIn.name ?? 'Guest';
    final textPrim = isDark ? _C.textPrimDark : _C.textPrimLight;
    final textSec = isDark ? const Color(0xB8FFFFFF) : const Color(0xFF64748B);
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    final avatarSize = isTablet ? 48.0 : 42.0;
    final isSignedIn = signIn.isSignedIn;
    final hasCustomImage =
        isSignedIn && (signIn.imageUrl != null && signIn.imageUrl!.isNotEmpty);
    final hasProfileAvatar = isSignedIn && (signIn.profileId != null);

    return Padding(
      padding: EdgeInsets.only(left: isTablet ? 16 : 4),
      child: Row(
        children: [
          // Avatar / drawer opener
          GestureDetector(
            onTap: () => scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.primary.withValues(alpha: 0.15),
                border: Border.all(
                  color: _C.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: hasCustomImage
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: signIn.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: isTablet ? 24 : 20,
                            color: _C.primary,
                          ),
                        ),
                      ),
                    )
                  : hasProfileAvatar
                      ? ClipOval(
                          child: Image.asset(
                            'assets/images/profiles/${signIn.profileId}.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: isTablet ? 24 : 20,
                                color: _C.primary,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: isTablet ? 24 : 20,
                            color: _C.primary,
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 12),
          // Greeting text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Hi Welcome',
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 11,
                        color: textSec,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('👋', style: TextStyle(fontSize: isTablet ? 14 : 11)),
                  ],
                ),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 14,
                    fontWeight: FontWeight.w700,
                    color: textPrim,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wordmark for TV/Profile tab appbars ──────────────────────────────────────

class _GradientWordmark extends StatelessWidget {
  final bool isDark;
  const _GradientWordmark({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_C.secondary, Color(0xFFEF4444)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: const Text(
        'Reelriot',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          fontFamily: 'PoppinsSB',
        ),
      ),
    );
  }
}

// ─── Circular icon button ──────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final size = isTablet ? 46.0 : 38.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          splashColor: _C.primary.withValues(alpha: 0.12),
          highlightColor: _C.primary.withValues(alpha: 0.06),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? _C.bgSurfaceDark : _C.bgSurfaceLight,
              border: Border.all(
                color: isDark ? _C.borderDark : _C.borderLight,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: isTablet ? 20 : 16,
              color: isDark ? _C.textPrimDark : _C.textPrimLight,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Metadata struct for a tab ────────────────────────────────────────────

class _TabMeta {
  final IconData icon;
  final String label;
  const _TabMeta({required this.icon, required this.label});
}

// ─── Cinematic tab bar (design.json: bottomTabBar) ────────────────────────

class _CinematicTabBar extends StatelessWidget {
  final List<_TabMeta> tabs;
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onTabChange;

  const _CinematicTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.isDark,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _C.tabBarDark : _C.tabBarLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isTablet ? 32 : 24),
          topRight: Radius.circular(isTablet ? 32 : 24),
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? _C.borderDark : _C.borderLight,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 740 : 560),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 8,
                vertical: isTablet ? 12 : 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(tabs.length, (i) {
                  return _TabButton(
                    meta: tabs[i],
                    isActive: i == selectedIndex,
                    isDark: isDark,
                    isTablet: isTablet,
                    onTap: () => onTabChange(i),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Individual tab button ────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final _TabMeta meta;
  final bool isActive;
  final bool isDark;
  final bool isTablet;
  final VoidCallback onTap;

  const _TabButton({
    required this.meta,
    required this.isActive,
    required this.isDark,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark ? _C.inactiveDark : _C.inactiveLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        constraints: BoxConstraints(
          minHeight: isTablet ? 52 : 44,
          minWidth: isTablet ? 52 : 44,
        ),
        padding: isActive
            ? EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 18,
                vertical: isTablet ? 12 : 9,
              )
            : EdgeInsets.symmetric(
                horizontal: isTablet ? 18 : 14,
                vertical: isTablet ? 12 : 9,
              ),
        decoration: BoxDecoration(
          color: isActive
              ? _C.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (meta.label == 'Profile') ...[
              Builder(
                builder: (context) {
                  final signIn = context.watch<SignInProvider>();
                  final iconSize = isTablet ? 23.0 : 19.0;
                  final isSignedIn = signIn.isSignedIn;
                  final hasCustomImage = isSignedIn &&
                      (signIn.imageUrl != null && signIn.imageUrl!.isNotEmpty);
                  final hasProfileAvatar =
                      isSignedIn && (signIn.profileId != null);

                  if (hasCustomImage || hasProfileAvatar) {
                    return Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? _C.primary
                              : inactiveColor.withValues(alpha: 0.6),
                          width: isActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: ClipOval(
                        child: hasCustomImage
                            ? CachedNetworkImage(
                                imageUrl: signIn.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.person_rounded,
                                  size: iconSize * 0.7,
                                  color: isActive ? _C.primary : inactiveColor,
                                ),
                              )
                            : Image.asset(
                                'assets/images/profiles/${signIn.profileId}.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.person_rounded,
                                  size: iconSize * 0.7,
                                  color: isActive ? _C.primary : inactiveColor,
                                ),
                              ),
                      ),
                    );
                  }

                  return Icon(
                    meta.icon,
                    size: isTablet ? 23 : 18,
                    color: isActive ? _C.primary : inactiveColor,
                  );
                },
              ),
            ] else ...[
              Icon(
                meta.icon,
                size: isTablet ? 23 : 18,
                color: isActive ? _C.primary : inactiveColor,
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              child: isActive
                  ? Row(
                      children: [
                        const SizedBox(width: 7),
                        Text(
                          meta.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.primary,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

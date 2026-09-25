// ignore_for_file: unused_local_variable
import 'dart:async';

import 'package:reelriot/preferences/profile_tab_preference.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/provider/recently_watched_provider.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/provider/sign_in_provider.dart';
import 'package:reelriot/screens/auth_screens/welcome.dart';
import 'package:reelriot/utils/app_images.dart';
import 'package:reelriot/utils/config_api.dart';
import 'package:reelriot/utils/routes/app_pages.dart';
import 'package:reelriot/widgets/watch_stat_card.dart';
import 'package:reelriot/widgets/guest_profile_content.dart';
import 'package:reelriot/widgets/sign_out_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:caffeine_core/caffeine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Design tokens (design.json) ─────────────────────────────────────────────
class _C {
  static const primary = Color(0xFFDC2626);
  static const secondary = Color(0xFF7C3AED);
  static const bgCanvasDark = Color(0xFF030712);
  static const bgSurfaceDark = Color(0xFF0B0F14);
  static const bgElevatedDark = Color(0x0AFFFFFF);
  static const bgCanvasLight = Color(0xFFF8FAFC);
  static const bgSurfaceLight = Color(0xFFFFFFFF);
  static const bgElevatedLight = Color(0xFFF1F5F9);
  static const borderDark = Color(0x14FFFFFF);
  static const borderLight = Color(0x140F172A);
  static const textPrimDark = Color(0xFFFFFFFF);
  static const textPrimLight = Color(0xFF0B0F14);
  static const textSecDark = Color(0xB8FFFFFF);
  static const textSecLight = Color(0xFF475569);
  static const textTertDark = Color(0x80FFFFFF);
  static const textTertLight = Color(0xFF94A3B8);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  GoTrueClient get _auth => _supabase.auth;

  StreamSubscription<AuthState>? _authSubscription;
  Stream<Map<String, dynamic>>? _profileStream;
  Map<String, dynamic>? profileData;
  String? month;
  int? year;
  String? uid;
  String? _lastTrackedUid;

  @override
  void initState() {
    super.initState();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user ?? _auth.currentUser;
      final currentUid = (user != null && !user.isAnonymous) ? user.id : null;
      if (currentUid != _lastTrackedUid) {
        _lastTrackedUid = currentUid;
        _initProfileStream();
        getData();
        if (mounted && currentUid != null) {
          final recentPrv = Provider.of<RecentProvider>(context, listen: false);
          recentPrv.syncFromCloud();
          recentPrv.fetchWatchStatsFromApi();
        }
      }
    });

    _initProfileStream();
    getData();
    // Proactively refresh remote config and caffeine-api watch stats on open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) return;
      final appDep = Provider.of<AppDependencyProvider>(context, listen: false);
      await refreshConfig(appDep);
      if (!mounted) return;
      final recentPrv = Provider.of<RecentProvider>(context, listen: false);
      await recentPrv.syncFromCloud();
      if (!mounted) return;
      await recentPrv.fetchWatchStatsFromApi();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sp = Provider.of<SignInProvider>(context);
    final user = _auth.currentUser;
    final isAuth = sp.isSignedIn && user != null && !user.isAnonymous;
    final currentUid = isAuth ? user.id : null;
    if (currentUid != _lastTrackedUid) {
      _lastTrackedUid = currentUid;
      _initProfileStream();
      getData();
      if (currentUid != null) {
        final recentPrv = Provider.of<RecentProvider>(context, listen: false);
        recentPrv.syncFromCloud();
        recentPrv.fetchWatchStatsFromApi();
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _initProfileStream() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _profileStream = null;
          uid = null;
          profileData = null;
        });
      } else {
        _profileStream = null;
        uid = null;
        profileData = null;
      }
      return;
    }

    final newStream = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .limit(1)
        .map((data) {
          if (data.isNotEmpty) {
            debugPrint('[Avatar Sync] 🟢 Received real-time update: profile_id=${data.first['profile_id']}');
            profileData = data.first;
            if (data.first['joined_at'] != null && (month == null || year == null)) {
              try {
                final dt = DateTime.parse(data.first['joined_at'].toString());
                month = DateFormat('MMMM').format(DateTime(0, dt.month));
                year = dt.year;
              } catch (_) {}
            }
            return data.first;
          }
          debugPrint('[Avatar Sync] ⚠️ Received empty profile update');
          return profileData ?? <String, dynamic>{};
        })
        .handleError((error) {
          debugPrint('[Avatar Sync] ⚠️ Stream error: $error');
          return profileData ?? <String, dynamic>{};
        });

    if (mounted) {
      setState(() {
        uid = user.id;
        _profileStream = newStream;
      });
    } else {
      uid = user.id;
      _profileStream = newStream;
    }
  }

  // Legacy method kept for non-avatar metadata if needed
  Future<void> getData() async {
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final res = await _supabase.from('profiles').select().eq('id', user.id).limit(1);
        if (res.isNotEmpty && mounted) {
          final data = res[0];
          setState(() {
            profileData = data;
            if (data['joined_at'] != null) {
              try {
                final dt = DateTime.parse(data['joined_at'].toString());
                month = DateFormat('MMMM').format(DateTime(0, dt.month));
                year = dt.year;
              } catch (_) {}
            }
          });
        }
      } catch (e) {
        debugPrint('[ProfilePage] Error fetching profile: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = Provider.of<SignInProvider>(context);
    final appDep = Provider.of<AppDependencyProvider>(context);
    final recent = Provider.of<RecentProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? _C.bgCanvasDark : _C.bgCanvasLight;
    final surface = isDark ? _C.bgSurfaceDark : _C.bgSurfaceLight;
    final elevated = isDark ? _C.bgElevatedDark : _C.bgElevatedLight;
    final border = isDark ? _C.borderDark : _C.borderLight;
    final textPrim = isDark ? _C.textPrimDark : _C.textPrimLight;
    final textSec = isDark ? _C.textSecDark : _C.textSecLight;
    final textTert = isDark ? _C.textTertDark : _C.textTertLight;

    final user = _auth.currentUser;
    final isGuest = !sp.isSignedIn || user == null || user.isAnonymous;

    if (isGuest) {
      return Scaffold(
        backgroundColor: bg,
        body: GuestProfileContent(
          isDark: isDark,
          bg: bg,
          surface: surface,
          elevated: elevated,
          border: border,
          textPrim: textPrim,
          textSec: textSec,
          textTert: textTert,
          appDep: appDep,
        ),
      );
    }

    if (_profileStream == null || uid != user.id) {
      _initProfileStream();
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[Avatar Sync] Stream error in UI: ${snapshot.error}');
        }
        final data = snapshot.data ??
            profileData ??
            <String, dynamic>{
              'name': sp.name ?? 'ReelRiot User',
              'username': sp.username ?? sp.name ?? 'ReelRiot User',
              'profile_id': sp.profileId ?? 0,
              'image_url': sp.imageUrl ?? '',
            };

        final moviesMin = recent.movieWatchTimeMinutesLast2Weeks;
        final tvMin = recent.tvWatchTimeMinutesLast2Weeks;
        final moviesFormatted = recent.formatWatchTime(moviesMin);
        final tvFormatted = recent.formatWatchTime(tvMin);

        final currentUser = _auth.currentUser;
        final bool isEmailVerified = data['verified'] == true ||
            currentUser?.emailConfirmedAt != null ||
            currentUser?.userMetadata?['email_verified'] == true ||
            currentUser?.appMetadata['provider'] == 'google';

        if (isEmailVerified && data['verified'] != true && currentUser != null) {
          _supabase
              .from('profiles')
              .update({'verified': true})
              .eq('id', currentUser.id)
              .catchError((_) => null);
        }

        final screenWidth = MediaQuery.sizeOf(context).width;
        final isTablet = screenWidth >= 600;

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 16,
                vertical: isTablet ? 24 : 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    children: [
                      // ── 1. Avatar & Profile Header ────────────────────────
                      if (isTablet)
                        _buildTabletHeader(
                          context,
                          data: data,
                          currentUser: currentUser,
                          isEmailVerified: isEmailVerified,
                          border: border,
                          textPrim: textPrim,
                          textSec: textSec,
                          textTert: textTert,
                          elevated: elevated,
                        )
                      else
                        _buildPhoneHeader(
                          context,
                          data: data,
                          currentUser: currentUser,
                          isEmailVerified: isEmailVerified,
                          border: border,
                          textPrim: textPrim,
                          textSec: textSec,
                          textTert: textTert,
                        ),

                      // ── 2. Main Content (Dual-column on tablet, Single on phone) ──
                      SizedBox(height: isTablet ? 24 : 24),
                      if (isTablet)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Watch Stats
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildWatchStatsCard(
                                    elevated: elevated,
                                    border: border,
                                    textPrim: textPrim,
                                    moviesFormatted: moviesFormatted,
                                    tvFormatted: tvFormatted,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Right Column: Settings + Sign Out
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _buildSettingsList(appDep, elevated, border, textPrim, textSec, textTert),
                                  const SizedBox(height: 18),
                                  _buildSignOutButton(context, sp),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildWatchStatsCard(
                          elevated: elevated,
                          border: border,
                          textPrim: textPrim,
                          moviesFormatted: moviesFormatted,
                          tvFormatted: tvFormatted,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsList(appDep, elevated, border, textPrim, textSec, textTert),
                        const SizedBox(height: 20),
                        _buildSignOutButton(context, sp),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header for Tablet (Landscape card layout) ──────────────────────────────
  Widget _buildTabletHeader(
    BuildContext context, {
    required Map<String, dynamic> data,
    required User? currentUser,
    required bool isEmailVerified,
    required Color border,
    required Color textPrim,
    required Color textSec,
    required Color textTert,
    required Color elevated,
  }) {
    final authProvider = Provider.of<SignInProvider>(context, listen: false);
    final dbProfileId = data['profile_id']?.toString();
    final authProfileId = authProvider.profileId?.toString();
    final avatarId = (dbProfileId != null && dbProfileId.isNotEmpty)
        ? dbProfileId
        : (authProfileId != null && authProfileId.isNotEmpty ? authProfileId : '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 2),
            ),
            child: (data['image_url'] != null && data['image_url'].toString().isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: data['image_url'],
                    imageBuilder: (_, imageProvider) => CircleAvatar(
                      backgroundImage: imageProvider,
                      radius: 40,
                    ),
                    memCacheWidth: 160,
                    memCacheHeight: 160,
                    errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40),
                  )
                : CachedNetworkImage(
                    imageUrl: AvatarUtils.getAvatarUrl(avatarId),
                    imageBuilder: (_, imageProvider) => CircleAvatar(
                      backgroundImage: imageProvider,
                      radius: 40,
                    ),
                    memCacheWidth: 160,
                    memCacheHeight: 160,
                    errorWidget: (_, __, ___) => Image.asset(
                      'assets/images/profiles/$avatarId.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40),
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? data['username'] ?? 'caffeineUser123',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: textPrim,
                    fontFamily: 'PoppinsSB',
                  ),
                ),
                if (data['username'] != null &&
                    data['username'].toString().isNotEmpty &&
                    data['username'] != data['name']) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${data['username']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textSec,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      data['email'] ?? currentUser?.email ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSec,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (isEmailVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: _C.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${tr('joined')}: ${month ?? ''} ${year ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textTert,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => Get.toNamed(Routes.profileEdit),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: Text(
              tr("edit_profile"),
              style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'PoppinsSB'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: textPrim,
              side: BorderSide(color: border, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header for Phone (Centered layout) ──────────────────────────────────────
  Widget _buildPhoneHeader(
    BuildContext context, {
    required Map<String, dynamic> data,
    required User? currentUser,
    required bool isEmailVerified,
    required Color border,
    required Color textPrim,
    required Color textSec,
    required Color textTert,
  }) {
    final authProvider = Provider.of<SignInProvider>(context, listen: false);
    final dbProfileId = data['profile_id']?.toString();
    final authProfileId = authProvider.profileId?.toString();
    final avatarId = (dbProfileId != null && dbProfileId.isNotEmpty)
        ? dbProfileId
        : (authProfileId != null && authProfileId.isNotEmpty ? authProfileId : '0');

    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: (data['image_url'] != null && data['image_url'].toString().isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: data['image_url'],
                  imageBuilder: (_, imageProvider) => CircleAvatar(
                    backgroundImage: imageProvider,
                    radius: 48,
                  ),
                  memCacheWidth: 192,
                  memCacheHeight: 192,
                  errorWidget: (_, __, ___) => const Icon(Icons.person, size: 48),
                )
              : CachedNetworkImage(
                  imageUrl: AvatarUtils.getAvatarUrl(avatarId),
                  imageBuilder: (_, imageProvider) => CircleAvatar(
                    backgroundImage: imageProvider,
                    radius: 48,
                  ),
                  memCacheWidth: 192,
                  memCacheHeight: 192,
                  errorWidget: (_, __, ___) => Image.asset(
                    'assets/images/profiles/$avatarId.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Text(
          data['name'] ?? data['username'] ?? 'caffeineUser123',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrim,
            fontFamily: 'PoppinsSB',
          ),
          textAlign: TextAlign.center,
        ),
        if (data['username'] != null &&
            data['username'].toString().isNotEmpty &&
            data['username'] != data['name']) ...[
          const SizedBox(height: 2),
          Text(
            '@${data['username']}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textSec,
              fontFamily: 'Poppins',
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          '${tr('joined')}: ${month ?? ''} ${year ?? ''}',
          style: TextStyle(
            fontSize: 13,
            color: textTert,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            Text(
              data['email'] ?? currentUser?.email ?? '',
              style: TextStyle(
                fontSize: 13,
                color: textSec,
                fontFamily: 'Poppins',
              ),
            ),
            if (isEmailVerified)
              const Icon(
                Icons.verified_rounded,
                size: 18,
                color: _C.primary,
              ),
          ],
        ),
      ],
    );
  }

  // ── Watch Stats Card ───────────────────────────────────────────────────────
  Widget _buildWatchStatsCard({
    required Color elevated,
    required Color border,
    required Color textPrim,
    required String moviesFormatted,
    required String tvFormatted,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 20,
                color: _C.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                tr('last_2_weeks'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrim,
                  fontFamily: 'PoppinsSB',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: WatchStatCard(
                  icon: Icons.movie_creation_rounded,
                  label: tr('movies'),
                  value: moviesFormatted,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WatchStatCard(
                  icon: Icons.live_tv_rounded,
                  label: tr('tv_series'),
                  value: tvFormatted,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Settings List ──────────────────────────────────────────────────────────
  Widget _buildSettingsList(
    AppDependencyProvider appDep,
    Color elevated,
    Color border,
    Color textPrim,
    Color textSec,
    Color textTert,
  ) {
    final showActivateTv = appDep.isFeatureEnabled('toggle_tv_activate_button', defaultValue: true);
    final filteredSettings = settingdata.where((item) => showActivateTv || item.tital != tr("pair_tv")).toList();
    return Container(
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredSettings.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: border,
          indent: 56,
          endIndent: 16,
        ),
        itemBuilder: (context, i) {
          return InkWell(
            onTap: filteredSettings[i].onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    filteredSettings[i].iconImage,
                    colorFilter: ColorFilter.mode(
                      textPrim,
                      BlendMode.srcIn,
                    ),
                    height: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      filteredSettings[i].tital,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrim,
                        fontFamily: 'PoppinsSB',
                      ),
                    ),
                  ),
                  if (filteredSettings[i].subTital != null)
                    Text(
                      '${filteredSettings[i].subTital}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textSec,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: textTert,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Sign Out Button ────────────────────────────────────────────────────────
  Widget _buildSignOutButton(BuildContext context, SignInProvider sp) {
    return InkWell(
      onTap: () => SignOutBottomSheet.show(context, sp),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              MovixIcon.logOut,
              colorFilter: const ColorFilter.mode(
                _C.primary,
                BlendMode.srcIn,
              ),
              height: 20,
            ),
            const SizedBox(width: 10),
            Text(
              tr('sign_out'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.primary,
                fontFamily: 'PoppinsSB',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:caffeine_core/caffeine_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reelriot/models/profile_image_list.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/provider/sign_in_provider.dart';
import 'package:reelriot/screens/profile/delete_account.dart';
import 'package:reelriot/screens/profile/password_change.dart';
import 'package:reelriot/utils/app_images.dart';
import 'package:reelriot/utils/globlal_methods.dart';
import 'package:reelriot/utils/theme/textStyle.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _Design {
  static const primary = Color(0xFFDC2626);
  static const primaryDim = Color(0x1ADC2626);
  static const primaryBorder = Color(0x33DC2626);

  static const bgCanvasDark = Color(0xFF030712);
  static const bgCanvasLight = Color(0xFFF8FAFC);
  static const bgSurfaceDark = Color(0xFF0B0F14);
  static const bgSurfaceLight = Color(0xFFFFFFFF);
  static const bgCardDark = Color(0xFF111827);
  static const bgCardLight = Color(0xFFF1F5F9);

  static const borderDark = Color(0x14FFFFFF);
  static const borderLight = Color(0x140F172A);
  static const iconBgDark = Color(0x14FFFFFF);

  static const textPrimDark = Color(0xFFFFFFFF);
  static const textPrimLight = Color(0xFF0B0F14);
  static const textSecDark = Color(0xB8FFFFFF);
  static const textSecLight = Color(0xFF64748B);

  static const radiusLg = 20.0;
  static const radiusMd = 16.0;
  static const radiusSm = 12.0;
  static const screenPadH = 20.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const ctaHeight = 52.0;
  static const shadowCard = BoxShadow(
    color: Color(0x38000000),
    blurRadius: 30,
    offset: Offset(0, 10),
  );
}

class ProfileEdit extends StatefulWidget {
  const ProfileEdit({super.key});

  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  final _auth = Supabase.instance.client.auth;
  final _supabase = Supabase.instance.client;
  final GlobalMethods _globalMethods = GlobalMethods();
  final ProfileImages _profileImages = ProfileImages();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSaving = false;
  bool? _userAnonymous;

  String? _uid;
  String? _email;
  String? _username;
  String? _joinedAtMonth;
  int? _joinedAtYear;
  bool? _isVerified;

  String _initialEmail = '';
  int _initialProfileId = 0;
  int _selectedProfileId = 0;

  List<UserIdentity> _identities = [];
  bool _isLoadingIdentities = false;
  bool _isLinkingGoogle = false;
  bool _isUnlinkingGoogle = false;

  Future<void> _fetchIdentities() async {
    if (!mounted) return;
    setState(() => _isLoadingIdentities = true);
    try {
      final sp = Provider.of<SignInProvider>(context, listen: false);
      final identities = await sp.getUserIdentities();
      if (mounted) {
        setState(() {
          _identities = identities;
          _isLoadingIdentities = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingIdentities = false);
    }
  }

  Future<void> _handleLinkGoogle() async {
    if (_isLinkingGoogle) return;
    setState(() => _isLinkingGoogle = true);
    try {
      final sp = Provider.of<SignInProvider>(context, listen: false);
      await sp.linkGoogleAccount();
      await _fetchIdentities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google account linked successfully'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _globalMethods.authErrorHandle(e.toString(), context);
      }
    } finally {
      if (mounted) setState(() => _isLinkingGoogle = false);
    }
  }

  Future<void> _handleUnlinkGoogle(UserIdentity identity) async {
    if (_isUnlinkingGoogle) return;
    final sp = Provider.of<SignInProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Unlink Google Account'),
        content: const Text(
          'Are you sure you want to unlink your Google account? You will need to log in with your email and password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Design.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isUnlinkingGoogle = true);
    try {
      await sp.unlinkIdentity(identity);
      await _fetchIdentities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google account unlinked'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _globalMethods.authErrorHandle(e.toString(), context);
      }
    } finally {
      if (mounted) setState(() => _isUnlinkingGoogle = false);
    }
  }

  static const int _emailCooldownSeconds = 60;
  DateTime? _lastEmailSentTimestamp;

  bool _canSendVerificationEmail({BuildContext? targetContext}) {
    final ctx = targetContext ?? context;
    if (_lastEmailSentTimestamp != null) {
      final diff =
          DateTime.now().difference(_lastEmailSentTimestamp!).inSeconds;
      if (diff < _emailCooldownSeconds) {
        final remaining = _emailCooldownSeconds - diff;
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                tr("rate_limit_wait",
                    namedArgs: {'seconds': remaining.toString()}),
                style: kTextSmallBodyStyle,
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
    }
    _lastEmailSentTimestamp = DateTime.now();
    return true;
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFormDirtyCheck);
    _fetchUserData();
  }

  @override
  void dispose() {
    _emailController.removeListener(_onFormDirtyCheck);
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _onFormDirtyCheck() {
    setState(() {});
  }

  bool get _isDirty {
    final avatarChanged = _selectedProfileId != _initialProfileId;
    final emailChanged = _emailController.text.trim().toLowerCase() !=
        _initialEmail.trim().toLowerCase();
    return avatarChanged || emailChanged;
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    _uid = user?.id;

    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _userAnonymous = true;
          _isLoading = false;
        });
      }
      return;
    }

    final sp = Provider.of<SignInProvider>(context, listen: false);
    final fallbackEmail = (user.email != null && user.email!.isNotEmpty)
        ? user.email!
        : (sp.email ?? '');

    _email = fallbackEmail;
    _initialEmail = fallbackEmail;
    _emailController.text = fallbackEmail;
    _fetchIdentities();

    try {
      final res =
          await _supabase.from('profiles').select().eq('id', _uid!).limit(1);

      if (res.isNotEmpty && mounted) {
        final data = res[0];
        final fetchedUsername = (data['username'] as String?) ?? '';
        final fetchedProfileId = (data['profile_id'] as int?) ?? 0;

        _initialProfileId = fetchedProfileId;
        _selectedProfileId = fetchedProfileId;

        _username = fetchedUsername;

        final dataEmail = (data['email'] as String?);
        _email = (dataEmail != null && dataEmail.trim().isNotEmpty)
            ? dataEmail
            : fallbackEmail;
        _initialEmail = _email ?? '';
        _emailController.text = _initialEmail;
        _isVerified = (data['verified'] == true) ||
            user.emailConfirmedAt != null ||
            user.userMetadata?['email_verified'] == true ||
            user.appMetadata['provider'] == 'google';

        if (_isVerified == true && data['verified'] != true) {
          _supabase
              .from('profiles')
              .update({'verified': true})
              .eq('id', _uid!)
              .catchError((_) => null);
        }

        final joinedAtStr = data['joined_at'] as String?;
        if (joinedAtStr != null) {
          try {
            final dt = DateTime.parse(joinedAtStr);
            _joinedAtMonth = DateFormat('MMMM').format(DateTime(0, dt.month));
            _joinedAtYear = dt.year;
          } catch (_) {}
        }

        setState(() {
          _userAnonymous = false;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[EditProfile] Error fetching user profile: $e');
    }

    if (mounted) {
      _emailController.text = _initialEmail;
      setState(() {
        _userAnonymous = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final isValid = _formKey.currentState?.validate() ?? true;
    if (!isValid || _uid == null || !_isDirty) return;

    _emailFocusNode.unfocus();

    final avatarChanged = _selectedProfileId != _initialProfileId;
    final targetEmail = _emailController.text.trim();
    final emailChanged = targetEmail.toLowerCase() !=
        _initialEmail.trim().toLowerCase();

    if (emailChanged && !_canSendVerificationEmail()) {
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      if (avatarChanged) {
        // 1. Dual-Source Sync: Update Auth Metadata first (both avatar and profile_id keys)
        await _auth.updateUser(UserAttributes(
          data: {
            'avatar': _selectedProfileId,
            'profile_id': _selectedProfileId,
          },
        ));

        // 2. Update profiles table (avatar / profile_id)
        await _supabase.from('profiles').update({
          'profile_id': _selectedProfileId,
        }).eq('id', _uid!);
      }

      if (emailChanged) {
        // Trigger email update and verification email dispatch via Resend
        await _auth.updateUser(
          UserAttributes(email: targetEmail),
          emailRedirectTo: kIsWeb ? null : 'io.reelriot.app://login-callback/',
        );
      }

      if (!mounted) return;

      // 3. Update SignInProvider state for instantaneous sync across app
      await Provider.of<SignInProvider>(context, listen: false)
          .getUserDataFromFirestore(_uid);

      if (mounted) {
        final successMsg = emailChanged
            ? tr("email_confirmation_sent")
            : tr("profile_updated_successfully");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMsg,
              style: kTextSmallBodyStyle,
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final msg = e.message.toLowerCase();
        if (msg.contains('rate') ||
            msg.contains('limit') ||
            msg.contains('too many')) {
          _globalMethods.authErrorHandle(
              tr("rate_limit_exceeded"), context);
        } else {
          _globalMethods.authErrorHandle(e.message, context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _globalMethods.authErrorHandle(e.toString(), context);
      }
    }
  }

  Future<bool> _handlePopScope() async {
    if (!_isDirty) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr("discard_dialog_title")),
        content: Text(tr("discard_dialog_desc")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr("keep_editing")),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Design.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr("discard")),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _openAvatarPickerSheet({
    required BuildContext context,
    required Color surface,
    required Color cardBg,
    required Color border,
    required Color textPrim,
    required Color textSec,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(_Design.radiusLg)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: isTablet ? 0.65 : 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            final allProfiles = _profileImages.profile();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 28 : _Design.screenPadH,
                    vertical: _Design.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: textSec.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: _Design.space4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr("select_avatar"),
                            style: TextStyle(
                              color: textPrim,
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'PoppinsSB',
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: textSec),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: _Design.space3),
                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isTablet ? 6 : 4,
                            crossAxisSpacing: isTablet ? 18 : 14,
                            mainAxisSpacing: isTablet ? 18 : 14,
                          ),
                          itemCount: allProfiles.length,
                          itemBuilder: (context, index) {
                            final profile = allProfiles[index];
                            final isSelected = _selectedProfileId == profile.index;
                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedProfileId = profile.index;
                                });
                                Navigator.of(sheetContext).pop();
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? _Design.primary : border,
                                    width: isSelected ? 3.0 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: _Design.primary
                                                .withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: AvatarUtils.getAvatarUrl(profile.index),
                                        fit: BoxFit.cover,
                                        memCacheWidth: 160,
                                        memCacheHeight: 160,
                                        placeholder: (_, __) => Container(color: cardBg),
                                        errorWidget: (_, __, ___) => Image.asset(
                                          'assets/images/profiles/${profile.index}.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: cardBg,
                                            child: const Icon(
                                              Icons.person_rounded,
                                              color: _Design.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: _Design.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isDark = themeMode == 'dark' || themeMode == 'amoled';
    final bg = isDark ? _Design.bgCanvasDark : _Design.bgCanvasLight;
    final surface = isDark ? _Design.bgSurfaceDark : _Design.bgSurfaceLight;
    final cardBg = isDark ? _Design.bgCardDark : _Design.bgCardLight;
    final textPrim = isDark ? _Design.textPrimDark : _Design.textPrimLight;
    final textSec = isDark ? _Design.textSecDark : _Design.textSecLight;
    final border = isDark ? _Design.borderDark : _Design.borderLight;
    final iconBg = isDark ? _Design.iconBgDark : _Design.borderLight;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(context, textPrim, iconBg, surface, isTablet),
        body: const Center(
          child: CircularProgressIndicator(
            color: _Design.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_userAnonymous == true) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(context, textPrim, iconBg, surface, isTablet),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _Design.screenPadH),
            child: Text(
              tr("bookmark_feature_notice"),
              textAlign: TextAlign.center,
              style: TextStyle(color: textSec, fontSize: 15),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _handlePopScope();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(context, textPrim, iconBg, surface, isTablet),
        bottomNavigationBar: _buildStickyBottomBar(
          surface: surface,
          border: border,
          textPrim: textPrim,
          textSec: textSec,
          isTablet: isTablet,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : _Design.screenPadH,
            vertical: isTablet ? 24 : _Design.space4,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Form(
                key: _formKey,
                child: isTablet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Avatar Preview + Account Info Card
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildHeroAvatarSection(
                                  context: context,
                                  surface: surface,
                                  cardBg: cardBg,
                                  border: border,
                                  textPrim: textPrim,
                                  textSec: textSec,
                                ),
                                const SizedBox(height: _Design.space5),
                                _buildAccountInfoCard(
                                  surface: surface,
                                  border: border,
                                  textPrim: textPrim,
                                  textSec: textSec,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Right Column: Email Card + Security Card
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _buildEmailCard(
                                  surface: surface,
                                  border: border,
                                  textPrim: textPrim,
                                  textSec: textSec,
                                ),
                                const SizedBox(height: _Design.space5),
                                _buildLinkedAccountsCard(
                                  surface: surface,
                                  border: border,
                                  textPrim: textPrim,
                                  textSec: textSec,
                                ),
                                const SizedBox(height: _Design.space5),
                                _buildSecurityCard(
                                  surface: surface,
                                  border: border,
                                  textPrim: textPrim,
                                  textSec: textSec,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ─── Hero Avatar Preview & Picker ─────────────────────────
                          _buildHeroAvatarSection(
                            context: context,
                            surface: surface,
                            cardBg: cardBg,
                            border: border,
                            textPrim: textPrim,
                            textSec: textSec,
                          ),

                          const SizedBox(height: _Design.space5),

                          // ─── Standard Email Input Card ────────────────────────────
                          _buildEmailCard(
                            surface: surface,
                            border: border,
                            textPrim: textPrim,
                            textSec: textSec,
                          ),

                          const SizedBox(height: _Design.space5),

                          // ─── Account Info Card ────────────────────────────────────
                          _buildAccountInfoCard(
                            surface: surface,
                            border: border,
                            textPrim: textPrim,
                            textSec: textSec,
                          ),

                          const SizedBox(height: _Design.space5),

                          // ─── Linked Accounts Card ────────────────────────────────
                          _buildLinkedAccountsCard(
                            surface: surface,
                            border: border,
                            textPrim: textPrim,
                            textSec: textSec,
                          ),

                          const SizedBox(height: _Design.space5),

                          // ─── Security & Management Actions ────────────────────────
                          _buildSecurityCard(
                            surface: surface,
                            border: border,
                            textPrim: textPrim,
                            textSec: textSec,
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Color textPrim,
    Color iconBg,
    Color surface,
    bool isTablet,
  ) {
    return AppBar(
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
        onPressed: () async {
          if (_isDirty) {
            final shouldPop = await _handlePopScope();
            if (shouldPop && context.mounted) Navigator.pop(context);
          } else {
            Navigator.pop(context);
          }
        },
        tooltip: tr("back"),
      ),
      title: Text(
        tr("edit_profile"),
        style: TextStyle(
          color: textPrim,
          fontSize: isTablet ? 20 : 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'PoppinsSB',
        ),
      ),
    );
  }

  Widget _buildHeroAvatarSection({
    required BuildContext context,
    required Color surface,
    required Color cardBg,
    required Color border,
    required Color textPrim,
    required Color textSec,
  }) {
    final previewProfiles = _profileImages.profile().take(12).toList();

    return Container(
      padding: const EdgeInsets.all(_Design.space4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_Design.radiusMd),
        border: Border.all(color: border),
        boxShadow: const [_Design.shadowCard],
      ),
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _openAvatarPickerSheet(
                    context: context,
                    surface: surface,
                    cardBg: cardBg,
                    border: border,
                    textPrim: textPrim,
                    textSec: textSec,
                  ),
                  child: Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _Design.primary,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _Design.primary.withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: AvatarUtils.getAvatarUrl(_selectedProfileId),
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        memCacheHeight: 200,
                        placeholder: (_, __) => Container(color: cardBg),
                        errorWidget: (_, __, ___) => Image.asset(
                          'assets/images/profiles/$_selectedProfileId.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: cardBg,
                            child: const Icon(
                              Icons.person_rounded,
                              size: 48,
                              color: _Design.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _openAvatarPickerSheet(
                      context: context,
                      surface: surface,
                      cardBg: cardBg,
                      border: border,
                      textPrim: textPrim,
                      textSec: textSec,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _Design.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _Design.space3),
          Text(
            tr("profile_picture"),
            style: TextStyle(
              color: textPrim,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _Design.space3),
          // Quick selection strip
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: previewProfiles.length + 1,
              itemBuilder: (context, index) {
                if (index == previewProfiles.length) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ActionChip(
                      onPressed: () => _openAvatarPickerSheet(
                        context: context,
                        surface: surface,
                        cardBg: cardBg,
                        border: border,
                        textPrim: textPrim,
                        textSec: textSec,
                      ),
                      avatar: const Icon(Icons.grid_view_rounded, size: 16),
                      label: Text(tr("browse_all_avatars")),
                      labelStyle: TextStyle(
                        color: textPrim,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: cardBg,
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }

                final profile = previewProfiles[index];
                final isSelected = _selectedProfileId == profile.index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedProfileId = profile.index;
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _Design.primary : border,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: AvatarUtils.getAvatarUrl(profile.index),
                          fit: BoxFit.cover,
                          memCacheWidth: 100,
                          memCacheHeight: 100,
                          placeholder: (_, __) => Container(color: cardBg),
                          errorWidget: (_, __, ___) => Image.asset(
                            'assets/images/profiles/${profile.index}.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: cardBg,
                              child: const Icon(Icons.person, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailCard({
    required Color surface,
    required Color border,
    required Color textPrim,
    required Color textSec,
  }) {
    return Container(
      padding: const EdgeInsets.all(_Design.space4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_Design.radiusMd),
        border: Border.all(color: border),
        boxShadow: const [_Design.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: textPrim, fontSize: 15),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return tr("invalid_email");
              }
              if (!value.contains('@') || !value.contains('.')) {
                return tr("invalid_email");
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: tr("email"),
              labelStyle: TextStyle(color: textSec),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: textSec,
                size: 22,
              ),
              suffixIcon: _isVerified == true &&
                      _emailController.text.trim().toLowerCase() ==
                          _initialEmail.trim().toLowerCase()
                  ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.verified_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                    )
                  : _emailController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              size: 18, color: textSec),
                          onPressed: () {
                            _emailController.clear();
                          },
                        )
                      : null,
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_Design.radiusSm),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_Design.radiusSm),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_Design.radiusSm),
                borderSide: const BorderSide(
                  color: _Design.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard({
    required Color surface,
    required Color border,
    required Color textPrim,
    required Color textSec,
  }) {
    final memberSinceText = (_joinedAtMonth != null && _joinedAtYear != null)
        ? '$_joinedAtMonth $_joinedAtYear'
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(_Design.space4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_Design.radiusMd),
        border: Border.all(color: border),
        boxShadow: const [_Design.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr("account_info"),
            style: TextStyle(
              color: textPrim,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _Design.space3),
          if (_username != null && _username!.isNotEmpty) ...[
            _buildInfoRow(
              icon: Icons.alternate_email_rounded,
              label: tr("username"),
              value: '@$_username',
              textPrim: textPrim,
              textSec: textSec,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: _Design.space2),
              child: Divider(height: 1, color: border),
            ),
          ],
          _buildInfoRow(
            icon: Icons.calendar_today_rounded,
            label: tr("member_since"),
            value: memberSinceText,
            textPrim: textPrim,
            textSec: textSec,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textPrim,
    required Color textSec,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: textSec),
        const SizedBox(width: _Design.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: textSec, fontSize: 12),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrim,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildLinkedAccountsCard({
    required Color surface,
    required Color border,
    required Color textPrim,
    required Color textSec,
  }) {
    final googleIdentity = _identities.cast<UserIdentity?>().firstWhere(
      (id) => id?.provider == 'google',
      orElse: () => null,
    );
    final isGoogleLinked = googleIdentity != null;
    final googleEmail = googleIdentity?.identityData?['email'] as String?;

    return Container(
      padding: const EdgeInsets.all(_Design.space4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_Design.radiusMd),
        border: Border.all(color: border),
        boxShadow: const [_Design.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linked Accounts',
            style: TextStyle(
              color: textPrim,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _Design.space3),
          Container(
            padding: const EdgeInsets.all(_Design.space3),
            decoration: BoxDecoration(
              color: _Design.bgCardDark.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(_Design.radiusSm),
              border: Border.all(color: border, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    AssetValues.googleLogo,
                    width: 20,
                    height: 20,
                  ),
                ),
                const SizedBox(width: _Design.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google',
                        style: TextStyle(
                          color: textPrim,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isGoogleLinked
                            ? (googleEmail ?? 'Connected')
                            : 'Not linked',
                        style: TextStyle(
                          color: isGoogleLinked
                              ? const Color(0xFF22C55E)
                              : textSec,
                          fontSize: 12,
                          fontWeight: isGoogleLinked
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingIdentities || _isLinkingGoogle || _isUnlinkingGoogle)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _Design.primary,
                      strokeWidth: 2,
                    ),
                  )
                else if (googleIdentity != null)
                  OutlinedButton(
                    onPressed: () => _handleUnlinkGoogle(googleIdentity),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Disconnect',
                      style: TextStyle(
                        color: textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: _handleLinkGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Design.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Connect',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard({
    required Color surface,
    required Color border,
    required Color textPrim,
    required Color textSec,
  }) {
    return Container(
      padding: const EdgeInsets.all(_Design.space4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_Design.radiusMd),
        border: Border.all(color: border),
        boxShadow: const [_Design.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr("account_security"),
            style: TextStyle(
              color: textPrim,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _Design.space2),
          _ActionTile(
            icon: Icons.lock_outline_rounded,
            label: tr("change_password"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PasswordChangeScreen(),
                ),
              );
            },
            textPrim: textPrim,
            textSec: textSec,
          ),
          Divider(height: 1, color: border),
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            label: tr("delete_account"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              );
            },
            destructive: true,
            textPrim: textPrim,
            textSec: textSec,
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar({
    required Color surface,
    required Color border,
    required Color textPrim,
    required Color textSec,
    required bool isTablet,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
        boxShadow: const [_Design.shadowCard],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : _Design.screenPadH,
            vertical: _Design.space3,
          ),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: SizedBox(
                width: double.infinity,
                height: _Design.ctaHeight,
                child: ElevatedButton(
                  onPressed: (_isDirty && !_isSaving) ? _saveProfile : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Design.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _Design.primary.withValues(alpha: 0.35),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_Design.radiusMd),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 20),
                            const SizedBox(width: _Design.space2),
                            Text(
                              tr("save_changes"),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final Color textPrim;
  final Color textSec;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    required this.textPrim,
    required this.textSec,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? _Design.primary : textPrim;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_Design.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: _Design.space3,
            horizontal: 4,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: color,
              ),
              const SizedBox(width: _Design.space3),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: destructive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: textSec,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

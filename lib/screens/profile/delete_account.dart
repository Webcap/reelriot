import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:caffeine_core/caffeine_core.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/provider/sign_in_provider.dart';
import 'package:reelriot/screens/auth_screens/welcome.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/utils/globlal_methods.dart';
import 'package:reelriot/utils/theme/textStyle.dart';

// ─── Design tokens (design.json) ─────────────────────────────────────────────
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

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  DeleteAccountScreenState createState() => DeleteAccountScreenState();
}

class DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _supabase = Supabase.instance.client;
  final GlobalMethods _globalMethods = GlobalMethods();

  final TextEditingController _confirmController = TextEditingController();
  final FocusNode _confirmFocusNode = FocusNode();

  bool _isLoadingData = true;
  bool _isDeleting = false;
  bool _isConfirmed = false;

  String? _uid;
  String? _email;
  String? _name;
  String? _username;
  int? _profileId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _confirmController.addListener(_onConfirmTextChanged);
  }

  @override
  void dispose() {
    _confirmController.removeListener(_onConfirmTextChanged);
    _confirmController.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  void _onConfirmTextChanged() {
    final confirmed = _confirmController.text.trim() == 'CONFIRM';
    if (confirmed != _isConfirmed) {
      setState(() {
        _isConfirmed = confirmed;
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    _uid = user?.id;
    _email = user?.email;

    if (_uid == null) {
      if (mounted) setState(() => _isLoadingData = false);
      return;
    }

    try {
      final res = await _supabase
          .from('profiles')
          .select('name, username, email, profile_id')
          .eq('id', _uid!)
          .limit(1);

      if (res.isNotEmpty && mounted) {
        final data = res[0];
        setState(() {
          _name = data['name'] as String?;
          _username = data['username'] as String?;
          _email = (data['email'] as String?) ?? _email;
          _profileId = data['profile_id'] as int?;
          _isLoadingData = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[DeleteAccount] Error loading profile: $e');
    }

    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _showFinalConfirmationSheet({
    required BuildContext context,
    required Color surface,
    required Color textPrim,
    required Color textSec,
    required Color border,
  }) async {
    _confirmFocusNode.unfocus();

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_Design.radiusLg)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _Design.screenPadH,
              vertical: _Design.space5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: _Design.space5),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _Design.primaryDim,
                      shape: BoxShape.circle,
                      border: Border.all(color: _Design.primaryBorder, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: _Design.primary,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: _Design.space4),
                Text(
                  tr("delete_account_confirm_modal_title"),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrim,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: _Design.space2),
                Text(
                  tr("delete_account_confirm_modal_desc"),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSec,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: _Design.space6),
                SizedBox(
                  height: _Design.ctaHeight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(modalContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Design.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_Design.radiusMd),
                      ),
                    ),
                    child: Text(
                      tr("delete_account_confirm_action"),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _Design.space3),
                SizedBox(
                  height: _Design.ctaHeight,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(modalContext).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrim,
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_Design.radiusMd),
                      ),
                    ),
                    child: Text(
                      tr("cancel"),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true && mounted) {
      _executeAccountDeletion();
    }
  }

  Future<void> _executeAccountDeletion() async {
    if (_uid == null) return;

    setState(() => _isDeleting = true);

    try {
      final session = _supabase.auth.currentSession;
      final accessToken = session?.accessToken;

      bool backendDeleted = false;

      // 1. Call backend API to delete from auth.users (service role) and purge databases
      if (accessToken != null && accessToken.isNotEmpty) {
        try {
          final uri = Uri.parse('$caffeineApiUrl/user/account');
          final headers = {
            'Content-Type': 'application/json',
            if (caffeineApiKey.isNotEmpty) 'x-api-key': caffeineApiKey,
            'Authorization': 'Bearer $accessToken',
          };
          final response = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            backendDeleted = true;
          } else {
            debugPrint(
                '[DeleteAccount] Backend returned status ${response.statusCode}: ${response.body}');
          }
        } catch (apiErr) {
          debugPrint(
              '[DeleteAccount] Error calling delete account API: $apiErr');
        }
      }

      // 2. Direct client fallback cleanup if backend call was unreachable
      if (!backendDeleted) {
        Future<void> safeDelete(
            String table, String column, String value) async {
          try {
            await _supabase.from(table).delete().eq(column, value);
          } catch (e) {
            debugPrint(
                '[DeleteAccount] Notice: could not clear $table for $value: $e');
          }
        }

        await safeDelete('continue_watching_history', 'user_id', _uid!);
        await safeDelete('playback_history_events', 'user_id', _uid!);
        await safeDelete('completed_watch_history', 'user_id', _uid!);
        await safeDelete('bookmarks', 'user_id', _uid!);
        await safeDelete('usernames', 'user_id', _uid!);
        await safeDelete('messages', 'user_id', _uid!);
        await safeDelete('profiles', 'id', _uid!);
      }

      if (!mounted) return;

      // 3. Clear local databases, cached data and sign out
      final signInProvider =
          Provider.of<SignInProvider>(context, listen: false);
      await signInProvider.clearStoredData();
      await signInProvider.userSignOut();

      if (mounted) {
        // 4. Clear navigation stack and route directly to welcome screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr("account_deleted_successfully"),
              style: kTextSmallBodyStyle,
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        final msg = e.message.toLowerCase();
        if (msg.contains('mismatch')) {
          _globalMethods.authErrorHandle(tr("user_mismatch"), context);
        } else if (msg.contains('not found')) {
          _globalMethods.authErrorHandle(tr("user_not_found"), context);
        } else if (msg.contains('recent') && msg.contains('login')) {
          _globalMethods.authErrorHandle(tr("requires_recent_login"), context);
        } else {
          _globalMethods.authErrorHandle(e.message, context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        _globalMethods.authErrorHandle(e.toString(), context);
      }
    }
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

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(context, textPrim, border, isDark),
        body: const Center(
          child: CircularProgressIndicator(
            color: _Design.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_uid == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(context, textPrim, border, isDark),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _Design.screenPadH),
            child: Text(
              tr("user_not_found"),
              textAlign: TextAlign.center,
              style: TextStyle(color: textSec, fontSize: 15),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(context, textPrim, border, isDark),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: _Design.screenPadH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: _Design.space4),

            // Danger Header Card
            _buildWarningHero(textPrim, textSec),

            const SizedBox(height: _Design.space5),

            // Target Account Summary
            _buildAccountContextCard(
              surface: surface,
              border: border,
              textPrim: textPrim,
              textSec: textSec,
            ),

            const SizedBox(height: _Design.space5),

            // Consequences List
            _buildConsequencesCard(
              surface: surface,
              border: border,
              textPrim: textPrim,
              textSec: textSec,
            ),

            const SizedBox(height: _Design.space6),

            // Confirmation Input Section
            _buildConfirmationInput(
              surface: surface,
              cardBg: cardBg,
              border: border,
              textPrim: textPrim,
              textSec: textSec,
            ),

            const SizedBox(height: _Design.space6),

            // Destructive Delete Button
            SizedBox(
              height: _Design.ctaHeight,
              child: ElevatedButton(
                onPressed: (_isConfirmed && !_isDeleting)
                    ? () => _showFinalConfirmationSheet(
                          context: context,
                          surface: surface,
                          textPrim: textPrim,
                          textSec: textSec,
                          border: border,
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Design.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      _Design.primary.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_Design.radiusMd),
                  ),
                ),
                child: _isDeleting
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
                          const Icon(Icons.delete_forever_rounded, size: 22),
                          const SizedBox(width: _Design.space2),
                          Text(
                            tr("delete_account_button"),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Color textPrim,
    Color border,
    bool isDark,
  ) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? _Design.bgSurfaceDark : _Design.bgSurfaceLight,
      leading: Padding(
        padding: const EdgeInsets.only(left: _Design.space2),
        child: Material(
          color: isDark ? _Design.iconBgDark : border,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 22,
              ),
            ),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: textPrim),
      title: Text(
        tr("delete_account"),
        style: TextStyle(
          color: textPrim,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWarningHero(Color textPrim, Color textSec) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _Design.primaryDim,
            shape: BoxShape.circle,
            border: Border.all(color: _Design.primaryBorder, width: 1.5),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: _Design.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: _Design.space3),
        Text(
          tr("delete_account_warning_title"),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textPrim,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: _Design.space2),
        Text(
          tr("delete_account_warning_desc"),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textSec,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountContextCard({
    required Color surface,
    required Color border,
    required Color textPrim,
    required Color textSec,
  }) {
    final avatarId = _profileId ?? 0;
    final displayName = (_name != null && _name!.isNotEmpty)
        ? _name!
        : (_username != null && _username!.isNotEmpty)
            ? _username!
            : tr("profile");

    return Container(
      padding: const EdgeInsets.all(_Design.space4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_Design.radiusMd),
        border: Border.all(color: border),
        boxShadow: const [_Design.shadowCard],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_Design.radiusSm),
            child: SizedBox(
              width: 48,
              height: 48,
              child: CachedNetworkImage(
                imageUrl: AvatarUtils.getAvatarUrl(avatarId),
                fit: BoxFit.cover,
                memCacheWidth: 100,
                memCacheHeight: 100,
                placeholder: (_, __) => Container(color: _Design.primaryDim),
                errorWidget: (_, __, ___) => Image.asset(
                  'assets/images/profiles/$avatarId.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _Design.primaryDim,
                    child: const Icon(
                      Icons.person_rounded,
                      color: _Design.primary,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: _Design.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrim,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_username != null && _username!.isNotEmpty)
                  Text(
                    '@$_username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSec,
                      fontSize: 13,
                    ),
                  ),
                if (_email != null && _email!.isNotEmpty)
                  Text(
                    _email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsequencesCard({
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
        children: [
          _buildConsequenceRow(
            icon: Icons.bookmark_remove_outlined,
            text: tr("delete_account_consequence_bookmarks"),
            textPrim: textPrim,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: _Design.space3),
            child: Divider(height: 1, color: border),
          ),
          _buildConsequenceRow(
            icon: Icons.history_toggle_off_rounded,
            text: tr("delete_account_consequence_history"),
            textPrim: textPrim,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: _Design.space3),
            child: Divider(height: 1, color: border),
          ),
          _buildConsequenceRow(
            icon: Icons.person_remove_outlined,
            text: tr("delete_account_consequence_profile"),
            textPrim: textPrim,
          ),
        ],
      ),
    );
  }

  Widget _buildConsequenceRow({
    required IconData icon,
    required String text,
    required Color textPrim,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: _Design.primary,
        ),
        const SizedBox(width: _Design.space3),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textPrim,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationInput({
    required Color surface,
    required Color cardBg,
    required Color border,
    required Color textPrim,
    required Color textSec,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr("delete_account_input_label"),
          style: TextStyle(
            color: textPrim,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: _Design.space2),
        TextFormField(
          controller: _confirmController,
          focusNode: _confirmFocusNode,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(
            color: textPrim,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
            hintText: tr("delete_account_input_hint"),
            hintStyle: TextStyle(
              color: textSec.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
            filled: true,
            fillColor: surface,
            prefixIcon: const Icon(
              Icons.lock_person_outlined,
              size: 22,
              color: _Design.primary,
            ),
            suffixIcon: _isConfirmed
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 22,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: _Design.space4,
              vertical: _Design.space3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_Design.radiusSm),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_Design.radiusSm),
              borderSide: BorderSide(
                color: _isConfirmed ? Colors.green.withValues(alpha: 0.6) : border,
              ),
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
    );
  }
}

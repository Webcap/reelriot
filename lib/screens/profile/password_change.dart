import 'package:reelriot/provider/settings_provider.dart';
import 'package:reelriot/utils/globlal_methods.dart';
import 'package:reelriot/utils/theme/textStyle.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reelriot/utils/pwned_password.dart';


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
  static const radiusSm = 12.0;
  static const screenPadH = 24.0;
  static const space2 = 8.0;
  static const space4 = 16.0;
  static const space6 = 24.0;
  static const ctaHeight = 52.0;
  static const shadowCard = BoxShadow(
    color: Color(0x38000000),
    blurRadius: 30,
    offset: Offset(0, 10),
  );
}

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = Supabase.instance.client.auth;
  final GlobalMethods _globalMethods = GlobalMethods();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _currentPasswordFocus = FocusNode();
  final FocusNode _newPasswordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _userLoaded = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _email = user.email;
        _userLoaded = true;
      });
    } else {
      setState(() => _userLoaded = true);
    }
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return tr("enter_password");
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return tr("enter_new_pass");
    }
    if (value.length < 6) {
      return tr("weak_password");
    }
    if (value == '12345678' ||
        value == 'qwertyuiop' ||
        value.toLowerCase() == 'password') {
      return tr("lame_password");
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return tr("repeat_new_password");
    }
    if (value != _newPasswordController.text) {
      return tr("password_mismatch");
    }
    return null;
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _email;
    if (email == null || email.isEmpty) {
      _globalMethods.authErrorHandle(tr("user_not_found"), context);
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    setState(() => _isLoading = true);

    try {
      final pwnedResult = await checkPwnedPassword(newPassword);
      if (pwnedResult.isPwned) {
        if (!mounted) return;
        _globalMethods.authErrorHandle(
          'This password has appeared in a known public data breach (${pwnedResult.breachCount} times). Please choose a different password.',
          context,
        );
        return;
      }

      // Re-auth with current password so Supabase allows password change
      await _auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      if (!mounted) return;

      await _auth.updateUser(UserAttributes(password: newPassword));

      // Revoke all other platform sessions on password change for security
      try {
        await _auth.signOut(scope: SignOutScope.others);
      } catch (e) {
        debugPrint('[PasswordChange] Failed signing out other sessions: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr("password_changed"),
            maxLines: 2,
            style: kTextSmallBodyStyle,
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') && msg.contains('login')) {
        _globalMethods.authErrorHandle(tr("wrong_password"), context);
      } else if (msg.contains('wrong') && msg.contains('password')) {
        _globalMethods.authErrorHandle(tr("wrong_password"), context);
      } else if (msg.contains('weak')) {
        _globalMethods.authErrorHandle(tr("weak_password"), context);
      } else if (msg.contains('recent') && msg.contains('login')) {
        _globalMethods.authErrorHandle(tr("requires_recent_login"), context);
      } else {
        _globalMethods.authErrorHandle(e.message, context);
      }
    } catch (e) {
      if (mounted) {
        _globalMethods.authErrorHandle(tr("error_occured"), context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isDark = themeMode == 'dark' || themeMode == 'amoled';
    final bg = isDark ? _Design.bgCanvasDark : _Design.bgCanvasLight;
    final surface = isDark ? _Design.bgSurfaceDark : _Design.bgSurfaceLight;
    final textPrim = isDark ? _Design.textPrimDark : _Design.textPrimLight;
    final textSec = isDark ? _Design.textSecDark : _Design.textSecLight;
    final border = isDark ? _Design.borderDark : _Design.borderLight;

    if (!_userLoaded) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(
            color: _Design.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_email == null || _email!.isEmpty) {
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: _Design.space6),
              Text(
                tr("password_change"),
                style: TextStyle(
                  color: textPrim,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: _Design.space2),
              Text(
                tr("process_stuck"),
                style: TextStyle(
                  color: textSec,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: _Design.space6),
              _buildCard(
                surface: surface,
                border: border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPasswordField(
                      context: context,
                      controller: _currentPasswordController,
                      focusNode: _currentPasswordFocus,
                      nextFocus: _newPasswordFocus,
                      label: tr("current_password"),
                      obscure: _obscureCurrent,
                      onToggleObscure: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                      validator: _validateCurrentPassword,
                      textPrim: textPrim,
                      textSec: textSec,
                      border: border,
                      surface: surface,
                    ),
                    const SizedBox(height: _Design.space4),
                    _buildPasswordField(
                      context: context,
                      controller: _newPasswordController,
                      focusNode: _newPasswordFocus,
                      nextFocus: _confirmPasswordFocus,
                      label: tr("enter_new_pass"),
                      obscure: _obscureNew,
                      onToggleObscure: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      validator: _validateNewPassword,
                      textPrim: textPrim,
                      textSec: textSec,
                      border: border,
                      surface: surface,
                    ),
                    const SizedBox(height: _Design.space4),
                    _buildPasswordField(
                      context: context,
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocus,
                      nextFocus: null,
                      label: tr("repeat_new_password"),
                      obscure: _obscureConfirm,
                      onToggleObscure: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: _validateConfirm,
                      textPrim: textPrim,
                      textSec: textSec,
                      border: border,
                      surface: surface,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _Design.space6),
              SizedBox(
                height: _Design.ctaHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Design.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _Design.primary.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_Design.radiusMd),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          tr("reset_password"),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
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
        tr("change_password"),
        style: TextStyle(
          color: textPrim,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCard({
    required Color surface,
    required Color border,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_Design.radiusMd),
        border: Border.all(color: border),
        boxShadow: const [_Design.shadowCard],
      ),
      padding: const EdgeInsets.all(_Design.space4),
      child: child,
    );
  }

  Widget _buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required FocusNode? nextFocus,
    required String label,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
    required Color textPrim,
    required Color textSec,
    required Color border,
    required Color surface,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textInputAction:
          nextFocus != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: nextFocus != null
          ? (_) => FocusScope.of(context).requestFocus(nextFocus)
          : null,
      keyboardType: TextInputType.visiblePassword,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSec),
        errorMaxLines: 2,
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
          borderSide: const BorderSide(color: _Design.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_Design.radiusSm),
          borderSide: const BorderSide(color: _Design.primary),
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          size: 22,
          color: textPrim,
        ),
        suffixIcon: IconButton(
          onPressed: onToggleObscure,
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 22,
            color: textSec,
          ),
        ),
      ),
      style: TextStyle(color: textPrim, fontSize: 15),
    );
  }
}

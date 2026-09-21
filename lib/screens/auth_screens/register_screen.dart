import 'package:provider/provider.dart';
import 'package:reelriot/provider/bookmarks_provider.dart';
import 'package:reelriot/provider/recently_watched_provider.dart';
import 'package:reelriot/functions/functions.dart';
import 'package:reelriot/utils/theme/textStyle.dart';
import 'package:reelriot/utils/globals.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:reelriot/models/profile_image_list.dart';
import 'package:reelriot/screens/home_screen/dash_screen.dart';
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/utils/globlal_methods.dart';
import 'package:reelriot/utils/routes/app_pages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reelriot/utils/pwned_password.dart';


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const Color _bgColor = Color(0xFF030712);
  static const Color _surfaceColor = Color(0xFF0B0F14);
  static const Color _surfaceBorder = Color(0x14FFFFFF);
  static const Color _primaryColor = Color(0xFFDC2626);
  static const Color _secondaryColor = Color(0xFF7C3AED);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xB8FFFFFF);

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _passwordVerifyFocusNode = FocusNode();
  final ProfileImages profileImages = ProfileImages();

  int profileValue = 0;
  int selectedProfile = 0;
  bool _obscureText = true;
  String _emailAddress = '';
  String _password = '';
  String _userName = '';
  bool _isUserVerified = false;
  final _formKey = GlobalKey<FormState>();
  final _auth = Supabase.instance.client.auth;
  final _supabase = Supabase.instance.client;
  final GlobalMethods _globalMethods = GlobalMethods();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordVerifyFocusNode.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  Future<bool> usernameExists(String username) async {
    final res = await _supabase
        .from('usernames')
        .select('username')
        .eq('username', username.trim().toLowerCase())
        .limit(1);
    return res.isEmpty;
  }

  Future<bool> checkIfDocExists(String username) async {
    final res = await _supabase
        .from('usernames')
        .select('username')
        .eq('username', username.trim().toLowerCase())
        .limit(1);
    return res.isNotEmpty;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      errorMaxLines: 3,
      labelText: label,
      labelStyle: const TextStyle(color: _textSecondary),
      prefixIcon: Icon(icon, color: _textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primaryColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primaryColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primaryColor, width: 1.4),
      ),
    );
  }

  Widget _buildProfilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose profile avatar',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr("choose_profile"),
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: profileImages.profile().map((Profile profile) {
              final isSelected = profileValue == profile.index;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  selectedColor: _primaryColor.withValues(alpha: 0.18),
                  side: BorderSide(
                    color: isSelected ? _primaryColor : const Color(0x1FFFFFFF),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  labelPadding: const EdgeInsets.all(4),
                  label: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 58,
                      width: 58,
                      color: Colors.black,
                      child: Image.asset(
                        'assets/images/profiles/${profile.index}.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      profileValue = (selected ? profile.index : 0);
                      selectedProfile = profile.index;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void submitForm() async {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();
    var date = DateTime.now().toString();
    debugPrint('[Signup] Form submitted at $date');
    final value = await checkConnection();
    if (!mounted) return;

    if (!value) {
      debugPrint('[Signup] No network connection');
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(
          content: Text(
            tr("check_connection"),
            maxLines: 3,
            style: kTextSmallBodyStyle,
          ),
          duration: const Duration(seconds: 3),
        ),
        context,
      );
      return;
    }

    if (!isValid) {
      debugPrint('[Signup] Form validation failed or widget not mounted');
      return;
    }

    _formKey.currentState!.save();
    debugPrint(
      '[Signup] Validation passed – email=$_emailAddress username=$_userName',
    );

    try {
      setState(() {
        _isLoading = true;
      });

      debugPrint('[Signup] Checking if username "$_userName" exists...');
      if (await checkIfDocExists(_userName)) {
        debugPrint('[Signup] Username "$_userName" already taken');
        if (!mounted) return;
        _globalMethods.authErrorHandle(
          tr("username_exists").toString(),
          context,
        );
        return;
      }

      debugPrint('[Signup] Checking password against HaveIBeenPwned...');
      final pwnedResult = await checkPwnedPassword(_password.trim());
      if (pwnedResult.isPwned) {
        debugPrint('[Signup] Password breached ${pwnedResult.breachCount} times');
        if (!mounted) return;
        _globalMethods.authErrorHandle(
          'This password has appeared in a known public data breach (${pwnedResult.breachCount} times). Please choose a different password.',
          context,
        );
        return;
      }

      debugPrint('[Signup] Username available, calling Supabase signUp...');
      final res = await _auth.signUp(
        email: _emailAddress.toLowerCase().trim(),
        password: _password.trim(),
        data: {
          'username': _userName.trim().toLowerCase(),
          'profile_id': selectedProfile,
          'avatar': selectedProfile, // Added for Dual-Source Sync
          'verified': _isUserVerified,
          'first_run': true,
          'onboarding_completed': false,
        },
      );

      final uid = res.user?.id;
      final identities = res.user?.identities;

      debugPrint(
        '[Signup] signUp response – uid=$uid identitiesCount=${identities?.length} confirmationSentAt=${res.user?.confirmationSentAt}',
      );

      // Check if email already exists (Supabase email enumeration protection returns a fake user with empty identities)
      if (uid == null || (identities != null && identities.isEmpty)) {
        debugPrint('[Signup] Registration failed: UID is null or identities is empty (likely email already exists)');
        if (!mounted) return;
        _globalMethods.authErrorHandle(tr("email_exists"), context);
        return;
      }

      sharedPrefsSingleton.setString('name', _userName.trim().toLowerCase());
      sharedPrefsSingleton.setString('email', _emailAddress);
      sharedPrefsSingleton.setString(
        'username',
        _userName.trim().toLowerCase(),
      );
      sharedPrefsSingleton.setString('uid', uid);
      sharedPrefsSingleton.setString('provider', 'email');
      debugPrint('[Signup] Local prefs saved for uid=$uid');

      final hasSession = res.session != null;
      if (hasSession) {
        try {
          debugPrint('[Signup] Inserting username record...');
          await _supabase.from('usernames').insert({
            'username': _userName.trim().toLowerCase(),
            'user_id': uid,
          });
        } catch (e) {
          debugPrint('[Signup] Notice: usernames insert: $e');
        }

        try {
          debugPrint('[Signup] Inserting bookmarks record...');
          await _supabase.from('bookmarks').insert({
            'user_id': uid,
            'movies': [],
            'tv_shows': [],
          });
        } catch (e) {
          debugPrint('[Signup] Notice: bookmarks insert: $e');
        }

        if (mounted) {
          try {
            await Provider.of<RecentProvider>(context, listen: false).clearLocalData();
            if (mounted) {
              await Provider.of<BookmarksProvider>(context, listen: false).clearAllLocalBookmarks();
            }
          } catch (_) {}
        }

        debugPrint('[Signup] All DB records created – signup complete');
        if (!mounted) return;
        Get.offAllNamed(Routes.onboarding);
      } else {
        // Email confirmation is required by Supabase Auth – show verification notice dialog
        debugPrint('[Signup] Email confirmation required. Showing verification notice dialog.');
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_rounded, color: Color(0xFFDC2626), size: 28),
                SizedBox(width: 12),
                Text(
                  "Check Your Email",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              "We've sent a verification link to $_emailAddress. Please confirm your email to complete registration, then log in.",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(); // Return to Login Screen
                },
                child: const Text(
                  "Go to Login",
                  style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    } on AuthException catch (error) {
      debugPrint(
        '[Signup] AuthException: ${error.message} (statusCode=${error.statusCode})',
      );
      if (!mounted) return;
      final msg = error.message.toLowerCase();
      if (msg.contains('weak') || msg.contains('password')) {
        _globalMethods.authErrorHandle(tr("weak_password"), context);
      } else if (msg.contains('already') || msg.contains('exists')) {
        _globalMethods.authErrorHandle(tr("email_exists"), context);
      } else if (msg.contains('invalid') && msg.contains('email')) {
        _globalMethods.authErrorHandle(tr("invalid_email"), context);
      } else if (msg.contains('operation') || msg.contains('not allowed')) {
        _globalMethods.authErrorHandle(tr("operation_not_allowed"), context);
      } else {
        _globalMethods.authErrorHandle(error.message, context);
      }
    } catch (e, stackTrace) {
      debugPrint('[Signup] Unexpected error: $e');
      debugPrint('[Signup] Stack trace: $stackTrace');
      if (!mounted) return;
      _globalMethods.authErrorHandle(e.toString(), context);
    } finally {
      debugPrint('[Signup] submitForm finished (isLoading → false)');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _bgColor,
                    _surfaceColor.withValues(alpha: 0.95),
                    _bgColor,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _secondaryColor.withValues(alpha: 0.34),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primaryColor.withValues(alpha: 0.26),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      foregroundColor: _textPrimary,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onDoubleTap: () {
                          setState(() {
                            _isUserVerified = true;
                          });
                        },
                        child: Hero(
                          tag: 'logo_shadow',
                          child: Container(
                            width: 92,
                            height: 92,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(color: _surfaceBorder),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 28,
                                  color: Color(0x52220000),
                                  offset: Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Image.asset(appConfig.appIcon),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _surfaceBorder),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 28,
                          color: Color(0x52000000),
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: AutofillGroup(
                      onDisposeAction: AutofillContextAction.commit,
                      child: Form(
                       key: _formKey,
                       child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfilePicker(),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const ValueKey('email'),
                            autofillHints: const [AutofillHints.email],
                            focusNode: _emailFocusNode,
                            validator: (value) {
                              if (value!.isEmpty || !value.contains('@')) {
                                return tr("invalid_email");
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () => FocusScope.of(context)
                                .requestFocus(_usernameFocusNode),
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: _textPrimary),
                            decoration: _inputDecoration(
                              label: tr("email_address"),
                              icon: Icons.email_outlined,
                            ),
                            onSaved: (value) {
                              _emailAddress = value!;
                            },
                            onChanged: (value) {
                              _emailAddress = value;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^[a-zA-Z0-9_]*'),
                              ),
                            ],
                            key: const ValueKey('username'),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return tr("username_empty");
                              } else if (value.length < 5 ||
                                  value.length > 30) {
                                return tr("username_short_long");
                              } else if (!value
                                  .contains(RegExp(r'^[a-zA-Z0-9_]*'))) {
                                return tr("invalid_username");
                              }
                              return null;
                            },
                            focusNode: _usernameFocusNode,
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () => FocusScope.of(context)
                                .requestFocus(_passwordFocusNode),
                            keyboardType: TextInputType.text,
                            style: const TextStyle(color: _textPrimary),
                            decoration: _inputDecoration(
                              label: tr("username"),
                              icon: Icons.alternate_email_rounded,
                            ),
                            onSaved: (value) {
                              _userName = value!;
                            },
                            onChanged: (value) {
                              _userName = value;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('Password'),
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (value!.isEmpty || value.length < 7) {
                                return tr("invalid_password");
                              } else if (value == '12345678' ||
                                  value == 'qwertyuiop' ||
                                  value == 'password') {
                                return tr("lame_password");
                              }
                              return null;
                            },
                            keyboardType: TextInputType.visiblePassword,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscureText,
                            onEditingComplete: () => FocusScope.of(context)
                                .requestFocus(_passwordVerifyFocusNode),
                            style: const TextStyle(color: _textPrimary),
                            decoration: _inputDecoration(
                              label: tr("enter_password"),
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                            onSaved: (value) {
                              _password = value!;
                            },
                            onChanged: (value) {
                              _password = value;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('VerifyPassword'),
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (value != _password) {
                                return tr("password_mismatch");
                              }
                              return null;
                            },
                            obscureText: _obscureText,
                            keyboardType: TextInputType.visiblePassword,
                            focusNode: _passwordVerifyFocusNode,
                            style: const TextStyle(color: _textPrimary),
                            decoration: _inputDecoration(
                              label: tr("repeat_password"),
                              icon: Icons.lock_reset_rounded,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : submitForm,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    _primaryColor.withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      tr("sign_up"),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                tr("terms_privacy_agreement"),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textSecondary.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                       ),
                      ),      // closes Form
                    ),        // closes AutofillGroup
                  ),          // closes Container
                ],
              ),
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }
}

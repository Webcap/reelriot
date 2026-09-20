import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:reelriot/provider/sign_in_provider.dart';
import 'package:reelriot/utils/app_images.dart';
import 'package:reelriot/utils/routes/app_pages.dart';

class LinkAccountBottomSheet extends StatefulWidget {
  final SignInProvider sp;
  final String? email;

  const LinkAccountBottomSheet({
    super.key,
    required this.sp,
    this.email,
  });

  static Future<void> show(BuildContext context, SignInProvider sp, {String? email}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0B0F14) : const Color(0xFFFFFFFF);

    return Get.bottomSheet(
      LinkAccountBottomSheet(sp: sp, email: email),
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }

  @override
  State<LinkAccountBottomSheet> createState() => _LinkAccountBottomSheetState();
}

class _LinkAccountBottomSheetState extends State<LinkAccountBottomSheet> {
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? widget.sp.email ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password to confirm linking.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.sp.signInAndLinkGoogle(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Get.back(); // close bottom sheet
      Get.offAllNamed(Routes.dash);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = widget.sp.errorCode ?? e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrim = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0B0F14);
    final textSec = isDark ? const Color(0xB8FFFFFF) : const Color(0xFF475569);
    final border = isDark ? const Color(0x14FFFFFF) : const Color(0x140F172A);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isDark ? const Color(0x80FFFFFF) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AssetValues.googleLogo,
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Link Google Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrim,
                    fontFamily: 'PoppinsSB',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'An account with this email already exists. Enter your password to verify and link your Google account to your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSec,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: textPrim),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: textSec),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
                prefixIcon: Icon(Icons.email_outlined, color: textSec),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: textPrim),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: textSec),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
                prefixIcon: Icon(Icons.lock_outline, color: textSec),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: textSec,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Verify & Link Google Account',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'Cancel',
                style: TextStyle(color: textSec, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

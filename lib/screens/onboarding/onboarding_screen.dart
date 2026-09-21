import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:reelriot/models/profile_image_list.dart';
import 'package:reelriot/provider/sign_in_provider.dart';
import 'package:reelriot/services/analytics_service.dart';
import 'package:reelriot/utils/routes/app_pages.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // Design Tokens
  static const Color _bgColor = Color(0xFF030712);
  static const Color _surfaceColor = Color(0xFF0B0F14);
  static const Color _surfaceBorder = Color(0x14FFFFFF);
  static const Color _primaryColor = Color(0xFFDC2626);
  static const Color _secondaryColor = Color(0xFF7C3AED);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xB8FFFFFF);

  final ProfileImages _profileImages = ProfileImages();
  late final PageController _pageController;

  int _currentStep = 0; // 0: Welcome, 1: Avatar Picker, 2: Confirmation
  int _selectedAvatarId = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    AnalyticsService.instance.trackEvent('Onboarding Started');
    AnalyticsService.instance.trackEvent('Onboarding Step View', {
      'step': 1,
      'name': 'Welcome',
    });
    final sp = Provider.of<SignInProvider>(context, listen: false);
    if (sp.profileId != null && sp.profileId! >= 0) {
      _selectedAvatarId = sp.profileId!;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (step < 0 || step > 2) return;
    setState(() => _currentStep = step);
    final stepNames = ['Welcome', 'Identity', 'Confirmation'];
    AnalyticsService.instance.trackEvent('Onboarding Step View', {
      'step': step + 1,
      'name': stepNames[step],
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _handleFinish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final sp = Provider.of<SignInProvider>(context, listen: false);
      await sp.completeOnboarding(avatarId: _selectedAvatarId);

      AnalyticsService.instance.trackEvent('Onboarding Completed', {
        'avatar_id': _selectedAvatarId,
      });
      AnalyticsService.instance.setUserProfile('avatar_id', _selectedAvatarId);
      AnalyticsService.instance.setUserProfile('onboarding_completed', true);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Get.offAllNamed(Routes.dash);
    } catch (e) {
      debugPrint('[Onboarding] Complete error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Something went wrong. Please try again.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: _primaryColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width >= 600;

    return PopScope(
      canPop: false, // Disallow bypassing onboarding
      child: Scaffold(
        backgroundColor: _bgColor,
        body: Stack(
          children: [
            // Ambient Radial Gradients
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _secondaryColor.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryColor.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Top Step Indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        for (int i = 0; i < 3; i++) ...[
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= _currentStep
                                    ? _primaryColor
                                    : _surfaceBorder,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: i == _currentStep
                                    ? [
                                        BoxShadow(
                                          color: _primaryColor.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                          if (i < 2) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),

                  // Main Interactive Pages
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildWelcomeStep(isTablet),
                        _buildAvatarStep(isTablet),
                        _buildConfirmationStep(isTablet),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 1: Welcome ────────────────────────────────────────────────────────
  Widget _buildWelcomeStep(bool isTablet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Glowing Hero Icon
          Container(
            width: isTablet ? 120 : 96,
            height: isTablet ? 120 : 96,
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _primaryColor.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              size: isTablet ? 56 : 46,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Reelriot',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: isTablet ? 34 : 28,
              fontWeight: FontWeight.w800,
              fontFamily: 'PoppinsSB',
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Your personal gateway to cinema, series, and live streaming. Let’s get your profile set up.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: isTablet ? 16 : 14.5,
                height: 1.55,
              ),
            ),
          ),
          const Spacer(),
          // Action Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _goToStep(1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: _primaryColor.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PoppinsSB',
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Step 2: Identity / Avatar Selection ────────────────────────────────────
  Widget _buildAvatarStep(bool isTablet) {
    final allProfiles = _profileImages.profile();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Choose Your Identity',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: isTablet ? 28 : 23,
              fontWeight: FontWeight.w800,
              fontFamily: 'PoppinsSB',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select an avatar to represent you across Reelriot',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: isTablet ? 15 : 13.5,
            ),
          ),
          const SizedBox(height: 20),

          // Scrollable Avatar Grid
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _surfaceBorder),
              ),
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTablet ? 6 : 4,
                  crossAxisSpacing: isTablet ? 16 : 12,
                  mainAxisSpacing: isTablet ? 16 : 12,
                ),
                itemCount: allProfiles.length,
                itemBuilder: (context, index) {
                  final profile = allProfiles[index];
                  final isSelected = _selectedAvatarId == profile.index;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedAvatarId = profile.index);
                      AnalyticsService.instance.trackEvent(
                        'Onboarding Avatar Selected',
                        {'avatar_id': profile.index},
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _primaryColor : _surfaceBorder,
                          width: isSelected ? 3.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _primaryColor.withValues(alpha: 0.45),
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
                            child: Image.asset(
                              'assets/images/profiles/${profile.index}.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white.withValues(alpha: 0.05),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: _primaryColor,
                                ),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _primaryColor.withValues(alpha: 0.35),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),
          // Navigation Actions
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _goToStep(0);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: const BorderSide(color: _surfaceBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _goToStep(2);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: _primaryColor.withValues(alpha: 0.35),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'PoppinsSB',
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Step 3: Confirmation ───────────────────────────────────────────────────
  Widget _buildConfirmationStep(bool isTablet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Large Selected Avatar Preview with Sparkle Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: isTablet ? 160 : 130,
                height: isTablet ? 160 : 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primaryColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.4),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/profiles/$_selectedAvatarId.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bgColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'You\'re All Set!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: isTablet ? 34 : 28,
              fontWeight: FontWeight.w800,
              fontFamily: 'PoppinsSB',
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'Your profile is configured. Dive in and explore your personalized movies, series, and watchlists.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: isTablet ? 16 : 14.5,
                height: 1.55,
              ),
            ),
          ),
          const Spacer(),

          // Bottom Actions
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _goToStep(1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: const BorderSide(color: _surfaceBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleFinish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: _primaryColor.withValues(alpha: 0.4),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Enter Reelriot',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'PoppinsSB',
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

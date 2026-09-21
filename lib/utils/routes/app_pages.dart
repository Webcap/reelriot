import 'package:reelriot/screens/auth_screens/register_screen.dart';
import 'package:reelriot/screens/auth_screens/welcome.dart';
import 'package:reelriot/screens/auth_screens/splash_screen.dart';
import 'package:reelriot/screens/settings/settings.dart';
import 'package:reelriot/screens/profile/edit_profile.dart';
import 'package:reelriot/screens/profile/password_change.dart';
import 'package:reelriot/screens/home_screen/dash_screen.dart';
import 'package:reelriot/screens/profile/profile_page.dart';
import 'package:reelriot/screens/watch_history/watch_history_v2.dart';
import 'package:reelriot/screens/pair_tv_screen.dart';
import 'package:reelriot/screens/onboarding/onboarding_screen.dart';
import 'package:reelriot/utils/helpers/no_connection_screen.dart';
import 'package:get/get.dart';

part "app_routes.dart";

abstract class AppPages {
  static final pages = [
    GetPage(
      name: Routes.splash,
      page: SplashScreen.new,
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.login,
      page: WelcomeScreen.new,
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.dash,
      page: CaffieneHomePage.new,
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.profileEdit,
      page: ProfileEdit.new,
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.settings,
      page: Settings.new,
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.passwordChangeScreen,
      page: PasswordChangeScreen.new,
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.noConnection,
      page: NetworkErrorItem.new,
      transition: Transition.upToDown,
    ),
    GetPage(
      name: Routes.profile,
      page: ProfilePage.new,
      transition: Transition.upToDown,
    ),
    GetPage(
      name: Routes.signup,
      page: SignupScreen.new,
      transition: Transition.upToDown,
    ),
    GetPage(
      name: Routes.watchHistory,
      page: WatchHistoryV2.new,
      transition: Transition.upToDown,
    ),
    GetPage(
      name: Routes.pairTv,
      page: PairTvScreen.new,
      transition: Transition.upToDown,
    ),
    GetPage(
      name: Routes.onboarding,
      page: OnboardingScreen.new,
      transition: Transition.fade,
    ),
  ];
}

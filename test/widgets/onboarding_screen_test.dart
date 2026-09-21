import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:reelriot/provider/sign_in_provider.dart';
import 'package:reelriot/screens/onboarding/onboarding_screen.dart';

class MockSignInProvider extends Mock implements SignInProvider {}

void main() {
  late MockSignInProvider mockSignInProvider;

  setUp(() {
    mockSignInProvider = MockSignInProvider();
    when(() => mockSignInProvider.profileId).thenReturn(0);
    when(() => mockSignInProvider.firstRun).thenReturn(true);
    when(() => mockSignInProvider.isSignedIn).thenReturn(true);
  });

  Widget buildSubject() {
    return ChangeNotifierProvider<SignInProvider>.value(
      value: mockSignInProvider,
      child: const GetMaterialApp(
        home: OnboardingScreen(),
      ),
    );
  }

  testWidgets('renders Welcome step initially with Get Started button', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Welcome to Reelriot'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('clicking Get Started transitions to Choose Your Identity step', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final getStartedButton = find.text('Get Started');
    expect(getStartedButton, findsOneWidget);

    await tester.tap(getStartedButton);
    await tester.pumpAndSettle();

    expect(find.text('Choose Your Identity'), findsOneWidget);
    expect(find.text('Select an avatar to represent you across Reelriot'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('clicking Continue transitions to Confirmation step', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // Step 1 -> Step 2
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Step 2 -> Step 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text("You're All Set!"), findsOneWidget);
    expect(find.text('Enter Reelriot'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });
}

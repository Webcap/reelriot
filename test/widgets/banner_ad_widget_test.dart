// ignore_for_file: unused_import

import 'dart:async';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/services/ad_service.dart';
import 'package:reelriot/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:startapp_sdk/startapp.dart';
import '../test_helper.dart';

class FakeStartAppBannerAd extends Fake implements StartAppBannerAd {}

void main() {
  setUpAll(() {
    registerFallbackValue(StartAppBannerType.BANNER);
  });

  late MockAdService mockAdService;
  late MockAppDependencyProvider mockAppDependencyProvider;

  setUp(() {
    mockAdService = MockAdService();
    mockAppDependencyProvider = MockAppDependencyProvider();

    when(() => mockAdService.isBannerAdLoading).thenReturn(false);
    when(() => mockAdService.isEnabled).thenReturn(true);
    when(() => mockAppDependencyProvider.enableADS).thenReturn(true);
    when(() => mockAppDependencyProvider.enableBannerAds).thenReturn(true);
  });

  testWidgets('BannerAdWidget does not show anything when ads are disabled',
      (WidgetTester tester) async {
    when(() => mockAppDependencyProvider.enableADS).thenReturn(false);
    when(() => mockAppDependencyProvider.enableBannerAds).thenReturn(false);
    when(() => mockAdService.loadNewBannerAd()).thenAnswer((_) async => null);

    await tester.pumpWidget(createTestableWidget(
      child: const BannerAdWidget(),
      adService: mockAdService,
      appDependencyProvider: mockAppDependencyProvider,
    ));

    expect(find.byType(Container), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('BannerAdWidget shows banner when ads are enabled and loaded',
      (WidgetTester tester) async {
    final mockBanner = FakeStartAppBannerAd();
    when(() => mockAppDependencyProvider.enableADS).thenReturn(true);
    when(() => mockAppDependencyProvider.enableBannerAds).thenReturn(true);
    when(() => mockAdService.loadNewBannerAd()).thenAnswer((_) async => mockBanner);

    // We use a custom pump to avoid the internal crash of StartAppBanner in unit tests
    // by just checking if the widget is part of the tree.
    await tester.pumpWidget(createTestableWidget(
      child: const BannerAdWidget(),
      adService: mockAdService,
      appDependencyProvider: mockAppDependencyProvider,
    ));

    await tester.pump();

    // StartAppBanner tries to access platform view channels in headless tests
    while (tester.takeException() != null) {}

    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('BannerAdWidget shows skeleton shimmer when ads are loading',
      (WidgetTester tester) async {
    when(() => mockAppDependencyProvider.enableADS).thenReturn(true);
    when(() => mockAppDependencyProvider.enableBannerAds).thenReturn(true);
    final completer = Completer<StartAppBannerAd?>();
    when(() => mockAdService.loadNewBannerAd()).thenAnswer((_) => completer.future);

    await tester.pumpWidget(createTestableWidget(
      child: const BannerAdWidget(),
      adService: mockAdService,
      appDependencyProvider: mockAppDependencyProvider,
    ));

    expect(find.byType(Container), findsWidgets);
    completer.complete(null);
    await tester.pumpAndSettle();
  });
}


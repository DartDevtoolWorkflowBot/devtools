// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/controls/performance_controls.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  const windowSize = Size(3000.0, 1000.0);

  setUp(() {
    setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(NotificationService, NotificationService());
  });

  group('$PerformanceControls', () {
    late MockServiceConnectionManager mockServiceManager;
    late MockPerformanceController mockPerformanceController;

    setUp(() {
      mockServiceManager = MockServiceConnectionManager();
      when(mockServiceManager.serviceExtensionManager)
          .thenReturn(FakeServiceExtensionManager());
      final connectedApp = MockConnectedApp();
      mockConnectedApp(
        connectedApp,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );
      when(mockServiceManager.connectedApp).thenReturn(connectedApp);
      setGlobal(ServiceConnectionManager, mockServiceManager);
      mockPerformanceController = createMockPerformanceControllerWithDefaults();
    });

    tearDown(() {
      offlineController.exitOfflineMode();
    });

    Future<void> pumpControls(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          PerformanceControls(
            controller: mockPerformanceController,
            onClear: () {},
          ),
          performance: mockPerformanceController,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgetsWithWindowSize(
      'builds for Flutter app',
      windowSize,
      (WidgetTester tester) async {
        await pumpControls(tester);
        expect(find.byType(ExitOfflineButton), findsNothing);
        expect(find.byType(VisibilityButton), findsOneWidget);
        expect(find.byIcon(Icons.block), findsOneWidget);
        expect(find.text('Performance Overlay'), findsOneWidget);
        expect(find.text('Enhance Tracing'), findsOneWidget);
        expect(find.text('More debugging options'), findsOneWidget);
        expect(find.byIcon(Icons.file_download), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'builds for non flutter app',
      windowSize,
      (WidgetTester tester) async {
        mockConnectedApp(
          mockServiceManager.connectedApp!,
          isFlutterApp: false,
          isProfileBuild: false,
          isWebApp: false,
        );
        await pumpControls(tester);

        expect(find.byType(ExitOfflineButton), findsNothing);
        expect(find.byType(VisibilityButton), findsNothing);
        expect(find.byIcon(Icons.block), findsOneWidget);
        expect(find.text('Performance Overlay'), findsNothing);
        expect(find.text('Enhance Tracing'), findsNothing);
        expect(find.text('More debugging options'), findsNothing);
        expect(find.byIcon(Icons.file_download), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'builds for offline mode',
      windowSize,
      (WidgetTester tester) async {
        offlineController.enterOfflineMode(
          offlineApp: serviceManager.connectedApp!,
        );
        await pumpControls(tester);
        expect(find.byType(ExitOfflineButton), findsOneWidget);
        expect(find.byType(VisibilityButton), findsOneWidget);
        expect(find.byIcon(Icons.block), findsNothing);
        expect(find.text('Performance Overlay'), findsNothing);
        expect(find.text('Enhance Tracing'), findsNothing);
        expect(find.text('More debugging options'), findsNothing);
        expect(find.byIcon(Icons.file_download), findsNothing);
        expect(find.byIcon(Icons.settings_outlined), findsNothing);
        offlineController.exitOfflineMode();
      },
    );
  });
}

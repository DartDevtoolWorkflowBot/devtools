// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/logging/_log_details.dart';
import 'package:devtools_app/src/screens/logging/_logs_table.dart';
import 'package:devtools_app/src/screens/logging/_message_column.dart';
import 'package:devtools_app/src/service/service_extension_widgets.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late LoggingScreen screen;
  late MockLoggingController mockLoggingController;
  const windowSize = Size(1000.0, 1000.0);

  group('Logging Screen', () {
    Future<void> pumpLoggingScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          const LoggingScreenBody(),
          logging: mockLoggingController,
        ),
      );
    }

    setUp(() {
      mockLoggingController = createMockLoggingControllerWithDefaults();

      final FakeServiceManager fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp!.isFlutterWebAppNow)
          .thenReturn(false);
      when(fakeServiceManager.connectedApp!.isProfileBuildNow)
          .thenReturn(false);
      when(fakeServiceManager.errorBadgeManager.errorCountNotifier('logging'))
          .thenReturn(ValueNotifier<int>(0));
      setGlobal(NotificationService, NotificationService());
      setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());

      screen = LoggingScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Logging'), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'builds with no data',
      windowSize,
      (WidgetTester tester) async {
        await pumpLoggingScreen(tester);
        expect(find.byType(LoggingScreenBody), findsOneWidget);
        expect(find.byType(LogsTable), findsOneWidget);
        expect(find.byType(LogDetails), findsOneWidget);
        expect(find.byType(ClearButton), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(FilterButton), findsOneWidget);
        expect(find.byType(StructuredErrorsToggle), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'can clear logs',
      windowSize,
      (WidgetTester tester) async {
        await pumpLoggingScreen(tester);
        verifyNever(mockLoggingController.clear());
        await tester.tap(find.byType(ClearButton));
        verify(mockLoggingController.clear()).called(1);
      },
    );

    testWidgetsWithWindowSize(
      'search field is disabled with no data',
      windowSize,
      (WidgetTester tester) async {
        await pumpLoggingScreen(tester);
        verifyNever(mockLoggingController.clear());

        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);
        final TextField textField = tester.widget(textFieldFinder) as TextField;
        expect(textField.enabled, isFalse);
      },
    );

    testWidgetsWithWindowSize(
      'can toggle structured errors',
      windowSize,
      (WidgetTester tester) async {
        final serviceManager = FakeServiceManager();
        when(serviceManager.connectedApp!.isFlutterWebAppNow).thenReturn(false);
        when(serviceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
        setGlobal(
          ServiceConnectionManager,
          serviceManager,
        );
        await pumpLoggingScreen(tester);
        Switch toggle = tester.widget(find.byType(Switch));
        expect(toggle.value, false);

        serviceManager.serviceExtensionManager.fakeServiceExtensionStateChanged(
          structuredErrors.extension,
          'true',
        );
        await tester.pumpAndSettle();
        toggle = tester.widget(find.byType(Switch));
        expect(toggle.value, true);

        // TODO(djshuckerow): Hook up fake extension state querying.
      },
    );

    group('MessageColumn', () {
      late MessageColumn column;

      setUp(() {
        column = MessageColumn();
      });

      test('compare sorts logs correctly', () {
        final a = LogData('test', 'Hello world', 1);
        final b = LogData('test', 'Test test test', 1);
        expect(column.compare(a, b), equals(-1));
      });

      test('compare special cases sorting for frame logs', () {
        final a = LogData('flutter.frame', '#9  3.6ms ', 1);
        final b = LogData('flutter.frame', '#10  3.6ms ', 1);
        expect(column.compare(a, b), equals(-1));

        // The number of spaces between the frame number and duration as well
        // as after the duration can be inconsistent. Verify that the regexp
        // still works.
        final c = LogData('flutter.frame', '#10 3.6ms', 1);
        final d = LogData('flutter.frame', '#9  3.6ms ', 1);
        expect(column.compare(c, d), equals(1));

        final e = LogData('flutter.frame', '#10  3.6ms ', 1);
        final f = LogData('flutter.frame', '#9foo  3.6ms ', 1);
        expect(column.compare(e, f), equals(-1));

        final l1 = LogData('flutter.frame', '#2  3.6ms ', 1);
        final l2 = LogData('flutter.frame', '#2NOTAMATCH  3.6ms ', 1);
        final l3 = LogData('flutter.frame', '#10  3.6ms ', 1);
        final l4 = LogData('flutter.frame', '#10NOTAMATCH  3.6ms ', 1);
        final l5 = LogData('flutter.frame', '#11  3.6ms ', 1);
        final l6 = LogData('flutter.frame', '#11NOTAMATCH  3.6ms ', 1);
        final list = [l1, l2, l3, l4, l5, l6];
        list.sort(column.compare);

        expect(list[0], equals(l1));
        expect(list[1], equals(l3));
        expect(list[2], equals(l5));
        expect(list[3], equals(l4));
        expect(list[4], equals(l6));
        expect(list[5], equals(l2));
      });
    });
  });
}

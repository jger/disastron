// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/chat/presentation/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'LoadingWidget renders title, indeterminate progress bar, and badge',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingWidget(
              message: 'Starting offline assistant…',
              hint: '100% on-device • Private & offline',
            ),
          ),
        ),
      );

      expect(find.text('Starting offline assistant…'), findsOneWidget);
      expect(find.text('100% on-device • Private & offline'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final LinearProgressIndicator indicator = tester.widget(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull);
    },
  );

  testWidgets(
    'LoadingWidget renders determinate progress, percentage, and stage',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingWidget(
              message: 'Starting offline assistant…',
              progress: 0.45,
              stage: 'Initializing on-device engine…',
              hint: '100% on-device • Private & offline',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Starting offline assistant…'), findsOneWidget);
      expect(find.text('Initializing on-device engine…'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final LinearProgressIndicator indicator = tester.widget(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.45, 0.01));
    },
  );

  testWidgets('LoadingWidget clamps progress values over 1.0 (0-100 scale)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingWidget(
            message: 'Starting offline assistant…',
            progress: 80,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('80%'), findsOneWidget);
    final LinearProgressIndicator indicator = tester.widget(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.8, 0.01));
  });
}

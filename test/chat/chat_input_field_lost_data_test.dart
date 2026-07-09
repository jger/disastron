// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:convert';

import 'package:disastron/features/chat/presentation/chat_handlers.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_input_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// 1x1 transparent PNG, so `Image.memory` can actually decode the restored bytes.
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _FakeImagePicker extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  _FakeImagePicker(this._lostData);

  final LostDataResponse _lostData;
  int getLostDataCalls = 0;

  @override
  Future<LostDataResponse> getLostData() async {
    getLostDataCalls++;
    return _lostData;
  }
}

/// Pumps the field as if running on [platform].
///
/// The override must be cleared before the test body returns: flutter_test
/// verifies foundation debug vars are unset before `tearDown` ever runs.
Future<void> _pumpInputFieldOn(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputField(
            isImageSupported: true,
            onSubmitted: (ChatMessageDraft _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('ChatInputField lost-data recovery', () {
    testWidgets(
      'restores a photo Android delivered after killing the process',
      (WidgetTester tester) async {
        final _FakeImagePicker fake = _FakeImagePicker(
          LostDataResponse(
            file: XFile.fromData(_pngBytes, name: 'lost.png'),
            type: RetrieveType.image,
          ),
        );
        ImagePickerPlatform.instance = fake;

        await _pumpInputFieldOn(tester, TargetPlatform.android);

        expect(fake.getLostDataCalls, 1);
        expect(find.byType(Image), findsOneWidget);
        // The recovered image makes the message sendable without typing.
        final IconButton send = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send),
        );
        expect(send.onPressed, isNotNull);
      },
    );

    testWidgets('shows nothing when there is no lost data', (
      WidgetTester tester,
    ) async {
      final _FakeImagePicker fake = _FakeImagePicker(LostDataResponse.empty());
      ImagePickerPlatform.instance = fake;

      await _pumpInputFieldOn(tester, TargetPlatform.android);

      expect(fake.getLostDataCalls, 1);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('surfaces a message when recovery failed', (
      WidgetTester tester,
    ) async {
      final _FakeImagePicker fake = _FakeImagePicker(
        LostDataResponse(exception: PlatformException(code: 'no_access')),
      );
      ImagePickerPlatform.instance = fake;

      await _pumpInputFieldOn(tester, TargetPlatform.android);

      expect(find.byType(Image), findsNothing);
      expect(
        find.textContaining('Could not restore the photo'),
        findsOneWidget,
      );
    });

    testWidgets('is skipped off Android, where retrieveLostData throws', (
      WidgetTester tester,
    ) async {
      final _FakeImagePicker fake = _FakeImagePicker(LostDataResponse.empty());
      ImagePickerPlatform.instance = fake;

      await _pumpInputFieldOn(tester, TargetPlatform.iOS);

      expect(fake.getLostDataCalls, 0);
    });
  });
}

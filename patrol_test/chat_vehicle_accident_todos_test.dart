// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

// E2E: first-run "Vehicle crash" chip should produce at least one checklist
// item (native update_checklist tool or legacy [[TODOS]] fallback).
//
// Prereq: `make patrol-prepare` on the connected device/emulator.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'support/chat_patrol_boot.dart';

void main() {
  patrolTest('vehicle crash chip creates todos', ($) async {
    const String logTag = 'patrol-todos';
    await bootIntoPatrolChat($, logTag: logTag);

    patrolChatLog('tapping Vehicle crash chip', logTag: logTag);
    final DateTime chipDeadline = DateTime.now().add(
      const Duration(seconds: 15),
    );
    while (!$.tester.any(find.text('Vehicle crash')) &&
        DateTime.now().isBefore(chipDeadline)) {
      await $.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Vehicle crash'), findsOneWidget);
    await $('Vehicle crash').tap();
    await $.pump(const Duration(milliseconds: 500));

    final PatrolAssistantTurnResult turn = await awaitPatrolAssistantTurn($);
    expect(
      turn.tokensStarted && turn.completed,
      isTrue,
      reason:
          'Assistant never finished after Vehicle crash chip. ${turn.describe()}',
    );
    patrolChatLog('assistant turn done: ${turn.describe()}', logTag: logTag);

    patrolChatLog('opening Todos tab', logTag: logTag);
    await $(Icons.checklist_rounded).tap();
    await $.pump(const Duration(seconds: 1));

    expect(
      find.text('No items yet.'),
      findsNothing,
      reason:
          'Todos tab is still empty after Vehicle crash flow. '
          'Check update_checklist tool / [[TODOS]] fallback.',
    );
    expect(find.byType(CheckboxListTile), findsWidgets);
  });
}

import 'package:disastron/features/tool_layout/domain/app_tool.dart';
import 'package:disastron/features/tool_layout/domain/app_tool_catalog.dart';
import 'package:disastron/features/tool_layout/domain/tool_placement_defaults.dart';
import 'package:disastron/features/tool_layout/domain/tool_placement_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildToolPlacementDefaults', () {
    test('matches preset dashboard and drawer layout', () {
      final Map<String, ToolPlacementFlags> d = buildToolPlacementDefaults();

      expect(d[AppToolCatalog.callHelpId]!.dashboard, isTrue);
      expect(d[AppToolCatalog.callHelpId]!.drawer, isFalse);

      expect(d[AppToolCatalog.sosId]!.dashboard, isTrue);
      expect(d['karpa_cpr']!.dashboard, isTrue);
      expect(d['trip_planning']!.dashboard, isTrue);

      expect(d['general_safety']!.dashboard, isFalse);
      expect(d['general_safety']!.drawer, isFalse);

      expect(d[AppToolCatalog.appearanceSettingsId]!.drawer, isTrue);
      expect(d[AppToolCatalog.appearanceSettingsId]!.dashboard, isFalse);

      expect(d[AppToolCatalog.offlineModelId]!.drawer, isTrue);
      expect(d[AppToolCatalog.aboutId]!.drawer, isTrue);
    });
  });

  group('mergeToolPlacements', () {
    test('uses defaults when prefs empty', () {
      final Map<String, ToolPlacementFlags> merged =
          mergeToolPlacements(buildToolPlacementDefaults(), null);
      expect(merged[AppToolCatalog.callHelpId]!.dashboard, isTrue);
    });

    test('merges partial persisted JSON', () {
      const String raw = '''
{
  "call_help": {"dashboard": false, "drawer": true},
  "earthquake": {"dashboard": true, "drawer": false}
}
''';
      final Map<String, ToolPlacementFlags> merged =
          mergeToolPlacements(buildToolPlacementDefaults(), raw);

      expect(merged[AppToolCatalog.callHelpId]!.dashboard, isFalse);
      expect(merged[AppToolCatalog.callHelpId]!.drawer, isTrue);
      expect(merged['earthquake']!.dashboard, isTrue);
      expect(merged[AppToolCatalog.sosId]!.dashboard, isTrue);
    });

    test('ignores unknown tool ids in JSON', () {
      const String raw = '{"unknown_tool": {"dashboard": true, "drawer": true}}';
      final Map<String, ToolPlacementFlags> merged =
          mergeToolPlacements(buildToolPlacementDefaults(), raw);
      expect(merged.containsKey('unknown_tool'), isFalse);
    });
  });

  group('validatePlacementChange', () {
    test('allows wiki article to be hidden everywhere', () {
      final Map<String, ToolPlacementFlags> current =
          buildToolPlacementDefaults();
      final ToolPlacementValidation v = validatePlacementChange(
        current: current,
        toolId: 'earthquake',
        surface: AppToolSurface.dashboard,
        newValue: false,
      );
      expect(v.isOk, isTrue);
    });

    test('blocks removing call_help from both surfaces', () {
      final Map<String, ToolPlacementFlags> current =
          Map<String, ToolPlacementFlags>.from(buildToolPlacementDefaults());
      current[AppToolCatalog.callHelpId] = const ToolPlacementFlags(
        dashboard: false,
        drawer: true,
      );

      final ToolPlacementValidation v = validatePlacementChange(
        current: current,
        toolId: AppToolCatalog.callHelpId,
        surface: AppToolSurface.drawer,
        newValue: false,
      );

      expect(v.isOk, isFalse);
      expect(v.messageKey, 'tool_layout_validation_must_keep_one');
    });

    test('blocks removing sos from both surfaces', () {
      final Map<String, ToolPlacementFlags> current =
          buildToolPlacementDefaults();

      final ToolPlacementValidation v = validatePlacementChange(
        current: current,
        toolId: AppToolCatalog.sosId,
        surface: AppToolSurface.dashboard,
        newValue: false,
      );

      expect(v.isOk, isFalse);
    });

    test('blocks removing settings from both surfaces', () {
      final Map<String, ToolPlacementFlags> current =
          buildToolPlacementDefaults();

      final ToolPlacementValidation v = validatePlacementChange(
        current: current,
        toolId: AppToolCatalog.appearanceSettingsId,
        surface: AppToolSurface.drawer,
        newValue: false,
      );

      expect(v.isOk, isFalse);
    });
  });

  group('encodeToolPlacements', () {
    test('round-trips through merge', () {
      final Map<String, ToolPlacementFlags> original =
          buildToolPlacementDefaults();
      original['earthquake'] = const ToolPlacementFlags(
        dashboard: true,
        drawer: true,
      );
      final String raw = encodeToolPlacements(original);
      final Map<String, ToolPlacementFlags> merged =
          mergeToolPlacements(buildToolPlacementDefaults(), raw);
      expect(merged['earthquake']!.dashboard, isTrue);
      expect(merged['earthquake']!.drawer, isTrue);
    });
  });
}

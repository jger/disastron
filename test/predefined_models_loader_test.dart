import 'package:disastron/features/inference/data/predefined_models_loader.dart';
import 'package:disastron/features/inference/domain/predefined_inference_model.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

void _ensureFlutterTestBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

void main() {
  group('PredefinedInferenceModelsLoader.parseYaml', () {
    test('parses models and default_preset_id (SSOT)', () {
      const String yaml = '''
default_preset_id: gemma3_270m_q8
models:
  - id: gemma3_270m_q8
    title: Gemma 3 270M IT (q8)
    description: Smallest preset
    url: https://example.com/a.task
    size_mb: 304
    access: gated
    multimodal: true
  - id: gemma4_e2b_litertlm
    title: Gemma 4 E2B
    description: Larger
    url: https://example.com/b.litertlm
    model_type: gemma4
    size_mb: 2468
    access: public
    multimodal: true
    requires_token: false
''';

      final PredefinedInferenceModelsCatalog catalog =
          PredefinedInferenceModelsLoader.parseYaml(yaml);

      expect(catalog.defaultPresetId, 'gemma3_270m_q8');
      expect(catalog.defaultPreset.id, 'gemma3_270m_q8');
      expect(catalog.defaultPreset.title, 'Gemma 3 270M IT (q8)');
      expect(catalog.models, hasLength(2));

      expect(catalog.defaultPreset.modelType, ModelType.gemmaIt);
      expect(catalog.defaultPreset.sizeMb, 304);
      expect(catalog.defaultPreset.multimodal, isTrue);
      expect(catalog.defaultPreset.requiresHuggingFaceToken, isTrue);
      expect(
        catalog.defaultPreset.downloadMetadataLine,
        contains('304 MB'),
      );

      final PredefinedInferenceModel gemma4 = catalog.models[1];
      expect(gemma4.modelType, ModelType.gemma4);
      expect(gemma4.access, InferencePresetAccess.public);
      expect(gemma4.requiresToken, isFalse);
      expect(gemma4.requiresHuggingFaceToken, isFalse);
    });

    test('rejects default_preset_id not in models', () {
      const String yaml = '''
default_preset_id: missing_id
models:
  - id: gemma3_270m_q8
    title: Gemma 3 270M IT (q8)
    description: Smallest preset
    url: https://example.com/a.task
''';

      expect(
        () => PredefinedInferenceModelsLoader.parseYaml(yaml),
        throwsFormatException,
      );
    });

    test('bundled inference_models.yaml parses with metadata', () async {
      _ensureFlutterTestBinding();
      final catalog = await PredefinedInferenceModelsLoader.loadBundled();
      expect(catalog.defaultPresetId, 'gemma3_270m_q8');
      expect(catalog.defaultPreset.sizeMb, 304);
      expect(catalog.models.length, greaterThanOrEqualTo(5));
      final public = catalog.models
          .where((m) => m.access == InferencePresetAccess.public)
          .toList();
      expect(public, isNotEmpty);
      for (final m in public) {
        expect(m.requiresHuggingFaceToken, isFalse);
      }
    });

    test('requires default_preset_id', () {
      const String yaml = '''
models:
  - id: gemma3_270m_q8
    title: Gemma 3 270M IT (q8)
    description: Smallest preset
    url: https://example.com/a.task
''';

      expect(
        () => PredefinedInferenceModelsLoader.parseYaml(yaml),
        throwsFormatException,
      );
    });
  });
}

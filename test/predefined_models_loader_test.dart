import 'package:disastron/features/inference/data/predefined_models_loader.dart';
import 'package:disastron/features/inference/domain/predefined_inference_model.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

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
  - id: gemma4_e2b_litertlm
    title: Gemma 4 E2B
    description: Larger
    url: https://example.com/b.litertlm
    model_type: gemma4
    requires_token: true
''';

      final PredefinedInferenceModelsCatalog catalog =
          PredefinedInferenceModelsLoader.parseYaml(yaml);

      expect(catalog.defaultPresetId, 'gemma3_270m_q8');
      expect(catalog.defaultPreset.id, 'gemma3_270m_q8');
      expect(catalog.defaultPreset.title, 'Gemma 3 270M IT (q8)');
      expect(catalog.models, hasLength(2));

      expect(catalog.defaultPreset.modelType, ModelType.gemmaIt);
      expect(catalog.defaultPreset.requiresHuggingFaceToken, isTrue);

      final PredefinedInferenceModel gemma4 = catalog.models[1];
      expect(gemma4.modelType, ModelType.gemma4);
      expect(gemma4.requiresToken, isTrue);
      expect(gemma4.requiresHuggingFaceToken, isTrue);
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

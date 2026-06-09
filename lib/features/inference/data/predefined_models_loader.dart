import 'package:disastron/core/assets/bundled_asset_io.dart';
import 'package:disastron/features/inference/domain/predefined_inference_model.dart';
import 'package:disastron/features/inference/domain/predefined_inference_models_state.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:yaml/yaml.dart';

const String kInferenceModelsAssetPath = 'assets/data/inference_models.yaml';

/// Loads and parses [kInferenceModelsAssetPath].
abstract final class PredefinedInferenceModelsLoader {
  PredefinedInferenceModelsLoader._();

  static Future<PredefinedInferenceModelsCatalog> loadBundled() async {
    final String raw = await loadBundledAssetString(kInferenceModelsAssetPath);
    return parseYaml(raw);
  }

  /// Loads bundled YAML once and registers the catalog for sync accessors.
  static Future<void> ensureLoaded() async {
    if (isPredefinedInferenceModelsCatalogLoaded) {
      return;
    }
    registerPredefinedInferenceModelsCatalog(await loadBundled());
  }

  static PredefinedInferenceModelsCatalog parseYaml(String raw) {
    final Object? decoded = loadYaml(raw);
    if (decoded is! YamlMap) {
      throw const FormatException(
        'Expected YAML map at $kInferenceModelsAssetPath',
      );
    }

    final String defaultId = _requiredString(decoded, 'default_preset_id');
    final Object? modelsNode = decoded['models'];
    if (modelsNode is! YamlList) {
      throw const FormatException(
        'Expected "models" list at $kInferenceModelsAssetPath',
      );
    }

    final List<PredefinedInferenceModel> models = <PredefinedInferenceModel>[];
    for (final Object? entry in modelsNode) {
      if (entry is! YamlMap) {
        throw const FormatException('Each model entry must be a map');
      }
      models.add(_modelFromYaml(entry));
    }
    if (models.isEmpty) {
      throw const FormatException(
        'At least one model required in $kInferenceModelsAssetPath',
      );
    }
    final PredefinedInferenceModel defaultPreset = models.firstWhere(
      (PredefinedInferenceModel m) => m.id == defaultId,
      orElse: () => throw FormatException(
        'default_preset_id "$defaultId" must match a model id in "models" at '
        '$kInferenceModelsAssetPath',
      ),
    );

    return PredefinedInferenceModelsCatalog(
      defaultPresetId: defaultId,
      defaultPreset: defaultPreset,
      models: List<PredefinedInferenceModel>.unmodifiable(models),
    );
  }

  static PredefinedInferenceModel _modelFromYaml(YamlMap map) {
    return PredefinedInferenceModel(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      description: _requiredString(map, 'description'),
      url: _requiredString(map, 'url'),
      modelType: _parseModelType(map['model_type']),
      backend: _parseBackend(map['backend']),
      requiresToken: _optionalBool(map['requires_token']),
      sizeMb: _optionalPositiveInt(map['size_mb']),
      access: _parseAccess(map['access']),
      multimodal: _optionalBool(map['multimodal']) ?? false,
      supportsLora: _optionalBool(map['supports_lora']) ?? false,
    );
  }

  static int? _optionalPositiveInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int && value > 0) {
      return value;
    }
    throw FormatException('Expected positive int, got $value');
  }

  static InferencePresetAccess _parseAccess(Object? raw) {
    if (raw == null) {
      return InferencePresetAccess.gated;
    }
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('access must be "public" or "gated"');
    }
    switch (raw.trim().toLowerCase()) {
      case 'public':
        return InferencePresetAccess.public;
      case 'gated':
        return InferencePresetAccess.gated;
      default:
        throw FormatException('Unknown access "$raw"; use public or gated');
    }
  }

  static InferenceBackend? _parseBackend(Object? raw) {
    if (raw == null) return null;
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('backend must be "litert" or "mediapipe"');
    }
    switch (raw.trim().toLowerCase()) {
      case 'litert':
        return InferenceBackend.litert;
      case 'mediapipe':
        return InferenceBackend.mediapipe;
      default:
        throw FormatException(
          'Unknown backend "$raw"; use litert or mediapipe',
        );
    }
  }

  static String _requiredString(YamlMap map, String key) {
    final Object? value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or empty "$key" in inference_models.yaml');
    }
    return value.trim();
  }

  static bool? _optionalBool(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw FormatException('Expected bool for requires_token, got $value');
  }

  static ModelType _parseModelType(Object? raw) {
    if (raw == null) {
      return ModelType.gemmaIt;
    }
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException(
        'model_type must be a non-empty string when set',
      );
    }
    final String name = raw.trim();
    for (final ModelType type in ModelType.values) {
      if (type.name == name) {
        return type;
      }
    }
    throw FormatException(
      'Unknown model_type "$raw"; use one of: ${ModelType.values.map((ModelType e) => e.name).join(", ")}',
    );
  }
}

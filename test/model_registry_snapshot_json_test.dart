import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ModelRegistrySnapshot roundtrip JSON', () {
    const InstalledModelEntry entry = InstalledModelEntry(
      id: 'preset:test',
      sourceUrlOrPath: 'https://example.com/m.task',
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
      displayTitle: 'Test',
      presetId: 'test',
    );
    const ModelRegistrySnapshot snap = ModelRegistrySnapshot(
      entries: <InstalledModelEntry>[entry],
      activeEntryId: 'preset:test',
    );
    final ModelRegistrySnapshot back = ModelRegistrySnapshot.fromJson(
      snap.toJson(),
    );
    expect(back.activeEntryId, snap.activeEntryId);
    expect(back.entries.length, 1);
    expect(back.entries.single.id, entry.id);
    expect(back.entries.single.modelType, ModelType.gemma4);
  });
}

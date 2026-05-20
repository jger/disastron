import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'model_registry_provider.g.dart';

@Riverpod(keepAlive: true)
Future<ModelRegistrySnapshot> modelRegistrySnapshot(Ref ref) async {
  final ModelRegistryStore store = ModelRegistryStore();
  await store.migrateFromLegacyIfNeeded();
  return store.readSnapshot();
}

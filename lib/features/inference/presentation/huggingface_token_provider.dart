import 'package:disastron/features/inference/data/huggingface_token_store.dart';
import 'package:disastron/features/inference/inference_bootstrap.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'huggingface_token_provider.g.dart';

final HuggingfaceTokenStore _hfTokenStore = HuggingfaceTokenStore();

@Riverpod(keepAlive: true)
class HuggingfaceToken extends _$HuggingfaceToken {
  @override
  Future<String?> build() async {
    return _hfTokenStore.read();
  }

  Future<void> save(String token) async {
    await _hfTokenStore.write(token);
    await InferenceBootstrap.initializeGemmaWithToken(token);
    ref.invalidateSelf();
  }

  Future<void> clear() async {
    await _hfTokenStore.clear();
    await InferenceBootstrap.initializeGemmaWithToken(null);
    ref.invalidateSelf();
  }
}

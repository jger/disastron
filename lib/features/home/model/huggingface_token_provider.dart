import 'package:disastron/features/home/model/huggingface_token_store.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
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
    await FlutterGemma.initialize(huggingFaceToken: token.trim());
    ref.invalidateSelf();
  }

  Future<void> clear() async {
    await _hfTokenStore.clear();
    await FlutterGemma.initialize();
    ref.invalidateSelf();
  }
}

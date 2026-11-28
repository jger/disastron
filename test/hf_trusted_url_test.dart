import 'package:disastron/features/inference/domain/inference_model_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts https Hugging Face hosts', () {
    expect(
      isTrustedHuggingFaceDownloadUrl(
        'https://huggingface.co/a/b/resolve/main/x.task',
      ),
      isTrue,
    );
    expect(isTrustedHuggingFaceDownloadUrl('https://hf.co/a/b'), isTrue);
    expect(
      isTrustedHuggingFaceDownloadUrl('HTTPS://HuggingFace.co/a/b'),
      isTrue,
    );
  });

  test('rejects http, other hosts, lookalikes and malformed urls', () {
    for (final String u in <String>[
      'http://huggingface.co/a/b',
      'https://example.com/x.task',
      'https://huggingface.co.evil.com/a',
      'https://evil-huggingface.co/a',
      'https://evil.com/huggingface.co',
      'https://huggingface.co@evil.com/a',
      'not a url',
      '',
    ]) {
      expect(isTrustedHuggingFaceDownloadUrl(u), isFalse, reason: u);
    }
  });
}

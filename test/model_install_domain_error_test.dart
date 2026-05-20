import 'package:disastron/features/inference/domain/model_install_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('403 maps to auth + HF page', () {
    const String url =
        'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/x.task';
    final ModelInstallDomainError e =
        mapModelInstallException(Exception('403 Forbidden'), downloadUrl: url);
    expect(e.kind, ModelInstallDomainErrorKind.auth);
    expect(e.isGated403, isTrue);
    expect(
      e.gatedModelPageUrl,
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview',
    );
  });

  test('enospc maps to storage', () {
    final ModelInstallDomainError e =
        mapModelInstallException(Exception('OS Error: ENOSPC'));
    expect(e.kind, ModelInstallDomainErrorKind.storage);
  });
}

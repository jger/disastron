import 'package:disastron/features/inference/domain/model_install_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('403 maps to auth + HF page', () {
    const String url =
        'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/x.task';
    final ModelInstallDomainError e = mapModelInstallException(
      Exception('403 Forbidden'),
      downloadUrl: url,
    );
    expect(e.kind, ModelInstallDomainErrorKind.auth);
    expect(e.isGated403, isTrue);
    expect(
      e.gatedModelPageUrl,
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview',
    );
  });

  test('enospc maps to storage', () {
    final ModelInstallDomainError e = mapModelInstallException(
      Exception('OS Error: ENOSPC'),
    );
    expect(e.kind, ModelInstallDomainErrorKind.storage);
  });

  // Characterizes current behavior, which is looser than the field names read:
  // isGated403 is set for ANY 403/401 on ANY host, and a 401 is not a 403 at
  // all. Only gatedModelPageUrl is host-aware.
  //
  // model_setup_widget.dart:257 gates the 'model_gated_help' copy on
  // isGated403, so a plain 401 from a non-HuggingFace host renders "this model
  // is gated" guidance. The "open model page" button below it is separately
  // guarded on gatedModelPageUrl != null, so only the copy is wrong, not the
  // link. Pinned as-is; fixing it is out of scope for the migration.
  test(
    '403 off huggingface is auth and flagged gated, but has no page url',
    () {
      final ModelInstallDomainError e = mapModelInstallException(
        Exception('403 Forbidden'),
        downloadUrl: 'https://example.com/models/x.task',
      );
      expect(e.kind, ModelInstallDomainErrorKind.auth);
      expect(e.isGated403, isTrue);
      expect(e.gatedModelPageUrl, isNull);
    },
  );

  test('403 without a download url has no page url', () {
    final ModelInstallDomainError e = mapModelInstallException(
      Exception('403 Forbidden'),
    );
    expect(e.kind, ModelInstallDomainErrorKind.auth);
    expect(e.gatedModelPageUrl, isNull);
  });

  test('401 maps to auth and is also flagged gated', () {
    final ModelInstallDomainError e = mapModelInstallException(
      Exception('401 Unauthorized'),
    );
    expect(e.kind, ModelInstallDomainErrorKind.auth);
    expect(e.isGated403, isTrue);
  });

  test('socket and timeout map to network', () {
    expect(
      mapModelInstallException(Exception('SocketException: failed')).kind,
      ModelInstallDomainErrorKind.network,
    );
    expect(
      mapModelInstallException(Exception('Connection timed out')).kind,
      ModelInstallDomainErrorKind.network,
    );
  });

  test('unrecognised failures map to unknown', () {
    expect(
      mapModelInstallException(Exception('kaboom')).kind,
      ModelInstallDomainErrorKind.unknown,
    );
  });
}

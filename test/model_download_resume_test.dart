import 'package:disastron/features/inference/data/model_download_resume_service.dart';
import 'package:disastron/features/inference/data/pending_model_download_store.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String url = 'https://huggingface.co/example/model.task';
  const String path = '/data/user/0/app/model.task';

  test('taskIdFor is stable for the same url and target path', () {
    expect(
      ModelDownloadResumeService.taskIdFor(url, path),
      ModelDownloadResumeService.taskIdFor(url, path),
    );
  });

  // taskIdFor must produce the same id as flutter_gemma's SmartDownloader
  // (mobile/smart_downloader.dart), otherwise an interrupted download is not
  // recognised on resume and restarts from byte zero. The id is not asserted
  // against a golden literal because String.hashCode is not guaranteed stable
  // across Dart SDKs -- both sides compute it at runtime, so only the shape and
  // the discrimination are contractual.
  //
  // If flutter_gemma's resume support is adopted and this service deleted,
  // re-verify resume end-to-end on device; these tests cannot catch a scheme
  // change upstream.
  test('taskIdFor matches the SmartDownloader hex_hex shape', () {
    expect(
      ModelDownloadResumeService.taskIdFor(url, path),
      matches(RegExp(r'^[0-9a-f]{1,8}_[0-9a-f]{1,8}$')),
    );
  });

  test('taskIdFor discriminates on url', () {
    expect(
      ModelDownloadResumeService.taskIdFor(url, path),
      isNot(
        ModelDownloadResumeService.taskIdFor(
          'https://huggingface.co/example/other.task',
          path,
        ),
      ),
    );
  });

  test('taskIdFor discriminates on target path', () {
    expect(
      ModelDownloadResumeService.taskIdFor(url, path),
      isNot(
        ModelDownloadResumeService.taskIdFor(
          url,
          '/data/user/0/app/other.task',
        ),
      ),
    );
  });

  test('PendingModelDownload json roundtrip', () {
    final PendingModelDownload pending = PendingModelDownload(
      url: 'https://huggingface.co/example/model.task',
      filename: 'model.task',
      presetId: 'gemma3n_e2b_int4',
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.task,
      lastProgress: 42,
      updatedAt: DateTime.utc(2026, 5, 21),
    );
    final PendingModelDownload? decoded = PendingModelDownload.fromJson(
      pending.toJson(),
    );
    expect(decoded, isNotNull);
    expect(decoded!.url, pending.url);
    expect(decoded.filename, pending.filename);
    expect(decoded.presetId, pending.presetId);
    expect(decoded.modelType, pending.modelType);
    expect(decoded.fileType, pending.fileType);
    expect(decoded.lastProgress, 42);
  });
}

import 'package:disastron/features/inference/data/model_download_resume_service.dart';
import 'package:disastron/features/inference/data/pending_model_download_store.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('taskIdFor is stable for the same url and target path', () {
    const String url = 'https://huggingface.co/example/model.task';
    const String path = '/data/user/0/app/model.task';
    expect(
      ModelDownloadResumeService.taskIdFor(url, path),
      ModelDownloadResumeService.taskIdFor(url, path),
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
    final PendingModelDownload? decoded =
        PendingModelDownload.fromJson(pending.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.url, pending.url);
    expect(decoded.filename, pending.filename);
    expect(decoded.presetId, pending.presetId);
    expect(decoded.modelType, pending.modelType);
    expect(decoded.fileType, pending.fileType);
    expect(decoded.lastProgress, 42);
  });
}

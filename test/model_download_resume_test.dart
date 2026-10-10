import 'package:disastron/features/inference/data/model_download_resume_service.dart';
import 'package:disastron/features/inference/data/pending_model_download_store.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '/fake/temp';

  @override
  Future<String?> getApplicationSupportPath() async => '/fake/support';

  @override
  Future<String?> getApplicationDocumentsPath() async => '/fake/documents';

  @override
  Future<String?> getLibraryPath() async => '/fake/library';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String path = '/fake/temp/model.task';

  setUpAll(() {
    PathProviderPlatform.instance = _FakePathProvider();
  });

  test('taskIdFor is stable for the same target path', () async {
    expect(
      await ModelDownloadResumeService.taskIdFor(path),
      await ModelDownloadResumeService.taskIdFor(path),
    );
  });

  test('taskIdFor matches SmartDownloader computeTaskId shape', () async {
    final String id = await ModelDownloadResumeService.taskIdFor(path);
    expect(id, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('taskIdFor discriminates on target path', () async {
    expect(
      await ModelDownloadResumeService.taskIdFor(path),
      isNot(
        await ModelDownloadResumeService.taskIdFor('/fake/temp/other.task'),
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

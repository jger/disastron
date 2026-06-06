import 'package:disastron/features/wiki/data/wiki_downloader_service.dart';
import 'package:disastron/features/wiki/domain/wiki_source.dart';
import 'package:disastron/features/wiki/presentation/wiki_sources_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wiki_download_provider.g.dart';

enum WikiDownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

class WikiDownloadState {
  const WikiDownloadState({
    required this.status,
    this.progress = 0.0,
    this.error,
    this.sizeMB = 0.0,
  });
  final WikiDownloadStatus status;
  final double progress;
  final String? error;
  final double sizeMB;

  WikiDownloadState copyWith({
    WikiDownloadStatus? status,
    double? progress,
    String? error,
    double? sizeMB,
  }) {
    return WikiDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      sizeMB: sizeMB ?? this.sizeMB,
    );
  }
}

@Riverpod(keepAlive: true)
class WikiDownload extends _$WikiDownload {
  final _service = const WikiDownloaderService();

  @override
  Future<Map<String, WikiDownloadState>> build() async {
    final sources = await ref.watch(wikiSourcesProvider.future);
    final map = <String, WikiDownloadState>{};
    for (final s in sources) {
      final downloaded = await _service.isPageDownloaded(s.url);
      double sizeMB = 0;
      if (downloaded) {
        sizeMB = await _service.getPageDirectorySizeMB(s.url);
      }
      map[s.url] = WikiDownloadState(
        status: downloaded
            ? WikiDownloadStatus.downloaded
            : WikiDownloadStatus.notDownloaded,
        sizeMB: sizeMB,
      );
    }
    return map;
  }

  Future<void> downloadPage(WikiSource source) async {
    final currentMap = Map<String, WikiDownloadState>.from(state.value ?? {});

    // Set downloading state
    currentMap[source.url] = const WikiDownloadState(
      status: WikiDownloadStatus.downloading,
    );
    state = AsyncValue.data(currentMap);

    try {
      await _service.downloadPage(
        source.url,
        onProgress: (progress) {
          final map = Map<String, WikiDownloadState>.from(state.value ?? {});
          map[source.url] = WikiDownloadState(
            status: WikiDownloadStatus.downloading,
            progress: progress,
          );
          state = AsyncValue.data(map);
        },
      );

      final sizeMB = await _service.getPageDirectorySizeMB(source.url);
      final map = Map<String, WikiDownloadState>.from(state.value ?? {});
      map[source.url] = WikiDownloadState(
        status: WikiDownloadStatus.downloaded,
        progress: 1,
        sizeMB: sizeMB,
      );
      state = AsyncValue.data(map);
    } catch (e) {
      final map = Map<String, WikiDownloadState>.from(state.value ?? {});
      map[source.url] = WikiDownloadState(
        status: WikiDownloadStatus.failed,
        error: e.toString(),
      );
      state = AsyncValue.data(map);
    }
  }

  Future<void> deleteDownloadedPage(WikiSource source) async {
    try {
      await _service.deleteOfflinePage(source.url);
      final map = Map<String, WikiDownloadState>.from(state.value ?? {});
      map[source.url] = const WikiDownloadState(
        status: WikiDownloadStatus.notDownloaded,
      );
      state = AsyncValue.data(map);
    } catch (_) {}
  }
}

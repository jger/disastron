import 'package:disastron/features/wiki/data/wiki_sources_store.dart';
import 'package:disastron/features/wiki/domain/wiki_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wiki_sources_provider.g.dart';

@Riverpod(keepAlive: true)
class WikiSources extends _$WikiSources {
  final _store = const WikiSourcesStore();

  @override
  Future<List<WikiSource>> build() async {
    return _store.loadSources();
  }

  Future<void> addSource(WikiSource source) async {
    final current = state.value ?? [];
    if (current.any((s) => s.url == source.url)) {
      return;
    }
    final updated = [...current, source];
    state = AsyncValue.data(updated);
    await _store.saveSources(updated);
  }

  Future<void> updateSource(String oldUrl, WikiSource updatedSource) async {
    final current = state.value ?? [];
    final updated = current
        .map((s) => s.url == oldUrl ? updatedSource : s)
        .toList();
    state = AsyncValue.data(updated);
    await _store.saveSources(updated);
  }

  Future<void> deleteSource(String url) async {
    final current = state.value ?? [];
    final updated = current.where((s) => s.url != url).toList();
    state = AsyncValue.data(updated);
    await _store.saveSources(updated);
  }

  Future<void> importSources(List<WikiSource> newSources) async {
    state = AsyncValue.data(newSources);
    await _store.saveSources(newSources);
  }
}

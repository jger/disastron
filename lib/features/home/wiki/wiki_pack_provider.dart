import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/features/home/wiki/wiki_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final FutureProvider<WikiPack> wikiPackProvider =
    FutureProvider<WikiPack>((Ref ref) async {
  final AppLocaleState state = await ref.watch(appLocaleProvider.future);
  return WikiPack.loadForLocale(state.localeCode);
});

// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/features/wiki/presentation/wiki_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wiki_pack_provider.g.dart';

@riverpod
Future<WikiPack> wikiPack(Ref ref) async {
  final AppLocaleState state = await ref.watch(appLocaleProvider.future);
  return WikiPack.loadForLocale(state.localeCode);
}

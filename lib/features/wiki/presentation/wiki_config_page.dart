import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:disastron/app/app_locales.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/features/wiki/data/wiki_sources_store.dart';
import 'package:disastron/features/wiki/domain/wiki_source.dart';
import 'package:disastron/features/wiki/presentation/wiki_download_provider.dart';
import 'package:disastron/features/wiki/presentation/wiki_sources_provider.dart';
import 'package:disastron/shared/widgets/genui_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

@RoutePage()
class WikiConfigPage extends ConsumerWidget {
  const WikiConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(wikiSourcesProvider);
    final localeAsync = ref.watch(appLocaleProvider);
    final String currentLocale = localeAsync.maybeWhen(
      data: (s) => s.localeCode,
      orElse: () => 'en',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('wiki_config_title'.tr()),
        actions: [
          IconButton(
            tooltip: 'wiki_import'.tr(),
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () => _importWikiYaml(context, ref),
          ),
          IconButton(
            tooltip: 'wiki_export'.tr(),
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportWikiYaml(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: sourcesAsync.when(
        data: (sources) {
          final localSources = sources
              .where((s) => s.locale == currentLocale)
              .toList();

          return localSources.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'wiki_config_empty'.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: localSources.length,
                  itemBuilder: (context, index) {
                    final s = localSources[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GenUiCard(
                        title: s.title,
                        subtitle: '${s.category} · [${s.locale.toUpperCase()}]',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SelectableText(
                              s.url,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showAddEditSourceDialog(
                                    context,
                                    ref,
                                    source: s,
                                    currentLocale: currentLocale,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: Text('wiki_edit'.tr()),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                  ),
                                  onPressed: () =>
                                      _confirmDeleteSource(context, ref, s),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: Text('wiki_delete'.tr()),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('wiki_load_error'.tr(args: [err.toString()]))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditSourceDialog(
          context,
          ref,
          currentLocale: currentLocale,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddEditSourceDialog(
    BuildContext context,
    WidgetRef ref, {
    required String currentLocale,
    WikiSource? source,
  }) async {
    final isEdit = source != null;
    final urlController = TextEditingController(text: source?.url ?? '');
    final titleController = TextEditingController(text: source?.title ?? '');
    final categoryController = TextEditingController(
      text: source?.category ?? '',
    );
    String selectedLocale = source?.locale ?? currentLocale;

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'wiki_edit_source'.tr() : 'wiki_add_source'.tr()),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'wiki_title_label'.tr(),
                    hintText: 'wiki_title_hint'.tr(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'wiki_field_required'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: 'wiki_url_label'.tr(),
                    hintText: 'https://...',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'wiki_field_required'.tr();
                    }
                    final cleanVal = val.trim();
                    if (!cleanVal.startsWith('http://') &&
                        !cleanVal.startsWith('https://')) {
                      return 'wiki_url_invalid'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: 'wiki_category_label'.tr(),
                    hintText: 'wiki_category_hint'.tr(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'wiki_field_required'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedLocale,
                  decoration: InputDecoration(
                    labelText: 'wiki_locale_label'.tr(),
                  ),
                  items: AppLocales.codes
                      .map(
                        (code) => DropdownMenuItem(
                          value: code,
                          child: Text(code.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      selectedLocale = val;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final inputSource = WikiSource(
                  url: urlController.text.trim(),
                  title: titleController.text.trim(),
                  category: categoryController.text.trim(),
                  locale: selectedLocale,
                );

                if (isEdit) {
                  await ref
                      .read(wikiSourcesProvider.notifier)
                      .updateSource(source.url, inputSource);
                } else {
                  await ref
                      .read(wikiSourcesProvider.notifier)
                      .addSource(inputSource);
                }

                if (context.mounted) {
                  Navigator.pop(ctx);
                }
              }
            },
            child: Text('wiki_save'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSource(
    BuildContext context,
    WidgetRef ref,
    WikiSource source,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('wiki_delete_title'.tr()),
        content: Text('wiki_delete_message'.tr(args: [source.title])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('remove'.tr()),
          ),
        ],
      ),
    );

    if (ok ?? false) {
      // Delete downloaded files first
      await ref
          .read(wikiDownloadProvider.notifier)
          .deleteDownloadedPage(source);
      // Delete from config list
      await ref.read(wikiSourcesProvider.notifier).deleteSource(source.url);
    }
  }

  Future<void> _exportWikiYaml(BuildContext context, WidgetRef ref) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final file = File('${docDir.path}/wiki.yaml');
      if (!file.existsSync()) {
        final list = await ref.read(wikiSourcesProvider.future);
        await ref.read(wikiSourcesProvider.notifier).importSources(list);
      }
      final bytes = await file.readAsBytes();
      final String? path = await FilePicker.saveFile(
        dialogTitle: 'wiki_export_title'.tr(),
        fileName: 'wiki.yaml',
        bytes: bytes,
      );
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('wiki_export_success'.tr(args: [path]))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('wiki_export_failed'.tr(args: [e.toString()])),
          ),
        );
      }
    }
  }

  Future<void> _importWikiYaml(BuildContext context, WidgetRef ref) async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['yaml', 'yml'],
      );
      final String? path = result?.files.single.path;
      if (path == null) return;

      final content = await File(path).readAsString();
      // Try to parse using store
      const tempStore = WikiSourcesStore();
      final parsed = tempStore.parseWikiSourcesFromYaml(content);
      if (parsed.isEmpty) {
        throw FormatException('wiki_import_invalid_yaml'.tr());
      }

      await ref.read(wikiSourcesProvider.notifier).importSources(parsed);

      // Invalidate status provider to check newly imported files
      ref.invalidate(wikiDownloadProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('wiki_import_success'.tr())));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('wiki_import_failed'.tr(args: [e.toString()])),
          ),
        );
      }
    }
  }
}

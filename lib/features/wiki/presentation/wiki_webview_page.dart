import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disastron/app/locale_provider.dart';
import 'package:disastron/features/wiki/domain/wiki_source.dart';
import 'package:disastron/features/wiki/presentation/wiki_download_provider.dart';
import 'package:disastron/features/wiki/presentation/wiki_sources_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

@RoutePage()
class WikiWebviewPage extends ConsumerStatefulWidget {
  const WikiWebviewPage({required this.url, required this.title, super.key});
  final String url;
  final String title;

  @override
  ConsumerState<WikiWebviewPage> createState() => _WikiWebviewPageState();
}

class _WikiWebviewPageState extends ConsumerState<WikiWebviewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  bool _isViewingOnline = false;
  String _activeUrl = '';
  String _lastKnownCategory = 'Imported';

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.url;

    final sources = ref.read(wikiSourcesProvider).value ?? [];
    final matching = sources.firstWhere(
      (s) => s.url.split('#').first == widget.url.split('#').first,
      orElse: () =>
          const WikiSource(url: '', title: '', category: '', locale: ''),
    );
    if (matching.url.isNotEmpty) {
      _lastKnownCategory = matching.category;
    }

    _controller = WebViewController()
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
      )
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _loading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Webview Resource Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            final docDir = await getApplicationDocumentsDirectory();
            final sandboxPath = docDir.path;
            final sources = ref.read(wikiSourcesProvider).value ?? [];

            final targetSource = _findSourceForUrl(url, sources, sandboxPath);
            if (targetSource != null) {
              _lastKnownCategory = targetSource.category;
            }

            if (url.startsWith('file://')) {
              final docDir = await getApplicationDocumentsDirectory();
              final uri = Uri.tryParse(url);
              if (uri != null) {
                final normalizedPath = uri.path;
                final sandboxPath = docDir.path;
                if (normalizedPath.startsWith(sandboxPath)) {
                  return NavigationDecision.navigate;
                }

                // Relative/protocol-relative URL resolved to file:// by the WebView.
                // We convert it back to an online HTTP/HTTPS URL.
                String reconstructedUrl = '';
                if (uri.host.isNotEmpty) {
                  reconstructedUrl =
                      'https://${uri.host}${uri.path}${uri.query.isNotEmpty ? '?${uri.query}' : ''}';
                } else {
                  final activeUri = Uri.tryParse(_activeUrl);
                  if (activeUri != null) {
                    final baseScheme = activeUri.scheme.isNotEmpty
                        ? activeUri.scheme
                        : 'https';
                    final baseHost = activeUri.host;
                    reconstructedUrl =
                        '$baseScheme://$baseHost${uri.path}${uri.query.isNotEmpty ? '?${uri.query}' : ''}';
                  } else {
                    reconstructedUrl = 'https://en.m.wikipedia.org${uri.path}';
                  }
                }

                final isOnline = await _checkIfOnline();
                if (isOnline) {
                  setState(() {
                    _isViewingOnline = true;
                    _activeUrl = reconstructedUrl;
                  });
                  await _controller.loadRequest(Uri.parse(reconstructedUrl));
                } else {
                  if (mounted) {
                    _showOfflineAlert();
                  }
                }
                return NavigationDecision.prevent;
              }
              return NavigationDecision.prevent;
            }

            final cleanedUrl = url.split('#').first;

            final matchingSource = sources.firstWhere(
              (s) => s.url.split('#').first == cleanedUrl,
              orElse: () => const WikiSource(
                url: '',
                title: '',
                category: '',
                locale: '',
              ),
            );

            if (matchingSource.url.isNotEmpty) {
              final docDir = await getApplicationDocumentsDirectory();
              final urlHash = matchingSource.url.hashCode
                  .toUnsigned(32)
                  .toRadixString(16);
              final localFile = File(
                '${docDir.path}/wiki_offline_downloads/$urlHash/index.html',
              );

              if (localFile.existsSync()) {
                setState(() {
                  _isViewingOnline = false;
                  _activeUrl = matchingSource.url;
                });
                await _controller.loadFile(localFile.path);
                return NavigationDecision.prevent;
              }
            }

            final isOnline = await _checkIfOnline();
            if (isOnline) {
              setState(() {
                _isViewingOnline = true;
                _activeUrl = url;
              });
              return NavigationDecision.navigate;
            } else {
              if (mounted) {
                _showOfflineAlert();
              }
              return NavigationDecision.prevent;
            }
          },
        ),
      );
    _loadOfflineHtml();
  }

  Future<bool> _checkIfOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showOfflineAlert() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('wiki_offline_alert_title'.tr()),
        content: Text('wiki_offline_alert_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _loadOfflineHtml() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final urlHash = widget.url.hashCode.toUnsigned(32).toRadixString(16);
      final localPath =
          '${docDir.path}/wiki_offline_downloads/$urlHash/index.html';
      final file = File(localPath);

      if (file.existsSync()) {
        await _controller.loadFile(file.path);
      } else {
        if (mounted) {
          setState(() {
            _error =
                'Offline content not found. Please download this page when online.';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load offline content: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _importCurrentPage() async {
    try {
      final String pageTitle =
          await _controller.getTitle() ?? 'Imported Wiki Page';
      final String pageUrl = _activeUrl;

      final titleController = TextEditingController(text: pageTitle);
      final categoryController = TextEditingController(
        text: _lastKnownCategory,
      );
      final formKey = GlobalKey<FormState>();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('wiki_import_dialog_title'.tr()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('wiki_import_dialog_message'.tr()),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'wiki_title_label'.tr(),
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
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: 'wiki_category_label'.tr(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'wiki_field_required'.tr();
                    }
                    return null;
                  },
                ),
              ],
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
                  final localeState = ref.read(appLocaleProvider).value;
                  final currentLocale = localeState?.localeCode ?? 'en';

                  final newSource = WikiSource(
                    url: pageUrl,
                    title: titleController.text.trim(),
                    category: categoryController.text.trim(),
                    locale: currentLocale,
                  );

                  await ref
                      .read(wikiSourcesProvider.notifier)
                      .addSource(newSource);

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }

                  if (mounted) {
                    setState(() {
                      _lastKnownCategory = newSource.category;
                    });
                  }

                  unawaited(
                    ref
                        .read(wikiDownloadProvider.notifier)
                        .downloadPage(newSource),
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('wiki_import_success_snack'.tr())),
                    );
                  }
                }
              },
              child: Text('wiki_save'.tr()),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('wiki_import_failed'.tr(args: [e.toString()])),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(wikiDownloadProvider).value ?? {};
    final dlState = downloads[_activeUrl];

    ref.listen<AsyncValue<Map<String, WikiDownloadState>>>(
      wikiDownloadProvider,
      (previous, next) async {
        final prevStatus = previous?.value?[_activeUrl]?.status;
        final nextState = next.value?[_activeUrl];
        final nextStatus = nextState?.status;

        if (_isViewingOnline &&
            prevStatus != WikiDownloadStatus.downloaded &&
            nextStatus == WikiDownloadStatus.downloaded) {
          final docDir = await getApplicationDocumentsDirectory();
          final urlHash = _activeUrl.hashCode.toUnsigned(32).toRadixString(16);
          final localFile = File(
            '${docDir.path}/wiki_offline_downloads/$urlHash/index.html',
          );

          if (localFile.existsSync() && mounted) {
            setState(() {
              _isViewingOnline = false;
            });
            await _controller.loadFile(localFile.path);
          }
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isViewingOnline ? 'wiki_online_banner_title'.tr() : widget.title,
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          if (_isViewingOnline) _buildOnlineBanner(context, dlState),
          Expanded(
            child: Stack(
              children: [
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  WebViewWidget(controller: _controller),
                if (_loading && _error == null)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineBanner(BuildContext context, WikiDownloadState? dlState) {
    final status = dlState?.status ?? WikiDownloadStatus.notDownloaded;

    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            status == WikiDownloadStatus.downloading
                ? Icons.downloading_rounded
                : Icons.language,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status == WikiDownloadStatus.downloading
                  ? 'wiki_downloading_progress'.tr(
                      args: [
                        ((dlState?.progress ?? 0.0) * 100).toStringAsFixed(0),
                      ],
                    )
                  : 'wiki_online_banner_title'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (status == WikiDownloadStatus.downloading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: dlState?.progress,
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: _importCurrentPage,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text('wiki_online_banner_import'.tr()),
            ),
        ],
      ),
    );
  }

  WikiSource? _findSourceForUrl(
    String url,
    List<WikiSource> sources,
    String sandboxPath,
  ) {
    final cleanedUrl = url.split('#').first;

    if (cleanedUrl.startsWith('file://')) {
      final uri = Uri.tryParse(cleanedUrl);
      if (uri != null) {
        final path = uri.path;
        if (path.startsWith(sandboxPath)) {
          final regExp = RegExp('wiki_offline_downloads/([^/]+)/index.html');
          final match = regExp.firstMatch(path);
          if (match != null) {
            final hash = match.group(1);
            for (final s in sources) {
              final sHash = s.url.hashCode.toUnsigned(32).toRadixString(16);
              if (sHash == hash) {
                return s;
              }
            }
          }
        } else {
          String reconstructedUrl = '';
          if (uri.host.isNotEmpty) {
            reconstructedUrl =
                'https://${uri.host}${uri.path}${uri.query.isNotEmpty ? '?${uri.query}' : ''}';
          } else {
            final activeUri = Uri.tryParse(_activeUrl);
            if (activeUri != null) {
              final baseScheme = activeUri.scheme.isNotEmpty
                  ? activeUri.scheme
                  : 'https';
              final baseHost = activeUri.host;
              reconstructedUrl =
                  '$baseScheme://$baseHost${uri.path}${uri.query.isNotEmpty ? '?${uri.query}' : ''}';
            } else {
              reconstructedUrl = 'https://en.m.wikipedia.org${uri.path}';
            }
          }
          final cleanedReconstructed = reconstructedUrl.split('#').first;
          final match = sources.firstWhere(
            (s) => s.url.split('#').first == cleanedReconstructed,
            orElse: () =>
                const WikiSource(url: '', title: '', category: '', locale: ''),
          );
          return match.url.isNotEmpty ? match : null;
        }
      }
      return null;
    }

    final match = sources.firstWhere(
      (s) => s.url.split('#').first == cleanedUrl,
      orElse: () =>
          const WikiSource(url: '', title: '', category: '', locale: ''),
    );
    return match.url.isNotEmpty ? match : null;
  }
}

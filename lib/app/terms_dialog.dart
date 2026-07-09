import 'dart:async';

import 'package:disastron/app/locale_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showTermsDialog(
  BuildContext context,
  WidgetRef? ref, {
  bool onlyView = false,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: onlyView,
    builder: (BuildContext ctx) {
      return _TermsDialogContent(
        ref: ref,
        onlyView: onlyView,
        onDismiss: () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        },
      );
    },
  );
}

class _TermsDialogContent extends StatefulWidget {
  const _TermsDialogContent({
    required this.ref,
    required this.onlyView,
    required this.onDismiss,
  });

  final WidgetRef? ref;
  final bool onlyView;
  final VoidCallback onDismiss;

  @override
  State<_TermsDialogContent> createState() => _TermsDialogContentState();
}

class _TermsDialogContentState extends State<_TermsDialogContent> {
  late final ScrollController _scrollController;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('terms_title'.tr()),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!widget.onlyView) ...<Widget>[
                Text(
                  'terms_message'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _sectionHeader(context, 'terms_section_1_title'.tr()),
                        const SizedBox(height: 4),
                        Text(
                          'terms_section_1_body'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        _sectionHeader(context, 'terms_section_2_title'.tr()),
                        const SizedBox(height: 4),
                        Text(
                          'terms_section_2_body'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        _sectionHeader(context, 'terms_section_3_title'.tr()),
                        const SizedBox(height: 4),
                        Text(
                          'terms_section_3_body'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        _sectionHeader(context, 'terms_section_4_title'.tr()),
                        const SizedBox(height: 4),
                        Text(
                          'terms_section_4_body'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final Uri uri = Uri.parse('https://disastron.com/terms');
                  unawaited(
                    launchUrl(uri, mode: LaunchMode.externalApplication),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'terms_view_link'.tr(),
                          style: TextStyle(
                            color: colorScheme.primary,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!widget.onlyView) ...<Widget>[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _accepted,
                  onChanged: (bool? v) {
                    setState(() => _accepted = v ?? false);
                  },
                  title: Text(
                    'terms_checkbox'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (widget.onlyView)
          TextButton(onPressed: widget.onDismiss, child: Text('close'.tr()))
        else ...<Widget>[
          TextButton(
            onPressed: () async {
              await SystemNavigator.pop();
            },
            child: Text('terms_decline'.tr()),
          ),
          FilledButton(
            onPressed: _accepted
                ? () async {
                    if (widget.ref != null) {
                      await widget.ref!
                          .read(appLocaleProvider.notifier)
                          .acceptTerms();
                    }
                    widget.onDismiss();
                  }
                : null,
            child: Text('terms_accept'.tr()),
          ),
        ],
      ],
    );
  }
}

Widget _sectionHeader(BuildContext context, String title) {
  return Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
  );
}

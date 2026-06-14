import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time notice for browser / installed PWA users about limited features.
Future<void> showWebPwaNoticeDialogIfNeeded(BuildContext context) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(PrefsKeys.webPwaNoticeShown) ?? false) {
    return;
  }
  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text('web_pwa_notice_title'.tr()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'web_pwa_notice_message'.tr(),
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _NoticeBullet(text: 'web_pwa_notice_gps'.tr()),
              _NoticeBullet(text: 'web_pwa_notice_audio'.tr()),
              _NoticeBullet(text: 'web_pwa_notice_battery'.tr()),
              _NoticeBullet(text: 'web_pwa_notice_hardware'.tr()),
            ],
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('web_pwa_notice_ok'.tr()),
          ),
        ],
      );
    },
  );

  await prefs.setBool(PrefsKeys.webPwaNoticeShown, true);
}

class _NoticeBullet extends StatelessWidget {
  const _NoticeBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '• ',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/inference/presentation/widgets/model_setup_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ModelConfigPage extends StatelessWidget {
  const ModelConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('model_config_title'.tr())),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: ModelSetupWidget(showAppearance: false, wrapInScrollView: false),
      ),
    );
  }
}

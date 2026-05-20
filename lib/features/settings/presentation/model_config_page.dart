import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/dashboard/presentation/widgets/model_setup_widget.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ModelConfigPage extends StatelessWidget {
  const ModelConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline model'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: ModelSetupWidget(
          showAppearance: false,
          wrapInScrollView: false,
        ),
      ),
    );
  }
}

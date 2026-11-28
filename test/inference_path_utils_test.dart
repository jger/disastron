import 'dart:io';

import 'package:disastron/features/inference/data/lora_registry_store.dart';
import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:disastron/features/inference/domain/inference_path_utils.dart';
import 'package:disastron/features/inference/presentation/model_install_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TempPathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _TempPathProvider(this._docsPath);

  final String _docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _docsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('safeFilenameFromStored', () {
    test('accepts normal model and LoRA URLs and paths', () {
      expect(
        safeFilenameFromStored(
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
        ),
        'gemma-4-E2B-it.litertlm',
      );
      expect(
        safeFilenameFromStored(
          'https://example.com/adapters/medical_lora_v1.bin?download=true#top',
        ),
        'medical_lora_v1.bin',
      );
      expect(
        safeFilenameFromStored('/storage/emulated/0/Download/my_adapter.bin'),
        'my_adapter.bin',
      );
    });

    test('rejects percent-encoded path traversal (CWE-22)', () {
      const List<String> malicious = <String>[
        'https://evil.example/a/%2E%2E%2Fshared_prefs%2FFlutterSharedPreferences.xml',
        'https://evil.example/%2e%2e%2fsecret.xml',
        'https://evil.example/%2E%2E%5Csecret.xml',
        'https://evil.example/%2Fetc%2Fpasswd',
        'https://evil.example/%2e%2e',
        'https://evil.example/%2e',
        'https://evil.example/foo%00bar.bin',
        'https://evil.example/C%3Aevil.bin',
        'https://evil.example/trailing-slash/',
        'https://evil.example',
        '',
        '..',
        '.',
      ];
      for (final String url in malicious) {
        expect(
          () => safeFilenameFromStored(url),
          throwsFormatException,
          reason: 'Expected $url to be rejected',
        );
      }
    });
  });

  group('resolveConfinedFilePath', () {
    test('returns direct child inside base directory', () {
      final String resolved = resolveConfinedFilePath(
        '/app/documents',
        'https://example.com/models/adapter.bin',
      );
      expect(resolved, p.normalize(p.absolute('/app/documents/adapter.bin')));
    });

    test('throws on traversal URL and tryResolveConfinedFilePath returns null', () {
      const String attackUrl =
          'https://evil.example/a/%2E%2E%2Fshared_prefs%2FFlutterSharedPreferences.xml';
      expect(
        () => resolveConfinedFilePath('/app/documents', attackUrl),
        throwsFormatException,
      );
      expect(tryResolveConfinedFilePath('/app/documents', attackUrl), isNull);
    });
  });

  group('ModelInstallOrchestrator LoRA path confinement', () {
    late Directory sandboxRoot;
    late Directory docsDir;
    late Directory sharedPrefsDir;
    late File victimFile;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      sandboxRoot = await Directory.systemTemp.createTemp('disastron_cwe22_');
      docsDir = await Directory(p.join(sandboxRoot.path, 'app_flutter'))
          .create();
      sharedPrefsDir = await Directory(p.join(sandboxRoot.path, 'shared_prefs'))
          .create();
      victimFile = File(
        p.join(sharedPrefsDir.path, 'FlutterSharedPreferences.xml'),
      );
      await victimFile.writeAsString('<map/>');
      PathProviderPlatform.instance = _TempPathProvider(docsDir.path);
    });

    tearDown(() async {
      if (sandboxRoot.existsSync()) {
        await sandboxRoot.delete(recursive: true);
      }
    });

    test('installLoraFromNetwork rejects traversal URL before download', () async {
      final ModelInstallOrchestrator orchestrator = ModelInstallOrchestrator(
        registry: ModelRegistryStore(),
      );
      const String attackUrl =
          'https://evil.example/a/%2E%2E%2Fshared_prefs%2FFlutterSharedPreferences.xml';

      await expectLater(
        orchestrator.installLoraFromNetwork(attackUrl, 'preset:test'),
        throwsFormatException,
      );
      expect(await victimFile.readAsString(), '<map/>');
    });

    test('removeLoraEntry refuses to delete files outside documents dir', () async {
      const String attackUrl =
          'https://evil.example/a/%2E%2E%2Fshared_prefs%2FFlutterSharedPreferences.xml';
      final LoraRegistryStore loraStore = LoraRegistryStore();
      await loraStore.writeSnapshot(
        const LoraRegistrySnapshot(
          entries: <InstalledLoraEntry>[
            InstalledLoraEntry(
              id: 'lora:malicious',
              modelEntryId: 'preset:test',
              sourceUrlOrPath: attackUrl,
              displayLabel: 'evil',
            ),
          ],
          activeLoraIdPerModel: <String, String>{
            'preset:test': 'lora:malicious',
          },
        ),
      );

      final ModelInstallOrchestrator orchestrator = ModelInstallOrchestrator(
        registry: ModelRegistryStore(),
      );
      await orchestrator.removeLoraEntry('lora:malicious');

      // Victim file outside documents dir must remain untouched.
      expect(victimFile.existsSync(), isTrue);
      // Malicious registry entry is still cleaned up.
      final LoraRegistrySnapshot after = await loraStore.readSnapshot();
      expect(after.entries, isEmpty);
      expect(after.activeLoraIdPerModel, isEmpty);
    });
  });
}

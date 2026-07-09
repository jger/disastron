# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Disastron is an offline-first Flutter emergency-readiness app: bundled offline wiki, emergency numbers by country, SOS tools (torch/alarm/vibration), and on-device LLM chat via `flutter_gemma` (models downloaded at runtime, never committed). Targets Android, iOS, and web (PWA/WASM). Flutter **3.44.5** (`.fvmrc`, FVM recommended), Dart `>=3.11.0`.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # required after clone and after Riverpod/AutoRoute annotation changes
flutter run

flutter test                                   # all tests
flutter test test/wiki_yaml_parsing_test.dart  # single test file
flutter test --plain-name "substring"          # single test by name

dart format .                                  # CI enforces with --set-exit-if-changed
dart analyze --fatal-infos --fatal-warnings .  # CI treats infos/warnings as errors

make pre-release-checks    # full CI gate: pub get, format check, build_runner, analyze, test
python3 tool/validate_wiki.py   # validate wiki packs after touching assets/wiki/
```

All `*.g.dart` / `*.gr.dart` files are gitignored — build_runner must run before analyze/test will pass on a fresh checkout.

## Releases and commits

Use **Conventional Commits** (`feat:`, `fix:`, `chore:`, …). semantic-release runs on `main` and bumps `pubspec.yaml` / `CHANGELOG.md` automatically (release commits carry `[skip ci]`). Never commit model weight files (`.task`, `.litertlm`, `.bin`), `key.properties`, or keystores.

## Architecture

Feature-first with Riverpod (see `.cursor/rules/feature-first-riverpod.mdc` for the full convention). Each feature under `lib/features/<name>/` splits into `data/` (stores, services, loaders), `domain/` (entities, states, domain errors), and `presentation/` (pages, widgets, providers); simpler features have only `presentation/`.

- `lib/main.dart` — wraps the app in `EasyLocalization` → `ProviderScope` → `LocaleEasyBridge`; awaits `AppBootstrap.initializeGemma()` and predefined-model loading before `runApp`.
- `lib/core/bootstrap/app_bootstrap.dart` — startup initialization (Gemma plugin, predefined inference models from `assets/data/inference_models.yaml`, start-locale resolution).
- `lib/app/` — app-level cross-cutting state: appearance/theme modes (including high-contrast variants, `appearance_provider.dart`), locale provider bridged to easy_localization, terms-acceptance and initial-language dialogs.
- `lib/router/routes.dart` — auto_route table; `routes.gr.dart` is generated.
- `lib/features/inference/` — the most involved feature: model registry store, predefined model presets, download/resume via `background_downloader`, Hugging Face token store, LoRA registry, install-domain errors. Chat (`lib/features/chat/`) consumes the active model through `flutter_gemma`.
- `lib/features/wiki/` — bundled markdown articles per locale in `assets/wiki/<locale>/` with `manifest.yaml`, plus a downloader service for extra packs.
- `lib/core/` — shared plumbing: bundled asset IO, preference keys (`prefs_keys.dart`), theme/spacing, snackbar feedback.

State management uses Riverpod codegen (`@riverpod` annotations + `riverpod_generator`); `riverpod_lint` and `custom_lint` are active.

## Localization

Two separate systems, both keyed by the same 7 locales (en, de, fr, es, el, zh, ar):
- UI strings: `assets/translations/<locale>.json`, accessed with `.tr()` (easy_localization). Add new keys to **all** locale files.
- Wiki content: `assets/wiki/<locale>/` markdown + `svg/*.json` label files; validate with `tool/validate_wiki.py`.

## Style notes

- `analysis_options.yaml` enables strict-casts/inference/raw-types and a large explicit lint set: package imports only (`always_use_package_imports`), single quotes, trailing commas required, `avoid_print`, sorted constructors first.
- Dart library files carry `// SPDX-License-Identifier: MIT` + copyright headers — keep them on new files.
- Platform-conditional code: web has quirks (no `Platform.environment`, OPFS model storage, locale restore) — guard with `kIsWeb` blocks; see `dev.md` for accumulated iOS/web build gotchas.

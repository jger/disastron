# Contributing to Disastron

Thank you for helping improve Disastron. Pull requests are welcome.

## Before you start

- Read [README.md](README.md) for project scope and disclaimers.
- Read [CONTENT_ATTRIBUTION.md](CONTENT_ATTRIBUTION.md) when changing wiki or medical content.
- Report security issues per [SECURITY.md](SECURITY.md) — not as public exploit write-ups in issues.

## Tech stack

Flutter, Riverpod, Auto Route, `flutter_edge_ai` (LiteRT-LM on-device inference), `image_picker` (chat attachments on supported multimodal models), bundled assets (offline wiki, emergency numbers, climate normals), and local permissions for location / camera / photos / audio / vibration as required by the platform.

## Development setup

Requirements:

- Flutter **3.47.5** (see [`.fvmrc`](.fvmrc); [FVM](https://fvm.app/) recommended)
- Dart SDK `>=3.13.0 <4.0.0`

```bash
cd disastron   # your clone of this repository
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Run the same checks as CI:

```bash
make pre-release-checks
```

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`, …). Releases on `main` are automated via semantic-release.

## Code generation

After changing Riverpod or Auto Route annotations:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated `*.g.dart` files are not tracked; CI regenerates them. `lib/router/routes.gr.dart` is tracked — keep it in sync when routes change.

## Wiki and translations

- UI strings: `assets/translations/<locale>.json` via `easy_localization` (`.tr()`).
- Wiki articles: `assets/wiki/<locale>/` with manifest in `assets/wiki/manifest.yaml`.
- Validate wiki packs: `python3 tool/validate_wiki.py`

When adding a locale, copy `assets/wiki/en/` and translate markdown plus `svg/*.json` label files.

## Patrol (on-device E2E testing)

[Patrol](https://patrol.leancode.co/) drives real on-device UI tests under `patrol_test/` — used where plain `flutter test` integration tests can't reach the device (e.g. native permission dialogs, or devices like MIUI where `adb shell input` is blocked). Requires `patrol_cli` 4.8.0+ with `patrol` 4.10 (`dart pub global activate patrol_cli 4.8.0`) and a connected/booted Android device or emulator.

```bash
make patrol-prepare   # one-time: cache + seed a model onto the device (see PRESET in Makefile)
make patrol-test      # run the default investigation test (TARGET/DEVICE overridable)
```

`patrol-test` pre-grants runtime permissions and runs with `--no-uninstall` so app data (including the multi-GB seeded model) survives between runs. If the Gradle-based orchestrator can't install on your device, fall back to `make patrol-test-manual` (`tool/patrol/run_no_orchestrator.sh`, plain `adb install` + `am instrument`).

**Patrol MCP** (`.mcp.json`, `patrol_mcp` package) exposes Patrol to MCP-capable AI agents (e.g. Claude Code) as tools to launch/restart a test run, take screenshots, and inspect the native UI tree — useful for driving and debugging on-device test sessions interactively rather than only via `make patrol-test`.

## Model training (LoRA)

Dataset pipeline, n8n synthesis workflows, and Gemma 4 E2B LoRA training live in a separate **`disastron-training`** repository (not bundled here). The app wiki (`assets/wiki/`) is the source of truth for bundled content; training artifacts are versioned there. LoRA adapters are not bundled in the mobile app by default (LiteRT-LM vs PyTorch). **Do not** commit downloaded `.task`, `.litertlm`, or `.bin` weight blobs to git.

## Pull requests

1. Fork and branch from `main`.
2. Keep changes focused; match existing architecture under `lib/features/`.
3. Run `make pre-release-checks` before opening the PR.
4. Describe user-visible changes and link issues when applicable.

CI runs on every pull request (format, analyze, test).

## Releases & signing (maintainers)

Versions and GitHub Releases are driven by **[semantic-release](https://github.com/semantic-release/semantic-release)** at the repo root ([`package.json`](package.json), [`release.config.js`](release.config.js), [`.github/workflows/release.yml`](.github/workflows/release.yml)). On pushes to `main`, the workflow:

1. Runs formatting, codegen, analysis, and unit tests.
2. Restores the Android upload keystore from GitHub Secrets.
3. Bumps `pubspec.yaml` and `CHANGELOG.md` (`scripts/increment_build.sh`).
4. Builds the signed release APK and SHA-256 checksum (`scripts/build_apk.sh`).
5. Commits version changes with `[skip ci]` and publishes `dist/disastron-<version>.apk` + `.sha256` to GitHub Releases.

**Required repository secrets for CI releases:**
- `GH_TOKEN` — personal access token (or fine-grained token) with `contents: write`.
- `ANDROID_KEYSTORE_BASE64` — base64-encoded upload keystore (`base64 -i upload-keystore.jks`).
- `ANDROID_STORE_PASSWORD` — `storePassword` from `android/key.properties`.
- `ANDROID_KEY_ALIAS` — `keyAlias` from `android/key.properties`.
- `ANDROID_KEY_PASSWORD` — `keyPassword` from `android/key.properties`.

Public clones without `android/key.properties` automatically fall back to **debug signing** for local release testing:
- Never commit `key.properties`, `*.jks`, or keystore passwords.
- F-Droid metadata lives under [`metadata/`](metadata/). See [`metadata/en-US/full_description.txt`](metadata/en-US/full_description.txt) for listing copy.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).

# Disastron

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Offline-first Flutter app for **emergency readiness and calm decision support** when networks fail or you need answers without leaving the device.

## About the name

**Disastron** is formed from Ancient Greek **δις** (*dis*, here “twice” or “doubly”) and **ἄστρον** (*astron*, “star”) — **δις ἄστρον**, evoking a **bad omen in the stars** or an **ill‑starred** moment. English **disaster** comes from the same picture by another route: Italian *disastro* from Latin *dis-* + *astrum* (“star”), i.e. fate turning against you under unfavorable stars. The app name compresses that old sense of cosmic misalignment into one word.

## Why this exists

The goal is to offer the **strongest help we can build—without artificial limits**—to anyone who needs it. **Human life is not a market segment**; access to solid guidance in a crisis should not be gated by subscriptions or vendor lock-in.

**Open source:** application source code and bundled assets in this repository are released under the [MIT License](LICENSE). Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Important notices

- **Not medical advice** — Wiki articles (including CPR reminders) and on-device chat output are for **education and convenience only**. They are **not** a substitute for certified training, professional care, or calling emergency services when someone is hurt or unwell.
- **Emergency numbers** — The bundled list is maintained in good faith; **verify numbers** for your region and situation. Official guidance from local authorities always takes precedence.
- **SOS, alarm, torch, vibration** — Use these features **only where lawful and safe**; they can distract others or cause distress if misused.
- **On-device AI** — Local models can **hallucinate or be wrong**. Do not rely on them for life-critical decisions; use judgment and human help.

## Privacy

The app is **offline-first** by design. Things that can leave the device when you choose to use them include: **optional downloads** of inference model files from Hugging Face (and any URL you paste), and **location / coarse place** when you grant OS permissions (used for context such as emergency numbers and dashboard text).

## Security

See [`SECURITY.md`](SECURITY.md) for how to report issues and a short checklist for secret scanning before releases.

## Features

- **Dashboard** — Device snapshot (battery, rough place from GPS/geocoding), expandable **day/night** and **local conditions** (sun times, typical temperatures from bundled climate data). Pull-to-refresh.
- **Call help** — **Offline** emergency-number list **by detected country** (bundled JSON), with context from location where permissions allow.
- **CPR & planning** — Quick entry to **bundled offline wiki** articles (e.g. CPR essentials, home kit / trip prep). Not a substitute for professional services or training.
- **SOS signal** — Screen/torch **Morse SOS**, optional **alarm tone**, **vibration**, and **Bluetooth** awareness (user-toggled); use only where lawful and safe.
- **Wiki tab** — Full list of offline reference articles (markdown).
- **Todos** — Simple on-device checklist support (including chat-driven actions where implemented).
- **Chat** — **On-device** LLM inference (Gemma family via `flutter_gemma`); models downloaded to storage. With a **multimodal** model active, you can attach **one photo per message** from the gallery or camera; text-only models keep the attach control disabled with an in-app hint. Optional **Hugging Face token** only for authorized model downloads—**no app login**, no cloud chat backend in the default design.
- **Settings** — **Theme & appearance** (multiple modes, including dark high contrast for visibility and battery messaging), **offline model** install (presets, URL, file from device).

Core principle: **work offline** so maps, towers, and accounts are not single points of failure when things go wrong.

## Model training (LoRA)

Dataset pipeline, n8n synthesis workflows, and Gemma 4 E2B LoRA training live in a separate **`disastron-training`** repository (not bundled here). The app wiki (`assets/wiki/`) is the source of truth for bundled content; training artifacts are versioned there. LoRA adapters are not bundled in the mobile app by default (LiteRT-LM vs PyTorch).

## Development

Requirements: Flutter **3.44.5** ([`.fvmrc`](.fvmrc)), Dart `>=3.11.0`.

```bash
cd disastron   # your clone of this repository
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for PR workflow, wiki validation, and maintainer release signing. Content licensing for wiki articles: [CONTENT_ATTRIBUTION.md](CONTENT_ATTRIBUTION.md).

## Patrol (on-device E2E)

[Patrol](https://patrol.leancode.co/) drives real on-device UI tests under `patrol_test/` — used where plain `flutter test` integration tests can't reach the device (e.g. native permission dialogs, or devices like MIUI where `adb shell input` is blocked). Requires `patrol_cli >= 4` (`dart pub global activate patrol_cli`) and a connected/booted Android device or emulator.

```bash
make patrol-prepare   # one-time: cache + seed a model onto the device (see PRESET in Makefile)
make patrol-test       # run the default investigation test (TARGET/DEVICE overridable)
```

`patrol-test` pre-grants runtime permissions and runs with `--no-uninstall` so app data (including the multi-GB seeded model) survives between runs. If the Gradle-based orchestrator can't install on your device, fall back to `make patrol-test-manual` (`tool/patrol/run_no_orchestrator.sh`, plain `adb install` + `am instrument`). See [`docs/patrol-chat-stop-investigation.md`](docs/patrol-chat-stop-investigation.md) for the full workflow and background.

**Patrol MCP** (`.mcp.json`, `patrol_mcp` package) exposes Patrol to MCP-capable AI agents (e.g. Claude Code) as tools to launch/restart a test run, take screenshots, and inspect the native UI tree — useful for driving and debugging on-device test sessions interactively rather than only via `make patrol-test`.

## Tech (short)

Flutter, Riverpod, Auto Route, `flutter_gemma`, `image_picker` (chat attachments on supported models), bundled assets (wiki, emergency numbers, climate normals), local permissions for location / camera / photos / audio / vibration as required by the platform.

## Releases (semantic-release)

Versions and GitHub Releases are driven by **[semantic-release](https://github.com/semantic-release/semantic-release)** at the repo root (`package.json`, `release.config.js`). Use **[Conventional Commits](https://www.conventionalcommits.org/)** (`feat:`, `fix:`, `chore:`, …) on `main` so releases and changelog entries are generated correctly. The release workflow bumps **`pubspec.yaml`**, updates **`CHANGELOG.md`**, and commits with **`[skip ci]`** on the release commit.

**CI setup:** add a repository secret `GH_TOKEN` — a personal access token (or fine-grained token) with `contents: write` so the workflow can push release commits and create GitHub Releases (same as the Triliza release workflow).

**Local checks** (same Flutter steps as CI, without publishing):

```bash
make pre-release-checks
```

## Third-party software

Dart and Flutter dependencies ship under their own licenses. Full gathered texts are in [`third_party_licenses.txt`](third_party_licenses.txt); [`third_party_licenses.json`](third_party_licenses.json) records how that file was produced. See [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) and [`NOTICE`](NOTICE).

## Downloaded models (separate from repo license)

Preset and custom installs fetch **model weight files** (for example Gemma checkpoints) from Hugging Face or URLs you supply. Those files are **not** licensed under the MIT terms of this repository. You must comply with each model’s terms (for gated Gemma checkpoints, see [Google Gemma terms](https://ai.google.dev/gemma/terms) and the model card on Hugging Face). **Do not** commit downloaded `.task` / `.litertlm` / other weight blobs to git.

## Trademarks

**Gemma** and **Hugging Face** are trademarks of their respective owners. This project is an independent app; it is not endorsed by Google or Hugging Face.

## License

Copyright (c) 2024-2026 Jannis Gerardis.

Source code and bundled assets in this repository are licensed under the **MIT License** — see [`LICENSE`](LICENSE). SPDX identifier: `MIT` (also noted in `// SPDX-License-Identifier: MIT` headers in Dart library files).

# Contributing to Disastron

Thank you for helping improve Disastron. Pull requests are welcome.

## Before you start

- Read [README.md](README.md) for project scope and disclaimers.
- Read [CONTENT_ATTRIBUTION.md](CONTENT_ATTRIBUTION.md) when changing wiki or medical content.
- Report security issues per [SECURITY.md](SECURITY.md) — not as public exploit write-ups in issues.

## Development setup

Requirements:

- Flutter **3.44.5** (see [`.fvmrc`](.fvmrc); [FVM](https://fvm.app/) recommended)
- Dart SDK `>=3.11.0 <4.0.0`

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

## Pull requests

1. Fork and branch from `main`.
2. Keep changes focused; match existing architecture under `lib/features/`.
3. Run `make pre-release-checks` before opening the PR.
4. Describe user-visible changes and link issues when applicable.

CI runs on every pull request (format, analyze, test).

## Maintainer releases (Play Store / F-Droid)

Public clones build with **debug signing** for local release testing. Store builds are signed by maintainers only:

- Never commit `key.properties`, `*.jks`, or keystore passwords.
- Configure release signing locally or in a private CI environment with secrets.
- Do not bundle model weight files (`.task`, `.litertlm`, `.bin`) in the repo or store APK/AAB — users download models at runtime.

F-Droid metadata lives under [`metadata/`](metadata/). See [`metadata/en-US/full_description.txt`](metadata/en-US/full_description.txt) for listing copy.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).

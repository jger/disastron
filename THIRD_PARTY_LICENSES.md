# Third-party licenses

Disastron builds on many open-source Dart and Flutter packages. Full license texts and notices as gathered from each package’s pub cache entry are in:

- [`third_party_licenses.txt`](third_party_licenses.txt) — aggregated disclaimer (all dependencies, including dev tools used in this repo).

Metadata for tooling:

- [`third_party_licenses.json`](third_party_licenses.json) — points at the text file and records how it was generated.

## Regenerating

From the repository root (after `dart pub get`):

```bash
dart run license_checker check-licenses -c license_checker.yaml
dart run license_checker generate-disclaimer -y -c license_checker.yaml -f third_party_licenses.txt
```

Configuration for permitted SPDX identifiers and Flutter SDK packages without a separate `LICENSE` file in the pub cache is in [`license_checker.yaml`](license_checker.yaml).

## Flutter SDK

Packages such as `flutter`, `flutter_test`, and `sky_engine` are part of the Flutter SDK; their terms apply in addition to the dependency list above. See the Flutter SDK license terms shipped with your Flutter installation.

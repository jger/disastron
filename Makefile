# Mirrors Dart/Flutter steps from .github/workflows/release.yml (without Node/semantic-release).

.PHONY: pre-release-checks
pre-release-checks:
	flutter pub get
	dart format --output=none --set-exit-if-changed .
	dart run build_runner build --delete-conflicting-outputs
	dart analyze --fatal-infos --fatal-warnings .
	flutter test

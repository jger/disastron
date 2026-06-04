# Mirrors Dart/Flutter steps from .github/workflows/release.yml (without Node/semantic-release).

.DEFAULT_GOAL := help

.PHONY: help pre-release-checks
help: ## List available targets
	@grep -E '^[a-zA-Z0-9_.-]+:.*?##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

pre-release-checks: ## pub get, format, build_runner, analyze, test (release gate)
	flutter pub get
	dart format --output=none --set-exit-if-changed .
	dart run build_runner build --delete-conflicting-outputs
	dart analyze --fatal-infos --fatal-warnings .
	flutter test

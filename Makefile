# Mirrors Dart/Flutter steps from .github/workflows/release.yml (without Node/semantic-release).

.DEFAULT_GOAL := help

.PHONY: help pre-release-checks patrol-prepare patrol-test patrol-test-manual
help: ## List available targets
	@grep -E '^[a-zA-Z0-9_.-]+:.*?##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

pre-release-checks: ## pub get, format, build_runner, analyze, test (release gate)
	flutter pub get
	dart format --output=none --set-exit-if-changed .
	dart run build_runner build --delete-conflicting-outputs
	dart analyze --fatal-infos --fatal-warnings .
	flutter test

# --- Patrol E2E (docs/patrol-chat-stop-investigation.md) -----------------
# PRESET: gemma4_e2b_litertlm (default) | gemma4_e4b_litertlm | gemma3_270m_q8 | <url>
PRESET ?= gemma4_e2b_litertlm

patrol-prepare: ## One-time: cache the model locally + seed it into the app on the adb device
	bash tool/patrol/prepare_model.sh $(PRESET)

# TARGET: test file to run; DEVICE: adb serial (optional, for multiple devices)
TARGET ?= patrol_test/chat_stop_regression_test.dart

patrol-test: ## Run the chat stop/continue investigation on the connected device
	@v=$$(patrol --version 2>/dev/null | grep -oE '[0-9]+' | head -1); \
	if [ -z "$$v" ] || [ "$$v" -lt 4 ]; then \
		echo "error: patrol_cli >= 4 required for patrol 4.x (found: $$(patrol --version 2>/dev/null || echo 'not installed'))."; \
		echo "fix:   dart pub global activate patrol_cli"; \
		exit 1; \
	fi
	@# Pre-grant runtime permissions so no native dialog blocks chat init.
	@# Needs a unique adb target: pass DEVICE=<serial> when several are attached.
	@ADB="adb $(if $(DEVICE),-s $(DEVICE),)"; \
	for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION POST_NOTIFICATIONS; do \
		$$ADB shell pm grant dev.zardoz.disastron android.permission.$$p 2>/dev/null || true; \
	done
	@# --no-uninstall is ESSENTIAL: patrol's default uninstalls the app
	@# before AND after the run, wiping app data incl. the 2.4GB model+seed.
	patrol test --no-uninstall --target $(TARGET) $(if $(DEVICE),--device $(DEVICE),)

patrol-test-manual: ## Fallback runner: plain adb install + am instrument (MIUI blocks gradle's -g install)
	bash tool/patrol/run_no_orchestrator.sh

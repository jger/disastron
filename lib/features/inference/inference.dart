// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

/// Public API for on-device model install, registry, and settings UI.
library;

export 'data/model_registry_store.dart';
export 'domain/predefined_models.dart';
export 'presentation/active_inference_model_summary.dart';
export 'presentation/huggingface_token_provider.dart';
export 'presentation/inference_model_vision_support.dart';
export 'presentation/local_gemma_model_provider.dart';
export 'presentation/lora_provider.dart';
export 'presentation/model_install_flow_coordinator.dart';
export 'presentation/model_registry_provider.dart';
export 'presentation/pages/model_config_page.dart';
export 'presentation/widgets/interrupted_download_panel.dart';
export 'presentation/widgets/model_install_progress_panel.dart';
export 'presentation/widgets/model_setup_widget.dart';
export 'presentation/widgets/preset_download_metadata.dart';

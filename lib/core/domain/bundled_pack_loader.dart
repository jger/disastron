// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

/// Bundled JSON pack contract (swap in tests with a fake loader).
typedef BundledPackLoader<T> = Future<T> Function(String assetPath);

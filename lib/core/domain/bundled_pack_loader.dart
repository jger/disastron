/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

/// Bundled JSON pack contract (swap in tests with a fake loader).
typedef BundledPackLoader<T> = Future<T> Function(String assetPath);

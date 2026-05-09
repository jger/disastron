/// Fine-grained surface phase while the local model is installing.
enum ModelInstallSurfacePhase {
  /// Bytes not yet reported (token dialog, metered confirm, or native prep).
  preparing,

  /// Install/download progress 1–100.
  transferring,
}

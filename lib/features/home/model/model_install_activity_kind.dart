/// What the user started; combined with [LocalGemmaModelUi.progress] for status copy.
enum ModelInstallActivityKind {
  downloadNetwork,
  importLocalFile,
  restoreSaved,
  activateExisting,

  /// Preflight only or legacy state.
  unknown,
}

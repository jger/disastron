/// Typed install/switch errors for consistent UI (maps raw plugin exceptions once).
enum ModelInstallDomainErrorKind {
  auth,
  network,
  storage,
  compatibility,
  unknown,
}

class ModelInstallDomainError {
  const ModelInstallDomainError({
    required this.kind,
    required this.message,
    this.isGated403 = false,
    this.gatedModelPageUrl,
  });

  final ModelInstallDomainErrorKind kind;
  final String message;
  final bool isGated403;
  final String? gatedModelPageUrl;
}

String? hfModelPageFromDownloadUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }
  if (!uri.host.toLowerCase().contains('huggingface.co')) {
    return null;
  }
  final List<String> segs = uri.pathSegments;
  if (segs.length < 2) {
    return null;
  }
  return 'https://huggingface.co/${segs[0]}/${segs[1]}';
}

ModelInstallDomainError mapModelInstallException(
  Object error, {
  String? downloadUrl,
}) {
  final String msg = error.toString();
  final String lower = msg.toLowerCase();
  final bool is403 = msg.contains('403') ||
      lower.contains('forbidden') ||
      lower.contains('401');
  final String? page = is403 && downloadUrl != null
      ? hfModelPageFromDownloadUrl(downloadUrl)
      : null;

  if (is403) {
    return ModelInstallDomainError(
      kind: ModelInstallDomainErrorKind.auth,
      message: msg,
      isGated403: true,
      gatedModelPageUrl: page,
    );
  }
  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('timed out') ||
      lower.contains('host lookup')) {
    return ModelInstallDomainError(
      kind: ModelInstallDomainErrorKind.network,
      message: msg,
    );
  }
  if (lower.contains('enospc') ||
      lower.contains('no space left') ||
      lower.contains('not enough space') ||
      lower.contains('disk full') ||
      lower.contains('storage full') ||
      lower.contains('sqlite_full')) {
    return ModelInstallDomainError(
      kind: ModelInstallDomainErrorKind.storage,
      message: msg,
    );
  }
  if (lower.contains('not compatible') ||
      lower.contains('unsupported') ||
      lower.contains('invalid model')) {
    return ModelInstallDomainError(
      kind: ModelInstallDomainErrorKind.compatibility,
      message: msg,
    );
  }
  return ModelInstallDomainError(
    kind: ModelInstallDomainErrorKind.unknown,
    message: msg,
  );
}

import 'dart:developer' as developer;
import 'dart:io' show File;

import 'package:background_downloader/background_downloader.dart';
import 'package:disastron/features/inference/data/pending_model_download_store.dart';
import 'package:disastron/features/inference/presentation/model_install_orchestrator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of checking whether a pending download can be resumed.
class ResumableDownloadSnapshot {
  const ResumableDownloadSnapshot({
    required this.resumable,
    this.partialBytes,
    this.taskId,
  });

  final bool resumable;
  final int? partialBytes;
  final String? taskId;
}

/// Mirrors flutter_gemma SmartDownloader task paths and IDs for resume/discard.
class ModelDownloadResumeService {
  const ModelDownloadResumeService();

  static Future<void> prepareOnStartup() async {
    if (kIsWeb) {
      return;
    }
    try {
      await FileDownloader().resumeFromBackground();
      developer.log(
        'background_downloader resumeFromBackground completed',
        name: 'ModelDownloadResumeService',
      );
    } on Object catch (e, st) {
      developer.log(
        'resumeFromBackground failed: $e',
        name: 'ModelDownloadResumeService',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Same deterministic id as flutter_gemma SmartDownloader.
  static String taskIdFor(String url, String targetPath) {
    return '${url.hashCode.toUnsigned(32).toRadixString(16)}_'
        '${targetPath.hashCode.toUnsigned(32).toRadixString(16)}';
  }

  static Future<String> targetPathForUrl(String url) async {
    final String dir = (await getApplicationDocumentsDirectory()).path;
    return p.join(dir, basenameFromStored(url));
  }

  /// Cancels a zombie WorkManager task without deleting partial bytes on disk.
  Future<void> cancelStaleTask(String url) async {
    if (kIsWeb) {
      return;
    }
    final String targetPath = await targetPathForUrl(url);
    final String taskId = taskIdFor(url, targetPath);
    try {
      await FileDownloader().cancelTaskWithId(taskId);
      developer.log(
        'Cancelled stale download task: $taskId',
        name: 'ModelDownloadResumeService',
      );
    } on Object catch (e) {
      developer.log(
        'cancelStaleTask failed: $e',
        name: 'ModelDownloadResumeService',
      );
    }
  }

  Future<ResumableDownloadSnapshot> detectResumable(
    PendingModelDownload pending,
  ) async {
    if (kIsWeb) {
      return const ResumableDownloadSnapshot(resumable: false);
    }

    final String targetPath = await targetPathForUrl(pending.url);
    final String taskId = taskIdFor(pending.url, targetPath);
    final File file = File(targetPath);
    final bool fileExists = file.existsSync();
    int partialBytes = 0;
    if (fileExists) {
      partialBytes = await file.length();
    }

    final bool installed =
        await FlutterGemma.isModelInstalled(pending.filename);
    if (installed) {
      developer.log(
        'detectResumable: model already installed (${pending.filename})',
        name: 'ModelDownloadResumeService',
      );
      return ResumableDownloadSnapshot(
        resumable: false,
        partialBytes: partialBytes > 0 ? partialBytes : null,
        taskId: taskId,
      );
    }

    Task? task;
    try {
      task = await FileDownloader().taskForId(taskId);
    } on Object catch (e) {
      developer.log(
        'taskForId failed: $e',
        name: 'ModelDownloadResumeService',
      );
    }

    final bool hasPartialFile = fileExists && partialBytes > 0;
    final bool hasActiveTask = task != null;

    developer.log(
      'detectResumable url=${pending.url} taskId=$taskId '
      'partialBytes=$partialBytes hasTask=$hasActiveTask',
      name: 'ModelDownloadResumeService',
    );

    return ResumableDownloadSnapshot(
      resumable: hasPartialFile || hasActiveTask,
      partialBytes: hasPartialFile ? partialBytes : null,
      taskId: taskId,
    );
  }

  Future<void> discardPending(PendingModelDownload pending) async {
    if (kIsWeb) {
      return;
    }

    final String targetPath = await targetPathForUrl(pending.url);
    final String taskId = taskIdFor(pending.url, targetPath);

    try {
      await FileDownloader().cancelTaskWithId(taskId);
    } on Object catch (e) {
      developer.log(
        'cancelTaskWithId failed: $e',
        name: 'ModelDownloadResumeService',
      );
    }

    final File file = File(targetPath);
    if (file.existsSync()) {
      try {
        await file.delete();
        developer.log(
          'Deleted partial file: $targetPath',
          name: 'ModelDownloadResumeService',
        );
      } on Object catch (e) {
        developer.log(
          'delete partial failed: $e',
          name: 'ModelDownloadResumeService',
        );
      }
    }
  }
}

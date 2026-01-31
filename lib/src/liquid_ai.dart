import 'dart:async';

import 'models/download_event.dart';
import 'models/download_progress.dart';
import 'models/load_event.dart';
import 'models/model_runner.dart';
import 'models/model_status.dart';
import 'platform/liquid_ai_platform_interface.dart';

/// Main entry point for the Liquid AI SDK.
///
/// Provides methods for downloading, loading, and managing AI models.
class LiquidAi {
  /// Creates a new [LiquidAi] instance.
  ///
  /// Optionally accepts a [platform] for testing purposes.
  LiquidAi({LiquidAiPlatform? platform})
    : _platform = platform ?? LiquidAiPlatform.instance;

  final LiquidAiPlatform _platform;

  /// Returns the platform version string.
  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  /// Downloads a model without loading it.
  ///
  /// Returns a stream of [DownloadEvent] objects indicating progress.
  /// The stream will emit:
  /// - [DownloadStartedEvent] when download begins
  /// - [DownloadProgressEvent] during download with progress updates
  /// - [DownloadCompleteEvent] when download completes successfully
  /// - [DownloadErrorEvent] if an error occurs
  /// - [DownloadCancelledEvent] if the operation is cancelled
  Stream<DownloadEvent> downloadModel(String model, String quantization) {
    late StreamController<DownloadEvent> controller;
    StreamSubscription<Map<String, dynamic>>? subscription;
    String? operationId;
    var isClosed = false;

    void safeAdd(DownloadEvent event) {
      if (!isClosed) {
        controller.add(event);
      }
    }

    void safeClose() {
      if (!isClosed) {
        isClosed = true;
        controller.close();
      }
    }

    controller = StreamController<DownloadEvent>(
      onListen: () async {
        // Subscribe to the event stream BEFORE calling downloadModel
        // to ensure we don't miss any events
        subscription = _platform.progressEvents.listen((event) {
          // Filter events by operationId once we have it
          if (operationId != null && event['operationId'] == operationId) {
            final eventData = _parseProgressEvent(event, operationId!);
            if (eventData != null) {
              safeAdd(eventData);
              if (eventData is DownloadCompleteEvent ||
                  eventData is DownloadErrorEvent ||
                  eventData is DownloadCancelledEvent) {
                safeClose();
              }
            }
          }
        });

        // Now start the download
        operationId = await _platform.downloadModel(model, quantization);
      },
      onCancel: () {
        isClosed = true;
        subscription?.cancel();
        if (operationId != null) {
          _platform.cancelOperation(operationId!);
        }
      },
    );

    return controller.stream;
  }

  /// Downloads (if needed) and loads a model.
  ///
  /// Returns a stream of [LoadEvent] objects indicating progress.
  /// The stream will emit:
  /// - [LoadStartedEvent] when operation begins
  /// - [LoadProgressEvent] during download/load with progress updates
  /// - [LoadCompleteEvent] when model is loaded, containing a [ModelRunner]
  /// - [LoadErrorEvent] if an error occurs
  /// - [LoadCancelledEvent] if the operation is cancelled
  Stream<LoadEvent> loadModel(String model, String quantization) {
    late StreamController<LoadEvent> controller;
    StreamSubscription<Map<String, dynamic>>? subscription;
    String? operationId;
    var isClosed = false;

    void safeAdd(LoadEvent event) {
      if (!isClosed) {
        controller.add(event);
      }
    }

    void safeClose() {
      if (!isClosed) {
        isClosed = true;
        controller.close();
      }
    }

    controller = StreamController<LoadEvent>(
      onListen: () async {
        // Subscribe to the event stream BEFORE calling loadModel
        // to ensure we don't miss any events
        subscription = _platform.progressEvents.listen((event) {
          // Filter events by operationId once we have it
          if (operationId != null && event['operationId'] == operationId) {
            final eventData = _parseLoadEvent(
              event,
              operationId!,
              model,
              quantization,
            );
            if (eventData != null) {
              safeAdd(eventData);
              if (eventData is LoadCompleteEvent ||
                  eventData is LoadErrorEvent ||
                  eventData is LoadCancelledEvent) {
                safeClose();
              }
            }
          }
        });

        // Now start the load
        operationId = await _platform.loadModel(model, quantization);
      },
      onCancel: () {
        isClosed = true;
        subscription?.cancel();
        if (operationId != null) {
          _platform.cancelOperation(operationId!);
        }
      },
    );

    return controller.stream;
  }

  /// Checks if a model is already downloaded locally.
  Future<bool> isModelDownloaded(String model, String quantization) {
    return _platform.isModelDownloaded(model, quantization);
  }

  /// Gets the current status of a model.
  Future<ModelStatus> getModelStatus(String model, String quantization) {
    return _platform.getModelStatus(model, quantization);
  }

  /// Deletes a downloaded model from local storage.
  Future<void> deleteModel(String model, String quantization) {
    return _platform.deleteModel(model, quantization);
  }

  /// Cancels an ongoing operation.
  Future<void> cancelOperation(String operationId) {
    return _platform.cancelOperation(operationId);
  }

  DownloadEvent? _parseProgressEvent(
    Map<String, dynamic> event,
    String operationId,
  ) {
    final status = event['status'] as String?;
    switch (status) {
      case 'started':
        return DownloadStartedEvent(operationId: operationId);
      case 'progress':
        return DownloadProgressEvent(
          operationId: operationId,
          progress: DownloadProgress(
            operationId: operationId,
            progress: (event['progress'] as num).toDouble(),
            speed: event['speed'] as int?,
          ),
        );
      case 'completed':
        return DownloadCompleteEvent(operationId: operationId);
      case 'error':
        return DownloadErrorEvent(
          operationId: operationId,
          error: event['error'] as String? ?? 'Unknown error',
        );
      case 'cancelled':
        return DownloadCancelledEvent(operationId: operationId);
      default:
        return null;
    }
  }

  LoadEvent? _parseLoadEvent(
    Map<String, dynamic> event,
    String operationId,
    String model,
    String quantization,
  ) {
    final status = event['status'] as String?;
    switch (status) {
      case 'started':
        return LoadStartedEvent(operationId: operationId);
      case 'progress':
        return LoadProgressEvent(
          operationId: operationId,
          progress: DownloadProgress(
            operationId: operationId,
            progress: (event['progress'] as num).toDouble(),
            speed: event['speed'] as int?,
          ),
        );
      case 'completed':
        final runnerId = event['runnerId'] as String?;
        if (runnerId == null) {
          return LoadErrorEvent(
            operationId: operationId,
            error: 'No runner ID returned',
          );
        }
        return LoadCompleteEvent(
          operationId: operationId,
          runner: ModelRunner(
            runnerId: runnerId,
            model: model,
            quantization: quantization,
          ),
        );
      case 'error':
        return LoadErrorEvent(
          operationId: operationId,
          error: event['error'] as String? ?? 'Unknown error',
        );
      case 'cancelled':
        return LoadCancelledEvent(operationId: operationId);
      default:
        return null;
    }
  }
}

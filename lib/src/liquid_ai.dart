import 'dart:async';

import 'models/download_event.dart';
import 'models/download_progress.dart';
import 'models/load_event.dart';
import 'models/load_options.dart';
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
        // Cancel the subscription BEFORE closing the controller
        // to avoid race conditions with the event channel
        subscription?.cancel();
        subscription = null;
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
        if (!isClosed) {
          isClosed = true;
          subscription?.cancel();
          subscription = null;
          if (operationId != null) {
            _platform.cancelOperation(operationId!);
          }
        }
      },
    );

    return controller.stream;
  }

  /// Downloads (if needed) and loads a model.
  ///
  /// The optional [options] parameter allows configuring inference engine
  /// settings like context size, batch size, and GPU acceleration.
  ///
  /// Returns a stream of [LoadEvent] objects indicating progress.
  /// The stream will emit:
  /// - [LoadStartedEvent] when operation begins
  /// - [LoadProgressEvent] during download/load with progress updates
  /// - [LoadCompleteEvent] when model is loaded, containing a [ModelRunner]
  /// - [LoadErrorEvent] if an error occurs
  /// - [LoadCancelledEvent] if the operation is cancelled
  ///
  /// Example:
  /// ```dart
  /// final options = LoadOptions(contextSize: 2048);
  /// await for (final event in liquidAi.loadModel(
  ///   'lfm2-1b',
  ///   'Q4_K_M',
  ///   options: options,
  /// )) {
  ///   switch (event) {
  ///     case LoadCompleteEvent(:final runner):
  ///       print('Model loaded: ${runner.model}');
  ///     case LoadProgressEvent(:final progress):
  ///       print('Progress: ${progress.progressPercent}%');
  ///     case LoadErrorEvent(:final error):
  ///       print('Error: $error');
  ///     default:
  ///       break;
  ///   }
  /// }
  /// ```
  Stream<LoadEvent> loadModel(
    String model,
    String quantization, {
    LoadOptions? options,
  }) {
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
        // Cancel the subscription BEFORE closing the controller
        // to avoid race conditions with the event channel
        subscription?.cancel();
        subscription = null;
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
        operationId = await _platform.loadModel(
          model,
          quantization,
          options: options,
        );
      },
      onCancel: () {
        if (!isClosed) {
          isClosed = true;
          subscription?.cancel();
          subscription = null;
          if (operationId != null) {
            _platform.cancelOperation(operationId!);
          }
        }
      },
    );

    return controller.stream;
  }

  /// Loads a model from a local file path.
  ///
  /// This is useful for loading models that are bundled with the app or
  /// have been downloaded to a custom location.
  ///
  /// The [path] must be an absolute path to a valid model file (e.g., .gguf).
  ///
  /// The optional [options] parameter allows configuring inference engine
  /// settings like context size, batch size, and GPU acceleration.
  ///
  /// Returns a stream of [LoadEvent] objects indicating progress.
  /// The stream will emit:
  /// - [LoadStartedEvent] when operation begins
  /// - [LoadProgressEvent] during load with progress updates
  /// - [LoadCompleteEvent] when model is loaded, containing a [ModelRunner]
  /// - [LoadErrorEvent] if an error occurs
  /// - [LoadCancelledEvent] if the operation is cancelled
  ///
  /// Example:
  /// ```dart
  /// // Load from app bundle (iOS)
  /// final bundlePath = '${Directory.current.path}/models/model.gguf';
  ///
  /// // Load from assets (after copying to documents directory)
  /// final docDir = await getApplicationDocumentsDirectory();
  /// final modelPath = '${docDir.path}/models/my-model.gguf';
  ///
  /// await for (final event in liquidAi.loadModelFromPath(modelPath)) {
  ///   switch (event) {
  ///     case LoadCompleteEvent(:final runner):
  ///       print('Model loaded!');
  ///     case LoadErrorEvent(:final error):
  ///       print('Error: $error');
  ///     default:
  ///       break;
  ///   }
  /// }
  /// ```
  Stream<LoadEvent> loadModelFromPath(String path, {LoadOptions? options}) {
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
        // Cancel the subscription BEFORE closing the controller
        // to avoid race conditions with the event channel
        subscription?.cancel();
        subscription = null;
        controller.close();
      }
    }

    controller = StreamController<LoadEvent>(
      onListen: () async {
        subscription = _platform.progressEvents.listen((event) {
          if (operationId != null && event['operationId'] == operationId) {
            final eventData = _parseLoadEventFromPath(
              event,
              operationId!,
              path,
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

        operationId = await _platform.loadModelFromPath(path, options: options);
      },
      onCancel: () {
        if (!isClosed) {
          isClosed = true;
          subscription?.cancel();
          subscription = null;
          if (operationId != null) {
            _platform.cancelOperation(operationId!);
          }
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
          errorCode: event['errorCode'] as String?,
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
          errorCode: event['errorCode'] as String?,
        );
      case 'cancelled':
        return LoadCancelledEvent(operationId: operationId);
      default:
        return null;
    }
  }

  LoadEvent? _parseLoadEventFromPath(
    Map<String, dynamic> event,
    String operationId,
    String path,
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
        // Extract model name from path (filename without extension)
        final fileName = path.split('/').last;
        final modelName = fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;
        return LoadCompleteEvent(
          operationId: operationId,
          runner: ModelRunner(
            runnerId: runnerId,
            model: modelName,
            quantization: 'local',
          ),
        );
      case 'error':
        return LoadErrorEvent(
          operationId: operationId,
          error: event['error'] as String? ?? 'Unknown error',
          errorCode: event['errorCode'] as String?,
        );
      case 'cancelled':
        return LoadCancelledEvent(operationId: operationId);
      default:
        return null;
    }
  }
}

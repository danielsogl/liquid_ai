import 'dart:async';

import 'models/download_event.dart';
import 'models/download_progress.dart';
import 'models/load_event.dart';
import 'models/load_options.dart';
import 'models/model_manifest.dart';
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

  /// Downloads a model from a direct URL.
  ///
  /// Supports any GGUF model, including those from Hugging Face.
  /// The model will be cached locally with the given [modelId].
  ///
  /// The [quantization] parameter is used for categorization and defaults
  /// to 'custom'.
  ///
  /// Returns a stream of [DownloadEvent] objects indicating progress.
  /// The stream will emit:
  /// - [DownloadStartedEvent] when download begins
  /// - [DownloadProgressEvent] during download with progress updates
  /// - [DownloadCompleteEvent] when download completes successfully
  /// - [DownloadErrorEvent] if an error occurs
  /// - [DownloadCancelledEvent] if the operation is cancelled
  ///
  /// Example:
  /// ```dart
  /// await for (final event in liquidAi.downloadModelFromUrl(
  ///   url: 'https://huggingface.co/model.gguf?download=true',
  ///   modelId: 'my-custom-model',
  /// )) {
  ///   switch (event) {
  ///     case DownloadProgressEvent(:final progress):
  ///       print('Progress: ${progress.progressPercent}%');
  ///     case DownloadCompleteEvent():
  ///       print('Download complete!');
  ///     case DownloadErrorEvent(:final error):
  ///       print('Error: $error');
  ///     default:
  ///       break;
  ///   }
  /// }
  /// ```
  Stream<DownloadEvent> downloadModelFromUrl({
    required String url,
    required String modelId,
    String quantization = 'custom',
  }) {
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
        subscription?.cancel();
        subscription = null;
        controller.close();
      }
    }

    controller = StreamController<DownloadEvent>(
      onListen: () async {
        subscription = _platform.progressEvents.listen((event) {
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

        operationId = await _platform.downloadModelFromUrl(
          url,
          modelId,
          quantization: quantization,
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

  /// Downloads a split vision model from multiple URLs.
  ///
  /// Some vision models require separate files for the language model
  /// and the multimodal projector. This method downloads all files
  /// and links them together.
  ///
  /// The first URL should be the main language model file.
  /// Additional URLs can be projector files or other components.
  ///
  /// The [quantization] parameter is used for categorization and defaults
  /// to 'custom'.
  ///
  /// Returns a stream of [DownloadEvent] objects indicating progress.
  /// The stream will emit:
  /// - [DownloadStartedEvent] when download begins
  /// - [DownloadProgressEvent] during download with progress updates
  /// - [DownloadCompleteEvent] when download completes successfully
  /// - [DownloadErrorEvent] if an error occurs
  /// - [DownloadCancelledEvent] if the operation is cancelled
  ///
  /// Example:
  /// ```dart
  /// await for (final event in liquidAi.downloadSplitModel(
  ///   urls: [
  ///     'https://huggingface.co/.../language.gguf?download=true',
  ///     'https://huggingface.co/.../mmproj.gguf?download=true',
  ///   ],
  ///   modelId: 'my-vision-model',
  /// )) {
  ///   switch (event) {
  ///     case DownloadProgressEvent(:final progress):
  ///       print('Progress: ${progress.progressPercent}%');
  ///     case DownloadCompleteEvent():
  ///       print('Download complete!');
  ///     case DownloadErrorEvent(:final error):
  ///       print('Error: $error');
  ///     default:
  ///       break;
  ///   }
  /// }
  /// ```
  Stream<DownloadEvent> downloadSplitModel({
    required List<String> urls,
    required String modelId,
    String quantization = 'custom',
  }) {
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
        subscription?.cancel();
        subscription = null;
        controller.close();
      }
    }

    controller = StreamController<DownloadEvent>(
      onListen: () async {
        subscription = _platform.progressEvents.listen((event) {
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

        operationId = await _platform.downloadSplitModel(
          urls,
          modelId,
          quantization: quantization,
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

  /// Lists all cached models.
  ///
  /// Returns a list of [ModelManifest] objects for all locally cached models.
  /// This is useful for showing users what models are available offline
  /// and managing storage usage.
  ///
  /// Example:
  /// ```dart
  /// final cachedModels = await liquidAi.getCachedModels();
  /// for (final manifest in cachedModels) {
  ///   print('${manifest.modelSlug} (${manifest.quantizationSlug})');
  /// }
  /// ```
  Future<List<ModelManifest>> getCachedModels() {
    return _platform.getCachedModels();
  }

  /// Checks if a model with the given [modelId] is cached.
  ///
  /// This is useful for checking models downloaded via [downloadModelFromUrl]
  /// or [downloadSplitModel] where a custom model ID was specified.
  ///
  /// For catalog models, use [isModelDownloaded] instead.
  ///
  /// Example:
  /// ```dart
  /// final isCached = await liquidAi.isModelCached('my-custom-model');
  /// if (isCached) {
  ///   print('Model is ready to use');
  /// } else {
  ///   print('Model needs to be downloaded');
  /// }
  /// ```
  Future<bool> isModelCached(String modelId) {
    return _platform.isModelCached(modelId);
  }

  /// Deletes all cached models.
  ///
  /// This removes all locally stored model files, freeing up storage space.
  /// Use with caution as models will need to be re-downloaded before use.
  ///
  /// Example:
  /// ```dart
  /// await liquidAi.deleteAllModels();
  /// print('All models deleted');
  /// ```
  Future<void> deleteAllModels() {
    return _platform.deleteAllModels();
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
        final manifestMap = event['manifest'] as Map<String, dynamic>?;
        final manifest = manifestMap != null
            ? ModelManifest.fromMap(manifestMap)
            : null;
        return LoadCompleteEvent(
          operationId: operationId,
          runner: ModelRunner(
            runnerId: runnerId,
            model: model,
            quantization: quantization,
            manifest: manifest,
          ),
          manifest: manifest,
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
        final manifestMap = event['manifest'] as Map<String, dynamic>?;
        final manifest = manifestMap != null
            ? ModelManifest.fromMap(manifestMap)
            : null;
        return LoadCompleteEvent(
          operationId: operationId,
          runner: ModelRunner.fromPath(
            runnerId: runnerId,
            path: path,
            manifest: manifest,
          ),
          manifest: manifest,
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

import 'dart:async';

import '../liquid_ai.dart';
import '../platform/liquid_ai_platform_interface.dart';
import 'load_event.dart';
import 'load_options.dart';
import 'model_runner.dart';

/// Manages model lifecycle ensuring only one model is loaded at a time.
///
/// This singleton prevents memory issues on native devices by automatically
/// unloading the previous model before loading a new one. Use this class
/// when switching between models to avoid having multiple models in memory
/// simultaneously.
///
/// Example:
/// ```dart
/// final manager = ModelManager.instance;
///
/// // Load a model (automatically unloads any previous model)
/// final runner = await manager.loadModel('model-slug', 'Q4_K_M');
///
/// // Switch to a different model (previous one is unloaded first)
/// final newRunner = await manager.loadModel('other-model', 'Q4_K_M');
///
/// // Explicitly unload when done
/// await manager.unloadCurrentModel();
/// ```
class ModelManager {
  ModelManager._({LiquidAi? liquidAi, LiquidAiPlatform? platform})
    : _liquidAi = liquidAi ?? LiquidAi(),
      _platform = platform ?? LiquidAiPlatform.instance;

  static ModelManager? _instance;

  /// The singleton instance of [ModelManager].
  ///
  /// Creates the instance on first access.
  static ModelManager get instance => _instance ??= ModelManager._();

  /// Resets the singleton instance.
  ///
  /// This is primarily useful for testing. After calling this, the next
  /// access to [instance] will create a fresh [ModelManager].
  static void resetInstance() {
    _instance = null;
  }

  /// Creates a [ModelManager] for testing with custom dependencies.
  ///
  /// This allows injecting mock [LiquidAi] and [LiquidAiPlatform] for testing.
  static void initializeForTesting({
    LiquidAi? liquidAi,
    LiquidAiPlatform? platform,
  }) {
    _instance = ModelManager._(liquidAi: liquidAi, platform: platform);
  }

  final LiquidAi _liquidAi;
  final LiquidAiPlatform _platform;

  /// The currently loaded model runner, if any.
  ModelRunner? _currentRunner;

  /// Whether a model is currently being loaded.
  bool _isLoading = false;

  /// The currently loaded model runner, or null if no model is loaded.
  ModelRunner? get currentRunner => _currentRunner;

  /// Whether a model is currently loaded.
  bool get hasLoadedModel => _currentRunner != null;

  /// Whether a model load operation is in progress.
  bool get isLoading => _isLoading;

  /// The model slug of the currently loaded model.
  ///
  /// Returns null if no model is loaded or if the model was loaded from path.
  String? get currentModelSlug => _currentRunner?.model;

  /// The quantization of the currently loaded model.
  ///
  /// Returns null if no model is loaded or if the model was loaded from path.
  String? get currentQuantization => _currentRunner?.quantization;

  /// The file path of the currently loaded model.
  ///
  /// Returns null if no model is loaded or if the model was loaded from
  /// catalog.
  String? get currentPath => _currentRunner?.path;

  /// Whether the currently loaded model was loaded from a local file path.
  bool get isCurrentModelPathLoaded => _currentRunner?.isPathLoaded ?? false;

  /// Syncs Dart state with native state.
  ///
  /// Call this after hot-reload or on app initialization to recover the
  /// currently loaded model state from the native layer. During hot-reload,
  /// Dart state is reset but native state persists, which can lead to
  /// memory leaks and inconsistent state.
  ///
  /// Example:
  /// ```dart
  /// // In your app initialization or after hot-reload
  /// await ModelManager.instance.syncWithNative();
  ///
  /// if (ModelManager.instance.hasLoadedModel) {
  ///   // Model was recovered from native state
  ///   final runner = ModelManager.instance.currentRunner!;
  /// }
  /// ```
  ///
  /// Returns true if a model was found and synced, false if no model was
  /// loaded on the native side.
  Future<bool> syncWithNative() async {
    if (_isLoading) {
      throw StateError('Cannot sync while a load operation is in progress.');
    }

    final loadedInfo = await _platform.getLoadedModelInfo();

    if (loadedInfo == null) {
      // No model loaded on native side, clear Dart state
      _currentRunner = null;
      return false;
    }

    // Reconstruct the ModelRunner from native state
    _currentRunner = ModelRunner.fromNativeInfo(
      loadedInfo,
      platform: _platform,
    );
    return true;
  }

  /// Loads a model, automatically unloading any previously loaded model first.
  ///
  /// This method ensures that only one model is in memory at a time by
  /// disposing of the current model before loading the new one. This prevents
  /// memory errors on devices with limited resources.
  ///
  /// The optional [options] parameter allows configuring inference engine
  /// settings like context size, batch size, and GPU acceleration.
  ///
  /// Returns a stream of [LoadEvent] objects indicating progress:
  /// - [LoadStartedEvent] when the operation begins
  /// - [LoadProgressEvent] during download/load with progress updates
  /// - [LoadCompleteEvent] when the model is loaded successfully
  /// - [LoadErrorEvent] if an error occurs
  /// - [LoadCancelledEvent] if the operation is cancelled
  ///
  /// If loading fails, no model will be loaded (the previous model is already
  /// unloaded at this point). Handle [LoadErrorEvent] appropriately.
  ///
  /// Throws [StateError] if a load operation is already in progress.
  Stream<LoadEvent> loadModel(
    String model,
    String quantization, {
    LoadOptions? options,
  }) {
    if (_isLoading) {
      throw StateError(
        'A model load operation is already in progress. '
        'Wait for it to complete before loading another model.',
      );
    }

    late StreamController<LoadEvent> controller;
    StreamSubscription<LoadEvent>? subscription;
    var isClosed = false;

    void safeAdd(LoadEvent event) {
      if (!isClosed) {
        controller.add(event);
      }
    }

    void safeClose() {
      if (!isClosed) {
        isClosed = true;
        _isLoading = false;
        controller.close();
      }
    }

    controller = StreamController<LoadEvent>(
      onListen: () async {
        _isLoading = true;

        // Unload the current model first to free memory
        try {
          await _unloadCurrentModelInternal();
        } catch (_) {
          // If unload fails, still try to load (best effort cleanup)
        }

        // Now load the new model
        subscription = _liquidAi
            .loadModel(model, quantization, options: options)
            .listen(
              (event) {
                safeAdd(event);

                if (event is LoadCompleteEvent) {
                  _currentRunner = event.runner;
                  safeClose();
                } else if (event is LoadErrorEvent ||
                    event is LoadCancelledEvent) {
                  // Ensure no runner is set on failure
                  _currentRunner = null;
                  safeClose();
                }
              },
              onError: (error) {
                _currentRunner = null;
                if (!isClosed) {
                  controller.addError(error);
                }
                safeClose();
              },
              onDone: safeClose,
            );
      },
      onCancel: () {
        isClosed = true;
        _isLoading = false;
        subscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// Loads a model and returns the [ModelRunner] when complete.
  ///
  /// This is a convenience method that wraps [loadModel] and returns the
  /// final [ModelRunner] or null if loading failed.
  ///
  /// The optional [options] parameter allows configuring inference engine
  /// settings like context size, batch size, and GPU acceleration.
  ///
  /// Returns null if:
  /// - The load operation was cancelled
  /// - An error occurred during loading
  ///
  /// If you need progress updates or detailed error information, use
  /// [loadModel] instead.
  Future<ModelRunner?> loadModelAsync(
    String model,
    String quantization, {
    LoadOptions? options,
  }) async {
    final completer = Completer<ModelRunner?>();
    StreamSubscription<LoadEvent>? subscription;

    subscription = loadModel(model, quantization, options: options).listen(
      (event) {
        if (event is LoadCompleteEvent) {
          if (!completer.isCompleted) {
            completer.complete(event.runner);
          }
          subscription?.cancel();
        } else if (event is LoadErrorEvent || event is LoadCancelledEvent) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          subscription?.cancel();
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        subscription?.cancel();
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    return completer.future;
  }

  /// Loads a model from a local file path, automatically unloading any
  /// previously loaded model first.
  ///
  /// This is useful for loading models bundled with the app or downloaded
  /// to a custom location.
  ///
  /// The [path] must be an absolute path to a valid model file (e.g., .gguf).
  ///
  /// The optional [options] parameter allows configuring inference engine
  /// settings like context size, batch size, and GPU acceleration.
  ///
  /// Returns a stream of [LoadEvent] objects indicating progress.
  ///
  /// Throws [StateError] if a load operation is already in progress.
  Stream<LoadEvent> loadModelFromPath(String path, {LoadOptions? options}) {
    if (_isLoading) {
      throw StateError(
        'A model load operation is already in progress. '
        'Wait for it to complete before loading another model.',
      );
    }

    late StreamController<LoadEvent> controller;
    StreamSubscription<LoadEvent>? subscription;
    var isClosed = false;

    void safeAdd(LoadEvent event) {
      if (!isClosed) {
        controller.add(event);
      }
    }

    void safeClose() {
      if (!isClosed) {
        isClosed = true;
        _isLoading = false;
        controller.close();
      }
    }

    controller = StreamController<LoadEvent>(
      onListen: () async {
        _isLoading = true;

        // Unload the current model first to free memory
        try {
          await _unloadCurrentModelInternal();
        } catch (_) {
          // If unload fails, still try to load (best effort cleanup)
        }

        // Now load the new model from path
        subscription = _liquidAi
            .loadModelFromPath(path, options: options)
            .listen(
              (event) {
                safeAdd(event);

                if (event is LoadCompleteEvent) {
                  _currentRunner = event.runner;
                  safeClose();
                } else if (event is LoadErrorEvent ||
                    event is LoadCancelledEvent) {
                  _currentRunner = null;
                  safeClose();
                }
              },
              onError: (error) {
                _currentRunner = null;
                if (!isClosed) {
                  controller.addError(error);
                }
                safeClose();
              },
              onDone: safeClose,
            );
      },
      onCancel: () {
        isClosed = true;
        _isLoading = false;
        subscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// Loads a model from a local file path and returns the [ModelRunner].
  ///
  /// This is a convenience method that wraps [loadModelFromPath] and returns
  /// the final [ModelRunner] or null if loading failed.
  Future<ModelRunner?> loadModelFromPathAsync(
    String path, {
    LoadOptions? options,
  }) async {
    final completer = Completer<ModelRunner?>();
    StreamSubscription<LoadEvent>? subscription;

    subscription = loadModelFromPath(path, options: options).listen(
      (event) {
        if (event is LoadCompleteEvent) {
          if (!completer.isCompleted) {
            completer.complete(event.runner);
          }
          subscription?.cancel();
        } else if (event is LoadErrorEvent || event is LoadCancelledEvent) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          subscription?.cancel();
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        subscription?.cancel();
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    return completer.future;
  }

  /// Unloads the currently loaded model, freeing its memory.
  ///
  /// This is safe to call even if no model is loaded. After calling this,
  /// [currentRunner] will be null and [hasLoadedModel] will be false.
  ///
  /// Throws [StateError] if a load operation is in progress.
  Future<void> unloadCurrentModel() async {
    if (_isLoading) {
      throw StateError('Cannot unload while a load operation is in progress.');
    }
    await _unloadCurrentModelInternal();
  }

  /// Force unloads all models and clears all native state.
  ///
  /// Use this when the native state might be inconsistent or when recovering
  /// from errors. This is a destructive operation that will unload any loaded
  /// model and clear all caches.
  ///
  /// After calling this, [currentRunner] will be null and [hasLoadedModel]
  /// will be false.
  ///
  /// Throws [StateError] if a load operation is in progress.
  Future<void> forceUnloadAll() async {
    if (_isLoading) {
      throw StateError(
        'Cannot force unload while a load operation is in progress.',
      );
    }
    _currentRunner = null;
    await _platform.forceUnloadAll();
  }

  /// Internal method to unload the current model.
  ///
  /// Unlike [unloadCurrentModel], this does not check [_isLoading] and is
  /// used internally during the load process.
  Future<void> _unloadCurrentModelInternal() async {
    final runner = _currentRunner;
    _currentRunner = null;

    if (runner != null && !runner.isDisposed) {
      await runner.dispose();
    }
  }

  /// Checks if a specific catalog model is currently loaded.
  ///
  /// Returns true if a model is loaded and matches both the [model] slug
  /// and [quantization]. Returns false for path-loaded models.
  bool isModelLoaded(String model, String quantization) {
    return _currentRunner?.model == model &&
        _currentRunner?.quantization == quantization;
  }

  /// Checks if a model from a specific path is currently loaded.
  ///
  /// Returns true if a model is loaded from the given [path].
  bool isPathLoaded(String path) {
    return _currentRunner?.path == path;
  }
}

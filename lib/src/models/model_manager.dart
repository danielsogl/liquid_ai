import 'dart:async';

import '../liquid_ai.dart';
import 'load_event.dart';
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
  ModelManager._({LiquidAi? liquidAi}) : _liquidAi = liquidAi ?? LiquidAi();

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

  /// Creates a [ModelManager] for testing with a custom [LiquidAi] instance.
  ///
  /// This allows injecting a mock [LiquidAi] for unit testing.
  static void initializeForTesting(LiquidAi liquidAi) {
    _instance = ModelManager._(liquidAi: liquidAi);
  }

  final LiquidAi _liquidAi;

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

  /// The model slug of the currently loaded model, or null if none.
  String? get currentModelSlug => _currentRunner?.model;

  /// The quantization of the currently loaded model, or null if none.
  String? get currentQuantization => _currentRunner?.quantization;

  /// Loads a model, automatically unloading any previously loaded model first.
  ///
  /// This method ensures that only one model is in memory at a time by
  /// disposing of the current model before loading the new one. This prevents
  /// memory errors on devices with limited resources.
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
  Stream<LoadEvent> loadModel(String model, String quantization) {
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
        await _unloadCurrentModelInternal();

        // Now load the new model
        subscription = _liquidAi
            .loadModel(model, quantization)
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
  /// Returns null if:
  /// - The load operation was cancelled
  /// - An error occurred during loading
  ///
  /// If you need progress updates or detailed error information, use
  /// [loadModel] instead.
  Future<ModelRunner?> loadModelAsync(String model, String quantization) async {
    final completer = Completer<ModelRunner?>();
    StreamSubscription<LoadEvent>? subscription;

    subscription = loadModel(model, quantization).listen(
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

  /// Checks if a specific model is currently loaded.
  ///
  /// Returns true if a model is loaded and matches both the [model] slug
  /// and [quantization].
  bool isModelLoaded(String model, String quantization) {
    return _currentRunner?.model == model &&
        _currentRunner?.quantization == quantization;
  }
}

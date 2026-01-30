import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:liquid_ai/liquid_ai.dart';

/// Status of a single model's download.
enum ModelDownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  error,
}

/// State for a single model.
class ModelState {
  const ModelState({
    required this.status,
    this.progress = 0.0,
    this.speed = 0,
    this.operationId,
    this.errorMessage,
    this.downloadedQuantization,
  });

  final ModelDownloadStatus status;
  final double progress;
  final int speed;
  final String? operationId;
  final String? errorMessage;

  /// The quantization that is currently downloaded (null if not downloaded).
  final QuantizationInfo? downloadedQuantization;

  ModelState copyWith({
    ModelDownloadStatus? status,
    double? progress,
    int? speed,
    String? operationId,
    String? errorMessage,
    QuantizationInfo? downloadedQuantization,
    bool clearQuantization = false,
  }) {
    return ModelState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      operationId: operationId ?? this.operationId,
      errorMessage: errorMessage ?? this.errorMessage,
      downloadedQuantization: clearQuantization
          ? null
          : (downloadedQuantization ?? this.downloadedQuantization),
    );
  }
}

/// Manages download state for all models.
class DownloadState extends ChangeNotifier {
  DownloadState({LiquidAi? liquidAi}) : _liquidAi = liquidAi ?? LiquidAi();

  final LiquidAi _liquidAi;
  final Map<String, ModelState> _modelStates = {};
  final Map<String, StreamSubscription<DownloadEvent>> _subscriptions = {};

  bool _isDownloadingAll = false;

  /// The list of available models.
  List<LeapModel> get models => ModelCatalog.available;

  /// Whether a "download all" operation is in progress.
  bool get isDownloadingAll => _isDownloadingAll;

  /// Whether any download is currently in progress.
  bool get isAnyDownloading {
    return _modelStates.values.any(
      (state) => state.status == ModelDownloadStatus.downloading,
    );
  }

  /// Gets the state for a specific model.
  ModelState getModelState(String modelSlug) {
    return _modelStates[modelSlug] ??
        const ModelState(status: ModelDownloadStatus.notDownloaded);
  }

  /// Initializes state by checking which models are already downloaded.
  Future<void> initialize() async {
    for (final model in models) {
      // Check each quantization to find which one is downloaded
      QuantizationInfo? downloadedQuant;
      for (final quant in model.quantizations) {
        final isDownloaded = await _liquidAi.isModelDownloaded(
          model.slug,
          quant.slug,
        );
        if (isDownloaded) {
          downloadedQuant = quant;
          break;
        }
      }

      _modelStates[model.slug] = ModelState(
        status: downloadedQuant != null
            ? ModelDownloadStatus.downloaded
            : ModelDownloadStatus.notDownloaded,
        downloadedQuantization: downloadedQuant,
      );
    }
    notifyListeners();
  }

  /// Downloads a single model with its default quantization.
  Future<void> downloadModel(LeapModel model) async {
    await downloadModelWithQuantization(model, model.defaultQuantization);
  }

  /// Downloads a single model with a specific quantization.
  Future<void> downloadModelWithQuantization(
    LeapModel model,
    QuantizationInfo quantization,
  ) async {
    if (_modelStates[model.slug]?.status == ModelDownloadStatus.downloading) {
      return;
    }

    _modelStates[model.slug] = ModelState(
      status: ModelDownloadStatus.downloading,
      downloadedQuantization:
          _modelStates[model.slug]?.downloadedQuantization,
    );
    notifyListeners();

    final stream = _liquidAi.downloadModel(model.slug, quantization.slug);

    _subscriptions[model.slug]?.cancel();
    _subscriptions[model.slug] = stream.listen(
      (event) => _handleDownloadEvent(model.slug, event, quantization),
      onError: (error) {
        _modelStates[model.slug] = ModelState(
          status: ModelDownloadStatus.error,
          errorMessage: error.toString(),
          downloadedQuantization:
              _modelStates[model.slug]?.downloadedQuantization,
        );
        notifyListeners();
      },
    );
  }

  /// Switches to a different quantization.
  ///
  /// This will delete the currently downloaded quantization and download
  /// the new one.
  Future<void> switchQuantization(
    LeapModel model,
    QuantizationInfo newQuantization,
  ) async {
    final currentState = _modelStates[model.slug];
    final currentQuant = currentState?.downloadedQuantization;

    // Delete the current quantization if exists
    if (currentQuant != null) {
      await _liquidAi.deleteModel(model.slug, currentQuant.slug);
    }

    // Download the new quantization
    await downloadModelWithQuantization(model, newQuantization);
  }

  /// Downloads all models that aren't already downloaded.
  Future<void> downloadAllModels() async {
    if (_isDownloadingAll) return;

    _isDownloadingAll = true;
    notifyListeners();

    for (final model in models) {
      final state = _modelStates[model.slug];
      if (state?.status != ModelDownloadStatus.downloaded) {
        await _downloadModelAndWait(model);
      }
    }

    _isDownloadingAll = false;
    notifyListeners();
  }

  Future<void> _downloadModelAndWait(LeapModel model) async {
    final completer = Completer<void>();
    final quantization = model.defaultQuantization;

    _modelStates[model.slug] = ModelState(
      status: ModelDownloadStatus.downloading,
      downloadedQuantization:
          _modelStates[model.slug]?.downloadedQuantization,
    );
    notifyListeners();

    final stream = _liquidAi.downloadModel(model.slug, quantization.slug);

    _subscriptions[model.slug]?.cancel();
    _subscriptions[model.slug] = stream.listen(
      (event) {
        _handleDownloadEvent(model.slug, event, quantization);
        if (event is DownloadCompleteEvent ||
            event is DownloadErrorEvent ||
            event is DownloadCancelledEvent) {
          if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (error) {
        _modelStates[model.slug] = ModelState(
          status: ModelDownloadStatus.error,
          errorMessage: error.toString(),
          downloadedQuantization:
              _modelStates[model.slug]?.downloadedQuantization,
        );
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
  }

  void _handleDownloadEvent(
    String modelSlug,
    DownloadEvent event,
    QuantizationInfo quantization,
  ) {
    final currentQuant = _modelStates[modelSlug]?.downloadedQuantization;

    switch (event) {
      case DownloadStartedEvent():
        _modelStates[modelSlug] = ModelState(
          status: ModelDownloadStatus.downloading,
          operationId: event.operationId,
          downloadedQuantization: currentQuant,
        );
      case DownloadProgressEvent():
        _modelStates[modelSlug] = ModelState(
          status: ModelDownloadStatus.downloading,
          progress: event.progress.progress,
          speed: event.progress.speed ?? 0,
          operationId: event.operationId,
          downloadedQuantization: currentQuant,
        );
      case DownloadCompleteEvent():
        _modelStates[modelSlug] = ModelState(
          status: ModelDownloadStatus.downloaded,
          progress: 1.0,
          downloadedQuantization: quantization,
        );
        _subscriptions[modelSlug]?.cancel();
        _subscriptions.remove(modelSlug);
      case DownloadErrorEvent():
        _modelStates[modelSlug] = ModelState(
          status: ModelDownloadStatus.error,
          errorMessage: event.error,
          downloadedQuantization: currentQuant,
        );
        _subscriptions[modelSlug]?.cancel();
        _subscriptions.remove(modelSlug);
      case DownloadCancelledEvent():
        _modelStates[modelSlug] = ModelState(
          status: currentQuant != null
              ? ModelDownloadStatus.downloaded
              : ModelDownloadStatus.notDownloaded,
          downloadedQuantization: currentQuant,
        );
        _subscriptions[modelSlug]?.cancel();
        _subscriptions.remove(modelSlug);
    }
    notifyListeners();
  }

  /// Cancels an ongoing download.
  Future<void> cancelDownload(LeapModel model) async {
    final state = _modelStates[model.slug];
    if (state?.operationId != null) {
      await _liquidAi.cancelOperation(state!.operationId!);
    }
    _subscriptions[model.slug]?.cancel();
    _subscriptions.remove(model.slug);

    final currentQuant = state?.downloadedQuantization;
    _modelStates[model.slug] = ModelState(
      status: currentQuant != null
          ? ModelDownloadStatus.downloaded
          : ModelDownloadStatus.notDownloaded,
      downloadedQuantization: currentQuant,
    );
    notifyListeners();
  }

  /// Deletes a downloaded model.
  Future<void> deleteModel(LeapModel model) async {
    final state = _modelStates[model.slug];
    final quantization = state?.downloadedQuantization;

    if (quantization != null) {
      await _liquidAi.deleteModel(model.slug, quantization.slug);
    }

    _modelStates[model.slug] = const ModelState(
      status: ModelDownloadStatus.notDownloaded,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}

import '../platform/liquid_ai_platform_interface.dart';

/// A loaded model runner that can perform inference.
class ModelRunner {
  /// Creates a new [ModelRunner].
  ModelRunner({
    required this.runnerId,
    required this.model,
    required this.quantization,
    LiquidAiPlatform? platform,
  }) : _platform = platform ?? LiquidAiPlatform.instance;

  /// The unique identifier for this runner.
  final String runnerId;

  /// The model slug.
  final String model;

  /// The quantization slug.
  final String quantization;

  /// Whether this runner has been disposed.
  bool _isDisposed = false;

  final LiquidAiPlatform _platform;

  /// Whether this runner has been disposed.
  bool get isDisposed => _isDisposed;

  /// Disposes of this runner and releases native resources.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _platform.unloadModel(runnerId);
  }
}

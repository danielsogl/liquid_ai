import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('ModelStatus', () {
    test('creates with default progress', () {
      const status = ModelStatus(type: ModelStatusType.notDownloaded);

      expect(status.type, ModelStatusType.notDownloaded);
      expect(status.progress, 0.0);
    });

    test('creates with custom progress', () {
      const status = ModelStatus(
        type: ModelStatusType.downloading,
        progress: 0.5,
      );

      expect(status.type, ModelStatusType.downloading);
      expect(status.progress, 0.5);
    });

    test('isDownloaded returns true when downloaded', () {
      const status = ModelStatus(
        type: ModelStatusType.downloaded,
        progress: 1.0,
      );

      expect(status.isDownloaded, isTrue);
      expect(status.isDownloading, isFalse);
    });

    test('isDownloading returns true when downloading', () {
      const status = ModelStatus(
        type: ModelStatusType.downloading,
        progress: 0.5,
      );

      expect(status.isDownloaded, isFalse);
      expect(status.isDownloading, isTrue);
    });

    test('fromMap parses downloaded status', () {
      final status = ModelStatus.fromMap({
        'type': 'downloaded',
        'progress': 1.0,
      });

      expect(status.type, ModelStatusType.downloaded);
      expect(status.progress, 1.0);
    });

    test('fromMap parses downloading status', () {
      final status = ModelStatus.fromMap({
        'type': 'downloading',
        'progress': 0.5,
      });

      expect(status.type, ModelStatusType.downloading);
      expect(status.progress, 0.5);
    });

    test('fromMap parses notDownloaded status', () {
      final status = ModelStatus.fromMap({
        'type': 'notDownloaded',
        'progress': 0.0,
      });

      expect(status.type, ModelStatusType.notDownloaded);
      expect(status.progress, 0.0);
    });

    test('fromMap handles unknown type as notDownloaded', () {
      final status = ModelStatus.fromMap({
        'type': 'unknown',
        'progress': 0.0,
      });

      expect(status.type, ModelStatusType.notDownloaded);
    });

    test('fromMap handles missing progress', () {
      final status = ModelStatus.fromMap({
        'type': 'downloaded',
      });

      expect(status.progress, 0.0);
    });

    test('fromMap handles integer progress', () {
      final status = ModelStatus.fromMap({
        'type': 'downloaded',
        'progress': 1,
      });

      expect(status.progress, 1.0);
    });

    test('toMap converts to map', () {
      const status = ModelStatus(
        type: ModelStatusType.downloading,
        progress: 0.5,
      );

      final map = status.toMap();

      expect(map['type'], 'downloading');
      expect(map['progress'], 0.5);
    });

    test('toString returns formatted string', () {
      const status = ModelStatus(
        type: ModelStatusType.downloaded,
        progress: 1.0,
      );

      expect(
        status.toString(),
        'ModelStatus(type: ModelStatusType.downloaded, progress: 1.0)',
      );
    });
  });
}

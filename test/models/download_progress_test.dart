import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('DownloadProgress', () {
    test('creates with required fields', () {
      const progress = DownloadProgress(
        operationId: 'op_1',
        progress: 0.5,
      );

      expect(progress.operationId, 'op_1');
      expect(progress.progress, 0.5);
      expect(progress.bytesDownloaded, isNull);
      expect(progress.totalBytes, isNull);
      expect(progress.speed, isNull);
    });

    test('creates with all fields', () {
      const progress = DownloadProgress(
        operationId: 'op_1',
        progress: 0.75,
        bytesDownloaded: 750000,
        totalBytes: 1000000,
        speed: 100000,
      );

      expect(progress.operationId, 'op_1');
      expect(progress.progress, 0.75);
      expect(progress.bytesDownloaded, 750000);
      expect(progress.totalBytes, 1000000);
      expect(progress.speed, 100000);
    });

    test('calculates progressPercent correctly', () {
      const progress = DownloadProgress(
        operationId: 'op_1',
        progress: 0.756,
      );

      expect(progress.progressPercent, 76);
    });

    test('creates from map with all fields', () {
      final progress = DownloadProgress.fromMap({
        'operationId': 'op_1',
        'progress': 0.5,
        'bytesDownloaded': 500000,
        'totalBytes': 1000000,
        'speed': 50000,
      });

      expect(progress.operationId, 'op_1');
      expect(progress.progress, 0.5);
      expect(progress.bytesDownloaded, 500000);
      expect(progress.totalBytes, 1000000);
      expect(progress.speed, 50000);
    });

    test('creates from map with minimal fields', () {
      final progress = DownloadProgress.fromMap({
        'operationId': 'op_1',
        'progress': 0.25,
      });

      expect(progress.operationId, 'op_1');
      expect(progress.progress, 0.25);
      expect(progress.bytesDownloaded, isNull);
      expect(progress.totalBytes, isNull);
      expect(progress.speed, isNull);
    });

    test('handles integer progress value', () {
      final progress = DownloadProgress.fromMap({
        'operationId': 'op_1',
        'progress': 1,
      });

      expect(progress.progress, 1.0);
    });

    test('converts to map', () {
      const progress = DownloadProgress(
        operationId: 'op_1',
        progress: 0.5,
        bytesDownloaded: 500000,
        totalBytes: 1000000,
        speed: 50000,
      );

      final map = progress.toMap();

      expect(map['operationId'], 'op_1');
      expect(map['progress'], 0.5);
      expect(map['bytesDownloaded'], 500000);
      expect(map['totalBytes'], 1000000);
      expect(map['speed'], 50000);
    });

    test('toMap excludes null fields', () {
      const progress = DownloadProgress(
        operationId: 'op_1',
        progress: 0.5,
      );

      final map = progress.toMap();

      expect(map.containsKey('bytesDownloaded'), isFalse);
      expect(map.containsKey('totalBytes'), isFalse);
      expect(map.containsKey('speed'), isFalse);
    });

    test('toString returns formatted string', () {
      const progress = DownloadProgress(
        operationId: 'op_1',
        progress: 0.75,
        speed: 100000,
      );

      expect(
        progress.toString(),
        'DownloadProgress(operationId: op_1, progress: 75%, speed: 100000 B/s)',
      );
    });

    test('toString handles null speed', () {
      const progress = DownloadProgress(
        operationId: 'op_1',
        progress: 0.5,
      );

      expect(
        progress.toString(),
        'DownloadProgress(operationId: op_1, progress: 50%, speed: 0 B/s)',
      );
    });
  });
}

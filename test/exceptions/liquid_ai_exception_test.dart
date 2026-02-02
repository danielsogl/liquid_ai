import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('parseLeapError', () {
    group('InsufficientMemoryException', () {
      test('detects "memory" keyword', () {
        final exception = parseLeapError('Out of memory');
        expect(exception, isA<InsufficientMemoryException>());
        expect(exception.code, equals('INSUFFICIENT_MEMORY'));
      });

      test('detects "insufficient memory" phrase', () {
        final exception = parseLeapError('Insufficient memory to load model');
        expect(exception, isA<InsufficientMemoryException>());
      });

      test('detects "oom" keyword', () {
        final exception = parseLeapError('OOM error occurred');
        expect(exception, isA<InsufficientMemoryException>());
      });

      test('detects "cannot allocate" phrase', () {
        final exception = parseLeapError('Cannot allocate 2GB for model');
        expect(exception, isA<InsufficientMemoryException>());
      });

      test('detects "allocation failed" phrase', () {
        final exception = parseLeapError('Memory allocation failed');
        expect(exception, isA<InsufficientMemoryException>());
      });
    });

    group('RequestInterruptedException', () {
      test('detects "request interrupted" phrase', () {
        final exception = parseLeapError('Request interrupted by user');
        expect(exception, isA<RequestInterruptedException>());
        expect(exception.code, equals('REQUEST_INTERRUPTED'));
      });

      test('detects "interrupted by user" phrase', () {
        final exception = parseLeapError(
          'LEAP Error: modelLoadingFailure [Request interrupted by user]',
        );
        expect(exception, isA<RequestInterruptedException>());
      });

      test('detects "operation cancelled" phrase', () {
        final exception = parseLeapError('Operation cancelled');
        expect(exception, isA<RequestInterruptedException>());
      });
    });

    group('ModelNotFoundException', () {
      test('detects "not found" phrase', () {
        final exception = parseLeapError('Model file not found');
        expect(exception, isA<ModelNotFoundException>());
        expect(exception.code, equals('MODEL_NOT_FOUND'));
      });

      test('detects "does not exist" phrase', () {
        final exception = parseLeapError('The specified model does not exist');
        expect(exception, isA<ModelNotFoundException>());
      });
    });

    group('NetworkException', () {
      test('detects "network" keyword', () {
        final exception = parseLeapError('Network error occurred');
        expect(exception, isA<NetworkException>());
        expect(exception.code, equals('NETWORK_ERROR'));
      });

      test('detects "connection" keyword', () {
        final exception = parseLeapError('Connection failed');
        expect(exception, isA<NetworkException>());
      });

      test('detects "timeout" keyword', () {
        final exception = parseLeapError('Request timeout');
        expect(exception, isA<NetworkException>());
      });

      test('detects "no internet" phrase', () {
        final exception = parseLeapError('No internet connection');
        expect(exception, isA<NetworkException>());
      });
    });

    group('LeapInternalException', () {
      test('detects "internalerror" keyword', () {
        final exception = parseLeapError('LeapSDK.LiquidError.internalError');
        expect(exception, isA<LeapInternalException>());
        expect(exception.code, equals('LEAP_INTERNAL_ERROR'));
      });

      test('detects "LEAP Error" phrase', () {
        final exception = parseLeapError('LEAP Error: something went wrong');
        expect(exception, isA<LeapInternalException>());
      });
    });

    group('ModelLoadingException', () {
      test('detects "modelloadingfailure" keyword', () {
        final exception = parseLeapError(
          'modelLoadingFailure: Failed to load weights',
        );
        expect(exception, isA<ModelLoadingException>());
        expect(exception.code, equals('MODEL_LOADING_FAILURE'));
      });

      test('detects "failed to load model" phrase', () {
        final exception = parseLeapError('Failed to load model from path');
        expect(exception, isA<ModelLoadingException>());
      });
    });

    group('LoadException (default)', () {
      test('returns LoadException for unrecognized errors', () {
        final exception = parseLeapError('Unknown error occurred');
        expect(exception, isA<LoadException>());
        expect(exception.code, equals('LOAD_ERROR'));
      });
    });

    group('real-world error messages', () {
      test('parses iOS LEAP error with interrupted message', () {
        final errorMessage =
            "LEAP Error: modelLoadingFailure ('Failed to load model from path: "
            "/var/mobile/Containers/Data/Application/.../leap_models/...' "
            "Optional(LeapSDK.LiquidError.internalError))"
            "[Request interrupted by user]";
        final exception = parseLeapError(errorMessage);
        // Should detect "interrupted by user" first
        expect(exception, isA<RequestInterruptedException>());
      });

      test('parses Android memory error', () {
        final errorMessage =
            'java.lang.OutOfMemoryError: Failed to allocate a 512MB allocation';
        final exception = parseLeapError(errorMessage);
        expect(exception, isA<InsufficientMemoryException>());
      });
    });
  });

  group('LoadErrorEvent', () {
    test('parses memory error correctly', () {
      final event = LoadErrorEvent(operationId: 'op_1', error: 'Out of memory');
      expect(event.isMemoryError, isTrue);
      expect(event.isInterrupted, isFalse);
      expect(event.isNetworkError, isFalse);
      expect(event.exception, isA<InsufficientMemoryException>());
    });

    test('parses interrupted error correctly', () {
      final event = LoadErrorEvent(
        operationId: 'op_1',
        error: 'Request interrupted by user',
      );
      expect(event.isMemoryError, isFalse);
      expect(event.isInterrupted, isTrue);
      expect(event.isNetworkError, isFalse);
      expect(event.exception, isA<RequestInterruptedException>());
    });

    test('parses network error correctly', () {
      final event = LoadErrorEvent(
        operationId: 'op_1',
        error: 'Network connection failed',
      );
      expect(event.isMemoryError, isFalse);
      expect(event.isInterrupted, isFalse);
      expect(event.isNetworkError, isTrue);
      expect(event.exception, isA<NetworkException>());
    });
  });

  group('DownloadErrorEvent', () {
    test('parses network error correctly', () {
      final event = DownloadErrorEvent(
        operationId: 'op_1',
        error: 'Connection timeout',
      );
      expect(event.isNetworkError, isTrue);
      expect(event.exception, isA<NetworkException>());
    });
  });

  group('parseLeapError with errorCode', () {
    test('uses errorCode when provided for INSUFFICIENT_MEMORY', () {
      final exception = parseLeapError(
        'Some generic error message',
        errorCode: 'INSUFFICIENT_MEMORY',
      );
      expect(exception, isA<InsufficientMemoryException>());
      expect(exception.code, equals('INSUFFICIENT_MEMORY'));
    });

    test('uses errorCode when provided for MODEL_NOT_FOUND', () {
      final exception = parseLeapError(
        'Some generic error message',
        errorCode: 'MODEL_NOT_FOUND',
      );
      expect(exception, isA<ModelNotFoundException>());
    });

    test('uses errorCode when provided for NETWORK_ERROR', () {
      final exception = parseLeapError(
        'Some generic error message',
        errorCode: 'NETWORK_ERROR',
      );
      expect(exception, isA<NetworkException>());
    });

    test('uses errorCode when provided for REQUEST_INTERRUPTED', () {
      final exception = parseLeapError(
        'Some generic error message',
        errorCode: 'REQUEST_INTERRUPTED',
      );
      expect(exception, isA<RequestInterruptedException>());
    });

    test('uses errorCode when provided for MODEL_LOADING_FAILURE', () {
      final exception = parseLeapError(
        'Some generic error message',
        errorCode: 'MODEL_LOADING_FAILURE',
      );
      expect(exception, isA<ModelLoadingException>());
    });

    test('uses errorCode when provided for INTERNAL_ERROR', () {
      final exception = parseLeapError(
        'Some generic error message',
        errorCode: 'INTERNAL_ERROR',
      );
      expect(exception, isA<LeapInternalException>());
    });

    test('falls back to string parsing for unknown errorCode', () {
      final exception = parseLeapError(
        'Out of memory error',
        errorCode: 'UNKNOWN_CODE',
      );
      // Should fall back to string parsing and detect memory error
      expect(exception, isA<InsufficientMemoryException>());
    });

    test('errorCode takes precedence over string parsing', () {
      // Message says "memory" but code says network
      final exception = parseLeapError(
        'Out of memory',
        errorCode: 'NETWORK_ERROR',
      );
      // ErrorCode should take precedence
      expect(exception, isA<NetworkException>());
    });
  });

  group('LoadErrorEvent with errorCode', () {
    test('uses errorCode from native', () {
      final event = LoadErrorEvent(
        operationId: 'op_1',
        error: 'Generic error',
        errorCode: 'INSUFFICIENT_MEMORY',
      );
      expect(event.isMemoryError, isTrue);
      expect(event.exception, isA<InsufficientMemoryException>());
    });
  });

  group('DownloadErrorEvent with errorCode', () {
    test('uses errorCode from native', () {
      final event = DownloadErrorEvent(
        operationId: 'op_1',
        error: 'Generic error',
        errorCode: 'NETWORK_ERROR',
      );
      expect(event.isNetworkError, isTrue);
      expect(event.exception, isA<NetworkException>());
    });
  });
}

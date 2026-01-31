import 'dart:typed_data';

import 'chat_message.dart';
import 'generation_stats.dart';
import 'leap_function.dart';

/// Base class for generation events.
sealed class GenerationEvent {
  const GenerationEvent();

  /// The unique generation identifier.
  String get generationId;

  /// Creates an event from a JSON map.
  factory GenerationEvent.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    final generationId = map['generationId'] as String;

    switch (type) {
      case 'chunk':
        return GenerationChunkEvent(
          generationId: generationId,
          chunk: map['chunk'] as String,
        );
      case 'reasoningChunk':
        return GenerationReasoningChunkEvent(
          generationId: generationId,
          chunk: map['chunk'] as String,
        );
      case 'audioSample':
        return GenerationAudioEvent(
          generationId: generationId,
          audioSamples: Float32List.fromList(
            (map['audioSamples'] as List)
                .map((e) => (e as num).toDouble())
                .toList(),
          ),
          sampleRate: map['sampleRate'] as int,
        );
      case 'functionCall':
        return GenerationFunctionCallEvent(
          generationId: generationId,
          functionCalls: (map['functionCalls'] as List)
              .map(
                (c) => LeapFunctionCall.fromMap(
                  Map<String, dynamic>.from(c as Map),
                ),
              )
              .toList(),
        );
      case 'complete':
        return GenerationCompleteEvent(
          generationId: generationId,
          message: ChatMessage.fromMap(
            Map<String, dynamic>.from(map['message'] as Map),
          ),
          finishReason: _parseFinishReason(map['finishReason'] as String),
          stats: map['stats'] != null
              ? GenerationStats.fromMap(
                  Map<String, dynamic>.from(map['stats'] as Map),
                )
              : null,
        );
      case 'error':
        return GenerationErrorEvent(
          generationId: generationId,
          error: map['error'] as String,
        );
      case 'cancelled':
        return GenerationCancelledEvent(generationId: generationId);
      default:
        throw ArgumentError('Unknown generation event type: $type');
    }
  }
}

/// Event containing a text chunk from generation.
class GenerationChunkEvent extends GenerationEvent {
  /// Creates a new [GenerationChunkEvent].
  const GenerationChunkEvent({required this.generationId, required this.chunk});

  @override
  final String generationId;

  /// The generated text chunk.
  final String chunk;

  @override
  String toString() =>
      'GenerationChunkEvent(generationId: $generationId, chunk: $chunk)';
}

/// Event containing a reasoning/thinking text chunk.
class GenerationReasoningChunkEvent extends GenerationEvent {
  /// Creates a new [GenerationReasoningChunkEvent].
  const GenerationReasoningChunkEvent({
    required this.generationId,
    required this.chunk,
  });

  @override
  final String generationId;

  /// The reasoning text chunk.
  final String chunk;

  @override
  String toString() =>
      'GenerationReasoningChunkEvent('
      'generationId: $generationId, chunk: $chunk)';
}

/// Event containing audio samples from generation.
class GenerationAudioEvent extends GenerationEvent {
  /// Creates a new [GenerationAudioEvent].
  const GenerationAudioEvent({
    required this.generationId,
    required this.audioSamples,
    required this.sampleRate,
  });

  @override
  final String generationId;

  /// The audio samples.
  final Float32List audioSamples;

  /// The sample rate in Hz.
  final int sampleRate;

  @override
  String toString() =>
      'GenerationAudioEvent('
      'generationId: $generationId, '
      'samples: ${audioSamples.length}, '
      'sampleRate: $sampleRate)';
}

/// Event containing function calls from the model.
class GenerationFunctionCallEvent extends GenerationEvent {
  /// Creates a new [GenerationFunctionCallEvent].
  const GenerationFunctionCallEvent({
    required this.generationId,
    required this.functionCalls,
  });

  @override
  final String generationId;

  /// The function calls made by the model.
  final List<LeapFunctionCall> functionCalls;

  @override
  String toString() =>
      'GenerationFunctionCallEvent('
      'generationId: $generationId, '
      'calls: ${functionCalls.length})';
}

/// Event indicating generation completed successfully.
class GenerationCompleteEvent extends GenerationEvent {
  /// Creates a new [GenerationCompleteEvent].
  const GenerationCompleteEvent({
    required this.generationId,
    required this.message,
    required this.finishReason,
    this.stats,
  });

  @override
  final String generationId;

  /// The complete generated message.
  final ChatMessage message;

  /// The reason generation finished.
  final GenerationFinishReason finishReason;

  /// Statistics about the generation.
  final GenerationStats? stats;

  @override
  String toString() =>
      'GenerationCompleteEvent('
      'generationId: $generationId, '
      'finishReason: $finishReason, '
      'stats: $stats)';
}

/// Event indicating an error during generation.
class GenerationErrorEvent extends GenerationEvent {
  /// Creates a new [GenerationErrorEvent].
  const GenerationErrorEvent({required this.generationId, required this.error});

  @override
  final String generationId;

  /// The error message.
  final String error;

  @override
  String toString() =>
      'GenerationErrorEvent(generationId: $generationId, error: $error)';
}

/// Event indicating generation was cancelled.
class GenerationCancelledEvent extends GenerationEvent {
  /// Creates a new [GenerationCancelledEvent].
  const GenerationCancelledEvent({required this.generationId});

  @override
  final String generationId;

  @override
  String toString() => 'GenerationCancelledEvent(generationId: $generationId)';
}

GenerationFinishReason _parseFinishReason(String reason) {
  switch (reason) {
    case 'endOfSequence':
      return GenerationFinishReason.endOfSequence;
    case 'maxTokens':
      return GenerationFinishReason.maxTokens;
    case 'stopped':
      return GenerationFinishReason.stopped;
    case 'functionCall':
      return GenerationFinishReason.functionCall;
    case 'error':
      return GenerationFinishReason.error;
    default:
      return GenerationFinishReason.endOfSequence;
  }
}

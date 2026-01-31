import 'dart:async';
import 'dart:convert';

import '../platform/liquid_ai_platform_interface.dart';
import '../schema/json_schema.dart';
import 'chat_message.dart';
import 'generation_event.dart';
import 'generation_options.dart';
import 'leap_function.dart';
import 'structured_generation.dart';

/// A conversation with a loaded model.
class Conversation {
  /// Creates a new [Conversation].
  Conversation({
    required this.conversationId,
    required this.runnerId,
    LiquidAiPlatform? platform,
  }) : _platform = platform ?? LiquidAiPlatform.instance;

  /// The unique identifier for this conversation.
  final String conversationId;

  /// The runner ID this conversation is associated with.
  final String runnerId;

  final LiquidAiPlatform _platform;

  bool _isDisposed = false;
  String? _activeGenerationId;

  /// Whether this conversation has been disposed.
  bool get isDisposed => _isDisposed;

  /// Whether a generation is currently in progress.
  bool get isGenerating => _activeGenerationId != null;

  /// Gets the conversation history.
  Future<List<ChatMessage>> getHistory() async {
    _checkDisposed();
    final history = await _platform.getConversationHistory(conversationId);
    return history.map((m) => ChatMessage.fromMap(m)).toList();
  }

  /// Generates a response to the given message.
  ///
  /// Returns a stream of generation events. The stream completes when
  /// generation is finished or an error occurs.
  Stream<GenerationEvent> generateResponse(
    ChatMessage message, {
    GenerationOptions? options,
  }) {
    _checkDisposed();

    final controller = StreamController<GenerationEvent>();
    StreamSubscription<Map<String, dynamic>>? subscription;

    () async {
      try {
        final generationId = await _platform.generateResponse(
          conversationId,
          message.toMap(),
          options: options?.toMap(),
        );

        _activeGenerationId = generationId;

        subscription = _platform.generationEvents
            .where((event) => event['generationId'] == generationId)
            .listen(
              (event) {
                try {
                  final generationEvent = GenerationEvent.fromMap(event);
                  controller.add(generationEvent);

                  if (generationEvent is GenerationCompleteEvent ||
                      generationEvent is GenerationErrorEvent ||
                      generationEvent is GenerationCancelledEvent) {
                    _activeGenerationId = null;
                    subscription?.cancel();
                    controller.close();
                  }
                } catch (e) {
                  controller.addError(e);
                }
              },
              onError: (error) {
                _activeGenerationId = null;
                controller.addError(error);
                controller.close();
              },
            );
      } catch (e) {
        _activeGenerationId = null;
        controller.addError(e);
        await controller.close();
      }
    }();

    controller.onCancel = () {
      subscription?.cancel();
    };

    return controller.stream;
  }

  /// Generates a simple text response.
  ///
  /// This is a convenience method that collects all chunks and returns
  /// the complete response text.
  Future<String> generateText(
    String prompt, {
    GenerationOptions? options,
  }) async {
    _checkDisposed();

    final message = ChatMessage.user(prompt);
    final buffer = StringBuffer();

    await for (final event in generateResponse(message, options: options)) {
      switch (event) {
        case GenerationChunkEvent():
          buffer.write(event.chunk);
        case GenerationCompleteEvent():
          return event.message.text ?? buffer.toString();
        case GenerationErrorEvent():
          throw Exception(event.error);
        case GenerationCancelledEvent():
          throw Exception('Generation was cancelled');
        default:
          break;
      }
    }

    return buffer.toString();
  }

  /// Generates a structured response matching the given schema.
  ///
  /// This method constrains the model output to match [schema] and
  /// automatically parses the JSON response using [fromJson].
  ///
  /// Example:
  /// ```dart
  /// final jokeSchema = JsonSchema.object('A joke')
  ///     .addString('setup', 'The setup')
  ///     .addString('punchline', 'The punchline')
  ///     .build();
  ///
  /// await for (final event in conversation.generateStructured(
  ///   message,
  ///   schema: jokeSchema,
  ///   fromJson: (json) => Joke.fromJson(json),
  /// )) {
  ///   switch (event) {
  ///     case StructuredCompleteEvent(:final result):
  ///       print(result.setup);
  ///       print(result.punchline);
  ///     case StructuredErrorEvent(:final error):
  ///       print('Error: $error');
  ///   }
  /// }
  /// ```
  Stream<StructuredGenerationEvent<T>> generateStructured<T>(
    ChatMessage message, {
    required JsonSchema schema,
    required T Function(Map<String, dynamic> json) fromJson,
    GenerationOptions? options,
  }) {
    _checkDisposed();

    final controller = StreamController<StructuredGenerationEvent<T>>();
    final buffer = StringBuffer();
    var tokenCount = 0;

    final schemaOptions = (options ?? const GenerationOptions()).withSchema(
      schema,
    );

    () async {
      try {
        await for (final event in generateResponse(
          message,
          options: schemaOptions,
        )) {
          switch (event) {
            case GenerationChunkEvent():
              buffer.write(event.chunk);
              tokenCount++;
              // Emit progress event (token count only, not partial JSON)
              controller.add(StructuredProgressEvent<T>(tokenCount: tokenCount));

            case GenerationCompleteEvent():
              final rawText = event.message.text ?? buffer.toString();

              // Step 1: Extract JSON from response
              Map<String, dynamic> jsonMap;
              try {
                jsonMap = JsonCleaner.extractJson(rawText);
              } on FormatException catch (e) {
                controller.add(
                  StructuredErrorEvent<T>(
                    error: 'Failed to extract JSON from response: ${e.message}',
                    rawResponse: rawText,
                  ),
                );
                await controller.close();
                return;
              }

              // Step 2: Convert to typed object using fromJson
              T result;
              try {
                result = fromJson(jsonMap);
              } catch (e) {
                controller.add(
                  StructuredErrorEvent<T>(
                    error: 'Failed to parse JSON into object: $e',
                    rawResponse: rawText,
                  ),
                );
                await controller.close();
                return;
              }

              // Step 3: Emit success event with clean JSON
              final cleanJson = const JsonEncoder.withIndent('  ').convert(
                jsonMap,
              );
              controller.add(
                StructuredCompleteEvent<T>(
                  result: result,
                  rawJson: cleanJson,
                  stats: event.stats,
                ),
              );
              await controller.close();

            case GenerationErrorEvent():
              controller.add(StructuredErrorEvent<T>(error: event.error));
              await controller.close();

            case GenerationCancelledEvent():
              controller.add(
                StructuredCancelledEvent<T>(
                  partialResponse: buffer.isNotEmpty ? buffer.toString() : null,
                ),
              );
              await controller.close();

            default:
              break;
          }
        }
      } catch (e) {
        controller.add(StructuredErrorEvent<T>(error: e.toString()));
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Stops the current generation.
  Future<void> stopGeneration() async {
    if (_activeGenerationId != null) {
      await _platform.stopGeneration(_activeGenerationId!);
      _activeGenerationId = null;
    }
  }

  /// Registers a function that can be called by the model.
  Future<void> registerFunction(LeapFunction function) async {
    _checkDisposed();
    await _platform.registerFunction(conversationId, function.toMap());
  }

  /// Provides the result of a function call back to the model.
  Future<void> provideFunctionResult(LeapFunctionResult result) async {
    _checkDisposed();
    await _platform.provideFunctionResult(conversationId, result.toMap());
  }

  /// Exports the conversation as a JSON string.
  Future<String> export() async {
    _checkDisposed();
    return _platform.exportConversation(conversationId);
  }

  /// Exports the conversation as a JSON object.
  Future<Map<String, dynamic>> exportAsMap() async {
    final jsonString = await export();
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  /// Disposes of this conversation and releases resources.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    if (_activeGenerationId != null) {
      await stopGeneration();
    }

    await _platform.disposeConversation(conversationId);
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Conversation has been disposed');
    }
  }
}

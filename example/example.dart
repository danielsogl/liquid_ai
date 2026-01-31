// ignore_for_file: avoid_print, unused_local_variable

/// Example demonstrating the liquid_ai package features.
///
/// This example shows how to:
/// - Load and manage AI models
/// - Generate text responses
/// - Stream chat responses
/// - Generate structured JSON output
/// - Use function calling (tool use)
/// - Browse the model catalog
library;

import 'dart:typed_data';

import 'package:liquid_ai/liquid_ai.dart';

void main() async {
  // Initialize the SDK
  final liquidAi = LiquidAi();

  // ============================================================
  // 1. Model Loading with Progress
  // ============================================================

  // Use the model catalog to find models by slug
  final model = ModelCatalog.findBySlug('LFM2.5-1.2B-Instruct');
  if (model == null) {
    print('Model not found in catalog');
    return;
  }

  // Use enum for quantization - get the default or specify one
  const quantization = ModelQuantization.q4KM;

  print('Loading ${model.name} (${quantization.slug})...');
  ModelRunner? modelRunner;

  await for (final event in liquidAi.loadModel(model.slug, quantization.slug)) {
    switch (event) {
      case LoadStartedEvent():
        print('Download started');
      case LoadProgressEvent(:final progress):
        print('Progress: ${(progress.progress * 100).toStringAsFixed(1)}%');
      case LoadCompleteEvent(:final runner):
        print('Model loaded!');
        modelRunner = runner;
      case LoadErrorEvent(:final error):
        print('Error: $error');
        return;
      case LoadCancelledEvent():
        print('Cancelled');
        return;
    }
  }

  final runner = modelRunner;
  if (runner == null) return;

  // ============================================================
  // 2. Simple Text Generation
  // ============================================================

  final conversation = await runner.createConversation(
    systemPrompt: 'You are a helpful assistant.',
  );

  // Quick one-shot generation
  final response = await conversation.generateText(
    'What is the capital of France?',
  );
  print('Response: $response');

  // ============================================================
  // 3. Streaming Chat
  // ============================================================

  print('\nStreaming response:');
  final message = ChatMessage.user('Tell me a short joke.');

  await for (final event in conversation.generateResponse(message)) {
    switch (event) {
      case GenerationChunkEvent(:final chunk):
        // Print each token as it arrives
        print(chunk);
      case GenerationCompleteEvent(:final stats):
        print('\n--- Generation complete ---');
        if (stats != null) {
          print('Tokens: ${stats.tokenCount}');
          print('Speed: ${stats.tokensPerSecond.toStringAsFixed(1)} tok/s');
        }
      case GenerationErrorEvent(:final error):
        print('Error: $error');
      case GenerationCancelledEvent():
        print('Cancelled');
      default:
        break;
    }
  }

  // ============================================================
  // 4. Structured JSON Output
  // ============================================================

  // Define a schema for the expected output
  final jokeSchema = JsonSchema.object('A joke with setup and punchline')
      .addString('setup', 'The setup of the joke')
      .addString('punchline', 'The punchline')
      .addString(
        'category',
        'The joke category',
        enumValues: ['pun', 'knock-knock', 'one-liner', 'other'],
      )
      .build();

  // Generate structured output
  print('\nGenerating structured joke...');
  final structuredMessage = ChatMessage.user('Tell me a programming joke.');

  await for (final event in conversation.generateStructured(
    structuredMessage,
    schema: jokeSchema,
    fromJson: (json) => Joke.fromJson(json),
  )) {
    switch (event) {
      case StructuredProgressEvent(:final tokenCount):
        print('Generating... ($tokenCount tokens)');
      case StructuredCompleteEvent<Joke>(:final result, :final rawJson):
        print('Setup: ${result.setup}');
        print('Punchline: ${result.punchline}');
        print('Category: ${result.category}');
        print('Raw JSON: $rawJson');
      case StructuredErrorEvent(:final error, :final rawResponse):
        print('Error: $error');
        if (rawResponse != null) print('Raw: $rawResponse');
      case StructuredCancelledEvent():
        print('Cancelled');
    }
  }

  // ============================================================
  // 5. Function Calling (Tool Use)
  // ============================================================

  // Define a function the model can call
  final weatherFunction = LeapFunction.withSchema(
    name: 'get_weather',
    description: 'Get the current weather for a location',
    schema: JsonSchema.object('Weather request parameters')
        .addString('location', 'The city name, e.g., "San Francisco"')
        .addString(
          'unit',
          'Temperature unit',
          required: false,
          enumValues: ['celsius', 'fahrenheit'],
        )
        .build(),
  );

  // Register the function with the conversation
  await conversation.registerFunction(weatherFunction);

  // Generate a response that may call the function
  print('\nAsking about weather...');
  final weatherMessage = ChatMessage.user("What's the weather in Tokyo?");

  await for (final event in conversation.generateResponse(weatherMessage)) {
    switch (event) {
      case GenerationFunctionCallEvent(:final functionCalls):
        for (final call in functionCalls) {
          print('Function called: ${call.name}');
          print('Arguments: ${call.arguments}');

          // Execute the function (your implementation)
          final result = await getWeather(
            call.arguments['location'] as String,
            call.arguments['unit'] as String? ?? 'celsius',
          );

          // Provide result back to the model
          await conversation.provideFunctionResult(
            LeapFunctionResult(callId: call.id, result: result),
          );
        }
      case GenerationChunkEvent(:final chunk):
        print(chunk);
      case GenerationCompleteEvent():
        print('\n--- Complete ---');
      default:
        break;
    }
  }

  // ============================================================
  // 6. Multimodal (Vision)
  // ============================================================

  // Load a vision-language model for image understanding
  final visionModel = ModelCatalog.findBySlug('LFM2.5-VL-1.6B');
  if (visionModel == null) {
    print('Vision model not found');
    return;
  }

  // Vision models use Q8_0 or F16 quantization
  print('\nLoading ${visionModel.name}...');
  ModelRunner? visionRunner;

  await for (final event in liquidAi.loadModel(
    visionModel.slug,
    visionModel.defaultQuantization.slug,
  )) {
    if (event is LoadCompleteEvent) {
      visionRunner = event.runner;
    }
  }

  if (visionRunner != null) {
    final visionConversation = await visionRunner.createConversation();

    // Create a message with image content
    final imageBytes = Uint8List(0); // Your JPEG image bytes here
    final imageMessage = ChatMessage(
      role: ChatMessageRole.user,
      content: [
        ImageContent(data: imageBytes),
        TextContent(text: 'What do you see in this image?'),
      ],
    );

    await for (final event in visionConversation.generateResponse(
      imageMessage,
    )) {
      if (event is GenerationChunkEvent) {
        print(event.chunk);
      }
    }

    await visionConversation.dispose();
    await visionRunner.dispose();
  }

  // ============================================================
  // 7. Model Catalog
  // ============================================================

  print('\n--- Available Models ---');

  // Get all available models
  for (final model in ModelCatalog.available) {
    print('${model.name} (${model.parameters})');
    print('  ${model.description}');
    print(
      '  Quantizations: ${model.quantizations.map((q) => q.quantization.name).join(", ")}',
    );
    print('');
  }

  // Filter by capability
  print('Vision models:');
  for (final model in ModelCatalog.visionModels) {
    print('  - ${model.name}');
  }

  // Find a specific model
  final thinkingModel = ModelCatalog.findBySlug('LFM2.5-1.2B-Thinking');
  if (thinkingModel != null) {
    print('\nReasoning model: ${thinkingModel.name}');
    print('Context length: ${thinkingModel.contextLength} tokens');
    print('Default quantization: ${thinkingModel.defaultQuantization.slug}');
  }

  // ============================================================
  // 8. Model Management
  // ============================================================

  // Check if a model is downloaded (using the model and quantization from above)
  final isDownloaded = await liquidAi.isModelDownloaded(
    model.slug,
    quantization.slug,
  );
  print('\nModel downloaded: $isDownloaded');

  // Get model status
  final status = await liquidAi.getModelStatus(model.slug, quantization.slug);
  print('Model status: $status');

  // Delete a model when no longer needed
  // await liquidAi.deleteModel(model.slug, quantization.slug);

  // ============================================================
  // Cleanup
  // ============================================================

  await conversation.dispose();
  await runner.dispose();

  print('\nDone!');
}

// ============================================================
// Helper Classes and Functions
// ============================================================

/// Example data class for structured generation.
class Joke {
  final String setup;
  final String punchline;
  final String category;

  Joke({required this.setup, required this.punchline, required this.category});

  factory Joke.fromJson(Map<String, dynamic> json) {
    return Joke(
      setup: json['setup'] as String,
      punchline: json['punchline'] as String,
      category: json['category'] as String,
    );
  }
}

/// Example function for tool use demonstration.
Future<String> getWeather(String location, String unit) async {
  // In a real app, this would call a weather API
  return '{"temperature": 22, "unit": "$unit", "condition": "sunny"}';
}

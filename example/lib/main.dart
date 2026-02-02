// ignore_for_file: avoid_print

/// Example app demonstrating the liquid_ai package.
///
/// This example shows the key features of the liquid_ai package:
///
/// ## Quick Start
///
/// ```dart
/// import 'package:liquid_ai/liquid_ai.dart';
///
/// void main() async {
///   final liquidAi = LiquidAi();
///
///   // Load a model from the catalog
///   await for (final event in liquidAi.loadModel(
///     'LFM2.5-1.2B-Instruct',
///     'Q4_K_M',
///   )) {
///     if (event is LoadCompleteEvent) {
///       final runner = event.runner;
///       final conversation = await runner.createConversation(
///         systemPrompt: 'You are a helpful assistant.',
///       );
///
///       // Simple text generation
///       final response = await conversation.generateText(
///         'What is the capital of France?',
///       );
///       print(response); // "Paris is the capital of France."
///
///       await conversation.dispose();
///       await runner.dispose();
///     }
///   }
/// }
/// ```
///
/// ## Streaming Responses
///
/// ```dart
/// final message = ChatMessage.user('Tell me a joke.');
///
/// await for (final event in conversation.generateResponse(message)) {
///   switch (event) {
///     case GenerationChunkEvent(:final chunk):
///       print(chunk); // Print each token as it arrives
///     case GenerationCompleteEvent(:final stats):
///       print('Speed: ${stats?.tokensPerSecond} tok/s');
///   }
/// }
/// ```
///
/// ## Structured Output (JSON)
///
/// ```dart
/// final schema = JsonSchema.object('A joke')
///     .addString('setup', 'The setup')
///     .addString('punchline', 'The punchline')
///     .build();
///
/// await for (final event in conversation.generateStructured(
///   ChatMessage.user('Tell me a joke.'),
///   schema: schema,
///   fromJson: (json) => Joke.fromJson(json),
/// )) {
///   if (event is StructuredCompleteEvent<Joke>) {
///     print(event.result.setup);
///     print(event.result.punchline);
///   }
/// }
/// ```
///
/// ## Function Calling (Tools)
///
/// ```dart
/// final weatherTool = LeapFunction.withSchema(
///   name: 'get_weather',
///   description: 'Get weather for a location',
///   schema: JsonSchema.object('Parameters')
///       .addString('location', 'City name')
///       .build(),
/// );
///
/// await conversation.registerFunction(weatherTool);
///
/// await for (final event in conversation.generateResponse(
///   ChatMessage.user("What's the weather in Tokyo?"),
/// )) {
///   if (event is GenerationFunctionCallEvent) {
///     for (final call in event.functionCalls) {
///       final result = await getWeather(call.arguments['location']);
///       await conversation.provideFunctionResult(
///         LeapFunctionResult(callId: call.id, result: result),
///       );
///     }
///   }
/// }
/// ```
///
/// ## Vision (Multimodal)
///
/// ```dart
/// // Load a vision model
/// await for (final event in liquidAi.loadModel(
///   'LFM2.5-VL-1.6B',
///   'F16',
/// )) {
///   if (event is LoadCompleteEvent) {
///     final conversation = await event.runner.createConversation();
///
///     final message = ChatMessage(
///       role: ChatMessageRole.user,
///       content: [
///         ImageContent(data: imageBytes), // JPEG bytes
///         TextContent(text: 'Describe this image.'),
///       ],
///     );
///
///     await for (final event in conversation.generateResponse(message)) {
///       if (event is GenerationChunkEvent) print(event.chunk);
///     }
///   }
/// }
/// ```
///
/// ## Model Catalog
///
/// ```dart
/// // Browse available models
/// for (final model in ModelCatalog.available) {
///   print('${model.name} - ${model.description}');
/// }
///
/// // Filter by capability
/// final visionModels = ModelCatalog.visionModels;
/// final thinkingModels = ModelCatalog.thinkingModels;
///
/// // Find specific model
/// final model = ModelCatalog.findBySlug('LFM2.5-1.2B-Instruct');
/// ```
///
/// See [example/example.dart](https://github.com/danielsogl/liquid_ai/blob/main/example/example.dart)
/// for a comprehensive runnable example with all features.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/chat_state.dart';
import 'state/download_state.dart';
import 'state/tools_state.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadState()..initialize()),
        ChangeNotifierProvider(create: (_) => ChatState()),
        ChangeNotifierProvider(create: (_) => ToolsState()),
      ],
      child: const LiquidAiExampleApp(),
    ),
  );
}

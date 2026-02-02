# liquid_ai

[![pub package](https://img.shields.io/pub/v/liquid_ai.svg)](https://pub.dev/packages/liquid_ai)
[![build](https://github.com/danielsogl/liquid_ai/actions/workflows/checks.yml/badge.svg)](https://github.com/danielsogl/liquid_ai/actions/workflows/checks.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/danielsogl/liquid_ai/blob/main/LICENSE)

Run powerful on-device AI models in your Flutter apps with the LEAP SDK. Supports text generation, streaming chat, structured JSON output, function calling, and vision models - all running locally on iOS and Android.

## Features

- **On-Device Inference** - Run AI models locally without internet connectivity
- **Streaming Responses** - Real-time token-by-token text generation
- **Structured Output** - Constrain model output to JSON schemas with automatic validation
- **Function Calling** - Define tools the model can invoke with typed parameters
- **Vision Models** - Analyze images with multimodal vision-language models
- **Model Catalog** - Browse and filter 20+ optimized models for different tasks
- **Progress Tracking** - Monitor download and loading progress with detailed events
- **Resource Management** - Efficient memory handling with explicit lifecycle control

## Platform Support

| Platform | Supported | Notes |
|----------|-----------|-------|
| iOS      | Yes       | iOS 17.0+, SPM (default) or CocoaPods |
| Android  | Yes       | API 31+ (Android 12) |
| macOS    | No        | Not yet supported |
| Web      | No        | Native inference only |

## Quick Start

### Installation

Add `liquid_ai` to your `pubspec.yaml`:

```yaml
dependencies:
  liquid_ai: ^0.0.1
```

### iOS Setup

**Swift Package Manager (default, recommended):**

SPM is enabled by default in Flutter 3.24+. No additional setup required.

**CocoaPods (alternative):**

If you need to use CocoaPods, add the LEAP SDK git source to your `ios/Podfile`:

```ruby
target 'Runner' do
  # Add LEAP SDK from git (required for v0.9.x)
  pod 'Leap-SDK', :git => 'https://github.com/Liquid4All/leap-ios.git', :tag => 'v0.9.2'
  pod 'Leap-Model-Downloader', :git => 'https://github.com/Liquid4All/leap-ios.git', :tag => 'v0.9.2'

  # ... rest of your Podfile
end
```

Then disable SPM in your `pubspec.yaml`:

```yaml
flutter:
  config:
    enable-swift-package-manager: false
```

### Basic Usage

```dart
import 'package:liquid_ai/liquid_ai.dart';

// Initialize the SDK
final liquidAi = LiquidAi();

// Find a model from the catalog
final model = ModelCatalog.findBySlug('LFM2.5-1.2B-Instruct')!;
const quantization = ModelQuantization.q4KM;

// Load the model (downloads if needed)
ModelRunner? runner;
await for (final event in liquidAi.loadModel(model.slug, quantization.slug)) {
  if (event is LoadCompleteEvent) {
    runner = event.runner;
  }
}

// Create a conversation and generate text
final conversation = await runner!.createConversation(
  systemPrompt: 'You are a helpful assistant.',
);
final response = await conversation.generateText('Hello!');
print(response);

// Clean up
await conversation.dispose();
await runner.dispose();
```

## Model Loading

Models are downloaded automatically on first use and cached locally. Track progress with load events:

```dart
// Use the catalog and enums for type safety
final model = ModelCatalog.findBySlug('LFM2.5-1.2B-Instruct')!;
const quantization = ModelQuantization.q4KM;

// Or use the model's default quantization
final defaultQuant = model.defaultQuantization;

await for (final event in liquidAi.loadModel(model.slug, quantization.slug)) {
  switch (event) {
    case LoadStartedEvent():
      print('Starting download...');
    case LoadProgressEvent(:final progress):
      print('${(progress.progress * 100).toStringAsFixed(1)}%');
      if (progress.speed != null) {
        print('Speed: ${progress.speed! ~/ 1024} KB/s');
      }
    case LoadCompleteEvent(:final runner):
      print('Ready!');
      // Use runner to create conversations
    case LoadErrorEvent(:final error):
      print('Failed: $error');
    case LoadCancelledEvent():
      print('Cancelled');
  }
}
```

### Load Options

Configure the inference engine when loading models:

```dart
await for (final event in liquidAi.loadModel(
  model.slug,
  quantization.slug,
  options: LoadOptions(
    contextSize: 4096,   // Maximum context window
    batchSize: 512,      // Batch size for prompt processing
    threads: 4,          // Number of CPU threads
    gpuLayers: 32,       // Layers to offload to GPU (if available)
  ),
)) {
  // Handle events...
}
```

### Load from Local File

Load a model directly from a file path (useful for custom or bundled models):

```dart
await for (final event in liquidAi.loadModelFromPath(
  '/path/to/model.gguf',
  options: LoadOptions(contextSize: 2048),
)) {
  if (event is LoadCompleteEvent) {
    runner = event.runner;
  }
}
```

### Model Status

```dart
// Check if already downloaded
final downloaded = await liquidAi.isModelDownloaded(model.slug, quantization.slug);

// Get detailed status
final status = await liquidAi.getModelStatus(model.slug, quantization.slug);

// Delete to free storage
await liquidAi.deleteModel(model.slug, quantization.slug);
```

### Download from URL (Hugging Face Support)

Download models directly from any URL, including Hugging Face:

```dart
await for (final event in liquidAi.downloadModelFromUrl(
  url: 'https://huggingface.co/user/model/resolve/main/model.gguf?download=true',
  modelId: 'my-custom-model',
  quantization: 'Q4_K_M', // Optional, defaults to 'custom'
)) {
  switch (event) {
    case DownloadProgressEvent(:final progress):
      print('${(progress.progress * 100).toStringAsFixed(1)}%');
    case DownloadCompleteEvent():
      print('Download complete!');
    case DownloadErrorEvent(:final error):
      print('Error: $error');
    default:
      break;
  }
}

// Then load the downloaded model
await for (final event in liquidAi.loadModel('my-custom-model', 'Q4_K_M')) {
  // Handle load events...
}
```

### Cache Management

List and manage cached models:

```dart
// Check if a specific model is cached (useful for URL-downloaded models)
final isCached = await liquidAi.isModelCached('my-custom-model');
if (!isCached) {
  // Download the model...
}

// List all cached models
final cachedModels = await liquidAi.getCachedModels();
for (final manifest in cachedModels) {
  print('${manifest.modelSlug} (${manifest.quantizationSlug})');
  print('  Path: ${manifest.localModelPath}');
}

// Delete all cached models to free storage
await liquidAi.deleteAllModels();
```

### Model Manifest

When a model is loaded, you can access extended metadata through the `ModelManifest`:

```dart
await for (final event in liquidAi.loadModel(model.slug, quantization.slug)) {
  if (event is LoadCompleteEvent) {
    final manifest = event.manifest;
    if (manifest != null) {
      print('Model: ${manifest.modelSlug}');
      print('Quantization: ${manifest.quantizationSlug}');
      print('Path: ${manifest.localModelPath}');

      // Access via runner as well
      print('Runner manifest: ${event.runner.manifest}');
    }
  }
}
```

## Text Generation

### Simple Generation

```dart
final response = await conversation.generateText('What is the capital of France?');
print(response); // "The capital of France is Paris."
```

### Streaming Generation

Stream tokens as they're generated for real-time display:

```dart
final message = ChatMessage.user('Tell me a story.');

await for (final event in conversation.generateResponse(message)) {
  switch (event) {
    case GenerationChunkEvent(:final chunk):
      stdout.write(chunk); // Print token immediately
    case GenerationCompleteEvent(:final stats):
      print('\n${stats?.tokensPerSecond?.toStringAsFixed(1)} tokens/sec');
    case GenerationErrorEvent(:final error):
      print('Error: $error');
    default:
      break;
  }
}
```

### Generation Options

Fine-tune generation with sampling parameters:

```dart
final options = GenerationOptions(
  temperature: 0.7,    // Creativity (0.0-2.0)
  topP: 0.9,           // Nucleus sampling
  topK: 40,            // Top-K sampling
  maxTokens: 256,      // Maximum output length
);

final response = await conversation.generateText(
  'Write a haiku.',
  options: options,
);
```

## Structured Output

Generate JSON that conforms to a schema with automatic validation:

```dart
// Define the expected output structure
final recipeSchema = JsonSchema.object('A cooking recipe')
    .addString('name', 'The recipe name')
    .addArray('ingredients', 'List of ingredients',
        items: StringProperty(description: 'An ingredient'))
    .addInt('prepTime', 'Preparation time in minutes', minimum: 1)
    .addInt('cookTime', 'Cooking time in minutes', minimum: 0)
    .addObject('nutrition', 'Nutritional information',
        configureNested: (b) => b
            .addInt('calories', 'Calories per serving')
            .addNumber('protein', 'Protein in grams'))
    .build();

// Generate structured output
final message = ChatMessage.user('Give me a recipe for chocolate chip cookies.');

await for (final event in conversation.generateStructured(
  message,
  schema: recipeSchema,
  fromJson: Recipe.fromJson,
)) {
  switch (event) {
    case StructuredProgressEvent(:final tokenCount):
      print('Generating... ($tokenCount tokens)');
    case StructuredCompleteEvent<Recipe>(:final result):
      print('Recipe: ${result.name}');
      print('Ingredients: ${result.ingredients.join(", ")}');
      print('Calories: ${result.nutrition.calories}');
    case StructuredErrorEvent(:final error, :final rawResponse):
      print('Failed: $error');
  }
}
```

### Schema Types

The schema builder supports these property types:

| Method | JSON Type | Options |
|--------|-----------|---------|
| `addString` | `string` | `enumValues`, `minLength`, `maxLength` |
| `addInt` | `integer` | `minimum`, `maximum` |
| `addNumber` | `number` | `minimum`, `maximum` |
| `addBool` | `boolean` | - |
| `addArray` | `array` | `items`, `minItems`, `maxItems` |
| `addObject` | `object` | `configureNested` |

## Function Calling

Define tools the model can invoke to extend its capabilities:

```dart
// Define a function with typed parameters
final searchFunction = LeapFunction.withSchema(
  name: 'search_web',
  description: 'Search the web for current information',
  schema: JsonSchema.object('Search parameters')
      .addString('query', 'The search query')
      .addInt('limit', 'Maximum results', required: false, minimum: 1, maximum: 10)
      .build(),
);

// Register with the conversation
await conversation.registerFunction(searchFunction);

// Handle function calls during generation
await for (final event in conversation.generateResponse(message)) {
  switch (event) {
    case GenerationFunctionCallEvent(:final functionCalls):
      for (final call in functionCalls) {
        print('Calling ${call.name} with ${call.arguments}');

        // Execute your function
        final result = await executeSearch(call.arguments);

        // Return the result to continue generation
        await conversation.provideFunctionResult(
          LeapFunctionResult(callId: call.id, result: result),
        );
      }
    case GenerationChunkEvent(:final chunk):
      stdout.write(chunk);
    default:
      break;
  }
}
```

## Vision Models

Analyze images with multimodal vision-language models:

```dart
// Load a vision model from the catalog
final visionModel = ModelCatalog.findBySlug('LFM2.5-VL-1.6B')!;

await for (final event in liquidAi.loadModel(
  visionModel.slug,
  visionModel.defaultQuantization.slug, // Q8_0 for vision models
)) {
  if (event is LoadCompleteEvent) {
    runner = event.runner;
  }
}

// Create a conversation and send an image
final conversation = await runner.createConversation();

// Load image as JPEG bytes
final imageBytes = await File('photo.jpg').readAsBytes();

final message = ChatMessage(
  role: ChatMessageRole.user,
  content: [
    ImageContent(data: imageBytes),
    TextContent(text: 'Describe what you see in this image.'),
  ],
);

await for (final event in conversation.generateResponse(message)) {
  if (event is GenerationChunkEvent) {
    stdout.write(event.chunk);
  }
}
```

## Model Catalog

Browse available models programmatically:

```dart
// All available (non-deprecated) models
final models = ModelCatalog.available;

// Filter by capability
final visionModels = ModelCatalog.visionModels;
final reasoningModels = ModelCatalog.byTask(ModelTask.reasoning);
final japaneseModels = ModelCatalog.byLanguage('ja');

// Find a specific model
final model = ModelCatalog.findBySlug('LFM2.5-1.2B-Instruct');
if (model != null) {
  print('${model.name} - ${model.parameters} parameters');
  print('Context: ${model.contextLength} tokens');

  // Access available quantizations
  for (final quant in model.quantizations) {
    print('  ${quant.quantization.name}: ${quant.slug}');
  }

  // Get the recommended default quantization
  print('Default: ${model.defaultQuantization.slug}');
}
```

### Available Models

| Model | Parameters | Task | Modalities |
|-------|------------|------|------------|
| LFM2.5-1.2B-Instruct | 1.2B | General | Text |
| LFM2.5-1.2B-Thinking | 1.2B | Reasoning | Text |
| LFM2.5-VL-1.6B | 1.6B | General | Text, Image |
| LFM2-2.6B | 2.6B | General | Text |
| LFM2-2.6B-Exp | 2.6B | Reasoning | Text |
| LFM2-VL-3B | 3B | General | Text, Image |
| LFM2-350M | 350M | General | Text |
| LFM2-700M | 700M | General | Text |

See `ModelCatalog.all` for the complete list including specialized models for extraction, translation, and summarization.

### Quantization Options

Models are available in multiple quantization levels via the `ModelQuantization` enum:

| Enum | Slug | Size | Quality | Use Case |
|------|------|------|---------|----------|
| `ModelQuantization.q4_0` | `Q4_0` | Smallest | Good | Mobile devices, fast inference |
| `ModelQuantization.q4KM` | `Q4_K_M` | Small | Better | Balanced quality and size |
| `ModelQuantization.q5KM` | `Q5_K_M` | Medium | High | Quality-focused applications |
| `ModelQuantization.q8_0` | `Q8_0` | Large | Highest | Maximum quality |
| `ModelQuantization.f16` | `F16` | Largest | Reference | Vision models only |

## Error Handling

Handle errors gracefully with typed exceptions:

```dart
try {
  final response = await conversation.generateText('...');
} on LiquidAiException catch (e) {
  print('SDK error: ${e.message}');
} on StateError catch (e) {
  print('Invalid state: ${e.message}'); // e.g., disposed conversation
}
```

Common error scenarios:

- **Model not found** - Invalid model slug or quantization
- **Download failed** - Network issues during model download
- **Out of memory** - Model too large for device
- **Context exceeded** - Conversation history too long
- **Generation cancelled** - User or timeout cancellation

## Conversation Management

### System Prompts

Set context for the conversation:

```dart
final conversation = await runner.createConversation(
  systemPrompt: 'You are a helpful coding assistant. Respond concisely.',
);
```

### Conversation History

Access and restore conversation state:

```dart
// Get current history
final history = await conversation.getHistory();

// Export conversation
final json = await conversation.export();

// Create from existing history
final restored = await runner.createConversationFromHistory(history);
```

### Clear History

Reset the conversation while keeping it active:

```dart
// Clear history but keep the system prompt
await conversation.clearHistory();

// Clear everything including system prompt
await conversation.clearHistory(keepSystemPrompt: false);
```

### Fork Conversations

Create independent copies for exploring different conversation branches:

```dart
// Create a checkpoint before trying something
final checkpoint = await conversation.fork();

// Try something in the original conversation
await conversation.generateText('Tell me about quantum physics');

// Use the checkpoint to explore a different path
await checkpoint.generateText('Tell me about biology');

// Both conversations now have different histories
// Don't forget to dispose the forked conversation when done
await checkpoint.dispose();
```

### Token Counting

Monitor context usage (iOS only):

```dart
final tokens = await conversation.getTokenCount();
if (tokens > 4000) {
  print('Warning: Approaching context limit');
}
```

## Resource Management

### Basic Cleanup

Always dispose of resources when done:

```dart
// Dispose in reverse order of creation
await conversation.dispose();
await runner.dispose();

// Or use try/finally
try {
  final conversation = await runner.createConversation();
  // Use conversation...
} finally {
  await conversation.dispose();
}
```

### ModelManager for Single-Model Apps

For apps that load only one model at a time, use `ModelManager` to automatically manage model lifecycle:

```dart
final manager = ModelManager.instance;

// Load a model (automatically unloads any previous model)
final runner = await manager.loadModelAsync('LFM2.5-1.2B-Instruct', 'Q4_K_M');

// Check what's loaded
print('Loaded: ${manager.currentModelSlug}');
print('Has model: ${manager.hasLoadedModel}');

// Load a different model (previous one is automatically unloaded first)
final newRunner = await manager.loadModelAsync('LFM2-2.6B', 'Q4_K_M');

// Explicitly unload when done
await manager.unloadCurrentModel();
```

### Hot-Reload Recovery

During Flutter hot-reload, Dart state is reset but native state persists. Use `syncWithNative()` to recover the loaded model state:

```dart
// In your app initialization
Future<void> initializeApp() async {
  final manager = ModelManager.instance;

  // Sync Dart state with native state
  final wasModelLoaded = await manager.syncWithNative();

  if (wasModelLoaded) {
    print('Recovered loaded model: ${manager.currentModelSlug}');
    // The runner is available at manager.currentRunner
  }
}
```

This is especially important for state management solutions like Provider:

```dart
class AppState extends ChangeNotifier {
  final _modelManager = ModelManager.instance;

  Future<void> initialize() async {
    // Recover model state after hot-reload
    await _modelManager.syncWithNative();

    if (_modelManager.hasLoadedModel) {
      // Update UI state to reflect loaded model
      notifyListeners();
    }
  }
}
```

### Loading Models from Local Paths

Load models from custom locations (useful for bundled or custom models):

```dart
// Using ModelManager
final runner = await ModelManager.instance.loadModelFromPathAsync(
  '/path/to/model.gguf',
  options: LoadOptions(contextSize: 2048),
);

// Check if loaded from path
if (ModelManager.instance.isCurrentModelPathLoaded) {
  print('Model path: ${ModelManager.instance.currentPath}');
}
```

## API Reference

For complete API documentation, see the [API Reference](https://pub.dev/documentation/liquid_ai/latest/).

Key classes:

- [`LiquidAi`](https://pub.dev/documentation/liquid_ai/latest/liquid_ai/LiquidAi-class.html) - Main entry point for model management
- [`ModelRunner`](https://pub.dev/documentation/liquid_ai/latest/liquid_ai/ModelRunner-class.html) - A loaded model ready for inference
- [`ModelManager`](https://pub.dev/documentation/liquid_ai/latest/liquid_ai/ModelManager-class.html) - Singleton for single-model lifecycle management
- [`ModelManifest`](https://pub.dev/documentation/liquid_ai/latest/liquid_ai/ModelManifest-class.html) - Extended metadata for loaded models
- [`Conversation`](https://pub.dev/documentation/liquid_ai/latest/liquid_ai/Conversation-class.html) - Chat session with history
- [`JsonSchema`](https://pub.dev/documentation/liquid_ai/latest/liquid_ai/JsonSchema-class.html) - Schema builder for structured output
- [`LeapFunction`](https://pub.dev/documentation/liquid_ai/latest/liquid_ai/LeapFunction-class.html) - Function definition for tool use
- [`ModelCatalog`](https://pub.dev/documentation/liquid_ai/latest/liquid_ai/ModelCatalog-class.html) - Model discovery and filtering

## Contributing

Contributions are welcome! Please read our [contributing guidelines](https://github.com/danielsogl/liquid_ai/blob/main/CONTRIBUTING.md) before submitting a pull request.

## License

MIT License - see the [LICENSE](https://github.com/danielsogl/liquid_ai/blob/main/LICENSE) file for details.

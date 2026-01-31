import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:liquid_ai/liquid_ai.dart';

/// Represents a message in the tools demo chat UI.
class ToolsMessageUI {
  const ToolsMessageUI({
    required this.type,
    required this.content,
    this.functionName,
    this.functionArguments,
    this.isStreaming = false,
    this.stats,
  });

  /// The type of message.
  final ToolsMessageType type;

  /// The text content of the message.
  final String content;

  /// The name of the function (for function call/result messages).
  final String? functionName;

  /// The function arguments (for function call messages).
  final Map<String, dynamic>? functionArguments;

  /// Whether the message is currently streaming.
  final bool isStreaming;

  /// Generation statistics (only for assistant messages).
  final GenerationStats? stats;

  ToolsMessageUI copyWith({
    ToolsMessageType? type,
    String? content,
    String? functionName,
    Map<String, dynamic>? functionArguments,
    bool? isStreaming,
    GenerationStats? stats,
  }) {
    return ToolsMessageUI(
      type: type ?? this.type,
      content: content ?? this.content,
      functionName: functionName ?? this.functionName,
      functionArguments: functionArguments ?? this.functionArguments,
      isStreaming: isStreaming ?? this.isStreaming,
      stats: stats ?? this.stats,
    );
  }
}

/// Types of messages in the tools demo.
enum ToolsMessageType {
  /// A message from the user.
  user,

  /// A message from the assistant.
  assistant,

  /// A function call from the assistant.
  functionCall,

  /// A result from a function execution.
  functionResult,
}

/// Default system prompt for the tools demo.
const _toolsSystemPrompt = '''
You are a helpful AI assistant with access to tools. When the user asks for
weather information or mathematical calculations, use the appropriate tool.

Available tools:
- get_weather: Get the current weather for a location
- calculate: Perform a mathematical calculation

Always use tools when appropriate rather than making up answers.
''';

/// Demo functions available in the tools demo.
final List<LeapFunction> _demoFunctions = [
  LeapFunction.withSchema(
    name: 'get_weather',
    description: 'Get the current weather for a specified location.',
    schema: JsonSchema.object('Weather request parameters')
        .addString('location', 'The city name, e.g., "New York" or "London"')
        .addString(
          'unit',
          'Temperature unit',
          required: false,
          enumValues: ['celsius', 'fahrenheit'],
        )
        .build(),
  ),
  LeapFunction.withSchema(
    name: 'calculate',
    description: 'Perform a mathematical calculation.',
    schema: JsonSchema.object('Calculation parameters')
        .addString(
          'expression',
          'The mathematical expression to evaluate, e.g., "2 + 2" or "sqrt(16)"',
        )
        .build(),
  ),
];

/// Manages state for the tools demo conversation.
class ToolsState extends ChangeNotifier {
  ToolsState();

  /// The currently loaded model runner.
  ModelRunner? _runner;

  /// The current conversation.
  Conversation? _conversation;

  /// The currently selected model.
  LeapModel? _selectedModel;

  /// The messages in the current conversation.
  final List<ToolsMessageUI> _messages = [];

  /// Whether a generation is in progress.
  bool _isGenerating = false;

  /// Gets the list of messages.
  List<ToolsMessageUI> get messages => List.unmodifiable(_messages);

  /// Gets the list of registered demo functions.
  List<LeapFunction> get registeredFunctions =>
      List.unmodifiable(_demoFunctions);

  /// Gets whether the tools demo is ready to use.
  bool get isReady => _runner != null && _conversation != null;

  /// Gets whether a generation is in progress.
  bool get isGenerating => _isGenerating;

  /// Gets the current runner.
  ModelRunner? get runner => _runner;

  /// Gets the currently selected model.
  LeapModel? get selectedModel => _selectedModel;

  /// Initializes the tools demo with a model runner.
  Future<void> initialize(ModelRunner runner, {LeapModel? model}) async {
    _runner = runner;
    _selectedModel = model;
    _messages.clear();

    _conversation = await runner.createConversation(
      systemPrompt: _toolsSystemPrompt,
    );

    // Register all demo functions
    for (final function in _demoFunctions) {
      await _conversation!.registerFunction(function);
    }

    notifyListeners();
  }

  /// Switches to a different model.
  Future<void> switchModel(ModelRunner runner, {LeapModel? model}) async {
    if (_isGenerating) {
      await stopGeneration();
    }

    await _conversation?.dispose();
    _conversation = null;
    _runner = null;

    await initialize(runner, model: model);
  }

  /// Sends a message and handles the response.
  Future<void> sendMessage(String text) async {
    debugPrint('[ToolsState] sendMessage called with: $text');
    if (!isReady || _isGenerating) {
      debugPrint('[ToolsState] sendMessage blocked - isReady: $isReady, isGenerating: $_isGenerating');
      return;
    }
    if (text.trim().isEmpty) return;

    // Add user message
    _messages.add(ToolsMessageUI(type: ToolsMessageType.user, content: text));

    _isGenerating = true;
    notifyListeners();

    final message = ChatMessage.user(text);
    debugPrint('[ToolsState] Starting generation with user message');
    await _generateWithFunctionHandling(message);
    debugPrint('[ToolsState] sendMessage completed');
  }

  /// Generates a response and handles function calls following the SDK pattern.
  ///
  /// This method follows the Leap SDK's tool calling flow:
  /// 1. Generate response with user message
  /// 2. If function calls received, execute them
  /// 3. Send results back via ChatMessage.tool()
  /// 4. Continue generation to get final response
  Future<void> _generateWithFunctionHandling(ChatMessage message) async {
    debugPrint('[ToolsState] _generateWithFunctionHandling called');
    debugPrint('[ToolsState] Message role: ${message.role}, content: ${message.text}');

    // Only add assistant placeholder for non-tool messages
    if (message.role != ChatMessageRole.tool) {
      _messages.add(
        const ToolsMessageUI(
          type: ToolsMessageType.assistant,
          content: '',
          isStreaming: true,
        ),
      );
      notifyListeners();
    }

    final buffer = StringBuffer();
    List<LeapFunctionCall>? pendingFunctionCalls;

    try {
      debugPrint('[ToolsState] Starting generation');
      await for (final event in _conversation!.generateResponse(message)) {
        debugPrint('[ToolsState] Received event: ${event.runtimeType}');

        switch (event) {
          case GenerationChunkEvent():
            buffer.write(event.chunk);
            _updateLastMessage(buffer.toString(), isStreaming: true);

          case GenerationFunctionCallEvent():
            debugPrint('[ToolsState] Function calls received: ${event.functionCalls.length}');
            // Remove empty assistant placeholder
            _removeLastAssistantMessageIfEmpty();
            // Store function calls to process after stream completes
            pendingFunctionCalls = event.functionCalls;

          case GenerationCompleteEvent():
            debugPrint('[ToolsState] Generation complete');
            final responseText = event.message.text ?? buffer.toString();

            if (pendingFunctionCalls != null) {
              // Process function calls and continue with tool message
              await _processFunctionCalls(pendingFunctionCalls);
            } else if (responseText.isNotEmpty) {
              // Normal text response
              _updateLastMessage(
                responseText,
                isStreaming: false,
                stats: event.stats,
              );
              _isGenerating = false;
              notifyListeners();
            } else {
              _removeLastAssistantMessageIfEmpty();
              _isGenerating = false;
              notifyListeners();
            }

          case GenerationErrorEvent():
            debugPrint('[ToolsState] Error: ${event.error}');
            _updateLastMessage('Error: ${event.error}', isStreaming: false);
            _isGenerating = false;
            notifyListeners();

          case GenerationCancelledEvent():
            debugPrint('[ToolsState] Cancelled');
            _updateLastMessage(buffer.toString(), isStreaming: false);
            _isGenerating = false;
            notifyListeners();

          default:
            break;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ToolsState] Error: $e\n$stackTrace');
      _updateLastMessage('Error: $e', isStreaming: false);
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Processes function calls and continues generation.
  ///
  /// Flow:
  /// 1. Execute each function
  /// 2. Provide results back to conversation history
  /// 3. Send continuation message to get natural language response
  Future<void> _processFunctionCalls(List<LeapFunctionCall> calls) async {
    debugPrint('[ToolsState] Processing ${calls.length} function calls');

    final results = <String>[];

    for (final call in calls) {
      // Add function call UI message
      _messages.add(
        ToolsMessageUI(
          type: ToolsMessageType.functionCall,
          content: 'Calling ${call.name}...',
          functionName: call.name,
          functionArguments: call.arguments,
        ),
      );
      notifyListeners();

      // Execute the function
      final result = await _executeFunction(call);
      debugPrint('[ToolsState] ${call.name} returned: $result');

      // Add function result UI message
      _messages.add(
        ToolsMessageUI(
          type: ToolsMessageType.functionResult,
          content: result,
          functionName: call.name,
        ),
      );
      notifyListeners();

      // Provide result back to conversation history
      await _conversation!.provideFunctionResult(
        LeapFunctionResult(callId: call.id, result: result),
      );

      results.add('${call.name} returned: $result');
    }

    // Send continuation message to get natural language response
    // Using user message with explicit instructions to avoid another tool call
    final resultsText = results.join('\n');
    final continuationMessage = ChatMessage.user(
      'The tool returned the following results:\n$resultsText\n\n'
      'Please provide a helpful response to the user based on these results.',
    );

    debugPrint('[ToolsState] Sending continuation message');

    // Add placeholder for the model's response
    _messages.add(
      const ToolsMessageUI(
        type: ToolsMessageType.assistant,
        content: '',
        isStreaming: true,
      ),
    );
    notifyListeners();

    // Continue generation - this should produce natural language, not another tool call
    await _generateWithFunctionHandling(continuationMessage);
  }

  /// Executes a demo function and returns the result.
  Future<String> _executeFunction(LeapFunctionCall call) async {
    switch (call.name) {
      case 'get_weather':
        return _getWeather(call.arguments);
      case 'calculate':
        return _calculate(call.arguments);
      default:
        return json.encode({'error': 'Unknown function: ${call.name}'});
    }
  }

  /// Mock implementation of get_weather function.
  String _getWeather(Map<String, dynamic> args) {
    final location = args['location'] as String? ?? 'Unknown';
    final unit = args['unit'] as String? ?? 'celsius';

    // Generate mock weather data
    final random = Random();
    final tempC = random.nextInt(30) + 5; // 5-35°C
    final temp = unit == 'fahrenheit' ? (tempC * 9 / 5 + 32).round() : tempC;
    final conditions = [
      'sunny',
      'cloudy',
      'partly cloudy',
      'rainy',
    ][random.nextInt(4)];
    final humidity = random.nextInt(60) + 30; // 30-90%

    return json.encode({
      'location': location,
      'temperature': temp,
      'unit': unit == 'fahrenheit' ? '°F' : '°C',
      'conditions': conditions,
      'humidity': '$humidity%',
    });
  }

  /// Mock implementation of calculate function.
  String _calculate(Map<String, dynamic> args) {
    final expression = args['expression'] as String? ?? '';

    try {
      // Simple expression evaluation (handles basic arithmetic)
      final result = _evaluateExpression(expression);
      return json.encode({'expression': expression, 'result': result});
    } catch (e) {
      return json.encode({
        'expression': expression,
        'error': 'Could not evaluate expression: $e',
      });
    }
  }

  /// Simple expression evaluator for basic arithmetic.
  double _evaluateExpression(String expression) {
    // Clean up the expression
    final expr = expression.replaceAll(' ', '').toLowerCase();

    // Handle sqrt
    final sqrtMatch = RegExp(r'sqrt\((\d+(?:\.\d+)?)\)').firstMatch(expr);
    if (sqrtMatch != null) {
      final value = double.parse(sqrtMatch.group(1)!);
      return sqrt(value);
    }

    // Handle basic arithmetic
    if (expr.contains('+')) {
      final parts = expr.split('+');
      return parts.map(double.parse).reduce((a, b) => a + b);
    }
    if (expr.contains('-') && !expr.startsWith('-')) {
      final parts = expr.split('-');
      return parts.map(double.parse).reduce((a, b) => a - b);
    }
    if (expr.contains('*')) {
      final parts = expr.split('*');
      return parts.map(double.parse).reduce((a, b) => a * b);
    }
    if (expr.contains('/')) {
      final parts = expr.split('/');
      return parts.map(double.parse).reduce((a, b) => a / b);
    }

    // Try to parse as a number
    return double.parse(expr);
  }

  /// Stops the current generation.
  Future<void> stopGeneration() async {
    await _conversation?.stopGeneration();
    _isGenerating = false;
    if (_messages.isNotEmpty) {
      _updateLastMessage(_messages.last.content, isStreaming: false);
    }
    notifyListeners();
  }

  /// Clears the conversation and starts fresh.
  Future<void> clearConversation() async {
    if (_runner == null) return;

    await _conversation?.dispose();
    _messages.clear();

    _conversation = await _runner!.createConversation(
      systemPrompt: _toolsSystemPrompt,
    );

    // Re-register all demo functions
    for (final function in _demoFunctions) {
      await _conversation!.registerFunction(function);
    }

    notifyListeners();
  }

  /// Resets the tools state.
  void reset() {
    _runner = null;
    _conversation = null;
    _selectedModel = null;
    _isGenerating = false;
    _messages.clear();
    notifyListeners();
  }

  void _updateLastMessage(
    String content, {
    required bool isStreaming,
    GenerationStats? stats,
  }) {
    if (_messages.isEmpty) return;

    final lastIndex = _messages.length - 1;
    final lastMessage = _messages[lastIndex];

    // Only update if the last message is an assistant message
    if (lastMessage.type == ToolsMessageType.assistant) {
      _messages[lastIndex] = lastMessage.copyWith(
        content: content,
        isStreaming: isStreaming,
        stats: stats,
      );
      notifyListeners();
    }
  }

  /// Removes the last assistant message if it's empty (streaming placeholder).
  void _removeLastAssistantMessageIfEmpty() {
    if (_messages.isEmpty) return;

    final lastMessage = _messages.last;
    if (lastMessage.type == ToolsMessageType.assistant &&
        lastMessage.content.isEmpty) {
      _messages.removeLast();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _conversation?.dispose();
    super.dispose();
  }
}

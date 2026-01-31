import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
    description:
        'Get the current weather for a location. Returns temperature, '
        'feels-like temperature, humidity, wind speed, gusts, and conditions.',
    schema: JsonSchema.object('Weather request parameters')
        .addString('location', 'The city name, e.g., "New York" or "London"')
        .addString(
          'unit',
          'Temperature unit (default: celsius)',
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
    if (!isReady || _isGenerating) return;
    if (text.trim().isEmpty) return;

    // Add user message
    _messages.add(ToolsMessageUI(type: ToolsMessageType.user, content: text));

    _isGenerating = true;
    notifyListeners();

    final message = ChatMessage.user(text);
    await _generateWithFunctionHandling(message);
  }

  /// Generates a response and handles function calls following the SDK pattern.
  ///
  /// This method follows the Leap SDK's tool calling flow:
  /// 1. Generate response with user message
  /// 2. If function calls received, execute them
  /// 3. Send results back via ChatMessage.tool()
  /// 4. Continue generation to get final response
  Future<void> _generateWithFunctionHandling(ChatMessage message) async {
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
      await for (final event in _conversation!.generateResponse(message)) {
        switch (event) {
          case GenerationChunkEvent():
            buffer.write(event.chunk);
            _updateLastMessage(buffer.toString(), isStreaming: true);

          case GenerationFunctionCallEvent():
            // Remove empty assistant placeholder
            _removeLastAssistantMessageIfEmpty();
            // Store function calls to process after stream completes
            pendingFunctionCalls = event.functionCalls;

          case GenerationCompleteEvent():
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
            _updateLastMessage('Error: ${event.error}', isStreaming: false);
            _isGenerating = false;
            notifyListeners();

          case GenerationCancelledEvent():
            _updateLastMessage(buffer.toString(), isStreaming: false);
            _isGenerating = false;
            notifyListeners();

          default:
            break;
        }
      }
    } catch (e) {
      _updateLastMessage('Error: $e', isStreaming: false);
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Processes function calls and continues generation.
  ///
  /// Flow:
  /// 1. Execute each function
  /// 2. Add tool result to conversation history
  /// 3. Generate response without function calling constraint
  Future<void> _processFunctionCalls(List<LeapFunctionCall> calls) async {
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

      // Add function result UI message
      _messages.add(
        ToolsMessageUI(
          type: ToolsMessageType.functionResult,
          content: result,
          functionName: call.name,
        ),
      );
      notifyListeners();

      // Add tool result to conversation history
      await _conversation!.provideFunctionResult(
        LeapFunctionResult(callId: call.id, result: result),
      );

      results.add('${call.name}: $result');
    }

    // Create a new conversation from history WITHOUT function registration
    // This avoids the tool call constraint being applied
    final history = await _conversation!.getHistory();
    await _conversation!.dispose();
    _conversation = await _runner!.createConversationFromHistory(history);

    // Note: We intentionally do NOT re-register functions here
    // so the model can generate a natural language response

    // Add assistant placeholder
    _messages.add(
      const ToolsMessageUI(
        type: ToolsMessageType.assistant,
        content: '',
        isStreaming: true,
      ),
    );
    notifyListeners();

    // Generate natural language response
    final prompt = 'Based on the tool results, provide a helpful response.';
    final buffer = StringBuffer();

    try {
      await for (final event in _conversation!.generateResponse(
        ChatMessage.user(prompt),
      )) {
        switch (event) {
          case GenerationChunkEvent():
            buffer.write(event.chunk);
            _updateLastMessage(buffer.toString(), isStreaming: true);

          case GenerationCompleteEvent():
            final responseText = event.message.text ?? buffer.toString();
            _updateLastMessage(
              responseText,
              isStreaming: false,
              stats: event.stats,
            );

            // Re-register functions for future tool calls
            for (final function in _demoFunctions) {
              await _conversation!.registerFunction(function);
            }

            _isGenerating = false;
            notifyListeners();

          case GenerationErrorEvent():
            _updateLastMessage('Error: ${event.error}', isStreaming: false);
            _isGenerating = false;
            notifyListeners();

          case GenerationCancelledEvent():
            _updateLastMessage(buffer.toString(), isStreaming: false);
            _isGenerating = false;
            notifyListeners();

          default:
            break;
        }
      }
    } catch (e) {
      _updateLastMessage('Error: $e', isStreaming: false);
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Executes a demo function and returns the result.
  Future<String> _executeFunction(LeapFunctionCall call) async {
    switch (call.name) {
      case 'get_weather':
        return await _getWeather(call.arguments);
      case 'calculate':
        return _calculate(call.arguments);
      default:
        return json.encode({'error': 'Unknown function: ${call.name}'});
    }
  }

  /// Fetches real weather data from Open-Meteo API.
  Future<String> _getWeather(Map<String, dynamic> args) async {
    final location = args['location'] as String? ?? 'Unknown';
    final isFahrenheit = args['unit'] == 'fahrenheit';

    try {
      // Geocode the location to get coordinates
      final geo = await _geocodeLocation(location);
      if (geo == null) {
        return json.encode({'error': 'Location not found: $location'});
      }

      // Fetch weather data using coordinates
      final weather = await _fetchWeather(
        geo['lat'] as double,
        geo['lon'] as double,
        isFahrenheit: isFahrenheit,
      );
      if (weather == null) {
        return json.encode({'error': 'Failed to fetch weather data'});
      }

      final tempUnit = isFahrenheit ? '°F' : '°C';
      final speedUnit = isFahrenheit ? 'mph' : 'km/h';

      return json.encode({
        'location': geo['name'],
        'conditions': _getWeatherCondition(weather['code'] as int),
        'temperature': '${weather['temp']}$tempUnit',
        'feelsLike': '${weather['feelsLike']}$tempUnit',
        'humidity': '${weather['humidity']}%',
        'wind': '${weather['windSpeed']} $speedUnit',
        'gusts': '${weather['windGusts']} $speedUnit',
      });
    } catch (e) {
      return json.encode({'error': 'Weather fetch failed: $e'});
    }
  }

  /// Geocodes a location name to coordinates.
  Future<Map<String, dynamic>?> _geocodeLocation(String location) async {
    final url = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeComponent(location)}&count=1',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    final place = results[0] as Map<String, dynamic>;
    final name = place['name'] as String;
    final country = place['country'] as String? ?? '';

    return {
      'lat': place['latitude'] as double,
      'lon': place['longitude'] as double,
      'name': country.isNotEmpty ? '$name, $country' : name,
    };
  }

  /// Fetches current weather for given coordinates.
  Future<Map<String, dynamic>?> _fetchWeather(
    double lat,
    double lon, {
    bool isFahrenheit = false,
  }) async {
    final tempUnit = isFahrenheit ? 'fahrenheit' : 'celsius';
    final windUnit = isFahrenheit ? 'mph' : 'kmh';
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,apparent_temperature,relative_humidity_2m,'
      'wind_speed_10m,wind_gusts_10m,weather_code'
      '&temperature_unit=$tempUnit&wind_speed_unit=$windUnit',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;

    return {
      'temp': (current['temperature_2m'] as num).round(),
      'feelsLike': (current['apparent_temperature'] as num).round(),
      'humidity': (current['relative_humidity_2m'] as num).round(),
      'windSpeed': (current['wind_speed_10m'] as num).round(),
      'windGusts': (current['wind_gusts_10m'] as num).round(),
      'code': current['weather_code'] as int,
    };
  }

  /// Maps Open-Meteo weather codes to human-readable conditions.
  String _getWeatherCondition(int code) {
    return switch (code) {
      0 => 'Clear sky',
      1 => 'Mainly clear',
      2 => 'Partly cloudy',
      3 => 'Overcast',
      45 || 48 => 'Foggy',
      51 || 53 || 55 => 'Drizzle',
      56 || 57 => 'Freezing drizzle',
      61 || 63 || 65 => 'Rain',
      66 || 67 => 'Freezing rain',
      71 || 73 || 75 => 'Snow',
      77 => 'Snow grains',
      80 || 81 || 82 => 'Rain showers',
      85 || 86 => 'Snow showers',
      95 => 'Thunderstorm',
      96 || 99 => 'Thunderstorm with hail',
      _ => 'Unknown',
    };
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

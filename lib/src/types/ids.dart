/// Type-safe identifier types for the Liquid AI SDK.
///
/// These extension types provide compile-time type safety for various IDs
/// used throughout the SDK, preventing accidental mixing of different ID types.
///
/// Example:
/// ```dart
/// // These are different types and cannot be accidentally mixed:
/// final runnerId = RunnerId('runner_1');
/// final conversationId = ConversationId('conv_1');
///
/// // This would be a compile error:
/// // someMethodExpectingRunnerId(conversationId); // Error!
/// ```
library;

/// A unique identifier for a model runner.
///
/// Model runners are created when a model is loaded and can be used to
/// create conversations.
extension type const RunnerId(String value) implements String {
  /// Creates a [RunnerId] from a string value.
  const RunnerId.fromString(String value) : this(value);
}

/// A unique identifier for a conversation.
///
/// Conversations are created from a model runner and maintain message history.
extension type const ConversationId(String value) implements String {
  /// Creates a [ConversationId] from a string value.
  const ConversationId.fromString(String value) : this(value);
}

/// A unique identifier for a generation operation.
///
/// Generation IDs are returned when starting a generation and can be used
/// to stop or track the generation.
extension type const GenerationId(String value) implements String {
  /// Creates a [GenerationId] from a string value.
  const GenerationId.fromString(String value) : this(value);
}

/// A unique identifier for a download or load operation.
///
/// Operation IDs are returned when starting operations like downloading or
/// loading models, and can be used to cancel or track progress.
extension type const OperationId(String value) implements String {
  /// Creates an [OperationId] from a string value.
  const OperationId.fromString(String value) : this(value);
}

/// A unique identifier for a function call made by the model.
///
/// Function call IDs link function calls to their results.
extension type const FunctionCallId(String value) implements String {
  /// Creates a [FunctionCallId] from a string value.
  const FunctionCallId.fromString(String value) : this(value);
}

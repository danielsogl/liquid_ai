import 'dart:convert';

import 'generation_stats.dart';

/// Events emitted during structured generation.
sealed class StructuredGenerationEvent<T> {
  const StructuredGenerationEvent();
}

/// Event indicating generation progress.
///
/// Unlike streaming text, this just indicates that generation is ongoing
/// without exposing partial (unparseable) JSON content.
class StructuredProgressEvent<T> extends StructuredGenerationEvent<T> {
  /// Creates a new [StructuredProgressEvent].
  const StructuredProgressEvent({required this.tokenCount});

  /// The number of tokens generated so far.
  final int tokenCount;

  @override
  String toString() => 'StructuredProgressEvent(tokenCount: $tokenCount)';
}

/// Event indicating structured generation completed successfully.
class StructuredCompleteEvent<T> extends StructuredGenerationEvent<T> {
  /// Creates a new [StructuredCompleteEvent].
  const StructuredCompleteEvent({
    required this.result,
    required this.rawJson,
    this.stats,
  });

  /// The parsed result object.
  final T result;

  /// The raw JSON string (after cleanup).
  final String rawJson;

  /// Statistics about the generation.
  final GenerationStats? stats;

  @override
  String toString() =>
      'StructuredCompleteEvent(result: $result, stats: $stats)';
}

/// Event indicating an error during structured generation.
class StructuredErrorEvent<T> extends StructuredGenerationEvent<T> {
  /// Creates a new [StructuredErrorEvent].
  const StructuredErrorEvent({required this.error, this.rawResponse});

  /// The error message.
  final String error;

  /// The raw response that failed to parse, if available.
  final String? rawResponse;

  @override
  String toString() => 'StructuredErrorEvent(error: $error)';
}

/// Event indicating structured generation was cancelled.
class StructuredCancelledEvent<T> extends StructuredGenerationEvent<T> {
  /// Creates a new [StructuredCancelledEvent].
  const StructuredCancelledEvent({this.partialResponse});

  /// Any partial response generated before cancellation.
  final String? partialResponse;

  @override
  String toString() => 'StructuredCancelledEvent()';
}

/// Utility for cleaning and extracting JSON from LLM output.
class JsonCleaner {
  /// Extracts and parses JSON from LLM output.
  ///
  /// This method handles various formats that LLMs commonly produce:
  /// - Pure JSON: `{"key": "value"}`
  /// - Markdown code blocks: ```json\n{"key": "value"}\n```
  /// - Text before/after JSON: `Here's the result: {"key": "value"} Hope this helps!`
  /// - Mixed content with markdown
  ///
  /// Returns the parsed JSON map.
  /// Throws [FormatException] if no valid JSON can be extracted.
  static Map<String, dynamic> extractJson(String text) {
    final trimmed = text.trim();

    // Strategy 1: Try direct parse (pure JSON)
    try {
      return jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      // Continue to other strategies
    }

    // Strategy 2: Extract from markdown code block
    final markdownJson = _extractFromMarkdownBlock(trimmed);
    if (markdownJson != null) {
      try {
        return jsonDecode(markdownJson) as Map<String, dynamic>;
      } catch (_) {
        // Continue to other strategies
      }
    }

    // Strategy 3: Find JSON object in text (first { to matching })
    final extractedJson = _extractJsonObject(trimmed);
    if (extractedJson != null) {
      try {
        return jsonDecode(extractedJson) as Map<String, dynamic>;
      } catch (_) {
        // Continue to other strategies
      }
    }

    // Strategy 4: Try stripping common prefixes/suffixes
    final stripped = _stripCommonPrefixesSuffixes(trimmed);
    if (stripped != trimmed) {
      try {
        return jsonDecode(stripped) as Map<String, dynamic>;
      } catch (_) {
        // Fall through to error
      }
    }

    throw FormatException(
      'Could not extract valid JSON from response',
      text,
    );
  }

  /// Extracts JSON content from markdown code blocks.
  static String? _extractFromMarkdownBlock(String text) {
    // Pattern for ```json ... ``` or ``` ... ```
    final patterns = [
      RegExp(r'```json\s*\n?([\s\S]*?)\n?```', multiLine: true),
      RegExp(r'```\s*\n?([\s\S]*?)\n?```', multiLine: true),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final content = match.group(1)?.trim();
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
    }

    return null;
  }

  /// Extracts a JSON object by finding balanced braces.
  static String? _extractJsonObject(String text) {
    final startIndex = text.indexOf('{');
    if (startIndex == -1) return null;

    var depth = 0;
    var inString = false;
    var escape = false;

    for (var i = startIndex; i < text.length; i++) {
      final char = text[i];

      if (escape) {
        escape = false;
        continue;
      }

      if (char == r'\') {
        escape = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        continue;
      }

      if (inString) continue;

      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return text.substring(startIndex, i + 1);
        }
      }
    }

    return null;
  }

  /// Strips common prefixes and suffixes that LLMs add.
  static String _stripCommonPrefixesSuffixes(String text) {
    var result = text;

    // Common prefixes
    final prefixes = [
      RegExp(r"^Here'?s?\s+(the\s+)?(JSON|result|response)[:\s]*", caseSensitive: false),
      RegExp(r'^(The\s+)?(JSON|result|response)\s+(is|would be)[:\s]*', caseSensitive: false),
      RegExp(r'^Sure[!,.]?\s*(Here[^:]*:)?\s*', caseSensitive: false),
      RegExp(r'^Certainly[!,.]?\s*(Here[^:]*:)?\s*', caseSensitive: false),
    ];

    for (final prefix in prefixes) {
      result = result.replaceFirst(prefix, '');
    }

    // Common suffixes
    final suffixes = [
      RegExp(r'\s*(Hope\s+this\s+helps[!.]?|Let\s+me\s+know[^.]*[.!]?)\s*$', caseSensitive: false),
      RegExp(r'\s*(This\s+JSON[^.]*[.!]?)\s*$', caseSensitive: false),
    ];

    for (final suffix in suffixes) {
      result = result.replaceFirst(suffix, '');
    }

    return result.trim();
  }

  /// Attempts to parse JSON, cleaning markdown if needed.
  ///
  /// Returns the parsed object or throws a [FormatException].
  /// @Deprecated: Use [extractJson] instead for better extraction.
  static Map<String, dynamic> parseJson(String text) {
    return extractJson(text);
  }

  /// Strips markdown code blocks from a JSON string.
  ///
  /// Handles formats like:
  /// - ```json ... ```
  /// - ``` ... ```
  @Deprecated('Use extractJson instead for more robust parsing')
  static String stripMarkdownCodeBlocks(String text) {
    var cleaned = text.trim();

    // Handle ```json prefix
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }

    // Handle ``` suffix
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }

    return cleaned.trim();
  }
}

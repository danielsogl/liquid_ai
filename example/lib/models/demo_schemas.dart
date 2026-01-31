import 'package:liquid_ai/liquid_ai.dart';

/// Pre-defined schemas for the structured output demo.

/// Schema for generating jokes with metadata.
final jokeSchema = JsonSchema.object('A joke with setup, punchline, and rating')
    .addString('setup', 'The setup or premise of the joke')
    .addString('punchline', 'The punchline that delivers the humor')
    .addString(
      'category',
      'The category of the joke',
      enumValues: ['pun', 'dad-joke', 'programming', 'wordplay', 'one-liner'],
    )
    .addInt(
      'rating',
      'Self-assessed humor rating from 1 to 10',
      minimum: 1,
      maximum: 10,
    )
    .build();

/// Schema for extracting recipe information.
final recipeSchema =
    JsonSchema.object('A recipe with ingredients and instructions')
        .addString('name', 'The name of the dish')
        .addString('description', 'A brief description of the dish')
        .addArray(
          'ingredients',
          'List of ingredients needed',
          items: const ObjectProperty(
            description: 'An ingredient with name and quantity',
            properties: {
              'name': StringProperty(description: 'Name of the ingredient'),
              'quantity': StringProperty(description: 'Amount needed'),
            },
            required: ['name', 'quantity'],
          ),
          minItems: 1,
        )
        .addArray(
          'instructions',
          'Step-by-step cooking instructions',
          items: const StringProperty(description: 'A cooking step'),
          minItems: 1,
        )
        .addInt('prepTimeMinutes', 'Preparation time in minutes', minimum: 0)
        .addInt('cookTimeMinutes', 'Cooking time in minutes', minimum: 0)
        .addInt('servings', 'Number of servings', minimum: 1)
        .build();

/// Schema for sentiment analysis results.
final sentimentSchema = JsonSchema.object('Sentiment analysis of text')
    .addString(
      'sentiment',
      'The overall sentiment',
      enumValues: ['positive', 'negative', 'neutral', 'mixed'],
    )
    .addNumber(
      'confidence',
      'Confidence score from 0.0 to 1.0',
      minimum: 0.0,
      maximum: 1.0,
    )
    .addArray(
      'keywords',
      'Key words or phrases that influenced the analysis',
      items: const StringProperty(description: 'A keyword or phrase'),
      minItems: 1,
      maxItems: 5,
    )
    .addString('explanation', 'Brief explanation of the sentiment analysis')
    .build();

/// Demo configuration for a structured output example.
class StructuredDemo {
  const StructuredDemo({
    required this.title,
    required this.description,
    required this.schema,
    required this.samplePrompt,
  });

  final String title;
  final String description;
  final JsonSchema schema;
  final String samplePrompt;
}

/// List of available demos.
final structuredDemos = [
  StructuredDemo(
    title: 'Joke Generator',
    description: 'Generate jokes with structured metadata',
    schema: jokeSchema,
    samplePrompt: 'Generate a programming joke about recursion in JSON format.',
  ),
  StructuredDemo(
    title: 'Recipe Extractor',
    description: 'Extract structured recipe information',
    schema: recipeSchema,
    samplePrompt:
        'Give me a recipe for chocolate chip cookies with a crispy texture. '
        'Output as JSON with name, description, ingredients, instructions, '
        'prepTimeMinutes, cookTimeMinutes, and servings.',
  ),
  StructuredDemo(
    title: 'Sentiment Analyzer',
    description: 'Analyze text sentiment with confidence scores',
    schema: sentimentSchema,
    samplePrompt:
        'Analyze the sentiment in JSON format: "I absolutely love this new '
        'feature, but the documentation could be better."',
  ),
];

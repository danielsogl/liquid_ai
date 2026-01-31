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
          items: const StringProperty(
            description: 'An ingredient with quantity',
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
    required this.schemaCode,
  });

  final String title;
  final String description;
  final JsonSchema schema;
  final String samplePrompt;
  final String schemaCode;
}

/// List of available demos.
final structuredDemos = [
  StructuredDemo(
    title: 'Joke Generator',
    description: 'Generate jokes with structured metadata',
    schema: jokeSchema,
    samplePrompt:
        'Generate a programming joke about recursion as JSON with setup, '
        'punchline, category, and rating fields.',
    schemaCode: '''JsonSchema.object('A joke with metadata')
    .addString('setup', 'The setup of the joke')
    .addString('punchline', 'The punchline')
    .addString('category', 'The category',
        enumValues: ['pun', 'dad-joke', 'programming', ...])
    .addInt('rating', 'Humor rating 1-10',
        minimum: 1, maximum: 10)
    .build()''',
  ),
  StructuredDemo(
    title: 'Recipe Extractor',
    description: 'Extract structured recipe information',
    schema: recipeSchema,
    samplePrompt:
        'Generate a JSON recipe for chocolate chip cookies with a crispy '
        'texture. Include name, description, ingredients list, instructions, '
        'prep time, cook time, and servings.',
    schemaCode: '''JsonSchema.object('A recipe')
    .addString('name', 'The dish name')
    .addString('description', 'Brief description')
    .addArray('ingredients', 'List of ingredients',
        items: StringProperty(...))
    .addArray('instructions', 'Cooking steps',
        items: StringProperty(...))
    .addInt('prepTimeMinutes', 'Prep time')
    .addInt('cookTimeMinutes', 'Cook time')
    .addInt('servings', 'Number of servings')
    .build()''',
  ),
  StructuredDemo(
    title: 'Sentiment Analyzer',
    description: 'Analyze text sentiment with confidence scores',
    schema: sentimentSchema,
    samplePrompt:
        'Analyze the sentiment of the following text and return JSON with '
        'sentiment, confidence, keywords, and explanation: "I absolutely '
        'love this new feature, but the documentation could be better."',
    schemaCode: '''JsonSchema.object('Sentiment analysis')
    .addString('sentiment', 'The sentiment',
        enumValues: ['positive', 'negative', 'neutral', 'mixed'])
    .addNumber('confidence', 'Score 0.0-1.0',
        minimum: 0.0, maximum: 1.0)
    .addArray('keywords', 'Key phrases',
        items: StringProperty(...))
    .addString('explanation', 'Analysis explanation')
    .build()''',
  ),
];

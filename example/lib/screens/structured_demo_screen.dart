import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_ai/liquid_ai.dart';
import 'package:provider/provider.dart';

import '../models/demo_schemas.dart';
import '../state/chat_state.dart';
import '../state/download_state.dart';

/// Demo screen for structured JSON output generation.
class StructuredDemoScreen extends StatefulWidget {
  const StructuredDemoScreen({super.key});

  @override
  State<StructuredDemoScreen> createState() => _StructuredDemoScreenState();
}

class _StructuredDemoScreenState extends State<StructuredDemoScreen> {
  int _selectedDemoIndex = 0;
  final _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedJson;
  String? _errorMessage;
  GenerationStats? _stats;
  int _tokenCount = 0;

  StructuredDemo get _currentDemo => structuredDemos[_selectedDemoIndex];

  @override
  void initState() {
    super.initState();
    _promptController.text = _currentDemo.samplePrompt;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _selectDemo(int index) {
    setState(() {
      _selectedDemoIndex = index;
      _promptController.text = structuredDemos[index].samplePrompt;
      _generatedJson = null;
      _errorMessage = null;
      _stats = null;
      _tokenCount = 0;
    });
  }

  Future<void> _generate() async {
    final chatState = context.read<ChatState>();

    if (!chatState.isReady) {
      setState(() {
        _errorMessage = 'Please select a model first';
      });
      return;
    }

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a prompt';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedJson = null;
      _errorMessage = null;
      _stats = null;
      _tokenCount = 0;
    });

    try {
      final runner = chatState.runner!;

      // Include schema in system prompt for better model alignment
      final schemaJson = _currentDemo.schema.toJsonString();
      final systemPrompt =
          '''You are a helpful assistant that always responds in valid JSON format.
Your response must exactly match this JSON schema:
$schemaJson

Important:
- Output ONLY the JSON object, no explanations or markdown
- Include ALL required fields
- Use the exact field names from the schema''';

      final conversation = await runner.createConversation(
        systemPrompt: systemPrompt,
      );

      final options = const GenerationOptions(
        temperature: 0.3,
        maxTokens: 1024,
      );

      // Use the new generateStructured method
      await for (final event in conversation.generateStructured(
        ChatMessage.user(prompt),
        schema: _currentDemo.schema,
        fromJson: (json) => json, // Return raw Map for demo display
        options: options,
      )) {
        switch (event) {
          case StructuredProgressEvent():
            // Update token count for progress indication
            setState(() {
              _tokenCount = event.tokenCount;
            });
          case StructuredCompleteEvent():
            setState(() {
              _generatedJson = event.rawJson;
              _stats = event.stats;
            });
          case StructuredErrorEvent():
            // Log error details to console for debugging
            debugPrint('=== Structured Generation Error ===');
            debugPrint('Error: ${event.error}');
            if (event.rawResponse != null) {
              debugPrint('Raw response: ${event.rawResponse}');
            }
            debugPrint('===================================');
            setState(() {
              _errorMessage = event.error;
              if (event.rawResponse != null) {
                _generatedJson = 'Raw response:\n${event.rawResponse}';
              }
            });
          case StructuredCancelledEvent():
            if (event.partialResponse != null) {
              setState(() {
                _generatedJson =
                    'Cancelled. Partial response:\n'
                    '${event.partialResponse}';
              });
            }
        }
      }

      await conversation.dispose();
    } catch (e) {
      final errorStr = e.toString();
      // Check if this is likely a hot reload issue (invalid runner)
      if (errorStr.contains('Invalid') ||
          errorStr.contains('disposed') ||
          errorStr.contains('null')) {
        chatState.reset();
        setState(() {
          _errorMessage = 'Model connection lost. Please select a model again.';
        });
      } else {
        setState(() {
          _errorMessage = errorStr;
        });
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_generatedJson != null) {
      Clipboard.setData(ClipboardData(text: _generatedJson!));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JSON copied to clipboard')));
    }
  }

  Future<void> _loadAndInitializeModel(
    LeapModel model,
    ChatState chatState,
    DownloadState downloadState,
  ) async {
    final modelState = downloadState.getModelState(model.slug);
    final quant = modelState.downloadedQuantization;

    if (quant == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No quantization available')),
        );
      }
      return;
    }

    final runner = await downloadState.loadModel(model.slug, quant.slug);

    if (runner != null) {
      await chatState.initialize(runner, model: model);
    } else if (mounted) {
      final error = downloadState.loadErrorMessage ?? 'Failed to load model';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Structured Output'),
        actions: [
          Consumer<ChatState>(
            builder: (context, chatState, _) {
              if (chatState.isReady) {
                return TextButton.icon(
                  onPressed: () => _showModelSwitcher(context),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(
                    chatState.selectedModel?.name ?? 'Model',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer2<DownloadState, ChatState>(
        builder: (context, downloadState, chatState, _) {
          final loadedModels = downloadState.models.where((model) {
            final state = downloadState.getModelState(model.slug);
            return state.status == ModelDownloadStatus.downloaded;
          }).toList();

          if (loadedModels.isEmpty) {
            return _buildNoModelsView();
          }

          // Show loading state while model is being loaded
          if (downloadState.isLoading) {
            return _buildLoadingView();
          }

          if (!chatState.isReady) {
            return _buildModelSelector(loadedModels, chatState, downloadState);
          }

          return Column(
            children: [
              _buildDemoSelector(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSchemaCard(),
                      const SizedBox(height: 16),
                      _buildPromptCard(chatState),
                      const SizedBox(height: 16),
                      if (_errorMessage != null) _buildErrorCard(),
                      if (_generatedJson != null) _buildResultCard(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoModelsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No models available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Download a model from the Models tab to start.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading model...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while the model is loaded into memory.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelector(
    List<LeapModel> loadedModels,
    ChatState chatState,
    DownloadState downloadState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.data_object,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a Model',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a model to generate structured JSON output.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: loadedModels.map((model) {
                return FilledButton.tonal(
                  onPressed: () =>
                      _loadAndInitializeModel(model, chatState, downloadState),
                  child: Text(model.name),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelSwitcher(BuildContext context) {
    final downloadState = context.read<DownloadState>();
    final chatState = context.read<ChatState>();
    final currentSlug = chatState.selectedModel?.slug;

    final loadedModels = downloadState.models.where((model) {
      final state = downloadState.getModelState(model.slug);
      return state.status == ModelDownloadStatus.downloaded;
    }).toList();

    if (loadedModels.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No models available')));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => _ModelSwitcherSheet(
        models: loadedModels,
        currentModelSlug: currentSlug,
        onModelSelected: (model) async {
          Navigator.pop(context);
          await _switchToModel(model, chatState, downloadState);
        },
      ),
    );
  }

  Future<void> _switchToModel(
    LeapModel model,
    ChatState chatState,
    DownloadState downloadState,
  ) async {
    final modelState = downloadState.getModelState(model.slug);
    final quant = modelState.downloadedQuantization;

    if (quant == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No quantization available')),
        );
      }
      return;
    }

    // Dispose old runner BEFORE loading new one to avoid having both models
    // in memory simultaneously, which can exceed memory limits
    await chatState.runner?.dispose();

    final runner = await downloadState.loadModel(model.slug, quant.slug);

    if (runner != null) {
      await chatState.switchModel(runner, model: model);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Switched to ${model.name}')));
      }
    } else if (mounted) {
      // Reset state since we disposed the old runner but failed to load new one
      chatState.reset();
      final error = downloadState.loadErrorMessage ?? 'Failed to load model';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _buildDemoSelector() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: structuredDemos.length,
        itemBuilder: (context, index) {
          final demo = structuredDemos[index];
          final isSelected = index == _selectedDemoIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: FilterChip(
              label: Text(demo.title),
              selected: isSelected,
              onSelected: (_) => _selectDemo(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSchemaCard() {
    // Format the JSON schema for display
    final schemaJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(_currentDemo.schema.toMap());

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          Icons.schema,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          'JSON Schema',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          _currentDemo.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: SelectableText(
              schemaJson,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard(ChatState chatState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Prompt', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter your prompt...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !_isGenerating,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isGenerating ? null : _generate,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isGenerating
                    ? 'Generating${_tokenCount > 0 ? ' ($_tokenCount tokens)' : '...'}'
                    : 'Generate',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  tooltip: 'Copy error',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _errorMessage!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error copied to clipboard'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.data_object,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Generated JSON',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard',
                  onPressed: _copyToClipboard,
                ),
              ],
            ),
            if (_stats != null) ...[
              const SizedBox(height: 4),
              _buildStatsRow(),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _generatedJson!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildParsedResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = _stats!;
    final items = <String>[];

    items.add('${stats.tokenCount} tokens');
    items.add('${stats.tokensPerSecond.toStringAsFixed(1)} tok/s');

    if (stats.generationTimeMs != null) {
      final seconds = stats.generationTimeMs! / 1000;
      items.add('${seconds.toStringAsFixed(2)}s');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        items.join(' \u00b7 '),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildParsedResult() {
    try {
      final parsed = jsonDecode(_generatedJson!) as Map<String, dynamic>;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Parsed Fields', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...parsed.entries.map((entry) => _buildFieldRow(entry)),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildFieldRow(MapEntry<String, dynamic> entry) {
    final value = entry.value;
    String displayValue;

    if (value is List) {
      displayValue = value.map((e) => e.toString()).join(', ');
    } else if (value is Map) {
      displayValue = jsonEncode(value);
    } else {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayValue,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelSwitcherSheet extends StatelessWidget {
  const _ModelSwitcherSheet({
    required this.models,
    required this.currentModelSlug,
    required this.onModelSelected,
  });

  final List<LeapModel> models;
  final String? currentModelSlug;
  final void Function(LeapModel model) onModelSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Text(
              'Switch Model',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: models.length,
              itemBuilder: (context, index) {
                final model = models[index];
                final isSelected = model.slug == currentModelSlug;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.smart_toy,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(model.name),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: isSelected ? null : () => onModelSelected(model),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

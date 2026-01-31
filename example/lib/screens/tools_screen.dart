import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:liquid_ai/liquid_ai.dart';
import 'package:provider/provider.dart';

import '../state/download_state.dart';
import '../state/tools_state.dart';

/// Tools demo screen for demonstrating function calling.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<ToolsState>(
          builder: (context, toolsState, _) {
            final modelName = toolsState.selectedModel?.name;
            if (modelName != null) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.build, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Tools - $modelName',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }
            return const Text('Tools Demo');
          },
        ),
        actions: [
          Consumer<ToolsState>(
            builder: (context, toolsState, _) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'functions':
                      _showFunctionsSheet(context, toolsState);
                    case 'clear':
                      toolsState.clearConversation();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'functions',
                    child: ListTile(
                      leading: Icon(Icons.functions),
                      title: Text('View Functions'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Clear'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer2<DownloadState, ToolsState>(
        builder: (context, downloadState, toolsState, _) {
          // Check for available runners
          final loadedModels = downloadState.models.where((model) {
            final state = downloadState.getModelState(model.slug);
            return state.status == ModelDownloadStatus.downloaded;
          }).toList();

          if (loadedModels.isEmpty) {
            return _buildNoModelsView();
          }

          if (!toolsState.isReady) {
            return _buildModelSelector(loadedModels, toolsState);
          }

          return Column(
            children: [
              Expanded(
                child: toolsState.messages.isEmpty
                    ? _buildEmptyChat(toolsState)
                    : _buildMessageList(toolsState),
              ),
              _buildInputArea(toolsState),
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
              'Download a model from the Models tab to try tool calling.',
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
    ToolsState toolsState,
  ) {
    final downloadState = context.watch<DownloadState>();
    final isLoading = downloadState.isLoading;

    if (isLoading) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.build_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Tools Demo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Select a model to try function calling with tools.',
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
                      _loadAndInitializeModel(model, toolsState, downloadState),
                  child: Text(model.name),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAndInitializeModel(
    LeapModel model,
    ToolsState toolsState,
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
      await toolsState.initialize(runner, model: model);
    } else if (mounted) {
      final error = downloadState.loadErrorMessage ?? 'Failed to load model';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _buildEmptyChat(ToolsState toolsState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Try the tools!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask about the weather or request a calculation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Example prompts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _ExampleChip(
                  label: "What's the weather in New York?",
                  onTap: () =>
                      _textController.text = "What's the weather in New York?",
                ),
                _ExampleChip(
                  label: 'Calculate 2 + 2',
                  onTap: () => _textController.text = 'Calculate 2 + 2',
                ),
                _ExampleChip(
                  label: 'What is sqrt(144)?',
                  onTap: () => _textController.text = 'What is sqrt(144)?',
                ),
                _ExampleChip(
                  label: 'Weather in London in Fahrenheit',
                  onTap: () => _textController.text =
                      'What is the weather in London? Use Fahrenheit.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ToolsState toolsState) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: toolsState.messages.length,
      itemBuilder: (context, index) {
        final message = toolsState.messages[index];
        return _ToolsMessageBubble(
          message: message,
          isLast: index == toolsState.messages.length - 1,
        );
      },
    );
  }

  Widget _buildInputArea(ToolsState toolsState) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  enabled: !toolsState.isGenerating,
                  decoration: InputDecoration(
                    hintText: 'Ask about weather or calculations...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty && !toolsState.isGenerating) {
                      _sendMessage(toolsState);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (toolsState.isGenerating)
                IconButton.filled(
                  onPressed: toolsState.stopGeneration,
                  icon: const Icon(Icons.stop),
                  tooltip: 'Stop generation',
                )
              else
                IconButton.filled(
                  onPressed: _textController.text.trim().isNotEmpty
                      ? () => _sendMessage(toolsState)
                      : null,
                  icon: const Icon(Icons.send),
                  tooltip: 'Send message',
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage(ToolsState toolsState) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    toolsState.sendMessage(text);
    _textController.clear();
    _focusNode.requestFocus();
  }

  void _showFunctionsSheet(BuildContext context, ToolsState toolsState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registered Functions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'These tools are available to the model:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: toolsState.registeredFunctions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final function = toolsState.registeredFunctions[index];
                      return _FunctionCard(function: function);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _FunctionCard extends StatelessWidget {
  const _FunctionCard({required this.function});

  final LeapFunction function;

  @override
  Widget build(BuildContext context) {
    final params = function.parameters['properties'] as Map<String, dynamic>?;
    final required = function.parameters['required'] as List<dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.functions,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  function.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              function.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (params != null && params.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Parameters:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              ...params.entries.map((entry) {
                final paramName = entry.key;
                final paramInfo = entry.value as Map<String, dynamic>;
                final isRequired = required?.contains(paramName) ?? false;

                return Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$paramName${isRequired ? '*' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        ' (${paramInfo['type']}): ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          paramInfo['description'] as String? ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolsMessageBubble extends StatelessWidget {
  const _ToolsMessageBubble({required this.message, this.isLast = false});

  final ToolsMessageUI message;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case ToolsMessageType.user:
        return _buildUserMessage(context);
      case ToolsMessageType.assistant:
        return _buildAssistantMessage(context);
      case ToolsMessageType.functionCall:
        return _buildFunctionCallMessage(context);
      case ToolsMessageType.functionResult:
        return _buildFunctionResultMessage(context);
    }
  }

  Widget _buildUserMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: SelectableText(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(
              Icons.person,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantMessage(BuildContext context) {
    if (message.isStreaming && message.content.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const _TypingIndicator(),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (message.stats != null && !message.isStreaming) ...[
                    const SizedBox(height: 8),
                    _StatsView(stats: message.stats!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCallMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.tertiary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.call_made,
              size: 20,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calling ${message.functionName}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (message.functionArguments != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      const JsonEncoder.withIndent(
                        '  ',
                      ).convert(message.functionArguments),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionResultMessage(BuildContext context) {
    Map<String, dynamic>? parsedResult;
    try {
      parsedResult = json.decode(message.content) as Map<String, dynamic>;
    } catch (_) {
      // Not valid JSON, display as-is
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.call_received,
              size: 20,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${message.functionName} result',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    parsedResult != null
                        ? const JsonEncoder.withIndent(
                            '  ',
                          ).convert(parsedResult)
                        : message.content,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.stats});

  final GenerationStats stats;

  @override
  Widget build(BuildContext context) {
    final items = <String>[];

    items.add('${stats.tokenCount} tokens');
    items.add('${stats.tokensPerSecond.toStringAsFixed(1)} tok/s');

    if (stats.promptTokenCount != null) {
      items.add('${stats.promptTokenCount} prompt');
    }

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
        items.join(' · '),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final opacity = (1 - ((_controller.value - delay) % 1.0).abs() * 2)
                .clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

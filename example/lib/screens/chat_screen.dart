import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_ai/liquid_ai.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../state/download_state.dart';

/// Chat screen for interacting with a loaded model.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

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

  Future<void> _exportConversation(ChatState chatState) async {
    final json = await chatState.exportConversation();
    if (json != null && mounted) {
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation copied to clipboard')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          Consumer<ChatState>(
            builder: (context, chatState, _) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'settings':
                      _showSettingsSheet(context, chatState);
                    case 'export':
                      _exportConversation(chatState);
                    case 'clear':
                      chatState.clearConversation();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.tune),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.file_download),
                      title: Text('Export'),
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
      body: Consumer2<DownloadState, ChatState>(
        builder: (context, downloadState, chatState, _) {
          // Check for available runners
          final loadedModels = downloadState.models.where((model) {
            final state = downloadState.getModelState(model.slug);
            return state.status == ModelDownloadStatus.downloaded;
          }).toList();

          if (loadedModels.isEmpty) {
            return _buildNoModelsView();
          }

          if (!chatState.isReady) {
            return _buildModelSelector(loadedModels, chatState);
          }

          return Column(
            children: [
              Expanded(
                child: chatState.messages.isEmpty
                    ? _buildEmptyChat()
                    : _buildMessageList(chatState),
              ),
              _buildInputArea(chatState),
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
              'Download a model from the Models tab to start chatting.',
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

  Widget _buildModelSelector(List<dynamic> loadedModels, ChatState chatState) {
    final downloadState = context.watch<DownloadState>();
    final isLoading = downloadState.isLoading;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
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
            ] else ...[
              Icon(
                Icons.smart_toy_outlined,
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
                'Choose a downloaded model to start a conversation.',
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
                    onPressed: () => _loadAndInitializeModel(
                      model,
                      chatState,
                      downloadState,
                    ),
                    child: Text(model.name),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadAndInitializeModel(
    dynamic model,
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
      await chatState.initialize(runner);
    } else if (mounted) {
      final error = downloadState.loadErrorMessage ?? 'Failed to load model';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Type a message below to begin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        return _MessageBubble(
          message: message,
          isLast: index == chatState.messages.length - 1,
        );
      },
    );
  }

  Widget _buildInputArea(ChatState chatState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
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
                enabled: !chatState.isGenerating,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty && !chatState.isGenerating) {
                    _sendMessage(chatState);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            if (chatState.isGenerating)
              IconButton.filled(
                onPressed: chatState.stopGeneration,
                icon: const Icon(Icons.stop),
                tooltip: 'Stop generation',
              )
            else
              IconButton.filled(
                onPressed: _textController.text.trim().isEmpty
                    ? null
                    : () => _sendMessage(chatState),
                icon: const Icon(Icons.send),
                tooltip: 'Send message',
              ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ChatState chatState) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    chatState.sendMessage(text);
    _textController.clear();
    _focusNode.requestFocus();
  }

  void _showSettingsSheet(BuildContext context, ChatState chatState) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SettingsSheet(chatState: chatState),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.isLast = false});

  final ChatMessageUI message;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
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
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: message.isStreaming && message.content.isEmpty
                  ? const _TypingIndicator()
                  : SelectableText(
                      message.content,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          if (isUser) ...[
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
        ],
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

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.chatState});

  final ChatState chatState;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late double _temperature;
  late double _topP;
  late int _maxTokens;

  @override
  void initState() {
    super.initState();
    _temperature = widget.chatState.options.temperature ?? 0.7;
    _topP = widget.chatState.options.topP ?? 0.9;
    _maxTokens = widget.chatState.options.maxTokens ?? 1024;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generation Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          _SliderSetting(
            label: 'Temperature',
            value: _temperature,
            min: 0.0,
            max: 2.0,
            divisions: 20,
            onChanged: (value) => setState(() => _temperature = value),
          ),
          const SizedBox(height: 16),
          _SliderSetting(
            label: 'Top P',
            value: _topP,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (value) => setState(() => _topP = value),
          ),
          const SizedBox(height: 16),
          _SliderSetting(
            label: 'Max Tokens',
            value: _maxTokens.toDouble(),
            min: 64,
            max: 4096,
            divisions: 63,
            onChanged: (value) => setState(() => _maxTokens = value.toInt()),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  widget.chatState.updateOptions(
                    GenerationOptions(
                      temperature: _temperature,
                      topP: _topP,
                      maxTokens: _maxTokens,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              value == value.roundToDouble()
                  ? value.toInt().toString()
                  : value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

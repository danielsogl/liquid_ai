import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_ai/liquid_ai.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../state/download_state.dart';
import '../widgets/media_content.dart';
import '../widgets/media_picker.dart';

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

  // Pending media attachments
  Uint8List? _pendingImage;
  Uint8List? _pendingAudio;

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

  bool get _hasContent =>
      _textController.text.trim().isNotEmpty ||
      _pendingImage != null ||
      _pendingAudio != null;

  String _getHintText(ChatState chatState) {
    final supportsImage = chatState.supportsImage;
    final supportsAudio = chatState.supportsAudio;

    if (supportsImage && supportsAudio) {
      return 'Type a message, attach an image, or record audio...';
    } else if (supportsImage) {
      return 'Type a message or attach an image...';
    } else if (supportsAudio) {
      return 'Type a message or record audio...';
    }
    return 'Type a message...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<ChatState>(
          builder: (context, chatState, _) {
            final modelName = chatState.selectedModel?.name;
            if (modelName != null) {
              return InkWell(
                onTap: () => _showModelSwitcher(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(modelName, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.swap_horiz, size: 18),
                    ],
                  ),
                ),
              );
            }
            return const Text('Chat');
          },
        ),
        actions: [
          Consumer<ChatState>(
            builder: (context, chatState, _) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'switch_model':
                      _showModelSwitcher(context);
                    case 'settings':
                      _showSettingsSheet(context, chatState);
                    case 'export':
                      _exportConversation(chatState);
                    case 'clear':
                      chatState.clearConversation();
                  }
                },
                itemBuilder: (context) => [
                  if (chatState.isReady)
                    const PopupMenuItem(
                      value: 'switch_model',
                      child: ListTile(
                        leading: Icon(Icons.swap_horiz),
                        title: Text('Switch Model'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
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

  Widget _buildModelSelector(
    List<LeapModel> loadedModels,
    ChatState chatState,
  ) {
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Media preview area
            if (_pendingImage != null || _pendingAudio != null)
              _buildMediaPreview(),
            // Input row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Image picker button (only if model supports images)
                  if (chatState.supportsImage)
                    ImagePickerButton(
                      enabled: !chatState.isGenerating && _pendingImage == null,
                      onImagePicked: (bytes) {
                        setState(() => _pendingImage = bytes);
                      },
                    ),
                  // Audio recorder button (only if model supports audio)
                  if (chatState.supportsAudio)
                    AudioRecorderButton(
                      enabled: !chatState.isGenerating && _pendingAudio == null,
                      onAudioRecorded: (bytes) {
                        setState(() => _pendingAudio = bytes);
                      },
                    ),
                  if (chatState.supportsImage || chatState.supportsAudio)
                    const SizedBox(width: 8),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      enabled: !chatState.isGenerating,
                      decoration: InputDecoration(
                        hintText: _getHintText(chatState),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (text) {
                        if (_hasContent && !chatState.isGenerating) {
                          _sendMessage(chatState);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send/stop button
                  if (chatState.isGenerating)
                    IconButton.filled(
                      onPressed: chatState.stopGeneration,
                      icon: const Icon(Icons.stop),
                      tooltip: 'Stop generation',
                    )
                  else
                    IconButton.filled(
                      onPressed: _hasContent
                          ? () => _sendMessage(chatState)
                          : null,
                      icon: const Icon(Icons.send),
                      tooltip: 'Send message',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_pendingImage != null)
            _MediaPreviewChip(
              icon: Icons.image,
              label: 'Image',
              onRemove: () => setState(() => _pendingImage = null),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  _pendingImage!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (_pendingAudio != null)
            _MediaPreviewChip(
              icon: Icons.mic,
              label: 'Audio',
              onRemove: () => setState(() => _pendingAudio = null),
            ),
        ],
      ),
    );
  }

  void _sendMessage(ChatState chatState) {
    final text = _textController.text.trim();

    chatState.sendMessageWithMedia(
      text: text.isNotEmpty ? text : null,
      image: _pendingImage,
      audio: _pendingAudio,
    );

    _textController.clear();
    setState(() {
      _pendingImage = null;
      _pendingAudio = null;
    });
    _focusNode.requestFocus();
  }

  void _showSettingsSheet(BuildContext context, ChatState chatState) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SettingsSheet(chatState: chatState),
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
      isScrollControlled: true,
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

    final runner = await downloadState.loadModel(model.slug, quant.slug);

    if (runner != null) {
      await chatState.switchModel(runner, model: model);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Switched to ${model.name}')));
      }
    } else if (mounted) {
      final error = downloadState.loadErrorMessage ?? 'Failed to load model';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _MediaPreviewChip extends StatelessWidget {
  const _MediaPreviewChip({
    required this.icon,
    required this.label,
    required this.onRemove,
    this.child,
  });

  final IconData icon;
  final String label;
  final VoidCallback onRemove;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (child != null) child! else Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.close,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
              child: _buildContent(context, isUser),
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

  Widget _buildContent(BuildContext context, bool isUser) {
    if (message.isStreaming && message.content.isEmpty) {
      return const _TypingIndicator();
    }

    final contentWidgets = <Widget>[];

    // Add images
    for (final imageContent in message.images) {
      contentWidgets.add(
        Padding(
          padding: contentWidgets.isEmpty
              ? EdgeInsets.zero
              : const EdgeInsets.only(top: 8),
          child: ImageContentView(content: imageContent),
        ),
      );
    }

    // Add audio
    for (final audioContent in message.audio) {
      contentWidgets.add(
        Padding(
          padding: contentWidgets.isEmpty
              ? EdgeInsets.zero
              : const EdgeInsets.only(top: 8),
          child: AudioContentView(content: audioContent),
        ),
      );
    }

    // Add text
    final text = message.text;
    if (text != null && text.isNotEmpty) {
      contentWidgets.add(
        Padding(
          padding: contentWidgets.isEmpty
              ? EdgeInsets.zero
              : const EdgeInsets.only(top: 8),
          child: SelectableText(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isUser
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Add stats for assistant messages
    if (!isUser && message.stats != null && !message.isStreaming) {
      contentWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _StatsView(stats: message.stats!),
        ),
      );
    }

    if (contentWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    if (contentWidgets.length == 1) {
      return contentWidgets.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: contentWidgets,
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.stats});

  final GenerationStats stats;

  @override
  Widget build(BuildContext context) {
    final items = <String>[];

    // Tokens generated
    items.add('${stats.tokenCount} tokens');

    // Tokens per second
    items.add('${stats.tokensPerSecond.toStringAsFixed(1)} tok/s');

    // Prompt tokens if available
    if (stats.promptTokenCount != null) {
      items.add('${stats.promptTokenCount} prompt');
    }

    // Generation time if available
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

class _ModelSwitcherSheet extends StatelessWidget {
  const _ModelSwitcherSheet({
    required this.models,
    required this.currentModelSlug,
    required this.onModelSelected,
  });

  final List<LeapModel> models;
  final String? currentModelSlug;
  final void Function(LeapModel model) onModelSelected;

  IconData _getModalityIcon(LeapModel model) {
    if (model.supportsImage) return Icons.image;
    if (model.supportsAudio) return Icons.mic;
    return Icons.text_fields;
  }

  String _getModalityLabel(LeapModel model) {
    final modalities = <String>[];
    if (model.supportsText) modalities.add('Text');
    if (model.supportsImage) modalities.add('Vision');
    if (model.supportsAudio) modalities.add('Audio');
    return modalities.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Switch Model',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Message history will be preserved, but the new model '
                  'won\'t have previous context.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final isSelected = model.slug == currentModelSlug;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          _getModalityIcon(model),
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(model.name),
                      subtitle: Text(_getModalityLabel(model)),
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
      },
    );
  }
}

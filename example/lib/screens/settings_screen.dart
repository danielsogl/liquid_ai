import 'package:flutter/material.dart';
import 'package:liquid_ai/liquid_ai.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../state/download_state.dart';
import '../state/tools_state.dart';

/// Screen displaying app settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'About'),
          const _AboutTile(),
          const Divider(),
          const _SectionHeader(title: 'Storage'),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Clear all models'),
            subtitle: const Text('Delete all downloaded models'),
            onTap: () => _showClearDialog(context),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All Models'),
        content: const Text(
          'Are you sure you want to delete all downloaded models? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _clearAllModels(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllModels(BuildContext context) async {
    final downloadState = context.read<DownloadState>();
    final chatState = context.read<ChatState>();
    final toolsState = context.read<ToolsState>();

    // Reset chat and tools state first
    chatState.reset();
    toolsState.reset();

    // Unload any currently loaded model
    await ModelManager.instance.unloadCurrentModel();

    // Delete all downloaded models
    var deletedCount = 0;
    for (final model in downloadState.models) {
      final modelState = downloadState.getModelState(model.slug);
      if (modelState.status == ModelDownloadStatus.downloaded) {
        await downloadState.deleteModel(model);
        deletedCount++;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount > 0
                ? 'Deleted $deletedCount model${deletedCount == 1 ? '' : 's'}'
                : 'No models to delete',
          ),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _AboutTile extends StatefulWidget {
  const _AboutTile();

  @override
  State<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends State<_AboutTile> {
  static final _liquidAi = LiquidAi();
  Future<String?>? _platformVersion;

  @override
  void initState() {
    super.initState();
    _platformVersion = _liquidAi.getPlatformVersion();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _platformVersion,
      builder: (context, snapshot) {
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Liquid AI Example'),
          subtitle: Text(
            snapshot.hasData ? 'Platform: ${snapshot.data}' : 'Loading...',
          ),
        );
      },
    );
  }
}

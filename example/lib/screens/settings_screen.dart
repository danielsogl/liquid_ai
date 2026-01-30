import 'package:flutter/material.dart';
import 'package:liquid_ai/liquid_ai.dart';

/// Screen displaying app settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'About'),
          _AboutTile(),
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
      builder: (context) => AlertDialog(
        title: const Text('Clear All Models'),
        content: const Text(
          'Are you sure you want to delete all downloaded models? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Models cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
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

class _AboutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: LiquidAi().getPlatformVersion(),
      builder: (context, snapshot) {
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Liquid AI Example'),
          subtitle: Text(
            snapshot.hasData
                ? 'Platform: ${snapshot.data}'
                : 'Loading...',
          ),
        );
      },
    );
  }
}

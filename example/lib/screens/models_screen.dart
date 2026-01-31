import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/download_state.dart';
import '../widgets/model_list_item.dart';

/// Screen displaying available models and download controls.
class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'About models',
          ),
        ],
      ),
      body: Consumer<DownloadState>(
        builder: (context, state, child) {
          final models = state.models;

          if (models.isEmpty) {
            return const Center(child: Text('No models available'));
          }

          return RefreshIndicator(
            onRefresh: () => state.initialize(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: models.length,
              itemBuilder: (context, index) {
                return ModelListItem(model: models[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: _DownloadAllFab(),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Models'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Liquid AI provides a variety of models optimized for '
                'on-device inference. Each model is available in multiple '
                'quantizations to balance quality and size.',
              ),
              SizedBox(height: 16),
              Text(
                'Quantization Options:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Q4_0: Smallest size, fastest inference'),
              Text('• Q4_K_M: Good balance (recommended)'),
              Text('• Q5_K_M: Better quality, larger size'),
              Text('• Q8_0: Best quality, largest size'),
              SizedBox(height: 16),
              Text(
                'Tap on a model card to see more details and '
                'all available quantization options.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _DownloadAllFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadState>(
      builder: (context, state, child) {
        final hasUndownloaded = state.models.any((model) {
          final modelState = state.getModelState(model.slug);
          return modelState.status != ModelDownloadStatus.downloaded;
        });

        if (!hasUndownloaded) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: state.isAnyDownloading ? null : state.downloadAllModels,
          icon: state.isDownloadingAll
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download),
          label: Text(
            state.isDownloadingAll ? 'Downloading...' : 'Download All',
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:liquid_ai/liquid_ai.dart';

import '../state/download_state.dart';

/// A view for selecting a model to load.
class ModelSelectorView extends StatelessWidget {
  const ModelSelectorView({
    super.key,
    required this.models,
    required this.onModelSelected,
    required this.icon,
    required this.title,
    required this.description,
  });

  final List<LeapModel> models;
  final Future<void> Function(LeapModel model) onModelSelected;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
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
              children: models.map((model) {
                return FilledButton.tonal(
                  onPressed: () => onModelSelected(model),
                  child: Text(model.name),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bottom sheet for switching between loaded models.
class ModelSwitcherSheet extends StatelessWidget {
  const ModelSwitcherSheet({
    super.key,
    required this.models,
    required this.currentModelSlug,
    required this.onModelSelected,
    this.showModalityInfo = false,
  });

  final List<LeapModel> models;
  final String? currentModelSlug;
  final void Function(LeapModel model) onModelSelected;
  final bool showModalityInfo;

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
    if (showModalityInfo) {
      return _buildFullSheet(context);
    }
    return _buildSimpleSheet(context);
  }

  Widget _buildSimpleSheet(BuildContext context) {
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

  Widget _buildFullSheet(BuildContext context) {
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
                  "won't have previous context.",
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

/// Helper to load and initialize a model.
///
/// Returns the runner if successful, null otherwise.
Future<ModelRunner?> loadAndInitializeModel({
  required BuildContext context,
  required LeapModel model,
  required DownloadState downloadState,
}) async {
  final modelState = downloadState.getModelState(model.slug);
  final quant = modelState.downloadedQuantization;

  if (quant == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quantization available')),
      );
    }
    return null;
  }

  final runner = await downloadState.loadModel(model.slug, quant.slug);

  if (runner == null && context.mounted) {
    final error = downloadState.loadErrorMessage ?? 'Failed to load model';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  return runner;
}

/// Gets the list of downloaded models.
List<LeapModel> getDownloadedModels(DownloadState downloadState) {
  return downloadState.models.where((model) {
    final state = downloadState.getModelState(model.slug);
    return state.status == ModelDownloadStatus.downloaded;
  }).toList();
}

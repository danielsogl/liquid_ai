import 'package:flutter/material.dart';
import 'package:liquid_ai/liquid_ai.dart';
import 'package:provider/provider.dart';

import '../state/download_state.dart';

/// List item displaying a model with download controls.
class ModelListItem extends StatelessWidget {
  const ModelListItem({super.key, required this.model});

  final LeapModel model;

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadState>(
      builder: (context, state, child) {
        final modelState = state.getModelState(model.slug);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () => _showModelDetails(context, state, modelState),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, modelState),
                  const SizedBox(height: 8),
                  _buildDescription(context),
                  const SizedBox(height: 8),
                  _buildChips(context, modelState),
                  if (modelState.status == ModelDownloadStatus.downloading) ...[
                    const SizedBox(height: 12),
                    _buildProgressIndicator(context, modelState),
                  ],
                  if (modelState.status == ModelDownloadStatus.error) ...[
                    const SizedBox(height: 8),
                    _buildErrorMessage(context, modelState),
                  ],
                  const SizedBox(height: 12),
                  _buildActionButtons(context, state, modelState),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ModelState modelState) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    model.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (model.isDeprecated) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Deprecated',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${model.parameters} parameters',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _buildStatusIcon(context, modelState),
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Text(
      model.description,
      style: Theme.of(context).textTheme.bodyMedium,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildChips(BuildContext context, ModelState modelState) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildChip(context, model.taskDescription, Icons.category),
        if (modelState.downloadedQuantization != null)
          _buildChip(
            context,
            modelState.downloadedQuantization!.slug,
            Icons.memory,
            isPrimary: true,
          ),
        if (model.contextLength != null)
          _buildChip(
            context,
            '${model.contextLength} tokens',
            Icons.straighten,
          ),
        if (model.languages != null)
          _buildChip(
            context,
            model.languages!.join(', ').toUpperCase(),
            Icons.translate,
          ),
      ],
    );
  }

  Widget _buildChip(
    BuildContext context,
    String label,
    IconData icon, {
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isPrimary
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isPrimary
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isPrimary ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, ModelState modelState) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: modelState.progress,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(modelState.progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _formatSpeed(modelState.speed),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context, ModelState modelState) {
    return Text(
      modelState.errorMessage ?? 'Download failed',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, ModelState modelState) {
    switch (modelState.status) {
      case ModelDownloadStatus.downloaded:
        return Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
        );
      case ModelDownloadStatus.downloading:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: modelState.progress,
          ),
        );
      case ModelDownloadStatus.error:
        return Icon(Icons.error, color: Theme.of(context).colorScheme.error);
      case ModelDownloadStatus.notDownloaded:
        return Icon(
          Icons.cloud_download_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    }
  }

  Widget _buildActionButtons(
    BuildContext context,
    DownloadState state,
    ModelState modelState,
  ) {
    switch (modelState.status) {
      case ModelDownloadStatus.notDownloaded:
      case ModelDownloadStatus.error:
        return Row(
          children: [
            FilledButton.icon(
              onPressed: () => state.downloadModel(model),
              icon: const Icon(Icons.download),
              label: Text('Download (${model.defaultQuantization.slug})'),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: () =>
                  _showQuantizationPicker(context, state, modelState),
              icon: const Icon(Icons.tune),
              tooltip: 'Choose quantization',
            ),
          ],
        );
      case ModelDownloadStatus.downloading:
        return OutlinedButton.icon(
          onPressed: () => state.cancelDownload(model),
          icon: const Icon(Icons.cancel),
          label: const Text('Cancel'),
        );
      case ModelDownloadStatus.downloaded:
        return Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _showDeleteDialog(context, state),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _showQuantizationPicker(context, state, modelState),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch'),
            ),
          ],
        );
    }
  }

  void _showQuantizationPicker(
    BuildContext context,
    DownloadState state,
    ModelState modelState,
  ) {
    final downloadedQuant = modelState.downloadedQuantization;
    final isDownloaded = modelState.status == ModelDownloadStatus.downloaded;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDownloaded
                        ? 'Switch Quantization'
                        : 'Select Quantization',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (isDownloaded) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Currently downloaded: ${downloadedQuant?.slug ?? "None"}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ...model.quantizations.map((q) {
              final isDefault = q == model.defaultQuantization;
              final isCurrentlyDownloaded = downloadedQuant?.slug == q.slug;

              return ListTile(
                leading: Icon(
                  isCurrentlyDownloaded
                      ? Icons.check_circle
                      : (isDefault ? Icons.star : Icons.memory),
                  color: isCurrentlyDownloaded
                      ? Theme.of(context).colorScheme.primary
                      : (isDefault
                            ? Theme.of(context).colorScheme.secondary
                            : null),
                ),
                title: Text(
                  q.slug,
                  style: TextStyle(
                    fontWeight: isCurrentlyDownloaded ? FontWeight.bold : null,
                  ),
                ),
                subtitle: Text(_getQuantizationDescription(q.quantization)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDefault)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          'Recommended',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    if (isCurrentlyDownloaded)
                      const Icon(Icons.download_done, size: 20),
                  ],
                ),
                onTap: isCurrentlyDownloaded
                    ? null
                    : () {
                        Navigator.pop(context);
                        if (isDownloaded) {
                          _showSwitchConfirmationDialog(
                            context,
                            state,
                            downloadedQuant!,
                            q,
                          );
                        } else {
                          state.downloadModelWithQuantization(model, q);
                        }
                      },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSwitchConfirmationDialog(
    BuildContext context,
    DownloadState state,
    QuantizationInfo currentQuant,
    QuantizationInfo newQuant,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Quantization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will delete the current ${currentQuant.slug} model and '
              'download ${newQuant.slug} instead.',
            ),
            const SizedBox(height: 16),
            _buildComparisonRow(
              context,
              'Current',
              currentQuant.slug,
              _getQuantizationDescription(currentQuant.quantization),
            ),
            const SizedBox(height: 8),
            const Icon(Icons.arrow_downward),
            const SizedBox(height: 8),
            _buildComparisonRow(
              context,
              'New',
              newQuant.slug,
              _getQuantizationDescription(newQuant.quantization),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              state.switchQuantization(model, newQuant);
            },
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    BuildContext context,
    String label,
    String quant,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quant, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getQuantizationDescription(ModelQuantization q) {
    return switch (q) {
      ModelQuantization.q4_0 => 'Smallest size, fastest inference',
      ModelQuantization.q4KM => 'Good balance of size and quality',
      ModelQuantization.q5KM => 'Better quality, larger size',
      ModelQuantization.q8_0 => 'Best quality, largest size',
    };
  }

  void _showDeleteDialog(BuildContext context, DownloadState state) {
    final modelState = state.getModelState(model.slug);
    final quant = modelState.downloadedQuantization;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text(
          'Are you sure you want to delete ${model.name}'
          '${quant != null ? ' (${quant.slug})' : ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              state.deleteModel(model);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showModelDetails(
    BuildContext context,
    DownloadState state,
    ModelState modelState,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer<DownloadState>(
        builder: (context, state, child) {
          final currentState = state.getModelState(model.slug);
          final downloadedQuant = currentState.downloadedQuantization;
          final isDownloading =
              currentState.status == ModelDownloadStatus.downloading;

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      model.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (model.isDeprecated) ...[
                      const SizedBox(height: 8),
                      Chip(
                        label: const Text('Deprecated'),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildDetailRow(context, 'Parameters', model.parameters),
                    _buildDetailRow(context, 'Task', model.taskDescription),
                    if (model.contextLength != null)
                      _buildDetailRow(
                        context,
                        'Context Length',
                        '${model.contextLength} tokens',
                      ),
                    if (model.languages != null)
                      _buildDetailRow(
                        context,
                        'Languages',
                        model.languages!.join(', ').toUpperCase(),
                      ),
                    if (model.updatedAt != null)
                      _buildDetailRow(context, 'Updated', model.updatedAt!),
                    if (downloadedQuant != null)
                      _buildDetailRow(
                        context,
                        'Downloaded',
                        downloadedQuant.slug,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(model.description),
                    const SizedBox(height: 24),
                    Text(
                      'Quantization Options',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      downloadedQuant != null
                          ? 'Tap another quantization to switch.'
                          : 'Tap a quantization to download.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...model.quantizations.map((q) {
                      final isDefault = q == model.defaultQuantization;
                      final isCurrentlyDownloaded =
                          downloadedQuant?.slug == q.slug;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isCurrentlyDownloaded
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: isDownloading || isCurrentlyDownloaded
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    if (downloadedQuant != null) {
                                      _showSwitchConfirmationDialog(
                                        context,
                                        state,
                                        downloadedQuant,
                                        q,
                                      );
                                    } else {
                                      state.downloadModelWithQuantization(
                                        model,
                                        q,
                                      );
                                    }
                                  },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    isCurrentlyDownloaded
                                        ? Icons.check_circle
                                        : Icons.memory,
                                    color: isCurrentlyDownloaded
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              q.slug,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight:
                                                        isCurrentlyDownloaded
                                                        ? FontWeight.bold
                                                        : null,
                                                  ),
                                            ),
                                            if (isDefault) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.star,
                                                size: 16,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          _getQuantizationDescription(
                                            q.quantization,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCurrentlyDownloaded)
                                    Text(
                                      'Downloaded',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    )
                                  else if (!isDownloading)
                                    Icon(
                                      downloadedQuant != null
                                          ? Icons.swap_horiz
                                          : Icons.download,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '$bytesPerSecond B/s';
  }
}

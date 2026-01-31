import 'package:flutter/material.dart';
import 'package:liquid_ai/liquid_ai.dart';
import 'package:provider/provider.dart';

import '../state/download_state.dart';
import '../widgets/model_list_item.dart';

/// Filter options for download status.
enum DownloadFilter { all, downloaded, notDownloaded }

/// Screen displaying available models and download controls.
class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedSize;
  ModelTask? _selectedTask;
  DownloadFilter _downloadFilter = DownloadFilter.all;

  /// Available parameter sizes from the catalog.
  List<String> get _availableSizes {
    final sizes = <String>{};
    for (final model in ModelCatalog.available) {
      sizes.add(model.parameters);
    }
    // Sort by size (numeric extraction)
    final sorted = sizes.toList()
      ..sort((a, b) {
        final aNum = _extractNumber(a);
        final bNum = _extractNumber(b);
        return aNum.compareTo(bNum);
      });
    return sorted;
  }

  /// Available task types from the catalog.
  List<ModelTask> get _availableTasks {
    final tasks = <ModelTask>{};
    for (final model in ModelCatalog.available) {
      tasks.add(model.task);
    }
    return tasks.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  double _extractNumber(String size) {
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(size);
    if (match == null) return 0;
    final num = double.parse(match.group(1)!);
    if (size.contains('B')) return num * 1000;
    return num;
  }

  List<LeapModel> _filterModels(List<LeapModel> models, DownloadState state) {
    return models.where((model) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = model.name.toLowerCase().contains(query);
        final matchesSlug = model.slug.toLowerCase().contains(query);
        final matchesDesc = model.description.toLowerCase().contains(query);
        if (!matchesName && !matchesSlug && !matchesDesc) return false;
      }

      // Size filter
      if (_selectedSize != null && model.parameters != _selectedSize) {
        return false;
      }

      // Task filter
      if (_selectedTask != null && model.task != _selectedTask) {
        return false;
      }

      // Download status filter
      if (_downloadFilter != DownloadFilter.all) {
        final modelState = state.getModelState(model.slug);
        final isDownloaded =
            modelState.status == ModelDownloadStatus.downloaded;
        if (_downloadFilter == DownloadFilter.downloaded && !isDownloaded) {
          return false;
        }
        if (_downloadFilter == DownloadFilter.notDownloaded && isDownloaded) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedSize = null;
      _selectedTask = null;
      _downloadFilter = DownloadFilter.all;
    });
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedSize != null ||
      _selectedTask != null ||
      _downloadFilter != DownloadFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearFilters,
              tooltip: 'Clear filters',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'About models',
          ),
        ],
      ),
      body: Consumer<DownloadState>(
        builder: (context, state, child) {
          final allModels = state.models;
          final filteredModels = _filterModels(allModels, state);

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search models...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Size filter
                    _FilterDropdown<String>(
                      label: 'Size',
                      value: _selectedSize,
                      items: _availableSizes,
                      itemLabel: (size) => size,
                      onChanged: (value) =>
                          setState(() => _selectedSize = value),
                    ),
                    const SizedBox(width: 8),

                    // Task filter
                    _FilterDropdown<ModelTask>(
                      label: 'Task',
                      value: _selectedTask,
                      items: _availableTasks,
                      itemLabel: (task) => _taskLabel(task),
                      onChanged: (value) =>
                          setState(() => _selectedTask = value),
                    ),
                    const SizedBox(width: 8),

                    // Download status filter
                    _FilterDropdown<DownloadFilter>(
                      label: 'Status',
                      value: _downloadFilter == DownloadFilter.all
                          ? null
                          : _downloadFilter,
                      items: const [
                        DownloadFilter.downloaded,
                        DownloadFilter.notDownloaded,
                      ],
                      itemLabel: (filter) => switch (filter) {
                        DownloadFilter.all => 'All',
                        DownloadFilter.downloaded => 'Downloaded',
                        DownloadFilter.notDownloaded => 'Not Downloaded',
                      },
                      onChanged: (value) => setState(
                        () => _downloadFilter = value ?? DownloadFilter.all,
                      ),
                    ),
                  ],
                ),
              ),

              // Results count
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${filteredModels.length} of ${allModels.length} models',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),

              // Model list
              Expanded(
                child: filteredModels.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No models match your filters',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: _clearFilters,
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => state.initialize(),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 88),
                          itemCount: filteredModels.length,
                          itemBuilder: (context, index) {
                            return ModelListItem(model: filteredModels[index]);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _DownloadAllFab(),
    );
  }

  String _taskLabel(ModelTask task) {
    return switch (task) {
      ModelTask.general => 'General',
      ModelTask.rag => 'RAG',
      ModelTask.extraction => 'Extraction',
      ModelTask.toolUse => 'Tool Use',
      ModelTask.translation => 'Translation',
      ModelTask.summarization => 'Summarization',
      ModelTask.piiExtraction => 'PII',
      ModelTask.reasoning => 'Reasoning',
    };
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

/// A dropdown-style filter chip.
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<T>(
          initialValue: value,
          onSelected: onChanged,
          offset: const Offset(0, 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => items
              .map(
                (item) => PopupMenuItem<T>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(
                        value == item ? Icons.check : Icons.circle_outlined,
                        size: 18,
                        color: value == item
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Text(itemLabel(item)),
                    ],
                  ),
                ),
              )
              .toList(),
          child: InputChip(
            label: Text(
              isSelected ? itemLabel(value as T) : label,
              style: TextStyle(
                color: isSelected ? colorScheme.onSecondaryContainer : null,
              ),
            ),
            avatar: Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isSelected ? colorScheme.onSecondaryContainer : null,
            ),
            selected: isSelected,
            showCheckmark: false,
            onDeleted: isSelected ? () => onChanged(null) : null,
            deleteIcon: const Icon(Icons.close, size: 16),
            onPressed: null, // Handled by PopupMenuButton
          ),
        ),
      ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/models/models.dart';
import 'package:jobeval/core/api/api_service.dart';

class CadViewerScreen extends ConsumerStatefulWidget {
  final String projectId;

  const CadViewerScreen({super.key, required this.projectId});

  @override
  ConsumerState<CadViewerScreen> createState() => _CadViewerScreenState();
}

class _CadViewerScreenState extends ConsumerState<CadViewerScreen> {
  bool _isLoading = true;
  String? _modelUrl;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    final api = ref.read(apiServiceProvider);
    try {
      final specs = await api.getCadSpecs(widget.projectId);
      _modelUrl = 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Box/glTF/Box.gltf';
    } catch (e) {
      _modelUrl = null;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('3D CAD Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: _toggleOrthographic,
            tooltip: 'Orthographic Views',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetCamera,
            tooltip: 'Reset Camera',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _modelUrl == null
              ? _buildEmptyState()
              : Column(
                  children: [
                    // 3D Viewer placeholder
                    Expanded(
                      child: Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.view_in_ar, size: 80, color: theme.colorScheme.primary),
                              const SizedBox(height: 16),
                              Text(
                                '3D Model Viewer',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _modelUrl ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // View controls
                    Positioned(
                      bottom: 24,
                      left: 24,
                      child: _buildViewControls(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No 3D Model Available',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a STEP, IGES, STL, or BREP file to view the 3D model.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildViewControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton('Top', Icons.device_hub, () => _setView('top')),
          const SizedBox(height: 8),
          _buildViewButton('Front', Icons.camera_front, () => _setView('front')),
          const SizedBox(height: 8),
          _buildViewButton('Right', Icons.screen_share, () => _setView('right')),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _buildViewButton('Isometric', Icons.visibility, () => _setView('iso')),
        ],
      ),
    );
  }

  Widget _buildViewButton(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleOrthographic() {}
  void _resetCamera() {}
  void _setView(String view) {}
}
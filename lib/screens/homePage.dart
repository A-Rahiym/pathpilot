/// Consumer-driven home screen that renders the map UI and delegates all logic
/// to `HomeController`, keeping the widgets focused on presentation only.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/application/home_controller.dart';
import '../features/home/application/home_state.dart';
import '../providers/app_providers.dart';
import '../services/camera_gemini_service.dart';
import '../widgets/custom_map.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  /// Hooks controller initialization + state listeners after first frame.
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeControllerProvider.notifier).initialize();
    });

    ref.listen<HomeState>(homeControllerProvider, (previous, next) {
      if (next.detectedCommand != null &&
          next.detectedCommand != previous?.detectedCommand) {
        _showDetectedCommandDialog(next.detectedCommand!);
        ref.read(homeControllerProvider.notifier).clearDetectedCommandFlag();
      }

      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showErrorSnackBar(next.errorMessage!);
        ref.read(homeControllerProvider.notifier).clearErrorMessage();
      }
    });
  }

  @override
  /// Builds the layered home UI stack powered entirely by HomeState.
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);
    final cameraService = ref.watch(cameraGeminiServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          controller.startListening();
        },
        onLongPressUp: () {
          controller.stopListening();
        },
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomMap(
                    center: state.mapCenter,
                    onMapCreated: controller.onMapCreated,
                    markers: state.markers,
                    polylines: state.polylines,
                  ),
                ),
              ),
              Positioned(
                top: 24,
                left: 24,
                right: 24,
                child: _SearchPanel(
                  controller: controller,
                  state: state,
                  searchController: _searchController,
                ),
              ),
              Positioned(
                right: 24,
                bottom: 700,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _MapControlButton(onPressed: controller.recenterMap),
                  ],
                ),
              ),
              if (state.isListening)
                const Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: _ListeningIndicator(),
                ),
              Positioned(
                bottom: 24,
                left: 24,
                child: _CameraPanel(
                  controller: controller,
                  state: state,
                  cameraService: cameraService,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Opacity(
                  opacity: 0.15,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 240,
                    child: InkWell(
                      onTap: state.isListening
                          ? () {
                              controller.stopListening();
                            }
                          : () {
                              controller.startListening();
                            },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays a transient dialog echoing recognized voice commands.
  void _showDetectedCommandDialog(String command) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        content: Text(
          'Detected command:\n$command',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Shows errors surfaced by the controller as snack bars.
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  /// Disposes the text controller and instructs HomeController to clean up.
  void dispose() {
    _searchController.dispose();
    ref.read(homeControllerProvider.notifier).disposeController();
    super.dispose();
  }
}

/// Search bar + autocomplete dropdown that wires directly to HomeController.
class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.state,
    required this.searchController,
  });

  final HomeController controller;
  final HomeState state;
  final TextEditingController searchController;

  @override
  /// Renders the search input, navigate CTA, and suggestion list.
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search destination',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      controller.clearSearchResults();
                      searchController.clear();
                      controller.clearPendingSearch();
                    } else {
                      controller.searchLocations(value);
                    }
                  },
                  onSubmitted: (value) {
                    if (value.isEmpty) return;
                    controller.setPendingSearch(value);
                    controller.handleLocationRequest(value);
                  },
                ),
              ),
              if (state.pendingSearch != null && !state.showSearchResults)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final query = state.pendingSearch;
                    if (query == null) return;
                    await controller.handleLocationRequest(query);
                    controller.clearPendingSearch();
                    controller.clearSearchResults();
                    searchController.clear();
                  },
                  child: const Text('Navigate'),
                ),
              IconButton(
                icon: Icon(
                  state.isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                ),
                onPressed: state.isListening
                    ? () {
                        controller.stopListening();
                      }
                    : () {
                        controller.startListening();
                      },
              ),
            ],
          ),
        ),
        if (state.showSearchResults && state.searchLabels.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF232323),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              itemCount: state.searchLabels.length,
              itemBuilder: (context, index) {
                final label = state.searchLabels[index];
                final result = state.searchResults.isNotEmpty
                    ? state.searchResults[index]
                    : null;
                return ListTile(
                  title: Text(
                    label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    result != null
                        ? '${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}'
                        : 'Address details...',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () async {
                    searchController.text = label;
                    await controller.handleSearchResultTap(index);
                    controller.clearPendingSearch();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Simple reusable explore/center button overlay for the map.
class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  /// Builds a square material button wrapping the provided callback.
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF232323),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          onPressed();
        },
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.explore, color: Colors.white),
        ),
      ),
    );
  }
}

/// Visual indicator displayed while speech recognition is active.
class _ListeningIndicator extends StatelessWidget {
  const _ListeningIndicator();

  @override
  /// Builds the small pill used to show the current listening status.
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Listening...',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

/// Hosts the camera preview and toggle FAB for obstacle detection.
class _CameraPanel extends StatelessWidget {
  const _CameraPanel({
    required this.controller,
    required this.state,
    required this.cameraService,
  });

  final HomeController controller;
  final HomeState state;
  final CameraGeminiService cameraService;

  @override
  /// Displays the camera preview along with stream toggle controls.
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child:
              cameraService.controller != null &&
                  cameraService.controller!.value.isInitialized
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CameraPreview(cameraService.controller!),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          mini: true,
          onPressed: () {
            controller.toggleCameraStreaming();
          },
          tooltip: state.cameraStreaming ? 'Stop Detection' : 'Start Detection',
          backgroundColor: state.cameraStreaming ? Colors.red : Colors.blue,
          child: Icon(
            state.cameraStreaming ? Icons.visibility_off : Icons.visibility,
          ),
        ),
      ],
    );
  }
}

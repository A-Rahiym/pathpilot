/// Hosts the camera preview and toggle FAB for obstacle detection.
/// Consumes CameraState via Riverpod and delegates actions to CameraController.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import 'camera_controller.dart';

class CameraPanel extends ConsumerWidget {
  const CameraPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final cameraService = ref.watch(cameraGeminiServiceProvider);

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

/// Map widget that renders the Google Map with markers and polylines.
/// Consumes MapState via Riverpod and delegates map creation to MapController.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/custom_map.dart';
import 'map_controller.dart';

class MapWidget extends ConsumerWidget {
  const MapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mapControllerProvider);
    final controller = ref.read(mapControllerProvider.notifier);

    return Padding(
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
    );
  }
}

import 'package:flutter/material.dart';
import '../features/directions/directions_controller.dart';
// import 'navigation.dart'; // <-- your navigation screen file
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pathpilot/widgets/main_nav.dart';
// import '../features/directions/directions_controller.dart';
class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  final Color primaryColor = const Color(0xFF1566EB);
  final Color backgroundLight = const Color(0xFFFFFFFF);
  final Color textLight = const Color.fromARGB(255, 255, 255, 255);

  Future<void> handleWhereAmI(WidgetRef ref) async {
    final directionsController = ref.read(
      directionsControllerProvider.notifier,
    );
    // Announce location
    await directionsController.announceCurrentLocation();
    // Request location permission
    await Permission.location.request();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: backgroundLight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.explore, size: 32, color: primaryColor),
                  const Text(
                    'PATH PILOT',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Tap the microphone to speak',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 18,
                          color: textLight,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Mic
                      SizedBox(
                        height: 160,
                        width: 160,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: primaryColor,
                            elevation: 8,
                          ),
                          child: const Icon(
                            Icons.mic,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Button Group
                      Column(
                        children: [
                          // START NAVIGATION
                          _buildMainButton(
                            'Start Navigation',
                            primaryColor,
                            onTap: () {
                              MainNav.of(
                                context,
                              )?.goToPage(1); // Switch to Navigation page
                            },
                          ),
                          const SizedBox(height: 16),

                          // WHERE AM I? (calls announce location)
                          _buildMainButton(
                            'Where Am I?',
                            primaryColor,
                            onTap: () {
                              handleWhereAmI(ref);
                            },
                          ),
                          const SizedBox(height: 16),

                          // OBJECT DETECTION
                          _buildMainButton(
                            'Object Detection',
                            primaryColor,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.grey.shade200.withOpacity(0.8),
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.language, color: Colors.black),
                label: const Text(
                  'Language: EN',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200.withOpacity(0.8),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton(String text, Color color, {required Function onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: ElevatedButton(
        onPressed: () => onTap(),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

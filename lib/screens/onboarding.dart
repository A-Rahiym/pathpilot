import 'package:flutter/material.dart';
import 'package:pathpilot/widgets/main_nav.dart';
import '../services/tts_service.dart';

final ttsService = TtsService();

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final Color primaryColor = const Color(0xFF1266ED);
  final Color backgroundLight = const Color(0xFFF6F7F8);
  final Color textLight = const Color.fromARGB(255, 31, 63, 104);
  final Color textSecondary = const Color(0xFF4C6A9A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),

            /// Title Section
            Text(
              'Welcome to PATH PILOT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: textLight,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              "Your voice-first AI guide for safe and confident navigation. Let's get you set up.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 16,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            /// Carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildCarouselItem(
                    icon: Icons.person,
                    title: 'Obstacle Detection',
                    subtitle: 'Detect obstacles in real-time along your path.',
                  ),
                  _buildCarouselItem(
                    icon: Icons.volume_up,
                    title: 'Voice Navigation',
                    subtitle: 'Clear and accurate turn-by-turn voice instructions.',
                  ),
                  _buildCarouselItem(
                    icon: Icons.vibration,
                    title: 'Haptic Feedback',
                    subtitle: 'Feel gentle vibrations guiding your movement.',
                  ),
                  _buildCarouselItem(
                    icon: Icons.sos,
                    title: 'Emergency Help',
                    subtitle: 'Quick SOS access when you need help urgently.',
                  ),
                ],
              ),
            ),

            /// Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 28 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color:
                        _currentPage == index ? primaryColor : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(5),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            /// Buttons Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _finishOnboarding(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Select Language',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () => _finishOnboarding(),
                    child: Text(
                      'Skip for now',
                      style: TextStyle(fontSize: 16, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// -------------------------
  ///  CAROUSEL ITEM BUILDER
  /// -------------------------
  Widget _buildCarouselItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Container(
            height: 160,
            width: 160,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 96, color: primaryColor),
          ),
          const SizedBox(height: 16),

          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 8),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// -------------------------
  ///  FINISH ONBOARDING
  /// -------------------------
  void _finishOnboarding() {
    /// Navigate to MAIN NAV HOME (index 0)
    MainNav.of(context)?.goToPage(0);
  }
}

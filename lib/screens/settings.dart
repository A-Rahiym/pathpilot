import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // String _selectedTheme = 'Light';
  bool _voiceGuidance = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              color: const Color(0xFF232323),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AppBar
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).maybePop();
                        },
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Settings',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // To balance the back button
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Voice Navigation Switch
                  _settingsSwitchTile(
                    title: 'Voice Navigation',
                    value: _voiceGuidance,
                    onChanged: (val) => setState(() => _voiceGuidance = val),
                  ),
                  _divider(),
                  // Units
                  _settingsListTile(
                    title: 'Units',
                    value: 'Miles',
                    onTap: () {
                      // TODO: Show units selection dialog
                    },
                  ),
                  _divider(),
                  // Voice
                  _settingsListTile(
                    title: 'Voice',
                    value: 'Female',
                    onTap: () {
                      // TODO: Show voice selection dialog
                    },
                  ),
                  _divider(),
                  // Clear Recent Destinations
                  _settingsListTile(
                    title: 'Clear Recent Destinations',
                    value: '',
                    onTap: () {
                      // TODO: Clear recent destinations
                    },
                  ),
                  _divider(),
                  // About
                  _settingsListTile(
                    title: 'About',
                    value: '',
                    onTap: () {
                      // TODO: Show about dialog
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2196F3),
          ),
        ],
      ),
    );
  }

  Widget _settingsListTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            Row(
              children: [
                if (value.isNotEmpty)
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white38,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Divider(color: Colors.white24, height: 1),
    );
  }
}

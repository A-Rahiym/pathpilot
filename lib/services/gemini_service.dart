import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../core/constants.dart';

class CommandResult {
  final String? intent;
  final String? destination;
  CommandResult({this.intent, this.destination});
}

class GeminiService {
  // Reverse geocode: get placemarks from coordinates
  Future<List<dynamic>> getPlacemarksFromCoordinates(
    double lat,
    double lng,
  ) async {
    try {
      // Use geocoding package
      return await placemarkFromCoordinates(lat, lng);
    } catch (e) {
      // Fallback: Google Maps Geocoding API
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${AppConstants.googleMapsApiKey}',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final results = data['results'] as List<dynamic>;
        return results;
      }
    }
    return [];
  }

  // Format a placemark or Google result to a readable address
  String formatPlacemark(dynamic placemark) {
    // If using geocoding package's Placemark
    if (placemark is Placemark) {
      final name = placemark.name ?? '';
      final street = placemark.street ?? '';
      final locality = placemark.locality ?? '';
      final admin = placemark.administrativeArea ?? '';
      final country = placemark.country ?? '';
      final address = [
        name,
        street,
        locality,
        admin,
        country,
      ].where((s) => s.isNotEmpty).join(', ');
      if (address.isNotEmpty) return address;
    }
    // If using Google Maps API result
    if (placemark is Map && placemark['formatted_address'] != null) {
      return placemark['formatted_address'];
    }
    return 'Unknown address';
  }
  // Helper to clean Gemini's reply from code block markers
  String cleanJson(String text) {
    final regex = RegExp(r'```(?:json)?([\s\S]*?)```');
    final match = regex.firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return text.trim();
  }

  /// Returns the prompt for Gemini command parsing
  String commandParsingPrompt(String userCommand) {
    return '''
You are Path Pilot, a voice navigation assistant for visually impaired users.
Your job is to extract the user's intent and any relevant parameters from their spoken command.

Supported commands and their intents:
- "Where am I?" or "What is my current location?" → intent: location
- "Take me to [destination]" or "Navigate to [destination]" → intent: navigate, destination: [destination]
- "Stop navigation" or "Cancel navigation" → intent: stop_navigation
- "Show camera" → intent: show_camera
- "Hide camera" → intent: hide_camera
- "Switch view" or "Toggle view" → intent: switch_view
- "Describe the current scene" or "Describe view" → intent: describe_scene
- "User guide" or "Help" → intent: user_guide

If the command matches one of these, reply ONLY with a JSON object:
{
  "intent": "<intent>",
  "destination": "<destination or null>"
}

If the command does not require a destination, set "destination" to null.

User command: $userCommand
''';
  }

  /// Parses a voice command using Gemini LLM API and extracts intent/destination.
  Future<CommandResult> parseCommandLLM(String command, String apiKey) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );
    final prompt = commandParsingPrompt(command);
    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    });
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      print('Gemini raw reply: $text');
      final cleanedText = cleanJson(text);
      print('Gemini cleaned reply: $cleanedText');
      try {
        final jsonReply = jsonDecode(cleanedText);
        return CommandResult(
          intent: jsonReply['intent'],
          destination: jsonReply['destination'],
        );
      } catch (e) {
        print('Gemini JSON parse error: $e');
        return CommandResult();
      }
    } else {
      // API error
      return CommandResult();
    }
  }

  Future<Map<String, dynamic>> getMapsGroundedDirections({
    required String apiKey,
    required double userLat,
    required double userLng,
    required String destination,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final prompt =
        "My current location is at latitude $userLat longitude $userLng. Please guide me to $destination.";

    final body = jsonEncode({
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": prompt},
          ],
        },
      ],
      "tools": [
        {
          "googleMaps": {"enableWidget": true},
        },
      ],
      "toolConfig": {
        "retrievalConfig": {
          "latLng": {"latitude": userLat, "longitude": userLng},
        },
      },
    });

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // You may get: data['candidates'][0]['content']['parts'][0]['text'] (instructions)
      // And: data['groundingMetadata'] (links, sources)
      // And: data['googleMapsWidgetContextToken'] (for widget)
      return data;
    } else {
      print('Gemini Maps Grounding API error: ${response.statusCode}');
      return {};
    }
  }
}

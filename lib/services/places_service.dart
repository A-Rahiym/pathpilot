import 'package:http/http.dart' as http;
import 'dart:convert';

class PlacesService {
  final String apiKey;

  PlacesService(this.apiKey);
  Future<List<Map<String, String>>> autocomplete(
    String input, {
    double? lat,
    double? lng,
    int radius = 20000,
  }) async {
    final locationPart = (lat != null && lng != null)
        ? '&location=$lat,$lng&radius=$radius'
        : '';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeQueryComponent(input)}$locationPart&key=$apiKey&types=geocode',
    );
    final resp = await http.get(url);
    if (resp.statusCode != 200) return [];
    final jsonData = json.decode(resp.body);
    final status = jsonData['status'] as String?;
    if (status == null || (status != 'OK' && status != 'ZERO_RESULTS'))
      return [];
    final List predictions = (jsonData['predictions'] ?? []) as List;
    return predictions.map<Map<String, String>>((p) {
      return {
        'description': p['description'] as String? ?? '',
        'place_id': p['place_id'] as String? ?? '',
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty) return null;
    final fields = 'geometry,formatted_address,name'; // minimal fields
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=$fields&key=$apiKey',
    );
    final resp = await http.get(url);
    if (resp.statusCode != 200) return null;
    final jsonData = json.decode(resp.body);
    if ((jsonData['status'] as String?) != 'OK') return null;
    final Map<String, dynamic>? result =
        jsonData['result'] as Map<String, dynamic>?;
    if (result == null) return null;
    final loc = result['geometry']?['location'];
    if (loc == null) return null;
    return {
      'lat': (loc['lat'] as num).toDouble(),
      'lng': (loc['lng'] as num).toDouble(),
      'formatted_address':
          result['formatted_address'] as String? ??
          result['name'] as String? ??
          '',
    };
  }
  /// Search for places near a given lat/lng.
  /// Returns a list of maps: [{'name': ..., 'address': ...}, ...]
  Future<List<Map<String, dynamic>>> searchNearby(
    double lat,
    double lng, {
    int radius = 100,
    String type = 'establishment', // or leave blank for all types
  }) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng'
        '&radius=$radius'
        '&type=$type'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>;
      return results
          .map(
            (place) => {
              'name': place['name'],
              'address': place['vicinity'] ?? place['formatted_address'] ?? '',
            },
          )
          .toList();
    } else {
      print('Places Nearby API error: ${response.statusCode}');
      return [];
    }
  }
}

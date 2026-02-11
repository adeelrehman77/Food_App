import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TenantDiscoveryService {
  final String discoveryUrl = "https://api.funadventure.ae/discover/";
  final _storage = const FlutterSecureStorage();

  /// Hits the global discovery API to get the specific API endpoint 
  /// for the provided kitchen code or subdomain.
  Future<String?> discoverTenant(String kitchenCode) async {
    try {
      final response = await http.post(
        Uri.parse(discoveryUrl),
        body: json.encode({'kitchen_code': kitchenCode}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String apiEndpoint = data['api_endpoint']; // e.g., "https://kitchen1.funadventure.ae/api/v1/"
        final String tenantId = data['tenant_id'];

        // Persist for future use
        await _storage.write(key: 'baseUrl', value: apiEndpoint);
        await _storage.write(key: 'tenantId', value: tenantId);

        return apiEndpoint;
      } else {
        print("Discovery failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during tenant discovery: $e");
      return null;
    }
  }
}

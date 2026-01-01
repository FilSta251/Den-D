import 'dart:convert';
import 'package:http/http.dart' as http;

class AIChatService {
  // Zadej URL API sluťby (uprav podle dokumentace poskytovatele)
  final String apiUrl;
  // Tvůj API klíč
  final String apiKey;

  AIChatService({required this.apiUrl, required this.apiKey});

  Future<String> sendMessage(String message) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({'message': message}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reply'] ?? "OdpověďŹ není k dispozici.";
    } else {
      throw Exception("Chyba při komunikaci s AI API: ${response.statusCode}");
    }
  }
}


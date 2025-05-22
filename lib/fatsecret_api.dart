import 'dart:convert';
import 'package:http/http.dart' as http;

const String fatSecretClientId = '5b6af238810a46c885260b8425a5b92f';
const String fatSecretClientSecret = 'c8344d35b5e840bcb0801082a5ca0507';

Future<String?> getFatSecretAccessToken() async {
  final response = await http.post(
    Uri.parse('https://oauth.fatsecret.com/connect/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'grant_type': 'client_credentials',
      'scope': 'basic',
      'client_id': fatSecretClientId,
      'client_secret': fatSecretClientSecret,
    },
  );
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['access_token'];
  }
  return null;
}

Future<Map<String, dynamic>?> getFoodNutrients(String foodName) async {
  final accessToken = await getFatSecretAccessToken();
  if (accessToken == null) return null;

  // 1. Yemeği ara
  final searchResponse = await http.get(
    Uri.parse(
      'https://platform.fatsecret.com/rest/server.api?method=foods.search&search_expression=$foodName&format=json',
    ),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (searchResponse.statusCode != 200) return null;
  final searchData = json.decode(searchResponse.body);
  final foods = searchData['foods']?['food'];
  if (foods == null || foods.isEmpty) return null;
  final foodId = foods[0]['food_id'];

  // 2. Besin detayını çek
  final detailResponse = await http.get(
    Uri.parse(
      'https://platform.fatsecret.com/rest/server.api?method=food.get&food_id=$foodId&format=json',
    ),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (detailResponse.statusCode != 200) return null;
  final detailData = json.decode(detailResponse.body);
  final servings = detailData['food']?['servings']?['serving'];
  if (servings == null) return null;
  final serving = servings is List ? servings[0] : servings;
  return {
    'calories': double.tryParse(serving['calories'] ?? '0') ?? 0,
    'protein': double.tryParse(serving['protein'] ?? '0') ?? 0,
    'carbs': double.tryParse(serving['carbohydrate'] ?? '0') ?? 0,
    'fat': double.tryParse(serving['fat'] ?? '0') ?? 0,
  };
}

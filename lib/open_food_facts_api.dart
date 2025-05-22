import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>?> getFoodNutrientsFromOpenFoodFacts(
  String foodName,
) async {
  // Türkçe arama için 'tr' ekleyebilirsin, ama İngilizce daha çok sonuç döner
  final url = Uri.parse(
    'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$foodName&search_simple=1&action=process&json=1',
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final products = data['products'];
    if (products != null && products.isNotEmpty) {
      final product = products[0];
      final nutriments = product['nutriments'] ?? {};
      return {
        'calories':
            (nutriments['energy-kcal_100g'] ?? nutriments['energy_100g'] ?? 0)
                .toDouble(),
        'protein': (nutriments['proteins_100g'] ?? 0).toDouble(),
        'carbs': (nutriments['carbohydrates_100g'] ?? 0).toDouble(),
        'fat': (nutriments['fat_100g'] ?? 0).toDouble(),
      };
    }
  }
  return null;
}

Future<List<Map<String, dynamic>>> searchFoodProducts(String foodName) async {
  final url = Uri.parse(
    'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$foodName&search_simple=1&action=process&json=1',
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final products = data['products'];
    if (products != null && products.isNotEmpty) {
      // Sadece adı ve besin bilgisi olanları filtrele
      return products
          .where((p) => p['product_name'] != null && p['nutriments'] != null)
          .map<Map<String, dynamic>>(
            (p) => {
              'name': p['product_name'],
              'brand': p['brands'] ?? '',
              'nutriments': p['nutriments'],
            },
          )
          .toList();
    }
  }
  return [];
}

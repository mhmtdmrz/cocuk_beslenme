import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../food_service.dart';

class FoodsPage extends StatefulWidget {
  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  late Future<List<Map<String, dynamic>>> _foodsFuture;
  List<Map<String, dynamic>> _allFoods = [];
  List<Map<String, dynamic>> _filteredFoods = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _foodsFuture = FoodService().fetchFoods();
    _foodsFuture.then((foods) {
      setState(() {
        _allFoods = foods;
        _filteredFoods = foods;
      });
    });
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text.trim().toLowerCase();
      _filteredFoods =
          _allFoods
              .where(
                (food) =>
                    (food['name_tr'] ?? '').toLowerCase().contains(
                      _searchText,
                    ) ||
                    (food['name_en'] ?? '').toLowerCase().contains(_searchText),
              )
              .toList();
    });
  }

  Future<void> _addFoodDialog(BuildContext context, String name) async {
    final nameTrController = TextEditingController(text: name);
    final nameEnController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Yeni Gıda Ekle'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameTrController,
                      decoration: InputDecoration(labelText: 'Türkçe Adı'),
                      validator:
                          (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                    ),
                    TextFormField(
                      controller: nameEnController,
                      decoration: InputDecoration(labelText: 'İngilizce Adı'),
                      validator:
                          (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                    ),
                    TextFormField(
                      controller: caloriesController,
                      decoration: InputDecoration(labelText: 'Kalori (100g)'),
                      keyboardType: TextInputType.number,
                      validator:
                          (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                    ),
                    TextFormField(
                      controller: proteinController,
                      decoration: InputDecoration(labelText: 'Protein (g)'),
                      keyboardType: TextInputType.number,
                      validator:
                          (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                    ),
                    TextFormField(
                      controller: carbsController,
                      decoration: InputDecoration(labelText: 'Karb. (g)'),
                      keyboardType: TextInputType.number,
                      validator:
                          (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                    ),
                    TextFormField(
                      controller: fatController,
                      decoration: InputDecoration(labelText: 'Yağ (g)'),
                      keyboardType: TextInputType.number,
                      validator:
                          (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    await FirebaseFirestore.instance
                        .collection('basic_foods')
                        .add({
                          'name_tr': nameTrController.text.trim(),
                          'name_en': nameEnController.text.trim(),
                          'calories':
                              double.tryParse(caloriesController.text) ?? 0,
                          'protein':
                              double.tryParse(proteinController.text) ?? 0,
                          'carbs': double.tryParse(carbsController.text) ?? 0,
                          'fat': double.tryParse(fatController.text) ?? 0,
                        });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gıda başarıyla eklendi!')),
                    );
                  }
                },
                child: Text('Ekle'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Temel Gıdalar')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _foodsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          // Listeyi güncel tutmak için:
          if (_allFoods.isEmpty && snapshot.hasData) {
            _allFoods = snapshot.data!;
            _filteredFoods =
                _allFoods
                    .where(
                      (food) =>
                          (food['name_tr'] ?? '').toLowerCase().contains(
                            _searchText,
                          ) ||
                          (food['name_en'] ?? '').toLowerCase().contains(
                            _searchText,
                          ),
                    )
                    .toList();
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Gıda Ara',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (_filteredFoods.isEmpty && _searchText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        '"$_searchText" bulunamadı. \n Dilerseniz kendiniz ekleyebilirsiniz',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('Yeni Gıda Ekle'),
                        onPressed: () => _addFoodDialog(context, _searchText),
                      ),
                    ],
                  ),
                ),
              if (_filteredFoods.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredFoods.length,
                    itemBuilder: (context, index) {
                      final food = _filteredFoods[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(food['name_tr'] ?? ''),
                          subtitle: Text(
                            'Kalori: ${food['calories']} | Protein: ${food['protein']}g | Karb: ${food['carbs']}g | Yağ: ${food['fat']}g',
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

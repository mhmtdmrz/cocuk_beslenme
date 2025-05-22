import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChildDetailPage extends StatefulWidget {
  final String childId;
  const ChildDetailPage({super.key, required this.childId});

  @override
  State<ChildDetailPage> createState() => _ChildDetailPageState();
}

class _ChildDetailPageState extends State<ChildDetailPage> {
  final foodController = TextEditingController();
  final amountController = TextEditingController();
  final List<String> mealTypes = ['Kahvaltı', 'Öğle', 'Akşam', 'Ara Öğün'];
  String selectedMealType = 'Kahvaltı';
  DateTime selectedDate = DateTime.now();

  List<Map<String, dynamic>> _basicFoods = [];
  List<String> _foodSuggestions = [];

  // Çocuk bilgileri
  int? childAge;
  double? childWeight;
  String? childGender;

  // Son eksik değerler (öneri popup için)
  double _lastCalorieDeficit = 0;
  double _lastProteinDeficit = 0;
  double _lastCarbDeficit = 0;
  double _lastFatDeficit = 0;

  @override
  void initState() {
    super.initState();
    _fetchBasicFoods();
    _fetchChildInfo();
    selectedMealType = getMealTypeFromTime(TimeOfDay.now());
  }

  Future<void> _fetchBasicFoods() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('basic_foods').get();
    setState(() {
      _basicFoods =
          snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
      _foodSuggestions =
          _basicFoods.map((f) => f['name_tr'] as String).toList();
    });
  }

  Future<void> _fetchChildInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('children')
            .doc(widget.childId)
            .get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        childAge =
            data['age'] is int
                ? data['age']
                : int.tryParse(data['age'].toString());
        childWeight =
            data['weight'] is double
                ? data['weight']
                : double.tryParse(data['weight'].toString());
        childGender = data['gender']?.toString().toLowerCase();
      });
    }
  }

  Future<Map<String, dynamic>?> _searchBasicFoods(String name) async {
    final lower = name.trim().toLowerCase();
    return _basicFoods.firstWhere(
      (f) => (f['name_tr'] as String).toLowerCase() == lower,
      orElse: () => {},
    );
  }

  Future<String> translateToEnglish(String text) async {
    final response = await http.post(
      Uri.parse('https://openl-translate.p.rapidapi.com/translate'),
      headers: {
        'Content-Type': 'application/json',
        "x-rapidapi-host": "openl-translate.p.rapidapi.com",
        "x-rapidapi-key": "75218bd0f3mshd10adbfa166083cp1c8343jsn5200fcb1effc",
      },
      body: jsonEncode({'target_lang': "en", 'text': text}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['translatedText'] ?? text;
    }
    return text;
  }

  Future<List<Map<String, dynamic>>> searchFoodProducts(String query) async {
    final url = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$query&search_simple=1&action=process&json=1&page_size=10',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final products =
          (data['products'] as List)
              .map(
                (p) => {
                  'name': p['product_name'] ?? '',
                  'brand': p['brands'] ?? '',
                  'nutriments': p['nutriments'] ?? {},
                },
              )
              .where((p) => (p['name'] as String).isNotEmpty)
              .toList();
      return products.cast<Map<String, dynamic>>();
    }
    return [];
  }

  String getMealTypeFromTime(TimeOfDay time) {
    final totalMinutes = time.hour * 60 + time.minute;
    if (totalMinutes >= 360 && totalMinutes < 720) {
      // 06:00 - 12:00
      return 'Kahvaltı';
    } else if (totalMinutes >= 720 && totalMinutes < 900) {
      // 12:00 - 15:00
      return 'Öğle';
    } else if (totalMinutes >= 1020 && totalMinutes < 1260) {
      // 17:00 - 21:00
      return 'Akşam';
    } else {
      return 'Ara Öğün';
    }
  }

  Map<String, double> getDailyNeeds() {
    if (childAge == null || childWeight == null || childGender == null) {
      return {'calories': 1200, 'protein': 20, 'carbs': 130, 'fat': 35};
    }
    if (childAge! < 4) {
      return {'calories': 1000, 'protein': 13, 'carbs': 130, 'fat': 35};
    } else if (childAge! < 9) {
      return {
        'calories': childGender == 'erkek' ? 1400 : 1200,
        'protein': 19,
        'carbs': 130,
        'fat': 40,
      };
    } else if (childAge! < 14) {
      return {
        'calories': childGender == 'erkek' ? 1800 : 1600,
        'protein': 34,
        'carbs': 130,
        'fat': 50,
      };
    } else {
      return {
        'calories': childGender == 'erkek' ? 2200 : 1800,
        'protein': 52,
        'carbs': 130,
        'fat': 60,
      };
    }
  }

  Future<void> addMeal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final foodName = foodController.text.trim();
    final amount = double.tryParse(amountController.text) ?? 0;
    if (foodName.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen yemek ve miktar giriniz!')),
      );
      return;
    }

    Map<String, dynamic>? foodData = await _searchBasicFoods(foodName);
    if (foodData != null && foodData.isNotEmpty) {
      await _addMealToFirestore(foodData, amount, foodName, selectedMealType);
      foodController.clear();
      amountController.clear();
      return;
    }

    final foodNameEn = await translateToEnglish(foodName);
    final products = await searchFoodProducts(foodNameEn);

    if (products.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ürün bulunamadı!')));
      return;
    }

    Map<String, dynamic>? selectedProduct;
    if (products.length == 1) {
      selectedProduct = products[0];
    } else {
      selectedProduct = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: const Text('Ürün Seç'),
            children:
                products.map((product) {
                  final name = product['name'] ?? '';
                  final brand = product['brand'] ?? '';
                  return SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, product),
                    child: Text('$name${brand.isNotEmpty ? ' ($brand)' : ''}'),
                  );
                }).toList(),
          );
        },
      );
      if (selectedProduct == null) return;
    }

    final nutriments = selectedProduct['nutriments'] ?? {};
    final nutrients = {
      'calories':
          double.tryParse(
            nutriments['energy-kcal_100g']?.toString() ??
                nutriments['energy_100g']?.toString() ??
                '0',
          ) ??
          0,
      'protein':
          double.tryParse(nutriments['proteins_100g']?.toString() ?? '0') ?? 0,
      'carbs':
          double.tryParse(
            nutriments['carbohydrates_100g']?.toString() ?? '0',
          ) ??
          0,
      'fat': double.tryParse(nutriments['fat_100g']?.toString() ?? '0') ?? 0,
    };

    final newFoodData = {
      'name_tr': foodName,
      'name_en': foodNameEn,
      ...nutrients,
    };
    await FirebaseFirestore.instance.collection('basic_foods').add(newFoodData);
    await _addMealToFirestore(newFoodData, amount, foodName, selectedMealType);

    await _fetchBasicFoods();
  }

  Future<void> _addMealToFirestore(
    Map<String, dynamic> foodData,
    double amount,
    String foodName,
    String mealType,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final scale = amount / 100.0;
    final scaledNutrients = {
      'calories': (foodData['calories'] ?? 0) * scale,
      'protein': (foodData['protein'] ?? 0) * scale,
      'carbs': (foodData['carbs'] ?? 0) * scale,
      'fat': (foodData['fat'] ?? 0) * scale,
    };
    final now = DateTime.now();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('children')
        .doc(widget.childId)
        .collection('meals')
        .add({
          'food': foodName,
          'amount': amount,
          'nutrients': scaledNutrients,
          'date': DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            now.hour,
            now.minute,
            now.second,
          ),
          'mealType': mealType,
          'brand': foodData['brand'] ?? '',
        });
    foodController.clear();
    amountController.clear();
    setState(() {});
  }

  Future<void> deleteMeal(String mealId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('children')
        .doc(widget.childId)
        .collection('meals')
        .doc(mealId)
        .delete();
    setState(() {});
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // --- ÖNERİ POPUP FONKSİYONU ---
  void showMacroSuggestionPopup(BuildContext context) {
    String? macro;
    double deficit = 0;
    String macroLabel = "";
    if (_lastProteinDeficit > 0) {
      macro = "protein";
      deficit = _lastProteinDeficit;
      macroLabel = "protein";
    } else if (_lastCarbDeficit > 0) {
      macro = "carbs";
      deficit = _lastCarbDeficit;
      macroLabel = "karbonhidrat";
    } else if (_lastFatDeficit > 0) {
      macro = "fat";
      deficit = _lastFatDeficit;
      macroLabel = "yağ";
    } else {
      macro = null;
    }

    List<Widget> children = [];
    if (macro == null) {
      children.add(const Text("Bugün için eksik makro besin yok!"));
    } else {
      List<Map<String, dynamic>> macroFoods =
          _basicFoods
              .where((food) => (food[macro] ?? 0) > 0)
              .map((food) {
                double valuePer100g = (food[macro] ?? 0).toDouble();
                double neededGram =
                    valuePer100g > 0
                        ? (deficit / valuePer100g) * 100
                        : double.infinity;
                return {...food, 'neededGram': neededGram};
              })
              .where((food) => food['neededGram'] < 500)
              .toList();

      macroFoods.sort(
        (a, b) =>
            (a['neededGram'] as double).compareTo(b['neededGram'] as double),
      );
      final suggestions = macroFoods.take(3).toList();

      if (suggestions.isEmpty) {
        children.add(Text("Eksik $macroLabel için uygun öneri bulunamadı."));
      } else {
        children.add(
          Text(
            "Eksik $macroLabel için öneriler:",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
        children.add(const SizedBox(height: 8));
        children.addAll(
          suggestions.map(
            (food) => Text(
              "${food['name_tr']} → ${food['neededGram'].ceil()} gram yedirirsen eksik $macroLabel tamamlanır. "
              "(100g'da: ${food[macro]?.toStringAsFixed(1)}g $macroLabel)",
            ),
          ),
        );
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Beslenme Önerisi"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Kapat"),
              ),
            ],
          ),
    );
  }
  // --- /ÖNERİ POPUP FONKSİYONU ---

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Giriş yapmalısınız'));
    final mealsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('children')
        .doc(widget.childId)
        .collection('meals');

    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final dailyNeeds = getDailyNeeds();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yemek Takibi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => selectDate(context),
            tooltip: "Tarih Seç",
          ),
        ],
      ),
      body: Column(
        children: [
          // Çocuk bilgileri ve ihtiyaçlar
          if (childAge != null && childWeight != null && childGender != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Text(
                        "Çocuk Bilgileri: Yaş: $childAge, Kilo: ${childWeight?.toStringAsFixed(1)}, Cinsiyet: ${childGender![0].toUpperCase()}${childGender!.substring(1)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Günlük İhtiyaç: Kalori: ${dailyNeeds['calories']?.toStringAsFixed(0)} kcal | Protein: ${dailyNeeds['protein']?.toStringAsFixed(0)} g | Karb: ${dailyNeeds['carbs']?.toStringAsFixed(0)} g | Yağ: ${dailyNeeds['fat']?.toStringAsFixed(0)} g",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Öğün seçimi yukarıda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Text(
                  "Öğün: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: selectedMealType,
                  items:
                      mealTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMealType = value!;
                    });
                  },
                ),
                const Spacer(),
                Text(
                  "Tarih: ${selectedDate.day}.${selectedDate.month}.${selectedDate.year}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, size: 20),
                  onPressed: () => selectDate(context),
                  tooltip: "Tarih Seç",
                ),
              ],
            ),
          ),
          // Yemek ve miktar alanı + ekle butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }
                      return _foodSuggestions.where((String option) {
                        return option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        );
                      });
                    },
                    onSelected: (String selection) {
                      foodController.text = selection;
                    },
                    fieldViewBuilder: (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      foodController.text = controller.text;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'Yemek'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Miktar (g)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: addMeal,
                  tooltip: "Yemek Ekle",
                ),
              ],
            ),
          ),
          // Günlük yemekler ve toplamlar
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  mealsRef
                      .where('date', isGreaterThanOrEqualTo: startOfDay)
                      .where('date', isLessThan: endOfDay)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                double totalCalories = 0,
                    totalProtein = 0,
                    totalCarbs = 0,
                    totalFat = 0;
                for (var doc in docs) {
                  final n = (doc['nutrients'] ?? {}) as Map<String, dynamic>;
                  totalCalories += (n['calories'] ?? 0).toDouble();
                  totalProtein += (n['protein'] ?? 0).toDouble();
                  totalCarbs += (n['carbs'] ?? 0).toDouble();
                  totalFat += (n['fat'] ?? 0).toDouble();
                }
                final calorieDeficit =
                    (dailyNeeds['calories'] ?? 0) - totalCalories;
                final proteinDeficit =
                    (dailyNeeds['protein'] ?? 0) - totalProtein;
                final carbDeficit = (dailyNeeds['carbs'] ?? 0) - totalCarbs;
                final fatDeficit = (dailyNeeds['fat'] ?? 0) - totalFat;

                // Son eksik değerleri sakla (öneri popup için)
                _lastCalorieDeficit = calorieDeficit;
                _lastProteinDeficit = proteinDeficit;
                _lastCarbDeficit = carbDeficit;
                _lastFatDeficit = fatDeficit;

                Map<String, List<QueryDocumentSnapshot>> grouped = {};
                for (var doc in docs) {
                  final mealType = doc['mealType'] ?? 'Diğer';
                  grouped.putIfAbsent(mealType, () => []).add(doc);
                }

                // Eksik kalanlar sıfır veya altındaysa gösterme
                bool hasDeficit =
                    calorieDeficit > 0 ||
                    proteinDeficit > 0 ||
                    carbDeficit > 0 ||
                    fatDeficit > 0;

                return Stack(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Card(
                            color: Colors.blue[50],
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Text(
                                    "Toplam Kalori: ${totalCalories.toStringAsFixed(1)} kcal",
                                  ),
                                  Text(
                                    "Protein: ${totalProtein.toStringAsFixed(1)} g",
                                  ),
                                  Text(
                                    "Karbonhidrat: ${totalCarbs.toStringAsFixed(1)} g",
                                  ),
                                  Text("Yağ: ${totalFat.toStringAsFixed(1)} g"),
                                  const SizedBox(height: 8),
                                  if (hasDeficit)
                                    Text(
                                      "Eksik Kalan: "
                                      "${calorieDeficit > 0 ? "Kalori: ${calorieDeficit.toStringAsFixed(0)} kcal, " : ""}"
                                      "${proteinDeficit > 0 ? "Protein: ${proteinDeficit.toStringAsFixed(1)} g, " : ""}"
                                      "${carbDeficit > 0 ? "Karb: ${carbDeficit.toStringAsFixed(1)} g, " : ""}"
                                      "${fatDeficit > 0 ? "Yağ: ${fatDeficit.toStringAsFixed(1)} g" : ""}",
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child:
                              grouped.isEmpty
                                  ? const Center(
                                    child: Text("Bu gün için yemek kaydı yok."),
                                  )
                                  : ListView(
                                    children:
                                        grouped.entries.map((entry) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                      horizontal: 8,
                                                    ),
                                                child: Text(
                                                  entry.key,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              ...entry.value.map((doc) {
                                                final data =
                                                    doc.data()
                                                        as Map<String, dynamic>;
                                                final n =
                                                    data['nutrients'] ?? {};
                                                return Dismissible(
                                                  key: Key(doc.id),
                                                  direction:
                                                      DismissDirection
                                                          .endToStart,
                                                  background: Container(
                                                    color: Colors.red,
                                                    alignment:
                                                        Alignment.centerRight,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                        ),
                                                    child: const Icon(
                                                      Icons.delete,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  confirmDismiss: (
                                                    direction,
                                                  ) async {
                                                    return await showDialog<
                                                      bool
                                                    >(
                                                      context: context,
                                                      builder:
                                                          (
                                                            context,
                                                          ) => AlertDialog(
                                                            title: const Text(
                                                              'Yemeği Sil',
                                                            ),
                                                            content: const Text(
                                                              'Bu yemeği silmek istediğinize emin misiniz?',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      false,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'İptal',
                                                                    ),
                                                              ),
                                                              TextButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      true,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Sil',
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                    );
                                                  },
                                                  onDismissed: (
                                                    direction,
                                                  ) async {
                                                    await deleteMeal(doc.id);
                                                  },
                                                  child: ListTile(
                                                    title: Text(
                                                      '${data['food']} (${data['amount']}g)',
                                                    ),
                                                    subtitle: Text(
                                                      'Kalori: ${n['calories']?.toStringAsFixed(1) ?? '-'} | Protein: ${n['protein']?.toStringAsFixed(1) ?? '-'}g | Karb: ${n['carbs']?.toStringAsFixed(1) ?? '-'}g | Yağ: ${n['fat']?.toStringAsFixed(1) ?? '-'}g',
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          );
                                        }).toList(),
                                  ),
                        ),
                      ],
                    ),
                    if (hasDeficit)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.extended(
                          onPressed: () => showMacroSuggestionPopup(context),
                          icon: const Icon(Icons.lightbulb),
                          label: const Text("Öneri"),
                          tooltip: "Eksik makroya göre öneri al",
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

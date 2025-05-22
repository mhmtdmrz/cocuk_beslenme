import 'package:cloud_firestore/cloud_firestore.dart';

class FoodService {
  final CollectionReference foodsRef = FirebaseFirestore.instance.collection(
    'basic_foods',
  );

  Future<List<Map<String, dynamic>>> fetchFoods() async {
    final snapshot = await foodsRef.get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }
}

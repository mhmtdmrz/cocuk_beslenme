import 'package:cocuk_beslenme/foods_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'child_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Giriş yapmalısınız'));
    final childrenRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('children');

    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final heightController = TextEditingController();
    final weightController = TextEditingController();

    void addChild(BuildContext context) async {
      await childrenRef.add({
        'name': nameController.text,
        'age': int.tryParse(ageController.text) ?? 0,
        'height': double.tryParse(heightController.text) ?? 0,
        'weight': double.tryParse(weightController.text) ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      nameController.clear();
      ageController.clear();
      heightController.clear();
      weightController.clear();
      Navigator.pop(context);
    }

    void updateChild(BuildContext context, String childId) async {
      await childrenRef.doc(childId).update({
        'name': nameController.text,
        'age': int.tryParse(ageController.text) ?? 0,
        'height': double.tryParse(heightController.text) ?? 0,
        'weight': double.tryParse(weightController.text) ?? 0,
      });
      nameController.clear();
      ageController.clear();
      heightController.clear();
      weightController.clear();
      Navigator.pop(context);
    }

    void showAddChildDialog(BuildContext context) {
      nameController.clear();
      ageController.clear();
      heightController.clear();
      weightController.clear();
      showDialog(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Çocuk Ekle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Ad'),
                  ),
                  TextField(
                    controller: ageController,
                    decoration: const InputDecoration(labelText: 'Yaş'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: heightController,
                    decoration: const InputDecoration(labelText: 'Boy (cm)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: weightController,
                    decoration: const InputDecoration(labelText: 'Kilo (kg)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext); // Önce dialogu kapat
                    await childrenRef.add({
                      'name': nameController.text,
                      'age': int.tryParse(ageController.text) ?? 0,
                      'height': double.tryParse(heightController.text) ?? 0,
                      'weight': double.tryParse(weightController.text) ?? 0,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    nameController.clear();
                    ageController.clear();
                    heightController.clear();
                    weightController.clear();
                  },
                  child: const Text('Ekle'),
                ),
              ],
            ),
      );
    }

    void showEditChildDialog(
      BuildContext context,
      String childId,
      Map<String, dynamic> data,
    ) {
      nameController.text = data['name']?.toString() ?? '';
      ageController.text = data['age']?.toString() ?? '';
      heightController.text = data['height']?.toString() ?? '';
      weightController.text = data['weight']?.toString() ?? '';
      showDialog(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Çocuk Bilgilerini Düzenle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Ad'),
                  ),
                  TextField(
                    controller: ageController,
                    decoration: const InputDecoration(labelText: 'Yaş'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: heightController,
                    decoration: const InputDecoration(labelText: 'Boy (cm)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: weightController,
                    decoration: const InputDecoration(labelText: 'Kilo (kg)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext); // Önce dialogu kapat
                    await childrenRef.doc(childId).update({
                      'name': nameController.text,
                      'age': int.tryParse(ageController.text) ?? 0,
                      'height': double.tryParse(heightController.text) ?? 0,
                      'weight': double.tryParse(weightController.text) ?? 0,
                    });
                    nameController.clear();
                    ageController.clear();
                    heightController.clear();
                    weightController.clear();
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            ),
      );
    }

    void deleteChild(BuildContext context, String childId) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Çocuğu Sil'),
              content: const Text(
                'Bu çocuğu silmek istediğinize emin misiniz? Tüm yemek kayıtları da silinecek!',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Sil'),
                ),
              ],
            ),
      );
      if (confirm == true) {
        // Çocuğun altındaki meals koleksiyonunu da silmek istersen burada recursive silme yapabilirsin.
        await childrenRef.doc(childId).delete();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çocuklarım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.fastfood),
              label: const Text('Temel Gıdalar'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FoodsPage()),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: childrenRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Henüz çocuk eklemediniz.'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final childId = docs[i].id;
                    return ListTile(
                      title: Text(data['name'] ?? ''),
                      subtitle: Text(
                        'Yaş: ${data['age']}, Boy: ${data['height']} cm, Kilo: ${data['weight']} kg',
                      ),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChildDetailPage(childId: childId),
                            ),
                          ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            showEditChildDialog(context, childId, data);
                          } else if (value == 'delete') {
                            deleteChild(context, childId);
                          }
                        },
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Düzenle'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Sil'),
                              ),
                            ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddChildDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

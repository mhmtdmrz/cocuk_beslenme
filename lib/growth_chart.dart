import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class GrowthChart extends StatelessWidget {
  final String childId;
  const GrowthChart({super.key, required this.childId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Giriş yapmalısınız'));
    final growthRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('children')
        .doc(childId)
        .collection('growth');

    return Scaffold(
      appBar: AppBar(title: const Text('Büyüme Grafiği')),
      body: StreamBuilder<QuerySnapshot>(
        stream: growthRef.orderBy('date').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('Henüz büyüme verisi yok.'));
          final spots =
              docs.asMap().entries.map((e) {
                final i = e.key;
                final data = e.value.data() as Map<String, dynamic>;
                return FlSpot(
                  i.toDouble(),
                  (data['weight'] as num?)?.toDouble() ?? 0,
                );
              }).toList();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    color: Colors.blue,
                  ),
                ],
                titlesData: FlTitlesData(show: false),
              ),
            ),
          );
        },
      ),
    );
  }
}

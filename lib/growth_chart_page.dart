import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class GrowthChartPage extends StatefulWidget {
  const GrowthChartPage({super.key});

  @override
  State<GrowthChartPage> createState() => _GrowthChartPageState();
}

class _GrowthChartPageState extends State<GrowthChartPage> {
  String? selectedChildId;
  Map<String, dynamic>? selectedChildData;
  List<Map<String, dynamic>> children = [];
  int? touchedIndex; // Seçili çubuk

  @override
  void initState() {
    super.initState();
    fetchChildren();
  }

  Future<void> fetchChildren() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('children')
            .get();
    if (!mounted) return;
    setState(() {
      children =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      if (children.isNotEmpty) {
        selectedChildId = children.first['id'].toString();
        selectedChildData = children.first;
      }
    });
  }

  Map<String, double> getDailyNeeds(Map<String, dynamic> child) {
    int? childAge =
        child['age'] is int
            ? child['age']
            : int.tryParse(child['age'].toString());
    String? childGender = child['gender']?.toString().toLowerCase();
    if (childAge == null || childGender == null) {
      return {'calories': 1200};
    }
    if (childAge < 4) {
      return {'calories': 1000};
    } else if (childAge < 9) {
      return {'calories': childGender == 'erkek' ? 1400 : 1200};
    } else if (childAge < 14) {
      return {'calories': childGender == 'erkek' ? 1800 : 1600};
    } else {
      return {'calories': childGender == 'erkek' ? 2200 : 1800};
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Giriş yapmalısınız'));
    }

    if (children.isEmpty) {
      return const Center(child: Text('Önce çocuk ekleyin.'));
    }

    final child = children.firstWhere(
      (c) => c['id'].toString() == selectedChildId,
      orElse: () => children.first,
    );
    final dailyNeed = getDailyNeeds(child)['calories'] ?? 1200;

    // Son 7 günün tarihleri
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelişim Grafiği'),
        actions: [
          if (children.length > 1)
            DropdownButton<String>(
              value: selectedChildId,
              onChanged: (val) {
                setState(() {
                  selectedChildId = val;
                  selectedChildData = children.firstWhere(
                    (c) => c['id'].toString() == val,
                  );
                  touchedIndex = null;
                });
              },
              items:
                  children
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c['id'].toString(),
                          child: Text(c['name'] ?? 'Çocuk'),
                        ),
                      )
                      .toList(),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('children')
                .doc(selectedChildId)
                .collection('meals')
                .where(
                  'date',
                  isGreaterThan: now.subtract(const Duration(days: 7)),
                )
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Günlere göre toplam kaloriler
          Map<String, double> dayCalories = {
            for (var d in days) '${d.day}.${d.month}': 0.0,
          };
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final key = '${date.day}.${date.month}';
            final cal = (data['nutrients']?['calories'] ?? 0).toDouble();
            if (dayCalories.containsKey(key)) {
              dayCalories[key] = (dayCalories[key] ?? 0) + cal;
            }
          }

          // maxY güvenli şekilde
          double maxY;
          if (dayCalories.values.isNotEmpty) {
            maxY = max(dailyNeed * 1.3, dayCalories.values.reduce(max) + 100);
          } else {
            maxY = dailyNeed * 1.3;
          }

          final barGroups = <BarChartGroupData>[];
          int i = 0;
          for (var entry in dayCalories.entries) {
            final cal = entry.value;
            Color barColor;
            if (cal < dailyNeed * 0.95) {
              barColor = Colors.red; // Eksik
            } else if (cal > dailyNeed * 1.05) {
              barColor = Colors.blue; // Fazla
            } else {
              barColor = Colors.green; // Yeterli
            }
            barGroups.add(
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: cal,
                    color: barColor,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                showingTooltipIndicators: touchedIndex == i ? [0] : [],
              ),
            );
            i++;
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  '${child['name'] ?? ''} için son 7 günün kalori alımı',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GestureDetector(
                    // BarChart'ın dışına tıklanınca seçimi kaldır
                    onTap: () => setState(() => touchedIndex = null),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        minY: 0,
                        barGroups: barGroups,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 200,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < days.length) {
                                  return Text(
                                    '${days[idx].day}.${days[idx].month}',
                                    style: const TextStyle(fontSize: 12),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchCallback: (event, response) {
                            if (event.isInterestedForInteractions &&
                                response != null &&
                                response.spot != null) {
                              setState(() {
                                touchedIndex =
                                    response.spot!.touchedBarGroupIndex;
                              });
                            }
                          },
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: Colors.black87,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final day = days[group.x.toInt()];
                              return BarTooltipItem(
                                '${day.day}.${day.month}\n'
                                'Alınan: ${rod.toY.toStringAsFixed(0)} kcal\n'
                                'İhtiyaç: ${dailyNeed.toStringAsFixed(0)} kcal',
                                const TextStyle(color: Colors.white),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (touchedIndex != null)
                  Builder(
                    builder: (context) {
                      final idx = touchedIndex!;
                      final day = days[idx];
                      final cal = dayCalories['${day.day}.${day.month}'] ?? 0.0;
                      return Column(
                        children: [
                          Text(
                            '${day.day}.${day.month} günü',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Alınan: ${cal.toStringAsFixed(0)} kcal',
                            style: const TextStyle(fontSize: 15),
                          ),
                          Text(
                            'İhtiyaç: ${dailyNeed.toStringAsFixed(0)} kcal',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      );
                    },
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.square, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Yeterli  '),
                    Icon(Icons.square, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text('Eksik  '),
                    Icon(Icons.square, color: Colors.blue, size: 16),
                    SizedBox(width: 4),
                    Text('Fazla'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

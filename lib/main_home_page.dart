import 'package:flutter/material.dart';
import 'home_page.dart';
import 'growth_chart_page.dart';
import 'foods_page.dart';
import 'about_page.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePage(), // Çocuklarım
    GrowthChartPage(), // Gelişim Grafiği
    FoodsPage(), // Temel Gıdalar
    AboutPage(), // Hakkında
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.child_care),
            label: 'Çocuklarım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Gelişim Grafiği',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fastfood),
            label: 'Temel Gıdalar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Hakkında'),
        ],
      ),
    );
  }
}

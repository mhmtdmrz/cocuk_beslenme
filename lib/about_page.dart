import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uygulama Hakkında')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Çocuk Beslenme Takip Uygulaması',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Bu uygulama, çocuklarınızın günlük beslenmesini ve gelişimini takip etmenizi sağlar.\n\n'
              '• Öğün ve gıda takibi\n'
              '• Gelişim grafikleri\n'
              '• Temel gıdalar listesi\n'
              '• Beslenme önerileri\n\n'
              'Geliştirici: Mehmet DEMİRÖZ\n'
              'İletişim: mhmtdmrz97@gmail.com \n'
              'Pediatrist: Cansu BAŞ\n'
              'Pediatrist: Ahmet İbrahim BAŞ\n',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

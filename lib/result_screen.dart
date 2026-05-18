import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'analytics_store.dart';
import 'report_screen.dart';
import 'share_card_screen.dart';
import 'draw_insight_screen.dart';

class ResultScreen extends StatelessWidget {
  final Uint8List? drawingBytes;

  const ResultScreen({super.key, this.drawingBytes});

  Future<void> _showPaywall(BuildContext context) async {
    await AnalyticsStore.incrementReportClicks();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unlock Full Report',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('• Drawing analysis'),
              const Text('• Weekly progress'),
              const Text('• Personalized feedback'),
              const SizedBox(height: 24),

              /// 🔥 핵심 수정된 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await AnalyticsStore.incrementFreeTrialClicks();

                    if (!context.mounted) return;

                    Navigator.pop(context);

                    if (drawingBytes == null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportScreen(),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DrawInsightScreen(
                          drawingBytes: drawingBytes!,
                        ),
                      ),
                    );
                  },
                  child: const Text('Start Free Trial'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fakeDrawings = [
      {
        'title': 'Today Drawing',
        'subtitle': 'Just now',
        'icon': Icons.brush,
      },
      {
        'title': 'Circle Practice',
        'subtitle': 'Yesterday',
        'icon': Icons.palette_outlined,
      },
      {
        'title': 'Color Mood',
        'subtitle': '2 days ago',
        'icon': Icons.auto_awesome_outlined,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Drawing'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This is your drawing result',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            /// 🔥 drawing preview
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: drawingBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        drawingBytes!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 60,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 8),
                        const Text('No drawing preview available'),
                      ],
                    ),
            ),

            const SizedBox(height: 12),

            Text(
              'Recent drawings',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView.separated(
                itemCount: fakeDrawings.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = fakeDrawings[index];

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['subtitle'] as String,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            /// 🔥 View Full Report
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _showPaywall(context);
                },
                child: const Text('View Full Report'),
              ),
            ),

            const SizedBox(height: 10),

            /// 🔥 Share Card
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ShareCardScreen(drawingBytes: drawingBytes),
                    ),
                  );
                },
                child: const Text('Create Share Card'),
              ),
            ),

            const SizedBox(height: 10),

            /// 🔥 Draw Again
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Draw Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
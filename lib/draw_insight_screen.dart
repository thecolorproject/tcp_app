import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'analytics_store.dart';
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';

class DrawInsightScreen extends StatefulWidget {
  final Uint8List drawingBytes;

  const DrawInsightScreen({
    super.key,
    required this.drawingBytes,
  });

  @override
  State<DrawInsightScreen> createState() => _DrawInsightScreenState();
}

class _DrawInsightScreenState extends State<DrawInsightScreen> {
  final GlobalKey _insightCardKey = GlobalKey();

  bool _isSharing = false;
  double _cardScale = 1.0;

  late Future<List<_InsightItem>> _insightFuture;

  @override
  void initState() {
    super.initState();
    _insightFuture = _analyzeDrawingV2();
  }

  Future<List<_InsightItem>> _analyzeDrawingV2() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.drawingBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) return _fallbackItems();

      final pixels = byteData.buffer.asUint8List();
      final width = image.width;
      final height = image.height;

      final step = max(1, (max(width, height) / 180).ceil());
      final gridW = (width / step).ceil();
      final gridH = (height / step).ceil();

      final mask = List<bool>.filled(gridW * gridH, false);
      final hueBuckets = <int, int>{};

      int drawnCells = 0;
      int strongColorCells = 0;

      int minGX = gridW;
      int minGY = gridH;
      int maxGX = 0;
      int maxGY = 0;

      for (int gy = 0; gy < gridH; gy++) {
        for (int gx = 0; gx < gridW; gx++) {
          final x = min(gx * step, width - 1);
          final y = min(gy * step, height - 1);
          final index = (y * width + x) * 4;

          final r = pixels[index];
          final g = pixels[index + 1];
          final b = pixels[index + 2];
          final a = pixels[index + 3];

          if (!_isDrawnPixel(r, g, b, a)) continue;

          final idx = gy * gridW + gx;
          mask[idx] = true;
          drawnCells++;

          minGX = min(minGX, gx);
          minGY = min(minGY, gy);
          maxGX = max(maxGX, gx);
          maxGY = max(maxGY, gy);

          final hsv = HSVColor.fromColor(Color.fromARGB(a, r, g, b));

          if (hsv.saturation >= 0.16 && hsv.value >= 0.18) {
            strongColorCells++;
            final hueBucket = (hsv.hue / 24).round() % 15;
            hueBuckets[hueBucket] = (hueBuckets[hueBucket] ?? 0) + 1;
          }
        }
      }

      if (drawnCells == 0) return _fallbackItems();

      final totalCells = gridW * gridH;
      final drawnRatio = drawnCells / totalCells;

      final boxW = maxGX - minGX + 1;
      final boxH = maxGY - minGY + 1;
      final boxAreaRatio = (boxW * boxH) / totalCells;

      final colorCount = _countSignificantHueBuckets(
        hueBuckets,
        strongColorCells,
      );

      final structure = _analyzeStrokeStructure(
        mask: mask,
        gridW: gridW,
        gridH: gridH,
        drawnCells: drawnCells,
      );

      return [
        _InsightItem(
          emoji: '🎨',
          title: 'Color Use',
          value: _colorUseLabel(colorCount),
        ),
        _InsightItem(
          emoji: '🧭',
          title: 'Space Use',
          value: _spaceUseLabel(boxAreaRatio),
        ),
        _InsightItem(
          emoji: '🧶',
          title: 'Line Variety',
          value: _lineVarietyLabel(
            drawn: structure.drawnCells,
            components: structure.componentCount,
            boxAreaRatio: boxAreaRatio,
            orientationScore: structure.orientationCount / 4.0,
            endpointRatio: structure.endpointRatio,
            junctionRatio: structure.junctionRatio,
          ),
        ),
        _InsightItem(
          emoji: '🟠',
          title: 'Coverage',
          value: _coverageLabel(drawnRatio),
        ),
      ];
    } catch (e) {
      debugPrint('Drawing analysis error: $e');
      return _fallbackItems();
    }
  }

  bool _isDrawnPixel(int r, int g, int b, int a) {
    if (a < 40) return false;

    final maxRgb = max(r, max(g, b));
    final minRgb = min(r, min(g, b));
    final delta = maxRgb - minRgb;

    final isWhiteCanvas = r > 242 && g > 242 && b > 242;
    if (isWhiteCanvas) return false;

    final isWeakNoise = delta < 12 && maxRgb > 210;
    if (isWeakNoise) return false;

    return true;
  }

  int _countSignificantHueBuckets(
    Map<int, int> hueBuckets,
    int strongColorCells,
  ) {
    if (strongColorCells <= 0 || hueBuckets.isEmpty) return 0;

    int count = 0;

    hueBuckets.forEach((_, bucketCount) {
      final ratio = bucketCount / strongColorCells;
      if (bucketCount >= 8 && ratio >= 0.07) {
        count++;
      }
    });

    return count;
  }

  _StrokeStructure _analyzeStrokeStructure({
    required List<bool> mask,
    required int gridW,
    required int gridH,
    required int drawnCells,
  }) {
    final visited = List<bool>.filled(mask.length, false);
    final componentSizes = <int>[];

    int endpointCells = 0;
    int junctionCells = 0;

    final orientationLinks = <int, int>{
      0: 0,
      45: 0,
      90: 0,
      135: 0,
    };

    bool inside(int x, int y) => x >= 0 && y >= 0 && x < gridW && y < gridH;
    int idx(int x, int y) => y * gridW + x;

    for (int y = 0; y < gridH; y++) {
      for (int x = 0; x < gridW; x++) {
        final current = idx(x, y);
        if (!mask[current]) continue;

        int neighbors = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;

            final nx = x + dx;
            final ny = y + dy;

            if (!inside(nx, ny)) continue;
            if (mask[idx(nx, ny)]) neighbors++;
          }
        }

        if (neighbors <= 1) endpointCells++;
        if (neighbors >= 4) junctionCells++;

        if (inside(x + 1, y) && mask[idx(x + 1, y)]) {
          orientationLinks[0] = orientationLinks[0]! + 1;
        }
        if (inside(x, y + 1) && mask[idx(x, y + 1)]) {
          orientationLinks[90] = orientationLinks[90]! + 1;
        }
        if (inside(x + 1, y + 1) && mask[idx(x + 1, y + 1)]) {
          orientationLinks[45] = orientationLinks[45]! + 1;
        }
        if (inside(x - 1, y + 1) && mask[idx(x - 1, y + 1)]) {
          orientationLinks[135] = orientationLinks[135]! + 1;
        }

        if (visited[current]) continue;

        int size = 0;
        final queue = <int>[current];
        visited[current] = true;

        while (queue.isNotEmpty) {
          final node = queue.removeLast();
          size++;

          final cx = node % gridW;
          final cy = node ~/ gridW;

          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;

              final nx = cx + dx;
              final ny = cy + dy;

              if (!inside(nx, ny)) continue;

              final ni = idx(nx, ny);
              if (!mask[ni] || visited[ni]) continue;

              visited[ni] = true;
              queue.add(ni);
            }
          }
        }

        if (size >= 4) componentSizes.add(size);
      }
    }

    final significantComponents =
        componentSizes.where((s) => s >= max(4, drawnCells * 0.04)).length;

    final totalLinks = orientationLinks.values.fold<int>(0, (a, b) => a + b);

    int significantOrientations = 0;
    if (totalLinks > 0) {
      orientationLinks.forEach((_, count) {
        final ratio = count / totalLinks;
        if (count >= 4 && ratio >= 0.12) significantOrientations++;
      });
    }

    final endpointRatio = endpointCells / drawnCells;
    final junctionRatio = junctionCells / drawnCells;

    return _StrokeStructure(
      componentCount: significantComponents,
      orientationCount: significantOrientations,
      endpointRatio: endpointRatio,
      junctionRatio: junctionRatio,
      drawnCells: drawnCells,
    );
  }

  String _lineVarietyLabel({
    required int drawn,
    required int components,
    required double boxAreaRatio,
    required double orientationScore,
    required double endpointRatio,
    required double junctionRatio,
  }) {
    if (drawn < 80 && boxAreaRatio < 0.20) {
      return 'Simple';
    }

    if (components <= 2 && boxAreaRatio < 0.25 && junctionRatio < 0.10) {
      return 'Simple';
    }

    double score = 0;

    score += orientationScore.clamp(0.0, 1.0) * 0.18;
    score += endpointRatio.clamp(0.0, 1.0) * 0.12;
    score += junctionRatio.clamp(0.0, 1.0) * 0.32;

    score += (components >= 4 ? 0.18 : components >= 2 ? 0.08 : 0.0);
    score += boxAreaRatio.clamp(0.0, 1.0) * 0.20;

    if (components >= 2 && junctionRatio > 0.05) {
      score += 0.10;
    }

    final bool likelyRepetitive =
        components <= 2 &&
        orientationScore > 0.45 &&
        boxAreaRatio < 0.35 &&
        junctionRatio < 0.18;

    if (likelyRepetitive) {
      score -= 0.22;
    }

    if (score >= 0.72 && components >= 3 && junctionRatio >= 0.10) {
      return 'Rich';
    }

    if (score >= 0.38) {
      return 'Moderate';
    }

    return 'Simple';
  }

  List<_InsightItem> _fallbackItems() {
    return const [
      _InsightItem(
        emoji: '🎨',
        title: 'Color Use',
        value: 'Limited',
      ),
      _InsightItem(
        emoji: '🧭',
        title: 'Space Use',
        value: 'Focused',
      ),
      _InsightItem(
        emoji: '🧶',
        title: 'Line Variety',
        value: 'Simple',
      ),
      _InsightItem(
        emoji: '🟠',
        title: 'Coverage',
        value: 'Sparse',
      ),
    ];
  }

  String _colorUseLabel(int colorCount) {
    if (colorCount <= 1) return 'Limited';
    if (colorCount <= 3) return 'Balanced';
    if (colorCount <= 6) return 'Rich';
    return 'Very Rich';
  }

  String _spaceUseLabel(double boxAreaRatio) {
    if (boxAreaRatio < 0.18) return 'Focused';
    if (boxAreaRatio < 0.55) return 'Balanced';
    return 'Broad';
  }

  String _coverageLabel(double drawnRatio) {
    if (drawnRatio < 0.018) return 'Sparse';
    if (drawnRatio < 0.065) return 'Moderate';
    return 'Dense';
  }

  Future<Uint8List?> _captureInsightCard() async {
    try {
      await Future.delayed(const Duration(milliseconds: 120));
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _insightCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Insight capture error: $e');
      return null;
    }
  }

  Future<void> _shareInsightCard() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
      _cardScale = 0.97;
    });

    try {
      final pngBytes = await _captureInsightCard();

      if (pngBytes == null) {
        _showSnackBar('Could not capture insight card.');
        return;
      }

      final fileName =
          'tcp_insight_card_${DateTime.now().millisecondsSinceEpoch}.png';

      if (kIsWeb) {
        await downloadImageWeb(pngBytes, fileName);
        _showSnackBar('Insight card downloaded.');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Drawing Insight from The Color Project 🎨',
      );

      _showSnackBar('Insight card ready to share.');
    } catch (e) {
      debugPrint('Insight share error: $e');
      _showSnackBar('Something went wrong while sharing.');
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _cardScale = 1.0;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Drawing Insight',
          style: textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: FutureBuilder<List<_InsightItem>>(
        future: _insightFuture,
        builder: (context, snapshot) {
          final items = snapshot.data ?? _fallbackItems();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AnimatedScale(
                    scale: _cardScale,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    child: RepaintBoundary(
                      key: _insightCardKey,
                      child: _InsightCard(
                        drawingBytes: widget.drawingBytes,
                        items: items,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 338),
                    child: Text(
                      'This summary is for creative reflection only and is not a developmental or medical assessment.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.black.withValues(alpha: 0.55),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 338),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSharing ? null : _shareInsightCard,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.black.withValues(alpha: 0.72),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isSharing
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Sharing...'),
                                ],
                              )
                            : const Text('Share Insight Card'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Uint8List drawingBytes;
  final List<_InsightItem> items;

  const _InsightCard({
    required this.drawingBytes,
    required this.items,
  });

  String _formattedDateFull() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Widget _buildTopSignature(TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'TCP',
          textAlign: TextAlign.right,
          style: textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.80),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          'The Color Project',
          textAlign: TextAlign.right,
          style: textTheme.bodySmall?.copyWith(
            fontSize: 8.2,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 338,
      decoration: BoxDecoration(
        color: AnalyticsStore.monthlyColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: SizedBox(
          height: 610,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _buildTopSignature(textTheme),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: Image.memory(
                      drawingBytes,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Creative Pattern Summary',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_formattedDateFull()} · ${AnalyticsStore.monthlyColorName}',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 210,
                child: Column(
                  children:
                      items.map((item) => _InsightRow(item: item)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final _InsightItem item;

  const _InsightRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Text(
            item.emoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              style: textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ),
          Text(
            item.value,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StrokeStructure {
  final int componentCount;
  final int orientationCount;
  final double endpointRatio;
  final double junctionRatio;
  final int drawnCells;

  const _StrokeStructure({
    required this.componentCount,
    required this.orientationCount,
    required this.endpointRatio,
    required this.junctionRatio,
    required this.drawnCells,
  });
}

class _InsightItem {
  final String emoji;
  final String title;
  final String value;

  const _InsightItem({
    required this.emoji,
    required this.title,
    required this.value,
  });
}
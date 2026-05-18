import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'analytics_store.dart';
import 'result_screen.dart';

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key});

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  static const double _a4PortraitAspectRatio = 1 / 1.4142;

  final List<DrawPoint?> _points = [];
  final GlobalKey _canvasKey = GlobalKey();

  Size _canvasSize = Size.zero;

  Color _selectedColor = Colors.black;
  bool _isEraser = false;
  double _strokeWidth = 4;

  Color _customColor = Colors.pink;
  double _red = 255;
  double _green = 105;
  double _blue = 180;

  final List<Color> _basePalette = [
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.brown,
  ];

  List<Color> _paletteWithMonthlyColor() {
    final palette = List<Color>.from(_basePalette);
    final monthlyColor = AnalyticsStore.monthlyColor;
    final exists =
        palette.any((c) => c.toARGB32() == monthlyColor.toARGB32());
    if (!exists) {
      palette.add(monthlyColor);
    }
    return palette;
  }

  void _clearCanvas() {
    setState(() {
      _points.clear();
    });
  }

  Future<Uint8List?> _captureCanvasPng() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary =
          _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _finishDrawing() async {
    final pngBytes = await _captureCanvasPng();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(drawingBytes: pngBytes),
      ),
    );
  }

  Offset _clampToCanvas(Offset p) {
    if (_canvasSize == Size.zero) return p;

    return Offset(
      p.dx.clamp(0.0, _canvasSize.width),
      p.dy.clamp(0.0, _canvasSize.height),
    );
  }

  void _addPoint(Offset localPosition) {
    final clamped = _clampToCanvas(localPosition);

    setState(() {
      _points.add(
        DrawPoint(
          offset: clamped,
          color: _isEraser ? Colors.white : _selectedColor,
          strokeWidth: _strokeWidth,
        ),
      );
    });
  }

  Widget _buildColorButton(Color color) {
    final isSelected =
        !_isEraser && _selectedColor.toARGB32() == color.toARGB32();
    final isMonthlyColor =
        color.toARGB32() == AnalyticsStore.monthlyColor.toARGB32();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _isEraser = false;
        });
      },
      child: Container(
        width: isSelected ? 36 : 30,
        height: isSelected ? 36 : 30,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade400,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isMonthlyColor
              ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isMonthlyColor
            ? const Icon(Icons.star, size: 14, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildCustomColorButton() {
    final isSelected =
        !_isEraser && _selectedColor.toARGB32() == _customColor.toARGB32();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = _customColor;
          _isEraser = false;
        });
        _showColorEditor();
      },
      child: Container(
        width: isSelected ? 38 : 32,
        height: isSelected ? 38 : 32,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _customColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade500,
            width: isSelected ? 3 : 1.5,
          ),
        ),
        child: const Icon(
          Icons.palette,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEraserButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isEraser = true;
        });
      },
      child: Container(
        width: _isEraser ? 38 : 32,
        height: _isEraser ? 38 : 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: _isEraser ? Colors.black : Colors.grey.shade500,
            width: _isEraser ? 3 : 1.5,
          ),
        ),
        child: const Icon(
          Icons.cleaning_services,
          size: 18,
          color: Colors.black87,
        ),
      ),
    );
  }

  void _showColorEditor() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewColor = Color.fromARGB(
              255,
              _red.toInt(),
              _green.toInt(),
              _blue.toInt(),
            );

            return AlertDialog(
              title: const Text('Edit Color'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: previewColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Red'),
                    ),
                    Slider(
                      value: _red,
                      min: 0,
                      max: 255,
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setDialogState(() {
                          _red = value;
                        });
                      },
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Green'),
                    ),
                    Slider(
                      value: _green,
                      min: 0,
                      max: 255,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setDialogState(() {
                          _green = value;
                        });
                      },
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Blue'),
                    ),
                    Slider(
                      value: _blue,
                      min: 0,
                      max: 255,
                      activeColor: Colors.blue,
                      onChanged: (value) {
                        setDialogState(() {
                          _blue = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _customColor = Color.fromARGB(
                        255,
                        _red.toInt(),
                        _green.toInt(),
                        _blue.toInt(),
                      );
                      _selectedColor = _customColor;
                      _isEraser = false;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteWithMonthlyColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Draw'),
        actions: [
          IconButton(
            onPressed: _clearCanvas,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            onPressed: _finishDrawing,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Colors.orange.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AnalyticsStore.monthlyColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "This Month’s Color: ${AnalyticsStore.monthlyColorName}",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Weekly Challenge: ${AnalyticsStore.weeklyChallenge}",
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxHeight = constraints.maxHeight;
                  final maxWidth = constraints.maxWidth;

                  double canvasHeight = maxHeight;
                  double canvasWidth = canvasHeight * _a4PortraitAspectRatio;

                  if (canvasWidth > maxWidth) {
                    canvasWidth = maxWidth;
                    canvasHeight = canvasWidth / _a4PortraitAspectRatio;
                  }

                  _canvasSize = Size(canvasWidth, canvasHeight);

                  return RepaintBoundary(
                    key: _canvasKey,
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) {
                          _addPoint(details.localPosition);
                        },
                        onPanUpdate: (details) {
                          _addPoint(details.localPosition);
                        },
                        onPanEnd: (_) {
                          setState(() {
                            _points.add(null);
                          });
                        },
                        child: ClipRect(
                          child: ColoredBox(
                            color: Colors.white,
                            child: CustomPaint(
                              size: Size(canvasWidth, canvasHeight),
                              painter: DrawingPainter(
                                points: _points,
                                canvasSize: _canvasSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.grey.shade100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Palette (★ = monthly color)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...palette.map(_buildColorButton),
                      const SizedBox(width: 12),
                      _buildCustomColorButton(),
                      const SizedBox(width: 12),
                      _buildEraserButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.brush, size: 18),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 1,
                        max: 30,
                        divisions: 29,
                        label: _strokeWidth.round().toString(),
                        activeColor: _isEraser ? Colors.grey : _selectedColor,
                        onChanged: (value) {
                          setState(() {
                            _strokeWidth = value;
                          });
                        },
                      ),
                    ),
                    Text(_strokeWidth.round().toString()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DrawPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  DrawPoint({
    required this.offset,
    required this.color,
    required this.strokeWidth,
  });
}

class DrawingPainter extends CustomPainter {
  final List<DrawPoint?> points;
  final Size canvasSize;

  DrawingPainter({
    required this.points,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & canvasSize);

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        final paint = Paint()
          ..color = current.color
          ..strokeWidth = current.strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(current.offset, next.offset, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
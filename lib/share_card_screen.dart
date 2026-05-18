import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'analytics_store.dart';
import 'draw_insight_screen.dart';
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';

enum ShareCardRatio {
  a4,
  square,
  fourFive,
}

class ShareCardScreen extends StatefulWidget {
  final Uint8List? drawingBytes;

  const ShareCardScreen({
    super.key,
    this.drawingBytes,
  });

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  static const double _a4PortraitAspectRatio = 1 / 1.4142;
  static const double _squareAspectRatio = 1.0;
  static const double _fourFiveAspectRatio = 4 / 5;

  final GlobalKey _shareCardKey = GlobalKey();

  bool _isExporting = false;
  double _cardScale = 1.0;
  ShareCardRatio _selectedRatio = ShareCardRatio.a4;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  double _aspectRatioFor(ShareCardRatio ratio) {
    switch (ratio) {
      case ShareCardRatio.a4:
        return _a4PortraitAspectRatio;
      case ShareCardRatio.square:
        return _squareAspectRatio;
      case ShareCardRatio.fourFive:
        return _fourFiveAspectRatio;
    }
  }

  String _ratioLabel(ShareCardRatio ratio) {
    switch (ratio) {
      case ShareCardRatio.a4:
        return 'A4';
      case ShareCardRatio.square:
        return '1:1';
      case ShareCardRatio.fourFive:
        return '4:5';
    }
  }

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

  InputDecoration _inputDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.black.withValues(alpha: 0.38),
        fontSize: 15,
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.black.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
    );
  }

  void _showTcpSnackBar({
    required String message,
    IconData icon = Icons.check_rounded,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _captureShareCard() async {
    try {
      await Future.delayed(const Duration(milliseconds: 120));
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  Future<void> _exportAndShareCard() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
      _cardScale = 0.97;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 120));

      final pngBytes = await _captureShareCard();

      if (pngBytes == null) {
        _showTcpSnackBar(
          message: 'Could not capture the card.',
          icon: Icons.error_outline_rounded,
        );
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'tcp_share_card_$timestamp.png';

      if (kIsWeb) {
        await downloadImageWeb(pngBytes, fileName);

        _showTcpSnackBar(
          message: 'Artwork downloaded successfully.',
          icon: Icons.download_rounded,
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Created with The Color Project 🎨',
      );

      _showTcpSnackBar(
        message: 'Artwork ready to share.',
        icon: Icons.ios_share_rounded,
      );
    } catch (e) {
      debugPrint('Share error: $e');
      _showTcpSnackBar(
        message: 'Something went wrong while sharing.',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _cardScale = 1.0;
        });
      }
    }
  }

  void _openDrawingInsight() {
    if (widget.drawingBytes == null) {
      _showTcpSnackBar(
        message: 'No artwork available for insight.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrawInsightScreen(
          drawingBytes: widget.drawingBytes!,
        ),
      ),
    );
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
            letterSpacing: 0.08,
          ),
        ),
      ],
    );
  }

  Widget _buildRatioChip(ShareCardRatio ratio) {
    final isSelected = _selectedRatio == ratio;

    return ChoiceChip(
      label: Text(_ratioLabel(ratio)),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedRatio = ratio;
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      side: BorderSide.none,
      selectedColor: Colors.black,
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
        letterSpacing: -0.1,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
    );
  }

  Widget _buildCardPreview(
    TextTheme textTheme,
    double aspectRatio,
    String userName,
    String caption,
  ) {
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: widget.drawingBytes != null
                          ? Image.memory(
                              widget.drawingBytes!,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            )
                          : Container(
                              alignment: Alignment.center,
                              child: Text(
                                'No artwork yet',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 88,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_formattedDateFull()} · ${AnalyticsStore.monthlyColorName}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (userName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'by $userName',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withValues(alpha: 0.95),
                              letterSpacing: -0.04,
                            ),
                          ),
                        ],
                        if (caption.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            '"$caption"',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                              letterSpacing: -0.08,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.18),
            width: 1.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final userName = _nameController.text.trim();
    final caption = _captionController.text.trim();
    final aspectRatio = _aspectRatioFor(_selectedRatio);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Share Card',
          style: textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a shareable card',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a ratio, add your name or caption, and share your artwork as a TCP card.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: Colors.black.withValues(alpha: 0.58),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration(
                hintText: 'Your name (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              decoration: _inputDecoration(
                hintText: 'Add a short caption (optional)',
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text(
              'Card Ratio',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ShareCardRatio.values
                  .map((ratio) => _buildRatioChip(ratio))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Center(
              child: AnimatedScale(
                scale: _cardScale,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: _buildCardPreview(
                    textTheme,
                    aspectRatio,
                    userName,
                    caption,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSecondaryButton(
              onPressed: _openDrawingInsight,
              label: 'View Drawing Insight',
              icon: Icons.insights_outlined,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isExporting ? null : _exportAndShareCard,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black.withValues(alpha: 0.72),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                child: _isExporting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Sharing...'),
                        ],
                      )
                    : const Text('Share Artwork'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
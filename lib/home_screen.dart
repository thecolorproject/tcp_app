import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'admin_screen.dart';
import 'analytics_store.dart';
import 'draw_screen.dart';
import 'paper_draw_screen.dart';
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _a4PortraitAspectRatio = 1 / 1.4142;

  final GlobalKey _templateKey = GlobalKey();
  bool _isDownloadingTemplate = false;

  @override
  void initState() {
    super.initState();
    _refreshLocalState();
  }

  Future<void> _refreshLocalState() async {
    await AnalyticsStore.load();
    if (mounted) setState(() {});
  }

  void _openQuickDraw() async {
    await AnalyticsStore.incrementQuickDrawOpens();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DrawScreen()),
    );
    await _refreshLocalState();
  }

  void _openPaperDraw() async {
    await AnalyticsStore.incrementPaperDrawOpens();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaperDrawScreen()),
    );
    await _refreshLocalState();
  }

  void _openAdmin() async {
    await AnalyticsStore.load();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminScreen()),
    );
    await _refreshLocalState();
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

  Future<Uint8List?> _captureTemplatePng() async {
    try {
      await Future.delayed(const Duration(milliseconds: 120));
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _templateKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.6);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Home template capture error: $e');
      return null;
    }
  }

  Future<void> _downloadTemplate() async {
    if (_isDownloadingTemplate) return;

    setState(() {
      _isDownloadingTemplate = true;
    });

    try {
      await AnalyticsStore.load();

      final pngBytes = await _captureTemplatePng();

      if (pngBytes == null) {
        _showTcpSnackBar(
          message: 'Could not prepare the template.',
          icon: Icons.error_outline_rounded,
        );
        return;
      }

      final safeColorName = AnalyticsStore.monthlyColorName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');

      final fileName =
          'tcp_template_${safeColorName.isEmpty ? 'monthly' : safeColorName}.png';

      if (kIsWeb) {
        await downloadImageWeb(pngBytes, fileName);
        _showTcpSnackBar(
          message: 'Template downloaded successfully.',
          icon: Icons.download_rounded,
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'The Color Project Template 🎨',
      );

      _showTcpSnackBar(
        message: 'Template is ready to share.',
        icon: Icons.ios_share_rounded,
      );
    } catch (e) {
      debugPrint('Home template download error: $e');
      _showTcpSnackBar(
        message: 'Something went wrong with the template.',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingTemplate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final recentDrawings = [
      {
        'title': 'Today Drawing',
        'subtitle': 'Quick sketch',
        'icon': Icons.brush,
      },
      {
        'title': 'Circle Practice',
        'subtitle': 'Yesterday',
        'icon': Icons.radio_button_unchecked,
      },
      {
        'title': 'Color Mood',
        'subtitle': '2 days ago',
        'icon': Icons.palette_outlined,
      },
    ];

    final mutedBody = textTheme.bodyLarge?.copyWith(
      color: Colors.black.withValues(alpha: 0.58),
    );

    final mutedSmall = textTheme.bodyMedium?.copyWith(
      color: Colors.black.withValues(alpha: 0.56),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TCP Home',
          style: textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
        ],
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to TCP',
                  style: textTheme.headlineLarge?.copyWith(
                    fontSize: 30,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Draw, explore, and build your creative habit.',
                  style: mutedBody,
                ),
                const SizedBox(height: 22),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 700;

                      final leftContent = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This Month’s Theme',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: AnalyticsStore.monthlyColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "This Month’s Color: ${AnalyticsStore.monthlyColorName}",
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Weekly Challenge: ${AnalyticsStore.weeklyChallenge}",
                            style: textTheme.bodyLarge?.copyWith(
                              color: Colors.black.withValues(alpha: 0.78),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isDownloadingTemplate
                                  ? null
                                  : _downloadTemplate,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.black.withValues(alpha: 0.72),
                                disabledForegroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              icon: _isDownloadingTemplate
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.1,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded, size: 18),
                              label: Text(
                                _isDownloadingTemplate
                                    ? 'Preparing Template...'
                                    : 'Download Template',
                              ),
                            ),
                          ),
                        ],
                      );

                      final rightContent = Center(
                        child: _TemplateCardPreview(
                          color: AnalyticsStore.monthlyColor,
                          colorName: AnalyticsStore.monthlyColorName,
                          width: isNarrow ? 152 : 184,
                          compact: true,
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            leftContent,
                            const SizedBox(height: 18),
                            rightContent,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: leftContent),
                          const SizedBox(width: 18),
                          Expanded(flex: 4, child: rightContent),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 26),

                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        title: 'Quick Draw',
                        subtitle: 'Draw right now',
                        icon: Icons.draw,
                        onTap: _openQuickDraw,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        title: 'Paper Draw',
                        subtitle: 'Upload a photo',
                        icon: Icons.image_outlined,
                        onTap: _openPaperDraw,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Challenge',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AnalyticsStore.weeklyChallenge,
                        style: textTheme.bodyLarge?.copyWith(
                          color: Colors.black.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _openQuickDraw,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Start Challenge'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'Recent Drawings',
                  style: textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),

                ...recentDrawings.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(18),
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
                          child: Icon(item['icon'] as IconData, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                style: textTheme.titleMedium?.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['subtitle'] as String,
                                style: mutedSmall,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.black.withValues(alpha: 0.75),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          Positioned(
            left: -10000,
            top: 0,
            child: IgnorePointer(
              child: RepaintBoundary(
                key: _templateKey,
                child: _TemplateCardPreview(
                  color: AnalyticsStore.monthlyColor,
                  colorName: AnalyticsStore.monthlyColorName,
                  width: 794,
                  compact: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCardPreview extends StatelessWidget {
  final Color color;
  final String colorName;
  final double width;
  final bool compact;

  const _TemplateCardPreview({
    required this.color,
    required this.colorName,
    required this.width,
    this.compact = false,
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
            fontSize: compact ? 8.3 : 18,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.80),
            letterSpacing: 0.35,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          'The Color Project',
          textAlign: TextAlign.right,
          style: textTheme.bodySmall?.copyWith(
            fontSize: compact ? 6.5 : 13.5,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.62),
            letterSpacing: 0.08,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final outerRadius = compact ? 18.0 : 56.0;
    final innerRadius = compact ? 10.0 : 34.0;
    final horizontalPadding = compact ? 12.0 : 38.0;
    final topPadding = compact ? 10.0 : 30.0;
    final bottomPadding = compact ? 12.0 : 34.0;
    final cardHeight = width / (1 / 1.4142);

    final metaHeight = compact ? 42.0 : 152.0;
    final dateFontSize = compact ? 8.2 : 20.0;
    final byFontSize = compact ? 8.0 : 18.5;
    final captionFontSize = compact ? 8.5 : 19.5;

    return Container(
      width: width,
      height: cardHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(outerRadius),
        boxShadow: compact
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          topPadding,
          horizontalPadding,
          bottomPadding,
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _buildTopSignature(textTheme),
            ),
            SizedBox(height: compact ? 6 : 18),

            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerRadius),
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                ),
              ),
            ),

            SizedBox(height: compact ? 6 : 18),

            SizedBox(
              height: metaHeight,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_formattedDateFull()} · $colorName',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: dateFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 8),
                      Text(
                        'by __________________',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: byFontSize,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: -0.04,
                        ),
                      ),
                      SizedBox(height: compact ? 3 : 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '"_________________________________________________"',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            fontSize: captionFontSize,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            letterSpacing: -0.08,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 14),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
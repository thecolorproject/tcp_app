import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_store.dart';
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final GlobalKey _templateKey = GlobalKey();

  static const String _challengeTypeKey = 'tcp_challenge_type';
  static const String _affectedMetricsKey = 'tcp_challenge_affected_metrics';
  static const String _constraintNoteKey = 'tcp_challenge_constraint_note';

  final List<String> _challengeTypes = [
    'Free Drawing',
    'Constraint-based',
    'Shape-based',
    'Color-based',
    'Spatial Organization',
    'Pattern / Repetition',
  ];

  final List<String> _metricOptions = [
    'Color Count',
    'Color Variety',
    'Line Variety',
    'Space Use',
    'Coverage',
    'Shape Variety',
    'Pattern Density',
    'Boundary Control',
  ];

  late final TextEditingController _monthlyColorNameController;
  late final TextEditingController _weeklyChallengeController;
  late final TextEditingController _constraintNoteController;

  String _selectedChallengeType = 'Free Drawing';
  final Set<String> _selectedAffectedMetrics = {};

  double _red = 255;
  double _green = 127;
  double _blue = 80;

  bool _isDownloadingTemplate = false;
  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _monthlyColorNameController = TextEditingController();
    _weeklyChallengeController = TextEditingController();
    _constraintNoteController = TextEditingController();
    _loadAdminState();
  }

  @override
  void dispose() {
    _monthlyColorNameController.dispose();
    _weeklyChallengeController.dispose();
    _constraintNoteController.dispose();
    super.dispose();
  }

  void _setSlidersFromColor(Color color) {
    final argb = color.toARGB32();
    _red = ((argb >> 16) & 0xFF).toDouble();
    _green = ((argb >> 8) & 0xFF).toDouble();
    _blue = (argb & 0xFF).toDouble();
  }

  Future<void> _loadChallengeMetadata() async {
    final prefs = await SharedPreferences.getInstance();

    _selectedChallengeType =
        prefs.getString(_challengeTypeKey) ?? 'Free Drawing';

    final affectedMetrics = prefs.getStringList(_affectedMetricsKey) ?? [];

    _selectedAffectedMetrics
      ..clear()
      ..addAll(affectedMetrics);

    _constraintNoteController.text =
        prefs.getString(_constraintNoteKey) ?? '';
  }

  Future<void> _saveChallengeMetadata() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_challengeTypeKey, _selectedChallengeType);
    await prefs.setStringList(
      _affectedMetricsKey,
      _selectedAffectedMetrics.toList(),
    );
    await prefs.setString(
      _constraintNoteKey,
      _constraintNoteController.text.trim(),
    );
  }

  Future<void> _loadAdminState() async {
    await AnalyticsStore.load();
    await _loadChallengeMetadata();

    _monthlyColorNameController.text = AnalyticsStore.monthlyColorName;
    _weeklyChallengeController.text = AnalyticsStore.weeklyChallenge;
    _setSlidersFromColor(AnalyticsStore.monthlyColor);

    if (!mounted) return;
    setState(() {
      _isLoaded = true;
    });
  }

  Color get _previewColor =>
      Color.fromARGB(255, _red.toInt(), _green.toInt(), _blue.toInt());

  String get _previewColorName {
    final value = _monthlyColorNameController.text.trim();
    return value.isEmpty ? 'This Month’s Color' : value;
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

  Future<void> _saveThemeSettings() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await AnalyticsStore.updateMonthlyTheme(
        name: _monthlyColorNameController.text.trim(),
        color: _previewColor,
      );

      await AnalyticsStore.updateWeeklyChallenge(
        _weeklyChallengeController.text.trim(),
      );

      await _saveChallengeMetadata();

      await AnalyticsStore.load();
      await _loadChallengeMetadata();

      _monthlyColorNameController.text = AnalyticsStore.monthlyColorName;
      _weeklyChallengeController.text = AnalyticsStore.weeklyChallenge;
      _setSlidersFromColor(AnalyticsStore.monthlyColor);

      if (!mounted) return;
      setState(() {});

      _showTcpSnackBar(
        message: 'Theme and challenge metadata saved.',
        icon: Icons.check_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _resetAnalytics() async {
    await AnalyticsStore.reset();
    await _loadAdminState();

    _showTcpSnackBar(
      message: 'Analytics reset successfully.',
      icon: Icons.restart_alt_rounded,
    );
  }

  Future<void> _refreshAnalytics() async {
    await _loadAdminState();

    _showTcpSnackBar(
      message: 'Metrics refreshed.',
      icon: Icons.refresh_rounded,
    );
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  List<String> _generateInsights() {
    final insights = <String>[];

    if (AnalyticsStore.quickDrawOpens > AnalyticsStore.paperDrawOpens) {
      insights.add('Users prefer Quick Draw');
    } else if (AnalyticsStore.paperDrawOpens >
        AnalyticsStore.quickDrawOpens) {
      insights.add('Users are engaging with Paper Draw');
    }

    if (AnalyticsStore.paperDrawContinueRate < 0.3) {
      insights.add('Paper Draw engagement is low');
    } else if (AnalyticsStore.paperDrawContinueRate > 0.6) {
      insights.add('Paper Draw flow is working well');
    }

    if (_selectedAffectedMetrics.isNotEmpty) {
      insights.add(
        'Challenge-aware insight enabled for: ${_selectedAffectedMetrics.join(', ')}',
      );
    }

    if (AnalyticsStore.reportClicks == 0 &&
        AnalyticsStore.paperDrawOpens == 0 &&
        AnalyticsStore.quickDrawOpens == 0) {
      insights.add('Not enough data yet');
    }

    return insights;
  }

  String _buildExportSummary() {
    final totalInterest =
        AnalyticsStore.reportClicks + AnalyticsStore.freeTrialClicks;
    final insights = _generateInsights();

    return '''
TCP MVP Summary

Theme Settings
- This Month's Color: ${AnalyticsStore.monthlyColorName}
- Weekly Challenge: ${AnalyticsStore.weeklyChallenge}
- Challenge Type: $_selectedChallengeType
- Affected Metrics: ${_selectedAffectedMetrics.isEmpty ? 'None' : _selectedAffectedMetrics.join(', ')}
- Constraint Note: ${_constraintNoteController.text.trim().isEmpty ? 'None' : _constraintNoteController.text.trim()}

Metrics
- Quick Draw opens: ${AnalyticsStore.quickDrawOpens}
- Paper Draw opens: ${AnalyticsStore.paperDrawOpens}
- Full Report clicks: ${AnalyticsStore.reportClicks}
- Free Trial clicks: ${AnalyticsStore.freeTrialClicks}
- Paper Draw continue clicks: ${AnalyticsStore.paperDrawContinueClicks}
- Total interest actions: $totalInterest
- Free Trial conversion rate: ${_formatPercent(AnalyticsStore.freeTrialConversionRate)}
- Paper Draw continue rate: ${_formatPercent(AnalyticsStore.paperDrawContinueRate)}

Insights
${insights.map((e) => '- $e').join('\n')}
''';
  }

  void _showExportSummary() {
    final summary = _buildExportSummary();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export Summary'),
          content: SingleChildScrollView(
            child: SelectableText(summary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
      debugPrint('Template capture error: $e');
      return null;
    }
  }

  Future<void> _downloadPaperTemplatePng() async {
    if (_isDownloadingTemplate) return;

    await _saveThemeSettings();
    if (!mounted) return;

    setState(() {
      _isDownloadingTemplate = true;
    });

    try {
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
          'tcp_paper_template_${safeColorName.isEmpty ? 'monthly' : safeColorName}.png';

      if (kIsWeb) {
        await downloadImageWeb(pngBytes, fileName);

        _showTcpSnackBar(
          message: 'Template downloaded successfully.',
          icon: Icons.download_rounded,
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
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
      debugPrint('Template download error: $e');

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

  Widget _buildAffectedMetricChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _metricOptions.map((metric) {
        final selected = _selectedAffectedMetrics.contains(metric);

        return FilterChip(
          label: Text(metric),
          selected: selected,
          showCheckmark: false,
          selectedColor: Colors.black,
          backgroundColor: Colors.grey.shade100,
          side: BorderSide.none,
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedAffectedMetrics.add(metric);
              } else {
                _selectedAffectedMetrics.remove(metric);
              }
            });
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final totalInterest =
        AnalyticsStore.reportClicks + AnalyticsStore.freeTrialClicks;
    final insights = _generateInsights();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Analytics',
          style: textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MVP Metrics Dashboard',
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Internal product testing dashboard for TCP.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: Colors.black.withValues(alpha: 0.64),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 760;

                            final settingsColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Share Card Settings',
                                  style: textTheme.titleLarge?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _monthlyColorNameController,
                                  decoration: _inputDecoration(
                                    hintText: "This Month's Color Name",
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: _previewColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _previewColorName,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                Text(
                                  'Red',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Slider(
                                  value: _red,
                                  min: 0,
                                  max: 255,
                                  activeColor: Colors.red,
                                  onChanged: (value) {
                                    setState(() {
                                      _red = value;
                                    });
                                  },
                                ),

                                Text(
                                  'Green',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Slider(
                                  value: _green,
                                  min: 0,
                                  max: 255,
                                  activeColor: Colors.green,
                                  onChanged: (value) {
                                    setState(() {
                                      _green = value;
                                    });
                                  },
                                ),

                                Text(
                                  'Blue',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Slider(
                                  value: _blue,
                                  min: 0,
                                  max: 255,
                                  activeColor: Colors.blue,
                                  onChanged: (value) {
                                    setState(() {
                                      _blue = value;
                                    });
                                  },
                                ),

                                const SizedBox(height: 18),

                                Text(
                                  'Challenge Settings',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                TextField(
                                  controller: _weeklyChallengeController,
                                  decoration: _inputDecoration(
                                    hintText:
                                        'Weekly Challenge Title, e.g. Draw a train using 3 colors',
                                  ),
                                  maxLines: 2,
                                  onChanged: (_) => setState(() {}),
                                ),

                                const SizedBox(height: 12),

                                DropdownButtonFormField<String>(
                                  value: _selectedChallengeType,
                                  decoration: _inputDecoration(
                                    hintText: 'Challenge Type',
                                  ),
                                  items: _challengeTypes
                                      .map(
                                        (type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(type),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedChallengeType = value;
                                    });
                                  },
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  'Affected Metrics',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                _buildAffectedMetricChips(),

                                const SizedBox(height: 12),

                                TextField(
                                  controller: _constraintNoteController,
                                  decoration: _inputDecoration(
                                    hintText:
                                        'Constraint note, e.g. Color count is task-constrained to 3 colors',
                                  ),
                                  maxLines: 3,
                                  onChanged: (_) => setState(() {}),
                                ),

                                const SizedBox(height: 14),

                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.68),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.black.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Text(
                                    _selectedAffectedMetrics.isEmpty
                                        ? 'Draw Insight will treat this as a free or general drawing task.'
                                        : 'Draw Insight will interpret ${_selectedAffectedMetrics.join(', ')} in the context of this challenge.',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.black.withValues(alpha: 0.68),
                                      height: 1.35,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isSaving ? null : _saveThemeSettings,
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
                                    ),
                                    child: Text(
                                      _isSaving
                                          ? 'Saving...'
                                          : 'Save Theme & Challenge',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isDownloadingTemplate
                                        ? null
                                        : _downloadPaperTemplatePng,
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
                                    ),
                                    child: _isDownloadingTemplate
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.1,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Colors.white,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Text('Preparing Template...'),
                                            ],
                                          )
                                        : const Text('Download Template PNG'),
                                  ),
                                ),
                              ],
                            );

                            final previewColumn = Center(
                              child: _AdminTemplateCardPreview(
                                color: _previewColor,
                                colorName: _previewColorName,
                                width: isNarrow ? 170 : 210,
                                compact: true,
                              ),
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  settingsColumn,
                                  const SizedBox(height: 18),
                                  previewColumn,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: settingsColumn),
                                const SizedBox(width: 18),
                                Expanded(flex: 4, child: previewColumn),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.purple.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Insights',
                              style: textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...insights.map(
                              (text) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• $text'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      _MetricCard(
                        title: 'Quick Draw opens',
                        value: AnalyticsStore.quickDrawOpens.toString(),
                        icon: Icons.draw,
                      ),
                      _MetricCard(
                        title: 'Paper Draw opens',
                        value: AnalyticsStore.paperDrawOpens.toString(),
                        icon: Icons.image_outlined,
                      ),
                      _MetricCard(
                        title: 'Full Report clicks',
                        value: AnalyticsStore.reportClicks.toString(),
                        icon: Icons.description_outlined,
                      ),
                      _MetricCard(
                        title: 'Free Trial clicks',
                        value: AnalyticsStore.freeTrialClicks.toString(),
                        icon: Icons.payments_outlined,
                      ),
                      _MetricCard(
                        title: 'Paper Draw continue clicks',
                        value:
                            AnalyticsStore.paperDrawContinueClicks.toString(),
                        icon: Icons.arrow_forward,
                      ),
                      _MetricCard(
                        title: 'Total interest actions',
                        value: totalInterest.toString(),
                        icon: Icons.insights_outlined,
                      ),
                      _MetricCard(
                        title: 'Free Trial conversion rate',
                        value: _formatPercent(
                          AnalyticsStore.freeTrialConversionRate,
                        ),
                        icon: Icons.trending_up,
                      ),
                      _MetricCard(
                        title: 'Paper Draw continue rate',
                        value: _formatPercent(
                          AnalyticsStore.paperDrawContinueRate,
                        ),
                        icon: Icons.analytics_outlined,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _showExportSummary,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Export Summary'),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _refreshAnalytics,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Refresh Metrics'),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _resetAnalytics,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Reset Analytics'),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: -10000,
            top: 0,
            child: IgnorePointer(
              child: RepaintBoundary(
                key: _templateKey,
                child: _AdminTemplateCardPreview(
                  color: _previewColor,
                  colorName: _previewColorName,
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

class _AdminTemplateCardPreview extends StatelessWidget {
  final Color color;
  final String colorName;
  final double width;
  final bool compact;

  const _AdminTemplateCardPreview({
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
                          '________________________',
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
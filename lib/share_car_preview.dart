import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'analytics_store.dart';

enum ShareCardRatio {
  a4,
  square,
  fourFive,
}

class ShareCardPreview extends StatelessWidget {
  final Uint8List? drawingBytes;
  final String userName;
  final String caption;
  final ShareCardRatio ratio;
  final bool compact;
  final double width;

  const ShareCardPreview({
    super.key,
    required this.drawingBytes,
    required this.userName,
    required this.caption,
    this.ratio = ShareCardRatio.a4,
    this.compact = false,
    this.width = 338,
  });

  static const double _a4PortraitAspectRatio = 1 / 1.4142;
  static const double _squareAspectRatio = 1.0;
  static const double _fourFiveAspectRatio = 4 / 5;

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
            fontSize: compact ? 8.5 : 10.5,
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
            fontSize: compact ? 6.8 : 8.2,
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
    final aspectRatio = _aspectRatioFor(ratio);

    final cardHeight = compact ? 260.0 : 610.0;
    final horizontalPadding = compact ? 12.0 : 16.0;
    final topPadding = compact ? 10.0 : 14.0;
    final bottomPadding = compact ? 12.0 : 16.0;
    final imageRadius = compact ? 10.0 : 14.0;
    final metaHeight = compact ? 42.0 : 88.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AnalyticsStore.monthlyColor,
        borderRadius: BorderRadius.circular(compact ? 18 : 24),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          topPadding,
          horizontalPadding,
          bottomPadding,
        ),
        child: SizedBox(
          height: cardHeight,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _buildTopSignature(textTheme),
              ),
              SizedBox(height: compact ? 6 : 8),

              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(imageRadius),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: drawingBytes != null
                          ? Image.memory(
                              drawingBytes!,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            )
                          : const SizedBox(),
                    ),
                  ),
                ),
              ),

              SizedBox(height: compact ? 6 : 8),

              SizedBox(
                height: metaHeight,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_formattedDateFull()} · ${AnalyticsStore.monthlyColorName}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: compact ? 8.5 : 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (userName.trim().isNotEmpty) ...[
                          SizedBox(height: compact ? 2 : 3),
                          Text(
                            'by ${userName.trim()}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: compact ? 8.2 : 13,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withValues(alpha: 0.95),
                              letterSpacing: -0.04,
                            ),
                          ),
                        ],
                        if (caption.trim().isNotEmpty) ...[
                          SizedBox(height: compact ? 3 : 5),
                          Text(
                            '"${caption.trim()}"',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge?.copyWith(
                              fontSize: compact ? 8.8 : 14,
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
}
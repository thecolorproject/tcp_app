import 'package:flutter/material.dart';

class PaperTemplateWidget extends StatelessWidget {
  final Color color;
  final String colorName;
  final bool previewMode;

  const PaperTemplateWidget({
    super.key,
    required this.color,
    required this.colorName,
    this.previewMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        final titleSize = previewMode ? h * 0.045 : h * 0.032;
        final textSize = previewMode ? h * 0.024 : h * 0.018;
        final outerPad = previewMode ? w * 0.06 : w * 0.035;
        final gapSmall = h * 0.012;
        final gapMedium = h * 0.02;

        return Container(
          color: color,
          child: Padding(
            padding: EdgeInsets.all(outerPad),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'The Color Project',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: gapMedium),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: gapMedium),
                _CenteredTemplateLine(
                  text: 'Date: ____________________________',
                  fontSize: textSize,
                ),
                SizedBox(height: gapSmall),
                _CenteredTemplateLine(
                  text: "This Month's Color: $colorName",
                  fontSize: textSize,
                ),
                SizedBox(height: gapSmall),
                _CenteredTemplateLine(
                  text: 'Your Name: ______________________',
                  fontSize: textSize,
                ),
                SizedBox(height: gapSmall),
                _CenteredTemplateLine(
                  text: 'Caption: _________________________________',
                  fontSize: textSize,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CenteredTemplateLine extends StatelessWidget {
  final String text;
  final double fontSize;

  const _CenteredTemplateLine({
    required this.text,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
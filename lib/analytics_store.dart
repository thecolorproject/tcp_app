import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsStore {
  // ======================
  // Metrics
  // ======================
  static int quickDrawOpens = 0;
  static int paperDrawOpens = 0;
  static int reportClicks = 0;
  static int freeTrialClicks = 0;
  static int paperDrawContinueClicks = 0;

  // ======================
  // Theme
  // ======================
  static String monthlyColorName = 'Cheek Pink';
  static String monthlyColorHex = 'FFFF7F50'; // ARGB (8자리 고정)
  static String weeklyChallenge = 'Draw a train using 3 colors';

  // ======================
  // Color getter (안전)
  // ======================
  static Color get monthlyColor {
    try {
      return Color(int.parse(monthlyColorHex, radix: 16));
    } catch (_) {
      return const Color(0xFFFF7F50);
    }
  }

  // ======================
  // Load (항상 최신값)
  // ======================
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    quickDrawOpens = prefs.getInt('quickDrawOpens') ?? 0;
    paperDrawOpens = prefs.getInt('paperDrawOpens') ?? 0;
    reportClicks = prefs.getInt('reportClicks') ?? 0;
    freeTrialClicks = prefs.getInt('freeTrialClicks') ?? 0;
    paperDrawContinueClicks =
        prefs.getInt('paperDrawContinueClicks') ?? 0;

    monthlyColorName =
        prefs.getString('monthlyColorName') ?? 'Cheek Pink';

    monthlyColorHex =
        prefs.getString('monthlyColorHex') ?? 'FFFF7F50';

    weeklyChallenge =
        prefs.getString('weeklyChallenge') ??
            'Draw a train using 3 colors';

    // 🔥 안전장치: HEX 길이 보정
    if (monthlyColorHex.length != 8) {
      monthlyColorHex = 'FFFF7F50';
      await prefs.setString('monthlyColorHex', monthlyColorHex);
    }
  }

  // ======================
  // Save
  // ======================
  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('quickDrawOpens', quickDrawOpens);
    await prefs.setInt('paperDrawOpens', paperDrawOpens);
    await prefs.setInt('reportClicks', reportClicks);
    await prefs.setInt('freeTrialClicks', freeTrialClicks);
    await prefs.setInt(
        'paperDrawContinueClicks', paperDrawContinueClicks);

    await prefs.setString('monthlyColorName', monthlyColorName);
    await prefs.setString('monthlyColorHex', monthlyColorHex);
    await prefs.setString('weeklyChallenge', weeklyChallenge);
  }

  // ======================
  // Increment
  // ======================
  static Future<void> incrementQuickDrawOpens() async {
    quickDrawOpens++;
    await save();
  }

  static Future<void> incrementPaperDrawOpens() async {
    paperDrawOpens++;
    await save();
  }

  static Future<void> incrementReportClicks() async {
    reportClicks++;
    await save();
  }

  static Future<void> incrementFreeTrialClicks() async {
    freeTrialClicks++;
    await save();
  }

  static Future<void> incrementPaperDrawContinueClicks() async {
    paperDrawContinueClicks++;
    await save();
  }

  // ======================
  // Theme Update (핵심 수정)
  // ======================
  static Future<void> updateMonthlyTheme({
    required String name,
    required Color color,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    monthlyColorName =
        name.trim().isEmpty ? 'Cheek Pink' : name.trim();

    // 🔥 핵심: 항상 8자리 HEX 유지 (ARGB)
    monthlyColorHex =
    color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();

    await prefs.setString('monthlyColorName', monthlyColorName);
    await prefs.setString('monthlyColorHex', monthlyColorHex);
  }

  static Future<void> updateWeeklyChallenge(String value) async {
    final prefs = await SharedPreferences.getInstance();

    weeklyChallenge = value.trim().isEmpty
        ? 'Draw a train using 3 colors'
        : value.trim();

    await prefs.setString('weeklyChallenge', weeklyChallenge);
  }

  // ======================
  // Reset
  // ======================
  static Future<void> reset() async {
    quickDrawOpens = 0;
    paperDrawOpens = 0;
    reportClicks = 0;
    freeTrialClicks = 0;
    paperDrawContinueClicks = 0;

    monthlyColorName = 'Cheek Pink';
    monthlyColorHex = 'FFFF7F50';
    weeklyChallenge = 'Draw a train using 3 colors';

    await save();
  }

  // ======================
  // Metrics
  // ======================
  static double get freeTrialConversionRate {
    if (reportClicks == 0) return 0;
    return freeTrialClicks / reportClicks;
  }

  static double get paperDrawContinueRate {
    if (paperDrawOpens == 0) return 0;
    return paperDrawContinueClicks / paperDrawOpens;
  }
}
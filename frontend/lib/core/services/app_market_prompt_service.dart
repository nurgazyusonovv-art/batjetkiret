import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

class AppMarketPromptService {
  AppMarketPromptService._();

  static const _defaultPlayUrl =
      'https://play.google.com/store/apps/details?id=kg.batkenexpress.app';
  static const _launchCountKey = 'market_prompt_launch_count';
  static const _ratedKey = 'market_prompt_rated';
  static const _lastRatingPromptAtKey = 'market_prompt_last_rating_at';
  static const _lastUpdatePromptCodeKey = 'market_prompt_last_update_code';

  static bool _sessionChecked = false;
  static bool _showingDialog = false;

  static Future<void> checkAndShow(BuildContext context) async {
    if (_sessionChecked ||
        _showingDialog ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _sessionChecked = true;

    final settings = await _loadSettings();
    if (settings == null || !context.mounted) return;

    final updateShown = await _maybeShowUpdateDialog(context, settings);
    if (updateShown || !context.mounted) return;

    await _maybeShowRatingDialog(context, settings);
  }

  static Future<Map<String, dynamic>?> _loadSettings() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.baseUrl}/admin/public-settings'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _maybeShowUpdateDialog(
    BuildContext context,
    Map<String, dynamic> settings,
  ) async {
    final latestCode = int.tryParse(
      settings['android_latest_version_code']?.toString() ?? '',
    );
    if (latestCode == null || latestCode <= 0) return false;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    if (latestCode <= currentCode) return false;

    final prefs = await SharedPreferences.getInstance();
    final required = _boolSetting(settings['android_update_required']);
    final lastPromptedCode = prefs.getInt(_lastUpdatePromptCodeKey) ?? 0;
    if (!required && lastPromptedCode == latestCode) return false;

    await prefs.setInt(_lastUpdatePromptCodeKey, latestCode);
    if (!context.mounted) return true;

    final playUrl = _stringSetting(
      settings['play_market_url'],
      _defaultPlayUrl,
    );
    _showingDialog = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !required,
        builder: (ctx) => AlertDialog(
          title: const Text('Жаңы версия чыкты'),
          content: const Text(
            'Тиркеменин жаңы версиясы даяр. Жакшыраак жана туруктуураак иштеши үчүн Play Marketтен жаңыртып алыңыз.',
          ),
          actions: [
            if (!required)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Кийинчерээк'),
              ),
            ElevatedButton(
              onPressed: () async {
                await _openPlayMarket(playUrl);
                if (ctx.mounted && !required) Navigator.of(ctx).pop();
              },
              child: const Text('Жүктөп алуу'),
            ),
          ],
        ),
      );
    } finally {
      _showingDialog = false;
    }
    return true;
  }

  static Future<void> _maybeShowRatingDialog(
    BuildContext context,
    Map<String, dynamic> settings,
  ) async {
    if (!_boolSetting(settings['rating_dialog_enabled'], defaultValue: true)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_ratedKey) == true) return;

    final launchCount = (prefs.getInt(_launchCountKey) ?? 0) + 1;
    await prefs.setInt(_launchCountKey, launchCount);

    final minLaunches =
        int.tryParse(
          settings['rating_prompt_min_launches']?.toString() ?? '',
        ) ??
        3;
    if (launchCount < minLaunches) return;

    final cooldownDays =
        int.tryParse(
          settings['rating_prompt_cooldown_days']?.toString() ?? '',
        ) ??
        14;
    final lastPromptAt = prefs.getInt(_lastRatingPromptAtKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownMs = Duration(days: cooldownDays).inMilliseconds;
    if (lastPromptAt > 0 && now - lastPromptAt < cooldownMs) return;

    if (!context.mounted) return;
    final playUrl = _stringSetting(
      settings['play_market_url'],
      _defaultPlayUrl,
    );
    _showingDialog = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Бизди баалап коюңуз'),
          content: const Text(
            'Эгер тиркеме сизге пайдалуу болуп жатса, Play Marketте баа берип коюңуз. Бул бизге чоң жардам болот.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setInt(_lastRatingPromptAtKey, now);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Кийинчерээк'),
            ),
            ElevatedButton(
              onPressed: () async {
                await prefs.setBool(_ratedKey, true);
                await _openPlayMarket(playUrl);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Баалоо'),
            ),
          ],
        ),
      );
    } finally {
      _showingDialog = false;
    }
  }

  static bool _boolSetting(dynamic value, {bool defaultValue = false}) {
    final text = value?.toString().toLowerCase().trim();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return defaultValue;
  }

  static String _stringSetting(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static Future<void> _openPlayMarket(String url) async {
    final uri = Uri.tryParse(url) ?? Uri.parse(_defaultPlayUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

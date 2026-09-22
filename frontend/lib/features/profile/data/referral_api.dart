import 'dart:convert';

import 'package:frontend/core/config.dart';
import 'package:http/http.dart' as http;

/// What the user's invite code has brought in.
class ReferralSummary {
  const ReferralSummary({
    required this.code,
    required this.invitedCount,
    required this.earned,
    required this.bonus,
  });

  /// The code to share — the user's own id, e.g. "BJ000123".
  final String code;
  final int invitedCount;
  final double earned;

  /// What one successful invite pays right now.
  final double bonus;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return ReferralSummary(
      code: (json['code'] ?? '').toString(),
      invitedCount: (json['invited_count'] as num?)?.toInt() ?? 0,
      earned: asDouble(json['earned']),
      bonus: asDouble(json['bonus']),
    );
  }
}

class ReferralApi {
  Future<ReferralSummary?> fetch(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/users/me/referrals'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      return ReferralSummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}

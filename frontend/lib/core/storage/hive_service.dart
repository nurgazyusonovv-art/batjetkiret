import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String _courierStatusBoxName = 'courier_status';
  static const String _courierOnlineKey = 'courier_online';

  /// Initialize Hive and open required boxes
  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(_courierStatusBoxName);
  }

  /// Save courier online status to local Hive storage
  static Future<void> saveCourierOnlineStatus(bool isOnline) async {
    final box = Hive.box(_courierStatusBoxName);
    await box.put(_courierOnlineKey, isOnline);
  }

  /// Get courier online status from local Hive storage
  static bool getCourierOnlineStatus() {
    final box = Hive.box(_courierStatusBoxName);
    return box.get(_courierOnlineKey, defaultValue: false) as bool;
  }

  /// Clear all courier status data
  static Future<void> clearCourierStatus() async {
    final box = Hive.box(_courierStatusBoxName);
    await box.clear();
  }
}

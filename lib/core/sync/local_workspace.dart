import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_helper.dart';
import 'firebase_config.dart';

/// Workspace ownership survives logout; this stores no authentication tokens.
class LocalWorkspace {
  static String get _key => 'planner.${FirebaseConfig.projectId}.workspace';

  static Future<void> restore(String? authenticatedId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final id =
        authenticatedId ??
        (saved != null && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(saved)
            ? saved
            : null);
    await select(id);
  }

  static Future<void> select(String? id) async {
    await DatabaseHelper.instance.switchAccount(id);
    final prefs = await SharedPreferences.getInstance();
    final saved = id == null
        ? await prefs.remove(_key)
        : await prefs.setString(_key, id);
    if (!saved) throw StateError('Could not remember local workspace');
  }
}

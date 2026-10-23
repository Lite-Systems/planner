// Firebase client configuration is public. Database access is enforced by
// Firebase ID tokens and firestore.rules, never by hiding this API key.
class FirebaseConfig {
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'smart-planner-lite-705372',
  );
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyAgRekdPITuwVHqNSQqD1OXcnJyPS8gkME',
  );
  static const authEmulator = String.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_HOST',
  );
  static const firestoreEmulator = String.fromEnvironment(
    'FIRESTORE_EMULATOR_HOST',
  );
  static const enabled = bool.fromEnvironment(
    'FIREBASE_ENABLED',
    defaultValue: true,
  );
  static bool get configured =>
      enabled && projectId.isNotEmpty && apiKey.isNotEmpty;
}

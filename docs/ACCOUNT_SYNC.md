# Firebase accounts and sync — free Spark plan

The app uses Firebase Authentication (email/password) and Cloud Firestore. No
Supabase, paid Cloud Functions, Firebase Storage, or custom API server is required.
Firebase's documented REST APIs work on Android, iPhone, macOS, and Windows while
SQLite remains the offline database. Sessions and refresh tokens use the operating
system's secure credential storage; passwords are never persisted by the app.

## Enable the live project

The checked-in configuration and CLI default now point to **Smart Planner**
(`smart-planner-lite-705372`), owned by `hanynady553@gmail.com`. The default Firestore
database uses `europe-west1` (Belgium), Standard edition, with its free tier
enabled and billing disabled. Private rules and indexes are deployed. Android,
Apple, and desktop app registrations belong to this project.

Console: https://console.firebase.google.com/project/smart-planner-lite-705372/overview

Email/password Authentication is initialized and enabled. Its provider
configuration is declared in `firebase.json`; the current Firebase CLI supports
applying it with `firebase deploy --only auth`. The old system CLI v13 does not
support that target; use a current CLI for authentication-provider deployment.

1. Sign into the correct account with `firebase login:add` / `firebase login:use`.
2. In the Firebase console, keep the project on **Spark**. Enable Authentication →
   Sign-in method → **Email/Password**.
3. Create the default **Cloud Firestore** database in production mode. Choose the
   intended region before creating it; do not enable billing, Storage, or Functions.
4. Deploy only this feature's rules/indexes:

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes --project smart-planner-lite-705372
   ```

   The rules grant each signed-in user access only to their own planner namespace;
   never replace them with test-mode public access.
5. Run the app normally: `flutter run`. For another project, pass its public
   Firebase web API key and project ID in each mobile/desktop build:

   ```sh
   flutter run --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT --dart-define=FIREBASE_API_KEY=YOUR_PUBLIC_API_KEY
   ```

   Firebase client API keys are public identifiers. User ID tokens and Firestore
   rules protect data. Never put a service-account credential in the app.

Settings → Account & Sync offers **Create account**, **Sign in**, **Forgot
password**, **Sync now**, conflict review, sign-out, and account deletion. Guest
use remains available. **Log out of Firebase** clears authentication credentials
and stops cloud requests without changing the current database. Projects, tasks,
finances, notes, and settings remain usable on the device, including after an app
restart. The app labels this state **Signed out — working locally**. Local edits
and deletions remain in the same account's durable journal; signing back into that
account resumes synchronization and conflict review. Signing into a different
account opens its separate database and never uploads the previous workspace.
The remembered workspace ID contains no credentials. Existing guest data remains
separate and can still be merged through the device-data import flow.

## Portable database backups

Settings → Database Backup exports/imports the active planner as a standalone
SQLite `.db` file. A transaction reads the records and account preferences from
one consistent local snapshot. Exports exclude sessions, ownership, upload queues,
cloud cursors, tombstones, triggers, and pending conflict decisions. File paths
remain local references; the database backup does not package attachment files.

While signed in, export refreshes Firebase first. If sync fails, leaves pending
changes, or needs conflict review, the app offers a clearly labeled local snapshot
instead; its filename contains `local_backup`. Signed-out exports also use that
label. Exporting does not require Firebase's paid managed export service.

Import validates SQLite integrity and the planner schema, then saves a durable
safety backup under the application-support `before_database_import` directory.
It merges business records into the current database without importing another
account's synchronization metadata. Older backups can omit newer optional fields;
the active schema supplies defaults. Missing required fields or parent records
reject the merge atomically. Identical records are skipped.

Different versions and deleted records are staged for review while the current
data remains unchanged. Related changed records are reviewed as one group, so
rejecting a deleted project cannot create orphan tasks. Choose the current device
or imported backup version from Account & Sync, including while signed out.
Another import is blocked until existing conflicts are resolved. Cloud exchange
waits while backup choices remain unresolved, then resumes normally. Imports and
exports pause the sync coordinator during database access; account switching is
blocked during the operation. No app restart is required after a successful import.

## Free-tier behavior

- Free Firestore quotas currently include 1 GiB stored data, 50,000 reads/day,
  20,000 writes/day, and 20,000 deletes/day, shared by the whole project. When a
  quota blocks sync, local edits remain saved and retry later.
- Images and attachments stay **on each device**. Their absolute file paths are
  excluded from Firestore and an incoming record preserves that device's files.
  Firebase Cloud Storage requires Blaze, so this implementation does not use it.
- Currency, hourly rates, and print preferences sync. Biometrics, language, theme,
  notification permissions, and desktop options remain local.
- A related project upload supports up to 400 changed records per transaction.
  Larger pending groups stay saved locally and show a limit message.
- Local edits enter a SQLite journal in the same transaction as their model rows.
  Firestore atomic commits use update-time preconditions to allocate cloud
  versions and reject stale edits. They work with ordinary Firebase user tokens,
  without granting database IAM permissions to end users. Deletion
  markers prevent old offline devices from recreating deleted records. Projects
  and linked payments resolve together; unrelated projects continue syncing.
- Sync runs after edits, app resume, manual refresh, and a 30-second retry while
  the app is open. An unchanged cloud head costs a small read instead of
  downloading the whole account. Suspended/closed apps sync when reopened.
- Guest import makes a local backup before merging. Backup imports preserve cloud
  versions and deletion markers, and create new local mutations only after an
  imported version is accepted. Signed-out imports wait for the same account to reconnect.
- Account deletion asks for the password again, blocks writes, deletes cloud
  planner records, and deletes Firebase Auth. It keeps only a minimal deletion
  marker to block unexpired tokens on other devices. Retry interrupted deletion.
  Guest data, local files, exported backups, and other devices' offline copies
  remain independent.

See the current provider limits and API references:
https://firebase.google.com/pricing
https://firebase.google.com/docs/firestore/quotas
https://firebase.google.com/docs/reference/rest/auth
https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024

## Verify without touching the live project

```sh
flutter analyze
flutter test
firebase emulators:exec --only auth,firestore --project demo-smart-planner 'flutter test test/firebase_account_integration_test.dart --dart-define=FIREBASE_PROJECT_ID=demo-smart-planner --dart-define=FIREBASE_API_KEY=demo-key --dart-define=FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1:8080'
```

The integration test uses real Auth and Firestore emulators, including the actual
Firestore rules. It covers registration, restored sessions, password reset, token
refresh, cross-device sync, conflicts, private access, and account deletion. It
skips unless both emulator hosts are explicitly supplied. It also covers portable
backup import reaching a second device, logout with local edits and restart,
reconnection, and the separate destructive deletion path. Do not set emulator
hosts in production builds. Password-reset email delivery requires a live check.

To run a deliberate live smoke check after Authentication is enabled:

```sh
flutter test test/firebase_live_smoke_test.dart --dart-define=LIVE_FIREBASE_CHECK=true
```

It creates temporary accounts, verifies registration/sign-in and real cross-device
record sync, checks that another account is denied access, then deletes the test
accounts and their records. It sends no emails and skips during normal tests.

Live verification on 2026-10-23 passed registration, sign-in, restored sessions,
phone/desktop data exchange, concurrent updates, cross-account read denial, and
account deletion. The temporary live accounts were removed; billing was rechecked
and remained disabled. Live password-reset email delivery was not exercised.

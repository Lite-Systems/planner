# Smart Planner

[**التوثيق بالعربية / Documentation in Arabic**](./docs/DOCUMENTATION_AR.md)

Smart Planner is a comprehensive freelance, project, task, and finance management app built with Flutter. It combines project tracking, time billing, income/expense management, wallets, reminders, PDF invoicing, voice input, backup/restore, and full Arabic/English localization in one offline-first app.

- **App name:** Smart Planner
- **Package:** `planner` · **Version:** 1.0.0+8
- **Bundle ID (iOS):** `com.litesystems.smartplanner`
- **UI:** Responsive Cupertino with shared navy/orange styling, light/dark themes and top-bar module navigation (no sidebar)
- **Platforms:** Android, iOS, Web, macOS, Windows, Linux

## Optional accounts and sync

Email/password accounts and private cross-device sync use Firebase Authentication
and Cloud Firestore on the free Spark plan. Projects, tasks, finances, notes, and
selected preferences save locally first; images and attachments remain on each
device. Accounts are optional. See [Firebase setup](docs/ACCOUNT_SYNC.md) for the
security rules, project configuration, and verification. Free hosting has quotas.

## Features

### Home Dashboard
- Welcome header with responsive wallet, pending, income and net-balance cards
- Task progress card (total / pending / in-progress with completion %)
- Live USD exchange-rate widget (USD → EGP / SAR) with manual refresh and last-update timestamp
- Compact wallet previews
- Active timers list with per-second elapsed-label updates
- Recent projects, recent income (3), and recent expenses (3) previews

### Projects
- Project list with live search, status filter, and sorting
- Add/edit projects: name, description, customer, end date, status, cover image (gallery/camera) or icon cover
- Project detail screen: cover header, progress, totals (cost / paid / remaining), members avatars, task list
- Project cards with cover, progress bar, task counts, and amounts
- Per-project invoice: **print, share, save, and preview as PDF**

### Tasks
- Full task editor: name, details, cost + currency, start/end dates, status (`To Do` / `In Progress` / `Done`), type (`New Feature` / `Bug` / `Enhancement`)
- Paid tracking with payment-method selection — marking a task paid **auto-creates an income record**; unpaying removes it
- Built-in time tracker: start/pause timer, accumulated time-spent, hourly rate with automatic cost calculation, timer start/end range, estimated vs. actual time
- Subtasks checklist with CRUD
- File and image attachments (persisted locally)
- Team members per project (name, phone, email, color avatar) with task assignment
- Task reminders: automatic local notification scheduling on start date
- Bulk archive (only done + paid tasks are archivable), archive screen with restore, per-project grouping, totals, and **print/share archive PDF**

### Voice Task Creation
- Speech-to-text bottom sheet with pulsing mic and waveform animation
- Bilingual parsing (English + Arabic): detects subtask markers (`with subtasks`, `مع المهام الفرعية`, …) and delimiters (`,`, `،`, `and`, `then`, `ثم`, `و`)
- Live transcript plus parsed task/subtask preview with manual editing before saving
- Locale-aware recognition (`ar-EG` / `en-US`)

### To-Do Aggregator (optional module)
- Cross-project view of all active tasks sorted by start date, grouped with project labels
- Status filter (`All` / `To Do` / `In Progress` / `Done`), tap to edit
- Can be toggled on/off in Settings

### Income Management
- Income list with category and month filters, totals header
- Add/edit income: title, amount + currency, date, category, payment method, note, optional linked task
- Income categories with CRUD (name, color, icon); delete blocked when in use
- Default seeded categories: Projects, Freelance, Other

### Expense Management (optional module)
- Month + category filters, total badge, count, grouped list
- Add/edit expenses with the same fields as income
- Expense categories with CRUD and usage-guarded delete
- Default seeded categories: Tools & Software, Subscriptions, Office, Travel, Other
- Pie-chart breakdown by category (`fl_chart`)

### Wallets / Payment Methods
- Wallet types: `cash` / `visa` / `bank` with name, color, auto icon, card number, starting balance
- Live per-wallet balance = starting balance + income − expenses (with currency conversion)
- Delete blocked when the wallet is referenced by tasks, income, or expenses

### Finance & Currencies
- Three currencies everywhere: `EGP`, `USD`, `SAR` (separate display currency for expenses)
- Live exchange rates from `open.er-api.com` with USD-pivot conversion
- Configurable hourly cost default for time billing
- Amount privacy mode (`hideAmounts` masks all money as `••••`)
- Consistent `formatMoney` / `convert` helpers across UI, PDFs, and balances

## Services

| Service | File | What it does |
|---|---|---|
| `DatabaseHelper` | `lib/core/services/database_helper.dart` | Singleton SQLite (`planner.db`, v21, legacy `masrofy.db` auto-migrated). 9 tables: projects, tasks, members, task-assignees, payment methods, income, income categories, expenses, expense categories. Full CRUD + usage counters + reset. Desktop uses `sqflite_common_ffi`. |
| `DatabaseBackupService` | `lib/core/services/database_backup_service.dart` | WAL checkpoint + copy, share backup (`.db` via `share_plus`), save-to-storage picker, import picker with validation (must contain `projects` + `tasks`), safe database replacement. |
| `PdfService` | `lib/core/services/pdf_service.dart` | A4 RTL/LTR invoices with Arabic Almarai font, app logo, header (project/customer/date), summary tables, per-task cards (price, paid badge, type badge, time-spent, dates, timer range, subtasks checklist), page footer, draft watermark. Print / share / save / preview. Content toggles for hour-cost, task time, task type, subtasks. |
| `NotificationService` | `lib/core/services/notification_service.dart` | `flutter_local_notifications` + `timezone`. Init (Android + iOS, permission request), task-due reminders (start date + 1h, skipped if past), cancel on update/delete/complete/archive. |
| `CurrencyService` | `lib/core/services/currency_service.dart` | Fetches latest USD → EGP/SAR rates from `https://open.er-api.com/v6/latest/USD` (8s timeout, null-safe fallback to saved rates). |
| `BiometricService` | `lib/core/services/biometric_service.dart` | `local_auth` authentication (`canCheckBiometrics \|\| isDeviceSupported`, device PIN fallback allowed, persists across backgrounding). |

Supporting utilities: `currency_helper` (normalize/format/convert/symbols), `speech_parser` (bilingual voice parsing), `file_persist` (persist picked images), `app_layout` (600/1024 breakpoints, responsive content, sheets, desktop scroll behavior), `app_thems` (Cupertino light/dark themes), `app_tokens`/`app_colors` (shared design tokens), `app_navigation_bar`/`app_list_section` (consistent page headers and grouped panels), `enums`, `icon_utils`, `restart_widget` (full restart after restore/reset), `app_lock_gate` (auto-lock overlay).

## App Protection & Settings

- Optional biometric/PIN app lock with auto-lock when the app goes to background (`AppLockGate`)
- Compact splash screen with settings preload and saved-locale restore; no artificial animation delay
- Settings screen: language, dark mode, biometric lock, hide amounts, module toggles (expenses, todos), currencies, hourly cost, USD rates, print-content toggles, desktop options (compact density, remember last section, keyboard shortcuts), backup/restore/reset
- Top-bar icons switch modules on phones and desktops and stay available in editors; disabled modules are omitted
- Desktop keyboard shortcuts: `Ctrl/Cmd + N` (new item), `Ctrl/Cmd + 1..6` (switch visible module), `Esc` (back/close local popup)
- Update prompt via `upgrader`, version footer in Settings

## Localization

- `easy_localization` with `assets/translations/ar.json` (~317 keys) + `en.json` (~318 keys), fallback locale Arabic
- Full RTL mirroring for Arabic, including PDFs
- Almarai Arabic font bundled (`assets/fonts/Almarai-Regular.ttf`)
- Language switch in Settings with confirm dialog, provider reload, and return-to-home

## Tech Stack

| Package | Purpose |
|---|---|
| `flutter`, `cupertino_icons` | CupertinoApp UI |
| `provider` | State management (Settings, Wallet, Project, Expenses, Income, Locale) |
| `easy_localization` | Arabic/English i18n |
| `sqflite`, `sqflite_common_ffi` | Local SQLite (+ desktop FFI) |
| `path_provider`, `path` | DB / docs / temp paths |
| `intl` | Date/number formatting (UI + PDF) |
| `fl_chart` | Expense pie chart |
| `local_auth` | Biometric app lock |
| `pdf`, `printing` | Invoice PDF generation/print |
| `uuid` | Entity IDs |
| `shared_preferences` | Settings/locale persistence |
| `flutter_animate` | Splash, mic, and list animations |
| `speech_to_text` | Voice task creation |
| `flutter_local_notifications`, `timezone` | Task reminders |
| `image_picker` | Project covers, task attachments |
| `file_picker`, `share_plus` | Backup save/import/share, PDF share |
| `upgrader` | Update prompt |
| `font_awesome_flutter` | Icons |

## Project Structure

```
lib/
  main.dart                  # Providers, EasyLocalization, AppShell (Firebase removed 2026-10-18)
  models/                    # project, project_task, project_member, payment_method,
                             # income, income_category, expense, expense_category
  providers/                 # settings, wallet, project, income, expenses, locale
  core/
    services/                # database_helper, backup, pdf, notification, currency, biometric
    utils/                   # currency_helper, speech_parser, app_layout, themes, tokens, …
    widgets/                 # app_lock_gate, restart_widget
  screens/
    splash/  shell/  home/
    projects/ (screens + widgets)  todos/
    income/  expenses/  settings/
  examples/                  # pdf_service usage examples
assets/
  fonts/ translations/ icons/ images/
docs/
  DOCUMENTATION_AR.md  LOCALIZATION_GUIDE.md  DESKTOP_UI_PERFORMANCE.md
  README_PDF_ENHANCEMENTS.md  google-play/  smart-planner-privacy/  productions.md
```

## Getting Started

Prerequisites: Flutter SDK (see `.fvmrc`), Dart `^3.12.1`, Xcode for iOS, Android SDK for Android.

```bash
flutter pub get
flutter gen-l10n  # only if localization setup requires it
flutter run
```

Useful commands:

```bash
flutter analyze
flutter test
flutter build apk --release
flutter build ipa --release
flutter build web --release
```

### Backup & PDF docs
- Production/store listing pack: [`docs/productions.md`](./docs/productions.md), [`docs/google-play/`](./docs/google-play/)
- PDF enhancements: [`docs/README_PDF_ENHANCEMENTS.md`](./docs/README_PDF_ENHANCEMENTS.md)
- Privacy policy source: [`docs/smart-planner-privacy/`](./docs/smart-planner-privacy/)
- Localization guide: [`docs/LOCALIZATION_GUIDE.md`](./docs/LOCALIZATION_GUIDE.md)

## Getting Started (Flutter default)

A few resources if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

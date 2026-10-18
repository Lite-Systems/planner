# Desktop UI & Performance — Audit + Enhancements

Date: 2026-10-13 · Scope: desktop-first review (macOS/Windows), UI professionalization, latency fixes.

## Current application-wide UI (2026-10-18)

- The dashboard palette is now the shared theme: navy surfaces, bordered panels,
  orange actions, consistent typography, fields, grouped settings and controls.
  Applies to modules, details, editors, wallets, categories, archive and auth.
- Top-bar module icons replace both sidebar and mobile drawer/bottom navigation.
  Phones show a compact two-row header; wider windows use one row with hover
  labels. The in-app logo is 28 pixels (48 on the simplified splash screen).
- A nested content navigator keeps the bar accessible in editors. Module changes
  close local detail routes, back returns within the module, and all Cupertino
  dialogs/popups use the same local navigator. Saved module selection, hidden
  modules, Ctrl/Cmd+1..6, Ctrl/Cmd+N and Escape remain supported.
- The obsolete compact-sidebar setting was removed. Its old stored preference
  is ignored; financial data and other preferences are untouched.
- Responsive regressions cover modules, editors, nested back, popup cancellation,
  resizing, saved/disabled selections, amount privacy, Arabic RTL and larger text.
  Chart legend/settings controls wrap on narrow screens; wallet privacy now also
  updates immediately from the shared top-bar button.
- Earlier sidebar references below describe historical work, not current UI.
- Current verification: all 49 tests pass. Full analysis reports no errors or
  warnings; four existing info lints remain in the PDF examples.

## Findings (audit summary)

| Severity | Finding | Location |
|---|---|---|
| 🔴 Critical | Windows/Linux builds had **no working database backend** — `pubspec.lock` only resolved sqflite implementations for android/darwin, so the shipped `fekra_pos.exe` could not open its DB | `pubspec.yaml` |
| 🔴 Critical | Every running-timer task card spawned `Timer.periodic(1s)` + bare `setState(() {})`, rebuilding the **entire card** per second (chips, shadows, progress bars). N visible timers = N full rebuilds/sec | `task_card.dart` |
| 🔴 Critical | `Consumer5<Income, Expenses, Project, Wallet, Settings>` rebuilt the whole home summary row + re-folded all data on **any** notification from **any** of the 5 providers | `home_summary_cards.dart` |
| 🟠 High | Outer `Consumer<ProjectProvider>` wrapped all of `HomeScreen` (nav bar, previews, wallet strip) — any project change rebuilt everything | `home_screen.dart` |
| 🟠 High | All `SettingsProvider` setters called `notifyListeners()` even when the value didn't change (the app root subscribes to `isDarkMode`) | `settings_provider.dart` |
| 🟡 Medium | Entrance animations (`flutter_animate`, per-item `delay: i*40`) replayed whenever list items scrolled out of the viewport and remounted, and on initial load of every data change | `expenses_screen.dart` |
| 🟡 Medium | Double shadow layers on cards (USD rate widget, expense chart card) — inconsistent elevation language | multiple |
| 🟡 Medium | FFI `getDatabasesPath()` default is CWD-relative (`.dart_tool/...`) — wrong for a shipped desktop app | `main.dart` |

## Changes made

### Performance (desktop latency)
1. **Windows/Linux database fixed** — added `sqflite_common_ffi`, initialized before `runApp`, and pinned the DB directory to the per-user Application Support folder (`_configureDesktopDatabase()` in `main.dart`).
2. **Timer ticking isolated** — new `_LiveTimerChip` in `task_card.dart` owns the 1-second ticker; only the elapsed-time text rebuilds per tick, never the card.
3. **Home summary split** — `home_summary_cards.dart` now uses per-card scoped `Consumer`s; a change in expenses only rebuilds the expenses card. Row structure rebuilds only when the *structure* changes (wallet added, expenses toggled).
4. **HomeScreen de-coupled** — removed the screen-wide `Consumer<ProjectProvider>`; task progress, active timers, and recent projects are now self-subscribing widgets (`_TaskProgressCard`, `_ActiveTimersSection`, `_RecentProjectsSection`).
5. **Spurious notifies eliminated** — all `SettingsProvider` setters early-return when the value is unchanged.
6. **Animations play once** — expenses screen gates entrance animations behind a first-frame flag; desktop layout never animates list items. Per-item animations capped at the first 8 items on mobile.
7. **Desktop cursor feedback** — `MouseRegion(cursor: SystemMouseCursors.click)` on task cards, timer button, expense cards, project cards, income tiles.

### UI professionalization
8. **Design token system** — new `lib/core/utils/app_tokens.dart`:
   - `AppRadius` (6/8/12/16/20/24), `AppSpacing` (4→32)
   - `AppText` — full Almarai type scale (display/sectionTitle/heading/cardTitle/body/caption/micro/amount) with context-resolved colors for dark mode
   - `AppShadows` — one soft card shadow + one hero shadow (replaces ad-hoc 1–2 layer stacks, fixes the double-shadow inconsistency)
   - `AppCard.container()` — the single standard card decoration
   - `AppClickable` — GestureDetector + mouse cursor for desktop
9. **Tokenized the highest-visibility surfaces**: home previews, wallet chips, task-progress card, USD rate card, income tiles, expense summary/chart cards, home section headers.

## Dashboard redesign (2026-10-18)

- Recreated the supplied Stitch dashboard as native Cupertino widgets: navy
  surfaces, orange accents, four financial metrics, task progress, compact
  transactions and wallets. Light mode and Arabic/English remain supported.
- Layout uses the available content-pane width: two metric columns on phones,
  four on wide desktops,
  and a two-column section layout when the pane is at least 1040 logical pixels.
  Module navigation now lives in the shared top bar.
- Existing providers and editors power every metric and action; no sample data
  or simulated online status ships in the dashboard. Expense preview values
  use the expense currency, and privacy hides transaction amounts and rates.
- Preview lists are capped at three records; provider selectors scope updates,
  and the shared timer ticker only rebuilds elapsed-time labels. The redesign
  adds no blur effects, entrance animations, network fonts or dependencies.
- Dashboard tests cover 320–1440 logical pixels, both languages and themes,
  larger text, active timers, privacy, navigation and empty data. Optional visual
  captures can be generated with
  `flutter test test/home_dashboard_test.dart --dart-define=DASHBOARD_CAPTURE_DIR=/private/tmp`.
- Verification: all 43 tests pass; analysis of `lib/screens/home` and
  `test/home_dashboard_test.dart` reports no issues.

## Verified

- `flutter analyze` — 0 errors, 0 warnings (10 pre-existing info lints unrelated to this change).
- `flutter test` — 20/20 passing.

## Recording follow-up (2026-10-18)

The supplied 26-second macOS recording shows a green triangular rendering
artifact persisting while a project opens. The following fixes address the
recorded rendering issue and errors reproduced in the running app:

- Use the documented macOS Skia fallback (`FLTEnableImpeller = false`) on
  Flutter 3.47.2. Impeller/Metal is a suspected cause of the GPU artifact;
  the rebuilt app logs the Skia backend and its captured project view renders
  without the triangle. This is a renderer workaround, not an engine fix.
  See [Flutter's macOS renderer documentation](https://docs.flutter.dev/perf/impeller#macos).
- Register `Almarai` with the exact family used by the UI and mark the bundled
  regular face as weight 400. The font-manifest regression test failed before
  the fix and passes afterward.
- Replace the outer desktop scrollbar with independent project/task pane
  controllers. Disable navigation-bar background blur in desktop project
  panes, and avoid unnecessary section rebuilds when selecting the same section.
- Reuse task/member caches when reopening projects, including empty projects.
  A database-backed test opens cached projects 20 times without a provider
  notification or replacing their task lists.
- Fix Income/Expenses consumers using the parent widget's `BuildContext` for
  `context.select`. Both screens reproduced the runtime assertion in tests;
  both now use the consumer's own context and rebuild successfully.

### Native macOS widget

Settings > Desktop now includes a macOS widget switch and add-widget
instructions. The embedded `PlannerWidget.appex` supplies small/medium widgets
for Desktop and Notification Center, with English/Arabic strings. Snapshots
contain task progress, at most three upcoming task names, and an active timer
count. They exclude financial data and archived tasks. Enabling app lock hides
all task data; disabling the widget replaces the shared snapshot with an empty
disabled state.

The app coalesces provider changes and skips identical snapshots. Native file
writes run on a serial background queue with atomic replacement; widgets never
open SQLite or run a polling loop. WidgetKit controls actual refresh timing.

Runner and PlannerWidget now share their signing configuration through
`macos/Runner/Configs/AppInfo.xcconfig`: `DEVELOPMENT_TEAM = J42PT5X89M`
(the existing iOS Runner team), `CODE_SIGN_IDENTITY = Apple Development`, and
`PLANNER_APP_GROUP = $(DEVELOPMENT_TEAM).com.litesystems.smartplanner`.
Both Info.plist files and all three entitlement files consume that one group
setting. Use the same authorized team for both targets if changing signing.
An ad-hoc build cannot enable widget sharing.
See [Apple's macOS app-group guidance](https://developer.apple.com/documentation/xcode/accessing-app-group-containers).

#### Widget activation error fix (2026-10-18)

The reported `widget_app_group_unavailable` error reproduced because the release
app and extension were ad-hoc signed with no team. Their former group variable
expanded to the bare app identifier, which the native prepare guard rejects.
The app's existing development certificate for its iOS team was available, so
both macOS targets now use that identity; no new certificate or portal group
registration was created.

Verification: the rebuilt app and extension have team `J42PT5X89M` and the same
`J42PT5X89M.com.litesystems.smartplanner` entitlement. Deep/strict signature
verification succeeds with access to macOS trust services. The native
`macos/Tests/WidgetReadinessProbe.swift` exercises the production container lookup;
run from a temporary probe bundle signed by the same team and entitled for the
group, it fails against the old build and passes against the new one, including
atomic JSON snapshot write/read using a unique disposable file. It never
overwrites `planner-widget.json` or changes the user's widget preference.

All 50 Flutter tests pass. The settings regression reproduces the original raw
PlatformException dialog before the UI fix; failures now show localized,
error-specific messages without the internal exception, and a failed prepare
keeps the switch off. Restart the app to load its new native signature before
trying the switch again.

After installing/running the signed app, enable the switch, right-click the
desktop > Edit Widgets > Smart Planner, and choose a size. macOS requires the
user to place the widget; the app provides setup instructions and a shortcut
to Desktop settings.

Regression checks: `flutter test` (font manifest, populated split-pane scrolling,
project cache reuse, finance-screen rebuilds, and widget privacy/coalescing),
`flutter analyze`, and `flutter build macos --release`.

## Finance screens and desktop sidebar follow-up

The running development app still held the old Income/Expenses consumer code,
so it continued reporting `context.select` outside build until hot reload.
Checking the running app after reload confirmed both sections render without
error widgets. Populated-screen regressions additionally caught an overflowing
Income title/metadata column in fixed-height cards and an unbounded category/date
row in Expense cards. Those labels now fit their available space.

The desktop sidebar header now includes a direct expand/collapse button. It
uses the existing `compactSidebar` preference, keeps the selected page alive,
and remains available in both 240px expanded and 76px compact layouts. Labels
are translated in English and Arabic. Tests cover toggling, navigation and
preference persistence for macOS and Windows with both text directions.

The Expenses total, category values and chart now all use `expensesCurrency`.
Previously the total used the app's main currency, categories added raw amounts
in different currencies, and the chart labeled them with the expense currency.
A regression with EGP 50 + USD 1, a 50 EGP/USD rate, and SAR as the main currency
now consistently reports USD 2 for the total and category instead of labeling
SAR 8 as USD and plotting 51 raw units against it.

## Recommended follow-ups (not yet done)

- ~~`onTaskPaidChanged` wired inside `HomeScreen.didChangeDependencies`~~ **Done** — wiring moved to `ProviderWiring` in `main.dart`, an always-mounted widget below the providers with the same restart semantics.
- ~~Desktop content pane has no scroll indicator~~ **Done** — `PrimaryScrollController` + `CupertinoScrollbar` (`thumbVisibility: true`) wrapped around the shell content pane in sidebar mode; compact mode untouched.
- ~~Linux runner default window sizing is the Flutter stub~~ **Done** — min size 800×560 added in `linux/runner/my_application.cc` (default is already 1280×720), matching the macOS Runner.
- ~~`app_styles.dart` vestigial file~~ **Deleted** (no imports existed).
- Expense/income/project/task list cards now consume the token system.

## Second-pass changes (this round)

1. `main.dart` — new `ProviderWiring` widget moves the task→income cross-provider wiring out of HomeScreen, eliminating the hidden coupling where the side effect only existed after Home was built at least once.
2. `app_shell.dart` — persistent desktop scrollbar for the content pane (sidebar layouts only; mobile scrolling behavior unchanged).
3. `expense_card` / `project_card` / `task_card` — migrated to `AppCard.container` / `AppRadius` / `AppShadows.card` tokens; consistent radii and single unified shadow.
4. `linux/runner/my_application.cc` — window min size 800×560.

## Recommended follow-ups (remaining)

- `add_task_screen.dart` (1,160 lines) and `project_detail_screen.dart` (820 lines) predate the token system — migrate when next touched.
- Home dashboard now uses a `CustomScrollView`; its curated sections remain bounded to three preview records each rather than rendering full collections.
- `todos_screen.dart` recomputes the full expand/sort per notification — fine at personal-finance data volumes, worth memoizing if task counts grow into the thousands.

## Third-pass changes (2026-10-16)

### Performance

1. **Voice sheet save button scoped** — `voice_task_sheet.dart` no longer calls
   `setState(() {})` on every keystroke (`onChanged`) or after speech init. The
   save button enable state now lives in a `ValueListenableBuilder` bound to
   `_taskNameController`; only the button subtree rebuilds per keystroke.
2. **Voice-field mic indicators scoped** — `add_task_screen.dart`
   `_toggleFieldSpeech` used to `setState(() {})` the entire sheet on every
   listening-status change and recognition result. `_listeningFieldName` is now
   backed by a `ValueNotifier` (`_listeningFieldNotifier`); the three mic
   suffixes (`_buildMicSuffix`) and the three "listening" placeholders are
   `ValueListenableBuilder`-scoped, so nothing else in the 1,100-line sheet
   rebuilds during dictation. The now-unused `StateSetter dialogSetState`
   parameter was removed from `_toggleFieldSpeech` / `_buildMicSuffix`.
3. **Archive list virtualized** — `archive_screen.dart` switched its
   project-grouped non-builder `ListView` to `ListView.builder` (one section per
   project group). Audited the other flagged lists and converted nothing there,
   because they were already builder-based or fixed-content:
   `projects_screen.dart:101`, `todos_screen.dart:89`,
   `income_screen.dart:140` (builder), `settings_screen.dart:52` /
   `home_screen.dart:120` (fixed curated sets — documented as acceptable).
4. **Animation-gate audit** — re-checked the spots the second pass flagged:
   `expense_categories_screen.dart` (`_CategoryList`) and `expenses_screen.dart`
   (`_entranceDone`, desktop check, first-8 cap on `_expenseCard`) already
   implement the documented gate. No additional ungated entrance animations
   found; nothing changed.

### UI professionalization

5. **`project_detail_screen.dart` tokenized** — filter panel/chips, filter
   toggle + count badge, customer label, bottom action row, and the voice
   gradient button now consume `AppRadius`/`AppSpacing`/`AppText`.
   `AppShadows.hero` replaces the ad-hoc single-layer mic-button shadow.
   Filter chips use `AppColors.elevatedBackground(context)` instead of
   hard-coded `systemGrey6`, so they adapt to dark mode, and are wrapped in
   `AppClickable` for desktop cursor feedback.
   Note: the purple/pink voice gradient (`0xFF8B5CF6`→`0xFFEC4899`) is kept
   literal; only its pink stop references `AppColors.expensePrimary`. If it
   gains a third usage, promote it to a named gradient in `AppColors`.
6. **`add_task_screen.dart` tokenized (mechanical pass)** — section paddings,
   field paddings, gaps, and card radii converted to `AppSpacing`/`AppRadius`/
   `AppText`. Values outside the token scale (2, 6, 10 px insets) were left
   literal rather than nudging the layout to the scale.

## Verified

- `flutter analyze` — 0 errors, 0 warnings (10 pre-existing info lints, unchanged).
- `flutter test` — 20/20 passing.

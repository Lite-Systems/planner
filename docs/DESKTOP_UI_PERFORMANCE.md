# Desktop UI & Performance — Audit + Enhancements

Date: 2026-10-13 · Scope: desktop-first review (macOS/Windows), UI professionalization, latency fixes.

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

## Verified

- `flutter analyze` — 0 errors, 0 warnings (10 pre-existing info lints unrelated to this change).
- `flutter test` — 20/20 passing.

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
- Home dashboard uses an eager (non-builder) `ListView`; children are a fixed set so it is acceptable, but convert to `CustomScrollView` + slivers if the dashboard grows.
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

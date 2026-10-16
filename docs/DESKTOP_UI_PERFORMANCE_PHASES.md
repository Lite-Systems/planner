# Desktop Performance — Phase 0–5 Verification

Date: 2026-10-13 · Scope: macOS desktop (Flutter, Cupertino UI, provider + SQLite v22).
Companion to `docs/DESKTOP_UI_PERFORMANCE.md` (the first-pass audit/enhancements).
Measure with `flutter run --profile -d macos` — debug builds are not representative.

## Status

- `flutter analyze` → 10 pre-existing info lints, 0 new (all in `lib/examples/*`,
  `add_expense_screen`, `add_income_screen`, `income_categories_screen`).
- `flutter test` → 20/20 pass.
- No user-visible behavior, UI design, localization, or data-model semantics
  changed — except the explicitly-requested desktop-only shadow softening and
  image downscale-on-pick.

## What changed, by phase

### Phase 1 — timer & rebuild isolation
- New shared, ref-counted `ValueNotifier<int>` ticker
  (`lib/core/utils/timer_ticker.dart`): one `Timer.periodic` while at least one
  running timer is visible; static chips don't listen. Elapsed time is derived
  from `lastStartTime` (no drift).
- `task_card.dart`: settings `select`, isolated `_TaskAssigneeChips`,
  payment-tag `Selector`.
- Active-timer cards (Home `Column`) wrapped in `RepaintBoundary`.
- `app_lock_gate`, `expense_summary_chart`, `expense_card`, `usd_rate_widget`,
  `income_screen`, `project_detail_screen` narrowed to `select`/`Selector`;
  `MediaQuery.of` → `sizeOf`/`viewInsetsOf` in 4 files.

### Phase 2 — database
- Schema **v22** with 12 indexes (foreign keys + date/category/payment-method/task
  lookups) in both `onCreate` and `onUpgrade` (`CREATE INDEX IF NOT EXISTS`).
- Wallet balances via SQL `GROUP BY payment method + currency`
  (`getWalletFlowTotals`), cached in `WalletProvider`, refreshed by
  income/expense listeners.
- Project totals/task counts via SQL `GROUP BY project`
  (`getProjectTaskAggregates`), cached in `ProjectProvider`, refreshed once per
  mutation.
- `archiveTasks` batched to a single notify; providers load in parallel via
  `Future.wait`.

### Phase 3 — images & GPU
- Image picker downscales/compresses (`maxWidth/maxHeight 1600`, `quality 85`);
  the project-dialog preview decodes at display size (`cacheWidth`).
- Category-list entrance animation no longer replays on remount; the chart is
  wrapped in `RepaintBoundary`; the expenses screen is decoupled from wallet
  balance refreshes; `shrinkWrap` removed from the add-task form.
- Hero shadow blur trimmed on desktop only.

### Phase 4 — PDF
- Almarai font + logo cached once; the document is built and `pdf.save()` runs
  on a background isolate via `compute`, with all labels pre-resolved on the
  main isolate (no `rootBundle`/`BuildContext` inside the isolate). RTL, the
  draft watermark, and content toggles are preserved.
- Modal `CupertinoActivityIndicator` shown during generation, dismissed before
  the print dialog / share sheet appears.

### Phase 5 — startup
- Only settings/locale restore before the first frame; Firebase/FCM/notifications
  deferred to a post-frame callback; provider DB loads deferred to post-frame.
- macOS skips Firebase/FCM and the update prompt (kept for other platforms). The
  currency fetch was already post-frame.

## Files touched

```
lib/main.dart
lib/core/utils/timer_ticker.dart                     (new)
lib/core/utils/app_tokens.dart
lib/core/widgets/app_lock_gate.dart
lib/core/services/database_helper.dart
lib/core/services/pdf_service.dart
lib/providers/wallet_provider.dart
lib/providers/project_provider.dart
lib/screens/home/home_screen.dart
lib/screens/home/widgets/home_summary_cards.dart
lib/screens/home/widgets/usd_rate_widget.dart
lib/screens/income/income_screen.dart
lib/screens/expenses/expenses_screen.dart
lib/screens/expenses/expense_categories_screen.dart
lib/screens/expenses/widgets/expense_card.dart
lib/screens/expenses/widgets/expense_summary_chart.dart
lib/screens/projects/screens/add_task_screen.dart
lib/screens/projects/screens/project_detail_screen.dart
lib/screens/projects/widgets/task_card.dart
lib/screens/projects/widgets/project_dialog.dart
lib/screens/projects/widgets/project_members_sheet.dart
lib/screens/projects/widgets/voice_task_sheet.dart
lib/screens/settings/payment_methods_screen.dart
```

## End-to-end manual test checklist

### Timers & tasks
- Start a timer → elapsed ticks; only the chip updates.
- Start 2+ timers → all count; exactly one internal timer runs.
- Pause/resume → no drift; elapsed correct.
- Complete / archive / delete a running task → chip gone, no ghost ticking.
- Navigate away/back → elapsed correct; ticker stops when none visible.
- Mark a task paid → income auto-created; wallet balance updates; unmark →
  income removed.
- Assignee chips and payment tag still render/update; project-detail member
  filter chips work.

### Money
- Create wallet + income + expense → balances correct across currencies
  (EGP/USD/SAR); net/income/expense/pending summary correct.
- Archive/restore tasks → task-progress counts/totals correct; delete a project
  → counts drop.

### Expenses / charts
- Switch months, touch pie sections, change currency / hide-amounts, add an
  expense → chart updates without whole-screen rebuilds; category list doesn't
  replay its entrance animation on scroll.

### Images
- Add/edit a project cover → preview crisp, stored file smaller; cover correct
  in cards and in RTL.

### PDF (Arabic & English)
- Print → preview renders, RTL intact, spinner appears then print dialog.
- Share → share sheet opens with the PDF; spinner gone first.
- Toggle hour-cost / task-type / task-time / subtasks → sections appear/disappear
  as before.
- Draft path (`saveProjectInvoiceToFile` / `getProjectInvoiceBytes` with
  `isDraft: true`) → watermark present.

### Data
- Backup (share + save) and restore, including a pre-v22 backup → opens, indexes
  created, data intact.
- Legacy `masrofy.db` → copied to `planner.db` and upgraded.

### Startup / platform
- Cold start on macOS: fast window, no Firebase/FCM errors, no update prompt;
  data populates shortly after; language + settings restore.
- Update prompt still present on Android/iOS.
- Language switch (AR/EN/RTL) everywhere.

## Single before/after profiling plan (profile mode only)

```
flutter run --profile -d macos
```

1. **Cold start** — `flutter run --profile -d macos --trace-startup`; compare
   time-to-first-frame (before/after). Expect Firebase/FCM/notification/DB work
   to no longer sit in the first frame.
2. **Home, 2+ timers running** — DevTools → Performance, record ~10 s. Before:
   N timers + N card rebuilds/sec. After: one timer, only the chip repaints.
3. **Project list scroll + edits** — Performance + "Highlight repaints": editing
   one task should not rebuild every visible card; covers should not re-decode
   at full resolution.
4. **Expenses screen** — scroll, touch the pie, change currency; confirm the
   chart layer is isolated and wallet balance refreshes don't repaint the screen.
5. **PDF generation** — Performance/CPU: the main isolate stays responsive; font
   parse appears once then cache-hits; PDF work shows on a background isolate.
6. **DB** — with many tasks/expenses, mark several paid and archive a batch:
   expect one grouped query + one notify per operation.

## Remaining / deliberate deviations

- The splash's ~1.5 s branded delay is unchanged (user-visible design, not
  pre-first-frame blocking).
- Home summary net/income/expense folds still run in Dart over already-loaded
  in-memory lists inside scoped consumers (cheap); only wallet + project
  aggregates moved to SQL.
- `_configureDesktopDatabase()` stays before `runApp` (needed before DB access;
  a no-op on macOS).
- The `AppShadows.hero` desktop blur reduction and image downscale-on-pick are
  the only intentional visual/data changes, both explicitly requested.

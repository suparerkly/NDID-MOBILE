---
name: ndid-testing
description: Run, write, and report on the tests for the NDID Verify LOSE app (Flutter app + Express/Prisma/SQLite mock server in this repo) — E2E UI flows, unit, widget, contract (app ↔ real server) and server API tests, plus the mutation check and the Thai test-report artifact. Use this whenever the user wants to run the tests, add or fix a test, cover a new screen or flow, check that a change didn't break verify/purchase/policy flows, test the server API, or get a test summary / test report / ผลทดสอบ / รายงานผลทดสอบ / ทำเทสต์ / รันเทสต์ / e2e / unit test for this project, even if they don't say "skill" or name the test layer.
---

# NDID Verify LOSE testing

This repo has five test layers. Each has a reason to exist; when adding coverage, put the test in the layer that can actually catch the bug.

| Layer | Path | Runs with | What it is for |
| --- | --- | --- | --- |
| E2E flow | `test/e2e/app_flow_e2e_test.dart` | `flutter test` | Whole app driven through the real UI from `NdidSimApp`, backed by an in-memory API (`ScriptedApi` extends `test/fake_api.dart`). Cases A1–A6 verify, B1–B4 purchase, C1–C3 policies/sign-out. |
| Unit | `test/unit/` | `flutter test` | Validators, liveness checker, YUV→NV21, models, `HttpAppApi` (via `http/testing.dart` `MockClient`), `AppState`, `MockNdidService`. |
| Widget | `test/widget_test.dart` | `flutter test` | Single screens in isolation. |
| Contract | `test/contract/server_contract_test.dart` | `./tool/test_contract.sh` | The app's real `HttpAppApi` + `AppState` against the real server and a real SQLite DB. Skipped by plain `flutter test` (no `API_BASE_URL`). |
| Server API | `server/test/api.test.js` | `npm --prefix server test` | Every endpoint with `node:test` + `fetch`, app started in-process from `server/src/app.js`. |
| Browser (Playwright) | `e2e-web/tests/flow.spec.mjs` | `./tool/test_web.sh` | The Flutter **web build** in real Chromium against the real server + temp SQLite, with a screenshot at every step. Cases W1–W4. |

`integration_test/` needs an emulator or device with a camera; it can't run in a headless container. Say so rather than skipping silently.

## Environment setup

1. **Flutter version must match `pubspec.lock`.** The lock pins SDK packages from Flutter **3.24.x** (collection 1.18.0, leak_tracker 10.0.5, sky_engine 0.0.99). Newer Flutter (e.g. 3.35) rewrites the lock and fails to compile `lib/theme.dart` (`DialogTheme` vs `DialogThemeData`). If `flutter` is missing, install 3.24.5:
   ```bash
   curl -sSfL -o /tmp/flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz && tar xf /tmp/flutter.tar.xz -C /opt && rm /tmp/flutter.tar.xz
   ```
   then `export PATH=/opt/flutter/bin:$PATH`, `git config --global --add safe.directory /opt/flutter`, `flutter pub get`. After `pub get`, `git status pubspec.lock` should be clean. If it changed, the Flutter version is wrong; restore it with `git checkout pubspec.lock`.
2. **Server deps:** `npm --prefix server install` (Node 20+).

## Running everything

`scripts/run_all.sh` (in this skill folder) runs all suites plus `flutter analyze` and prints one summary line per suite. Use it for "run the tests" and before writing a report:

```bash
bash .claude/skills/ndid-testing/scripts/run_all.sh
```

Individual suites: `flutter test`, `flutter test test/e2e`, `./tool/test_contract.sh`, `npm --prefix server test`.

## Database safety

Never point tests at `server/prisma/dev.db`, and never run `prisma db push --force-reset` / `migrate reset`. Prisma blocks those when an AI agent runs them and asks for the user's explicit consent, and they would wipe the user's dev data anyway. The repo avoids the need entirely:

- `prisma/schema.prisma` reads `DATABASE_URL` (default `file:./dev.db` in `server/.env`).
- `server/scripts/with-test-db.js <cmd…>` creates a brand-new SQLite file in a fresh temp dir, pushes the schema, seeds the 3 plans, runs the command, then deletes the dir. `npm test` and `npm run start:test` both use it.

If you need a DB for anything new, wrap it with `with-test-db.js` too.

## Writing E2E flow tests

Read `references/e2e-patterns.md` before adding or changing a test in `test/e2e/`. It covers the gotchas that cost time: mocking the camera and ML Kit channels, why `pumpAndSettle` hangs on the face-scan screen, the date-picker input, the tall test screen, and the reusable helpers (`verify`, `openPurchase`, `consentAndFillForm`, `pumpFor`, `tapAndSettle`, `chooseDropdown`, `pickBirthDate`).

Keep the case IDs (A/B/C + number) in the test names. The report and the flow map refer to them.

## Browser tests with Playwright (Flutter web)

Use this layer when the user mentions Playwright or a browser, wants screenshots/captures of the flow, or a change touches the web build (`face_scan_screen_web.dart`, web layout, CORS). Read `references/playwright-web.md` before writing or debugging a case. Flutter web only exposes an accessibility DOM, which needs a desktop-mode viewport. Real mouse clicks get intercepted during animations, so use the `press`/`tap`/`typeInto`/`navTile`/`text` helpers in `e2e-web/tests/helpers.mjs`.

For a capture artifact ("capture ลง artifact", ภาพหน้าจอ), run `./tool/test_web.sh`, then `scripts/build_web_report.py`, and publish the HTML it writes. The reference covers the flags.

## Writing server and contract tests

- Server: add cases to `server/test/api.test.js`. Use a **unique citizen ID per test**, because tests share one DB per run. Use `birthDateForAge(n)` for age-limit cases. Plan age ranges: PA 18–70 (1,200 บาท), HL 20–60 (8,900 บาท), TR 18–75 (690 บาท).
- Contract: tests go in `test/contract/`, guarded with `skip: skip` like the existing ones. Use `randomCitizenId()` so reruns against the same server don't collide.
- If you change an endpoint's response shape, update `test/fake_api.dart` too. Otherwise the E2E tests keep passing against a fake that no longer matches the server, and only the contract suite notices.

## Proving the tests catch bugs (mutation check)

A green run only means something if the tests would go red on a real bug. After adding or changing E2E tests, run:

```bash
bash .claude/skills/ndid-testing/scripts/mutation_check.sh
```

It plants known bugs in `lib/` one at a time (new policy appended instead of first, pay without accepting terms, back-navigation left open after verification), runs `flutter test test/e2e`, reports CAUGHT/MISSED, and restores `lib/` with `git checkout`. It refuses to run if `lib/` has uncommitted changes, so it can never destroy the user's work. If one is MISSED, add an assertion that fails for that bug (that's how the "terms not accepted → no confirm dialog" check in B1 came about), then rerun. Report missed mutations honestly, including ones you fixed.

## Test report artifact

When the user asks for a summary, report, or document of the results (เอกสาร / รายงาน / artifact / design), build the Thai report page from `assets/report_template.html`:

1. Run `scripts/run_all.sh` and the mutation check, and collect the numbers: per-suite counts, totals, failures, timings, the commit (`git log --oneline -1`), the branch, Flutter/Dart/Node versions, and the date in Buddhist Era (ปี พ.ศ. = ค.ศ. + 543).
2. Copy the template to the scratchpad and edit the copy so every number, case row, mutation row, limitation, and the "changes in repo" cards match what actually ran. The template is the previous report. Treat its numbers as examples to replace, not facts. If a test failed, show it with a fail state and say what failed. Never present a red run as green.
3. Embed screenshots: `python3 .claude/skills/ndid-testing/scripts/embed_thumbnails.py <edited.html> <out.html>` replaces `{{a1_welcome}}`-style placeholders with resized JPEG data URIs from `docs/screens/*.png`.
4. Publish `<out.html>` with the Artifact tool (icon `checklist`). If this conversation already published the report, republish the same file path so the URL stays the same.

Keep the report in Thai, matching the app and the user. The visual system (app blue `#2447d8`, Anuphan + IBM Plex Sans Thai + IBM Plex Mono, light/dark tokens, pass/warn pills) is already in the template. Keep it rather than redesigning.

## Finishing up

- Commit test work on a feature branch (e.g. `test/<topic>`), not `main`, and push only when the user asks. Mention the branch in the reply.
- In the reply, give the pass/fail totals, what's new, what isn't covered (real camera, device builds, web face-scan, the 10 s timeout path), and the commands to rerun.

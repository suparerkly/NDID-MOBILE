# Playwright on the Flutter web build (`e2e-web/`)

## Contents
1. How the suite is wired
2. Driving Flutter web: what works and what doesn't
3. Writing a new case
4. Captures and the report
5. Mutation check on the web build

## 1. How the suite is wired

- `tool/test_web.sh` builds the web app with `--no-web-resources-cdn` (CanvasKit comes from `build/web`, not gstatic) and `--dart-define=API_BASE_URL=http://127.0.0.1:3998`, then runs `npx playwright test` in `e2e-web/`. `SKIP_BUILD=1` reuses the existing `build/web`. Extra args go to Playwright (e.g. `-g W3`).
- `e2e-web/playwright.config.mjs` starts two `webServer`s: the mock server via `server/scripts/with-test-db.js` on **3998** (fresh temp SQLite, never `dev.db`) and `serve-web.mjs` (a tiny static server for `build/web`) on **8090**. `gracefulShutdown: SIGTERM` matters. With Playwright's default SIGKILL, `with-test-db.js` can't delete its temp DB, and a `/tmp/ndid-test-db-*` dir leaks on every run.
- `@playwright/test` is pinned to **1.63.0** to match the preinstalled browsers in `/opt/pw-browsers`. A different version wants another Chromium build. If the container's Playwright changes, match the pin to `require('playwright/package.json').version`.
- If port 3998 or 8090 is busy, Playwright refuses to start (`reuseExistingServer: false`). That's deliberate, so tests never talk to a stale server. Find and stop the old process first.

## 2. Driving Flutter web: what works and what doesn't

Flutter web paints to a canvas. Playwright can only see the app through Flutter's accessibility DOM (`flt-semantics-host`), which is off until something enables it.

- **Enable semantics:** `openApp()` dispatches a `click` on `flt-semantics-placeholder`. This only works in **desktop mode**. With mobile emulation (`devices['Pixel 7']`, `isMobile`/`hasTouch`), Flutter uses the mobile enabler, which ignores scripted taps, and you get zero `flt-semantics` nodes. So the config uses a phone-sized **desktop** viewport (412×915, DPR 2).
- **Don't use real mouse clicks on Flutter nodes.** During route animations the `<flutter-view>` canvas intercepts pointer events and `locator.click()` times out. Use `press(page, locator)` (wait until visible, then `dispatchEvent('click')`; Flutter treats a DOM click on `flt-semantics[flt-tappable]` as a tap) or `tap(page, buttonName)`. Both retry if the node gets re-created mid-animation.
- **Text fields** are real `<input aria-label="…">`. Use `typeInto(page, label, value)`, which runs `focus()` + `fill()` and asserts the value. Don't use click + Ctrl+A: focus can lag, the old value stays, and `LengthLimitingTextInputFormatter` silently truncates (a random citizen ID became `9000000000005`).
- **Roles you'll meet:** `button` (FilledButton/TextButton, `Back`, `ออกจากระบบ`), `radio` (`SelectTile`: banks, payment methods), `checkbox` (consent, terms; the terms error text is part of the checkbox's accessible name), `textbox`. Dropdowns are buttons named `"<label> <value>"`.
- **Cards without a role:** `NavTile` / `OutlinedPanel` use `InkWell`, so they appear as `flt-semantics[flt-tappable]` with no `role="button"`. Use `navTile(page, title)` (matches by leading text). The home "กรมธรรม์ของฉัน" card's name includes the count, so assert with `toHaveText(/1 ฉบับ$/)`. This is also a real accessibility finding: screen readers don't announce these cards as buttons.
- **Text lookups:** use `text(page, value)`, which is scoped to `flt-semantics-host` and exact for strings. Unscoped `getByText` also hits Flutter's hidden live-region announcement `<div>`s and fails strict mode. `InfoRow` merges label and value into one node ("เลขที่กรมธรรม์ TR-2026-123456"), so match those with a regex.
- **Face scan on web** is `face_scan_screen_web.dart`: there's no camera, just a `จำลองผลการยืนยันตัวตน` button, and the result arrives after MockNdidService's 2 s delay.

## 3. Writing a new case

- Name tests `W<n> <Thai description>`. The report uses the first word as the case code.
- Use `randomCitizenId()` for every new person. All tests share one server and DB per run.
- Check the server side with `fetch(`${API}/api/users/${userId}/policies`)`. `verify()` returns `userId` from the real `/api/verifications` response.
- Call `const snap = camera(page, testInfo)` and `await snap('slug', 'คำอธิบายภาษาไทย')` at each meaningful screen. It waits 700 ms for animations, saves `NN-slug.png`, attaches it, and updates `captions.json`.
- Run it twice. A Flutter-web test that passes once can still be timing-flaky.

## 4. Captures and the report

After `./tool/test_web.sh`:

```bash
python3 .claude/skills/ndid-testing/scripts/build_web_report.py <scratchpad>/ndid-web-playwright.html \
  --meta "Commit=$(git log --oneline -1 | cut -c1-7)" --meta "Branch=$(git branch --show-current)" \
  --meta "Chromium=<version>" --meta "Viewport=412×915 @2x" \
  --mutation "M2|ชำระเงินได้โดยไม่ยอมรับเงื่อนไข|W3|CAUGHT" \
  --finding "หัวข้อ|รายละเอียด"
```

It reads `e2e-web/test-results/results.json` and each test's `captions.json`, embeds the screenshots as JPEG, and fills `assets/web_report_template.html`. Pass, fail, and flaky counts come from the run. A failed test is shown in red with its error message. Publish the output with the Artifact tool (icon `camera`). Only add `--mutation` rows you actually ran.

## 5. Mutation check on the web build

`scripts/mutation_check.sh` covers the Flutter E2E suite. For the browser suite: apply the same `sed` from that script, `flutter build web …` (same flags as `tool/test_web.sh`), run `SKIP_BUILD=1 ./tool/test_web.sh -g <case>`, then `git checkout lib` and **rebuild** so `build/web` is clean again. M2 (pay without accepting terms) should fail W3.

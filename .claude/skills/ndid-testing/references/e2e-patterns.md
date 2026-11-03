# E2E flow test patterns (`test/e2e/app_flow_e2e_test.dart`)

## Contents
1. Camera and ML Kit
2. Pumping: when `pumpAndSettle` hangs
3. Screen size
4. Forms, dropdowns, date picker
5. Helpers in the test file
6. Making the backend fail
7. Snackbars

## 1. Camera and ML Kit

`flutter test` runs with `dart.library.io`, so `face_scan.dart` exports the **native** `FaceScanScreen`, which calls the camera and ML Kit plugins. With no mocks you get `MissingPluginException` and the test crashes, because `_startCamera` only catches `CameraException`. `setUp` mocks both channels:

```dart
const _cameraChannel = MethodChannel('plugins.flutter.io/camera');          // camera_platform_interface MethodChannelCamera
const _faceDetectorChannel = MethodChannel('google_mlkit_face_detector');  // FaceDetector.close() on dispose
messenger.setMockMethodCallHandler(_cameraChannel, (call) async =>
    call.method == 'availableCameras' ? <Object>[] : null);
messenger.setMockMethodCallHandler(_faceDetectorChannel, (_) async => null);
```

With an empty camera list, the screen shows `ไม่พบกล้องบนอุปกรณ์นี้` plus a `ลองอีกครั้ง` button. Tests run in debug mode, so the `ข้ามการสแกน (เฉพาะ debug build)` button is there. Tapping it calls `_submit`, which runs `MockNdidService` with its 2-second delay and then shows the success popup. Liveness logic itself is covered by `test/unit/liveness_checker_test.dart`, not by E2E.

## 2. Pumping: when `pumpAndSettle` hangs

`pumpAndSettle` times out while an endless animation is on screen. In this app that is the `CircularProgressIndicator` on the face-scan screen (before the camera error, and while submitting) and the paying spinner on the purchase button. In those stretches use `pumpFor(tester, Duration)` (100 ms steps):

- after tapping `ถัดไป: ตรวจสอบใบหน้า` → `pumpFor(1s)`
- after tapping skip → `pumpFor(3s)` (covers the 2 s mock delay). The face screen's spinner is still behind the dialog, so don't settle here.
- after tapping `ยืนยัน` in the payment dialog → `pumpFor(2s)`
- after a snackbar error, `pumpFor(5s)` before tapping again, so the snackbar is gone

Once `ไปที่เมนูประกัน` replaces the stack with Home, the spinner screen is disposed and `pumpAndSettle` is safe again.

## 3. Screen size

Use a tall view (1080×3200 at DPR 1.0) set in `setUp` and reset in `tearDown`, so whole forms fit and `ensureVisible` rarely matters. `tapAndSettle` still calls `ensureVisible` first, for long pages.

## 4. Forms, dropdowns, date picker

- Text fields have keys: `firstName`, `lastName`, `citizenId`, `birthDate`, `phone`, `email` (personal info), and `beneficiary` and `terms` (purchase).
- `กรอกข้อมูลตัวอย่าง` fills a valid sample (born 1/1/1990, citizen ID `9000000000004`). `consentAndFillForm` taps it first, then overrides fields, so birth date is set even when the test doesn't care.
- Dropdowns: `chooseDropdown(tester, currentValue, newValue)` taps the current text, then the `.last` match of the new value (the menu overlay renders a second copy).
- Date picker (Flutter 3.24, en_US locale): tap the `birthDate` field, tap `Icons.edit_outlined` to switch to typing, enter `MM/DD/YYYY` in the dialog's `TextField`, tap `OK`. That's what `pickBirthDate` does. A newer Flutter or another locale may change the icon or the format.
- Valid test citizen IDs (checksum OK): `1101700230678`, `9000000000004`, and `1000000000001`… only in server tests, where the checksum isn't enforced.

## 5. Helpers in the test file

| Helper | Does |
| --- | --- |
| `startApp(tester, api)` | `pumpWidget(NdidSimApp(api: api))` + settle |
| `consentAndFillForm(tester, Person)` | tick consent → start → sample data → override fields → `ถัดไป` |
| `chooseIdpAndOpenFaceScan(tester, idpName)` | select bank → open face scan → assert the no-camera state |
| `skipScan(tester)` | tap skip, assert the "sending" message, `pumpFor(3s)` |
| `verify(tester, api, person:, idp:)` | the whole Flow A, asserting popup contents and that Home has no back button |
| `openPurchase(tester, planName)` | Home → plans → expand (PA is expanded by default) → `ซื้อแบบนี้` |

`Person` defaults to `นายสมชาย ทดสอบระบบ`, `1101700230678`. Pass `birthDate: DateTime(now.year - N, 1, 1)` for age cases.

## 6. Making the backend fail

`ScriptedApi` (in the E2E file) extends `FakeAppApi`:
- `failVerifications = n`: the next n `saveVerification` calls throw `ApiException`
- `purchaseError = ApiException(...)`: `createPolicy` throws until you set it back to `null`
- `savedIdps` and `savedReferenceIds` record what reached the "server"

`FakeAppApi.createPolicy` always numbers policies `<plan>-<year>-000001`. Assert on that, not on random numbers.

## 7. Snackbars

Error messages come from `ApiException.message` and appear as a `SnackBar` (`find.text(message)`). Wait for one to disappear (about 4 s) before retrying, or the next `find.text` can match the old one.

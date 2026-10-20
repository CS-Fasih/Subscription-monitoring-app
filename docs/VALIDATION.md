# Validation record

Validated in the managed Linux cloud workspace on 20 October 2026 using Flutter 3.35.7, Dart 3.9.2, and headless Chromium. These results describe this checkout and running instance; they do not establish store publication, a GitHub Actions run, or restoration into a new cloud task.

| Check | Outcome |
| --- | --- |
| Frozen dependency resolution (`flutter pub get --enforce-lockfile`) | Passed |
| Dart formatting check | Passed; no changes needed |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub --coverage` | **33 passed**, none skipped; 25 domain/persistence and 8 widget tests |
| Line coverage | 2,279 / 2,605 executable lines (87.5%); generated in ignored `coverage/lcov.info` |
| All six screens at 1440×1000, 390×844, and 320×700 with 1.3× text | Passed; no layout overflows |
| Small-phone editor validation and persistent creation | Passed |
| Search/filter, pause confirmation/totals, calendar navigation, calculators | Passed |
| Release web build (`bash tool/build_web.sh --no-pub`) | Passed; bundled CanvasKit/fonts and generated offline cache |
| Served app document and JavaScript bundle | HTTP 200 |
| Chromium creation and persistence after reload | Passed |
| Actual JSON, CSV, and ICS downloads | Passed; downloaded contents verified |
| Actual file-picker backup restore | Passed |
| Offline reload, offline creation, and subsequent reload | Passed |
| Mobile browser navigation | Passed |
| Uncaught JavaScript errors / third-party asset requests in tested flows | None |
| Web distribution archive | Created `build/releases/tally-web-1.0.0.zip`; all 37 entries match the tested build, ZIP integrity passed, and a SHA-256 sidecar is included |
| Android signing guard, offline Gradle dry-runs | Passed: `:app:assembleRelease` and aggregate `:app:assemble` reject missing signing; `:app:assembleDebug` accepts the debug task graph. These checks do not compile an APK. |
| Android debug build | **Blocked by current network policy**; see below |
| iOS build and physical-device testing | Not run; macOS/Xcode and devices are required |

## Android prerequisite

The Android SDK, NDK, Gradle, and a full JDK 21 are installed. The build progresses to `:app:checkDebugAarMetadata`, then receives HTTP 403 while fetching `io.flutter` engine/embedding Maven artifacts from `https://storage.googleapis.com/download.flutter.io/`.

The `storage.googleapis.com` domain addition is saved in the environment configuration, but the observed running policy still denies it. Review and save the environment settings, then publish/apply them through the environment UI. Once the runtime reports the new policy, retry:

```bash
cd /workspace/Subscription-monitoring-app
source tool/cloud_env.sh
flutter build apk --debug --no-pub
```

TLS and artifact verification remain enabled. No token or application secret is needed. This is an environment blocker, not evidence of a successful Android package build. Signing, iOS compilation, native sharing on devices, and app-store submission are still unverified.

## Reproducibility and scope

- Installation and startup instructions were saved in the environment configuration draft. Publication is a separate user action.
- The development server is a local validation process. A new task must start its own server.
- CI configuration is included. Hosted workflow outcomes are separate from the local results above.
- Android release configuration requires owner-supplied signing variables. No credentials were created or embedded.
- Browser tests use isolated profiles and sample records. They never modify an existing user's workspace.
- Screenshots under `docs/screenshots` come from the compiled Flutter app. Calendar, insights, and tools captures include the extra record created during the browser test.
- Reminders use exported calendar alarms. They are not native push notifications or a live calendar subscription.

Run `TALLY_SCREENSHOTS_DIR=/tmp/tally-browser-checks npm test --prefix tool/browser` to repeat browser validation without overwriting the checked-in screenshots. Start the release web server first, as documented in the README.

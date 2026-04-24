# Mart Price Harness — Gemma 4 E2B validation app

Flutter app that runs **Gemma 4 E2B** on-device via **LiteRT-LM** and answers Korean queries strictly from a JSON data blob. Built as the validation harness for an 아산시 local mart price-comparison platform.

Two screens:

| Tab | What it does |
|---|---|
| **Harness** | Runs the 5 hardcoded test cases with timing + pass/fail. "Run all" sequentially executes each; "Copy MD" dumps a results table for the eval spreadsheet. |
| **Free-form** | Paste any DATA (JSON) + USER_QUERY (한국어), inspect the model's output + latency + char count. |

Decoding is greedy (`temperature 0`, `topK 1`) so pass/fail containment checks stay deterministic. A fresh session is opened per inference, so TC5-style prompt-injection attempts can never persist across calls.

## One-time setup

The repo ships `lib/`, `pubspec.yaml`, `assets/`, and docs. You need to materialize the native platform scaffolds and sideload the model.

### 1. Generate native platform directories

```bash
flutter create . --platforms=android,ios --org com.example --project-name martprice
flutter pub get
```

### 2. Apply native config deltas

**`android/app/build.gradle`** (inside `defaultConfig { ... }`):

```gradle
minSdkVersion 28
ndk {
    abiFilters 'arm64-v8a'
}
```

**`android/app/src/main/AndroidManifest.xml`** (inside `<application>`):

```xml
android:largeHeap="true"
```

**`ios/Podfile`** (top):

```ruby
platform :ios, '16.0'
```

Then:

```bash
cd ios && pod install && cd ..
```

### 3. Sideload the model

Download `gemma-4-E2B-it-int4.litertlm` from <https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm> (accept the license first). The app looks for this file at:

```
<applicationDocumentsDirectory>/gemma-4-E2B-it-int4.litertlm
```

**Android (via adb):**

```bash
adb push gemma-4-E2B-it-int4.litertlm \
  /sdcard/Android/data/com.example.martprice/files/
```

**iOS (via Xcode):** open **Window → Devices and Simulators**, select the device, pick the installed app, click the gear icon under *Installed Apps* → *Download Container*, drop the `.litertlm` into `Documents/`, then re-upload the container (or use **Add Files** to push directly).

If the file is missing, the app opens on a "Model not found" screen showing the expected path.

## Running

```bash
# Android
flutter run -d <device-id>

# iOS (on macOS)
flutter run -d <device-id>
```

First load takes 5–10 s on Tab S7 / iPhone 16 Pro. Inference is ~2–4 s per test case at E2B.

## Device compatibility

| Device | RAM | Status |
|---|---|---|
| iPhone 16 Pro | 8 GB | ✅ supported |
| Galaxy Tab S7 | 6–8 GB | ✅ supported |
| Galaxy S22/S23 | 8–12 GB | ✅ supported |
| Galaxy S7 phone (2016) | 4 GB | ⚠️ below floor — expect OOM on load |

If you need to target the 2016 S7 phone, swap to a smaller quant (int8 → int4) and confirm the `.litertlm` variant exists, or step down to Gemma 2 2B.

## Running the test cases

1. Launch the app → **Harness** tab.
2. Tap **Run all**.
3. Wait for all 5 cards to turn ✅/❌.
4. Tap **Copy MD** to paste a results table into the tracking doc.

Record the output from both an Android device and iPhone 16 Pro. TC3 (empty-state) and TC5 (prompt injection) are the zero-tolerance gates — any failure there means the model+prompt combination ships broken.

## Files to know

| Path | Purpose |
|---|---|
| `lib/prompt/system_prompt.dart` | The 10-rule system prompt (Korean, verbatim). **Tweak this when tests fail** — do not loosen the pass/fail checks. |
| `lib/prompt/user_template.dart` | `DATA:` / `USER_QUERY:` template, verbatim from the spec. |
| `lib/model/gemma_service.dart` | `flutter_gemma` wrapper: load, greedy inference, per-call session reset. |
| `lib/testharness/test_cases.dart` | The 5 cases + pass/fail rule lists. |
| `lib/testharness/pass_fail.dart` | `MustContain`, `MustNotContain`, `MustNotMatch`, `MaxLength` rule types. |
| `assets/fixtures/*.json` | Exact JSON blobs for each test case. |

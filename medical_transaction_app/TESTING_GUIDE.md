# Medical Transaction App - Testing Guide

This document provides comprehensive testing instructions for all features and flows required by the assignment.

## Prerequisites

### 1. Backend Setup
```bash
cd backend
npm install
npm start
```

The backend should be running on `http://localhost:3000`

**Verify backend is running:**
```bash
curl http://localhost:3000/health
# Should return: {"status":"ok","timestamp":"..."}
```

### 2. Flutter App Setup
```bash
cd medical_transaction_app
flutter pub get
flutter run
```

### 3. Platform-Specific Configuration

**For Android Emulator:**
- Update `lib/core/config/api_config.dart`:
  ```dart
  static const String defaultBaseUrl = 'http://10.0.2.2:3000';
  ```

**For iOS Simulator:**
- Uses `http://localhost:3000` (default)

**For Physical Devices:**
- Find your computer's IP: `ifconfig` (Mac/Linux) or `ipconfig` (Windows)
- Update `lib/core/config/api_config.dart` with your IP:
  ```dart
  static const String defaultBaseUrl = 'http://192.168.1.XXX:3000';
  ```

---

## Pass/Fail Test Scenarios (Required by Assignment)

These are the **critical tests** that must pass for the assignment.

### Test 1: 5-Minute Recording with Phone Locked ⭐

**Objective:** Verify audio streams to backend while phone is locked.

**Steps:**
1. Open the app
2. Tap "Start Recording" (or select a patient first)
3. Start recording
4. **Lock the phone** (press power button)
5. **Leave phone locked for 5 minutes**
6. Unlock phone
7. Stop recording

**Expected Results:**
- ✅ Recording continues while phone is locked
- ✅ Audio chunks are uploaded to backend during recording (not after)
- ✅ No data loss
- ✅ Backend receives chunks (check backend logs or database)

**How to Verify:**
- Check backend console logs for chunk uploads
- Verify chunks appear in backend storage
- Check app shows correct duration (5+ minutes)
- Verify no error messages in app

**Backend Verification:**
```bash
# Check backend logs for upload activity
# Look for: "Chunk uploaded successfully" messages
```

---

### Test 2: Phone Call Interruption ⭐

**Objective:** Verify auto-pause and auto-resume on phone calls.

**Steps:**
1. Start recording in the app
2. **Make a phone call** (call your own number or another phone)
3. Answer the call
4. Talk for 30 seconds
5. **End the call**
6. Return to the app

**Expected Results:**
- ✅ Recording **automatically pauses** when call starts
- ✅ Recording **automatically resumes** when call ends
- ✅ No audio lost during the call
- ✅ App shows "Paused" status during call
- ✅ App shows "Recording" status after call ends

**How to Verify:**
- App UI shows pause/resume state changes
- Recording duration timer pauses during call
- Audio level indicator stops during call
- Backend receives chunks before and after call (not during)

**Note:** This requires native platform channel implementation for phone call detection. Currently, the framework is in place but may need additional native code.

---

### Test 3: Network Outage Recovery ⭐

**Objective:** Verify chunks queue locally and upload when network returns.

**Steps:**
1. Start recording
2. Record for 30 seconds (let some chunks upload)
3. **Enable Airplane Mode** (or disconnect WiFi)
4. Continue recording for 1-2 minutes (chunks should queue locally)
5. **Disable Airplane Mode** (reconnect network)
6. Wait 30 seconds
7. Stop recording

**Expected Results:**
- ✅ Chunks continue to be created while offline
- ✅ Chunks are **queued locally** (stored in SQLite)
- ✅ When network returns, **queued chunks upload automatically**
- ✅ No data loss
- ✅ All chunks eventually reach backend

**How to Verify:**
- Check app logs for "No network connection" messages
- Check app logs for "Retrying upload" messages
- Verify all chunks appear in backend after network returns
- Check local SQLite database for pending chunks (before network returns)

**Backend Verification:**
```bash
# After network returns, check backend logs
# Should see multiple chunk uploads happening
```

**Database Check (if accessible):**
```bash
# Chunks should be in 'pending' or 'failed' status while offline
# Should change to 'uploaded' after network returns
```

---

### Test 4: Camera Integration During Recording ⭐

**Objective:** Verify recording continues when using camera.

**Steps:**
1. Start recording
2. **Switch to camera app** (or use in-app camera if implemented)
3. **Take a photo** (patient ID photo)
4. **Return to the recording app**
5. Continue recording for 30 seconds
6. Stop recording

**Expected Results:**
- ✅ Recording **continues** while camera is open
- ✅ Recording **continues** after returning to app
- ✅ No audio loss
- ✅ Proper native integration (camera doesn't interfere)

**How to Verify:**
- Recording duration continues counting
- Audio level indicator continues working
- Backend receives continuous chunks
- No error messages

**Note:** Camera integration UI may need to be added. The recording service should handle app switching gracefully.

---

### Test 5: App Kill and Recovery ⭐

**Objective:** Verify graceful recovery after app is killed.

**Steps:**
1. Start recording
2. Record for 1 minute
3. **Force kill the app** (swipe away from recent apps, or use task manager)
4. **Reopen the app**
5. Check app state

**Expected Results:**
- ✅ App **recovers gracefully** (no crashes)
- ✅ Session state is **saved** (or cleared appropriately)
- ✅ No orphaned recordings
- ✅ App shows clear state (either recovered session or clean start)

**How to Verify:**
- App opens without errors
- Check if session recovery dialog appears (if implemented)
- Verify no duplicate sessions in backend
- Check local database state

**Backend Verification:**
```bash
# Check that only one session exists (not duplicates)
# Verify session has correct status
```

---

## Core Feature Tests

### Test 6: Real-Time Audio Streaming

**Objective:** Verify chunks upload during recording (not after).

**Steps:**
1. Start recording
2. Record for 30 seconds
3. **Monitor backend logs** while recording
4. Stop recording

**Expected Results:**
- ✅ Chunks appear in backend logs **during recording**
- ✅ Chunks upload every 5 seconds (chunk duration)
- ✅ Upload happens **before** recording stops
- ✅ Not a batch upload after recording ends

**How to Verify:**
- Watch backend console for upload messages
- Check timestamps: chunks should arrive every ~5 seconds
- Verify chunks have sequence numbers (1, 2, 3, ...)

**Backend Logs to Watch:**
```
PUT /v1/upload-chunk/:sessionId/:chunkNumber - Chunk uploaded
POST /v1/notify-chunk-uploaded - Chunk confirmed
```

---

### Test 7: Audio Level Visualization

**Objective:** Verify real-time audio level display.

**Steps:**
1. Start recording
2. **Speak at different volumes:**
   - Whisper (low volume)
   - Normal speaking (medium volume)
   - Shout (high volume)
3. Observe audio level indicator

**Expected Results:**
- ✅ Audio level indicator **updates in real-time**
- ✅ Shows different levels for different volumes
- ✅ Visual feedback matches audio input
- ✅ Updates smoothly (no lag)

**How to Verify:**
- Visual indicator changes with voice volume
- Percentage or bar height changes
- Updates happen smoothly (not jerky)

---

### Test 8: Theme Switching (No Restart)

**Objective:** Verify theme changes without app restart.

**Steps:**
1. Open app
2. Go to Settings
3. **Change theme** (Light → Dark → System)
4. **Observe UI changes immediately**
5. **Kill and reopen app**
6. Verify theme persists

**Expected Results:**
- ✅ Theme changes **immediately** (no restart needed)
- ✅ All screens reflect new theme
- ✅ Theme **persists** after app restart
- ✅ System theme mode works (follows device setting)

**How to Verify:**
- UI colors change instantly
- Theme persists after app restart
- System theme follows device dark/light mode

---

### Test 9: Language Switching (No Restart)

**Objective:** Verify language changes without app restart.

**Steps:**
1. Open app
2. Go to Settings
3. **Change language** (English → Hindi)
4. **Observe UI text changes immediately**
5. Navigate through all screens
6. **Kill and reopen app**
7. Verify language persists

**Expected Results:**
- ✅ All UI text changes **immediately** (no restart)
- ✅ All screens show new language
- ✅ Language **persists** after app restart
- ✅ Both English and Hindi translations work

**How to Verify:**
- All buttons, labels, messages change language
- No English text remains
- Language persists after restart
- Test both directions: English ↔ Hindi

---

### Test 10: Patient Management Flow

**Objective:** Verify patient CRUD operations.

**Steps:**
1. **Add Patient:**
   - Go to Patients screen
   - Tap "+" button
   - Fill in name, phone, email
   - Save
2. **View Patients:**
   - Verify patient appears in list
3. **Start Recording with Patient:**
   - Tap on patient
   - Start recording
   - Verify patient name appears in recording screen
4. **View Patient Sessions:**
   - After recording, verify session is linked to patient

**Expected Results:**
- ✅ Patient is created successfully
- ✅ Patient appears in list
- ✅ Recording is linked to patient
- ✅ Sessions can be retrieved by patient

**How to Verify:**
- Patient appears in list immediately
- Patient name shows in recording screen
- Backend receives patient ID with session

---

### Test 11: Chunk Ordering and Sequence

**Objective:** Verify chunks maintain correct order.

**Steps:**
1. Start recording
2. Record for 1 minute (should create ~12 chunks)
3. Stop recording
4. Check backend for chunk sequence

**Expected Results:**
- ✅ Chunks have sequential numbers (1, 2, 3, ...)
- ✅ Chunks arrive in order (or are reordered correctly)
- ✅ No missing sequence numbers
- ✅ No duplicate sequence numbers

**How to Verify:**
- Check backend logs for chunk numbers
- Verify sequence: 1, 2, 3, 4, ...
- No gaps in sequence
- No duplicates

---

### Test 12: Retry Logic on Network Failure

**Objective:** Verify failed uploads retry automatically.

**Steps:**
1. Start recording
2. Record for 30 seconds
3. **Temporarily disconnect network** (for 10 seconds)
4. **Reconnect network**
5. Continue recording
6. Monitor retry behavior

**Expected Results:**
- ✅ Failed chunks are **queued locally**
- ✅ Chunks **retry automatically** when network returns
- ✅ Retry uses **exponential backoff**
- ✅ Eventually all chunks upload successfully

**How to Verify:**
- Check app logs for retry messages
- Verify chunks eventually upload
- Check retry delays increase (exponential backoff)

---

### Test 13: Background Recording (App Minimized)

**Objective:** Verify recording continues when app is minimized.

**Steps:**
1. Start recording
2. **Press home button** (minimize app)
3. **Wait 1 minute**
4. **Reopen app**
5. Check recording status

**Expected Results:**
- ✅ Recording **continues** while app is minimized
- ✅ Duration continues counting
- ✅ Chunks continue uploading
- ✅ App shows correct state when reopened

**How to Verify:**
- Duration shows more time when app reopens
- Backend receives chunks while app is minimized
- No data loss

**Note:** Requires foreground service (Android) or background audio (iOS) to be properly configured.

---

### Test 14: Native Share Sheet

**Objective:** Verify native share functionality.

**Steps:**
1. Complete a recording session
2. **Use share functionality** (if implemented in UI)
3. Verify native share sheet appears

**Expected Results:**
- ✅ **Native share sheet** appears (not custom UI)
- ✅ Can share to other apps
- ✅ Platform-specific share options available

**How to Verify:**
- Share sheet looks native (iOS/Android specific)
- Can share to messaging, email, etc.
- Not a custom Flutter dialog

---

### Test 15: Haptic Feedback

**Objective:** Verify haptic feedback on key actions.

**Steps:**
1. **Start recording** - should feel haptic feedback
2. **Stop recording** - should feel haptic feedback
3. **Pause/Resume** - should feel haptic feedback

**Expected Results:**
- ✅ **Haptic feedback** on start/stop/pause actions
- ✅ Different feedback types (medium impact, light impact)
- ✅ Feedback feels native

**How to Verify:**
- Feel vibration/haptic on button presses
- Different intensities for different actions

---

## Advanced Tests (If Implemented)

### Test 16: Gain Control

**Objective:** Verify microphone gain can be adjusted.

**Steps:**
1. Start recording
2. **Adjust gain control** (if UI exists)
3. Speak at same volume
4. Observe audio level changes

**Expected Results:**
- ✅ Audio level changes with gain adjustment
- ✅ Gain persists during recording
- ✅ Not just on/off, but variable control

---

### Test 17: Bluetooth/Wired Headset Switching

**Objective:** Verify audio input switches correctly.

**Steps:**
1. Start recording with phone microphone
2. **Connect Bluetooth headset**
3. Continue recording
4. **Disconnect headset**
5. Continue recording

**Expected Results:**
- ✅ Recording continues when headset connects
- ✅ Audio source switches automatically
- ✅ No interruption or data loss

---

## Testing Checklist

Use this checklist to ensure all tests are completed:

### Critical Pass/Fail Tests
- [ ] Test 1: 5-minute recording with phone locked
- [ ] Test 2: Phone call interruption
- [ ] Test 3: Network outage recovery
- [ ] Test 4: Camera integration during recording
- [ ] Test 5: App kill and recovery

### Core Features
- [ ] Test 6: Real-time audio streaming
- [ ] Test 7: Audio level visualization
- [ ] Test 8: Theme switching (no restart)
- [ ] Test 9: Language switching (no restart)
- [ ] Test 10: Patient management flow
- [ ] Test 11: Chunk ordering and sequence
- [ ] Test 12: Retry logic on network failure
- [ ] Test 13: Background recording (app minimized)

### Native Features
- [ ] Test 14: Native share sheet
- [ ] Test 15: Haptic feedback
- [ ] Test 16: Gain control (if implemented)
- [ ] Test 17: Bluetooth/wired headset switching (if implemented)

---

## Troubleshooting

### Backend Not Responding
- Check if backend is running: `curl http://localhost:3000/health`
- Check backend logs for errors
- Verify port 3000 is not in use by another app

### App Can't Connect to Backend
- **Android Emulator:** Change base URL to `http://10.0.2.2:3000`
- **Physical Device:** Use your computer's IP address
- Check firewall settings
- Verify backend CORS is enabled

### Recording Doesn't Work
- Check microphone permissions
- Verify audio recording service is initialized
- Check app logs for permission errors

### Chunks Not Uploading
- Check network connection
- Verify backend is running
- Check app logs for upload errors
- Verify chunk files are being created locally

### Theme/Language Not Persisting
- Check SharedPreferences is working
- Verify Provider state management
- Check for errors in console

---

## Backend Monitoring

### View Backend Logs
```bash
cd backend
npm start
# Watch console for request logs
```

### Check Backend Data (In-Memory)
The mock backend stores data in memory. To see current state:
- Check console logs for session/patient creation
- All data resets when server restarts

### Test Backend Directly
```bash
# Health check
curl http://localhost:3000/health

# Create session
curl -X POST http://localhost:3000/v1/upload-session \
  -H "Content-Type: application/json" \
  -d '{"userId":"test","patientName":"Test"}'

# Get patients
curl "http://localhost:3000/v1/patients?userId=test"
```

---

## Expected Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| Test 1: Locked Phone Recording | ⚠️ Needs Testing | Requires background service |
| Test 2: Phone Call Interruption | ⚠️ Needs Testing | Requires native call detection |
| Test 3: Network Outage | ✅ Should Work | Retry logic implemented |
| Test 4: Camera Integration | ⚠️ Needs Testing | Recording should continue |
| Test 5: App Kill Recovery | ⚠️ Needs Testing | Session recovery implemented |
| Test 6: Real-Time Streaming | ✅ Should Work | Chunks upload during recording |
| Test 7: Audio Levels | ✅ Should Work | Visualization implemented |
| Test 8: Theme Switching | ✅ Should Work | Provider + SharedPreferences |
| Test 9: Language Switching | ✅ Should Work | Full UI translation |
| Test 10: Patient Management | ✅ Should Work | CRUD operations implemented |

---

## Quick Test Commands

### Start Backend
```bash
cd backend && npm start
```

### Run Flutter App
```bash
cd medical_transaction_app && flutter run
```

### Check Backend Health
```bash
curl http://localhost:3000/health
```

### View App Logs
```bash
flutter run --verbose
```

### Build Release APK
```bash
flutter build apk --release
```

---

## Notes

- **All tests should be performed on physical devices or emulators** (not just web)
- **Background features** require proper platform configuration
- **Phone call detection** may need additional native code
- **Network testing** can use airplane mode or network disconnection
- **Record test results** for the demo video

---

## For Demo Video

When creating the 5-minute demo video, make sure to show:
1. ✅ 3-5 minute recording with phone locked
2. ✅ Phone call interruption with auto-recovery
3. ✅ Native features: camera, microphone levels, share sheet
4. ✅ Network dead zone with queued uploads
5. ✅ Heavy multitasking without data loss

Good luck with your testing! 🚀


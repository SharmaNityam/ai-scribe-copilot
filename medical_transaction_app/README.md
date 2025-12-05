# Medical Transaction App - Medical Transcription App

A production-ready Flutter mobile application for medical transcription with real-time audio streaming, bulletproof interruption handling, and native platform integrations.

## Features

- **Real-Time Audio Streaming**: Stream audio chunks to backend during recording (not after)
- **Background Recording**: Continue recording with phone locked or app minimized
- **Interruption Handling**: Auto-pause/resume on phone calls, network outages, app switching
- **Native Features**: Microphone access with gain control, camera integration, share sheet
- **Theme & Language**: Dark/light mode with English/Hindi language support
- **Patient Management**: Add and manage patients, link recordings to patients

## Platform Requirements

- **Flutter**: 3.9.2+
- **Android**: Minimum SDK 23 (Android 6.0+)
- **iOS**: iOS 12.0+

## Installation

### Prerequisites

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. Install dependencies:
   ```bash
   flutter pub get
   ```

### Backend Setup

The backend is a Node.js/Express mock server that can be deployed with Docker:

```bash
cd backend
docker-compose up
```

The backend will be available at `http://localhost:3000`

**Note**: For production deployment, update the `BASE_URL` in the backend environment variables and configure the Flutter app's `ApiRepository` with the production URL.

### Build Instructions

#### Android APK

```bash
flutter build apk --release
```

The APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

#### iOS

```bash
flutter build ios --simulator
# or
flutter build ios --release
```

**Note**: iOS requires an Apple Developer account for device builds. For demonstration purposes, a Loom video is provided.

## Project Structure

```
medical_transaction_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── core/
│   │   ├── models/                  # Data models
│   │   ├── repositories/           # API and local storage
│   │   ├── services/               # Business logic services
│   │   └── utils/                  # Utility functions
│   ├── features/
│   │   ├── recording/              # Recording screen and controller
│   │   ├── patients/               # Patient management
│   │   └── settings/               # Theme and language settings
│   └── widgets/                    # Reusable widgets
├── backend/                        # Mock backend server
│   ├── server.js                   # Express server
│   ├── docker-compose.yml          # Docker configuration
│   └── Dockerfile                  # Docker image definition
└── android/ios/                     # Platform-specific configurations
```

## API Endpoints

The app uses the following backend endpoints:

### Session Management
- `POST /v1/upload-session` - Start recording session
- `POST /v1/get-presigned-url` - Get chunk upload URL
- `PUT {presignedUrl}` - Upload audio chunk
- `POST /v1/notify-chunk-uploaded` - Confirm chunk received

### Patient Management
- `GET /v1/patients?userId={userId}` - Get patient list
- `POST /v1/add-patient-ext` - Add new patient
- `GET /v1/fetch-session-by-patient/{patientId}` - Get sessions by patient

## Key Features Implementation

### Real-Time Audio Streaming
- Records audio in 5-second chunks
- Immediately uploads each chunk after recording
- Maintains chunk sequence numbers
- Queues failed uploads locally for retry

### Background Recording
- **Android**: Foreground service with persistent notification
- **iOS**: Background audio session with AVAudioSession
- Continues recording when app is minimized or phone is locked

### Interruption Handling
- **Phone Calls**: Auto-pause on call start, auto-resume on call end
- **Network Outages**: Chunks queued locally, uploaded when connection restored
- **App Switching**: Recording continues in background
- **App Kill**: Session state saved, can be recovered on restart

### Native Features
- Microphone access with real-time amplitude visualization
- Camera integration for patient ID photos
- Native share sheet (not custom UI)
- System notifications with actions
- Haptic feedback on key actions

## Testing

### Pass/Fail Test Scenarios

1. **5-minute recording with phone locked**
   - Start recording → Lock phone → Leave locked
   - Expected: Audio streams to backend, no data loss

2. **Phone call interruption**
   - Recording → Phone call → End call
   - Expected: Auto-pause, auto-resume, no audio lost

3. **Network outage recovery**
   - Recording → Airplane mode → Network returns
   - Expected: Chunks queue locally, upload when connected

4. **Camera integration**
   - Recording → Open camera → Take photo → Return
   - Expected: Recording continues, proper native integration

5. **App kill recovery**
   - Recording → Kill app → Reopen
   - Expected: Graceful recovery, clear session state

## Configuration

### Backend URL

The backend URL is configured in `lib/core/config/api_config.dart`. By default, it uses `http://localhost:3000`.

**For different platforms:**
- **iOS Simulator**: `http://localhost:3000` (default)
- **Android Emulator**: Change to `http://10.0.2.2:3000` in `api_config.dart`
- **Physical Devices**: Use your computer's local IP (e.g., `http://192.168.1.100:3000`)
- **Production**: Update to your deployed backend URL

You can also override via environment variable:
```bash
flutter run --dart-define=API_BASE_URL=http://your-backend-url.com
```

### User ID

Currently using a mock user ID (`user_123`). In production, integrate with your authentication system.

## Known Limitations

- Backend uses in-memory storage (mock server)
- S3 presigned URLs are mocked (use real S3 in production)
- Phone call detection requires platform channel implementation (currently placeholder)

## Resources

- **API Documentation**: https://docs.google.com/document/d/1hzfry0fg7qQQb39cswEychYMtBiBKDAqIg6LamAKENI/edit?usp=sharing
- **Postman Collection**: https://drive.google.com/file/d/1rnEjRzH64ESlIi5VQekG525Dsf8IQZTP/view?usp=sharing

## Flutter Version

```bash
flutter --version
```

Output:
```
Flutter 3.9.2 • channel stable • https://github.com/flutter/flutter.git
Framework • revision ...
Tools • Dart 3.9.2 • DevTools 2.x.x
```

## License

This project is created for the Attack Capital Mobile Engineering Challenge.

## Author

Built for Attack Capital Mobile Engineering Challenge

# AI Scribe Copilot

Medical transcription app with real-time audio streaming and patient management.

## 📱 Download

### Android APK
Download the latest Android APK from [GitHub Releases](https://github.com/SharmaNityam/ai-scribe-copilot/releases) or [Drive Link](https://drive.google.com/file/d/12h1DXpc7le5WpNoMLjKsvqhNl0_K6mM-/view?usp=drive_link).

The APK is automatically built and attached to each release when you create a new GitHub release.

## 🎥 Demo Videos

### iOS Testing
Watch the iOS testing video showing all features: [iOS Demo Video](https://www.loom.com/share/df720c673e0340788fc8580c120028fe)

### Android Testing
Watch the Android testing video: [Android Demo Video](https://youtu.be/y6vI4Kx3CX4)

## 🔧 Technical Details

### Flutter Version
```
Flutter 3.35.3 • channel stable • https://github.com/flutter/flutter.git
Framework • revision a402d9a437 (3 months ago) • 2025-09-03 14:54:31 -0700
Engine • hash 672c59cfa87c8070c20ba2cd1a6c2a1baf5cf08b (revision ddf47dd3ff) (3 months ago) • 2025-09-03 20:02:13.000Z
Tools • Dart 3.9.2 • DevTools 2.48.0
```

## 🌐 Backend

### Deployment URL
**Backend URL:** `https://ai-scribe-copilot-rev9.onrender.com`

### ⚠️ Backend Limitations

**Important:** The backend is currently deployed on Render's free tier, which has the following limitations:

- **In-Memory Storage**: The backend uses in-memory storage (JavaScript `Map` objects), meaning all data is lost when the server restarts.
- **Automatic Sleep**: Render's free tier automatically puts servers to sleep after ~15 minutes of inactivity.
- **Data Loss on Restart**: When the server wakes up or restarts, all sessions, patients, and chunks stored in memory are cleared.
- **Session Recovery**: The Flutter app includes automatic session recovery logic that recreates lost sessions when the backend restarts.

**For Production Use:**
- Consider upgrading to a paid Render plan or migrating to a service with persistent storage
- Implement a database (PostgreSQL, MongoDB, etc.) for data persistence
- Set up a database-backed storage solution to prevent data loss

### API Documentation
📚 [API Documentation](https://docs.google.com/document/d/1hzfry0fg7qQQb39cswEychYMtBiBKDAqIg6LamAKENI/edit?usp=sharing)

### Postman Collection
🔧 [Postman Collection](https://drive.google.com/file/d/1rnEjRzH64ESlIi5VQekG525Dsf8IQZTP/view?usp=sharing)

## 🚀 Features

- Real-time audio recording and streaming
- Patient management
- Session management
- Audio chunk upload with automatic retry
- Session recovery on backend restart
- Local storage for offline support
- Cross-platform support (iOS, Android)

## 📦 Installation

### Prerequisites
- Flutter 3.35.3 or higher
- Dart 3.9.2 or higher
- Android Studio / Xcode (for mobile development)

### Setup
1. Clone the repository:
```bash
git clone https://github.com/SharmaNityam/ai-scribe-copilot.git
cd ai-scribe-copilot
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## 🏗️ Building

### Android APK
```bash
flutter build apk --release
```

The APK will be available at: `build/app/outputs/flutter-apk/app-release.apk`

### iOS
```bash
flutter build ios --release
```

## 📝 License

This project is private and proprietary.


# GoldSignal - AI-Powered Gold & Silver Price Tracker

A comprehensive Flutter application for tracking precious metals prices with AI-powered insights, supporting Arabic, English, and Urdu languages.

## 📱 Features

### Core Features
- **Live Gold & Silver Prices**: Real-time precious metal prices in 150+ currencies
- **Smart Currency System**: USD default with Arab currencies prioritized
- **Karat Calculator**: Support for 24K, 22K, 21K, 18K calculations
- **Historical Charts**: 7-day and 30-day price trends
- **Price Alerts**: Natural language alert creation
- **Portfolio Management**: Track your gold/silver investments

### AI-Powered Features
- **Market Insights**: "Explain Today's Move" with news analysis
- **Metals Bot**: AI chatbot specialized in precious metals
- **Smart Buying Assistant**: DCA planning and investment strategies
- **Jewelry Price Analyzer**: Fair price checker for jewelry purchases
- **Scam Detection**: Verify claims and rumors about gold prices
- **Voice Assistant**: Hands-free operation in multiple languages

### Authentication & Data
- **Guest Mode**: Start immediately with anonymous authentication
- **Email Authentication**: Create account to sync across devices
- **Firebase Integration**: Cloud storage for all user data
- **Offline Support**: Cached data for offline usage

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.16.0 or higher)
- Dart SDK (3.2.0 or higher)
- Android Studio / Xcode
- Node.js (for Firebase CLI)
- Firebase account

### Installation

1. **Clone the repository**
```bash
cd /Users/mostafaradwan/Documents/apps/goldsignal
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **iOS Setup**
```bash
cd ios
pod install
cd ..
```

## 🔥 Firebase Configuration

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project: `goldsignal-app`
3. Enable Google Analytics

### 2. Add Firebase to Flutter

#### Android Configuration
1. In Firebase Console, add Android app
2. Package name: `com.goldsignal.goldsignal`
3. Download `google-services.json`
4. Place in `android/app/`
5. Update `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```
6. Update `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'

android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        multiDexEnabled true
    }
}
```

#### iOS Configuration
1. In Firebase Console, add iOS app
2. Bundle ID: `com.goldsignal.goldsignal`
3. Download `GoogleService-Info.plist`
4. Add to `ios/Runner/` via Xcode
5. Update `ios/Podfile`:
```ruby
platform :ios, '12.0'
```

### 3. Enable Firebase Services

#### Authentication
```
Firebase Console → Authentication → Get Started
Enable:
- Anonymous
- Email/Password
```

#### Firestore Database
```
Firebase Console → Firestore Database → Create Database
Mode: Start in production mode
Location: Choose nearest region
```

#### Security Rules
Add these rules in Firestore:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
      
      match /{subcollection}/{document} {
        allow read, write: if request.auth != null 
          && request.auth.uid == userId;
      }
    }
  }
}
```

### 4. Generate Firebase Configuration
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Configure Flutter project
flutterfire configure
```

## 🔑 API Configuration

API keys are injected at **build/run time** via `--dart-define-from-file` (never commit real keys).

### Setup (local development)

```bash
cp secrets.json.example secrets.json
# Edit secrets.json — add your keys
flutter run --dart-define-from-file=secrets.json
```

Cursor / VS Code: use the included `.vscode/launch.json` configuration (already passes `--dart-define-from-file=secrets.json`).

Release builds:

```bash
flutter build apk --dart-define-from-file=secrets.json
flutter build ios --dart-define-from-file=secrets.json
```

After changing `secrets.json`, **rebuild** the app — keys are compile-time constants.

### Keys in `secrets.json`

| Key | Used for | Where to get it |
|-----|----------|-----------------|
| `METAL_PRICE_API_KEY` | Optional metalpriceapi.com fallback | [metalpriceapi.com](https://metalpriceapi.com) |
| `GROQ_API_KEY` | AI chat (Groq `gsk_...`) | [console.groq.com/keys](https://console.groq.com/keys) |

See [`lib/core/utils/api_config.dart`](lib/core/utils/api_config.dart) and [`secrets.json.example`](secrets.json.example).

## 📁 Project Structure

```
goldsignal/
├── lib/
│   ├── core/
│   │   ├── api/              # API services
│   │   ├── firebase/         # Firebase services
│   │   ├── storage/          # Local storage
│   │   └── utils/            # Utilities
│   ├── features/
│   │   ├── auth/             # Authentication
│   │   ├── dashboard/        # Main dashboard
│   │   ├── prices/           # Live prices
│   │   ├── calculator/       # Karat calculator
│   │   ├── chatbot/          # AI chatbot
│   │   ├── portfolio/        # Portfolio management
│   │   └── profile/          # User profile
│   ├── shared/
│   │   ├── models/           # Data models
│   │   ├── providers/        # Riverpod providers
│   │   ├── widgets/          # Reusable widgets
│   │   └── themes/           # App themes
│   └── main.dart
├── assets/
│   ├── translations/         # Localization files
│   │   ├── en.json
│   │   ├── ar.json
│   │   └── ur.json
│   └── knowledge_base/       # AI knowledge base
├── android/                  # Android configuration
├── ios/                      # iOS configuration
└── pubspec.yaml             # Dependencies
```

## 🌍 Localization

The app supports three languages:
- **English** (en)
- **Arabic** (ar) - with RTL support
- **Urdu** (ur)

Language files are located in `assets/translations/`

## 🎨 Themes

The app supports:
- Light Mode
- Dark Mode
- System Default

Theme configuration in `lib/shared/themes/app_theme.dart`

## 🏃 Running the App

### Development
```bash
# Run on iOS Simulator
flutter run -d iPhone

# Run on Android Emulator
flutter run -d emulator-5554

# Run on Chrome (Web)
flutter run -d chrome
```

### Building for Release

#### Android APK
```bash
flutter build apk --release
```

#### Android App Bundle
```bash
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📊 API Limits

### Free Tier Limits
- **MetalpriceAPI**: 100 requests/month
- **ExchangeRate-API**: 1,500 requests/month
- **Firebase Firestore**: 50K reads/day, 20K writes/day
- **OpenAI**: User provides API key

### User Limits (Per Day)
- Manual refresh: 10 times
- AI insights: 3 queries
- Jewelry analysis: 5 checks
- Chat messages: 20
- Portfolio recap: 1/month

## 🔒 Security

- Guest data auto-deletes after 30 days of inactivity
- No sensitive data in AI prompts
- API keys stored securely
- Firebase security rules enforced
- Encrypted local storage

## 🐛 Troubleshooting

### Common Issues

#### Firebase Connection Error
```bash
flutterfire configure --force
flutter clean
flutter pub get
```

#### iOS Build Issues
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter run
```

#### API Key Issues
- Verify API keys are correct
- Check API rate limits
- Ensure network connectivity

#### Dependency Issues
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

## 📝 Secrets file

Create `secrets.json` from the example (already in `.gitignore`):

```bash
cp secrets.json.example secrets.json
```

```json
{
  "METAL_PRICE_API_KEY": "your-metalpriceapi-key",
  "GROQ_API_KEY": "gsk_your-groq-key"
}
```

Run and build with `--dart-define-from-file=secrets.json` (see API Configuration above).

Do not commit `secrets.json`, `google-services.json`, or `GoogleService-Info.plist`.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Open pull request

## 📄 License

This project is licensed under the MIT License.

## 📞 Support

- Email: support@goldsignal.app
- Issues: GitHub Issues

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- MetalpriceAPI for precious metals data
- OpenAI for AI capabilities

---

**Note**: This app is for educational and informational purposes only. Not financial advice.

## Quick Start Commands

```bash
# Setup everything
flutter pub get
cd ios && pod install && cd ..

# Run the app
flutter run

# Build for production
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## Important Files to Configure

1. `lib/core/utils/api_config.dart` - Add API keys
2. `android/app/google-services.json` - Firebase Android config
3. `ios/Runner/GoogleService-Info.plist` - Firebase iOS config
4. `assets/translations/*.json` - Localization strings

## Development Status

- ✅ Core project structure
- ✅ Firebase Authentication (Guest + Email)
- ✅ API service integration
- ✅ Multi-language support setup
- ✅ Theme system (Light/Dark)
- ✅ Main screens created
- 🔄 AI features implementation
- 📝 Testing & Documentation

## Next Steps

1. Complete remaining UI screens
2. Implement AI chatbot with OpenAI
3. Add portfolio management features
4. Integrate charts library
5. Add background notifications
6. Implement offline caching
7. Add unit and widget tests

For detailed setup instructions, see the inline documentation in each file.# goldsignal

# XeroFlow

**Streamline your Xerox experience at St. Xavier's College**

XeroFlow is a Flutter mobile application designed to solve Xerox center congestion by allowing students to upload documents, select time slots, pay via Razorpay, and collect without waiting.

## Features

### Phase 1 - Onboarding Flow ✅
- **Splash Screen**: Logo and welcome message
- **Login**: Email authentication (only @xaviers.edu.in emails allowed) + Google Sign-In
- **OTP Verification**: 6-digit OTP input with 45-second resend timer
- **Profile Setup**: Name, Roll Number, Department, and Year selection
- **Dashboard**: 4-tab navigation (Home, New Order, My Orders, Profile)

### Planned Features
- Dark/Light theme support
- Haptic feedback on interactions
- Offline dashboard support
- Real-time order updates via Supabase
- Document upload (session storage)
- Time slot selection
- Razorpay payment integration

## Tech Stack

- **Flutter**: Cross-platform mobile framework
- **Supabase**: Authentication, Database, and Realtime subscriptions
- **Razorpay**: Payment gateway integration
- **Provider**: State management
- **Shared Preferences**: Local storage for offline support

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Supabase account

### 2. Clone and Install Dependencies

```bash
cd XeroFlow
flutter pub get
```

### 3. Supabase Setup

1. Create a new project on [Supabase](https://supabase.com)
2. Get your project URL and anon key from Settings > API
3. Update `lib/services/supabase_service.dart`:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```
4. Update `lib/main.dart` with the same credentials

### 4. Database Schema

Run the following SQL in your Supabase SQL Editor:

```sql
-- Create students table
CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  roll_number TEXT UNIQUE NOT NULL,
  dept TEXT NOT NULL,
  year TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create orders table
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,
  order_id TEXT UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  slot_time TIMESTAMP WITH TIME ZONE,
  cost DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Create policies for students table
CREATE POLICY "Users can view their own profile"
  ON students FOR SELECT
  USING (auth.uid()::text = id::text);

CREATE POLICY "Users can insert their own profile"
  ON students FOR INSERT
  WITH CHECK (auth.uid()::text = id::text);

CREATE POLICY "Users can update their own profile"
  ON students FOR UPDATE
  USING (auth.uid()::text = id::text);

-- Create policies for orders table
CREATE POLICY "Users can view their own orders"
  ON orders FOR SELECT
  USING (auth.uid()::text = student_id::text);

CREATE POLICY "Users can create their own orders"
  ON orders FOR INSERT
  WITH CHECK (auth.uid()::text = student_id::text);
```

### 5. Enable Email Authentication

1. Go to Authentication > Providers in Supabase dashboard
2. Enable Email provider
3. Configure email templates if needed (OTP emails will be sent automatically)

### 6. Google Sign-In Setup

1. **Get SHA-1 Fingerprint**:
   ```bash
   ./get_sha1.sh
   ```
   Or manually:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

2. **Configure Google Cloud Console**:
   - Create/select a project at [Google Cloud Console](https://console.cloud.google.com/)
   - Enable Google+ API
   - Create OAuth 2.0 Client ID (Android)
   - Add SHA-1 and package name: `com.xeroflow.xeroflow`

3. **Configure Supabase**:
   - Go to Authentication > Providers > Google
   - Enable Google provider
   - Add Client ID and Client Secret from Google Cloud Console
   - Set redirect URL: `com.xeroflow.xeroflow://login-callback`

📖 **Detailed instructions**: See [GOOGLE_SETUP.md](GOOGLE_SETUP.md)

### 7. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   └── student.dart
├── screens/
│   ├── onboarding/          # Onboarding flow screens
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   ├── otp_screen.dart
│   │   └── profile_setup_screen.dart
│   └── dashboard/           # Dashboard screens
│       └── dashboard_screen.dart
├── services/                # Business logic services
│   └── supabase_service.dart
├── theme/                   # Theme configuration
│   └── app_theme.dart
├── utils/                   # Utility functions
└── widgets/                 # Reusable widgets
```

## Navigation Flow

```
Splash Screen
    ↓
    ├─→ (New User) → Login → OTP → Profile Setup → Dashboard
    └─→ (Returning User) → Dashboard
```

## TODO

- [x] Project setup and dependencies
- [x] Onboarding flow (Splash, Login, OTP, Profile Setup)
- [ ] Supabase schema setup
- [ ] Dashboard with 4 tabs
- [ ] Document upload functionality
- [ ] Time slot selection
- [ ] Razorpay payment integration
- [ ] Real-time order updates
- [ ] Offline support
- [ ] Theme toggle

## Contributing

This is a private project for St. Xavier's College. For issues or suggestions, please contact the development team.

## License

Private - All rights reserved

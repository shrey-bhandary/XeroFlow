# Google Sign-In Setup Guide for XeroFlow

This guide will help you set up Google Sign-In for your XeroFlow app.

## Prerequisites

- Google Cloud Console account
- Flutter project with Supabase configured
- Android Studio (for SHA-1 generation)

## Step 1: Get Your SHA-1 Fingerprint

### Option A: Using the provided script (Recommended)

1. Make the script executable:
   ```bash
   chmod +x get_sha1.sh
   ```

2. Run the script:
   ```bash
   ./get_sha1.sh
   ```

3. Copy the SHA-1 value(s) shown in the output

### Option B: Manual method

#### For Debug Build (Development):
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### For Release Build (Production):
```bash
keytool -list -v -keystore android/app/key.jks -alias key
```
(You'll need to enter your keystore password)

Look for the **SHA1** value in the output.

### Option C: Using Gradle (Alternative)

Add this to your `android/app/build.gradle.kts`:

```kotlin
android {
    // ... existing code ...
    
    signingConfigs {
        getByName("debug") {
            // This will print SHA-1 in build output
        }
    }
}
```

Then run:
```bash
cd android && ./gradlew signingReport
```

## Step 2: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google+ API** (if not already enabled)
   - Go to **APIs & Services > Library**
   - Search for "Google+ API"
   - Click **Enable**

## Step 3: Configure OAuth Consent Screen

1. Go to **APIs & Services > OAuth consent screen**
2. Choose **External** (unless you have a Google Workspace)
3. Fill in the required information:
   - App name: **XeroFlow**
   - User support email: Your email
   - Developer contact: Your email
4. Add scopes:
   - `email`
   - `profile`
   - `openid`
5. Add test users (your @xaviers.edu.in email) if in testing mode
6. Click **Save and Continue** through all steps

## Step 4: Create OAuth 2.0 Client ID

1. Go to **APIs & Services > Credentials**
2. Click **+ CREATE CREDENTIALS > OAuth client ID**
3. Select **Android** as application type
4. Fill in:
   - **Name**: XeroFlow Android
   - **Package name**: `com.xeroflow.xeroflow`
   - **SHA-1 certificate fingerprint**: Paste the SHA-1 you got in Step 1
5. Click **Create**
6. **Copy the Client ID** (you'll need this for Supabase)

## Step 5: Configure Supabase

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Navigate to **Authentication > Providers**
3. Find **Google** and click to configure
4. Enable Google provider
5. Enter your **Client ID** and **Client Secret** from Google Cloud Console
6. Set **Redirect URL** to: `com.xaviers.xeroflow://login-callback`
7. Click **Save**

## Step 6: Update Android Configuration

The AndroidManifest.xml should already be configured, but verify it includes:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    <!-- Deep link for OAuth callback -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="com.xeroflow.xeroflow"/>
    </intent-filter>
</activity>
```

## Step 7: Test Google Sign-In

1. Run your app: `flutter run`
2. On the login screen, tap **Continue with Google**
3. Select a Google account with @xaviers.edu.in email
4. The app should authenticate and navigate to profile setup or dashboard

## Troubleshooting

### "Sign in failed" error
- Verify SHA-1 is correctly added in Google Cloud Console
- Check package name matches exactly: `com.xeroflow.xeroflow`
- Ensure OAuth consent screen is configured

### "Redirect URI mismatch" error
- Verify redirect URL in Supabase matches: `com.xeroflow.xeroflow://login-callback`
- Check AndroidManifest.xml has the correct intent filter

### Email domain validation
- The app only allows @xaviers.edu.in emails
- If a non-Xaviers email signs in, they'll be signed out automatically

### SHA-1 not working
- Make sure you're using the correct keystore (debug vs release)
- For production, you need the release keystore SHA-1
- Re-run the SHA-1 command after generating a new keystore

## Important Notes

1. **Debug vs Release**: You need separate SHA-1 values for debug and release builds
2. **Package Name**: Must match exactly in Google Cloud Console and AndroidManifest.xml
3. **Email Restriction**: Only @xaviers.edu.in emails are allowed (enforced in code)
4. **Testing**: Add test users in OAuth consent screen during development

## Next Steps

After setup:
- Test with a @xaviers.edu.in Google account
- Complete profile setup after first Google sign-in
- The app will remember the user for subsequent logins


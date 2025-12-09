#!/bin/bash

# Script to get SHA-1 fingerprint for Google Sign-In setup
# This is needed for Android Google Sign-In configuration

echo "=========================================="
echo "Getting SHA-1 Fingerprint for XeroFlow"
echo "=========================================="
echo ""

# Check if keytool is available
if ! command -v keytool &> /dev/null
then
    echo "Error: keytool not found. Make sure Java JDK is installed."
    exit 1
fi

# Path to debug keystore (default Flutter location)
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"
RELEASE_KEYSTORE="android/app/key.jks"

echo "1. Getting DEBUG SHA-1 (for development):"
echo "-------------------------------------------"
if [ -f "$DEBUG_KEYSTORE" ]; then
    keytool -list -v -keystore "$DEBUG_KEYSTORE" -alias androiddebugkey -storepass android -keypass android | grep -A 5 "Certificate fingerprints" | grep SHA1
else
    echo "Debug keystore not found at: $DEBUG_KEYSTORE"
    echo "Run 'flutter build apk --debug' first to generate it."
fi

echo ""
echo "2. Getting RELEASE SHA-1 (for production):"
echo "-------------------------------------------"
if [ -f "$RELEASE_KEYSTORE" ]; then
    echo "Enter keystore password when prompted:"
    keytool -list -v -keystore "$RELEASE_KEYSTORE" | grep -A 5 "Certificate fingerprints" | grep SHA1
else
    echo "Release keystore not found at: $RELEASE_KEYSTORE"
    echo "You need to create a release keystore first."
    echo ""
    echo "To create a release keystore, run:"
    echo "keytool -genkey -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key"
fi

echo ""
echo "=========================================="
echo "Instructions:"
echo "1. Copy the SHA-1 value(s) above"
echo "2. Go to Google Cloud Console"
echo "3. Select your project (or create one)"
echo "4. Go to APIs & Services > Credentials"
echo "5. Create OAuth 2.0 Client ID for Android"
echo "6. Add the SHA-1 and package name: com.xeroflow.xeroflow"
echo "=========================================="


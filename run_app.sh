#!/bin/bash

# XeroFlow - Run App Script with Supabase Configuration
# This script ensures Supabase is configured and runs the Flutter app

set -e  # Exit on error

echo "=========================================="
echo "XeroFlow - Flutter App Runner"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter is not installed or not in PATH${NC}"
    echo "Please install Flutter from https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo -e "${GREEN}✓ Flutter found${NC}"

# Check if we're in the project directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: pubspec.yaml not found. Please run this script from the project root.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Project directory confirmed${NC}"

# Check Supabase configuration
echo ""
echo "Checking Supabase configuration..."

SUPABASE_SERVICE_FILE="lib/services/supabase_service.dart"
MAIN_FILE="lib/main.dart"

if [ ! -f "$SUPABASE_SERVICE_FILE" ]; then
    echo -e "${RED}Error: $SUPABASE_SERVICE_FILE not found${NC}"
    exit 1
fi

# Check if Supabase credentials are configured
if grep -q "YOUR_SUPABASE_URL" "$SUPABASE_SERVICE_FILE"; then
    echo -e "${YELLOW}⚠ Warning: Supabase URL not configured${NC}"
    echo "Please update lib/services/supabase_service.dart with your Supabase credentials"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Supabase URL configured${NC}"
fi

if grep -q "YOUR_SUPABASE_ANON_KEY" "$SUPABASE_SERVICE_FILE"; then
    echo -e "${YELLOW}⚠ Warning: Supabase Anon Key not configured${NC}"
    echo "Please update lib/services/supabase_service.dart with your Supabase credentials"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Supabase Anon Key configured${NC}"
fi

# Get dependencies
echo ""
echo "Getting Flutter dependencies..."
flutter pub get

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to get dependencies${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Dependencies installed${NC}"

# Check for connected devices
echo ""
echo "Checking for connected devices..."
DEVICES=$(flutter devices | grep -c "•" || true)

if [ "$DEVICES" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No devices found${NC}"
    echo "Please connect a device or start an emulator"
    echo ""
    echo "Available options:"
    echo "1. Connect a physical device via USB"
    echo "2. Start an Android emulator"
    echo "3. Start an iOS simulator"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Device(s) found${NC}"
    flutter devices
fi

# Run the app
echo ""
echo "=========================================="
echo "Starting XeroFlow app..."
echo "=========================================="
echo ""

# Check for command line arguments
if [ "$1" == "--release" ]; then
    echo "Running in RELEASE mode..."
    flutter run --release
elif [ "$1" == "--profile" ]; then
    echo "Running in PROFILE mode..."
    flutter run --profile
else
    echo "Running in DEBUG mode..."
    flutter run
fi


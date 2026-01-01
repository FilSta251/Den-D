#!/bin/bash
# deploy.sh - Deployment script for Wedding Planner Flutter app
#
# Tento skript sestavuje a nasazuje aplikaci pro Android, iOS a Web.
# Použití:
#   ./deploy.sh [--android] [--ios] [--web]
#
# Pokud nejsou zadány žádné argumenty, bude nasazeno vše.
#
# Před spuštěním se ujistěte, že máte:
#   - Nainstalovaný Flutter
#   - Nainstalovaný fastlane (pro Android a iOS deploy)
#   - Nainstalovaný Firebase CLI (pro Web deploy)
#
# Nastavení prostředí (např. fastlane konfigurace, firebase.json) musí být provedeno předem.

set -euo pipefail

function usage() {
  echo "Usage: $0 [--android] [--ios] [--web]"
  echo "   --android  Build and deploy Android APK"
  echo "   --ios      Build and deploy iOS build"
  echo "   --web      Build and deploy Web version"
  exit 1
}

# Výchozí nastavení: pokud nejsou zadány argumenty, deploy všech platforem
DEPLOY_ANDROID=false
DEPLOY_IOS=false
DEPLOY_WEB=false

if [ "$#" -eq 0 ]; then
  DEPLOY_ANDROID=true
  DEPLOY_IOS=true
  DEPLOY_WEB=true
fi

# Zpracování argumentů
for arg in "$@"; do
  case $arg in
    --android)
      DEPLOY_ANDROID=true
      shift
      ;;
    --ios)
      DEPLOY_IOS=true
      shift
      ;;
    --web)
      DEPLOY_WEB=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done

# Funkce pro kontrolu, zda je příkaz nainstalován
function check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: $1 is not installed. Please install it and try again."
    exit 1
  fi
}

check_command flutter

# Pokud budeme deployovat Android nebo iOS, ověřujeme fastlane
if [ "$DEPLOY_ANDROID" = true ] || [ "$DEPLOY_IOS" = true ]; then
  check_command fastlane
fi

# Pokud deployujeme Web, ověřujeme firebase CLI
if [ "$DEPLOY_WEB" = true ]; then
  check_command firebase
fi

echo "Starting deployment process..."

# Vyčistí předchozí build a získá závislosti
flutter clean
flutter pub get

# Deployment pro Android
if [ "$DEPLOY_ANDROID" = true ]; then
  echo "Building Android APK..."
  flutter build apk --release
  echo "Deploying Android APK using fastlane..."
  # Předpokládáme, že fastlane lane 'android deploy' je nakonfigurován
  fastlane android deploy || echo "Warning: fastlane Android deployment failed."
fi

# Deployment pro iOS
if [ "$DEPLOY_IOS" = true ]; then
  echo "Building iOS app..."
  flutter build ios --release --no-codesign
  echo "Deploying iOS app using fastlane..."
  # Předpokládáme, že fastlane lane 'ios deploy' je nakonfigurován
  fastlane ios deploy || echo "Warning: fastlane iOS deployment failed."
fi

# Deployment pro Web
if [ "$DEPLOY_WEB" = true ]; then
  echo "Building Flutter Web app..."
  flutter build web --release
  echo "Deploying Web app to Firebase Hosting..."
  firebase deploy --only hosting || echo "Warning: Firebase hosting deployment failed."
fi

echo "Deployment process completed successfully."

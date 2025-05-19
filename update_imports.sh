#!/bin/bash

echo "Aktualizuji importy v souborech Dart..."

# Nahrazení přímých cest konstantami z Routes
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/auth"|Navigator.pushNamed(context, Routes.auth|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/main"|Navigator.pushNamed(context, Routes.main|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/brideGroomMain"|Navigator.pushNamed(context, Routes.brideGroomMain|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/profile"|Navigator.pushNamed(context, Routes.profile|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/weddingInfo"|Navigator.pushNamed(context, Routes.weddingInfo|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/weddingSchedule"|Navigator.pushNamed(context, Routes.weddingSchedule|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/subscription"|Navigator.pushNamed(context, Routes.subscription|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/messages"|Navigator.pushNamed(context, Routes.messages|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/settings"|Navigator.pushNamed(context, Routes.settings|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/checklist"|Navigator.pushNamed(context, Routes.checklist|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/calendar"|Navigator.pushNamed(context, Routes.calendar|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/aiChat"|Navigator.pushNamed(context, Routes.aiChat|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/suppliers"|Navigator.pushNamed(context, Routes.suppliers|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/budget"|Navigator.pushNamed(context, Routes.budget|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/guests"|Navigator.pushNamed(context, Routes.guests|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/home"|Navigator.pushNamed(context, Routes.home|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/usageSelection"|Navigator.pushNamed(context, Routes.usageSelection|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/introduction"|Navigator.pushNamed(context, Routes.introduction|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/onboarding"|Navigator.pushNamed(context, Routes.onboarding|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/chatbot"|Navigator.pushNamed(context, Routes.chatbot|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/welcome"|Navigator.pushNamed(context, Routes.welcome|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/"|Navigator.pushNamed(context, Routes.splash|g' {} \;

# Přidání importu Routes tam, kde se používá
find lib -name "*.dart" -type f -exec grep -l "Routes\." {} \; | xargs -I{} sed -i '1,10 s|^import|import '\''../router/app_router.dart'\'';\nimport|' {} \;

echo "Importy aktualizovány!"

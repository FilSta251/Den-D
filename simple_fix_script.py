#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Jednoduchý skript pro opravu const Text().tr() chyb
"""

import re
import os

# Soubory, které potřebují opravu (podle vašich chyb)
files_to_fix = [
    "lib/main.dart",
    "lib/screens/home_screen.dart",
    "lib/screens/legal_information_page.dart",
    "lib/screens/suppliers_list_page.dart"
]

print("=" * 60)
print("🔧 OPRAVA CHYB")
print("=" * 60)
print()

total_changes = 0

for file_path in files_to_fix:
    if not os.path.exists(file_path):
        print(f"⚠️  {file_path} - soubor nenalezen")
        continue
    
    try:
        # Načteme soubor
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # OPRAVA: Odstraní "const " před "Text(" když následuje .tr()
        # Pattern hledá: const Text(...).tr()
        content = re.sub(r'\bconst\s+(Text\s*\([^)]*\.tr\s*\(\s*\)\s*\))', r'\1', content)
        
        # Spočítáme změny
        if content != original:
            changes = len(re.findall(r'\bconst\s+Text\s*\([^)]*\.tr\s*\(\s*\)\s*\)', original))
            total_changes += changes
            
            # Uložíme změny
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print(f"✅ {file_path} - opraveno {changes} chyb")
        else:
            print(f"✓  {file_path} - žádné chyby")
    
    except Exception as e:
        print(f"❌ {file_path} - chyba: {e}")

print()
print("=" * 60)
if total_changes > 0:
    print(f"✅ Hotovo! Opraveno {total_changes} chyb.")
    print()
    print("🚀 Teď spusťte:")
    print("   flutter run")
else:
    print("✅ Žádné chyby k opravě.")
print("=" * 60)

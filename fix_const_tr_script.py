#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Skript pro automatickou opravu chyb s const a .tr() ve Flutter projektu.
Tento skript odstraní 'const' před Text() widgety, které používají .tr()
"""

import os
import re
import sys
from pathlib import Path

def fix_const_tr_in_file(file_path):
    """
    Opraví const Text().tr() chyby v jednom souboru.
    Vrací počet provedených změn.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        changes = 0
        
        # Pattern 1: const Text('něco'.tr())
        # Nahradí na: Text('něco'.tr())
        pattern1 = r'const\s+Text\s*\(\s*["\']([^"\']*)\'\s*\.tr\s*\(\s*\)\s*\)'
        matches1 = re.findall(pattern1, content)
        content = re.sub(pattern1, r"Text('\1'.tr())", content)
        changes += len(matches1)
        
        # Pattern 2: const Text("něco".tr())
        pattern2 = r'const\s+Text\s*\(\s*"([^"]*)"\s*\.tr\s*\(\s*\)\s*\)'
        matches2 = re.findall(pattern2, content)
        content = re.sub(pattern2, r'Text("\1".tr())', content)
        changes += len(matches2)
        
        # Pokud byly provedeny změny, zapíšeme je
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return changes
        
        return 0
        
    except Exception as e:
        print(f"❌ Chyba při zpracování {file_path}: {e}")
        return 0

def add_missing_import(file_path):
    """
    Přidá import pro easy_localization, pokud chybí a soubor používá .tr()
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Kontrola, zda soubor používá .tr()
        if '.tr()' not in content:
            return False
        
        # Kontrola, zda už má import
        import_pattern = r"import\s+['\"]package:easy_localization/easy_localization.dart['\"]"
        if re.search(import_pattern, content):
            return False
        
        # Najdeme první import
        first_import = re.search(r'^import\s+', content, re.MULTILINE)
        if first_import:
            # Přidáme import před první existující import
            new_import = "import 'package:easy_localization/easy_localization.dart';\n"
            content = content[:first_import.start()] + new_import + content[first_import.start():]
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        
        return False
        
    except Exception as e:
        print(f"❌ Chyba při přidávání importu do {file_path}: {e}")
        return False

def process_directory(lib_path):
    """
    Zpracuje všechny .dart soubory v lib složce.
    """
    total_changes = 0
    total_files = 0
    files_with_changes = []
    imports_added = []
    
    print("🔍 Hledám soubory k opravě...\n")
    
    # Procházíme všechny .dart soubory
    for dart_file in Path(lib_path).rglob('*.dart'):
        file_path = str(dart_file)
        
        # Oprava const Text().tr()
        changes = fix_const_tr_in_file(file_path)
        if changes > 0:
            total_changes += changes
            total_files += 1
            files_with_changes.append((file_path, changes))
            print(f"✅ {file_path}: {changes} oprav")
        
        # Přidání chybějících importů
        if add_missing_import(file_path):
            imports_added.append(file_path)
            print(f"📦 {file_path}: Přidán import easy_localization")
    
    # Výsledky
    print("\n" + "="*60)
    print("📊 VÝSLEDKY OPRAV")
    print("="*60)
    print(f"✅ Celkem opraveno souborů: {total_files}")
    print(f"✅ Celkem provedeno změn: {total_changes}")
    print(f"📦 Přidáno importů: {len(imports_added)}")
    
    if files_with_changes:
        print("\n📝 Soubory s provedenými změnami:")
        for file_path, changes in files_with_changes:
            relative_path = os.path.relpath(file_path, lib_path)
            print(f"   • {relative_path} ({changes} změn)")
    
    if imports_added:
        print("\n📦 Soubory s přidaným importem:")
        for file_path in imports_added:
            relative_path = os.path.relpath(file_path, lib_path)
            print(f"   • {relative_path}")
    
    return total_changes

def main():
    print("="*60)
    print("🔧 OPRAVA const Text().tr() CHYB")
    print("="*60)
    print()
    
    # Najdeme lib složku
    current_dir = os.getcwd()
    lib_path = os.path.join(current_dir, 'lib')
    
    if not os.path.exists(lib_path):
        print("❌ Chyba: Složka 'lib' nebyla nalezena!")
        print(f"   Aktuální adresář: {current_dir}")
        print("   Ujistěte se, že spouštíte skript z kořenové složky Flutter projektu.")
        sys.exit(1)
    
    print(f"📂 Zpracovávám složku: {lib_path}\n")
    
    # Zpracování všech souborů
    total_changes = process_directory(lib_path)
    
    if total_changes > 0:
        print("\n✅ Opravy dokončeny!")
        print("\n🚀 Další kroky:")
        print("   1. Zkontrolujte změny: git diff")
        print("   2. Spusťte: flutter clean")
        print("   3. Spusťte: flutter pub get")
        print("   4. Spusťte: flutter run")
    else:
        print("\n✅ Žádné chyby nebyly nalezeny!")
    
    print("\n" + "="*60)

if __name__ == "__main__":
    main()

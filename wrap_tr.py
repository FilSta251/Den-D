import os
import re

# Seznam složek, které nechceme zpracovávat
EXCLUDE_DIRS = {'.dart_tool', 'build', '.git', 'temp_project', 'test'}

# Vzor pro návrat původních importů, které omylem získaly 'importtr'
IMPORT_REVERT_PATTERN = re.compile(r'importtr\(([\"\'])(.*?)\1\);')

# Vzor pro nalezení textu v uvozovkách, který ještě není obalený tr(...)
TEXT_PATTERN = re.compile(r'''
    (?<!tr\()\s*          # Před textem nesmí být už 'tr('
    (['\"])
    (.*?)                  # Zachytí jakýkoli text uvnitř (nejméně)
    \1                     # Stejná uvozovka na konci
''', re.VERBOSE)

def process_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    changed = False
    for line in lines:
        # 1) Oprav importy, které už mají 'importtr'
        line = IMPORT_REVERT_PATTERN.sub(r'import \1\2\1;', line)
        # 2) Pokud jde o řádek import, necháme beze změny
        if line.lstrip().startswith('import '):
            new_lines.append(line)
            continue
        # 3) Jinak obalíme běžné texty do tr(...)
        wrapped = TEXT_PATTERN.sub(lambda m: f'tr({m.group(1)}{m.group(2)}{m.group(1)})', line)
        new_lines.append(wrapped)
        if wrapped != line:
            changed = True

    if changed:
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print(f'Updated: {path}')
    else:
        print(f'No change: {path}')

# Projdeme složku projektu
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
    for fname in files:
        if fname.endswith('.dart'):
            process_file(os.path.join(root, fname))

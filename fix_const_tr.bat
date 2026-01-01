@echo off
chcp 65001 >nul
echo ========================================
echo 🔧 OPRAVA const Text().tr() CHYB
echo ========================================
echo.

REM Kontrola Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python není nainstalován!
    echo    Stáhněte Python z: https://www.python.org/downloads/
    echo    Při instalaci zaškrtněte "Add Python to PATH"
    pause
    exit /b 1
)

REM Kontrola lib složky
if not exist "lib" (
    echo ❌ Složka 'lib' nebyla nalezena!
    echo    Ujistěte se, že spouštíte tento skript z kořenové složky projektu.
    pause
    exit /b 1
)

echo ✅ Python nalezen
echo ✅ Složka lib nalezena
echo.
echo 🚀 Spouštím opravu...
echo.

REM Spuštění Python skriptu
python fix_const_tr.py

echo.
echo ========================================
echo ✅ HOTOVO!
echo ========================================
pause

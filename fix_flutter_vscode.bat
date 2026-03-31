@echo off
echo Fixing Flutter doctor VS Code detection on Windows...
echo.

REM Step 1: Find exact VS Code path (handles common install locations)
echo Step 1: Locating VS Code executable...
where code >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=*" %%i in ('where code') do set "VS_CODE_PATH=%%i"
    echo Found VS Code at: %VS_CODE_PATH%
) else (
    echo VS Code not in PATH, trying standard location...
    set "VS_CODE_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Microsoft VS Code\Code.exe"
    if exist "%VS_CODE_PATH%" (
        echo Found at standard path: %VS_CODE_PATH%
    ) else (
        echo ERROR: VS Code not found. Run manually: where code
        pause
        exit /b 1
    )
)

REM Step 2: Test VS Code works
echo Step 2: Verifying VS Code...
"%VS_CODE_PATH%" --version
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: VS Code --version failed.
    pause
    exit /b 1
)
echo VS Code verified OK.

REM Step 3: Configure Flutter to use VS Code explicitly via environment variable
echo Step 3: Setting FLUTTER_VSCODE_PATH...
setx FLUTTER_VSCODE_PATH "%VS_CODE_PATH%" /M
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: setx failed (may need admin). Set manually: set FLUTTER_VSCODE_PATH=%VS_CODE_PATH%
)

REM Alternative: Flutter config command (Flutter 3.24+ supports it, fallback)
echo Step 4: Using Flutter config (if supported)...
flutter config --vscode-path "%VS_CODE_PATH%"
if %ERRORLEVEL% NEQ 0 (
    echo Flutter config command not supported, using env var method.
)

REM Step 5: Refresh Flutter cache
echo Step 5: Refreshing Flutter precache...
flutter precache --android --ios --web
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Precaching had issues, but continuing...
)

REM Step 6: Restart shell/env and verify
echo.
echo Step 6: Verification...
echo Close and reopen this terminal/CMD, then run:
echo flutter doctor -v
echo Expected: VS Code should show [✓] (with Flutter/Dart extensions).
echo.

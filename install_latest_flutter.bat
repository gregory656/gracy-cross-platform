@echo off
echo Downloading Flutter 3.24.3 stable...
powershell -Command \"Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.3-stable.zip' -OutFile flutter.zip; Expand-Archive flutter.zip C:\flutter -Force; Remove-Item flutter.zip\"
echo Done! Add C:\flutter\bin to PATH, restart terminal.
pause

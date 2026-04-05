# Flutter 3.41.x Upgrade TODO

- [x] 1. pubspec.yaml updated (Dart ^3.24.0+)
- [x] 2. Platforms OK
- [ ] 3. Install fresh Flutter SDK (see steps below)
- [ ] 4. flutter pub upgrade ; flutter analyze
- [ ] 5. flutter run

**SDK Fix (Windows):**
1. Download Flutter stable ZIP: https://docs.flutter.dev/release/archive?tab=windows
2. Extract to short path e.g. C:\flutter
3. Edit system PATH + C:\flutter\bin
4. Restart terminal/VSCode
5. flutter --version (should show 3.24.x+)
6. flutter pub get here

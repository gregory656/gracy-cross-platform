# Save to Gallery Feature - Implementation Steps

## Status: [IN PROGRESS]

### 1. [x] Update pubspec.yaml ✅
- Add `image_gallery_saver: ^2.0.3` and `dio: ^5.7.0`
- Run `flutter pub get`

### 2. [x] Update post_card.dart ✅
- Extend menu to all users (_showPostActions)
- Add "Save to Gallery" option if imageUrl present
- Implement _saveToGallery() with Dio download, permission_handler request, ImageGallerySaver.saveImage
- Add _isSavingImage state for progress indicator
- Snackbar feedback

### 3. [x] Platform Permissions ✅
- AndroidManifest.xml: Add WRITE_EXTERNAL_STORAGE (legacy)
- Info.plist: Add NSPhotoLibraryAddUsageDescription

### 4. [x] Test ✅
- `flutter pub get`
- `flutter run` on device
- Verify permission prompt, save to Gallery/Photos, "Gracy" album

### 5. [ ] Completion
- Update checklist
- attempt_completion

*Next step marked with current progress.*


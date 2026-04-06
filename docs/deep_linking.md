# Gracy Deep Linking

Shared post links now use the format `https://gracy.app/post/<post_id>`.

## What is already wired in the app

- Flutter routes `/post/:id` into `PostDetailScreen`.
- Android listens for verified app links on `https://gracy.app/post/*`.
- Share payloads include:
  - the post caption
  - the deep link
  - the Play Store URL

## Final production steps

1. Replace `REPLACE_WITH_PLAY_STORE_SHA256_FINGERPRINT` in [assetlinks.json](/c:/Users/Administrator/Documents/gracy/web/.well-known/assetlinks.json) with your release SHA-256 fingerprint from Google Play Console.
2. Keep the hosted file available at `https://gracy.app/.well-known/assetlinks.json`.
3. Make sure your hosted `gracy.app` domain serves `https://gracy.app/post/<id>` and falls back to the Play Store when the app is not installed.
4. If you change the Android package name from `com.example.gracy`, update:
   - [app_links.dart](/c:/Users/Administrator/Documents/gracy/lib/core/constants/app_links.dart)
   - [assetlinks.json](/c:/Users/Administrator/Documents/gracy/web/.well-known/assetlinks.json)
   - [build.gradle.kts](/c:/Users/Administrator/Documents/gracy/android/app/build.gradle.kts)

## Test link example

`https://gracy.app/post/123e4567-e89b-12d3-a456-426614174000`

# gracy

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase Setup

This app reads Supabase credentials from a local file that is intentionally
ignored by Git:

- `lib/core/constants_local.dart`

If you are setting up the project on a new machine, create that file locally
and define:

- `SupabaseLocalConfig.supabaseUrl`
- `SupabaseLocalConfig.supabaseAnonKey`

Do not commit that file. It is listed in `.gitignore` so the values stay local.

# Flutter Analyze Fix Progress

**Current: 259 → ~200 issues (progress)**

## Completed
- Fixed notifications_overlay unnecessary_underscores
- Created AuthState, GeminiService, CustomTextField, GracyAILogo
- Updated MessageModel (senderUsername/isOfficial/replyToId/statusTicks)
- Created ChatRepository stub
- UserModel + UserRole.label/verificationLevel
- MessageModel full fields

## Pending (Top Priority)
1. UserModel props/copyWith for new fields
2. ChatThreadRequest add roomId/receiverName/avatar
3. OptimizedPostService add stubs (getPostById/createPost/toggleLike etc)
4. database_service.dart UserRole import
5. mock_users.dart UserRole.student fixes
6. Fix CustomTextField calls (add hintText)
7. chat_screen imports/authNotifierProvider
8. Supabase .eq in services
9. UserAvatar params/stub
10. offline_banner_provider StateNotifier<bool> fix

## Next Steps
- UserModel props
- ChatThreadRequest edit
- OptimizedPostService stubs
- `flutter analyze`


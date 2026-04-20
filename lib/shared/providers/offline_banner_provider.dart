import 'package:flutter_riverpod/flutter_riverpod.dart';

class OfflineBannerNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show([String message = 'You are offline.']) => state = message;
  void hide() => state = null;
  void resetOfflineCachedContentNotice() => state = null;
  void showOfflineCachedContentOnce() =>
      state = 'Showing cached content while offline.';
}

final offlineBannerProvider = NotifierProvider<OfflineBannerNotifier, String?>(
  OfflineBannerNotifier.new,
);

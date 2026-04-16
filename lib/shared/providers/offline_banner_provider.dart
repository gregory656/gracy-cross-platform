import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final offlineBannerProvider =
    NotifierProvider<OfflineBannerController, String?>(
      OfflineBannerController.new,
    );

class OfflineBannerController extends Notifier<String?> {
  Timer? _clearTimer;

  @override
  String? build() {
    ref.onDispose(() {
      _clearTimer?.cancel();
    });
    return null;
  }

  void show(String message, {Duration duration = const Duration(seconds: 3)}) {
    _clearTimer?.cancel();
    state = message;
    _clearTimer = Timer(duration, clear);
  }

  void showOfflineCachedContent() {
    show('Offline: Showing cached content.');
  }

  void clear() {
    _clearTimer?.cancel();
    state = null;
  }
}

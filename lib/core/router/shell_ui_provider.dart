import 'package:flutter_riverpod/flutter_riverpod.dart';

final shellNavigationVisibleProvider =
    NotifierProvider<ShellNavigationVisibleNotifier, bool>(
  ShellNavigationVisibleNotifier.new,
);

class ShellNavigationVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void show() => state = true;

  void hide() => state = false;
}

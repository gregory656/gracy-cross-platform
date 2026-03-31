import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ⚠️ DO NOT DELETE: Required for future backend integration
  runApp(const ProviderScope(child: GracyApp()));
}


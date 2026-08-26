import 'dart:async';
import 'package:flutter/foundation.dart';

class StartupGuard {
  static Future<T?> optional<T>(
    String name,
    Future<T> Function() action, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      return await action().timeout(timeout);
    } catch (e, st) {
      debugPrint('$name startup skipped: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }
}

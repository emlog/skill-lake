import 'package:flutter/material.dart';

class SnackbarUtil {
  static void show(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    Duration? duration,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // 清空之前的提示信息队列
    messenger.clearSnackBars();

    // 展示最新提示信息
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior
            .floating, // Usually a good defaults if not already in theme
        duration: duration ??
            const Duration(milliseconds: 4000), // Default SnackBar duration
      ),
    );
  }
}

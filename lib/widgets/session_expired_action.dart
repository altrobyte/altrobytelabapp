import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';

/// The way out of an expired session.
///
/// These screens sit behind a login, so a 401 here never means "you are not
/// signed in" — it means the session has gone. A Retry button in front of
/// that retries the same rejection forever, which is what every one of these
/// pages used to offer.
class SessionExpiredAction extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const SessionExpiredAction({super.key, required this.error, required this.onRetry});

  bool get _expired {
    final text = (error ?? '').toLowerCase();
    return text.contains('sign in') ||
        text.contains('401') ||
        text.contains('unauthor') ||
        text.contains('expired');
  }

  @override
  Widget build(BuildContext context) {
    if (!_expired) {
      return ElevatedButton(onPressed: onRetry, child: const Text('Retry'));
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
      onPressed: () => context.go('/login'),
      child: const Text('Sign in again',
          style: TextStyle(color: Colors.white)),
    );
  }
}

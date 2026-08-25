import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

/// Sends what broke in the browser to somewhere a person will look.
///
/// Until this existed, a widget that threw for one reader on one browser was
/// invisible — the only way anything got found was somebody hitting it and
/// telling us. That is not a monitoring strategy, it is luck.
///
/// Three rules, because a reporter that misbehaves is worse than none:
///
///   • It never throws. A failure to report an error must not become one.
///   • It never blocks. Reporting is fire-and-forget on a short timeout, so a
///     dead network cannot make a broken screen also a frozen one.
///   • It never floods. The same error is sent once per session; the server
///     collapses the rest by fingerprint anyway, but there is no reason to
///     make it.
class ErrorReporter {
  ErrorReporter._();

  static final Set<String> _seen = {};
  static const _maxPerSession = 25;

  static void send(String where, Object? error, StackTrace? stack,
      {String? context}) {
    // In debug the console is right there and more useful than a round trip.
    if (kDebugMode) return;
    try {
      final message = '$error';
      final key = '$where|${message.length > 120 ? message.substring(0, 120) : message}';
      if (_seen.contains(key) || _seen.length >= _maxPerSession) return;
      _seen.add(key);

      final detail = [
        if (context != null && context.isNotEmpty) context,
        if (stack != null) '$stack',
      ].join('\n\n');

      // Unawaited on purpose: whatever went wrong, the reader is already
      // looking at it, and waiting on a POST helps nobody.
      unawaited(http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/errors/client'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'where': where,
              'kind': error.runtimeType.toString(),
              'message': message,
              'detail': detail.length > 4000
                  ? detail.substring(0, 4000)
                  : detail,
            }),
          )
          .timeout(const Duration(seconds: 8))
          .catchError((_) => http.Response('', 599)));
    } catch (_) {
      // Reporting is best effort by definition.
    }
  }
}

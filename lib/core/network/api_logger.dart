import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logs every API call, and — the part that matters day to day — says whether
/// the answer came from [MockInterceptor] or from the real host.
///
/// Without this the two are indistinguishable at runtime: a request that falls
/// through the mock because no route matches goes to the network and fails
/// exactly like a real outage.
///
/// Must be the **first** interceptor so it sees requests before the mock can
/// short-circuit them. The mock resolves with `callFollowingResponseInterceptor`
/// so responses still reach [onResponse].
class ApiLogInterceptor extends Interceptor {
  ApiLogInterceptor({
    this.enabled = kDebugMode,
    this.maxBodyChars = 1000,
    this.tag = '[API]',
    this.logBodies = true,
  });

  /// Off for binary transfers — dumping a few MB of image bytes as a JSON int
  /// array buries every other line in the console.
  final bool logBodies;

  /// Off in release by default — these lines carry request and response bodies.
  final bool enabled;

  /// Bodies longer than this are cut, so one big menu payload cannot bury the
  /// rest of the log.
  final int maxBodyChars;

  /// Prefixed to every line so API traffic can be filtered out of a busy
  /// console.
  final String tag;

  static const String _startKey = 'log_started_at';

  /// Set by MockInterceptor on requests it answers itself.
  static const String mockedKey = 'served_by_mock';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      options.extra[_startKey] = DateTime.now();
      _write('→ ${options.method} ${options.uri}');
      final body = logBodies ? _format(options.data) : null;
      if (body != null) _write('  body $body');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enabled) {
      final options = response.requestOptions;
      _write(
        '← ${response.statusCode} ${options.method} ${options.uri}'
        ' ${_source(options)}${_elapsed(options)}',
      );
      final body = logBodies ? _format(response.data) : null;
      if (body != null) _write('  $body');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      final options = err.requestOptions;
      final status = err.response?.statusCode;
      _write(
        '✗ ${status ?? err.type.name} ${options.method} ${options.uri}'
        ' ${_source(options)}${_elapsed(options)}',
      );
      if (err.response != null) {
        final body = _format(err.response!.data);
        if (body != null) _write('  $body');
      } else {
        // No response at all: the host was never reached. Worth calling out,
        // because it reads identically to a rejection in the UI.
        _write('  ไม่ได้รับคำตอบจากเซิร์ฟเวอร์ (${err.type.name})'
            '${err.message == null ? '' : ' — ${err.message}'}');
      }
    }
    handler.next(err);
  }

  String _source(RequestOptions options) =>
      options.extra[mockedKey] == true ? '[MOCK]' : '[NETWORK]';

  String _elapsed(RequestOptions options) {
    final started = options.extra[_startKey];
    if (started is! DateTime) return '';
    return ' ${DateTime.now().difference(started).inMilliseconds}ms';
  }

  String? _format(dynamic body) {
    if (body == null) return null;
    String text;
    try {
      text = body is String ? body : jsonEncode(body);
    } catch (_) {
      text = body.toString();
    }
    if (text.isEmpty) return null;
    return text.length > maxBodyChars
        ? '${text.substring(0, maxBodyChars)}… (${text.length} chars)'
        : text;
  }

  /// Goes through [debugPrint] so the lines land in the `flutter run` console
  /// (and `flutter logs`), not just the DevTools logging view. debugPrint also
  /// throttles, which keeps Android from dropping lines when a burst of
  /// requests goes out at once.
  ///
  /// Every line carries the [tag] so the noise is filterable:
  /// `flutter run | grep '\[API\]'`
  void _write(String line) => debugPrint('$tag $line');
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum NavigationAction { allowInApp, upgradeToHttps, openExternally, block }

class WebViewService {
  const WebViewService();

  static final Uri homeUrl = Uri.parse('https://hpanel.hostinger.com/');

  static const List<String> trustedDomains = <String>['hostinger.com'];

  static const MethodChannel _channel = MethodChannel(
    'com.hostingerpanel.app/webview',
  );

  @visibleForTesting
  static bool isTrustedHost(String host) {
    final String h = host.toLowerCase().trim();
    if (h.isEmpty) return false;
    for (final String domain in trustedDomains) {
      if (h == domain || h.endsWith('.$domain')) return true;
    }
    return false;
  }

  NavigationAction classify(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return NavigationAction.block;

    switch (uri.scheme.toLowerCase()) {
      case 'https':
        return isTrustedHost(uri.host)
            ? NavigationAction.allowInApp
            : NavigationAction.openExternally;
      case 'http':
        return isTrustedHost(uri.host)
            ? NavigationAction.upgradeToHttps
            : NavigationAction.openExternally;
      case 'about':
        return url == 'about:blank'
            ? NavigationAction.allowInApp
            : NavigationAction.block;
      case 'javascript':
      case 'file':
      case 'content':
      case 'data':
      case 'blob':
        return NavigationAction.block;
      default:
        return NavigationAction.openExternally;
    }
  }

  Future<bool> openExternally(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      debugPrint('Could not launch $url: ${e.message}');
      return false;
    }
  }

  Future<List<String>> pickFiles({
    required List<String> acceptTypes,
    required bool allowMultiple,
  }) async {
    try {
      final List<Object?>? result = await _channel.invokeMethod<List<Object?>>(
        'pickFiles',
        <String, Object>{
          'acceptTypes': acceptTypes,
          'allowMultiple': allowMultiple,
        },
      );
      return result?.whereType<String>().toList() ?? <String>[];
    } on PlatformException catch (e) {
      debugPrint('File picker failed: ${e.message}');
      return <String>[];
    }
  }

  Future<void> attachDownloadHandler(int webViewIdentifier) async {
    try {
      await _channel.invokeMethod<void>('attachDownloadHandler', <String, int>{
        'webViewId': webViewIdentifier,
      });
    } on PlatformException catch (e) {
      debugPrint('Could not attach download handler: ${e.message}');
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:webview/services/webview_service.dart';

void main() {
  const WebViewService service = WebViewService();

  group('isTrustedHost', () {
    test('accepts Hostinger domains and subdomains', () {
      expect(WebViewService.isTrustedHost('hostinger.com'), isTrue);
      expect(WebViewService.isTrustedHost('hpanel.hostinger.com'), isTrue);
      expect(WebViewService.isTrustedHost('AUTH.Hostinger.com'), isTrue);
    });

    test('rejects look-alike and unrelated hosts', () {
      expect(WebViewService.isTrustedHost('evilhostinger.com'), isFalse);
      expect(WebViewService.isTrustedHost('hostinger.com.evil.io'), isFalse);
      expect(WebViewService.isTrustedHost('google.com'), isFalse);
      expect(WebViewService.isTrustedHost(''), isFalse);
    });
  });

  group('classify', () {
    test('keeps trusted HTTPS pages in the app', () {
      expect(
        service.classify('https://hpanel.hostinger.com/websites'),
        NavigationAction.allowInApp,
      );
    });

    test('upgrades trusted HTTP to HTTPS', () {
      expect(
        service.classify('http://hpanel.hostinger.com/'),
        NavigationAction.upgradeToHttps,
      );
    });

    test('sends external sites and app schemes outside', () {
      expect(
        service.classify('https://example.com/'),
        NavigationAction.openExternally,
      );
      expect(
        service.classify('mailto:support@example.com'),
        NavigationAction.openExternally,
      );
      expect(service.classify('tel:+123456'), NavigationAction.openExternally);
    });

    test('blocks dangerous schemes', () {
      expect(service.classify('javascript:alert(1)'), NavigationAction.block);
      expect(service.classify('file:///etc/hosts'), NavigationAction.block);
      expect(service.classify('not a url'), NavigationAction.block);
    });
  });
}

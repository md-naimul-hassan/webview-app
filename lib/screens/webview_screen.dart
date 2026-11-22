import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../services/webview_service.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  static const Duration _progressDelay = Duration(milliseconds: 250);

  final WebViewService _service = const WebViewService();
  late final WebViewController _controller;

  bool _firstPageLoaded = false;

  String? _errorMessage;

  String? _failedUrl;

  double _progress = 0;
  bool _showProgress = false;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _configureController();
  }

  Future<void> _configureController() async {
    final WebViewController c = _controller;

    await c.setJavaScriptMode(JavaScriptMode.unrestricted);
    await c.setBackgroundColor(Colors.white);
    await c.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: _onNavigationRequest,
        onPageStarted: _onPageStarted,
        onProgress: (int p) {
          if (mounted) setState(() => _progress = p / 100);
        },
        onPageFinished: _onPageFinished,
        onWebResourceError: _onWebResourceError,
      ),
    );

    await c.setOnJavaScriptAlertDialog(_onJsAlert);
    await c.setOnJavaScriptConfirmDialog(_onJsConfirm);
    await c.setOnJavaScriptTextInputDialog(_onJsPrompt);

    final Object platform = c.platform;
    if (platform is AndroidWebViewController) {
      await AndroidWebViewController.enableDebugging(kDebugMode);
      await platform.setMediaPlaybackRequiresUserGesture(true);
      await platform.setMixedContentMode(MixedContentMode.neverAllow);
      await platform.setAllowFileAccess(false);
      await platform.setGeolocationEnabled(false);
      await platform.setOnShowFileSelector(_onShowFileSelector);

      final Object cookies = WebViewCookieManager().platform;
      if (cookies is AndroidWebViewCookieManager) {
        await cookies.setAcceptThirdPartyCookies(platform, true);
      }

      await _service.attachDownloadHandler(platform.webViewIdentifier);
    }

    await c.loadRequest(WebViewService.homeUrl);
  }

  FutureOr<NavigationDecision> _onNavigationRequest(NavigationRequest req) {
    if (!req.isMainFrame) return NavigationDecision.navigate;

    switch (_service.classify(req.url)) {
      case NavigationAction.allowInApp:
        return NavigationDecision.navigate;
      case NavigationAction.upgradeToHttps:
        final Uri secure = Uri.parse(req.url).replace(scheme: 'https');
        _controller.loadRequest(secure);
        return NavigationDecision.prevent;
      case NavigationAction.openExternally:
        _openExternal(req.url);
        return NavigationDecision.prevent;
      case NavigationAction.block:
        return NavigationDecision.prevent;
    }
  }

  Future<void> _openExternal(String url) async {
    final bool opened = await _service.openExternally(url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app found to open this link.')),
      );
    }
  }

  void _onPageStarted(String url) {
    _progressTimer?.cancel();
    _progressTimer = Timer(_progressDelay, () {
      if (mounted) setState(() => _showProgress = true);
    });
    if (mounted) setState(() => _progress = 0);
  }

  void _onPageFinished(String url) {
    _progressTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showProgress = false;
      if (_errorMessage == null) _firstPageLoaded = true;
    });
  }

  void _onWebResourceError(WebResourceError error) {
    if (error.isForMainFrame == false) return;
    if (error.errorType == WebResourceErrorType.unknown &&
        error.description.contains('ERR_ABORTED')) {
      return;
    }
    _progressTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showProgress = false;
      _failedUrl = error.url;
      _errorMessage = _describe(error);
    });
  }

  String _describe(WebResourceError error) {
    switch (error.errorType) {
      case WebResourceErrorType.hostLookup:
      case WebResourceErrorType.connect:
      case WebResourceErrorType.timeout:
      case null:
        return 'Check your internet connection and try again.';
      case WebResourceErrorType.failedSslHandshake:
        return 'A secure connection could not be established.';
      default:
        return 'The page could not be loaded. Please try again.';
    }
  }

  Future<void> _retry() async {
    final String? failed = _failedUrl;
    setState(() {
      _errorMessage = null;
      _failedUrl = null;
    });
    final Uri? target = failed == null ? null : Uri.tryParse(failed);
    if (target != null &&
        _service.classify(failed!) == NavigationAction.allowInApp) {
      await _controller.loadRequest(target);
    } else if (await _controller.currentUrl() != null) {
      await _controller.reload();
    } else {
      await _controller.loadRequest(WebViewService.homeUrl);
    }
  }

  Future<void> _handleBack() async {
    if (_errorMessage != null && _firstPageLoaded) {
      setState(() => _errorMessage = null);
      if (await _controller.canGoBack()) {
        await _controller.goBack();
        return;
      }
    }
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  Future<List<String>> _onShowFileSelector(FileSelectorParams params) {
    return _service.pickFiles(
      acceptTypes: params.acceptTypes,
      allowMultiple: params.mode == FileSelectorMode.openMultiple,
    );
  }

  String _dialogTitle(String url) {
    final String host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? 'Message' : host;
  }

  Future<void> _onJsAlert(JavaScriptAlertDialogRequest request) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(_dialogTitle(request.url)),
        content: SingleChildScrollView(child: Text(request.message)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _onJsConfirm(JavaScriptConfirmDialogRequest request) async {
    if (!mounted) return false;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(_dialogTitle(request.url)),
        content: SingleChildScrollView(child: Text(request.message)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<String> _onJsPrompt(JavaScriptTextInputDialogRequest request) async {
    if (!mounted) return '';
    final TextEditingController input = TextEditingController(
      text: request.defaultText ?? '',
    );
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(_dialogTitle(request.url)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(request.message),
            TextField(controller: input, autofocus: true),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(input.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    input.dispose();
    return value ?? '';
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showError = _errorMessage != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.white,
      ),
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: WebViewWidget(controller: _controller)),
                if (_firstPageLoaded && _showProgress && !showError)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: PageProgressBar(progress: _progress),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _firstPageLoaded,
                    child: AnimatedOpacity(
                      opacity: _firstPageLoaded || showError ? 0 : 1,
                      duration: const Duration(milliseconds: 250),
                      child: const LoadingWidget(),
                    ),
                  ),
                ),
                if (showError)
                  Positioned.fill(
                    child: ConnectionErrorView(
                      message: _errorMessage,
                      onRetry: _retry,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

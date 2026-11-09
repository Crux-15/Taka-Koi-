import 'package:flutter/foundation.dart';
import 'web_env_stub.dart' if (dart.library.js_interop) 'web_env_web.dart' as impl;

/// Where the app is running, for the web version.

/// Opened from the home-screen icon (installed), not a normal browser tab.
bool get isInstalledWebApp => kIsWeb && impl.isStandalone();

/// The web version on an iPhone/iPad (Safari).
bool get isIosWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// The web version on an Android phone's browser.
bool get isAndroidWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.android;

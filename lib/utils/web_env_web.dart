import 'dart:js_interop';

/// Defined in web/index.html.
@JS('takaKoiStandalone')
external JSBoolean? _standalone();

/// True when opened from the home-screen icon.
bool isStandalone() {
  try {
    return _standalone()?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

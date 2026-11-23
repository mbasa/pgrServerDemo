import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformInfo {
  /// True only when the app was compiled to WebAssembly (dart2wasm).
  static const bool isRunningWithWasm =
      bool.fromEnvironment('dart.tool.dart2wasm');

  /// 'Wasm' or 'JS' when running in a browser; null on native platforms.
  static String? get webRuntimeLabel {
    if (!kIsWeb) return null;
    return isRunningWithWasm ? 'Wasm' : 'JS';
  }
}

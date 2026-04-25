import 'dart:js_interop';

@JS('_updateBadge')
external void _jsUpdateBadge(JSNumber count);

void updateAppBadge(int count) {
  try {
    _jsUpdateBadge(count.toJS);
  } catch (_) {}
}

import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class ExternalLinkOverlay extends StatelessWidget {
  final String url;
  final Widget child;
  final BorderRadius? borderRadius;

  const ExternalLinkOverlay({
    super.key,
    required this.url,
    required this.child,
    this.borderRadius,
  });

  static final Set<String> _registered = {};

  String _viewType() {
    final id = 'external-link-${url.hashCode}';
    if (!_registered.contains(id)) {
      _registered.add(id);
      ui_web.platformViewRegistry.registerViewFactory(id, (int viewId) {
        final anchor = web.HTMLAnchorElement()
          ..href = url
          ..target = '_blank'
          ..rel = 'noopener noreferrer'
          ..style.display = 'block'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.cursor = 'pointer';
        return anchor;
      });
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _viewType();
    return Stack(
      children: [
        IgnorePointer(child: child),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: HtmlElementView(viewType: viewType),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) => child;
}

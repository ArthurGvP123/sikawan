import 'package:flutter/material.dart';

class FadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final Offset beginOffset;
  final Widget child;

  const FadeSlide({
    super.key,
    required this.animation,
    this.beginOffset = const Offset(0, 0.08),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    final fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: child,
      ),
    );
  }
}

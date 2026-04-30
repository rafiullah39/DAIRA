import 'package:flutter/material.dart';
import '../theme.dart';

class DairaLoader extends StatefulWidget {
  final double size;
  const DairaLoader({super.key, this.size = 50});

  @override
  State<DairaLoader> createState() => _DairaLoaderState();
}

class _DairaLoaderState extends State<DairaLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Speed of rotation
    )..repeat(); // Makes it spin forever
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotationTransition(
        turns: _controller,
        child: Image.asset(
          'assets/logo.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, e, s) =>
              Icon(Icons.autorenew, color: DairaTheme.accentOrange, size: widget.size),
        ),
      ),
    );
  }
}
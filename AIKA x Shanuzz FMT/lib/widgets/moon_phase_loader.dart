import 'dart:async';
import 'package:flutter/material.dart';

/// Animated moon phase loader that cycles through all 8 phases.
/// Replaces CircularProgressIndicator for a more thematic loading experience.
class MoonPhaseLoader extends StatefulWidget {
  final double size;
  final Duration speed;

  const MoonPhaseLoader({
    super.key,
    this.size = 48,
    this.speed = const Duration(milliseconds: 400),
  });

  @override
  State<MoonPhaseLoader> createState() => _MoonPhaseLoaderState();
}

class _MoonPhaseLoaderState extends State<MoonPhaseLoader> {
  static const List<String> _phases = [
    '🌑', // New Moon
    '🌒', // Waxing Crescent
    '🌓', // First Quarter
    '🌔', // Waxing Gibbous
    '🌕', // Full Moon
    '🌖', // Waning Gibbous
    '🌗', // Last Quarter
    '🌘', // Waning Crescent
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.speed, (_) {
      if (mounted) {
        setState(() => _index = (_index + 1) % _phases.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _phases[_index],
      style: TextStyle(fontSize: widget.size * 0.7),
    );
  }
}

/// Small moon phase indicator for use inside buttons.
class MoonPhaseButton extends StatefulWidget {
  final double size;

  const MoonPhaseButton({super.key, this.size = 20});

  @override
  State<MoonPhaseButton> createState() => _MoonPhaseButtonState();
}

class _MoonPhaseButtonState extends State<MoonPhaseButton> {
  static const List<String> _phases = [
    '🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) {
        setState(() => _index = (_index + 1) % _phases.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Text(
          _phases[_index],
          style: TextStyle(fontSize: widget.size * 0.85),
        ),
      ),
    );
  }
}

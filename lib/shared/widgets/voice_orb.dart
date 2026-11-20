import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';

/// A clean-room animated voice orb: a glowing persona-coloured sphere with
/// slow breathing rings and a small orbiting dot. It mirrors the *role* of the
/// studied app's orb/character — a live focal point that reacts to the voice
/// state — without copying any of its artwork or animation code.
class VoiceOrb extends StatefulWidget {
  final Color color;
  final VoiceStatus status;
  final double size;
  final VoidCallback? onTap;
  final bool compact;

  /// Widget tests set this to false so `pumpAndSettle` can finish. The real app
  /// keeps the orb animated.
  static bool animate = true;

  const VoiceOrb({
    super.key,
    required this.color,
    this.status = VoiceStatus.idle,
    this.size = 190,
    this.onTap,
    this.compact = false,
  });

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void initState() {
    super.initState();
    if (!VoiceOrb.animate) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _statusColor() => switch (widget.status) {
        VoiceStatus.idle => widget.color,
        VoiceStatus.listening => Colors.green.shade400,
        VoiceStatus.thinking => Colors.orange.shade400,
        VoiceStatus.speaking => Colors.lightBlue.shade400,
      };

  double _statusScale() => switch (widget.status) {
        VoiceStatus.idle => 1.0,
        VoiceStatus.listening => 1.08,
        VoiceStatus.thinking => 1.03,
        VoiceStatus.speaking => 1.12,
      };

  @override
  Widget build(BuildContext context) {
    final tone = _statusColor();
    final scale = _statusScale();
    return Semantics(
      button: widget.onTap != null,
      label: 'ZaRa voice orb — ${widget.status.name}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final breath = 0.5 + 0.5 * math.sin(t * math.pi * 2);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Soft halo behind the sphere.
                  Container(
                    width: widget.size * (0.86 + breath * 0.08),
                    height: widget.size * (0.86 + breath * 0.08),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          tone.withOpacity(0.22),
                          tone.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  // Breathing rings.
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: widget.size * (0.70 + i * 0.11 + breath * 0.05),
                      height: widget.size * (0.70 + i * 0.11 + breath * 0.05),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tone.withOpacity(0.28 - i * 0.07),
                          width: 1.4,
                        ),
                      ),
                    ),
                  // Orbiting dot.
                  Transform.rotate(
                    angle: t * math.pi * 2,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 7,
                        height: 7,
                        margin: EdgeInsets.only(top: widget.size * 0.055),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.9),
                          boxShadow: [
                            BoxShadow(color: tone, blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // The sphere itself.
                  Container(
                    width: widget.size * 0.60 * scale,
                    height: widget.size * 0.60 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.35, -0.4),
                        colors: [
                          Colors.white.withOpacity(0.95),
                          tone.withOpacity(0.92),
                          tone.withOpacity(0.35),
                        ],
                        stops: const [0.05, 0.45, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tone.withOpacity(0.45),
                          blurRadius: 22 + breath * 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.compact
                          ? Icon(
                              Icons.auto_awesome,
                              color: Colors.white.withOpacity(0.9),
                              size: widget.size * 0.18,
                            )
                          : Text(
                              'Z',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: widget.size * 0.24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

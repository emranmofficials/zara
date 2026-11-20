import 'package:flutter/material.dart';

/// Four personas. Names and colours are original to ZaRa.
enum Persona { zara, nova, orbit, echo }

extension PersonaX on Persona {
  String get label => switch (this) {
        Persona.zara => 'ZaRa',
        Persona.nova => 'Nova',
        Persona.orbit => 'Orbit',
        Persona.echo => 'Echo',
      };

  String get tagline => switch (this) {
        Persona.zara => 'calm & clear',
        Persona.nova => 'bright & quick',
        Persona.orbit => 'deep & steady',
        Persona.echo => 'soft & quiet',
      };

  Color get seed => switch (this) {
        Persona.zara => const Color(0xFF7C5CFF),
        Persona.nova => const Color(0xFFFF8A3D),
        Persona.orbit => const Color(0xFF1E6FD9),
        Persona.echo => const Color(0xFF00A38C),
      };

  bool get dark => switch (this) {
        Persona.orbit || Persona.echo => true,
        Persona.zara || Persona.nova => false,
      };
}

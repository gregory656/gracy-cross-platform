import 'package:flutter/material.dart';

class AvatarPalette {
  const AvatarPalette(this.start, this.end, this.accent);

  final Color start;
  final Color end;
  final Color accent;
}

class SeededAvatarPalette {
  const SeededAvatarPalette._();

  static const List<AvatarPalette> palettes = <AvatarPalette>[
    AvatarPalette(Color(0xFF7AA2F7), Color(0xFF5DE4C7), Color(0xFFB8FFF1)),
    AvatarPalette(Color(0xFF8B9CFF), Color(0xFF6AE1FF), Color(0xFFD9F2FF)),
    AvatarPalette(Color(0xFFFFB86C), Color(0xFFF9C74F), Color(0xFFFFE3A3)),
    AvatarPalette(Color(0xFFB97DFF), Color(0xFF7AD7FF), Color(0xFFE4D3FF)),
    AvatarPalette(Color(0xFF4DD4AC), Color(0xFF2F80ED), Color(0xFFC9FFF0)),
    AvatarPalette(Color(0xFFFF7A90), Color(0xFFFFB3C1), Color(0xFFFFE1E7)),
  ];

  static AvatarPalette paletteFor(String seed) {
    final int index = seed.hashCode.abs() % palettes.length;
    return palettes[index];
  }
}

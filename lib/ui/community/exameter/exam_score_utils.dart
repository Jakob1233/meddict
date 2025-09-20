import 'package:flutter/material.dart';

/// Returns a color that transitions from light green (score 1)
/// to red (score 100).
Color colorForScore(int score) {
  final clamped = score.clamp(1, 100);
  final t = (clamped - 1) / 99.0;

  const start = Color(0xFFB9F6CA); // light green A100-ish
  const end = Color(0xFFFF5252); // red A200-ish

  return Color.lerp(start, end, t)!;
}

/// Returns an emoji that represents how tough the score feels.
String emojiForScore(int score) {
  final s = score.clamp(1, 100);
  if (s <= 10) return '🤡';
  if (s <= 20) return '😎';
  if (s <= 30) return '🙂';
  if (s <= 40) return '😐';
  if (s <= 50) return '🫠';
  if (s <= 60) return '🥲';
  if (s <= 70) return '😥';
  if (s <= 80) return '😖';
  if (s <= 90) return '😵';
  return '💀';
}

/// Picks a readable foreground color (black/white) for the given background.
Color readableOn(Color bg) {
  final yiq = ((bg.red * 299) + (bg.green * 587) + (bg.blue * 114)) / 1000;
  return yiq >= 135 ? Colors.black : Colors.white;
}
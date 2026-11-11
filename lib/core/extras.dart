/// Small pure helpers for individual features. Each names its feature number.
library;

import 'dart:math';

import 'engine.dart';
import 'events.dart';

// ---- 18. Voice start ------------------------------------------------------
class VoiceCommand {
  const VoiceCommand(this.minutes, this.projectId);
  final int minutes;
  final String? projectId;
}

const _numberWords = {
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'ten': 10, 'fifteen': 15, 'twenty': 20,
  'twenty five': 25, 'twenty-five': 25, 'thirty': 30, 'forty five': 45, 'fifty': 50, 'ninety': 90,
};

/// Understands "start five minutes on DSA", "start 25", "begin". Returns null
/// when the phrase is not a start request.
VoiceCommand? parseVoice(String heard, List<Rec> projects) {
  final s = heard.toLowerCase().trim();
  if (!RegExp(r'\b(start|begin|go)\b').hasMatch(s)) return null;
  var minutes = 2;
  final digits = RegExp(r'(\d{1,3})').firstMatch(s);
  if (digits != null) {
    minutes = int.parse(digits.group(1)!);
  } else {
    for (final e in (_numberWords.entries.toList()..sort((a, b) => b.key.length.compareTo(a.key.length)))) {
      if (RegExp('\\b${e.key}\\b').hasMatch(s)) {
        minutes = e.value;
        break;
      }
    }
  }
  if (RegExp(r'\bhours?\b').hasMatch(s)) minutes *= 60;
  String? pid;
  final on = RegExp(r'\b(?:on|for)\s+(.+)$').firstMatch(s.replaceAll(RegExp(r'\b(minutes?|mins?|hours?)\b'), ''));
  final wanted = on?.group(1)?.trim() ?? '';
  for (final p in projects) {
    final name = p.str('name').toLowerCase();
    if (name.isNotEmpty && (s.contains(name) || (wanted.isNotEmpty && name.contains(wanted)))) {
      pid = p.id;
      break;
    }
  }
  return VoiceCommand(minutes.clamp(1, 180), pid);
}

// ---- 14. Dice start -------------------------------------------------------
/// Up to three candidates: today's planned first task, then open tasks.
List<String> diceOptions(DayView v) {
  final out = <String>[];
  final p = v.todayPlan;
  if (p != null && p.task.isNotEmpty) out.add(p.task);
  for (final t in v.of(Kind.task)) {
    if (out.length >= 3) break;
    if (!t.flag('done') && !out.contains(t.str('title'))) out.add(t.str('title'));
  }
  if (out.isEmpty) out.add(v.nextStep);
  return out;
}

String rollDice(List<String> options, Random rng) => options[rng.nextInt(options.length)];

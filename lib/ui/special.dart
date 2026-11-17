import 'package:flutter/material.dart';
import '../core/engine.dart';
import 'start_tools.dart';
import 'streak_tools.dart';
import 'vault_tools.dart';
import 'project_tools.dart';
import 'focus_tools.dart';
import 'game_tools.dart';
import 'feeling_tools.dart';
import 'study_tools.dart';
import 'coach_tools.dart';
import 'pressure_tool.dart';

export 'start_tools.dart';
export 'habit_screen.dart';
export 'streak_tools.dart';
export 'task_screen.dart';
export 'vault_tools.dart';
export 'project_tools.dart';
export 'focus_tools.dart';
export 'game_tools.dart';
export 'feeling_tools.dart';
export 'study_tools.dart';
export 'coach_tools.dart';
export 'pressure_tool.dart';

/// Screens for tools of kind "special", by feature number.
Widget specialTool(int n, DayView v) => switch (n) {
      14 => const DiceTool(),
      32 => ChainCalendar(v),
      47 => const WagerTool(),
      48 => const RestDays(),
      58 => const RepairTool(),
      59 || 60 => ModeTool(n),
      70 => const GiftTool(),
      74 => const ArchiveTool(),
      603 || 608 || 624 || 628 || 629 || 630 || 632 || 637 || 641 || 688 || 689 || 701 => PressureTool(n),
      607 => ChainCalendar(v),
      647 || 668 => const ShareCardTool(),
      520 || 529 || 531 || 538 || 543 => CoachTool(n),
      551 || 552 => RoutineTool(n),
      404 || 405 || 410 || 414 || 450 => StudyTool(n),
      277 => const FeelingTool(277, ['bored', 'anxious', 'overwhelmed', 'confused']),
      281 => const FeelingTool(281, ['boring', 'hard', 'unclear', 'pointless']),
      315 => const NapTool(),
      239 || 240 || 242 || 243 => GameTool(n),
      202 => const AllowTool(),
      207 || 214 || 215 => UsageTool(n),
      208 => const BreathTool(90),
      223 => const BreathTool(60),
      283 => const BreathTool(60, box: true),
      560 => const BreathTool(180),
      153 || 154 || 159 || 168 || 179 || 185 => ProjectTool(n),
      390 => const VaultTool(143),
      131 || 134 || 135 || 136 || 138 || 139 || 142 || 143 || 144 || 146 || 147 || 148 || 149 => VaultTool(n),
      _ => const Text('Not available.'),
    };

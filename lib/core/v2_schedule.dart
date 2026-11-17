/// Weekly work blocks (reference spec 5.10). Pure Dart.
///
/// A block is a record of kind [blockKind] with data
/// {wd: 1..7 (Monday first), minute: start minute of the day, len: minutes,
/// projectId: '' or a project id, remind: bool}.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'reminders.dart';

const String blockKind = 'block';
const List<String> weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const List<int> blockLengths = [15, 25, 30, 50, 60, 90, 120];

/// Blocks on [weekday] (1 = Monday .. 7 = Sunday), earliest first.
List<Rec> blocksOn(DayView v, int weekday) => v.of(blockKind).where((b) => b.integer('wd') == weekday).toList()
  ..sort((a, b) => a.integer('minute').compareTo(b.integer('minute')));

List<Rec> todaysBlocks(DayView v) => blocksOn(v, weekdayOf(v.today));

/// "09:00 to 09:25".
String blockSpan(Rec b) => '${hhmm(b.integer('minute'))} to ${hhmm(b.integer('minute') + b.integer('len'))}';

/// Name of the block's project, or '' when it has none (or it was deleted).
String blockProject(DayView v, Rec b) => v.rec(b.str('projectId'))?.str('name') ?? '';

/// Seven characters of 0/1, Monday first, with only [weekday] set.
String dayMask(int weekday) => [for (var d = 1; d <= 7; d++) d == weekday ? '1' : '0'].join();

/// One reminder at the start of every block that asked for one.
List<Reminder> scheduleReminders(DayView v) {
  final out = <Reminder>[];
  for (final (i, b) in v.of(blockKind).indexed) {
    final wd = b.integer('wd');
    if (!b.flag('remind') || wd < 1 || wd > 7) continue;
    final name = blockProject(v, b);
    out.add(Reminder(
        9000 + i,
        b.integer('minute') % 1440,
        'Scheduled block',
        name.isEmpty
            ? 'You booked ${b.integer('len')} minutes for now. Next step: ${v.nextStep}'
            : 'You booked ${b.integer('len')} minutes of "$name" for now. Two minutes opens it.',
        start: true,
        days: dayMask(wd)));
  }
  return out;
}

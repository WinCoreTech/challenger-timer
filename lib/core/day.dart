/// Day arithmetic for the whole app. Pure Dart.
///
/// A "logical day" is an integer: the number of whole days since 1970-01-01 of
/// local wall-clock time, shifted back by the day-end hour (default 3 am), so
/// 02:59 still belongs to the previous day. Every event stores the UTC offset
/// that was in force when it happened, so daylight-saving shifts and travel
/// across time zones never move an old event into a different day.
library;

const int msPerMinute = 60000;
const int msPerHour = 3600000;
const int msPerDay = 86400000;

/// An instant plus the local UTC offset at that instant.
class Moment {
  const Moment(this.ms, this.offsetMin);
  factory Moment.fromDateTime(DateTime d) =>
      Moment(d.millisecondsSinceEpoch, d.timeZoneOffset.inMinutes);
  final int ms;
  final int offsetMin;

  /// Local wall-clock milliseconds since the epoch.
  int get wallMs => ms + offsetMin * msPerMinute;
  int day(int dayEndHour) => dayOf(ms, offsetMin, dayEndHour);

  /// Minutes since local midnight, 0..1439.
  int get minuteOfDay => (wallMs ~/ msPerMinute) % 1440;
  int get hour => minuteOfDay ~/ 60;
}

typedef Clock = Moment Function();
Moment systemClock() => Moment.fromDateTime(DateTime.now());

int dayOf(int tsMs, int offsetMin, int dayEndHour) =>
    ((tsMs + offsetMin * msPerMinute - dayEndHour * msPerHour) / msPerDay).floor();

/// Civil date (UTC-based DateTime used only as a calendar) of a logical day.
DateTime dateOfDay(int day) => DateTime.utc(1970, 1, 1 + day);
int dayOfDate(int y, int m, int d) =>
    DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ msPerDay;

/// Year*12+month, used for "per calendar month" allowances.
int monthKey(int day) {
  final d = dateOfDay(day);
  return d.year * 12 + d.month - 1;
}

/// 1 = Monday .. 7 = Sunday.
int weekdayOf(int day) => dateOfDay(day).weekday;

/// Wall-clock ms at which logical [day] ends (the next day-end hour).
int dayEndWallMs(int day, int dayEndHour) => (day + 1) * msPerDay + dayEndHour * msPerHour;

/// Fraction of the logical day still left, 1.0 at day start, 0.0 at day end.
double dayFractionLeft(Moment now, int dayEndHour) {
  final end = dayEndWallMs(now.day(dayEndHour), dayEndHour);
  return ((end - now.wallMs) / msPerDay).clamp(0.0, 1.0);
}

String two(int n) => n.toString().padLeft(2, '0');
String hhmm(int minuteOfDay) => '${two(minuteOfDay ~/ 60 % 24)}:${two(minuteOfDay % 60)}';
String dayLabel(int day) {
  final d = dateOfDay(day);
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

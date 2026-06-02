import 'package:intl/intl.dart' as intl;

/// A calendar-aligned tick/grouping interval (e.g. "every 6 hours", "every
/// day at midnight", "every month on the 1st"). Replaces raw millisecond
/// stepping so bars and axis labels land on human-friendly boundaries
/// (00:00 / Monday / 1st) instead of arbitrary instants like 14:00/18:00.
///
/// Design follows the production pattern (D3 scaleTime ticks, Grafana
/// auto-interval): pick the interval from a calendar-aligned candidate
/// ladder by target density (≈ 1 per N pixels), then align()/next() walk
/// calendar boundaries and label() formats by granularity.
enum CalendarUnit { minute, hour, day, week, month, year }

class CalendarInterval {
  const CalendarInterval(this.unit, this.count);

  final CalendarUnit unit;
  final int count;

  /// Approximate milliseconds — used only for density/picking and bar width.
  /// Calendar walking uses align()/next(), which are exact.
  int get approxMs {
    switch (unit) {
      case CalendarUnit.minute:
        return count * 60 * 1000;
      case CalendarUnit.hour:
        return count * 3600 * 1000;
      case CalendarUnit.day:
        return count * 86400 * 1000;
      case CalendarUnit.week:
        return count * 7 * 86400 * 1000;
      case CalendarUnit.month:
        return count * 30 * 86400 * 1000;
      case CalendarUnit.year:
        return count * 365 * 86400 * 1000;
    }
  }

  Duration get approxDuration => Duration(milliseconds: approxMs);

  /// Floor [d] to the start of its calendar bucket.
  DateTime align(DateTime d) {
    switch (unit) {
      case CalendarUnit.minute:
        return DateTime(d.year, d.month, d.day, d.hour,
            (d.minute ~/ count) * count);
      case CalendarUnit.hour:
        return DateTime(d.year, d.month, d.day, (d.hour ~/ count) * count);
      case CalendarUnit.day:
        return DateTime(d.year, d.month, d.day);
      case CalendarUnit.week:
        // Monday-aligned, midnight.
        final monday = d.subtract(Duration(days: d.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case CalendarUnit.month:
        return DateTime(d.year, ((d.month - 1) ~/ count) * count + 1, 1);
      case CalendarUnit.year:
        return DateTime(d.year, 1, 1);
    }
  }

  /// Advance [d] by one interval (calendar-aware for month/year so DST and
  /// variable month lengths stay correct).
  DateTime next(DateTime d) {
    switch (unit) {
      case CalendarUnit.minute:
        return d.add(Duration(minutes: count));
      case CalendarUnit.hour:
        return d.add(Duration(hours: count));
      case CalendarUnit.day:
        return DateTime(d.year, d.month, d.day + count);
      case CalendarUnit.week:
        return DateTime(d.year, d.month, d.day + 7 * count);
      case CalendarUnit.month:
        return DateTime(d.year, d.month + count, 1);
      case CalendarUnit.year:
        return DateTime(d.year + count, 1, 1);
    }
  }

  /// Multi-scale label, granularity chosen by unit (D3 d3-time-format style).
  String label(DateTime d) {
    switch (unit) {
      case CalendarUnit.minute:
      case CalendarUnit.hour:
        return intl.DateFormat('HH:mm').format(d);
      case CalendarUnit.day:
      case CalendarUnit.week:
        return intl.DateFormat('d MMM').format(d);
      case CalendarUnit.month:
        return intl.DateFormat('MMM yyyy').format(d);
      case CalendarUnit.year:
        return intl.DateFormat('y').format(d);
    }
  }
}

/// Ascending ladder of calendar-aligned candidate intervals.
const List<CalendarInterval> kCalendarLadder = [
  CalendarInterval(CalendarUnit.minute, 1),
  CalendarInterval(CalendarUnit.minute, 5),
  CalendarInterval(CalendarUnit.minute, 15),
  CalendarInterval(CalendarUnit.minute, 30),
  CalendarInterval(CalendarUnit.hour, 1),
  CalendarInterval(CalendarUnit.hour, 3),
  CalendarInterval(CalendarUnit.hour, 6),
  CalendarInterval(CalendarUnit.hour, 12),
  CalendarInterval(CalendarUnit.day, 1),
  CalendarInterval(CalendarUnit.week, 1),
  CalendarInterval(CalendarUnit.month, 1),
  CalendarInterval(CalendarUnit.month, 3), // quarter
  CalendarInterval(CalendarUnit.year, 1),
];

/// Pick the finest calendar interval (>= [min], if given) that yields no more
/// than [targetCount] buckets across [rangeMs]. This is the "density" rule:
/// target ≈ 1 tick per ~N pixels → targetCount = width / N.
CalendarInterval pickCalendarInterval({
  required int rangeMs,
  required double targetCount,
  CalendarInterval? min,
}) {
  final t = targetCount < 1 ? 1.0 : targetCount;
  for (final c in kCalendarLadder) {
    if (min != null && c.approxMs < min.approxMs) continue;
    if (rangeMs / c.approxMs <= t) return c;
  }
  return kCalendarLadder.last;
}

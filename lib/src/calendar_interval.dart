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
enum CalendarUnit { second, minute, hour, day, week, month, year }

class CalendarInterval {
  const CalendarInterval(this.unit, this.count);

  final CalendarUnit unit;
  final int count;

  /// Approximate milliseconds — used only for density/picking and bar width.
  /// Calendar walking uses align()/next(), which are exact.
  int get approxMs {
    switch (unit) {
      case CalendarUnit.second:
        return count * 1000;
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
      case CalendarUnit.second:
        return DateTime(d.year, d.month, d.day, d.hour, d.minute,
            (d.second ~/ count) * count);
      case CalendarUnit.minute:
        return DateTime(d.year, d.month, d.day, d.hour,
            (d.minute ~/ count) * count);
      case CalendarUnit.hour:
        return DateTime(d.year, d.month, d.day, (d.hour ~/ count) * count);
      case CalendarUnit.day:
        if (count <= 1) return DateTime(d.year, d.month, d.day);
        // Multi-day: anchor to the month start (D3-style), so 2d/4d ticks
        // restart on the 1st each month. Drift on the last interval of a
        // month is accepted.
        final base = DateTime(d.year, d.month, 1);
        final daysSince = d.difference(base).inDays;
        return base.add(Duration(days: (daysSince ~/ count) * count));
      case CalendarUnit.week:
        // Monday-aligned, midnight.
        final monday = d.subtract(Duration(days: d.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case CalendarUnit.month:
        return DateTime(d.year, ((d.month - 1) ~/ count) * count + 1, 1);
      case CalendarUnit.year:
        // count-aware so decade/5-year rungs anchor to 1980, 1990, … etc.
        return DateTime((d.year ~/ count) * count, 1, 1);
    }
  }

  /// Advance [d] by one interval (calendar-aware for month/year so DST and
  /// variable month lengths stay correct).
  DateTime next(DateTime d) {
    switch (unit) {
      case CalendarUnit.second:
        return d.add(Duration(seconds: count));
      case CalendarUnit.minute:
        return d.add(Duration(minutes: count));
      case CalendarUnit.hour:
        return d.add(Duration(hours: count));
      case CalendarUnit.day:
        if (count <= 1) return DateTime(d.year, d.month, d.day + count);
        final n = DateTime(d.year, d.month, d.day + count);
        // Re-anchor at month boundaries so multi-day ticks restart on the 1st.
        if (n.month != d.month) return DateTime(n.year, n.month, 1);
        return n;
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
      case CalendarUnit.second:
        return intl.DateFormat('HH:mm:ss').format(d);
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

  /// Short label for the FINE tick row of the two-row axis — just the unit's
  /// own value, since the coarser context (month/year/date) is in the row
  /// below. hour→'HH:mm', day/week→day number, month→'MMM', year→'y'.
  String tickLabel(DateTime d) {
    switch (unit) {
      case CalendarUnit.second:
        return intl.DateFormat('HH:mm:ss').format(d);
      case CalendarUnit.minute:
      case CalendarUnit.hour:
        return intl.DateFormat('HH:mm').format(d);
      case CalendarUnit.day:
      case CalendarUnit.week:
        return intl.DateFormat('d').format(d);
      case CalendarUnit.month:
        return intl.DateFormat('MMM').format(d);
      case CalendarUnit.year:
        return intl.DateFormat('y').format(d);
    }
  }

  /// Label for the CONTEXT row when THIS interval is the coarse unit — the
  /// span's name, left-aligned at its boundary. hour→'HH:mm', day→'EEE d MMM',
  /// week→'d MMM', month→'MMMM yyyy', year→'y'.
  String spanLabel(DateTime d) {
    switch (unit) {
      case CalendarUnit.second:
        return intl.DateFormat('HH:mm:ss').format(d);
      case CalendarUnit.minute:
      case CalendarUnit.hour:
        return intl.DateFormat('HH:mm').format(d);
      case CalendarUnit.day:
        return intl.DateFormat('EEE d MMM').format(d);
      case CalendarUnit.week:
        return intl.DateFormat('d MMM').format(d);
      case CalendarUnit.month:
        return intl.DateFormat('MMMM yyyy').format(d);
      case CalendarUnit.year:
        return intl.DateFormat('y').format(d);
    }
  }
}

/// Ascending ladder of calendar-aligned candidate intervals.
const List<CalendarInterval> kCalendarLadder = [
  CalendarInterval(CalendarUnit.second, 1),
  CalendarInterval(CalendarUnit.second, 5),
  CalendarInterval(CalendarUnit.second, 15),
  CalendarInterval(CalendarUnit.second, 30),
  CalendarInterval(CalendarUnit.minute, 1),
  CalendarInterval(CalendarUnit.minute, 5),
  CalendarInterval(CalendarUnit.minute, 15),
  CalendarInterval(CalendarUnit.minute, 30),
  CalendarInterval(CalendarUnit.hour, 1),
  CalendarInterval(CalendarUnit.hour, 3),
  CalendarInterval(CalendarUnit.hour, 6),
  CalendarInterval(CalendarUnit.hour, 12),
  CalendarInterval(CalendarUnit.day, 1),
  CalendarInterval(CalendarUnit.day, 2),
  CalendarInterval(CalendarUnit.day, 4),
  CalendarInterval(CalendarUnit.week, 1),
  CalendarInterval(CalendarUnit.month, 1),
  CalendarInterval(CalendarUnit.month, 2),
  CalendarInterval(CalendarUnit.month, 3), // quarter
  CalendarInterval(CalendarUnit.month, 6),
  CalendarInterval(CalendarUnit.year, 1),
  CalendarInterval(CalendarUnit.year, 2),
  CalendarInterval(CalendarUnit.year, 5),
  CalendarInterval(CalendarUnit.year, 10), // decade
];

/// The coarser "major" interval to pair with a given minor [unit] for a
/// two-tier axis (small ticks at the fine unit + a heavier separator/bold
/// label at the coarse one): hour→day, day/week→month, month→year. Returns
/// null when the unit is already the coarsest (year).
CalendarInterval? majorIntervalFor(CalendarUnit unit) {
  switch (unit) {
    case CalendarUnit.second:
    case CalendarUnit.minute:
    case CalendarUnit.hour:
      return const CalendarInterval(CalendarUnit.day, 1);
    case CalendarUnit.day:
    case CalendarUnit.week:
      return const CalendarInterval(CalendarUnit.month, 1);
    case CalendarUnit.month:
      return const CalendarInterval(CalendarUnit.year, 1);
    case CalendarUnit.year:
      return null;
  }
}

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

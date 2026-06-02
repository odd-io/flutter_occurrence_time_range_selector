import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'grouped_event.dart';
import 'label_info.dart';
import 'tag_style.dart';
import 'timeline_style.dart';

class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.startDate,
    required this.endDate,
    required this.groupedEvents,
    required this.tagStyles,
    required this.zoomFactor,
    required this.style,
    required this.visibleLabels,
    this.majorLabels = const [],
    required this.getLabelInterval,
  });

  final DateTime endDate;
  final Duration Function() getLabelInterval;
  final Map<DateTime, List<GroupedEvent>> groupedEvents;
  final DateTime startDate;
  final TimelineStyle style;
  final Map<String, TagStyle> tagStyles;
  final List<LabelInfo> visibleLabels;
  // Coarser boundaries (month/year/day) rendered as heavier separators +
  // bold labels for the two-tier axis.
  final List<LabelInfo> majorLabels;
  final double zoomFactor;

  @override
  void paint(Canvas canvas, Size size) {
    const highlightSpace = 20.0; // reserved for highlights at the top
    final totalDuration = endDate.difference(startDate);
    if (totalDuration.inMilliseconds <= 0) return;
    final pixelsPerUnit = size.width / totalDuration.inMilliseconds;

    // Two-row axis: a fine tick row (day numbers / hours) above a context row
    // (month / day-date / year). Both rows sized off the label font.
    final fineFont = style.axisLabelStyle.fontSize ?? 11.0;
    final rowH = fineFont + 6;
    final labelHeight = rowH * 2;
    final axisY = size.height - labelHeight;

    // Faint gridlines behind the bars (fine ticks + context boundaries).
    _drawGridlines(canvas, axisY, pixelsPerUnit);

    // Stacked bars.
    _drawStackedEventBars(
        canvas, size, pixelsPerUnit, labelHeight, highlightSpace);

    // Main horizontal axis line.
    final axisPaint = Paint()
      ..color = style.axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, axisY), Offset(size.width, axisY), axisPaint);

    // Fine tick row (top) + context row (bottom).
    _drawFineTicks(canvas, size, pixelsPerUnit, axisY, rowH);
    _drawContextRow(canvas, size, pixelsPerUnit, axisY, rowH);
  }

  double _xOf(DateTime d, double pixelsPerUnit) =>
      d.difference(startDate).inMilliseconds * pixelsPerUnit;

  /// Faint full-height gridlines behind the bars: very light at every fine
  /// tick — consistent vertical "separation lines" at all zooms, including
  /// inside a single period where no context boundary is on screen — and
  /// slightly stronger at the context boundaries so periods still read as
  /// columns.
  void _drawGridlines(Canvas canvas, double axisY, double pixelsPerUnit) {
    final fine = Paint()
      ..color = style.axisColor.withValues(alpha: 0.07)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final label in visibleLabels) {
      final x = _xOf(label.dateTime, pixelsPerUnit);
      if (x < 0) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, axisY), fine);
    }
    final ctx = Paint()
      ..color = style.axisColor.withValues(alpha: 0.16)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final label in majorLabels) {
      final x = _xOf(label.dateTime, pixelsPerUnit);
      if (x < 0) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, axisY), ctx);
    }
  }

  /// Fine tick row (just under the axis line): a short mark + the unit's own
  /// value (day number / hour / month), centered on each tick.
  void _drawFineTicks(Canvas canvas, Size size, double pixelsPerUnit,
      double axisY, double rowH) {
    final tickPaint = Paint()
      ..color = style.axisColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    for (final label in visibleLabels) {
      final x = _xOf(label.dateTime, pixelsPerUnit);
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(Offset(x, axisY), Offset(x, axisY + 3), tickPaint);
      tp.text = TextSpan(text: label.text, style: style.axisLabelStyle);
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, axisY + 3));
    }
  }

  /// Context row (bottom): a stronger separator at each coarse boundary, plus
  /// the span's name. Placement rule (user): when ONE period fills the whole
  /// view (no boundary on screen) the label is CENTERED — a "you are in May
  /// 2026" header that stays put as you pan; when MULTIPLE periods are visible
  /// each label is left-aligned right after its boundary.
  void _drawContextRow(Canvas canvas, Size size, double pixelsPerUnit,
      double axisY, double rowH) {
    if (majorLabels.isEmpty) return;
    final sepPaint = Paint()
      ..color = style.axisColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    final boldStyle =
        style.axisLabelStyle.copyWith(fontWeight: FontWeight.bold);
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );
    final rowTop = axisY + rowH;

    // Draw separators for on-screen boundaries; count the ones strictly inside
    // the viewport (i.e. genuine period changes the user can see).
    var internalVisible = 0;
    for (final l in majorLabels) {
      final sepX = _xOf(l.dateTime, pixelsPerUnit);
      if (sepX >= 0 && sepX <= size.width) {
        canvas.drawLine(
            Offset(sepX, axisY), Offset(sepX, size.height), sepPaint);
        if (sepX > 1) internalVisible++;
      }
    }

    // Single period fills the view → center its label.
    if (internalVisible == 0) {
      // The covering span is the last boundary at/left of the viewport start.
      LabelInfo span = majorLabels.first;
      for (final l in majorLabels) {
        if (_xOf(l.dateTime, pixelsPerUnit) <= 0) span = l;
      }
      tp.text = TextSpan(text: span.text, style: boldStyle);
      tp.layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, rowTop));
      return;
    }

    // Multiple periods → left-align each label after its separator.
    for (var i = 0; i < majorLabels.length; i++) {
      final sepX = _xOf(majorLabels[i].dateTime, pixelsPerUnit);
      final nextX = i + 1 < majorLabels.length
          ? _xOf(majorLabels[i + 1].dateTime, pixelsPerUnit)
          : size.width;
      if (nextX <= 0) continue; // span entirely off the left edge
      final labelX = math.max(2.0, sepX + 4.0);
      tp.text = TextSpan(text: majorLabels[i].text, style: boldStyle);
      tp.layout();
      if (nextX - labelX >= tp.width) {
        tp.paint(canvas, Offset(labelX, rowTop));
      }
    }
  }

  @override
  bool shouldRepaint(covariant TimelinePainter oldDelegate) {
    return startDate != oldDelegate.startDate ||
        endDate != oldDelegate.endDate ||
        zoomFactor != oldDelegate.zoomFactor ||
        visibleLabels != oldDelegate.visibleLabels ||
        majorLabels != oldDelegate.majorLabels ||
        style != oldDelegate.style;
  }

  void _drawStackedEventBars(Canvas canvas, Size size, double pixelsPerUnit,
      double labelHeight, double highlightSpace) {
    final maxTotalCount = groupedEvents.isNotEmpty
        ? groupedEvents.values
            .map((group) => group.fold(0, (sum, event) => sum + event.value))
            .reduce(math.max)
        : 0;
    final availableHeight = size.height - labelHeight - highlightSpace;

    // Each bucket occupies a slot one interval wide. Fill ~85% of the slot but
    // cap the width so bars stay a CONSISTENT thin size across zoom levels —
    // when the interval coarsens (and data is sparse) an uncapped bar balloons
    // into a fat isolated block that looks like a different chart.
    final slotWidth = getLabelInterval().inMilliseconds * pixelsPerUnit;
    const maxBarPx = 12.0;
    final barWidth = math.max(2.0, math.min(slotWidth * 0.85, maxBarPx));
    final barInset = (slotWidth - barWidth) / 2;
    final axisY = size.height - labelHeight;
    // Any non-zero bucket gets at least this many px so single events stay
    // visible next to the bulk-upload spike (Kibana min-bar pattern).
    const minTotalPx = 3.0;

    groupedEvents.forEach((dateTime, events) {
      final x = _xOf(dateTime, pixelsPerUnit) + barInset;

      // Sort events alphabetically by tag for stable stacking.
      events.sort((a, b) => a.tag.compareTo(b.tag));

      // Per-segment fraction of availableHeight, with the stack normalized so
      // it never exceeds the available height.
      double totalFrac = 0;
      for (final e in events) {
        totalFrac += _calculateBarHeight(e.value, maxTotalCount);
      }
      if (totalFrac <= 0) return;
      final scaleFactor = totalFrac > 1 ? 1 / totalFrac : 1;

      final segPx = <double>[];
      double totalPx = 0;
      for (final e in events) {
        final h =
            _calculateBarHeight(e.value, maxTotalCount) * scaleFactor * availableHeight;
        segPx.add(h);
        totalPx += h;
      }
      // Boost the whole stack to the minimum visible height if needed.
      if (totalPx > 0 && totalPx < minTotalPx) {
        final boost = minTotalPx / totalPx;
        for (var i = 0; i < segPx.length; i++) {
          segPx[i] *= boost;
        }
      }

      double yOffset = axisY;
      for (var i = 0; i < events.length; i++) {
        final barHeight = segPx[i];
        final barPaint = Paint()
          ..color = tagStyles[events[i].tag]?.color ?? Colors.grey
          ..style = PaintingStyle.fill;
        canvas.drawRect(
            Rect.fromLTWH(x, yOffset - barHeight, barWidth, barHeight),
            barPaint);
        yOffset -= barHeight;
      }
    });
  }

  double _calculateBarHeight(int value, int maxValue) {
    switch (style.scaleType) {
      case ScaleType.linear:
        return value / maxValue;
      case ScaleType.logarithmic:
        return math.log(value + 1) / math.log(maxValue + 1);
      case ScaleType.squareRoot:
        return math.sqrt(value) / math.sqrt(maxValue);
    }
  }
}

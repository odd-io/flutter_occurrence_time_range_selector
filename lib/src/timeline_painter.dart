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
    const highlightSpace = 20.0; // Space reserved for highlights at the top
    final axisPaint = Paint()
      ..color = style.axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final labelHeight = style.axisLabelStyle.fontSize! + 10; // Add some padding

    // Draw the main horizontal axis
    canvas.drawLine(Offset(0, size.height - labelHeight),
        Offset(size.width, size.height - labelHeight), axisPaint);

    // Calculate the time range and pixel per time unit
    final totalDuration = endDate.difference(startDate);
    final pixelsPerUnit = size.width / totalDuration.inMilliseconds;

    // Day/night shading (behind everything) — only on the sub-day zoom.
    _drawDayNightBands(canvas, size, pixelsPerUnit, labelHeight);

    // Major separators (behind bars) — the coarser axis tier.
    _drawMajorSeparators(canvas, size, pixelsPerUnit, labelHeight);

    // Draw time labels
    _drawTimeLabels(canvas, size, pixelsPerUnit, labelHeight);

    // Draw stacked event bars
    _drawStackedEventBars(
        canvas, size, pixelsPerUnit, labelHeight, highlightSpace);
  }

  /// Fixed-band day/night shading (20:00–06:00 local). Drawn only when a
  /// shade color is set AND the bar interval is sub-day (otherwise a bar
  /// already spans many nights and the band is meaningless).
  void _drawDayNightBands(
      Canvas canvas, Size size, double pixelsPerUnit, double labelHeight) {
    final shade = style.dayNightShadeColor;
    if (shade == null) return;
    if (getLabelInterval() >= const Duration(days: 1)) return;

    final paint = Paint()
      ..color = shade
      ..style = PaintingStyle.fill;
    final top = 0.0;
    final bottom = size.height - labelHeight;

    // Walk each calendar day in range; shade [prev 20:00 .. 06:00] etc.
    // Start a day early so a night straddling the left edge still paints.
    var day = DateTime(startDate.year, startDate.month, startDate.day)
        .subtract(const Duration(days: 1));
    final end = endDate;
    while (day.isBefore(end)) {
      final nightStart = DateTime(day.year, day.month, day.day, 20);
      final nightEnd = DateTime(day.year, day.month, day.day)
          .add(const Duration(days: 1, hours: 6));
      final x1 = nightStart.difference(startDate).inMilliseconds * pixelsPerUnit;
      final x2 = nightEnd.difference(startDate).inMilliseconds * pixelsPerUnit;
      final l = x1.clamp(0.0, size.width);
      final r = x2.clamp(0.0, size.width);
      if (r > l) {
        canvas.drawRect(Rect.fromLTRB(l, top, r, bottom), paint);
      }
      day = day.add(const Duration(days: 1));
    }
  }

  /// Heavier vertical separators + bold labels at the coarse (major) tier.
  void _drawMajorSeparators(
      Canvas canvas, Size size, double pixelsPerUnit, double labelHeight) {
    if (majorLabels.isEmpty) return;
    final linePaint = Paint()
      ..color = style.axisColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final boldStyle = style.axisLabelStyle.copyWith(fontWeight: FontWeight.bold);
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    for (final label in majorLabels) {
      final x =
          label.dateTime.difference(startDate).inMilliseconds * pixelsPerUnit;
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height - labelHeight), linePaint);
      tp.text = TextSpan(text: label.text, style: boldStyle);
      tp.layout();
      tp.paint(canvas, Offset(x + 3, size.height - labelHeight));
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

  void _drawTimeLabels(
      Canvas canvas, Size size, double pixelsPerUnit, double labelHeight) {
    final labelPaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var label in visibleLabels) {
      final x =
          label.dateTime.difference(startDate).inMilliseconds * pixelsPerUnit;

      if (x >= 0 && x <= size.width) {
        labelPaint.text = TextSpan(
          text: label.text,
          style: style.axisLabelStyle,
        );
        labelPaint.layout();
        labelPaint.paint(canvas,
            Offset(x - labelPaint.width / 2, size.height - labelHeight));
      }
    }
  }

  void _drawStackedEventBars(Canvas canvas, Size size, double pixelsPerUnit,
      double labelHeight, double highlightSpace) {
    final maxTotalCount = groupedEvents.isNotEmpty
        ? groupedEvents.values
            .map((group) => group.fold(0, (sum, event) => sum + event.value))
            .reduce(math.max)
        : 0;
    final availableHeight = size.height - labelHeight - highlightSpace;

    // Each bucket occupies a slot one interval wide. Draw the bar at ~70%
    // of the slot (capped at maxBarPx) and center it, so wide slots render
    // as a distinct bar with whitespace instead of a fat block.
    final labelInterval = getLabelInterval();
    final slotWidth = labelInterval.inMilliseconds * pixelsPerUnit;
    const maxBarPx = 22.0;
    final barWidth = math.max(1.0, math.min(slotWidth * 0.7, maxBarPx));
    final barInset = (slotWidth - barWidth) / 2;

    groupedEvents.forEach((dateTime, events) {
      final x = dateTime.difference(startDate).inMilliseconds * pixelsPerUnit +
          barInset;
      double yOffset = size.height - labelHeight;

      // Sort events alphabetically by tag
      events.sort((a, b) => a.tag.compareTo(b.tag));

      double totalBarHeight = 0;

      for (var event in events) {
        double barHeight = _calculateBarHeight(event.value, maxTotalCount);
        totalBarHeight += barHeight;
      }

      // Scale factor to ensure total height doesn't exceed available height
      final scaleFactor = totalBarHeight > 1 ? 1 / totalBarHeight : 1;

      for (var event in events) {
        double barHeight = _calculateBarHeight(event.value, maxTotalCount) *
            scaleFactor *
            availableHeight;

        final barPaint = Paint()
          ..color = tagStyles[event.tag]?.color ?? Colors.grey
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

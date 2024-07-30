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
    required this.getLabelInterval,
  });

  final DateTime endDate;
  final Function() getLabelInterval;
  final Map<DateTime, List<GroupedEvent>> groupedEvents;
  final DateTime startDate;
  final TimelineStyle style;
  final Map<String, TagStyle> tagStyles;
  final List<LabelInfo> visibleLabels;
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

    // Draw time labels
    _drawTimeLabels(canvas, size, pixelsPerUnit, labelHeight);

    // Draw stacked event bars
    _drawStackedEventBars(
        canvas, size, pixelsPerUnit, labelHeight, highlightSpace);
  }

  @override
  bool shouldRepaint(covariant TimelinePainter oldDelegate) {
    return startDate != oldDelegate.startDate ||
        endDate != oldDelegate.endDate ||
        zoomFactor != oldDelegate.zoomFactor ||
        visibleLabels != oldDelegate.visibleLabels ||
        style.scaleType != oldDelegate.style.scaleType;
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

    final labelInterval = getLabelInterval();
    final barWidth = labelInterval.inMilliseconds * pixelsPerUnit;

    groupedEvents.forEach((dateTime, events) {
      final x = dateTime.difference(startDate).inMilliseconds * pixelsPerUnit;
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

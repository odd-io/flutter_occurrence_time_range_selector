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
    _drawStackedEventBars(canvas, size, pixelsPerUnit, labelHeight);
  }

  @override
  bool shouldRepaint(covariant TimelinePainter oldDelegate) {
    return startDate != oldDelegate.startDate ||
        endDate != oldDelegate.endDate ||
        zoomFactor != oldDelegate.zoomFactor ||
        visibleLabels != oldDelegate.visibleLabels;
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

  void _drawStackedEventBars(
      Canvas canvas, Size size, double pixelsPerUnit, double labelHeight) {
    final maxTotalCount = groupedEvents.isNotEmpty
        ? groupedEvents.values
            .map((group) => group.fold(0, (sum, event) => sum + event.value))
            .reduce(math.max)
        : 0;
    final availableHeight = size.height - labelHeight;
    final unitHeight =
        availableHeight / (maxTotalCount > 0 ? maxTotalCount : 1);

    final labelInterval = getLabelInterval();
    final barWidth = labelInterval.inMilliseconds * pixelsPerUnit;

    groupedEvents.forEach((dateTime, events) {
      final x = dateTime.difference(startDate).inMilliseconds * pixelsPerUnit;
      double yOffset = size.height - labelHeight;

      // Sort events alphabetically by tag
      events.sort((a, b) => a.tag.compareTo(b.tag));

      for (var event in events) {
        final barHeight = event.value * unitHeight;
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
}

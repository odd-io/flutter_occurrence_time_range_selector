import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:math' as math;

import 'enums.dart';
import 'grouped_event.dart';
import 'tag_style.dart';
import 'time_event.dart';
import 'timeline_style.dart';

class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.startDate,
    required this.endDate,
    required this.events,
    required this.tagStyles,
    required this.zoomLevel,
    required this.style,
  });

  final DateTime endDate;
  final List<TimeEvent> events;
  final DateTime startDate;
  final TimelineStyle style;
  final Map<String, TagStyle> tagStyles;
  final ZoomLevel zoomLevel;

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
    final pixelsPerUnit = size.width / totalDuration.inMinutes;

    // Draw time labels and vertical grid lines
    _drawTimeLabels(canvas, size, pixelsPerUnit, labelHeight);

    // Draw stacked event bars
    _drawStackedEventBars(canvas, size, pixelsPerUnit, labelHeight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // For simplicity, we're always repainting
  }

  void _drawTimeLabels(
      Canvas canvas, Size size, double pixelsPerUnit, double labelHeight) {
    final labelPaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final labelInterval = _getLabelInterval();
    DateTime currentLabel = _getFirstVisibleLabel(startDate);

    while (currentLabel.isBefore(endDate)) {
      final x = currentLabel.difference(startDate).inMinutes * pixelsPerUnit;

      // Draw time label
      labelPaint.text = TextSpan(
        text: _formatLabel(currentLabel),
        style: style.axisLabelStyle,
      );
      labelPaint.layout();
      labelPaint.paint(
          canvas, Offset(x - labelPaint.width / 2, size.height - labelHeight));

      // Move to next label based on zoom level
      currentLabel = currentLabel.add(labelInterval);
    }
  }

  void _drawStackedEventBars(
      Canvas canvas, Size size, double pixelsPerUnit, double labelHeight) {
    final groupedEvents = _groupEventsByZoomLevel();
    final maxTotalCount = groupedEvents.values
        .map((group) => group.fold(0, (sum, event) => sum + event.value))
        .reduce(math.max);
    final availableHeight = size.height - labelHeight;
    final unitWidth = _getUnitWidthInMinutes() * pixelsPerUnit;
    final unitHeight = availableHeight / maxTotalCount;

    groupedEvents.forEach((dateTime, events) {
      final x = dateTime.difference(startDate).inMinutes * pixelsPerUnit;
      double yOffset = availableHeight;

      // Sort events alphabetically by tag
      events.sort((a, b) => a.tag.compareTo(b.tag));

      for (var event in events) {
        final barHeight = event.value * unitHeight;
        final barPaint = Paint()
          ..color = tagStyles[event.tag]?.color ?? Colors.grey
          ..style = PaintingStyle.fill;

        canvas.drawRect(
            Rect.fromLTWH(x, yOffset - barHeight, unitWidth, barHeight),
            barPaint);

        yOffset -= barHeight;
      }
    });
  }

  Map<DateTime, List<GroupedEvent>> _groupEventsByZoomLevel() {
    final groupedEvents = <DateTime, List<GroupedEvent>>{};

    for (var event in events) {
      if (event.dateTime.isBefore(startDate) ||
          event.dateTime.isAfter(endDate)) {
        continue;
      }

      final groupKey = _getGroupKeyForDate(event.dateTime);
      groupedEvents.putIfAbsent(groupKey, () => []);

      final existingEvent = groupedEvents[groupKey]!
          .firstWhere((e) => e.tag == event.tag, orElse: () {
        final newEvent = GroupedEvent(tag: event.tag, value: 0);
        groupedEvents[groupKey]!.add(newEvent);
        return newEvent;
      });

      existingEvent.value++;
    }

    return groupedEvents;
  }

  DateTime _getGroupKeyForDate(DateTime date) {
    switch (zoomLevel) {
      case ZoomLevel.hour:
        return DateTime(date.year, date.month, date.day, date.hour);
      case ZoomLevel.day:
        return DateTime(date.year, date.month, date.day);
      case ZoomLevel.week:
        final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case ZoomLevel.month:
        return DateTime(date.year, date.month);
      case ZoomLevel.year:
        return DateTime(date.year);
    }
  }

  int _getUnitWidthInMinutes() {
    switch (zoomLevel) {
      case ZoomLevel.hour:
        return 60;
      case ZoomLevel.day:
        return 24 * 60;
      case ZoomLevel.week:
        return 7 * 24 * 60;
      case ZoomLevel.month:
        return 30 * 24 * 60; // Approximation
      case ZoomLevel.year:
        return 365 * 24 * 60; // Approximation
    }
  }

  DateTime _getFirstVisibleLabel(DateTime start) {
    switch (zoomLevel) {
      case ZoomLevel.hour:
        return DateTime(start.year, start.month, start.day, start.hour);
      case ZoomLevel.day:
        return DateTime(start.year, start.month, start.day);
      case ZoomLevel.week:
        return start.subtract(Duration(days: start.weekday - 1));
      case ZoomLevel.month:
        return DateTime(start.year, start.month, 1);
      case ZoomLevel.year:
        return DateTime(start.year, 1, 1);
    }
  }

  Duration _getLabelInterval() {
    switch (zoomLevel) {
      case ZoomLevel.hour:
        return const Duration(hours: 6);
      case ZoomLevel.day:
        return const Duration(days: 1);
      case ZoomLevel.week:
        return const Duration(days: 7);
      case ZoomLevel.month:
        return const Duration(days: 30);
      case ZoomLevel.year:
        return const Duration(days: 365);
    }
  }

  String _formatLabel(DateTime date) {
    switch (zoomLevel) {
      case ZoomLevel.hour:
        return intl.DateFormat('HH:mm').format(date);
      case ZoomLevel.day:
        return intl.DateFormat('dd.MM').format(date);
      case ZoomLevel.week:
        return 'Week ${((date.day - 1) ~/ 7) + 1}\n${intl.DateFormat('MMM').format(date)}';
      case ZoomLevel.month:
        return intl.DateFormat('MMM yyyy').format(date);
      case ZoomLevel.year:
        return date.year.toString();
    }
  }
}

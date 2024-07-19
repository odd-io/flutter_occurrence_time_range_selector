import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'enums.dart';
import 'label_info.dart';
import 'tag_style.dart';
import 'time_event.dart';
import 'timeline_painter.dart';
import 'timeline_style.dart';

class TimeRangeSelector extends StatefulWidget {
  const TimeRangeSelector({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.events,
    required this.tagStyles,
    this.onRangeChanged,
    this.onEventHover,
    required this.style,
  });

  final Function(DateTime, DateTime)? onRangeChanged;
  final Function(TimeEvent?)? onEventHover;
  final DateTime endDate;
  final List<TimeEvent> events;
  final DateTime startDate;
  final TimelineStyle style;
  final Map<String, TagStyle> tagStyles;

  @override
  TimeRangeSelectorState createState() => TimeRangeSelectorState();
}

class TimeRangeSelectorState extends State<TimeRangeSelector> {
  late DateTime _currentEndDate;
  late DateTime _currentStartDate;
  late ZoomLevel _currentZoomLevel;
  final List<LabelInfo> _visibleLabels = [];
  double _pixelsPerMinute = 1.0;

  @override
  void initState() {
    super.initState();
    _currentStartDate = widget.startDate;
    _currentEndDate = widget.endDate;
    _currentZoomLevel = _calculateInitialZoomLevel();
    _initializeLabels();
  }

  void _initializeLabels() {
    final labelInterval = _getLabelInterval(_currentZoomLevel);
    DateTime currentLabel =
        _getFirstVisibleLabel(_currentStartDate, _currentZoomLevel);
    _visibleLabels.clear();

    while (currentLabel.isBefore(_currentEndDate)) {
      _visibleLabels.add(LabelInfo(
          currentLabel, _formatLabel(currentLabel, _currentZoomLevel)));
      currentLabel = currentLabel.add(labelInterval);
    }
  }

  void _updateVisibleLabels() {
    final labelInterval = _getLabelInterval(_currentZoomLevel);

    // Remove labels that are now out of range
    _visibleLabels.removeWhere((label) =>
        label.dateTime.isBefore(_currentStartDate) ||
        label.dateTime.isAfter(_currentEndDate));

    // Add new labels at the start if needed
    if (_visibleLabels.isNotEmpty) {
      DateTime firstLabelDate = _visibleLabels.first.dateTime;
      while (firstLabelDate.isAfter(_currentStartDate)) {
        firstLabelDate = firstLabelDate.subtract(labelInterval);
        _visibleLabels.insert(
            0,
            LabelInfo(firstLabelDate,
                _formatLabel(firstLabelDate, _currentZoomLevel)));
      }
    }

    // Add new labels at the end if needed
    if (_visibleLabels.isNotEmpty) {
      DateTime lastLabelDate = _visibleLabels.last.dateTime;
      while (lastLabelDate.isBefore(_currentEndDate)) {
        lastLabelDate = lastLabelDate.add(labelInterval);
        _visibleLabels.add(LabelInfo(
            lastLabelDate, _formatLabel(lastLabelDate, _currentZoomLevel)));
      }
    }

    // If all labels were removed, reinitialize
    if (_visibleLabels.isEmpty) {
      _initializeLabels();
    }

    // Update label text based on current zoom level
    for (var label in _visibleLabels) {
      label.text = _formatLabel(label.dateTime, _currentZoomLevel);
    }
  }

  ZoomLevel _calculateZoomLevel(Duration range) {
    if (range.inDays <= 15) return ZoomLevel.hour;
    if (range.inDays <= 168) return ZoomLevel.day;
    if (range.inDays <= 1176) return ZoomLevel.week;
    if (range.inDays <= 5040) return ZoomLevel.month;
    return ZoomLevel.year;
  }

  ZoomLevel _calculateInitialZoomLevel() {
    return _calculateZoomLevel(_currentEndDate.difference(_currentStartDate));
  }

  void _handleZoom(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        double zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
        Duration currentRange = _currentEndDate.difference(_currentStartDate);
        Duration newRange =
            Duration(minutes: (currentRange.inMinutes / zoomFactor).round());

        DateTime middlePoint = _currentStartDate.add(currentRange ~/ 2);
        _currentStartDate = middlePoint.subtract(newRange ~/ 2);
        _currentEndDate = middlePoint.add(newRange ~/ 2);

        _currentZoomLevel = _calculateZoomLevel(newRange);
        _updateVisibleLabels();
      });
      widget.onRangeChanged?.call(_currentStartDate, _currentEndDate);
    }
  }

  void _handlePan(DragUpdateDetails details) {
    Duration shiftDuration;
    switch (_currentZoomLevel) {
      case ZoomLevel.hour:
        shiftDuration = Duration(minutes: -details.delta.dx.round());
        break;
      case ZoomLevel.day:
        shiftDuration = Duration(hours: -details.delta.dx.round());
        break;
      case ZoomLevel.week:
        shiftDuration = Duration(hours: -7 * details.delta.dx.round());
        break;
      case ZoomLevel.month:
        shiftDuration = Duration(hours: -30 * details.delta.dx.round());
        break;
      case ZoomLevel.year:
        shiftDuration = Duration(hours: -365 * details.delta.dx.round());
        break;
      default:
        shiftDuration = const Duration(); // No shift by default
    }
    setState(() {
      _currentStartDate = _currentStartDate.add(shiftDuration);
      _currentEndDate = _currentEndDate.add(shiftDuration);
      _updateVisibleLabels();
    });
    widget.onRangeChanged?.call(_currentStartDate, _currentEndDate);
  }

  DateTime _getFirstVisibleLabel(DateTime start, ZoomLevel zoomLevel) {
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

  Duration _getLabelInterval(ZoomLevel zoomLevel) {
    switch (zoomLevel) {
      case ZoomLevel.hour:
        return const Duration(hours: 6);
      case ZoomLevel.day:
        return const Duration(days: 4);
      case ZoomLevel.week:
        return const Duration(days: 7);
      case ZoomLevel.month:
        return const Duration(days: 30);
      case ZoomLevel.year:
        return const Duration(days: 365);
    }
  }

  String _formatLabel(DateTime date, ZoomLevel zoomLevel) {
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

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handleZoom,
      child: GestureDetector(
        onPanUpdate: _handlePan,
        child: Container(
          color: widget.style.backgroundColor,
          child: CustomPaint(
            size: Size.infinite,
            painter: TimelinePainter(
              startDate: _currentStartDate,
              endDate: _currentEndDate,
              events: widget.events,
              tagStyles: widget.tagStyles,
              zoomLevel: _currentZoomLevel,
              style: widget.style,
              visibleLabels: _visibleLabels,
            ),
          ),
        ),
      ),
    );
  }
}

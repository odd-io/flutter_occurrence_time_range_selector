import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:math' as math;

import 'grouped_event.dart';
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
  Duration _currentGroupingInterval = Duration.zero;
  late DateTime _currentStartDate;
  Map<DateTime, List<GroupedEvent>> _groupedEvents = {};
  final List<LabelInfo> _visibleLabels = [];
  late double _widgetWidth;
  late double _zoomFactor; // minutes per pixel

  @override
  void initState() {
    super.initState();
    _currentStartDate = widget.startDate;
    _currentEndDate = widget.endDate;
    _zoomFactor = _calculateInitialZoomFactor();
    _updateGroupedEvents();
  }

  double _calculateInitialZoomFactor() {
    final range = _currentEndDate.difference(_currentStartDate);
    return range.inMinutes / 1000; // Adjust this value as needed
  }

  void _generateLabels() {
    _visibleLabels.clear();
    final labelInterval = _calculateDynamicLabelInterval();
    DateTime currentLabel =
        _alignToLabelInterval(_currentStartDate, labelInterval);

    while (currentLabel.isBefore(_currentEndDate)) {
      _visibleLabels.add(LabelInfo(currentLabel, _formatLabel(currentLabel)));
      currentLabel = currentLabel.add(labelInterval);
    }
  }

  Duration _calculateDynamicLabelInterval() {
    // Aim for approximately 1 label per 100 pixels
    final desiredLabelCount = (_widgetWidth / 100).round();
    final totalMinutes =
        _currentEndDate.difference(_currentStartDate).inMinutes;
    final minutesPerLabel = totalMinutes / desiredLabelCount;

    // Round to nearest sensible interval
    if (minutesPerLabel < 60) {
      return Duration(minutes: (minutesPerLabel / 5).ceil() * 5);
    } else if (minutesPerLabel < 1440) {
      return Duration(hours: (minutesPerLabel / 60).ceil());
    } else if (minutesPerLabel < 10080) {
      return Duration(days: (minutesPerLabel / 1440).ceil());
    } else if (minutesPerLabel < 43200) {
      return Duration(days: ((minutesPerLabel / 10080).ceil() * 7));
    } else {
      return Duration(days: ((minutesPerLabel / 43200).ceil() * 30));
    }
  }

  DateTime _alignToLabelInterval(DateTime date, Duration interval) {
    return DateTime.fromMillisecondsSinceEpoch(
        (date.millisecondsSinceEpoch / interval.inMilliseconds).floor() *
            interval.inMilliseconds);
  }

  String _formatLabel(DateTime date) {
    final interval = _calculateDynamicLabelInterval();
    if (interval.inMinutes < 60) {
      return intl.DateFormat('HH:mm').format(date);
    } else if (interval.inHours < 24) {
      return intl.DateFormat('dd.MM HH:mm').format(date);
    } else if (interval.inDays < 7) {
      return intl.DateFormat('dd.MM').format(date);
    } else if (interval.inDays < 30) {
      return 'Week ${((date.day - 1) ~/ 7) + 1}\n${intl.DateFormat('MMM').format(date)}';
    } else if (interval.inDays < 365) {
      return intl.DateFormat('MMM yyyy').format(date);
    } else {
      return date.year.toString();
    }
  }

  void _updateGroupedEvents() {
    final newGroupingInterval = _calculateGroupingInterval();
    if (newGroupingInterval != _currentGroupingInterval) {
      _currentGroupingInterval = newGroupingInterval;
      _groupedEvents =
          _groupEventsByInterval(widget.events, _currentGroupingInterval);
    }
  }

  Duration _calculateGroupingInterval() {
    if (_zoomFactor < 1) return const Duration(minutes: 1);
    if (_zoomFactor < 5) return const Duration(minutes: 5);
    if (_zoomFactor < 15) return const Duration(minutes: 15);
    if (_zoomFactor < 30) return const Duration(minutes: 30);
    if (_zoomFactor < 60) return const Duration(hours: 1);
    if (_zoomFactor < 120) return const Duration(hours: 2);
    if (_zoomFactor < 360) return const Duration(hours: 6);
    if (_zoomFactor < 720) return const Duration(hours: 12);
    if (_zoomFactor < 1440) return const Duration(days: 1);
    if (_zoomFactor < 10080) return const Duration(days: 7);
    if (_zoomFactor < 43200) return const Duration(days: 30);
    if (_zoomFactor < 129600) return const Duration(days: 90);
    if (_zoomFactor < 259200) return const Duration(days: 180);
    return const Duration(days: 365);
  }

  Map<DateTime, List<GroupedEvent>> _groupEventsByInterval(
      List<TimeEvent> events, Duration interval) {
    final groupedEvents = <DateTime, List<GroupedEvent>>{};

    for (var event in events) {
      final groupKey = DateTime.fromMillisecondsSinceEpoch(
          (event.dateTime.millisecondsSinceEpoch ~/ interval.inMilliseconds) *
              interval.inMilliseconds);

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

  void _handleZoom(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        double zoomChange = event.scrollDelta.dy > 0 ? 1.1 : 0.9;
        _zoomFactor *= zoomChange;

        Duration currentRange = _currentEndDate.difference(_currentStartDate);
        DateTime middlePoint = _currentStartDate.add(currentRange ~/ 2);
        Duration newHalfRange = Duration(
            minutes: (currentRange.inMinutes * zoomChange ~/ 2).round());

        _currentStartDate = middlePoint.subtract(newHalfRange);
        _currentEndDate = middlePoint.add(newHalfRange);

        _updateGroupedEvents();
        _generateLabels();
      });
      widget.onRangeChanged?.call(_currentStartDate, _currentEndDate);
    }
  }

  void _handlePan(DragUpdateDetails details) {
    Duration shiftDuration =
        Duration(minutes: (_zoomFactor * -details.delta.dx).round());
    setState(() {
      _currentStartDate = _currentStartDate.add(shiftDuration);
      _currentEndDate = _currentEndDate.add(shiftDuration);
      _generateLabels();
    });
    widget.onRangeChanged?.call(_currentStartDate, _currentEndDate);
  }

  Map<DateTime, List<GroupedEvent>> _getRelevantGroups() {
    Map<DateTime, List<GroupedEvent>> selectedEvents = {};
    for (var key in _groupedEvents.keys) {
      if (key.isAfter(_currentStartDate) && key.isBefore(_currentEndDate)) {
        selectedEvents[key] = _groupedEvents[key]!;
      }
    }
    return selectedEvents;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _widgetWidth = constraints.maxWidth;
        _generateLabels();
        return Listener(
          onPointerSignal: _handleZoom,
          child: GestureDetector(
            onPanUpdate: _handlePan,
            child: Container(
              color: widget.style.backgroundColor,
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: TimelinePainter(
                  startDate: _currentStartDate,
                  endDate: _currentEndDate,
                  groupedEvents: _getRelevantGroups(),
                  tagStyles: widget.tagStyles,
                  zoomFactor: _zoomFactor,
                  style: widget.style,
                  visibleLabels: _visibleLabels,
                  getLabelInterval: _calculateGroupingInterval,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

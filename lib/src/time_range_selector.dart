import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'grouped_event.dart';
import 'highlight_group.dart';
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
    required this.style,
    this.minZoomFactor = 1,
    this.maxZoomFactor = 31536000000,
    this.highlightGroups = const [],
  });

  final Function(DateTime, DateTime)? onRangeChanged;
  final DateTime endDate;
  final List<TimeEvent> events;
  final List<HighlightGroup> highlightGroups;
  final double maxZoomFactor;
  final double minZoomFactor;
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
  late double _zoomFactor; // milliseconds per pixel

  @override
  void initState() {
    super.initState();
    _currentStartDate = widget.startDate;
    _currentEndDate = widget.endDate;
    _zoomFactor = _calculateInitialZoomFactor().clamp(
      widget.minZoomFactor,
      widget.maxZoomFactor,
    );
    _updateGroupedEvents();
  }

  double _calculateInitialZoomFactor() {
    final range = _currentEndDate.difference(_currentStartDate);
    return range.inMilliseconds / 1000;
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
    final totalMilliseconds =
        _currentEndDate.difference(_currentStartDate).inMilliseconds;
    final millisecondsPerLabel = totalMilliseconds / desiredLabelCount;

    // Round to nearest sensible interval
    if (millisecondsPerLabel < 1000) {
      return Duration(milliseconds: (millisecondsPerLabel / 100).ceil() * 100);
    } else if (millisecondsPerLabel < 60000) {
      // Less than a minute
      return Duration(
          milliseconds: (millisecondsPerLabel / 1000).ceil() * 1000);
    } else if (millisecondsPerLabel < 3600000) {
      // Less than an hour
      return Duration(minutes: (millisecondsPerLabel / 60000).ceil());
    } else if (millisecondsPerLabel < 86400000) {
      // Less than a day
      return Duration(hours: (millisecondsPerLabel / 3600000).ceil());
    } else if (millisecondsPerLabel < 604800000) {
      // Less than a week
      return Duration(days: (millisecondsPerLabel / 86400000).ceil());
    } else if (millisecondsPerLabel < 2592000000) {
      // Less than a month
      return Duration(days: ((millisecondsPerLabel / 604800000).ceil() * 7));
    } else {
      return Duration(days: ((millisecondsPerLabel / 2592000000).ceil() * 30));
    }
  }

  DateTime _alignToLabelInterval(DateTime date, Duration interval) {
    return DateTime.fromMillisecondsSinceEpoch(
        (date.millisecondsSinceEpoch / interval.inMilliseconds).floor() *
            interval.inMilliseconds);
  }

  String _formatLabel(DateTime date) {
    final interval = _calculateDynamicLabelInterval();
    if (interval.inMilliseconds < 1000) {
      return intl.DateFormat('HH:mm:ss.SSS').format(date);
    } else if (interval.inMilliseconds < 60000) {
      return intl.DateFormat('HH:mm:ss').format(date);
    } else if (interval.inMinutes < 60) {
      return intl.DateFormat('HH:mm').format(date);
    } else if (interval.inHours < 24) {
      return intl.DateFormat('dd.MM HH:mm').format(date);
    } else if (interval.inDays < 7) {
      return intl.DateFormat('dd.MM').format(date);
    } else if (interval.inDays < 30) {
      return 'Week ${((date.day - 1) ~/ 7) + 1} ${intl.DateFormat('MMM').format(date)}';
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
    if (_zoomFactor < 1) return const Duration(milliseconds: 1);
    if (_zoomFactor < 10) return const Duration(milliseconds: 10);
    if (_zoomFactor < 100) return const Duration(milliseconds: 100);
    if (_zoomFactor < 1000) return const Duration(seconds: 1);
    if (_zoomFactor < 5000) return const Duration(seconds: 5);
    if (_zoomFactor < 15000) return const Duration(seconds: 15);
    if (_zoomFactor < 30000) return const Duration(seconds: 30);
    if (_zoomFactor < 60000) return const Duration(minutes: 1);
    if (_zoomFactor < 300000) return const Duration(minutes: 5);
    if (_zoomFactor < 900000) return const Duration(minutes: 15);
    if (_zoomFactor < 1800000) return const Duration(minutes: 30);
    if (_zoomFactor < 3600000) return const Duration(hours: 1);
    if (_zoomFactor < 7200000) return const Duration(hours: 2);
    if (_zoomFactor < 21600000) return const Duration(hours: 6);
    if (_zoomFactor < 43200000) return const Duration(hours: 12);
    if (_zoomFactor < 86400000) return const Duration(days: 1);
    if (_zoomFactor < 604800000) return const Duration(days: 7);
    if (_zoomFactor < 2592000000) return const Duration(days: 30);
    if (_zoomFactor < 7776000000) return const Duration(days: 90);
    if (_zoomFactor < 15552000000) return const Duration(days: 180);
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

  List<Widget> _buildHighlights(BoxConstraints constraints) {
    final totalDuration = _currentEndDate.difference(_currentStartDate);
    final pixelsPerUnit = constraints.maxWidth / totalDuration.inMilliseconds;

    return widget.highlightGroups.expand((group) {
      return group.dates.map((date) {
        final x =
            date.difference(_currentStartDate).inMilliseconds * pixelsPerUnit;
        if (x >= 0 && x <= constraints.maxWidth) {
          return Positioned(
            left: x,
            top: 0,
            child: group.builder(context, Size(20, constraints.maxHeight)),
          );
        }
        return const SizedBox.shrink();
      });
    }).toList();
  }

  void _handleZoom(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      double zoomChange = event.scrollDelta.dy > 0 ? 1.1 : 0.9;
      final newZoomFactor = (_zoomFactor * zoomChange)
          .clamp(widget.minZoomFactor, widget.maxZoomFactor);
      if (newZoomFactor == _zoomFactor) {
        return;
      }

      Duration currentRange = _currentEndDate.difference(_currentStartDate);
      DateTime middlePoint = _currentStartDate.add(currentRange ~/ 2);
      Duration newHalfRange = Duration(
          milliseconds:
              (currentRange.inMilliseconds * zoomChange ~/ 2).round());

      setState(() {
        _zoomFactor = newZoomFactor;

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
        Duration(milliseconds: (_zoomFactor * -details.delta.dx).round());
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
        return Stack(
          children: [
            Listener(
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
            ),
            ..._buildHighlights(constraints),
          ],
        );
      },
    );
  }
}

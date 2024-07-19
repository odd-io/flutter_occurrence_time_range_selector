import 'package:flutter/material.dart';

import 'enums.dart';
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

  @override
  void initState() {
    super.initState();
    _currentStartDate = widget.startDate;
    _currentEndDate = widget.endDate;
    _currentZoomLevel = _calculateInitialZoomLevel();
  }

  ZoomLevel _calculateInitialZoomLevel() {
    final difference = _currentEndDate.difference(_currentStartDate).inDays;
    if (difference <= 7) return ZoomLevel.hour;
    if (difference <= 168) return ZoomLevel.day;
    if (difference <= 1176) return ZoomLevel.week;
    if (difference <= 5040) return ZoomLevel.month;
    return ZoomLevel.year;
  }

  void _updateZoomLevel() {
    ZoomLevel newZoomLevel = _calculateInitialZoomLevel();
    if (newZoomLevel != _currentZoomLevel) {
      setState(() {
        _currentZoomLevel = newZoomLevel;
      });
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
    });
    widget.onRangeChanged?.call(_currentStartDate, _currentEndDate);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          ),
        ),
      ),
    );
  }
}

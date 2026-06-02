import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'calendar_interval.dart';
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
    this.events = const [],
    this.preAggregated,
    this.baseInterval,
    required this.tagStyles,
    this.onRangeChanged,
    required this.style,
    this.minZoomFactor = 1,
    this.maxZoomFactor = 31536000000,
    this.highlightGroups = const [],
  });

  final Function(DateTime, DateTime)? onRangeChanged;
  final DateTime endDate;

  /// Per-occurrence input (one [TimeEvent] per event). The widget counts
  /// these into per-bucket totals. Use [preAggregated] instead when you
  /// already have server-side counts — it avoids materializing one object
  /// per event (the timeline only ever needs counts).
  final List<TimeEvent> events;

  /// Pre-aggregated counts: bucketStart (a fine base grid, e.g. daily) →
  /// {tag: count}. When provided, [events] is ignored and the widget
  /// re-aggregates this base grid to the current calendar-nice display
  /// interval. This is the production-shaped path (no per-event objects).
  final Map<DateTime, Map<String, int>>? preAggregated;

  /// The finest interval the data supports (the server bucket size). The
  /// widget never aggregates finer than this. When null it falls back to
  /// daily for pre-aggregated input, or unbounded for raw events.
  final CalendarInterval? baseInterval;

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
  late DateTime _currentStartDate;
  Map<DateTime, List<GroupedEvent>> _groupedEvents = {};
  final List<LabelInfo> _visibleLabels = [];
  // Coarser "major" boundaries (month/year/day) for the two-tier axis —
  // heavier separators + bold labels drawn by the painter.
  final List<LabelInfo> _majorLabels = [];
  double _widgetWidth = 0;
  late double _zoomFactor; // milliseconds per pixel
  double? _initialScaleZoomFactor;

  // Current calendar-aligned bar/grouping interval (chosen from range + width).
  CalendarInterval? _barInterval;

  @override
  void initState() {
    super.initState();
    _currentStartDate = widget.startDate;
    _currentEndDate = widget.endDate;
    _zoomFactor = _calculateInitialZoomFactor().clamp(
      widget.minZoomFactor,
      widget.maxZoomFactor,
    );
    // Grouping + labels are computed in build(), once the widget width is known.
  }

  @override
  void didUpdateWidget(TimeRangeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.events, oldWidget.events) ||
        !identical(widget.preAggregated, oldWidget.preAggregated) ||
        widget.baseInterval != oldWidget.baseInterval) {
      _barInterval = null; // force re-group on next build
    }
  }

  double _calculateInitialZoomFactor() {
    final range = _currentEndDate.difference(_currentStartDate);
    return range.inMilliseconds / 1000;
  }

  /// Finest calendar interval we may aggregate to. The explicit
  /// [baseInterval] (server bucket) wins; otherwise pre-aggregated input
  /// defaults to daily and raw events are unbounded.
  CalendarInterval? get _minInterval =>
      widget.baseInterval ??
      (widget.preAggregated != null
          ? const CalendarInterval(CalendarUnit.day, 1)
          : null);

  /// Recompute bars + labels for the current range/width. Called from build()
  /// (and therefore after every pan/zoom setState). Re-groups only when the
  /// chosen bar interval actually changes, so panning is cheap.
  void _recompute() {
    final rangeMs = _currentEndDate.difference(_currentStartDate).inMilliseconds;
    if (rangeMs <= 0 || _widgetWidth <= 0) return;

    // Bars: target a comfortable density (~1 bar per 4px), never finer than
    // the base grid. Calendar-aligned so bars sit on day/week/month edges.
    final newBar = pickCalendarInterval(
      rangeMs: rangeMs,
      targetCount: _widgetWidth / 4,
      min: _minInterval,
    );
    if (_barInterval == null ||
        newBar.unit != _barInterval!.unit ||
        newBar.count != _barInterval!.count) {
      _barInterval = newBar;
      _groupedEvents = _groupEvents(newBar);
    }
    _generateLabels();
  }

  /// Build per-bucket counts, aligned to [bar]. Works for both the
  /// pre-aggregated base grid and the raw per-event list.
  Map<DateTime, List<GroupedEvent>> _groupEvents(CalendarInterval bar) {
    final buckets = <DateTime, Map<String, int>>{};
    final pre = widget.preAggregated;
    if (pre != null) {
      pre.forEach((day, tagCounts) {
        final key = bar.align(day);
        final m = buckets.putIfAbsent(key, () => {});
        tagCounts.forEach((tag, c) => m[tag] = (m[tag] ?? 0) + c);
      });
    } else {
      for (final e in widget.events) {
        final key = bar.align(e.dateTime);
        final m = buckets.putIfAbsent(key, () => {});
        m[e.tag] = (m[e.tag] ?? 0) + 1;
      }
    }
    return buckets.map((key, m) => MapEntry(
        key, m.entries.map((e) => GroupedEvent(tag: e.key, value: e.value)).toList()));
  }

  void _generateLabels() {
    _visibleLabels.clear();
    _majorLabels.clear();
    final rangeMs = _currentEndDate.difference(_currentStartDate).inMilliseconds;
    if (rangeMs <= 0 || _widgetWidth <= 0) return;
    final pxPerMs = _widgetWidth / rangeMs;
    double xOf(DateTime d) =>
        d.difference(_currentStartDate).inMilliseconds * pxPerMs;

    // Minor labels: ~1 per 110px (Extended-Wilkinson density rule), never
    // finer than the bars. Calendar-aligned so they land on 00:00/Mon/1st.
    final labelIv = pickCalendarInterval(
      rangeMs: rangeMs,
      targetCount: _widgetWidth / 110,
      min: _barInterval,
    );

    // Major boundaries: the next coarser calendar unit (day→month→year).
    // Drawn as heavier separators + bold labels so periods are visually
    // grouped (e.g. months distinguished on a multi-week view).
    final majorIv = majorIntervalFor(labelIv.unit);
    final majorXs = <double>[];
    if (majorIv != null) {
      DateTime m = majorIv.align(_currentStartDate);
      if (m.isBefore(_currentStartDate)) m = majorIv.next(m);
      double lastX = -1e9;
      while (m.isBefore(_currentEndDate)) {
        final x = xOf(m);
        if (x - lastX >= 60.0) {
          _majorLabels.add(LabelInfo(m, majorIv.label(m)));
          majorXs.add(x);
          lastX = x;
        }
        m = majorIv.next(m);
      }
    }

    // Minor labels, thinned against each other AND against the majors so a
    // bold month label never collides with a minor day label.
    DateTime cur = labelIv.align(_currentStartDate);
    if (cur.isBefore(_currentStartDate)) cur = labelIv.next(cur);
    double lastX = -1e9;
    const minGapPx = 55.0;
    while (cur.isBefore(_currentEndDate)) {
      final x = xOf(cur);
      final nearMajor = majorXs.any((mx) => (mx - x).abs() < minGapPx);
      if (!nearMajor && x - lastX >= minGapPx) {
        _visibleLabels.add(LabelInfo(cur, labelIv.label(cur)));
        lastX = x;
      }
      cur = labelIv.next(cur);
    }
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

  void _handleScaleStart(ScaleStartDetails details) {
    _initialScaleZoomFactor = _zoomFactor;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // Handle zooming with pinch gesture
    if (details.scale != 1.0 && _initialScaleZoomFactor != null) {
      double newZoomFactor = (_initialScaleZoomFactor! / details.scale)
          .clamp(widget.minZoomFactor, widget.maxZoomFactor);

      if (newZoomFactor == _zoomFactor) {
        return;
      }

      Duration currentRange = _currentEndDate.difference(_currentStartDate);
      DateTime middlePoint = _currentStartDate.add(currentRange ~/ 2);
      double zoomChange = newZoomFactor / _zoomFactor;

      Duration newHalfRange = Duration(
        milliseconds: (currentRange.inMilliseconds * zoomChange / 2).round(),
      );

      setState(() {
        _zoomFactor = newZoomFactor;

        _currentStartDate = middlePoint.subtract(newHalfRange);
        _currentEndDate = middlePoint.add(newHalfRange);
        // bars + labels recomputed in build() via _recompute().
      });
      widget.onRangeChanged?.call(_currentStartDate, _currentEndDate);
    }

    // Handle panning during pinch gesture (touch devices)
    if (details.scale == 1.0 && details.focalPointDelta.dx != 0) {
      _processPanUpdate(details.focalPointDelta);
    }
  }

  void _handlePanStart(DragStartDetails details) {
    // Initialize state for mouse panning if needed
  }

  void _handleMousePanUpdate(DragUpdateDetails details) {
    _processPanUpdate(details.delta);
  }

  void _processPanUpdate(Offset delta) {
    Duration shiftDuration = Duration(
      milliseconds: (_zoomFactor * -delta.dx).round(),
    );

    setState(() {
      _currentStartDate = _currentStartDate.add(shiftDuration);
      _currentEndDate = _currentEndDate.add(shiftDuration);
      // labels recomputed in build() via _recompute().
    });

    widget.onRangeChanged?.call(_currentStartDate, _currentEndDate);
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
        // bars + labels recomputed in build() via _recompute().
      });
      widget.onRangeChanged?.call(_currentStartDate, _currentEndDate);
    }
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
        _recompute();
        return Stack(
          children: [
            RawGestureDetector(
              gestures: {
                ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                    ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(),
                  (ScaleGestureRecognizer instance) {
                    instance.onStart = _handleScaleStart;
                    instance.onUpdate = _handleScaleUpdate;
                    instance.supportedDevices = {PointerDeviceKind.touch};
                  },
                ),
                PanGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                  () => PanGestureRecognizer(),
                  (PanGestureRecognizer instance) {
                    instance.onStart = _handlePanStart;
                    instance.onUpdate = _handleMousePanUpdate;
                    instance.supportedDevices = {PointerDeviceKind.mouse};
                  },
                ),
              },
              child: Listener(
                onPointerSignal: _handleZoom,
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
                      majorLabels: _majorLabels,
                      getLabelInterval: () =>
                          _barInterval?.approxDuration ?? const Duration(days: 1),
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

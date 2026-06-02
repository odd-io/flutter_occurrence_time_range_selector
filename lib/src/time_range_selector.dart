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
  // Two-row ruler: fine ticks (day numbers / hours) on the top row...
  final List<LabelInfo> _visibleLabels = [];
  // ...and the coarser context spans (month / day-date / year) on the bottom
  // row — one label per boundary, painted left-aligned with a separator line.
  final List<LabelInfo> _majorLabels = [];
  double _widgetWidth = 0;
  late double _zoomFactor; // milliseconds per pixel
  double? _initialScaleZoomFactor;

  // Current calendar-aligned bar/grouping interval (chosen from range + width).
  CalendarInterval? _barInterval;

  @override
  void initState() {
    super.initState();
    // Work entirely in LOCAL time so calendar alignment (align/next) and the
    // axis labels land on local 00:00 / Monday / 1st — the data buckets are
    // already local. Mixing UTC start/end with local alignment put ticks on
    // UTC hours (e.g. 05:00 instead of 06:00).
    _currentStartDate = widget.startDate.toLocal();
    _currentEndDate = widget.endDate.toLocal();
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

    // Bars: aim for ~1 bar per 24px so the interval WALKS the calendar ladder
    // as you zoom (1h→3h→6h→12h→1d→1w…), ~2x per step — instead of always
    // grabbing the finest rung and then leaping 1h→1d at a threshold. This is
    // the D3 scaleTime / Grafana auto-interval behaviour. Never finer than the
    // base grid. Tunable: smaller divisor = more, thinner bars + bigger steps.
    final newBar = pickCalendarInterval(
      rangeMs: rangeMs,
      targetCount: _widgetWidth / 9,
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

    // Fine tick row: ~1 per 110px (Extended-Wilkinson density rule), never
    // finer than the bars. Calendar-aligned to local 00:00/Mon/1st. Labels
    // are the unit's own value only (day number / hour / month) — the coarse
    // context lives in the row below.
    var fineIv = pickCalendarInterval(
      rangeMs: rangeMs,
      targetCount: _widgetWidth / 110,
      min: _barInterval,
    );
    // High-zoom guarantee: at a sub-/few-day view always show time-of-day. If
    // the bar floor is coarse the fine ticks would otherwise degrade to day
    // numbers and the context would coarsen to the month (its boundaries
    // off-screen), leaving no readable time ("what time is this?"). Force a
    // sub-day rung so ticks render HH:mm and the context stays a day.
    const twoDaysMs = 2 * 86400 * 1000;
    if (rangeMs <= twoDaysMs &&
        fineIv.approxMs >=
            const CalendarInterval(CalendarUnit.day, 1).approxMs) {
      fineIv = const CalendarInterval(CalendarUnit.hour, 12);
    }
    DateTime cur = fineIv.align(_currentStartDate);
    if (cur.isBefore(_currentStartDate)) cur = fineIv.next(cur);
    double lastTickX = -1e9;
    const minGapPx = 42.0;
    while (cur.isBefore(_currentEndDate)) {
      final x = xOf(cur);
      if (x - lastTickX >= minGapPx) {
        _visibleLabels.add(LabelInfo(cur, fineIv.tickLabel(cur)));
        lastTickX = x;
      }
      cur = fineIv.next(cur);
    }

    // Context row: the next coarser calendar unit (hour→day, day/week→month,
    // month→year). One label per span, carried on its boundary DateTime — the
    // painter draws a separator line there and left-aligns the span label.
    final contextIv = majorIntervalFor(fineIv.unit);
    if (contextIv != null) {
      DateTime m = contextIv.align(_currentStartDate);
      // Include the boundary at/just-before start so the first (partial) span
      // is still labelled at the left edge.
      while (m.isBefore(_currentEndDate)) {
        if (!m.isBefore(_currentStartDate) || contextIv.next(m).isAfter(_currentStartDate)) {
          _majorLabels.add(LabelInfo(m, contextIv.spanLabel(m)));
        }
        m = contextIv.next(m);
      }
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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_occurrence_time_range_selector/flutter_occurrence_time_range_selector.dart';

/// Controlled component: the widget adopts EXTERNAL startDate/endDate prop
/// changes into its viewport (no key/remount needed), but never mid-gesture.
void main() {
  DateTime? lastStart;

  Widget build(DateTime start, DateTime end, void Function(DateTime, DateTime) cb) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 120,
            child: TimeRangeSelector(
              startDate: start,
              endDate: end,
              tagStyles: const {},
              minRangeMs: 3600 * 1000,
              onRangeChanged: cb,
              style: TimelineStyle(
                axisColor: Colors.black,
                axisLabelStyle: const TextStyle(fontSize: 10),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
      );

  Future<void> wheel(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(TimeRangeSelector));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -10)));
    await tester.pump();
  }

  testWidgets(
      'adopts an external window prop change — a later gesture operates on the '
      'NEW window, proving the strip followed the props without a remount',
      (tester) async {
    void cb(DateTime s, DateTime e) => lastStart = s;

    // Window A: year 2000.
    await tester.pumpWidget(build(DateTime(2000), DateTime(2000, 1, 2), cb));
    await tester.pump();

    // Rebuild with a far-away Window B (year 2020) — SAME widget, no key change,
    // so this drives didUpdateWidget rather than a fresh initState.
    await tester
        .pumpWidget(build(DateTime(2020), DateTime(2021), cb));
    await tester.pump();

    // A gesture now must report a window in 2020 (adopted), not 2000 (stale).
    await wheel(tester);
    expect(lastStart, isNotNull);
    expect(lastStart!.year, inInclusiveRange(2019, 2021),
        reason: 'the gesture operates on the adopted 2020 window');
  });

  testWidgets(
      'does NOT stomp an in-progress gesture: a prop change during a wheel '
      'burst is ignored until the gesture settles', (tester) async {
    void cb(DateTime s, DateTime e) => lastStart = s;

    await tester.pumpWidget(build(DateTime(2000), DateTime(2000, 1, 2), cb));
    await tester.pump();

    // Start a wheel burst (marks the gesture active with a 400ms cooldown).
    await wheel(tester);

    // An external prop change lands WHILE the gesture is active — must be
    // ignored (guarded), so the ongoing gesture keeps operating on year 2000.
    await tester.pumpWidget(build(DateTime(2020), DateTime(2021), cb));
    await tester.pump();
    await wheel(tester); // still within the 400ms cooldown

    expect(lastStart!.year, inInclusiveRange(1999, 2001),
        reason: 'a mid-gesture prop change must not stomp the active window');
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_occurrence_time_range_selector/flutter_occurrence_time_range_selector.dart';

/// minRangeMs: wheel-zooming can never collapse the viewport below the
/// floor. Without it, deep zoom legally reached a ~1-second window that a
/// consumer committed as a degenerate (start == end) time filter.
void main() {
  testWidgets('wheel zoom clamps at minRangeMs and never collapses',
      (tester) async {
    DateTime? lastStart;
    DateTime? lastEnd;
    final start = DateTime(2024, 1, 1);
    final end = DateTime(2024, 12, 31);

    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 800,
        height: 120,
        child: TimeRangeSelector(
          startDate: start,
          endDate: end,
          tagStyles: const {},
          minRangeMs: 3600 * 1000, // 1 hour floor
          onRangeChanged: (s, e) {
            lastStart = s;
            lastEnd = e;
          },
          style: TimelineStyle(
            axisColor: Colors.black,
            axisLabelStyle: const TextStyle(fontSize: 10),
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    ));

    final center = tester.getCenter(find.byType(TimeRangeSelector));
    // A deep zoom storm: 300 wheel-in ticks (each ×0.9 → far below 1h
    // without the floor: 365d × 0.9^300 ≈ 6 microseconds).
    final testPointer = TestPointer(1, PointerDeviceKind.mouse);
    testPointer.hover(center);
    for (var i = 0; i < 300; i++) {
      await tester.sendEventToBinding(
          testPointer.scroll(const Offset(0, -10)));
      await tester.pump();
    }

    expect(lastStart, isNotNull, reason: 'zoom must report ranges');
    final span = lastEnd!.difference(lastStart!);
    expect(span.inMilliseconds, greaterThanOrEqualTo(3600 * 1000),
        reason: 'the viewport must clamp at the floor');
    // And well-formed: strictly start < end, never degenerate.
    expect(lastStart!.isBefore(lastEnd!), isTrue);
  });
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_occurrence_time_range_selector/flutter_occurrence_time_range_selector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Occurrence Time Range Selector Demo'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  List<TimeEvent> generateRandomEvents(
      DateTime start, DateTime end, List<String> tags, int count) {
    Random random = Random();
    List<TimeEvent> events = [];

    print('Generating $count random events between $start and $end');
    final t1 = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < count; i++) {
      DateTime randomDate = DateTime(
        start.year,
        start.month + random.nextInt(end.month - start.month + 1),
        random.nextInt(31) + 1,
        random.nextInt(24),
        random.nextInt(60),
        random.nextInt(60),
        random.nextInt(1000),
      );
      if (randomDate.isAfter(start) && randomDate.isBefore(end)) {
        String randomTag = tags[random.nextInt(tags.length)];
        events.add(TimeEvent(tag: randomTag, dateTime: randomDate));
      } else {
        i--;
      }
    }
    final t2 = DateTime.now().millisecondsSinceEpoch;
    print('Generated $count random events in ${t2 - t1} ms');

    return events;
  }

  @override
  Widget build(BuildContext context) {
    final events = generateRandomEvents(
      DateTime(2024, 1, 1),
      DateTime(2024, 6, 28),
      ['Class A', 'Class B', 'Class C', 'Class D', 'Class E'],
      10000,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Column(
        children: [
          const Expanded(child: SizedBox()),
          Expanded(
            child: TimeRangeSelector(
              startDate: DateTime(2024, 1, 12),
              endDate: DateTime(2024, 2, 15),
              events: events,
              tagStyles: const {
                'Class A': TagStyle(color: Colors.blue),
                'Class B': TagStyle(color: Colors.red),
                'Class C': TagStyle(color: Colors.green),
                'Class D': TagStyle(color: Colors.orange),
                'Class E': TagStyle(color: Colors.purple),
              },
              onRangeChanged: (DateTime newStart, DateTime newEnd) {
                print('New range: $newStart to $newEnd');
              },
              style: const TimelineStyle(
                axisColor: Colors.black,
                axisLabelStyle: TextStyle(fontSize: 18, color: Colors.black),
                barSpacing: 2,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Expanded(
              child: SizedBox(
            child: SelectableText(events.toString()),
          )),
        ],
      ),
    );
  }
}

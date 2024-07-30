import 'dart:async';
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Timer? _debounceTimer;
  late DateTime _endDate;
  late List<TimeEvent> _events;
  late DateTime _startDate;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(2024, 1, 12);
    _endDate = DateTime(2024, 2, 15);
    _events = generateRandomEvents(
      DateTime(2024, 1, 1),
      DateTime(2024, 6, 28),
      ['Class A', 'Class B', 'Class C', 'Class D', 'Class E'],
      10000,
    );
  }

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

  void _showDateRangePicker() async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2024, 12, 31),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (pickedRange != null) {
      _updateDateRange(pickedRange.start, pickedRange.end);
    }
  }

  void _updateDateRange(DateTime newStart, DateTime newEnd) {
    setState(() {
      _startDate = newStart;
      _endDate = newEnd;
    });
  }

  void _debouncedUpdateDateRange(DateTime newStart, DateTime newEnd) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateDateRange(newStart, newEnd);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ElevatedButton(
                onPressed: _showDateRangePicker,
                child: Text(
                    'Select Date Range: ${_startDate.toString().substring(0, 10)} to ${_endDate.toString().substring(0, 10)}'),
              ),
            ),
          ),
          Expanded(
            child: TimeRangeSelector(
              key: ValueKey('$_startDate-$_endDate'),
              startDate: _startDate,
              endDate: _endDate,
              events: _events,
              tagStyles: const {
                'Class A': TagStyle(color: Colors.blue),
                'Class B': TagStyle(color: Colors.red),
                'Class C': TagStyle(color: Colors.green),
                'Class D': TagStyle(color: Colors.orange),
                'Class E': TagStyle(color: Colors.purple),
              },
              onRangeChanged: (DateTime newStart, DateTime newEnd) {
                print('New range: $newStart to $newEnd');
                _debouncedUpdateDateRange(newStart, newEnd);
              },
              style: const TimelineStyle(
                axisColor: Colors.black,
                axisLabelStyle: TextStyle(fontSize: 18, color: Colors.black),
                backgroundColor: Colors.white,
                useLogarithmicScale: false,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(_events.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

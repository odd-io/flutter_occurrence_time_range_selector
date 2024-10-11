import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _addEvents = false;
  Timer? _debounceTimer;
  late DateTime _endDate;
  final TextEditingController _eventCountController = TextEditingController();
  late List<TimeEvent> _events;
  ScaleType _scaleType = ScaleType.linear;
  late DateTime _startDate;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _eventCountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(2024, 1, 12);
    _endDate = DateTime(2024, 2, 15);
    _events = generateRandomEvents(
      _startDate,
      _endDate,
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
      DateTime randomDate = start.add(Duration(
        seconds: random.nextInt(end.difference(start).inSeconds),
      ));
      String randomTag = tags[random.nextInt(tags.length)];
      events.add(TimeEvent(tag: randomTag, dateTime: randomDate));
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

  void _updateScaleType(ScaleType newScaleType) {
    setState(() {
      _scaleType = newScaleType;
    });
  }

  void _generateCustomEvents() {
    int count = int.tryParse(_eventCountController.text) ?? 0;
    if (count > 0) {
      setState(() {
        List<TimeEvent> newEvents = generateRandomEvents(
          _startDate,
          _endDate,
          ['Class A', 'Class B', 'Class C', 'Class D', 'Class E'],
          count,
        );
        if (_addEvents) {
          _events.addAll(newEvents);
        } else {
          _events = newEvents;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Determine screen width to adjust layout for mobile
          bool isNarrow = constraints.maxWidth < 600;
          return SingleChildScrollView(
            child: Column(
              children: [
                // Top Controls (Date Range and Scale Type)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildTopControls(isNarrow),
                        )
                      : Row(
                          children: _buildTopControls(isNarrow),
                        ),
                ),
                // Event Controls (Event Count and Generate Button)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildEventControls(isNarrow),
                        )
                      : Row(
                          children: _buildEventControls(isNarrow),
                        ),
                ),
                // Time Range Selector Widget
                SizedBox(
                  height: isNarrow ? 300 : 400, // Adjust height for mobile
                  child: TimeRangeSelector(
                    key: ValueKey(
                        '$_startDate-$_endDate-$_scaleType-${_events.length}'),
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
                    style: TimelineStyle(
                      axisColor: Colors.black,
                      axisLabelStyle:
                          const TextStyle(fontSize: 18, color: Colors.black),
                      backgroundColor: Colors.white,
                      scaleType: _scaleType,
                    ),
                    highlightGroups: [
                      HighlightGroup(
                        dates: [DateTime(2024, 3, 1), DateTime(2024, 4, 15)],
                        builder: (context, size) => const DotHighlight(),
                      ),
                      HighlightGroup(
                        dates: [DateTime(2024, 7, 4), DateTime(2024, 1, 20)],
                        builder: (context, size) =>
                            const StarHighlight(color: Colors.amber),
                      ),
                      HighlightGroup(
                        dates: [DateTime(2024, 5, 10)],
                        builder: (context, size) => Tooltip(
                          message: 'Special Date',
                          child: InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Special Date Tapped!'),
                                ),
                              );
                            },
                            child: Container(
                              width: 10,
                              height: 10,
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Total Events Text
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Total Events: ${_events.length}'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper method for top controls
  List<Widget> _buildTopControls(bool isNarrow) {
    return [
      if (isNarrow)
        ElevatedButton(
          onPressed: _showDateRangePicker,
          child: Text(
            'Date Range: ${_startDate.toString().substring(0, 10)}'
            ' to ${_endDate.toString().substring(0, 10)}',
          ),
        )
      else
        Expanded(
          child: ElevatedButton(
            onPressed: _showDateRangePicker,
            child: Text(
              'Date Range: ${_startDate.toString().substring(0, 10)}'
              ' to ${_endDate.toString().substring(0, 10)}',
            ),
          ),
        ),
      const SizedBox(width: 8),
      if (isNarrow)
        SegmentedButton<ScaleType>(
          segments: const [
            ButtonSegment<ScaleType>(
              value: ScaleType.linear,
              label: Text('Linear'),
            ),
            ButtonSegment<ScaleType>(
              value: ScaleType.squareRoot,
              label: Text('Square Root'),
            ),
            ButtonSegment<ScaleType>(
              value: ScaleType.logarithmic,
              label: Text('Logarithmic'),
            ),
          ],
          selected: {_scaleType},
          onSelectionChanged: (Set<ScaleType> newSelection) {
            _updateScaleType(newSelection.first);
          },
        )
      else
        Expanded(
          child: SegmentedButton<ScaleType>(
            segments: const [
              ButtonSegment<ScaleType>(
                value: ScaleType.linear,
                label: Text('Linear'),
              ),
              ButtonSegment<ScaleType>(
                value: ScaleType.squareRoot,
                label: Text('Square Root'),
              ),
              ButtonSegment<ScaleType>(
                value: ScaleType.logarithmic,
                label: Text('Logarithmic'),
              ),
            ],
            selected: {_scaleType},
            onSelectionChanged: (Set<ScaleType> newSelection) {
              _updateScaleType(newSelection.first);
            },
          ),
        ),
    ];
  }

  // Helper method for event controls
  List<Widget> _buildEventControls(bool isNarrow) {
    return [
      if (isNarrow)
        TextField(
          controller: _eventCountController,
          decoration: const InputDecoration(
            labelText: 'Number of Events',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        )
      else
        Expanded(
          child: TextField(
            controller: _eventCountController,
            decoration: const InputDecoration(
              labelText: 'Number of Events',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
      const SizedBox(width: 8),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: false,
            label: Text('Replace'),
          ),
          ButtonSegment<bool>(
            value: true,
            label: Text('Add'),
          ),
        ],
        selected: {_addEvents},
        onSelectionChanged: (Set<bool> newSelection) {
          setState(() {
            _addEvents = newSelection.first;
          });
        },
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: _generateCustomEvents,
        child: const Text('Generate Events'),
      ),
    ];
  }
}

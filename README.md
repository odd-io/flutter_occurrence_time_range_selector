# 📊 Occurrence Time Range Selector

A highly interactive and customizable Flutter widget that allows users to select a time range while visualizing event occurrences on a dynamic chart.

![example_screenshot](https://github.com/user-attachments/assets/23c158d2-0a73-46fd-a872-6304ca07bc1b)

## ✨ Features

- 🔍 Zoom and pan functionality for detailed exploration
- 📅 Dynamic time scale adapting to the selected range
- 📊 Stacked vertical bars for multiple event classes
- 🎨 Customizable colors and styles
- ⏱️ Millisecond precision for high-detail views
- 🖱️ Optimized for desktop use with mouse and keyboard

## 🚀 Getting Started

### Usage

Import the package in your Dart code:

```dart
import 'package:occurrence_time_range_selector/occurrence_time_range_selector.dart';
```

Then, you can use the `TimeRangeSelector` widget in your Flutter app:

```dart
final now = DateTime.now();

TimeRangeSelector(
  startDate: now.subtract(Duration(days: 30)),
  endDate: now.add(Duration(days: 30)),
  events: [
    TimeEvent(tag: 'Class A', dateTime: now.subtract(Duration(days: 15))),
    TimeEvent(tag: 'Class B', dateTime: now.subtract(Duration(days: 7))),
    TimeEvent(tag: 'Class A', dateTime: now),
    TimeEvent(tag: 'Class C', dateTime: now.add(Duration(days: 10))),
    TimeEvent(tag: 'Class B', dateTime: now.add(Duration(days: 20))),
  ],
  tagStyles: const {
    'Class A': TagStyle(color: Colors.blue),
    'Class B': TagStyle(color: Colors.red),
    'Class C': TagStyle(color: Colors.green),
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
)
```

## 🛠️ Customization

The `TimeRangeSelector` widget offers various customization options:

- `tagStyles`: Define colors for different event classes
- `style`: Customize the appearance of the timeline
- `minZoomFactor` and `maxZoomFactor`: Set limits for zooming capabilities

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](link_to_license_file) file for details.

---

Made with ❤️ by [odd.io](https://odd.io/)

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Defines the visual style for the TimeRangeSelector widget.
///
/// This class encapsulates various style properties that control the appearance
/// of the timeline, including colors and scaling options.
class TimelineStyle extends Equatable {
  /// Creates a [TimelineStyle] with the specified properties.
  ///
  /// All parameters are required except [useLogarithmicScale].
  const TimelineStyle({
    required this.axisColor,
    required this.axisLabelStyle,
    required this.backgroundColor,
    this.scaleType = ScaleType.linear,
    this.dayNightShadeColor,
  });

  /// The color of the timeline's axis line.
  ///
  /// This color is used for drawing the main horizontal axis of the timeline.
  final Color axisColor;

  /// The text style for the axis labels.
  ///
  /// This style is applied to the date/time labels along the timeline axis.
  final TextStyle axisLabelStyle;

  /// The background color of the entire timeline widget.
  final Color backgroundColor;

  /// The type of scaling to use for the timeline axis.
  ///
  /// The default value is [ScaleType.linear].
  final ScaleType scaleType;

  /// When non-null AND the bar interval is sub-day, the painter shades a
  /// fixed night window (20:00–06:00 local) behind the bars with this
  /// color. Null disables day/night shading. Use a low-alpha cool tint.
  final Color? dayNightShadeColor;

  @override
  List<Object?> get props => [
        axisColor,
        axisLabelStyle,
        backgroundColor,
        scaleType,
        dayNightShadeColor,
      ];
}

enum ScaleType { linear, logarithmic, squareRoot }

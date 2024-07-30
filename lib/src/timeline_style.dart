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
    this.useLogarithmicScale = false,
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

  /// Determines whether to use a logarithmic scale for event bar heights.
  ///
  /// When set to true, the heights of event bars are calculated using a logarithmic scale,
  /// which can be useful for visualizing data with a wide range of values.
  /// When false, a linear scale is used.
  ///
  /// Defaults to false.
  final bool useLogarithmicScale;

  @override
  List<Object?> get props => [
        axisColor,
        axisLabelStyle,
        backgroundColor,
        useLogarithmicScale,
      ];
}

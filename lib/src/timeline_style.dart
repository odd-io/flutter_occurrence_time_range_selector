import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class TimelineStyle extends Equatable {
  const TimelineStyle({
    required this.axisColor,
    required this.axisLabelStyle,
    required this.barSpacing,
    required this.backgroundColor,
  });

  final Color axisColor;
  final TextStyle axisLabelStyle;
  final Color backgroundColor;
  final double barSpacing;

  @override
  List<Object?> get props =>
      [axisColor, axisLabelStyle, barSpacing, backgroundColor];
}

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class HighlightGroup extends Equatable {
  const HighlightGroup({
    required this.dates,
    required this.builder,
  });

  final Widget Function(BuildContext, Size) builder;
  final List<DateTime> dates;

  @override
  List<Object?> get props => [dates, builder];
}

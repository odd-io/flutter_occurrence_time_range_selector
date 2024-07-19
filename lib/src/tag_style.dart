import 'dart:ui';

import 'package:equatable/equatable.dart';

class TagStyle extends Equatable {
  const TagStyle({required this.color});

  final Color color;

  @override
  List<Object?> get props => [color];
}

import 'package:flutter/material.dart';

class DotHighlight extends StatelessWidget {
  final Color color;
  final double size;

  const DotHighlight({
    super.key,
    this.color = Colors.black,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  DotHighlight copyWith({Color? color, double? size}) {
    return DotHighlight(
      color: color ?? this.color,
      size: size ?? this.size,
    );
  }
}

class StarHighlight extends StatelessWidget {
  final Color color;
  final double size;

  const StarHighlight({
    super.key,
    this.color = Colors.black,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.star,
      color: color,
      size: size,
    );
  }

  StarHighlight copyWith({Color? color, double? size}) {
    return StarHighlight(
      color: color ?? this.color,
      size: size ?? this.size,
    );
  }
}
